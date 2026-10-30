"""Isolated portal, filesystem boundary and submission regressions; never send files."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / 'scripts/portal_files.py'
FAKE_SHARE = ROOT / 'tests/fake_share_provider.py'


def module():
    spec = importlib.util.spec_from_file_location('portal_files', HELPER)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


class Files(unittest.TestCase):
    def setUp(self):
        # Fixtures assume umask 022; a group-writable source rightly loses the private fast path.
        self.addCleanup(os.umask, os.umask(0o022))

    def test_regular_files_and_limits_are_inspected(self):
        helper = module()
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            weird = base / ' strange\n☃.unknown'
            weird.write_bytes(b'abc')
            empty = base / 'empty'
            empty.touch()
            selection = helper.inspect_uris([weird.as_uri(), empty.as_uri()])
            self.assertEqual([item['size'] for item in selection], [3, 0])
            self.assertEqual(selection[0]['path'], str(weird))
            for bad in [base.as_uri(), 'https://example.com/file', 'file://remote/tmp/x', '/tmp/x', 'file:///tmp/%00x']:
                with self.subTest(bad=bad), self.assertRaises(ValueError):
                    helper.inspect_uris([bad])
            fifo = base / 'fifo'
            os.mkfifo(fifo)
            with self.assertRaises(ValueError):
                helper.inspect_uris([fifo.as_uri()])
            with self.assertRaises(ValueError):
                helper.inspect_uris([weird.as_uri()] * 101)
            huge = base / 'huge'
            with huge.open('wb') as stream:
                stream.truncate(2 ** 40 + 1)
            with self.assertRaises(ValueError):
                helper.inspect_uris([huge.as_uri()])

    def test_changed_sources_do_not_reach_backend(self):
        helper = module()
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / 'source'
            source.write_bytes(b'before')
            chosen = helper.inspect_uris([source.as_uri()])[0]
            source.write_bytes(b'changed')
            with self.assertRaises(ValueError):
                helper.validate_file(chosen)
            source.unlink()
            source.symlink_to('/dev/null')
            with self.assertRaises(ValueError):
                helper.validate_file(chosen)

    def share(self, mode, env, payload, command=None):
        """Run one submit against the owned fake KDE share service on a private bus."""
        command = command or [sys.executable, str(HELPER), 'submit']
        run = subprocess.run(['dbus-run-session', '--', sys.executable, str(FAKE_SHARE), mode, *command],
                             env=env, input=payload, capture_output=True, text=True, timeout=20)
        self.assertEqual(run.returncode, 0, run.stderr)
        report = json.loads(run.stdout)
        self.assertEqual(report['returncode'], 0, report['stderr'])
        report['results'] = [json.loads(line) for line in report['stdout'].splitlines()]
        for call in report['calls']:
            self.assertEqual((call['path'], call['interface'], call['method']),
                             ('/modules/kdeconnect/devices/reviewed_peer/share',
                              'org.kde.kdeconnect.device.share', 'shareUrls'))
            self.assertGreater(len(call['argv']), 1, 'process argv probe is empty')
            self.assertNotIn(call['local'], '\0'.join(call['argv']), 'file path reached process argv')
        return report

    def test_submission_accept_failure_timeout_and_cancel_are_truthful(self):
        helper = module()
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            source = base / 'sensitive file #1?%.txt'
            source.write_bytes(b'test')
            chosen = helper.inspect_uris([source.as_uri()])[0]
            env = dict(os.environ, HOME=str(base), XDG_CACHE_HOME=str(base / 'cache'))
            loader = "import importlib.util,sys; sys.path.insert(0," + repr(str(HELPER.parent)) + "); s=importlib.util.spec_from_file_location('picker'," + repr(str(HELPER)) + "); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); m.SUBMISSION_TIMEOUT=.3; raise SystemExit(m.main())"
            payload = json.dumps({'peerId': 'reviewed_peer', 'file': chosen}) + '\n'
            for mode, state, error in [('accept', 'request_accepted', ''), ('fail', 'submission_failed', 'submission-failed'),
                                       ('hang', 'submission_unknown', 'submission-unknown'),
                                       ('cancel', 'cancellation_unconfirmed', 'cancellation-unconfirmed'),
                                       ('unavailable', 'submission_failed', 'provider-missing')]:
                with self.subTest(mode=mode):
                    command = [sys.executable, '-c', loader, 'submit'] if mode == 'hang' else None
                    report = self.share(mode, env, payload, command)
                    self.assertEqual(report['results'], [{'event': 'preparing'}, {'event': 'submitting'},
                                                         {'state': state, 'error': error}])
                    # Exactly one share request per attempted source, as one percent-encoded file URL.
                    self.assertEqual([call['urls'] for call in report['calls']],
                                     [] if mode == 'unavailable' else [[source.as_uri()]])
                    self.assertEqual([call['local'] for call in report['calls']],
                                     [] if mode == 'unavailable' else [str(source)])
                    self.assertNotIn(str(source), report['stdout'] + report['stderr'])
                    self.assertNotIn(source.name, report['stdout'] + report['stderr'])

    def test_actual_submit_keeps_reviewed_bytes_when_shared_path_is_replaced_before_native_open(self):
        helper = module()
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            shared = base / 'shared'
            shared.mkdir(mode=0o777)
            shared.chmod(0o777)
            source = shared / 'reviewed file.bin'
            intended = b'OWNED-REVIEWED-BYTES'
            source.write_bytes(intended)
            chosen = helper.inspect_uris([source.as_uri()])[0]
            secret = base / 'owned-secret'
            secret.write_bytes(b'OWNED-SECRET-MUST-NOT-REACH-RECIPIENT')
            secret.chmod(0o600)
            cache = base / 'cache'
            env = dict(os.environ, HOME=str(base), XDG_CACHE_HOME=str(cache),
                       OWNED_ORIGINAL=str(source), OWNED_SECRET=str(secret))
            payload = json.dumps({'peerId': 'reviewed_peer', 'file': chosen}) + '\n'
            # Negative control substitutes only the former raw-path handoff in
            # this child. Actual submit/provider code and the replacement attack
            # remain identical. No production source is changed.
            control = ("import contextlib,runpy,sys\nsys.path.insert(0," + repr(str(HELPER.parent)) + ")\n"
                       "import private_sources as boundary\n"
                       "@contextlib.contextmanager\ndef raw_path(expected,cancelled):\n"
                       " yield boundary.PreparedSource(expected['path'],False)\n"
                       "boundary.prepared_source=raw_path\n"
                       "runpy.run_path(" + repr(str(HELPER)) + ",run_name='__main__')\n")
            red = self.share('replace', env, payload, [sys.executable, '-c', control, 'submit'])
            redirected = red['calls'][0]
            self.assertEqual(redirected['local'], str(source))
            self.assertEqual(bytes.fromhex(redirected['bytes']), secret.read_bytes(),
                             'raw-path negative control must demonstrate redirection')
            source.unlink()
            source.write_bytes(intended)
            chosen = helper.inspect_uris([source.as_uri()])[0]
            payload = json.dumps({'peerId': 'reviewed_peer', 'file': chosen}) + '\n'
            run = self.share('replace', env, payload)
            self.assertEqual(run['results'], [{'event': 'preparing'}, {'event': 'submitting'},
                                              {'state': 'request_accepted', 'error': ''}])
            actual = run['calls'][0]
            self.assertEqual(bytes.fromhex(actual['bytes']), intended)
            snapshot = Path(actual['local'])
            self.assertTrue(snapshot.is_relative_to(cache / 'Omaconnect.plus/share-snapshots'))
            self.assertEqual(snapshot.name, source.name)
            self.assertEqual(snapshot.stat().st_mode & 0o777, 0o600)
            self.assertEqual(snapshot.parent.stat().st_mode & 0o777, 0o700)
            self.assertTrue(source.is_symlink(), 'fixture replaced the original before opening the passed path')
            self.assertEqual(snapshot.read_bytes(), intended, 'snapshot survives the share call for later KDE open')
            for private in (str(source), str(secret), str(snapshot), 'OWNED-REVIEWED-BYTES', 'OWNED-SECRET'):
                self.assertNotIn(private, run['stdout'] + run['stderr'])

    def test_start_sweep_removes_only_expired_copies_and_never_creates_the_cache(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            env = {'PATH': '/usr/bin:/bin', 'HOME': str(base), 'XDG_CACHE_HOME': str(base / 'cache')}
            sweep = lambda: subprocess.run([sys.executable, str(HELPER), 'sweep'], env=env,
                                           capture_output=True, text=True, timeout=5)
            run = sweep()
            self.assertEqual((run.returncode, run.stdout, run.stderr), (0, '', ''))
            self.assertFalse((base / 'cache').exists(), 'sweep must not create the cache')
            snapshots = base / 'cache/Omaconnect.plus/share-snapshots'
            snapshots.mkdir(parents=True, mode=0o700)
            snapshots.parent.chmod(0o700)
            expired, recent = snapshots / ('source-' + 'a' * 32), snapshots / ('source-' + 'b' * 32)
            for folder in (expired, recent):
                folder.mkdir(mode=0o700)
                (folder / 'copy.bin').write_bytes(b'copy')
                (folder / 'copy.bin').chmod(0o600)
            old = time.time() - 24 * 60 * 60 - 10
            os.utime(expired, (old, old))
            run = sweep()
            self.assertEqual((run.returncode, run.stdout, run.stderr), (0, '', ''))
            self.assertFalse(expired.exists())
            self.assertTrue((recent / 'copy.bin').is_file())
            os.utime(recent, (old, old))
            snapshots.parent.chmod(0o755)
            run = sweep()
            self.assertEqual((run.returncode, run.stdout, run.stderr), (0, '', ''))
            self.assertTrue((recent / 'copy.bin').is_file(), 'an unsafe cache is left alone')

    def test_invalid_peer_returns_fixed_identity_mismatch_before_file_preparation(self):
        with tempfile.TemporaryDirectory() as directory:
            for peer in (None, '', 'bad\npeer', 'x' * 257, []):
                with self.subTest(peer_type=type(peer).__name__):
                    run = subprocess.run([sys.executable, str(HELPER), 'submit'],
                        env={'PATH': directory, 'HOME': directory, 'XDG_CACHE_HOME': directory},
                        input=json.dumps({'peerId': peer, 'file': {}}) + '\n',
                        capture_output=True, text=True, timeout=5)
                    self.assertEqual(run.returncode, 1)
                    self.assertEqual(json.loads(run.stdout), {'state': 'failed', 'error': 'identity-mismatch'})
                    self.assertEqual(run.stderr, '')
            self.assertEqual(list(Path(directory).iterdir()), [], 'invalid identity starts no cache/provider work')

    def test_private_portal_multiselect_and_cancel(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / ' arbitrary\nname.weird'
            source.write_bytes(b'test')
            env = dict(os.environ, TEST_PORTAL_URIS=json.dumps([source.as_uri()]), TEST_PICKER=str(HELPER))
            fixture = ROOT / 'tests/fake_file_portal.py'
            for response, expected in [('0', 'selected'), ('1', 'cancelled')]:
                run = subprocess.run(['dbus-run-session', '--', 'python3', str(fixture)], env=dict(env, TEST_PORTAL_RESPONSE=response), capture_output=True, text=True, timeout=15)
                self.assertEqual(run.returncode, 0, run.stderr)
                result = json.loads(run.stdout)
                self.assertEqual(result['state'], expected)
                if expected == 'selected':
                    self.assertEqual(result['files'][0]['path'], str(source))

    def test_real_model_and_controller_functions(self):
        run = subprocess.run(['node', str(ROOT / 'tests/transfer_model_test.js')], capture_output=True, text=True, timeout=10)
        self.assertEqual(run.returncode, 0, run.stderr)


if __name__ == '__main__':
    unittest.main()
