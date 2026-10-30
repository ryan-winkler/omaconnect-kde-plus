"""Minimum-size Settings navigation at native18 and spacing1.5; fake state only."""
import json
import unittest

if __package__:
    from . import test_native_ui as native_ui
else:
    import test_native_ui as native_ui


class SettingsNavigationLayoutTests(unittest.TestCase):
    def test_scaled_sidebar_routes_remain_visible_and_keyboard_operable(self):
        runner=native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture='settings_navigation_layout_ui.qml'
        runner.force_offscreen=True

        def configure(fixture,plugin,home,fake_bin):
            theme=home/'.local/state/omarchy/current/theme'
            theme.mkdir(parents=True)
            (theme/'colors.toml').write_text('foreground = "#eeeeee"\nbackground = "#141414"\naccent = "#80ee99"\n')
            (theme/'shell.toml').write_text('[font]\nbase-size = 18\n[spacing]\nscale = 1.5\nscale-with-font = false\n')

        def checked(fixture,home,output,calls):
            marker='SETTINGS_NAVIGATION_LAYOUT_PASS '
            measurements=json.loads(next(line.split(marker,1)[1] for line in output.splitlines() if marker in line))
            self.assertEqual([row['route'] for row in measurements],['Appearance','Connections','Quick actions','Device features','Device features','Quick actions','Connections','Appearance'])
            self.assertEqual([row['direction'] for row in measurements],[1,1,1,1,-1,-1,-1,-1])
            self.assertTrue(all(row['font']==18 and row['height']>=44 and row['truncated'] is False for row in measurements))
            self.assertTrue(all(row['y']>=-1 and row['y']+row['height']<=row['viewport']+1 and row['sidebarBottom']<=row['backTop']+1 for row in measurements))
            self.assertTrue(all(row['tool']=='fc-match' or (row['tool']=='hyprctl' and row['args'][:2]==['-j','getoption']) for row in calls),calls)
            self.assertEqual(json.loads((fixture/'portal-receipt.json').read_text()),[])
            self.assertFalse((home/'.config/kdeconnect').exists())

        runner.configure_fixture=configure
        runner.assert_fixture=checked
        runner.test_actual_service_bar_panel_and_controls()


if __name__=='__main__':unittest.main()
