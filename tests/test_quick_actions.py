"""Ordered quick-action contracts and native controls, with no provider actions."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import unittest

if __package__:
    from . import test_native_ui as native_ui
else:
    import test_native_ui as native_ui

ROOT=Path(__file__).resolve().parents[1]


class QuickActions(unittest.TestCase):
    @unittest.skipUnless(shutil.which('node'), 'Node model runtime absent')
    def test_actual_catalog_bounds_order_and_capability_filtering(self):
        code=r'''const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const api=vm.createContext({});vm.runInContext(fs.readFileSync(process.argv[1],'utf8').replace(/^\.pragma library\s*/,''),api);
assert.equal(api.DEFAULT_ORDER,'file,text,clipboard');assert.ok(!api.order(api.DEFAULT_ORDER).includes('ring'));
assert.equal(new Set(api.entries.map(row=>row.id)).size,api.entries.length);
assert.equal(api.parse('').length,0);assert.equal(api.parse('ring,file').join(','),'ring,file');
for(const value of [null,{},['ring'],'ring,ring','file,unknown',' ring','file,','ring;id','x'.repeat(513)])assert.equal(api.parse(value),null);
assert.equal(api.order('invalid').join(','),api.DEFAULT_ORDER);
const every=api.entries.map(row=>row.id).join(',');assert.ok(every.length>128 && every.length<=512);assert.equal(api.parse(every).length,api.entries.length);
for(const row of api.entries){assert.ok(row.label && row.description && row.group);assert.ok(row.description.length<200)}
const phone={paired:true,reachable:true,capabilities:{file:true,ring:true},loadedKnown:true,loadedPluginIds:[]};
assert.equal(api.available('ring,text,file,native-features',phone).join(','),'ring,file,native-features');
assert.match(api.availabilityText('ring',phone),/not active locally/);assert.match(api.availabilityText('text',phone),/does not report/);
phone.reachable=false;assert.equal(api.available('file,ring',phone).length,0);assert.match(api.availabilityText('ring',phone),/reachable/);
assert.match(api.availabilityText('file',null),/Choose a device/);
assert.equal(api.available('plus-settings,native-features,file',null).join(','),'plus-settings,native-features');
assert.equal(api.ready('plus-settings',null,null),true);assert.equal(api.ready('native-features',null,null),false);
const service={actionState:'idle',mediaLoading:false,mediaState:{}};
assert.equal(api.ready('native-features',null,service),true);
assert.equal(api.ready('quick-share',null,service),false,'Quick Share needs the installed app');assert.match(api.availabilityText('quick-share',null,service),/Install the r-quick-share/);
service.quickShareAvailable=true;assert.equal(api.ready('quick-share',null,service),true);assert.match(api.availabilityText('quick-share',null,service),/separate app/);
phone.reachable=true;assert.equal(api.compatible('ring',phone),true);assert.equal(api.ready('ring',phone,service),false,'inactive module stays visible but cannot dispatch');
phone.loadedPluginIds=['kdeconnect_findmyphone'];assert.equal(api.ready('ring',phone,service),true);
const media={paired:true,reachable:true,capabilities:{media:true,commands:true},pluginIds:['kdeconnect_mprisremote','kdeconnect_sftp','kdeconnect_systemvolume'],loadedKnown:true,loadedPluginIds:['kdeconnect_mprisremote']};
assert.equal(api.compatible('browse-files',media),true,'new native task can use the reported plugin inventory');
assert.equal(api.ready('browse-files',media,service),true,'native handoff remains available to configure an unloaded module');
assert.equal(api.compatible('native-volume',media),true);assert.equal(api.compatible('native-lock',media),false);
assert.equal(api.ready('media',media,service),true);assert.equal(api.ready('media-next',media,service),false);
assert.match(api.availabilityText('media-next',media,service),/choose a reported player/);
service.mediaState={player:'Owned player'};assert.equal(api.ready('media-next',media,service),true);
service.actionState='running';assert.equal(api.ready('media-next',media,service),false);assert.equal(api.ready('media',media,service),true);assert.equal(api.ready('native-features',null,service),true);
assert.match(api.availabilityText('native-volume',media,service),/native KDE Connect/);
assert.equal(api.entry('unfamiliar_native_plugin'),null,'unknown module IDs are native inventory, never generated commands');
const monitor={paired:true,reachable:true,pluginIds:['kdeconnect_virtualmonitor'],loadedKnown:true,loadedPluginIds:['kdeconnect_virtualmonitor'],virtualMonitor:{known:true,active:false,available:true}};
service.actionState='idle';assert.equal(api.ready('external-monitor',monitor,service),true);
monitor.virtualMonitor.active=true;monitor.virtualMonitor.available=false;assert.equal(api.ready('external-monitor',monitor,service),true);assert.equal(api.actionLabel('external-monitor',monitor),'Stop virtual monitor session');
monitor.virtualMonitor.known=false;assert.equal(api.ready('external-monitor',monitor,service),false);assert.match(api.availabilityText('external-monitor',monitor,service),/state is unavailable/);
'''
        result=subprocess.run([shutil.which('node'),'-e',code,str(ROOT/'ActionCatalog.js')],text=True,capture_output=True,timeout=5)
        self.assertEqual(result.returncode,0,result.stderr)

    @unittest.skipUnless(shutil.which('node'), 'Node model runtime absent')
    def test_catalog_matches_native_preference_allowlist_and_manifest(self):
        result=subprocess.run([shutil.which('node'),'-e',"const fs=require('fs'),vm=require('vm');let c={};vm.createContext(c);vm.runInContext(fs.readFileSync(process.argv[1],'utf8').replace(/^\\.pragma library\\s*/,''),c);console.log(JSON.stringify({ids:c.entries.map(x=>x.id),defaultOrder:c.DEFAULT_ORDER}));",str(ROOT/'ActionCatalog.js')],text=True,capture_output=True,check=True)
        catalog=json.loads(result.stdout)
        scripts=ROOT/'scripts';sys.path.insert(0,str(scripts))
        try:
            import network_preferences as helper
        finally:
            sys.path.pop(0)
        manifest=json.loads((ROOT/'manifest.json').read_text())
        self.assertEqual(set(catalog['ids']),helper.ACTION_IDS)
        self.assertEqual(catalog['defaultOrder'],manifest['settings']['quickActionsOrder']['default'])
        self.assertEqual(manifest['id'],'Omaconnect.plus')
        self.assertNotEqual(manifest['id'],'omaconnect')

    def configure_fixture(self,fixture,plugin,home,fake_bin):
        shutil.copyfile(ROOT/'scripts/manage_addresses.py',plugin/'scripts/quick_action_boundary.py')
        helper=plugin/'scripts/network_preferences.py'
        helper.write_text(helper.read_text().replace('from manage_addresses import','from quick_action_boundary import'))
        fake=fake_bin/'fake'
        fake.write_text(fake.read_text().replace("elif name == 'omarchy-shell': raise SystemExit(0)","elif name == 'omarchy-shell': print('unknown' if any('file,clipboard' == a.strip(chr(34)) for a in sys.argv) else 'ok')"))

    def assert_fixture(self,fixture,home,output,calls):
        self.assertIn('QUICK_ACTIONS_PASS',output,output)
        writes=[row['args'] for row in calls if row['tool']=='omarchy-shell']
        self.assertEqual([json.loads(row[-2]) for row in writes],['file,text,clipboard,ring','file,text,ring,clipboard','file,text,clipboard','file,clipboard'])
        self.assertTrue(all(row[:4]==['shell','setBarWidget','Omaconnect.plus','quickActionsOrder'] and row[-1]=='{}' for row in writes))
        self.assertFalse(any(row['tool'] in ('kdeconnect-cli','nmcli','remote-access-mode') for row in calls),calls)
        self.assertEqual(json.loads((fixture/'portal-receipt.json').read_text()),[])

    def test_native_add_remove_reorder_and_failed_save(self):
        runner=native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture='quick_actions_ui.qml';runner.force_offscreen=True
        runner.configure_fixture=self.configure_fixture;runner.assert_fixture=self.assert_fixture
        runner.test_actual_service_bar_panel_and_controls()


if __name__=='__main__':unittest.main()
