"""Native configuration migration round trips; owned dictionaries only."""
import copy
import importlib.util
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
SPEC=importlib.util.spec_from_file_location('release_migration',ROOT/'scripts/migrate_settings.py')
M=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(M)


class ReleaseMigration(unittest.TestCase):
    def config(self,entry):
        return {'bar':{'layout':{'tray':['other',entry]}},'plugins':[], 'disabledPlugins':['unrelated']}

    def test_real_native_inline_configuration_emits_native_inline_and_round_trips(self):
        source=self.config({'id':M.OLD,'showDeviceTypeIcons':False,'showTailscale':False,'showActionRing':False,'showActionPing':True,'showBatteryStats':False})
        original=copy.deepcopy(source)
        result,receipt,appearance=M.prepare(source)
        entry=result['bar']['layout']['tray'][1]
        self.assertNotIn('settings',entry)
        self.assertFalse(entry['showBatteryStats'])
        self.assertEqual(entry['quickActionsOrder'],'clipboard,file,sms,ping,text')
        self.assertEqual(appearance['bar_icon']['value'],'phone')
        self.assertEqual(M.rollback(result,receipt),original)
        self.assertEqual(source,original)

    def test_legacy_nested_strings_and_empty_shapes_restore_exactly(self):
        for entry in (M.OLD,{'id':M.OLD},{'id':M.OLD,'settings':{}},{'id':M.OLD,'settings':{'showActionFile':False,'showDeviceTypeIcons':True}}):
            with self.subTest(entry=entry):
                source=self.config(entry);result,receipt,_=M.prepare(source)
                self.assertNotIn('settings',result['bar']['layout']['tray'][1])
                self.assertEqual(M.rollback(result,receipt),source)

    def test_ambiguous_or_unknown_source_shapes_are_not_guessed(self):
        for entry in ({'id':M.OLD,'settings':{'showActionRing':True},'showActionRing':True}, {'id':M.OLD,'private_token':'DO_NOT_COPY'}, {'id':M.OLD,'showActionRing':1}):
            with self.subTest(entry=entry):
                with self.assertRaises(M.MigrationError):M.prepare(self.config(entry))

    def test_rollback_preserves_new_values_but_refuses_modified_managed_values(self):
        source=self.config({'id':M.OLD,'showBatteryStats':False})
        result,receipt,_=M.prepare(source)
        result['bar']['layout']['tray'][1]['later_fork_setting']='keep'
        result['plugins'].append({'id':'later-unrelated'})
        restored=M.rollback(result,receipt)
        self.assertEqual(restored['bar']['layout']['tray'][1]['later_fork_setting'],'keep')
        self.assertEqual(restored['plugins'],result['plugins'])
        result['bar']['layout']['tray'][1]['showBatteryStats']=True
        with self.assertRaisesRegex(M.MigrationError,'conflict'):M.rollback(result,receipt)

    def test_existing_disabled_flags_restore_their_original_order(self):
        for disabled in ([M.OLD,'unrelated'],[M.NEW,'unrelated'],[M.NEW,'unrelated',M.OLD]):
            with self.subTest(disabled=disabled):
                source=self.config({'id':M.OLD});source['disabledPlugins']=disabled
                result,receipt,_=M.prepare(source)
                self.assertEqual(M.rollback(result,receipt),source)

    def test_previously_staged_nested_snapshot_remains_rollback_compatible(self):
        source=self.config({'id':M.OLD,'settings':{'showBatteryStats':False}})
        result,receipt,_=M.prepare(source)
        row=receipt['entries'][0]
        row.pop('source_shape');row.pop('target_shape')
        current=result['bar']['layout']['tray'][1]
        result['bar']['layout']['tray'][1]={'id':M.NEW,'settings':{k:v for k,v in current.items() if k!='id'}}
        self.assertEqual(M.rollback(result,receipt),source)


if __name__=='__main__':unittest.main()
