import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).parents[1]
SPEC = importlib.util.spec_from_file_location("migration", ROOT / "scripts/migrate_settings.py")
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)


class Migration(unittest.TestCase):
    def source(self, bar="omarchy.bar"):
        return {"bar": {"id":bar,"layout":{"left":["clock"],"right":["tray", {"id":"omaconnect","settings":{"showDeviceTypeIcons":True,"showTailscale":True,"showBatteryStats":False,"defaultPingMessage":"Hello"}}, "power"]}}, "plugins":[{"id":"other","settings":{"private":"DO_NOT_SNAPSHOT"}}], "disabledPlugins":["unrelated"]}

    def test_native_and_replacement_bar_keep_the_exact_slot(self):
        for bar in ("omarchy.bar", "ryan.bar"):
            original = self.source(bar)
            before = copy.deepcopy(original)
            result, snapshot, appearance = M.prepare(original)
            self.assertEqual(original, before)
            entry = result["bar"]["layout"]["right"][1]
            self.assertEqual(entry["id"], "ryan.omaconnect")
            self.assertEqual(result["bar"]["id"], bar)
            self.assertEqual(result["bar"]["layout"]["right"][::2], ["tray", "power"])
            self.assertFalse(entry["showTailscale"])
            self.assertFalse(entry["showTroubleshooting"])
            self.assertEqual(appearance["bar_icon"]["mode"], "automatic")
            self.assertNotIn("DO_NOT_SNAPSHOT", json.dumps(snapshot))
            self.assertEqual(M.rollback(result, snapshot), original)

    def test_absent_legacy_icon_preserves_upstream_automatic_default(self):
        original = self.source()
        original["bar"]["layout"]["right"][1] = "omaconnect"
        candidate, receipt, appearance = M.prepare(original)
        self.assertEqual(appearance["bar_icon"]["mode"], "automatic")
        self.assertEqual(M.rollback(candidate, receipt), original)

    def test_native_tray_section_is_migrated_and_restored(self):
        original = self.source()
        entry = original["bar"]["layout"]["right"].pop(1)
        original["bar"]["layout"]["tray"] = ["other", entry]
        candidate, snapshot, _ = M.prepare(original)
        self.assertEqual(candidate["bar"]["layout"]["tray"][1]["id"], "ryan.omaconnect")
        self.assertEqual(M.rollback(candidate, snapshot), original)

    def test_dual_bar_and_service_settings_migrate_without_two_active_ids(self):
        original = self.source()
        original["plugins"].append({"id":"omaconnect","settings":{"showBarBattery":True}})
        candidate, snapshot, _appearance = M.prepare(original)
        self.assertEqual(candidate["plugins"][-1]["id"], "ryan.omaconnect")
        self.assertIn("omaconnect", candidate["disabledPlugins"])
        self.assertNotIn("ryan.omaconnect", candidate["disabledPlugins"])
        self.assertEqual(M.rollback(candidate, snapshot), original)

    def test_rollback_preserves_unrelated_later_changes_and_rejects_conflict(self):
        original = self.source()
        candidate, snapshot, _ = M.prepare(original)
        candidate["plugins"][0]["settings"]["later"] = True
        candidate["bar"]["layout"]["left"].append("new-widget")
        candidate["bar"]["layout"]["right"][1]["later_fork_setting"] = True
        result = M.rollback(candidate, snapshot)
        self.assertTrue(result["plugins"][0]["settings"]["later"])
        self.assertIn("new-widget", result["bar"]["layout"]["left"])
        self.assertTrue(result["bar"]["layout"]["right"][1]["settings"]["later_fork_setting"])
        candidate["bar"]["layout"]["right"][1]["showBatteryStats"] = True
        with self.assertRaisesRegex(M.MigrationError, "conflict"):
            M.rollback(candidate, snapshot)

    def test_unknown_old_settings_or_duplicate_slots_require_review(self):
        original = self.source()
        original["bar"]["layout"]["right"][1]["settings"]["api_key"] = "DO_NOT_COPY"
        with self.assertRaises(M.MigrationError):
            M.prepare(original)
        original = self.source()
        original["bar"]["layout"]["left"].append("omaconnect")
        with self.assertRaises(M.MigrationError):
            M.prepare(original)

    def test_cli_stages_private_artifacts_and_never_modifies_source(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "shell.json"
            source.write_text(json.dumps(self.source()))
            before = source.read_bytes()
            bindings = root / "bindings.conf"
            bindings.write_text('bind = SUPER, K, exec, omarchy-shell omaconnect toggle\n# DO_NOT_SNAPSHOT\n')
            target = root / "stage"
            run = subprocess.run([sys.executable, str(ROOT / "scripts/migrate_settings.py"), "prepare", "--source", str(source), "--output", str(target), "--bindings", str(bindings)], capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertEqual(source.read_bytes(), before)
            self.assertEqual(target.stat().st_mode & 0o777, 0o700)
            for path in target.iterdir():
                self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            snapshot = json.loads((target / "snapshot.json").read_text())
            self.assertEqual(snapshot["bindings"][0]["line"], 1)
            self.assertNotIn("omarchy-shell", json.dumps(snapshot))
            self.assertNotIn("DO_NOT_SNAPSHOT", json.dumps(snapshot))
            run = subprocess.run([sys.executable, str(ROOT / "scripts/migrate_settings.py"), "prepare", "--source", str(source), "--output", str(target)], capture_output=True, text=True)
            self.assertNotEqual(run.returncode, 0)


if __name__ == "__main__":
    unittest.main()
