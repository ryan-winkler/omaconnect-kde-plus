"""Actual local-note component with a fake store/service; no provider action."""
import os
from pathlib import Path
import shutil
import signal
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SHELL = Path('/usr/share/omarchy/shell')


class SyncthingNote(unittest.TestCase):
    @unittest.skipUnless(shutil.which('quickshell') and shutil.which('dbus-run-session')
                         and (SHELL/'Ui').is_dir(), 'native runtime absent')
    def test_device_draft_save_remove_readback_and_generic_owner(self):
        with tempfile.TemporaryDirectory(prefix='omaconnect-syncthing-note-') as temporary:
            fixture = Path(temporary)
            for name in ('Commons', 'Ui'):
                (fixture/name).symlink_to(SHELL/name)
            (fixture/'components').symlink_to(ROOT/'components')
            (fixture/'runtime').mkdir(mode=0o700)
            shutil.copyfile(ROOT/'tests/syncthing_note_ui.qml', fixture/'shell.qml')
            env = {'PATH':'/usr/bin', 'HOME':temporary, 'XDG_CONFIG_HOME':temporary+'/config',
                   'XDG_DATA_HOME':temporary+'/data', 'XDG_CACHE_HOME':temporary+'/cache',
                   'XDG_RUNTIME_DIR':temporary+'/runtime', 'QT_QPA_PLATFORM':'offscreen',
                   'QT_QUICK_BACKEND':'software', 'LANG':'C.UTF-8',
                   'DBUS_SYSTEM_BUS_ADDRESS':'unix:path='+temporary+'/no-system-bus'}
            process = subprocess.Popen(['/usr/bin/dbus-run-session','--','/usr/bin/quickshell',
                                        '--no-color','-p',temporary], env=env, text=True,
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
            try:
                output, error = process.communicate(timeout=8)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                output, error = process.communicate()
                self.fail('Native note fixture timed out: '+output+error)
            output += error
            self.assertEqual(process.returncode, 0, output)
            self.assertIn('SYNCTHING_NOTE_PASS', output, output)
            for error in ('SYNCTHING_NOTE_FAIL', 'TypeError:', 'ReferenceError:', 'Error loading configuration'):
                self.assertNotIn(error, output, output)


if __name__ == '__main__':
    unittest.main()
