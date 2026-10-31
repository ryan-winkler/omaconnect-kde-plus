"""Explicit source identity migration preserves settings without a personal alias."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
SPEC=importlib.util.spec_from_file_location('identity_migration',ROOT/'scripts/migrate_settings.py')
M=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(M)


class IdentityMigration(unittest.TestCase):
    def source(self):
        return {'bar':{'id':'custom.bar','layout':{'tray':['omaconnect',{'id':'legacy.plus',
            'showBatteryStats':False,'networkBthEnabled':True,'networkWireguardEnabled':False,
            'networkTailscaleEnabled':False,'quickActionsOrder':'ring,file,text',
            'bthHelperPath':'/owned/bin/remote-access-mode','defaultPingMessage':'Hello'}]}},
            'plugins':['unrelated'],'disabledPlugins':['unrelated-disabled']}

    def test_explicit_source_preserves_current_preferences_and_exact_round_trip(self):
        original=self.source();candidate,receipt,appearance=M.prepare(original,'legacy.plus')
        row=candidate['bar']['layout']['tray'][1]
        self.assertEqual(row['id'],'omaconnect.plus')
        self.assertTrue(row['networkBthEnabled'])
        self.assertFalse(row['showBatteryStats'])
        self.assertEqual(row['quickActionsOrder'],'ring,file,text')
        self.assertEqual(row['bthHelperPath'],'/owned/bin/remote-access-mode')
        self.assertEqual(row,dict(original['bar']['layout']['tray'][1],id='omaconnect.plus'))
        self.assertEqual(candidate['bar']['layout']['tray'][0],'omaconnect')
        self.assertIsNone(appearance,'Earlier Plus metadata must be reviewed, not replaced by inferred defaults')
        self.assertEqual(M.rollback(candidate,receipt),original)
        self.assertEqual(original,self.source())

    def uppercase_source(self,disabled=False):
        values={key:bool(index%2) for index,key in enumerate(sorted(M.BOOL_SETTINGS))}
        values.update(defaultPingMessage='Hello\nThere',bthHelperPath='/owned/bin/remote-access-mode',
            quickActionsOrder=','.join(sorted(M.ACTION_IDS,reverse=True)),
            sectionOrder='syncthing,addresses,connections,commands,media,native,drop,actions,devices')
        return {'bar':{'id':'omarchy.bar','layout':{'left':['clock'],
            'tray':['omaconnect',dict(values,id='Omaconnect.plus'),'power']}},
            'plugins':[{'id':'omaconnect','settings':{'upstream_only':'unchanged'}},
                {'id':'Omaconnect.plus','settings':dict(values)}],
            'disabledPlugins':['before']+(['Omaconnect.plus'] if disabled else [])+['after']}

    def test_former_plus_id_preserves_every_understood_setting_and_enabled_state(self):
        for disabled in (False,True):
            with self.subTest(disabled=disabled):
                original=self.uppercase_source(disabled);before=copy.deepcopy(original)
                candidate,receipt,appearance=M.prepare(original,'Omaconnect.plus')
                expected=original['bar']['layout']['tray'][1].copy();expected['id']='omaconnect.plus'
                self.assertEqual(candidate['bar']['layout']['tray'][1],expected)
                self.assertEqual(candidate['plugins'][1],expected)
                self.assertEqual(candidate['bar']['layout']['tray'][::2],['omaconnect','power'])
                self.assertEqual(candidate['plugins'][0],original['plugins'][0])
                self.assertEqual('omaconnect.plus' in candidate['disabledPlugins'],disabled)
                self.assertIn('Omaconnect.plus',candidate['disabledPlugins'])
                self.assertNotIn('omaconnect',candidate['disabledPlugins'])
                self.assertIsNone(appearance)
                self.assertEqual(M.rollback(candidate,receipt),original)
                self.assertEqual(original,before)

    def test_former_plus_drops_retired_information_settings_and_keeps_rollback(self):
        original=self.uppercase_source()
        for row in (original['bar']['layout']['tray'][1],original['plugins'][1]['settings']):
            row.update(showDeviceInformation=False,informationStartExpanded=True,sectionOrder='information,media,devices')
        before=copy.deepcopy(original)
        candidate,receipt,appearance=M.prepare(original,'Omaconnect.plus')
        row=candidate['bar']['layout']['tray'][1]
        self.assertNotIn('showDeviceInformation',row)
        self.assertNotIn('informationStartExpanded',row)
        self.assertEqual(row['sectionOrder'],'media,devices')
        self.assertEqual(M.rollback(candidate,receipt),original)
        self.assertEqual(original,before)

    def test_former_plus_duplicate_ambiguous_unknown_or_target_entries_refuse(self):
        for problem in ('duplicate-bar','duplicate-service','ambiguous-settings','unknown-setting','target-present'):
            source=self.uppercase_source();row=source['bar']['layout']['tray'][1]
            if problem=='duplicate-bar':source['bar']['layout']['left'].append('Omaconnect.plus')
            elif problem=='duplicate-service':source['plugins'].append('Omaconnect.plus')
            elif problem=='ambiguous-settings':row['settings']={'showBatteryStats':True}
            elif problem=='unknown-setting':row['future_private_value']='DO_NOT_COPY'
            else:source['plugins'].append('omaconnect.plus')
            before=copy.deepcopy(source)
            with self.subTest(problem=problem),self.assertRaises(M.MigrationError):M.prepare(source,'Omaconnect.plus')
            self.assertEqual(source,before)

    def test_former_plus_stale_setting_slot_or_enablement_blocks_rollback(self):
        source=self.uppercase_source();candidate,receipt,_=M.prepare(source,'Omaconnect.plus')
        for problem in ('setting','slot','enablement'):
            changed=copy.deepcopy(candidate)
            if problem=='setting':changed['bar']['layout']['tray'][1]['showInlineSend']=not changed['bar']['layout']['tray'][1]['showInlineSend']
            elif problem=='slot':changed['bar']['layout']['tray'].append(changed['bar']['layout']['tray'].pop(1))
            else:changed['disabledPlugins'].append('omaconnect.plus')
            with self.subTest(problem=problem),self.assertRaisesRegex(M.MigrationError,'conflict'):M.rollback(changed,receipt)

    def test_rollback_rejects_reappeared_source_or_uncaptured_target_references(self):
        source=self.uppercase_source();candidate,receipt,_=M.prepare(source,'Omaconnect.plus')
        for problem in ('old-bar','old-service','extra-target-bar','extra-target-service','moved-target-bar','moved-target-service'):
            changed=copy.deepcopy(candidate)
            if problem=='old-bar':changed['bar']['layout']['left'].append('Omaconnect.plus')
            elif problem=='old-service':changed['plugins'].append({'id':'Omaconnect.plus'})
            elif problem=='extra-target-bar':changed['bar']['layout']['left'].append({'id':'omaconnect.plus'})
            elif problem=='extra-target-service':changed['plugins'].append('omaconnect.plus')
            elif problem=='moved-target-bar':changed['bar']['layout']['left'].append(changed['bar']['layout']['tray'].pop(1))
            else:changed['plugins'].append(changed['plugins'].pop(1));changed['plugins'].insert(1,'another')
            before=copy.deepcopy(changed)
            with self.subTest(problem=problem),self.assertRaisesRegex(M.MigrationError,'conflict'):M.rollback(changed,receipt)
            self.assertEqual(changed,before)

    def test_rollback_dual_slots_keep_original_module_and_unrelated_later_edits(self):
        original=self.uppercase_source();candidate,receipt,_=M.prepare(original,'Omaconnect.plus')
        candidate['bar']['layout']['left'].append('another-widget')
        candidate['plugins'].append({'id':'another-service','settings':{'private':'UNCHANGED'}})
        restored=M.rollback(candidate,receipt)
        expected=copy.deepcopy(original)
        expected['bar']['layout']['left'].append('another-widget')
        expected['plugins'].append({'id':'another-service','settings':{'private':'UNCHANGED'}})
        self.assertEqual(restored,expected)

    def disabled_source(self,markers=None):
        source={'bar':{'id':'omarchy.bar','layout':{'tray':['omaconnect','clock']}},
            'plugins':[{'id':'omaconnect','settings':{'upstream_only':'unchanged'}}]}
        if markers is not None:source['disabledPlugins']=list(markers)
        return source

    def test_disabled_former_plus_without_roles_stays_disabled_and_round_trips_exactly(self):
        for markers in (None,[],['before','after'],['before','Omaconnect.plus','after']):
            with self.subTest(markers=markers):
                original=self.disabled_source(markers);before=copy.deepcopy(original)
                candidate,receipt,appearance=M.prepare(original,'Omaconnect.plus')
                expected=copy.deepcopy(original);expected['disabledPlugins']=list(markers or [])+['omaconnect.plus']
                self.assertEqual(candidate,expected)
                self.assertEqual(receipt['entries'],[])
                self.assertIsNone(appearance)
                self.assertEqual(M.rollback(candidate,receipt),original)
                self.assertEqual(original,before)

    def test_empty_roles_are_only_supported_for_explicit_former_plus(self):
        for source_id in ('omaconnect','legacy.plus'):
            with self.subTest(source_id=source_id),self.assertRaises(M.MigrationError):M.prepare({},source_id)
        with self.assertRaises(M.MigrationError):M.prepare({})
        for kind in ('bar','service'):
            source=self.disabled_source()
            if kind=='bar':source['bar']['layout']['tray'].append('omaconnect.plus')
            else:source['plugins'].append('omaconnect.plus')
            with self.subTest(kind=kind),self.assertRaises(M.MigrationError):M.prepare(source,'Omaconnect.plus')

    def test_disabled_former_plus_missing_or_empty_role_containers_round_trip(self):
        for original in ({},{'plugins':[]},{'bar':{'layout':{}}},{'bar':{'layout':{}},'plugins':[]}):
            with self.subTest(original=original):
                candidate,receipt,appearance=M.prepare(original,'Omaconnect.plus')
                self.assertEqual(candidate,dict(original,disabledPlugins=['omaconnect.plus']))
                self.assertEqual(receipt['entries'],[])
                self.assertIsNone(appearance)
                self.assertEqual(M.rollback(candidate,receipt),original)

    def test_disabled_empty_roles_refuse_rollback_after_id_or_flag_changes(self):
        original=self.disabled_source();candidate,receipt,_=M.prepare(original,'Omaconnect.plus')
        for problem in ('new-enabled','old-disabled','old-bar','old-service','new-bar','new-service'):
            changed=copy.deepcopy(candidate)
            if problem=='new-enabled':changed['disabledPlugins'].remove('omaconnect.plus')
            elif problem=='old-disabled':changed['disabledPlugins'].append('Omaconnect.plus')
            elif problem=='old-bar':changed['bar']['layout']['tray'].append('Omaconnect.plus')
            elif problem=='old-service':changed['plugins'].append('Omaconnect.plus')
            elif problem=='new-bar':changed['bar']['layout']['tray'].append('omaconnect.plus')
            else:changed['plugins'].append('omaconnect.plus')
            with self.subTest(problem=problem),self.assertRaisesRegex(M.MigrationError,'conflict'):M.rollback(changed,receipt)

    def test_invalid_source_target_conflict_and_unknown_fields_refuse(self):
        for source_id in ('../escape','legacy..plus','omarchy.clock','omaconnect.plus','x y',''):
            with self.subTest(source_id=source_id),self.assertRaises(M.MigrationError):M.prepare(self.source(),source_id)
        for key,value in [('quickActionsOrder','file,arbitrary-command'),('bthHelperPath','/unsafe/../remote-access-mode'),('networkBthEnabled',1),('unknown_private_key','DO_NOT_COPY')]:
            source=self.source();source['bar']['layout']['tray'][1][key]=value
            with self.subTest(key=key),self.assertRaises(M.MigrationError):M.prepare(source,'legacy.plus')
        source=self.source();source['bar']['layout']['tray'].append('omaconnect.plus')
        with self.assertRaises(M.MigrationError):M.prepare(source,'legacy.plus')

    def test_changed_managed_values_block_rollback_but_unrelated_edits_survive(self):
        source=self.source();candidate,receipt,_=M.prepare(source,'legacy.plus')
        candidate['plugins'].append('another')
        self.assertEqual(M.rollback(candidate,receipt)['plugins'],['unrelated','another'])
        candidate['bar']['layout']['tray'][1]['quickActionsOrder']='file'
        with self.assertRaises(M.MigrationError):M.rollback(candidate,receipt)

    def test_cli_source_id_stages_only_and_does_not_emit_replacement_appearance(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);source=root/'source.json';source.write_text(json.dumps(self.source()))
            before=source.read_bytes();out=root/'review'
            result=subprocess.run([sys.executable,str(ROOT/'scripts/migrate_settings.py'),'prepare',
                '--source',str(source),'--source-id','legacy.plus','--output',str(out)],capture_output=True,text=True,timeout=3)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            self.assertEqual(source.read_bytes(),before)
            self.assertFalse((out/'candidate-appearance.json').exists())
            self.assertEqual(json.loads((out/'snapshot.json').read_text())['old_id'],'legacy.plus')
            self.assertEqual(out.stat().st_mode&0o777,0o700)
            self.assertTrue(all(p.stat().st_mode&0o777==0o600 for p in out.iterdir()))

    def test_cli_former_plus_stages_only_preserves_bindings_and_rolls_back(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);source=root/'source.json';source.write_text(json.dumps(self.uppercase_source()))
            bindings=root/'bindings.conf'
            binding='bind = SUPER, K, exec, omarchy-shell Omaconnect.plus toggle'
            bindings.write_text(binding+'\nbind = SUPER, J, exec, omarchy-shell omaconnect toggle\n')
            before=source.read_bytes();before_bindings=bindings.read_bytes();out=root/'review'
            result=subprocess.run([sys.executable,str(ROOT/'scripts/migrate_settings.py'),'prepare',
                '--source',str(source),'--source-id','Omaconnect.plus','--bindings',str(bindings),'--output',str(out)],capture_output=True,text=True,timeout=3)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            self.assertEqual(set(p.name for p in out.iterdir()),{'candidate-shell.json','snapshot.json'})
            snapshot=json.loads((out/'snapshot.json').read_text())
            self.assertEqual(snapshot['old_id'],'Omaconnect.plus');self.assertEqual(snapshot['new_id'],'omaconnect.plus')
            self.assertEqual(snapshot['bindings'],[dict(path=str(bindings.resolve()),line=1,sha256=hashlib.sha256(binding.encode()).hexdigest(),old_id='Omaconnect.plus',new_id='omaconnect.plus',occurrences=1,action='review-exact-binding')])
            self.assertNotIn(binding,json.dumps(snapshot))
            rollback=root/'rollback'
            result=subprocess.run([sys.executable,str(ROOT/'scripts/migrate_settings.py'),'rollback',
                '--source',str(out/'candidate-shell.json'),'--snapshot',str(out/'snapshot.json'),'--output',str(rollback)],capture_output=True,text=True,timeout=3)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            self.assertEqual(json.loads((rollback/'candidate-shell.json').read_text()),self.uppercase_source())
            self.assertEqual(source.read_bytes(),before);self.assertEqual(bindings.read_bytes(),before_bindings)
            self.assertEqual(out.stat().st_mode&0o777,0o700)
            self.assertTrue(all(p.stat().st_mode&0o777==0o600 for p in out.iterdir()))

    def test_cli_duplicate_json_settings_refuse_without_staging(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);source=root/'source.json'
            source.write_text('{"plugins":[{"id":"Omaconnect.plus","settings":{"showInlineSend":true,"showInlineSend":false}}]}')
            before=source.read_bytes();out=root/'review'
            result=subprocess.run([sys.executable,str(ROOT/'scripts/migrate_settings.py'),'prepare',
                '--source',str(source),'--source-id','Omaconnect.plus','--output',str(out)],capture_output=True,text=True,timeout=3)
            self.assertNotEqual(result.returncode,0)
            self.assertFalse(out.exists());self.assertEqual(source.read_bytes(),before)

    def test_cli_disabled_former_plus_stages_no_roles_settings_or_appearance(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);source=root/'source.json';source.write_text(json.dumps(self.disabled_source()))
            before=source.read_bytes();out=root/'review'
            result=subprocess.run([sys.executable,str(ROOT/'scripts/migrate_settings.py'),'prepare',
                '--source',str(source),'--source-id','Omaconnect.plus','--output',str(out)],capture_output=True,text=True,timeout=3)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            self.assertEqual(set(p.name for p in out.iterdir()),{'candidate-shell.json','snapshot.json'})
            candidate=json.loads((out/'candidate-shell.json').read_text())
            self.assertEqual(candidate['bar'],self.disabled_source()['bar']);self.assertEqual(candidate['plugins'],self.disabled_source()['plugins'])
            self.assertEqual(candidate['disabledPlugins'],['omaconnect.plus'])
            self.assertEqual(json.loads((out/'snapshot.json').read_text())['entries'],[])
            rollback=root/'rollback'
            result=subprocess.run([sys.executable,str(ROOT/'scripts/migrate_settings.py'),'rollback',
                '--source',str(out/'candidate-shell.json'),'--snapshot',str(out/'snapshot.json'),'--output',str(rollback)],capture_output=True,text=True,timeout=3)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            self.assertEqual(json.loads((rollback/'candidate-shell.json').read_text()),self.disabled_source())
            self.assertEqual(source.read_bytes(),before)
            self.assertEqual(out.stat().st_mode&0o777,0o700)
            self.assertTrue(all(p.stat().st_mode&0o777==0o600 for p in out.iterdir()))


if __name__=='__main__':unittest.main()
