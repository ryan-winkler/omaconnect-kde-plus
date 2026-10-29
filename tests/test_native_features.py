"""Run real discovery/launcher boundaries against closed-PATH fake providers."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
BASH = shutil.which('bash')


class NativeFeaturesTests(unittest.TestCase):
    def discover(self, supported, loaded=None):
        with tempfile.TemporaryDirectory() as tmp:
            bindir = Path(tmp)
            for name in ('sed', 'grep', 'tr'):
                (bindir / name).symlink_to(shutil.which(name))
            stub = bindir / 'gdbus'
            stub.write_text('#!' + sys.executable + '\n' + '''import os,sys
args=' '.join(sys.argv[1:])
if 'NameHasOwner' in args: print('(true,)')
elif 'daemon.devices' in args: print("(['fixture_peer'],)")
elif 'customDevices' in args: print('(<@as []>,)')
elif 'loadedPlugins' in args:
    if 'LOADED' not in os.environ: sys.exit(1)
    print(os.environ['LOADED'])
elif 'supportedPlugins' in args: print(os.environ['SUPPORTED'])
elif 'verificationKey' in args: print("(<'fixture-key'>,)")
elif 'isPaired' in args or 'isReachable' in args: print('(<true>,)')
elif args.endswith(' name'): print("(<'Fixture peer'>,)")
elif args.endswith(' type'): print("(<'phone'>,)")
else: print('(<false>,)')
''')
            stub.chmod(0o700)
            env = {**os.environ, 'PATH': tmp, 'SUPPORTED': supported}
            if loaded is not None:
                env['LOADED'] = loaded
            else:
                env.pop('LOADED', None)
            result = subprocess.run([BASH, str(ROOT / 'scripts/discover_devices.sh')], env=env, text=True, capture_output=True, timeout=5)
            self.assertEqual(result.returncode, 0, result.stderr)
            return next(line.split('\t') for line in result.stdout.splitlines() if line.startswith('DEVICE\t'))

    def test_future_native_feature_survives_and_loading_is_separate(self):
        row = self.discover("(<['kdeconnect_notifications', 'kdeconnect_sftp', 'kdeconnect_future_feature', 'thirdparty.custom-addon', 'kdeconnect_remotecommands']>,)", "(['kdeconnect_sftp'],)")
        self.assertEqual(row[8].split(','), ['kdeconnect_notifications', 'kdeconnect_sftp', 'kdeconnect_future_feature', 'thirdparty.custom-addon', 'kdeconnect_remotecommands'])
        self.assertEqual(row[13:], ['fixture-key', 'kdeconnect_sftp', 'true'])
        old = self.discover("(<['kdeconnect_sftp']>,)")
        self.assertEqual(old[14:], ['', 'false'])
        malformed = self.discover("(<['kdeconnect_sftp']>,)", '(<false>,)')
        self.assertEqual(malformed[14:], ['', 'false'])
        empty = self.discover('(<@as []>,)', '(@as [],)')
        self.assertEqual(empty[14:], ['', 'true'])

    def test_invalid_or_oversized_plugin_arrays_do_not_reach_qml(self):
        for raw in ("(<['kdeconnect_valid', 'bad;$(command)']>,)", "(<['" + 'kdeconnect_a' * 4000 + "']>,)", '(' + repr(['kdeconnect_p' + str(i) for i in range(257)]) + ',)'):
            with self.subTest(size=len(raw)):
                row = self.discover(raw)
                self.assertEqual(row[8], '')

    @unittest.skipUnless(shutil.which('node'), 'node unavailable')
    def test_actual_qml_parser_preserves_metadata_and_action_direction(self):
        source = (ROOT / 'KdeConnectController.qml').read_text()
        function = source[source.index('    function parseScanLine('):source.index('    function applyScan(')]
        script = '''const assert=require('node:assert/strict');
const vm=require('node:vm');const input=JSON.parse(require('node:fs').readFileSync(0,'utf8'));
const api=vm.createContext({});vm.runInContext(input.fn,api);
const prefix='DEVICE\\tfixture_peer\\tPhone\\tphone\\ttrue\\ttrue\\t-1\\tfalse\\t';
let row=api.parseScanLine(prefix+'kdeconnect_runcommand,kdeconnect_mpriscontrol');
assert.equal(row.capabilities.commands,false);assert.equal(row.capabilities.media,false);
assert.equal(row.loadedKnown,false);
row=api.parseScanLine(prefix+'kdeconnect_remotecommands,kdeconnect_mprisremote,kdeconnect_future_feature,thirdparty.custom-addon\\t\\t-1\\tfalse\\tfalse\\tkey\\tkdeconnect_mprisremote\\ttrue');
assert.equal(row.capabilities.commands,true);assert.equal(row.capabilities.media,true);
assert.equal(row.pluginIds.includes('kdeconnect_future_feature'),true);assert.equal(row.pluginIds.includes('thirdparty.custom-addon'),true);
assert.equal(row.loadedKnown,true);assert.equal(row.loadedPluginIds.join(','),'kdeconnect_mprisremote');
'''
        result = subprocess.run([shutil.which('node'), '-e', script], input=json.dumps({'fn': function}), text=True, capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)

    def launch(self, app, args):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            log = base / 'argv.json'
            for name in ('nohup', app):
                path = base / name
                if name == 'nohup':
                    path.write_text('#!/bin/bash\nexec "$@"\n')
                else:
                    path.write_text('#!' + sys.executable + '\nimport json,sys\nfrom pathlib import Path\nPath(' + repr(str(log)) + ').write_text(json.dumps(sys.argv[1:]))\n')
                path.chmod(0o700)
            result = subprocess.run([BASH, str(ROOT / 'scripts/open_app.sh'), *args], env={**os.environ, 'PATH': tmp}, text=True, capture_output=True, timeout=5)
            if result.returncode == 0:
                until = time.monotonic() + 2
                while not log.exists() and time.monotonic() < until:
                    time.sleep(.01)
            return result.returncode, json.loads(log.read_text()) if log.exists() else None

    def test_device_launcher_uses_fixed_arguments_and_older_frontend_fallback(self):
        self.assertEqual(self.launch('kdeconnect-app', ['peer_123-abc']), (0, ['--device', 'peer_123-abc']))
        self.assertEqual(self.launch('kdeconnect-app', []), (0, []))
        self.assertEqual(self.launch('kdeconnect-settings', ['peer_123-abc']), (0, []))
        self.assertEqual(self.launch('kcmshell6', ['peer_123-abc']), (0, ['kcm_kdeconnect']))
        for args in (['--plugin-config'], ['peer;command'], ['../peer'], ['peer', 'extra']):
            self.assertEqual(self.launch('kdeconnect-app', args), (2, None))
