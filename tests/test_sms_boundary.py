"""SMS launcher argument contract; owned fake backend only, never native SMS."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
BASH = shutil.which('bash')


class SmsBoundary(unittest.TestCase):
    def launch(self, arguments, installed=True):
        with tempfile.TemporaryDirectory(prefix='omaconnect-sms-') as temporary:
            directory = Path(temporary)
            receipt = directory/'argv.json'
            (directory/'nohup').write_text('#!/bin/bash\nexec "$@"\n')
            (directory/'nohup').chmod(0o700)
            if installed:
                backend = directory/'kdeconnect-sms'
                backend.write_text('#!'+sys.executable+'\n'
                                   'import json,os,sys\n'
                                   'from pathlib import Path\n'
                                   'path=Path(os.environ["SMS_FIXTURE_RECEIPT"])\n'
                                   'pending=path.with_suffix(".tmp")\n'
                                   'pending.write_text(json.dumps(sys.argv[1:]))\n'
                                   'os.replace(pending,path)\n')
                backend.chmod(0o700)
            result = subprocess.run([BASH, str(ROOT/'scripts/open_sms.sh'), *arguments],
                                    env={**os.environ, 'PATH':temporary,
                                         'SMS_FIXTURE_RECEIPT':str(receipt)},
                                    text=True, capture_output=True, timeout=3)
            if result.returncode == 0:
                deadline = time.monotonic()+1
                while not receipt.exists() and time.monotonic() < deadline:
                    time.sleep(.01)
            # The fake child publishes a receipt only after finishing its write.
            calls = json.loads(receipt.read_text()) if receipt.exists() else None
            self.assertEqual(result.stdout+result.stderr, '')
            return result.returncode, calls

    def test_generic_and_bounded_device_launches_keep_exact_arguments(self):
        self.assertEqual(self.launch([]), (0, []))
        self.assertEqual(self.launch(['']), (0, []))
        for device in ('owned_peer-123.abc', '_owned_peer', 'A'*128):
            with self.subTest(device=device):
                self.assertEqual(self.launch([device]), (0, ['--device', device]))

    def test_invalid_ids_and_extra_arguments_never_reach_backend(self):
        cases = (['--help'], ['-owned'], ['.owned'], ['../owned'], ['owned/peer'],
                 ['owned peer'], ['owned\tpeer'], ['owned\npeer'], ['owned;command'],
                 ['$(owned-command)'], ['A'*129], ['owned', 'extra'], ['', 'extra'])
        for arguments in cases:
            with self.subTest(arguments=arguments):
                self.assertEqual(self.launch(arguments), (2, None))

    def test_missing_binary_keeps_exit_127_for_valid_requests(self):
        self.assertEqual(self.launch([], installed=False), (127, None))
        self.assertEqual(self.launch(['owned-peer'], installed=False), (127, None))


if __name__ == '__main__':
    unittest.main()
