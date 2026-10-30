"""Installed icon browsing uses virtualized real previews and draft-only actions."""
import json
from pathlib import Path
import unittest

if __package__:
    from . import test_native_ui as native_ui
    from .test_appearance_rendering import rgba_pixels
else:
    import test_native_ui as native_ui
    from test_appearance_rendering import rgba_pixels


class InstalledIconPickerTests(unittest.TestCase):
    def test_native_search_selection_bounds_and_visible_pixel_shapes(self):
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture = 'installed_icon_picker_ui.qml'
        runner.force_offscreen = True

        def configure(fixture, plugin, home, fake_bin):
            (fixture/'commands.jsonl').write_text('')
            assets = fixture/'icons'
            assets.mkdir()
            (assets/'even.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><path d="M3 3h18v13H3zM8 21h8" fill="none" stroke="black" stroke-width="2"/></svg>')
            (assets/'odd.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><circle cx="12" cy="12" r="8" fill="none" stroke="black" stroke-width="2"/></svg>')
            # Only the fixture's Qt theme lookup is substituted. The production
            # AppearanceIcon renderer and its pixel output stay under test.
            icon = plugin/'components/AppearanceIcon.qml'
            original = 'Quickshell.iconPath(Appearance.themeFor(normalized),true)'
            replacement = 'Qt.resolvedUrl("../../icons/" + (Number(normalized.value.slice(-1)) % 2 ? "odd.svg" : "even.svg")).toString()'
            source = icon.read_text()
            self.assertIn(original, source)
            icon.write_text(source.replace(original, replacement))

        def assert_picker(fixture, home, output, calls):
            self.assertEqual(json.loads((fixture/'portal-receipt.json').read_text()), [])
            self.assertTrue(all(call['tool']=='fc-match' or (call['tool']=='hyprctl' and call['args'][:2]==['-j','getoption']) for call in calls), calls)
            masks = []
            for index in (0, 1):
                pixels = rgba_pixels(fixture/('picker-icon-'+str(index)+'.png'))
                mask = [pixel[3] for pixel in pixels]
                self.assertGreater(sum(alpha>0 for alpha in mask), 20)
                self.assertLess(sum(alpha>0 for alpha in mask), len(mask)*.8)
                masks.append(mask)
            self.assertNotEqual(masks[0], masks[1], 'visible installed thumbnails must have distinct silhouettes')
            self.assertFalse((home/'.config/Omaconnect.plus').exists())

        runner.configure_fixture = configure
        runner.assert_fixture = assert_picker
        runner.test_actual_service_bar_panel_and_controls()


if __name__ == '__main__':
    unittest.main()
