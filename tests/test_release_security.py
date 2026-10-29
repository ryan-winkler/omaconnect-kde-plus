"""Release regressions use private state and owned fake process groups only."""
import importlib.util
import ctypes
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('release_addresses', ROOT/'scripts/manage_addresses.py')
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)


class ReleaseSecurity(unittest.TestCase):
    def test_fifo_metadata_is_rejected_without_waiting_for_a_writer(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            os.mkfifo(directory/'addresses.json', 0o600)
            code = "import sys;sys.path.insert(0,sys.argv[1]);import manage_addresses as m\ntry:m.load_metadata(__import__('pathlib').Path(sys.argv[2]))\nexcept m.AddressError:print('rejected')\n"
            try:
                result = subprocess.run([sys.executable,'-c',code,str(ROOT/'scripts'),temporary],capture_output=True,text=True,timeout=1)
            except subprocess.TimeoutExpired:
                self.fail('FIFO metadata blocked before the regular-file check')
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertEqual(result.stdout.strip(),'rejected')

    def test_timeout_reaps_the_owned_provider_process_group(self):
        with tempfile.TemporaryDirectory() as temporary:
            pidfile = Path(temporary)/'child.pid'
            code = "import pathlib,subprocess,sys,time\np=subprocess.Popen([sys.executable,'-c','import time;time.sleep(30)'])\npathlib.Path(sys.argv[1]).write_text(str(p.pid))\ntime.sleep(30)"
            child = None
            # Adopt and reap only our fake wrapper's child, including on the red
            # control. This prevents a failed regression from leaving zombies.
            libc = ctypes.CDLL(None)
            previous = ctypes.c_int()
            self.assertEqual(libc.prctl(37, ctypes.byref(previous), 0, 0, 0), 0)
            self.assertEqual(libc.prctl(36, 1, 0, 0, 0), 0)
            try:
                with self.assertRaisesRegex(M.AddressError,'address-timeout'):
                    M.bounded_command([sys.executable,'-c',code,str(pidfile)],time.monotonic()+.3)
                self.assertTrue(pidfile.exists(),'fake child did not start')
                child=int(pidfile.read_text())
                state=Path('/proc')/str(child)/'stat'
                for unused in range(20):
                    if not state.exists() or state.read_text().split()[2]=='Z':break
                    time.sleep(.01)
                self.assertTrue(not state.exists() or state.read_text().split()[2]=='Z','timed-out provider left a live descendant')
            finally:
                if child is None and pidfile.exists():child=int(pidfile.read_text())
                if child is not None:
                    try:os.kill(child,signal.SIGKILL)
                    except ProcessLookupError:pass
                    try:os.waitpid(child,0)
                    except ChildProcessError:pass
                libc.prctl(36, previous.value, 0, 0, 0)


if __name__=='__main__':unittest.main()
