"""Native daily menu and typed preferences; temporary host API and state only."""
import json
from pathlib import Path
import shutil
import unittest

if __package__:
    from . import test_native_ui as native_ui
else:
    import test_native_ui as native_ui

ROOT = Path(__file__).resolve().parents[1]


class CompactNavigation(unittest.TestCase):
    def configure_fixture(self, fixture, plugin, home, fake_bin):
        # Retain the real bounded settings transport, with a private host double.
        shutil.copyfile(ROOT/'scripts/manage_addresses.py', plugin/'scripts/preference_boundary.py')
        helper=plugin/'scripts/network_preferences.py'
        helper.write_text(helper.read_text().replace('from manage_addresses import', 'from preference_boundary import'))
        (fixture/'preferences.json').write_text('{}')
        fake=fake_bin/'fake'
        fake.write_text(fake.read_text().replace("elif name == 'omarchy-shell': raise SystemExit(0)", '''elif name == 'omarchy-shell':
 state=Path(os.environ['NATIVE_COMMAND_LOG']).with_name('preferences.json')
 values=json.loads(state.read_text()); values[sys.argv[4]]=json.loads(sys.argv[5])
 state.write_text(json.dumps(values)); print('ok')'''))

    def assert_fixture(self, fixture, home, output, calls):
        self.assertIn('COMPACT_NAVIGATION_PASS',output)
        writes=[row['args'] for row in calls if row['tool']=='omarchy-shell']
        self.assertEqual(writes, [['shell','setBarWidget','Omaconnect.plus',key,'true','{}']
            for key in ('navigationAtTop','showSendShortcut','showActivityShortcut')])
        self.assertEqual(json.loads((fixture/'preferences.json').read_text()),
                         dict(navigationAtTop=True,showSendShortcut=True,showActivityShortcut=True))
        self.assertFalse(any(row['tool'] in ('kdeconnect-cli','nmcli','remote-access-mode') for row in calls),calls)
        self.assertEqual(json.loads((fixture/'portal-receipt.json').read_text()),[])

    def test_real_menu_keys_accessibility_and_saved_configuration(self):
        runner=native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture='compact_navigation_ui.qml'
        runner.force_offscreen=True
        runner.configure_fixture=self.configure_fixture
        runner.assert_fixture=self.assert_fixture
        runner.test_actual_service_bar_panel_and_controls()

    def test_fitted_panel_keeps_navigation_and_menu_inside_each_view(self):
        runner=native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture='navigation_geometry_ui.qml'
        runner.force_offscreen=True
        def assert_geometry(fixture,home,output,calls):
            self.assertIn('GEOMETRY_PASS',output)
            self.assertFalse(any(row['tool'] in ('kdeconnect-cli','nmcli','omarchy-shell','remote-access-mode') for row in calls),calls)
            self.assertEqual(json.loads((fixture/'portal-receipt.json').read_text()),[])
        runner.assert_fixture=assert_geometry
        runner.test_actual_service_bar_panel_and_controls()
