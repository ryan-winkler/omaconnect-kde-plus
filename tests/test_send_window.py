"""Persistent normal Send window uses the same service; no host actions."""
import json
import unittest

if __package__:
    from . import test_native_ui as native_ui
else:
    import test_native_ui as native_ui


class SendWindow(unittest.TestCase):
    def configure_fixture(self, fixture, plugin, home, fake_bin):
        (fixture/'commands.jsonl').write_text('')

    def assert_fixture(self, fixture, home, output, calls):
        self.assertIn('SEND_WINDOW_PASS',output,output)
        self.assertTrue(all(row['tool'] in ('fc-match','hyprctl') for row in calls),calls)
        self.assertEqual(json.loads((fixture/'portal-receipt.json').read_text()),[])

    def test_native_persistent_send_window_preserves_draft_and_copy_only_drop(self):
        runner=native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture='send_window_ui.qml';runner.force_offscreen=True
        runner.configure_fixture=self.configure_fixture;runner.assert_fixture=self.assert_fixture
        runner.test_actual_service_bar_panel_and_controls()


if __name__=='__main__':unittest.main()
