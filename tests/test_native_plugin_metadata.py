"""Installed metadata lookup in the existing private native-UI sandbox."""
import json
from pathlib import Path
import unittest

if __package__:
    from . import test_native_ui as native_ui
else:
    import test_native_ui as native_ui


class NativePluginMetadataTests(unittest.TestCase):
    def test_installed_labels_without_device_or_configuration(self):
        if not Path('/usr/lib/qt6/qml/org/kde/kdeconnect/qmldir').is_file():
            self.skipTest('native KDE Connect QML module absent')
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture = 'native_plugin_metadata_ui.qml'
        runner.force_offscreen = True

        def configure(fixture, plugin, home, fake_bin):
            (fixture / 'commands.jsonl').write_text('')

        def assert_metadata(fixture, home, output, calls):
            self.assertIn('NATIVE_PASS plugin metadata', output)
            self.assertEqual(calls, [])
            self.assertEqual(json.loads((fixture / 'portal-receipt.json').read_text()), [])
            self.assertFalse((home / '.config/kdeconnect').exists())

        runner.configure_fixture = configure
        runner.assert_fixture = assert_metadata
        runner.test_actual_service_bar_panel_and_controls()


if __name__ == '__main__':
    unittest.main()
