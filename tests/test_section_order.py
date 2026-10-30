"""One shipped catalogue drives native section ordering and Python validation."""
import copy
import json
from pathlib import Path
import shutil
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
try:
    import section_order as sections
    import network_preferences as preferences
    import migrate_settings as migration
finally:
    sys.path.pop(0)

if __package__:
    from . import test_native_ui as native_ui
else:
    import test_native_ui as native_ui


class SectionOrderTests(unittest.TestCase):
    def test_canonical_ids_flags_and_native_manifest_match(self):
        self.assertEqual(sections.IDS, ('devices', 'actions', 'drop', 'native', 'information', 'media', 'commands', 'connections', 'addresses', 'syncthing'))
        self.assertNotIn('visibilityKey', sections.CATALOG[0])
        manifest = json.loads((ROOT / 'manifest.json').read_text())['settings']
        self.assertEqual(manifest['sectionOrder']['default'], '')
        for key, default in sections.BOOL_DEFAULTS.items():
            self.assertEqual(manifest[key]['type'], 'boolean')
            self.assertIs(manifest[key]['default'], default)
            self.assertIn(key, preferences.KEYS)
            self.assertIn(key, migration.BOOL_SETTINGS)
            for value in (True, False):
                self.assertIs(preferences.setting_value({'key': key, 'enabled': value}), value)
            for value in (0, 1, 'true', None):
                with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                    preferences.setting_value({'key': key, 'enabled': value})

    def test_order_validation_is_shared_by_saves_and_migration(self):
        self.assertEqual(sections.order_ids(''), list(sections.IDS))
        expected = ['syncthing'] + list(sections.IDS[:-1])
        self.assertEqual(sections.order_ids('syncthing'), expected)
        self.assertEqual(preferences.setting_value({'key': 'sectionOrder', 'value': 'syncthing'}), ','.join(expected))
        self.assertEqual(preferences.setting_value({'key': 'sectionOrder', 'value': ''}), '')
        self.assertEqual(migration.settings({'id': 'omaconnect.plus', 'sectionOrder': 'syncthing'})['sectionOrder'], 'syncthing')
        for value in (None, [], 'unknown', 'devices,devices', 'devices,', ' devices', 'devices;command', 'x' * 513):
            with self.subTest(value=value), self.assertRaises(ValueError):
                sections.order_ids(value)
            with self.subTest(save=value), self.assertRaises(ValueError):
                preferences.setting_value({'key': 'sectionOrder', 'value': value})
            with self.subTest(migration=value), self.assertRaises(migration.MigrationError):
                migration.settings({'id': 'omaconnect.plus', 'sectionOrder': value})

    @unittest.skipUnless(shutil.which('node'), 'Node runtime absent')
    def test_actual_js_and_python_share_catalogue_and_rejection_cases(self):
        invalid = []
        for field, value in [('id', '../devices'), ('defaultVisible', 'true'), ('defaultExpanded', 1), ('expandedKey', 'command;run'), ('settingsPage', 'Unknown'), ('command', 'anything')]:
            rows = copy.deepcopy(sections.CATALOG)
            rows[0][field] = value
            invalid.append(rows)
        duplicate = copy.deepcopy(sections.CATALOG)
        duplicate[1]['id'] = duplicate[0]['id']
        invalid.append(duplicate)
        oversized = []
        for index in range(32):
            row = copy.deepcopy(sections.CATALOG[0])
            row.update(id='section-' + str(index).zfill(24), expandedKey='expanded' + str(index))
            oversized.append(row)
        invalid.append(oversized)
        for rows in invalid:
            with self.assertRaises(ValueError):
                sections.validate_catalog(rows)
        code = r'''const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const api=vm.createContext({});vm.runInContext(fs.readFileSync(process.argv[1],'utf8').replace(/^\.pragma library\s*/,''),api);
const input=JSON.parse(fs.readFileSync(0,'utf8')),entries=api.parseCatalog(input.catalog);
assert.equal(entries.length,10);assert.equal(api.normalize('',entries).join(','),entries.map(row=>row.id).join(','));
assert.equal(api.normalize('syncthing',entries).join(','),'syncthing,'+entries.slice(0,-1).map(row=>row.id).join(','));
for(const value of [null,[],'unknown','devices,devices','devices,',' devices','devices;command','x'.repeat(513)])assert.equal(api.parse(value,entries),null);
for(const rows of input.invalid)assert.equal(api.parseCatalog(JSON.stringify(rows)).length,0);
assert.equal(api.parseCatalog('broken').length,0);assert.equal(api.parseCatalog('x'.repeat(32769)).length,0);
const ids=api.normalize('',entries);assert.equal(api.move(ids,'devices',-1),null);assert.equal(api.move(ids,'syncthing',1),null);
assert.equal(api.move(ids,'actions',-1).slice(0,2).join(','),'actions,devices');assert.equal(ids[0],'devices');
'''
        result = subprocess.run(['node', '-e', code, str(ROOT / 'SectionOrder.js')],
            input=json.dumps({'catalog': (ROOT / 'PanelSections.json').read_text(), 'invalid': invalid}),
            text=True, capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_native_order_editor_waits_for_readback_and_preserves_failed_save(self):
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture = 'section_order_ui.qml'
        runner.force_offscreen = True

        def configure(fixture, plugin, home, fake_bin):
            (fixture / 'save-gate').write_text('hold')
            (fixture / 'request-started').write_text('')
            shutil.copyfile(ROOT / 'scripts/manage_addresses.py', plugin / 'scripts/section_order_boundary.py')
            helper = plugin / 'scripts/network_preferences.py'
            helper.write_text(helper.read_text().replace('from manage_addresses import', 'from section_order_boundary import'))
            fake = fake_bin / 'fake'
            fake.write_text(fake.read_text().replace("elif name == 'omarchy-shell': raise SystemExit(0)",
                "elif name == 'omarchy-shell':\n"
                " gate=Path(os.environ['NATIVE_COMMAND_LOG']).parent/'save-gate'\n"
                " (gate.parent/'request-started').write_text(sys.argv[4])\n"
                " while gate.read_text() == 'hold': time.sleep(.01)\n"
                " print('unknown' if any(',syncthing,addresses' in a for a in sys.argv) else 'ok')"))

        def assert_editor(fixture, home, output, calls):
            self.assertIn('NATIVE_PASS section order', output)
            writes = [row['args'] for row in calls if row['tool'] == 'omarchy-shell']
            self.assertEqual(len(writes), 4, writes)
            self.assertTrue(all(row[:4] == ['shell', 'setBarWidget', 'omaconnect.plus', 'sectionOrder'] and row[-1] == '{}' for row in writes[:3]))
            self.assertEqual(json.loads(writes[0][-2]), 'actions,devices,drop,native,information,media,commands,connections,addresses,syncthing')
            self.assertEqual(json.loads(writes[1][-2]), 'actions,devices,drop,native,information,media,commands,connections,syncthing,addresses')
            self.assertEqual(json.loads(writes[2][-2]), '')
            self.assertEqual(writes[3], ['shell', 'setBarWidget', 'omaconnect.plus', 'showRemoteCommands', 'false', '{}'])
            self.assertTrue(all(row['tool'] in ('fc-match', 'hyprctl', 'omarchy-shell') for row in calls), calls)
            self.assertEqual(json.loads((fixture / 'portal-receipt.json').read_text()), [])

        runner.configure_fixture = configure
        runner.assert_fixture = assert_editor
        runner.test_actual_service_bar_panel_and_controls()

    def test_native_failed_process_start_releases_shared_save_guard(self):
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture = 'section_order_failure_ui.qml'
        runner.force_offscreen = True

        def configure(fixture, plugin, home, fake_bin):
            helper = plugin / 'components/PreferenceControls.qml'
            helper.write_text(helper.read_text().replace('"/usr/bin/timeout"', '"/nonexistent-setting-launcher"'))
            (fixture / 'commands.jsonl').write_text('')

        def assert_failure(fixture, home, output, calls):
            self.assertIn('NATIVE_PASS section startup failure releases save guard', output)
            self.assertTrue(all(row['tool'] in ('fc-match', 'hyprctl') for row in calls), calls)
            self.assertEqual(json.loads((fixture / 'portal-receipt.json').read_text()), [])

        runner.configure_fixture = configure
        runner.assert_fixture = assert_failure
        runner.test_actual_service_bar_panel_and_controls()


if __name__ == '__main__':
    unittest.main()
