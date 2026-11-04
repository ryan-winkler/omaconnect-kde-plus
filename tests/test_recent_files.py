"""Owned temporary roots and fake menus; never open UI or inspect user files."""
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).resolve().parents[1] / 'scripts'


def module():
    """Load a fresh helper module without starting a picker."""
    spec = importlib.util.spec_from_file_location('recent_files', SCRIPTS / 'recent_files.py')
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    return helper


class RecentFiles(unittest.TestCase):
    def setUp(self):
        """Isolate each case in owned roots with a replaceable menu executable."""
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name)
        self.helper = module()
        self.addCleanup(patch.stopall)
        patch.object(Path, 'home', return_value=self.home).start()
        patch.object(sys, 'path', [str(SCRIPTS), *sys.path]).start()
        self.menu = self.home / 'fake-menu'
        self.helper.MENU = str(self.menu)

    def file(self, name='Downloads/file.txt', mtime=10):
        """Create one synthetic candidate with a controlled modification time."""
        path = self.home / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b'owned fixture')
        os.utime(path, ns=(mtime, mtime))
        return path

    def fake(self, body):
        """Install an owned menu double that can exercise subprocess behavior."""
        self.menu.write_text('#!' + sys.executable + '\n' + body + '\n')
        self.menu.chmod(0o700)

    def test_selected_metadata_recent_order_and_fixed_native_arguments(self):
        """Verify recent ordering, recipient sanitization and inspected selection metadata."""
        old = self.file('Documents/old.pdf', 1)
        new = self.file('Downloads/new ☃ \'"\\.txt', 20)
        args = self.home / 'args.json'
        self.fake('import sys,json\nfrom pathlib import Path\n'
                  f'Path({str(args)!r}).write_text(json.dumps(sys.argv[1:]))\n'
                  'print(sys.argv[2])')
        result = self.helper.choose_recent('Phone\n\u202e --width 900')
        self.assertEqual(result['state'], 'selected')
        self.assertEqual(result['files'][0]['path'], str(new))
        self.assertEqual(result['files'][0]['size'], len(b'owned fixture'))
        self.assertTrue(result['files'][0]['inode'])
        argv = json.loads(args.read_text())
        self.assertEqual(argv, [self.helper.PROMPT + ' to Phone --width 900', str(new), str(old), '--',
                                '--width', '800', '--maxheight', '500'])

    def test_cancel_missing_menu_and_empty_roots_are_fixed_results(self):
        """Check empty roots, missing tools and menu exits expose only fixed results."""
        with patch.object(self.helper.subprocess, 'Popen') as popen:
            self.assertEqual(self.helper.choose_recent(),
                             {'state': 'failed', 'error': 'recent-files-empty'})
            popen.assert_not_called()
        self.file()
        self.assertEqual(self.helper.choose_recent()['error'], 'recent-files-unavailable')
        self.fake('import sys\nprint("private error",file=sys.stderr)\nsys.exit(1)')
        self.assertEqual(self.helper.choose_recent(), {'state': 'cancelled', 'files': []})
        self.fake('import sys\nprint("private error",file=sys.stderr)\nsys.exit(2)')
        self.assertEqual(self.helper.choose_recent(),
                         {'state': 'failed', 'error': 'recent-files-unavailable'})

    def test_rejects_unoffered_multiline_invalid_utf8_and_output_flood(self):
        """Reject injected selections and malformed or excessive menu output."""
        offered = self.file()
        other = self.file('elsewhere/unoffered.txt')
        for raw in [str(other).encode(), (str(offered) + '\n' + str(other)).encode(),
                    b'\xff', b'x' * (self.helper.MAX_OUTPUT + 1),
                    (str(offered) + '\n\n').encode()]:
            with self.subTest(raw=raw[:40]):
                self.fake(f'import os\nos.write(1,{raw!r})')
                self.assertEqual(self.helper.choose_recent(),
                                 {'state': 'failed', 'error': 'source-path-rejected'})

    def test_filters_controls_hidden_symlinks_folders_and_depth(self):
        """Exclude entries the native menu cannot safely offer as local regular files."""
        valid = self.file('Downloads/a/b/c/depth4.TXT')
        self.file('Downloads/a/b/c/d/depth5.txt')
        self.file('Downloads/.hidden.txt')
        self.file('Documents/.private/hidden.txt')
        for char in ['\n', '\t', '\r', '\x7f', '\u202e', '\u2028']:
            self.file('Pictures/control' + char + '.png')
        target = self.file('outside/unlisted.txt')
        (self.home / 'Downloads' / 'linked.txt').symlink_to(target)
        (self.home / 'Videos').symlink_to(self.home / 'outside', target_is_directory=True)
        (self.home / 'Downloads' / 'linked-directory').symlink_to(
            self.home / 'outside', target_is_directory=True)
        (self.home / 'Downloads' / 'directory.txt').mkdir()
        fifo = self.home / 'Downloads' / 'fifo.txt'
        os.mkfifo(fifo)
        self.file('Desktop/unsupported.exe')
        self.assertEqual(self.helper._candidates(self.home, lambda: False), [str(valid)])

    def test_json_option_budget_accounts_for_escapes_and_unicode(self):
        """Keep escaped and Unicode options within the native serialized argument budget."""
        for index in range(15):
            self.file(f'Downloads/{index:02}-☃-"\\.txt', index)
        self.helper.OPTION_BUDGET = 240
        options = self.helper._candidates(self.home, lambda: False)
        self.assertTrue(options)
        self.assertLess(len(options), 15)
        self.assertLessEqual(len(json.dumps(options, ensure_ascii=True,
                                            separators=(',', ':')).encode()), 240)
        self.assertIn('14-', options[0])
        self.helper.OPTION_BUDGET = 2
        self.assertEqual(self.helper._candidates(self.home, lambda: False), [])

    def test_scan_entry_and_time_limits_and_signal_restoration(self):
        """Bound candidate enumeration and restore the caller signal handler on failure."""
        for index in range(5):
            self.file(f'Downloads/{index}.txt')
        self.helper.MAX_SCAN_ENTRIES = 2
        self.assertLessEqual(len(self.helper._candidates(self.home, lambda: False)), 2)
        self.helper.SCAN_SECONDS = 0
        self.assertEqual(self.helper._candidates(self.home, lambda: False), [])
        previous = signal.getsignal(signal.SIGTERM)
        self.assertEqual(self.helper.choose_recent()['error'], 'recent-files-empty')
        self.assertEqual(signal.getsignal(signal.SIGTERM), previous)

    def test_cancel_during_scan_never_launches_menu(self):
        """Ensure scan cancellation starts no native menu process."""
        self.file()
        previous = signal.getsignal(signal.SIGTERM)

        def cancel(*unused):
            """Deliver SIGTERM while the candidate scan owns the cancellation handler."""
            os.kill(os.getpid(), signal.SIGTERM)
            return []

        with patch.object(self.helper, '_candidates', side_effect=cancel), \
                patch.object(self.helper.subprocess, 'Popen') as popen:
            self.assertEqual(self.helper.choose_recent(), {'state': 'cancelled', 'files': []})
            popen.assert_not_called()
        self.assertEqual(signal.getsignal(signal.SIGTERM), previous)

    def test_source_changed_to_symlink_after_selection_is_rejected(self):
        """Reject a selected candidate replaced by a symlink before inspection."""
        chosen = self.file()
        target = self.file('elsewhere/target.txt')
        self.fake('from pathlib import Path\n'
                  f'p=Path({str(chosen)!r})\np.unlink()\np.symlink_to({str(target)!r})\n'
                  f'print({str(chosen)!r})')
        self.assertEqual(self.helper.choose_recent(),
                         {'state': 'failed', 'error': 'source-path-rejected'})

    def test_timeout_kills_descendants_after_wrapper_exits(self):
        """Terminate a surviving menu descendant when its wrapper exits before timeout."""
        self.file()
        child_pid = self.home / 'child.pid'
        self.fake('import subprocess,sys\nfrom pathlib import Path\n'
                  'child=subprocess.Popen([sys.executable,"-c",'
                  '"import signal,time; signal.signal(signal.SIGTERM,signal.SIG_IGN); time.sleep(30)"])\n'
                  f'Path({str(child_pid)!r}).write_text(str(child.pid))')
        self.helper.MENU_SECONDS = .3
        started = time.monotonic()
        self.assertEqual(self.helper.choose_recent(),
                         {'state': 'failed', 'error': 'recent-files-timeout'})
        self.assertLess(time.monotonic() - started, 2)
        pid = int(child_pid.read_text())
        for _ in range(100):
            status = Path(f'/proc/{pid}/stat')
            if not status.exists() or status.read_text().split()[2] == 'Z':
                break
            time.sleep(.01)
        else:
            self.fail('menu descendant still running after timeout')

    def test_removed_private_tmpdir_blocks_stale_native_owner_result_writes(self):
        """Prevent late native result writes after selection, cancellation and timeout cleanup."""
        chosen = self.file()
        inherited = self.home / 'caller-temp'
        inherited.mkdir()
        receipt = self.home / 'native-owner-path.json'
        for mode in ('selected', 'cancelled', 'timeout'):
            with self.subTest(mode=mode):
                self.fake('import json,os,sys,tempfile,time\nfrom pathlib import Path\n'
                          'fd,name=tempfile.mkstemp(prefix="selection-")\n'
                          'os.write(fd,sys.argv[2].encode());os.close(fd)\n'
                          f'Path({str(receipt)!r}).write_text(json.dumps({{"selection":name,"directory":str(Path(name).parent),"mode":Path(name).parent.stat().st_mode & 0o777}}))\n'
                          + ('print(sys.argv[2])' if mode == 'selected' else
                             'sys.exit(1)' if mode == 'cancelled' else 'time.sleep(30)'))
                self.helper.MENU_SECONDS = .2
                with patch.dict(os.environ, TMPDIR=str(inherited)):
                    result = self.helper.choose_recent()
                self.assertEqual(result['state'], 'failed' if mode == 'timeout' else mode)
                owner = json.loads(receipt.read_text())
                parent = Path(owner['directory'])
                self.assertFalse(parent.exists(), 'wrapper result parent survived cleanup')
                self.assertNotEqual(parent, inherited, 'wrapper inherited a shared temp directory')
                self.assertEqual(owner['mode'], 0o700)
                # Native Menu.finishRequest uses shell redirection after its
                # wrapper has exited. A deleted parent must prevent recreation.
                stale = subprocess.run(['/bin/sh', '-c', 'printf "%s" "$1" > "$2"',
                                        'stale-menu', str(chosen), owner['selection']],
                                       capture_output=True, text=True, timeout=2)
                self.assertNotEqual(stale.returncode, 0)
                self.assertFalse(Path(owner['selection']).exists())
                if mode != 'selected':
                    self.assertNotIn(str(chosen), json.dumps(result))
                self.assertTrue(inherited.is_dir(), 'caller temporary directory was removed')
                self.assertEqual(list(inherited.iterdir()), [], 'candidate paths remained in caller temp files')

    def test_sigterm_cancels_and_reaps_menu(self):
        """Verify external cancellation returns no selection and reaps the owned wrapper."""
        self.file()
        pid_file = self.home / 'menu.pid'
        self.fake('import os,time\nfrom pathlib import Path\n'
                  f'Path({str(pid_file)!r}).write_text(str(os.getpid()))\ntime.sleep(30)')
        # A separate owned process can receive SIGTERM without signalling tests.
        loader = ('import sys,json; sys.path.insert(0,' + repr(str(SCRIPTS)) + '); '
                  'import recent_files as r; r.MENU=' + repr(str(self.menu)) + '; '
                  'print(json.dumps(r.choose_recent()))')
        env = dict(os.environ, HOME=str(self.home))
        process = subprocess.Popen([sys.executable, '-c', loader], env=env,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            for _ in range(200):
                if pid_file.exists():
                    break
                time.sleep(.01)
            self.assertTrue(pid_file.exists(), 'fake menu did not start')
            process.send_signal(signal.SIGTERM)
            stdout, stderr = process.communicate(timeout=3)
            self.assertEqual(process.returncode, 0, stderr)
            self.assertEqual(json.loads(stdout), {'state': 'cancelled', 'files': []})
            self.assertFalse(Path('/proc/' + pid_file.read_text()).exists())
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate()


if __name__ == '__main__':
    unittest.main()
