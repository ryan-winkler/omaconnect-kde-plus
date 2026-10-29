"""Explicit source identity migration preserves settings without a personal alias."""
import copy
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
        self.assertEqual(row['id'],'Omaconnect.plus')
        self.assertTrue(row['networkBthEnabled'])
        self.assertFalse(row['showBatteryStats'])
        self.assertEqual(row['quickActionsOrder'],'ring,file,text')
        self.assertEqual(row['bthHelperPath'],'/owned/bin/remote-access-mode')
        self.assertEqual(candidate['bar']['layout']['tray'][0],'omaconnect')
        self.assertIsNone(appearance,'Earlier Plus metadata must be reviewed, not replaced by inferred defaults')
        self.assertEqual(M.rollback(candidate,receipt),original)
        self.assertEqual(original,self.source())

    def test_invalid_source_target_conflict_and_unknown_fields_refuse(self):
        for source_id in ('../escape','legacy..plus','omarchy.clock','Omaconnect.plus','x y',''):
            with self.subTest(source_id=source_id),self.assertRaises(M.MigrationError):M.prepare(self.source(),source_id)
        for key,value in [('quickActionsOrder','file,arbitrary-command'),('bthHelperPath','/unsafe/../remote-access-mode'),('networkBthEnabled',1),('unknown_private_key','DO_NOT_COPY')]:
            source=self.source();source['bar']['layout']['tray'][1][key]=value
            with self.subTest(key=key),self.assertRaises(M.MigrationError):M.prepare(source,'legacy.plus')
        source=self.source();source['bar']['layout']['tray'].append('Omaconnect.plus')
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


if __name__=='__main__':unittest.main()
