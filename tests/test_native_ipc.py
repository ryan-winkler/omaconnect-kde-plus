"""Use the installed native registry on a private bus, without a live shell."""
import unittest

if __package__:
    from . import test_native_ui as native_ui
else:
    import test_native_ui as native_ui


class NativeIpc(unittest.TestCase):
    def test_direct_dispatch_preserves_lifecycle_and_exactly_once_semantics(self):
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture = 'native_ipc_ui.qml'
        runner.force_offscreen = True

        def inspect(fixture, home, output, calls):
            self.assertIn('NATIVE_PASS direct IPC lifecycle', output)
            self.assertEqual(calls, [])
            self.assertEqual((fixture / 'portal-receipt.json').read_text(), '[]')

        runner.configure_fixture = lambda fixture, plugin, home, fake_bin: (fixture / 'commands.jsonl').write_text('')
        runner.assert_fixture = inspect
        runner.test_actual_service_bar_panel_and_controls()


if __name__ == '__main__':
    unittest.main()
