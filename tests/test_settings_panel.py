"""Independent native settings window, domain navigation and feature search."""
import json
from pathlib import Path
import shutil
import unittest

if __package__:
    from . import test_native_ui as native_ui
else:
    import test_native_ui as native_ui


class SettingsPanelTests(unittest.TestCase):
    def assert_fixture(self, fixture, home, output, calls):
        self.assertIn('SETTINGS_PASS', output, output)
        self.assertTrue(all(row["tool"] == "fc-match" or (row["tool"] == "hyprctl" and row["args"][:2] == ["-j", "getoption"]) for row in calls), calls)
        self.assertEqual(json.loads((fixture/'portal-receipt.json').read_text()), [])
        destination=Path(__file__).resolve().parents[2]/'settings-design-review'
        destination.mkdir(exist_ok=True)
        images=list(fixture.glob('settings-*.png'))
        self.assertEqual(len(images),6)
        for image in images:
            shutil.copyfile(image,destination/image.name)

    def test_native_window_domains_search_and_return_flow(self):
        if not Path('/usr/lib/qt6/qml/QtTest/qmldir').is_file():
            self.skipTest('QtTest QML module absent')
        runner=native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture='settings_panel_ui.qml'
        runner.force_offscreen=True
        runner.assert_fixture=self.assert_fixture
        runner.test_actual_service_bar_panel_and_controls()


if __name__=='__main__':unittest.main()
