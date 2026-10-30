"""Optional app launch contract; no real app is started."""
import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("quickshare", Path(__file__).resolve().parents[1]/"scripts/open_quick_share.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class QuickShare(unittest.TestCase):
    def test_check_missing_and_invalid_never_launch(self):
        with patch.object(module, "available", return_value=False), patch.object(module.subprocess, "Popen") as spawn:
            self.assertEqual(module.main(["--check"]), 1)
            self.assertEqual(module.main(["--open"]), 1)
            self.assertEqual(module.main(["--bad"]), 2)
            spawn.assert_not_called()

    def test_check_launch_and_os_failure(self):
        with patch.object(module, "available", return_value=True), patch.object(module.subprocess, "Popen") as spawn:
            self.assertEqual(module.main(["--check"]), 0)
            spawn.assert_not_called()
            self.assertEqual(module.main(["--open"]), 0)
            spawn.assert_called_once_with([module.PROGRAM], stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            spawn.side_effect = OSError("owned fixture")
            self.assertEqual(module.main(["--open"]), 1)
