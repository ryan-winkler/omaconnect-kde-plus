"""Actual Panel ObjectModel movement and state boundaries; private fake host only."""
import json
from pathlib import Path
import shutil
import unittest
from unittest.mock import patch

if __package__:
    from . import test_native_ui as native_ui
else:
    import test_native_ui as native_ui

ROOT=Path(__file__).resolve().parents[1]


class SectionComposition(unittest.TestCase):
    def run_composition(self,catalogue_failure=None):
        runner=native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture='section_composition_ui.qml'
        runner.force_offscreen=True
        def configure(fixture,plugin,home,fake_bin):
            shutil.copyfile(ROOT/'scripts/manage_addresses.py',plugin/'scripts/composition_preference_boundary.py')
            helper=plugin/'scripts/network_preferences.py'
            helper.write_text(helper.read_text().replace('from manage_addresses import','from composition_preference_boundary import'))
            state=dict(sectionOrder='',networkBthEnabled=True,networkStartExpanded=False,
                       addressesStartExpanded=True,showSyncthingLinks=False,syncthingStartExpanded=False)
            if catalogue_failure:
                state.update(fixtureCatalogFailure=catalogue_failure,showSyncthingLinks=False,syncthingStartExpanded=True)
                catalogue=plugin/'PanelSections.json'
                if catalogue_failure=='malformed':
                    catalogue.write_text('invalid json')
                else:
                    entries=json.loads(catalogue.read_text())
                    catalogue.write_text(json.dumps([entry for entry in entries if entry['id']!='syncthing']))
            (fixture/'composition-settings.json').write_text(json.dumps(state))
            metadata=home/'.config/Omaconnect.plus';metadata.mkdir(parents=True,mode=0o700)
            appearance=metadata/'appearance.json'
            appearance.write_text(json.dumps(dict(schema_version=1,bar_icon=dict(mode='preset',value='phone',render='symbolic'),
                devices={'kdeconnect:A':dict(alias='',icon=dict(mode='inherit'),syncthing_device_id='-'.join(['AAAAAAA']*8))})))
            appearance.chmod(0o600)
            fake=fake_bin/'fake'
            fake.write_text(fake.read_text().replace("elif name == 'omarchy-shell': raise SystemExit(0)",'''elif name == 'omarchy-shell':
 state=Path(os.environ['NATIVE_COMMAND_LOG']).with_name('composition-settings.json')
 values=json.loads(state.read_text());values[sys.argv[4]]=json.loads(sys.argv[5])
 pending=state.with_suffix('.next');pending.write_text(json.dumps(values));pending.replace(state);print('ok')'''))
            (plugin/'scripts/open_quick_share.py').write_text('import sys,time\nif sys.argv[1:] == ["--check"]: raise SystemExit(0)\nif sys.argv[1:] != ["--open"]: raise SystemExit(99)\ntime.sleep(.5)\n')
            (plugin/'scripts/open_app.sh').write_text("#!/bin/bash\nexec /usr/bin/python3 -c 'import time; time.sleep(.5)'\n")
            (fake_bin/'busctl').symlink_to(fake)
            (fake_bin/'syncthing').symlink_to(fake)
        def checked(fixture,home,output,calls):
            self.assertIn('COLD_CATALOG_PASS' if catalogue_failure else 'SECTION_COMPOSITION_PASS',output)
            writes=[row['args'] for row in calls if row['tool']=='omarchy-shell']
            if catalogue_failure:
                self.assertEqual(writes,[],writes)
            else:
                self.assertEqual(len(writes),3,writes)
                self.assertTrue(all(row[:4]==['shell','setBarWidget','Omaconnect.plus','sectionOrder'] and row[-1]=='{}' for row in writes),writes)
                self.assertEqual(json.loads(writes[0][-2]).split(',')[:3],['devices','drop','actions'])
                self.assertEqual(json.loads(writes[1][-2]).split(',')[:3],['devices','actions','drop'])
                self.assertEqual(json.loads(writes[2][-2]).split(',')[-2:],['syncthing','addresses'])
            self.assertFalse(any(row['tool'] in ('kdeconnect-cli','nmcli','remote-access-mode','syncthing') for row in calls),calls)
            self.assertEqual(json.loads((fixture/'portal-receipt.json').read_text()),[])
            self.assertEqual((fixture/'one').read_bytes(),b'abc')
        original_run=native_ui.subprocess.run
        def isolated_run(command,*args,**kwargs):
            if command and command[0]=='/usr/bin/bwrap':
                command=list(command);fixture=Path(command[command.index('--chdir')+1]);at=command.index('/usr/bin/dbus-run-session')
                for name in ('busctl','syncthing'):
                    if Path('/usr/bin',name).exists():command[at:at]=['--ro-bind',str(fixture/'bin/fake'),'/usr/bin/'+name]
            return original_run(command,*args,**kwargs)
        runner.configure_fixture=configure;runner.assert_fixture=checked
        with patch.object(native_ui.subprocess,'run',side_effect=isolated_run):
            runner.test_actual_service_bar_panel_and_controls()

    def test_actual_panel_order_identity_drafts_and_drop_reveal(self):
        self.run_composition()

    def test_malformed_catalog_keeps_hidden_provider_stopped_and_navigation_usable(self):
        self.run_composition('malformed')

    def test_missing_optional_catalog_entry_keeps_hidden_provider_stopped(self):
        self.run_composition('missing-syncthing')
