"""Isolated portal, filesystem boundary and submission regressions; never send files."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / 'scripts/portal_files.py'


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

    def test_submission_accept_failure_timeout_and_cancel_are_truthful(self):
        helper = module()
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            source = base / 'sensitive-file'
            source.write_bytes(b'test')
            chosen = helper.inspect_uris([source.as_uri()])[0]
            backend = base / 'kdeconnect-cli'
            backend.write_text("#!/usr/bin/python3\nimport json,os,sys,time\nwith open(os.environ['FAKE_RECEIPT'],'a') as out: out.write(json.dumps(sys.argv[1:])+'\\n')\nif os.environ['FAKE_MODE']=='hang': time.sleep(5)\nraise SystemExit(0 if os.environ['FAKE_MODE']=='accept' else 1)\n")
            backend.chmod(0o700)
            receipt = base / 'receipt'
            env = dict(os.environ, PATH=str(base), HOME=str(base),
                       XDG_CACHE_HOME=str(base / 'cache'), FAKE_RECEIPT=str(receipt))
            loader = "import importlib.util,sys; sys.path.insert(0," + repr(str(HELPER.parent)) + "); s=importlib.util.spec_from_file_location('picker'," + repr(str(HELPER)) + "); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); m.SUBMISSION_TIMEOUT=.15; raise SystemExit(m.main())"
            payload = json.dumps({'peerId': 'reviewed-peer', 'file': chosen}) + '\n'
            for mode, state in [('accept', 'request_accepted'), ('fail', 'submission_failed'), ('hang', 'submission_unknown')]:
                run = subprocess.run([sys.executable, '-c', loader, 'submit'], env=dict(env, FAKE_MODE=mode), input=payload, capture_output=True, text=True, timeout=5)
                self.assertEqual(run.returncode, 0, run.stderr)
                result = [json.loads(line) for line in run.stdout.splitlines()]
                self.assertEqual(result[0], {'event': 'preparing'})
                self.assertIn({'event': 'submitting'},result)
                self.assertEqual(result[-1]['state'], state)
                self.assertNotIn(str(source), run.stdout + run.stderr)
            process = subprocess.Popen([sys.executable, str(HELPER), 'submit'], env=dict(env, FAKE_MODE='hang'), stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            process.stdin.write(payload)
            process.stdin.flush()
            self.assertEqual(json.loads(process.stdout.readline()), {'event': 'preparing'})
            self.assertEqual(json.loads(process.stdout.readline()), {'event': 'submitting'})
            process.terminate()
            output, error = process.communicate(timeout=5)
            self.assertEqual(json.loads(output)['state'], 'cancellation_unconfirmed')
            self.assertNotIn(str(source), output + error)
            calls = [json.loads(line) for line in receipt.read_text().splitlines()]
            # Exactly one invocation per attempted source, including timeout.
            self.assertTrue(3 <= len(calls) <= 4)
            self.assertTrue(all(call == ['-d', 'reviewed-peer', '--share', str(source)] for call in calls))

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
            receipt = base / 'native-receipt.json'
            backend = base / 'kdeconnect-cli'
            backend.write_text('''#!/usr/bin/python3
import json, os, sys
from pathlib import Path
assert sys.argv[1:4] == ['-d', 'reviewed-peer', '--share']
assert len(sys.argv) == 5
original = Path(os.environ['OWNED_ORIGINAL'])
original.unlink()
original.symlink_to(os.environ['OWNED_SECRET'])
passed = Path(sys.argv[4])
Path(os.environ['OWNED_RECEIPT']).write_text(json.dumps({
    'path': str(passed), 'bytes': passed.read_bytes().hex()}))
''')
            backend.chmod(0o700)
            cache = base / 'cache'
            env = {'PATH': str(base), 'HOME': str(base), 'XDG_CACHE_HOME': str(cache),
                   'OWNED_ORIGINAL': str(source), 'OWNED_SECRET': str(secret),
                   'OWNED_RECEIPT': str(receipt)}
            # Negative control substitutes only the former raw-path handoff in
            # this child. Actual submit/backend code and the replacement attack
            # remain identical. No production source is changed.
            control = ("import contextlib,runpy,sys\nsys.path.insert(0," + repr(str(HELPER.parent)) + ")\n"
                       "import private_sources as boundary\n"
                       "@contextlib.contextmanager\ndef raw_path(expected,cancelled):\n"
                       " yield boundary.PreparedSource(expected['path'],False)\n"
                       "boundary.prepared_source=raw_path\n"
                       "runpy.run_path(" + repr(str(HELPER)) + ",run_name='__main__')\n")
            red = subprocess.run([sys.executable, '-c', control, 'submit'], env=env,
                input=json.dumps({'peerId': 'reviewed-peer', 'file': chosen}) + '\n',
                capture_output=True, text=True, timeout=5)
            self.assertEqual(red.returncode, 0, red.stderr)
            redirected = json.loads(receipt.read_text())
            self.assertEqual(redirected['path'], str(source))
            self.assertEqual(bytes.fromhex(redirected['bytes']), secret.read_bytes(),
                             'raw-path negative control must demonstrate redirection')
            source.unlink()
            source.write_bytes(intended)
            chosen = helper.inspect_uris([source.as_uri()])[0]
            receipt.unlink()
            run = subprocess.run([sys.executable, str(HELPER), 'submit'], env=env,
                input=json.dumps({'peerId': 'reviewed-peer', 'file': chosen}) + '\n',
                capture_output=True, text=True, timeout=5)
            self.assertEqual(run.returncode, 0, run.stderr)
            results = [json.loads(line) for line in run.stdout.splitlines()]
            self.assertEqual(results, [{'event': 'preparing'}, {'event': 'submitting'},
                                      {'state': 'request_accepted', 'error': ''}])
            actual = json.loads(receipt.read_text())
            self.assertEqual(bytes.fromhex(actual['bytes']), intended)
            self.assertNotEqual(bytes.fromhex(actual['bytes']), secret.read_bytes())
            snapshot = Path(actual['path'])
            self.assertTrue(snapshot.is_relative_to(cache / 'Omaconnect.plus/share-snapshots'))
            self.assertEqual(snapshot.name, source.name)
            self.assertEqual(snapshot.stat().st_mode & 0o777, 0o600)
            self.assertEqual(snapshot.parent.stat().st_mode & 0o777, 0o700)
            self.assertTrue(source.is_symlink(), 'fixture replaced the original before opening the passed path')
            self.assertEqual(snapshot.read_bytes(), intended, 'snapshot survives CLI exit for later KDE reopen')
            for private in (str(source), str(secret), str(snapshot), 'OWNED-REVIEWED-BYTES', 'OWNED-SECRET'):
                self.assertNotIn(private, run.stdout + run.stderr)

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
