"""Native QML integration. No mapped host UI, real providers or network."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class NativeUi(unittest.TestCase):
    qml_fixture = 'native_ui.qml'
    force_offscreen = False

    def configure_fixture(self, fixture, plugin, home, fake_bin):
        """Allow another isolated scenario to replace only its temporary doubles."""

    @unittest.skipUnless(shutil.which('quickshell') and shutil.which('bwrap') and shutil.which('dbus-run-session'), 'native isolated runtime absent')
    def test_actual_service_bar_panel_and_controls(self):
        """Load product QML with private state and fake executable and bus boundaries."""
        with tempfile.TemporaryDirectory(prefix='omaconnect-native-') as temporary:
            fixture = Path(temporary)
            desktop = not self.force_offscreen and os.environ.get('OMACONNECT_DESKTOP_VALIDATION') == '1'
            wayland = Path(os.environ.get('XDG_RUNTIME_DIR','')) / os.environ.get('WAYLAND_DISPLAY','')
            if desktop and not wayland.is_socket(): self.fail('Current Wayland socket is unavailable')
            plugin = fixture / 'plugin'
            shutil.copytree(ROOT, plugin, ignore=shutil.ignore_patterns('.git','__pycache__'))
            (fixture / 'Commons').symlink_to('/usr/share/omarchy/shell/Commons')
            ui = fixture/'Ui'; ui.mkdir()
            for native in Path('/usr/share/omarchy/shell/Ui').iterdir():
                if native.name != 'KeyboardPanel.qml': (ui/native.name).symlink_to(native)
            # Qt's offscreen plugin has no Quickshell PanelWindow backend.
            # Substitute this hosting boundary only; product UI stays unchanged.
            (ui/'KeyboardPanel.qml').write_text('''import QtQuick
Item {
 required property Item anchorItem
 required property QtObject bar
 property var owner
 property bool open: false
 property var focusTarget
 property int contentWidth: 400
 property int contentHeight: 700
 width: contentWidth
 height: contentHeight
 function fittedContentWidth(value) { return value }
 function fittedContentHeight(value) { return Math.min(700,value) }
}
''')
            if desktop:
                (ui/'KeyboardPanel.qml').unlink()
                (ui/'KeyboardPanel.qml').symlink_to('/usr/share/omarchy/shell/Ui/KeyboardPanel.qml')
            shutil.copy(ROOT / 'tests' / self.qml_fixture, fixture / 'shell.qml')
            shutil.copy(ROOT / 'tests/native_ui_session.py', fixture / 'session.py')
            for name, content in [('one', b'abc'), ('two', b'defg'), ('slow', b'delay')]:
                (fixture / name).write_bytes(content)
            fake_bin = fixture / 'bin'; fake_bin.mkdir()
            for name in ('python3','bash','sh','dirname','dbus-daemon','timeout','head'):
                (fake_bin/name).symlink_to(shutil.which(name))
            fake = fake_bin/'fake'
            fake.write_text('''#!/usr/bin/python3
import json,os,sys,time
from pathlib import Path
name=Path(sys.argv[0]).name
with open(os.environ['NATIVE_COMMAND_LOG'],'a') as out: out.write(json.dumps({'tool':name,'args':sys.argv[1:]})+'\\n')
if name == 'kdeconnect-cli':
 time.sleep(4 if Path(sys.argv[-1]).name=='slow' else .1)
 raise SystemExit(0)
if name == 'dbus-monitor': time.sleep(30)
elif name == 'fc-match': print('sans-serif')
elif name == 'hyprctl': print('{"int":0,"bool":false}')
elif name == 'omarchy-shell': raise SystemExit(0)
elif name == 'remote-access-mode':
 if sys.argv[1:] != ['control-status']: raise SystemExit(98)
 print('{"schema_version":1,"configured":false}')
else: raise SystemExit(99)
''')
            fake.chmod(0o700)
            for name in ('kdeconnect-cli','dbus-monitor','hyprctl','fc-match','remote-access-mode','omarchy-shell','nmcli'):
                (fake_bin/name).symlink_to(fake)
            (plugin/'scripts/discover_devices.sh').write_text("#!/bin/bash\nprintf '%s\\n' 'CUSTOM_ADDRESSES_READY' $'DEVICE\\tA\\tOriginal phone\\tphone\\ttrue\\ttrue\\t80\\tfalse\\tkdeconnect_share,kdeconnect_battery' $'DEVICE\\tB\\tOther phone\\tlaptop\\ttrue\\ttrue\\t65\\tfalse\\tkdeconnect_share,kdeconnect_battery'\n")
            (plugin/'scripts/manage_addresses.py').write_text('import json,sys\njson.load(sys.stdin)\nprint(json.dumps({"schema_version":1,"ok":True,"addresses":[],"custom_addresses":[]}))\n')
            (plugin/'scripts/native_settings.py').write_text('''import json,sys
from pathlib import Path
request=json.load(sys.stdin)
state_file=Path.home()/"fixture-module-state.json"
states=json.loads(state_file.read_text()) if state_file.exists() else {}
peer=request["peerId"]
if request["operation"]=="set":
 states.setdefault(peer,{})[request["pluginId"]]=request["enabled"]
 state_file.write_text(json.dumps(states))
ids=request["pluginIds"] if request["operation"]=="read" else [request["pluginId"]]
values={name:states.get(peer,{}).get(name,name in ("kdeconnect_share","kdeconnect_battery")) for name in ids}
print(json.dumps({"state":"observed","peerId":peer,"enabled":values,"error":""}))
''')
            home = fixture/'home'; home.mkdir()
            (home/'.local/bin').mkdir(parents=True)
            (home/'.local/bin/remote-access-mode').symlink_to(fake_bin/'remote-access-mode')
            runtime = fixture/'runtime'; runtime.mkdir(mode=0o700)
            self.configure_fixture(fixture, plugin, home, fake_bin)
            env = {'PATH':str(fake_bin), 'HOME':str(home), 'XDG_CONFIG_HOME':str(home/'.config'), 'XDG_CACHE_HOME':str(home/'.cache'), 'XDG_DATA_HOME':str(home/'.local/share'), 'XDG_STATE_HOME':str(home/'.local/state'), 'XDG_RUNTIME_DIR':str(runtime), 'QT_QPA_PLATFORM':'offscreen', 'QT_QUICK_BACKEND':'software', 'LANG':'C.UTF-8', 'NATIVE_COMMAND_LOG':str(fixture/'commands.jsonl'), 'DBUS_SYSTEM_BUS_ADDRESS':'unix:path='+str(fixture/'no-system-bus')}
            if desktop:
                env.pop('QT_QUICK_BACKEND',None)
                env.update(QT_QPA_PLATFORM='wayland', QSG_RHI_BACKEND='opengl', WAYLAND_DISPLAY='validation-wayland', OMACONNECT_DESKTOP_VALIDATION='1')
            # Read-only host root, a single writable fixture, private process and
            # network namespaces, and fixed absolute actions replaced as well.
            # A synthetic root is owned by this test UID. A bound host root has
            # unmapped ownership (65534) inside the unprivileged user namespace,
            # which production source/cache checks must refuse. Keep those checks
            # intact; expose only runtime libraries/config and the owned fixture.
            command = ['/usr/bin/bwrap','--tmpfs','/','--ro-bind','/usr','/usr',
                       '--ro-bind','/etc','/etc','--symlink','usr/bin','/bin',
                       '--symlink','usr/bin','/sbin','--symlink','usr/lib','/lib']
            if Path('/lib64').exists(): command += ['--symlink','usr/lib','/lib64']
            command += ['--dir','/tmp','--bind',str(fixture),str(fixture),
                        '--chdir',str(fixture),'--unshare-net','--unshare-pid',
                        '--proc','/proc','--dev','/dev','--die-with-parent']
            for name in ('omarchy-shell','nmcli','hyprctl','kdeconnect-cli','dbus-monitor'):
                path=Path('/usr/bin')/name
                if path.exists(): command += ['--ro-bind',str(fake),str(path)]
            if desktop:
                command += ['--ro-bind',str(wayland),str(runtime/'validation-wayland')]
                if Path('/dev/dri').exists(): command += ['--dev-bind','/dev/dri','/dev/dri']
                theme = Path(os.environ['HOME'])/'.local/state/omarchy/current/theme'
                target = home/'.local/state/omarchy/current/theme'
                target.mkdir(parents=True)
                for name in ('colors.toml','shell.toml'):
                    if (theme/name).is_file(): shutil.copyfile(theme/name,target/name)
            command += ['/usr/bin/dbus-run-session','--','/usr/bin/python3',str(fixture/'session.py'),str(fixture)]
            result = subprocess.run(command, env=env, capture_output=True, text=True, timeout=22)
            output = result.stdout+result.stderr
            if desktop:
                destination = ROOT.parent/'desktop-validation'
                destination.mkdir(exist_ok=True)
                (destination/'native-ui.log').write_text(output)
                for shot in fixture.glob('desktop-*.png'): shutil.copyfile(shot,destination/shot.name)
            export_directory = os.environ.get('OMACONNECT_CAPTURE_DIR')
            if export_directory:
                destination = Path(export_directory)
                destination.mkdir(parents=True, exist_ok=True)
                for shot in fixture.glob('*.png'):
                    shutil.copyfile(shot, destination / shot.name)
            self.assertEqual(result.returncode, 0, output)
            self.assertIn('NATIVE_PASS', output, output)
            self.assertNotIn('NATIVE_FAIL', output, output)
            self.assertNotIn('TypeError:', output, output)
            self.assertNotIn('ReferenceError:', output, output)
            self.assertNotIn('Error loading configuration', output, output)
            calls = [json.loads(row) for row in (fixture/'commands.jsonl').read_text().splitlines()]
            self.assert_fixture(fixture, home, output, calls)
            print(output)

    def assert_fixture(self, fixture, home, output, calls):
        submissions = [call for call in calls if call['tool']=='kdeconnect-cli']
        self.assertEqual(len(submissions), 3, output)
        self.assertTrue(all(call['args'][:2] == ['-d','A'] for call in submissions), submissions)
        self.assertEqual(len(json.loads((fixture/'portal-receipt.json').read_text())), 2)
        state = json.loads((home/'.config/Omaconnect.plus/appearance.json').read_text())
        self.assertEqual(state['bar_icon']['value'], 'laptop')
        owner_calls = [call for call in calls if call['tool']=='omarchy-shell']
        self.assertEqual(len(owner_calls), 1, calls)
        self.assertFalse(any(call['tool']=='nmcli' for call in calls), calls)
        self.assertFalse(any(call['tool']=='remote-access-mode' for call in calls), 'Hidden BTH must not poll')


if __name__ == '__main__':
    unittest.main()
