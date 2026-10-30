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
    def discovery(self, supported, loaded=None, owner=True, activatable=None, cli=False):
        with tempfile.TemporaryDirectory() as tmp:
            bindir = Path(tmp)
            (bindir / 'python3').symlink_to(sys.executable)
            (bindir / 'dirname').symlink_to(shutil.which('dirname'))
            stub = bindir / 'busctl'
            stub.write_text('#!' + sys.executable + '\n' + '''import json,os,sys
args=[a for a in sys.argv[1:] if a not in ('--user', '--json=short')]
def reply(kind, *data): print(json.dumps({'type': kind, 'data': list(data)}))
def v(kind, value): return {'type': kind, 'data': value}
if 'NameHasOwner' in args:
    if os.environ['OWNER'] == 'error': sys.exit(1)
    if os.environ['OWNER'] == 'malformed': reply('s', 'unknown')
    else: reply('b', os.environ['OWNER'] == 'true')
elif 'ListActivatableNames' in args:
    if os.environ['ACTIVATABLE'] == 'error': sys.exit(1)
    print(os.environ['ACTIVATABLE'])
elif 'devices' in args: reply('as', ['fixture_peer'])
elif 'customDevices' in args: print(json.dumps({'type': 'as', 'data': []}))
elif 'loadedPlugins' in args:
    if 'LOADED' not in os.environ: sys.exit(1)
    print(os.environ['LOADED'])
elif args[-1] == 'org.kde.kdeconnect.device':
    reply('a{sv}', {'name': v('s', 'Fixture peer'), 'type': v('s', 'phone'), 'isPaired': v('b', True), 'isReachable': v('b', True), 'verificationKey': v('s', 'fixture-key'), 'supportedPlugins': v('as', json.loads(os.environ['SUPPORTED']))})
else: sys.exit(1)
''')
            stub.chmod(0o700)
            if cli:
                (bindir / 'kdeconnect-cli').symlink_to(stub)
            env = {**os.environ, 'PATH': tmp, 'SUPPORTED': json.dumps(supported),
                   'OWNER': owner if isinstance(owner, str) else 'true' if owner else 'false',
                   'ACTIVATABLE': activatable or '{"type":"as","data":[[]]}'}
            if loaded is not None:
                env['LOADED'] = loaded
            else:
                env.pop('LOADED', None)
            return subprocess.run([BASH, str(ROOT / 'scripts/discover_devices.sh')], env=env, text=True, capture_output=True, timeout=5)

    def discover(self, supported, loaded=None):
        result = self.discovery(supported, loaded)
        self.assertEqual(result.returncode, 0, result.stderr)
        return next(line.split('\t') for line in result.stdout.splitlines() if line.startswith('DEVICE\t'))

    def test_discovery_distinguishes_missing_package_from_stopped_or_unknown_daemon(self):
        # Closed PATH and fake bus only. A running daemon does not need the CLI.
        self.assertEqual(self.discovery([], owner=True).returncode, 0)
        self.assertEqual(self.discovery([], owner=False).returncode, 127)
        for owner in ('error', 'malformed'):
            with self.subTest(owner=owner):
                self.assertEqual(self.discovery([], owner=owner).returncode, 69)
        registered = '{"type":"as","data":[["org.kde.kdeconnect"]]}'
        for reply, cli in ((registered, False), (None, True), ('error', False),
                           ('{"type":"b","data":[false]}', False),
                           ('{"type":"b","data":[[]]}', False),
                           ('{"type":"as","data":[[null]]}', False)):
            with self.subTest(reply=reply, cli=cli):
                self.assertEqual(self.discovery([], owner=False, activatable=reply, cli=cli).returncode, 69)

    def test_missing_helper_dependencies_do_not_imply_missing_kde(self):
        # Do not inherit host commands. Even present KDE tools cannot repair the
        # missing discovery transport or parser requires dependency status 78.
        for missing in ("busctl", "python3"):
            with self.subTest(missing=missing), tempfile.TemporaryDirectory() as tmp:
                bindir = Path(tmp)
                for name in ("busctl", "python3", "kdeconnect-cli"):
                    if name == missing:
                        continue
                    stub = bindir / name
                    stub.write_text("#!/bin/bash\nexit 99\n")
                    stub.chmod(0o700)
                result = subprocess.run([BASH, str(ROOT / "scripts/discover_devices.sh")],
                    env={**os.environ, "PATH":tmp}, capture_output=True, text=True, timeout=5)
                self.assertEqual(result.returncode, 78)
                self.assertEqual(result.stdout, "")
                self.assertIn("Discovery needs busctl and Python 3", result.stderr)

    def test_future_native_feature_survives_and_loading_is_separate(self):
        row = self.discover(['kdeconnect_notifications', 'kdeconnect_sftp', 'kdeconnect_future_feature', 'thirdparty.custom-addon', 'kdeconnect_remotecommands'], '{"type":"as","data":[["kdeconnect_sftp"]]}')
        self.assertEqual(row[8].split(','), ['kdeconnect_notifications', 'kdeconnect_sftp', 'kdeconnect_future_feature', 'thirdparty.custom-addon', 'kdeconnect_remotecommands'])
        self.assertEqual(row[13:], ['fixture-key', 'kdeconnect_sftp', 'true'])
        old = self.discover(['kdeconnect_sftp'])
        self.assertEqual(old[14:], ['', 'false'])
        malformed = self.discover(['kdeconnect_sftp'], '{"type":"b","data":[false]}')
        self.assertEqual(malformed[14:], ['', 'false'])
        empty = self.discover([], '{"type":"as","data":[[]]}')
        self.assertEqual(empty[14:], ['', 'true'])

    def test_invalid_or_oversized_plugin_arrays_do_not_reach_qml(self):
        for supported in (['kdeconnect_valid', 'bad;$(command)'], ['kdeconnect_a' * 4000], ['kdeconnect_p' + str(i) for i in range(257)]):
            with self.subTest(size=len(supported)):
                row = self.discover(supported)
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
const info={addresses:['192.0.2.10:1716'],providers:['LAN'],monitor:{known:true,active:false,available:true}};
row=api.parseScanLine(prefix+'kdeconnect_virtualmonitor\\t\\t-1\\tfalse\\tfalse\\tkey\\tkdeconnect_virtualmonitor\\ttrue\\t'+JSON.stringify(info));
assert.equal(row.reachableAddresses[0],'192.0.2.10:1716');assert.equal(row.activeProviderNames[0],'LAN');assert.equal(row.virtualMonitor.available,true);
info.addresses=['x'.repeat(257)];info.monitor.known='true';
row=api.parseScanLine(prefix+'kdeconnect_virtualmonitor\\t\\t-1\\tfalse\\tfalse\\tkey\\t\\tfalse\\t'+JSON.stringify(info));
assert.equal(row.reachableAddresses.length,0);assert.equal(row.virtualMonitor.known,false);
'''
        result = subprocess.run([shutil.which('node'), '-e', script], input=json.dumps({'fn': function}), text=True, capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)

    @unittest.skipUnless(shutil.which('node'), 'node unavailable')
    def test_pairing_response_rejects_ids_unsafe_for_a_dbus_path(self):
        # D-Bus object-path elements allow only ASCII letters, digits and '_'.
        source = (ROOT / 'KdeConnectController.qml').read_text()
        function = source[source.index('    function validDeviceId('):source.index('    function respondToPairingRequest(')]
        self.assertIn('if (!validDeviceId(id)) return false', source[source.index('    function respondToPairingRequest('):])
        script = '''const assert=require('node:assert/strict');
const vm=require('node:vm');const api=vm.createContext({});
vm.runInContext(require('node:fs').readFileSync(0,'utf8'),api);
for (const id of ['0123456789abcdef0123456789abcdef','a1b2c3d4_e5f6_4a1b_9c2d_0123456789ab','peer_123_abc']) assert.equal(api.validDeviceId(id),true,id);
for (const id of ['','_peer','peer-123','../peer','peer/sub','peer.name','peer id','peer;x',null]) assert.equal(api.validDeviceId(id),false,String(id));
'''
        result = subprocess.run([shutil.which('node'), '-e', script], input=function, text=True, capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)

    def launch(self, app, args, config_support=True):
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            log = base / 'argv.json'
            (base / 'timeout').symlink_to(shutil.which('timeout'))
            for name in ('nohup', app):
                path = base / name
                if name == 'nohup':
                    path.write_text('#!/bin/bash\nexec "$@"\n')
                else:
                    path.write_text('#!' + sys.executable + '\nimport json,sys\nfrom pathlib import Path\n'
                        + 'if sys.argv[1:] == ["--help"]:\n print(' + repr('--plugin-config' if config_support else '--device') + '); sys.exit(0)\n'
                        + 'Path(' + repr(str(log)) + ').write_text(json.dumps(sys.argv[1:]))\n')
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
        for args in (['--plugin-config'], ['peer;command'], ['../peer'], ['peer', 'config', 'extra']):
            self.assertEqual(self.launch('kdeconnect-app', args), (2, None))

    def test_configuration_launcher_targets_exact_device_and_module_or_reports_unavailable(self):
        self.assertEqual(self.launch('kdeconnect-app', ['peer_123', 'kdeconnect_runcommand']),
            (0, ['--device', 'peer_123', '--plugin-config', 'kdeconnect_runcommand']))
        self.assertEqual(self.launch('kdeconnect-app', ['peer_123', 'kdeconnect_clipboard'], False), (69, None))
        for app in ('kdeconnect-settings', 'kcmshell6'):
            self.assertEqual(self.launch(app, ['peer_123', 'kdeconnect_runcommand']), (69, None))
        for args in (['', 'kdeconnect_runcommand'], ['peer', '../config'], ['peer', '--bad'], ['peer', 'x' * 129]):
            self.assertEqual(self.launch('kdeconnect-app', args), (2, None))


class DiscoveryDependencyUi(unittest.TestCase):
    def configure_fixture(self, fixture, plugin, home, fake_bin):
        # Exercise the actual controller's Process exit path, without a real bus.
        (plugin/'scripts/discover_devices.sh').write_text('#!/bin/bash\nexit 78\n')
        (fixture/'commands.jsonl').write_text('')

    def assert_fixture(self, fixture, home, output, calls):
        self.assertIn('NATIVE_PASS dependency discovery unavailable', output)
        self.assertTrue(all(row['tool'] in ('dbus-monitor', 'fc-match', 'hyprctl') for row in calls), calls)
        self.assertEqual(json.loads((fixture/'portal-receipt.json').read_text()), [])

    def test_dependency_exit_classifies_actual_controller(self):
        import test_native_ui as native_ui
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture = 'discovery_dependency_ui.qml'
        runner.force_offscreen = True
        runner.configure_fixture = self.configure_fixture
        runner.assert_fixture = self.assert_fixture
        runner.test_actual_service_bar_panel_and_controls()
