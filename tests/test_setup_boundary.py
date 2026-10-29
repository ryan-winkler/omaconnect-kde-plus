"""Inherited setup entrypoints must not execute privilege tools from this UI fork."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SetupBoundary(unittest.TestCase):
    def test_inherited_setup_paths_cannot_run_privilege_tools_without_a_terminal(self):
        for name in ('install_dependencies.sh', 'setup_firewall.sh'):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temporary:
                directory=Path(temporary)
                log=directory/'calls.jsonl'
                fake=directory/'sudo'
                fake.write_text('#!/usr/bin/python3\nimport json,os,sys\nwith open(os.environ["SETUP_TEST_CALLS"],"a") as f:f.write(json.dumps(sys.argv[1:])+"\\n")\n')
                fake.chmod(0o700)
                for command in ('ufw','sleep'):
                    p=directory/command;p.write_text('#!/bin/sh\nexit 0\n');p.chmod(0o700)
                script=ROOT/'scripts'/name
                if script.exists():
                    result=subprocess.run(['/usr/bin/bash',str(script)],stdin=subprocess.DEVNULL,
                        capture_output=True,text=True,timeout=3,
                        env={'PATH':str(directory)+':/usr/bin:/bin','HOME':temporary,'SETUP_TEST_CALLS':str(log)})
                    self.assertIn(result.returncode,(0,1))
                calls=[json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
                self.assertEqual(calls,[], 'UI fork must leave package/firewall changes to explicit native setup')


if __name__=='__main__':unittest.main()
