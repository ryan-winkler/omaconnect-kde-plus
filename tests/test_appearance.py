"""Appearance trust boundaries use only an owned temporary home."""
import json
import concurrent.futures
import shutil
import os
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
import zlib

HELPER = Path(__file__).resolve().parents[1] / 'scripts' / 'appearance.py'


def png(width=1, height=1):
    def chunk(kind, data):
        return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data))
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!IIBBBBB', width, height, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress((b'\0' + b'\xff\0\0\xff' * width) * height)) + chunk(b'IEND', b''))


class AppearanceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.home = Path(self.temp.name)
        self.env = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home/'config'), XDG_DATA_HOME=str(self.home/'data'))
        self.config = self.home/'config'/'ryan.omaconnect'/'appearance.json'

    def tearDown(self):
        self.temp.cleanup()

    def call(self, command, **request):
        result = subprocess.run(['python3', str(HELPER), command], input=json.dumps(request), capture_output=True, text=True, env=self.env)
        self.assertTrue(result.stdout, result.stderr)
        return json.loads(result.stdout)

    def test_default_atomic_persistence_and_stable_identity(self):
        self.assertEqual(self.call('read')['snapshot']['bar_icon']['value'], 'phone')
        self.assertFalse(self.config.exists())
        result = self.call('update', action='device', device_id='stable-1', alias='  Travel phone  ', icon={'mode':'preset','value':'laptop'})
        self.assertTrue(result['ok'], result)
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.config.parent.stat().st_mode & 0o777, 0o700)
        record = self.call('read')['snapshot']['devices']['kdeconnect:stable-1']
        self.assertEqual(record['alias'], 'Travel phone')
        self.assertEqual(record['icon']['value'], 'laptop')
        self.assertEqual(len(list(self.config.parent.glob('*.tmp'))), 0)

    def test_corrupt_and_oversized_state_are_preserved(self):
        self.config.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
        for source in (b'{bad', b' ' * (256*1024 + 1), b'['*2000+b']'*2000, json.dumps({'schema_version':1,'bar_icon':{'mode':'preset','value':'phone'},'devices':{},'unknown':'keep this'}).encode()):
            self.config.write_bytes(source)
            self.config.chmod(0o600)
            self.assertFalse(self.call('read')['ok'])
            self.assertFalse(self.call('update', action='bar', icon={'mode':'preset','value':'link'})['ok'])
            self.assertEqual(self.config.read_bytes(), source)

    def test_invalid_alias_id_and_device_bound(self):
        for alias in ('bad\nname', 'x'*81, 'bad\u202ename'):
            self.assertFalse(self.call('update', action='device', device_id='a', alias=alias, icon={'mode':'inherit'})['ok'])
        self.assertFalse(self.call('update', action='device', device_id='../a', alias='safe', icon={'mode':'inherit'})['ok'])
        self.config.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
        state = {'schema_version':1, 'bar_icon':{'mode':'preset','value':'phone'}, 'devices':{f'kdeconnect:d{i}':{'alias':'','icon':{'mode':'inherit'}} for i in range(256)}}
        self.config.write_text(json.dumps(state)); self.config.chmod(0o600)
        self.assertFalse(self.call('update', action='device', device_id='overflow', alias='', icon={'mode':'inherit'})['ok'])

    def test_image_copy_sniff_and_missing_asset(self):
        original = self.home/'source.wrong-extension'
        original.write_bytes(png())
        result = self.call('import', path=str(original))
        self.assertTrue(result['ok'], result)
        asset = Path(result['asset_dir'])/result['icon']['value']
        self.assertEqual(asset.read_bytes(), original.read_bytes())
        self.assertEqual(asset.stat().st_mode & 0o777, 0o600)
        original.unlink()
        self.assertTrue(asset.exists())
        self.assertTrue(self.call('update', action='bar', icon=result['icon'])['ok'])
        asset.unlink()
        self.assertTrue(self.call('read')['warnings'])

    def test_reject_svg_active_external_animation_and_fake_png(self):
        svg = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24">{}</svg>'
        cases = [svg.format('<script/>'), svg.format('<animate/>'), svg.format('<image href="https://example.org/a"/>'), svg.format('<path style="fill:url(https://example.org/a)"/>'), svg.format('<use href="file:///tmp/a"/>'), svg.format('<path onload="x"/>'), '<!DOCTYPE svg [<!ENTITY a "b">]>'+svg.format(''), svg.replace('24','513').format('')]
        for index, source in enumerate(cases):
            path = self.home/f'bad{index}.svg'; path.write_text(source)
            self.assertFalse(self.call('import', path=str(path))['ok'], source)
        for data in (b'not png', png()[:-4], png(513,1), png()+b'extra', b'x'*(1024*1024+1)):
            path = self.home/'bad.png'; path.write_bytes(data)
            self.assertFalse(self.call('import', path=str(path))['ok'])
        path = self.home/'safe.svg'; path.write_text(svg.format('<path d="M0 0L12 12" fill="currentColor"/>'))
        self.assertTrue(self.call('import', path=str(path))['ok'])

    def test_reject_symlinks_and_preserve_original(self):
        target = self.home/'original.png'; target.write_bytes(png())
        link = self.home/'link.png'; link.symlink_to(target)
        self.assertFalse(self.call('import', path=str(link))['ok'])
        self.config.parent.mkdir(parents=True, mode=0o700, exist_ok=True)
        self.config.symlink_to(target)
        self.assertFalse(self.call('update', action='bar', icon={'mode':'preset','value':'phone'})['ok'])
        self.assertEqual(target.read_bytes(), png())

    def test_concurrent_writes_preserve_both_devices(self):
        with concurrent.futures.ThreadPoolExecutor() as pool:
            futures = [pool.submit(self.call, 'update', action='device', device_id=f'peer-{i}', alias=f'Peer {i}', icon={'mode':'inherit'}) for i in range(12)]
            self.assertTrue(all(future.result()['ok'] for future in futures))
        self.assertEqual(len(self.call('read')['snapshot']['devices']), 12)

    def test_animated_crc_bomb_and_svg_reference_cycles_rejected(self):
        def chunk(kind, data):
            return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data))
        header = png()[:33]
        cases = [header + chunk(b'acTL', struct.pack('!II', 1, 0)) + png()[33:],
                 png()[:45] + b'bad crc' + png()[45:],
                 header + chunk(b'IDAT', zlib.compress(b'x'*1000000)) + chunk(b'IEND', b'')]
        for data in cases:
            path = self.home/'bad.png'; path.write_bytes(data)
            self.assertFalse(self.call('import', path=str(path))['ok'])
        cycles = '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><defs><g id="a"><use href="#a"/></g></defs><use href="#a"/></svg>'
        for data in (cycles.encode(), cycles.encode('utf-16')):
            path = self.home/'cycle.svg'; path.write_bytes(data)
            self.assertFalse(self.call('import', path=str(path))['ok'])

    @unittest.skipUnless(shutil.which('qs'), 'Quickshell is unavailable')
    def test_offscreen_qml_store_chooser_and_reload(self):
        self.assertTrue(self.call('update', action='device', device_id='fixture', alias='Local alias', icon={'mode':'inherit'})['ok'])
        root = HELPER.parent.parent
        wrapper = self.home/'shell.qml'
        wrapper.write_text("""import QtQuick
import QtQuick.Window
import Quickshell
import \"""" + root.as_uri() + """\" as App
import \"""" + (root/'components').as_uri() + """\" as Components
Window {
 width: 520; height: 740; visible: true
 App.AppearanceStore { id: store }
 Components.IconChooser { id: chooser; store: store }
 Connections {
  target: store
  function onReadyChanged() { if (store.ready && !store.error) Qt.callLater(function() { chooser.openForDevice(\"fixture\", \"<b>Advertised</b>\", \"phone\"); }); }
 }
 Timer { interval: 700; running: true; onTriggered: { console.log(\"CHOOSER_OPEN\",chooser.visible); chooser.choose({mode:\"preset\",value:\"laptop\"}); chooser.applyDraft(); } }
 Timer { interval: 1200; running: true; onTriggered: { chooser.openForBar(); chooser.choose({mode:\"preset\",value:\"share\"}); chooser.reject(); store.refresh(); } }
 Timer { interval: 1700; running: true; onTriggered: { console.log(\"RESULT\",store.displayName(\"fixture\",\"Renamed\"),store.deviceIcon(\"fixture\",\"phone\").value,store.barIcon(\"fixture\",\"phone\").value,store.error); Qt.quit(); } }
}
""")
        env = dict(self.env, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=str(self.home))
        env.pop('WAYLAND_DISPLAY', None)
        result = subprocess.run(['qs','-p',str(wrapper)], capture_output=True, text=True, env=env, timeout=7)
        output = result.stdout + result.stderr
        self.assertIn('CHOOSER_OPEN true', output, output)
        self.assertIn('RESULT Local alias laptop phone', output, output)
        for error in ('ReferenceError', 'TypeError', 'Unable to assign', 'Failed to load', 'invalidOverride'):
            self.assertNotIn(error, output, output)
        self.assertEqual(self.config.stat().st_mode & 0o777, 0o600)

    @unittest.skipUnless(shutil.which('qs'), 'Quickshell is unavailable')
    def test_offscreen_rejected_asset_and_automatic_preview(self):
        original = self.home/'source.png'
        original.write_bytes(png())
        imported = self.call('import', path=str(original))
        self.assertTrue(imported['ok'])
        self.assertTrue(self.call('update', action='bar', icon=imported['icon'])['ok'])
        self.assertTrue(self.call('update', action='device', device_id='fixture', alias='', icon=imported['icon'])['ok'])
        # Still a decodable PNG, but its content hash no longer matches approval.
        (Path(imported['asset_dir'])/imported['icon']['value']).write_bytes(png(2,1))
        root = HELPER.parent.parent
        wrapper = self.home/'preview.qml'
        wrapper.write_text("""import QtQuick
import QtQuick.Window
import Quickshell
import \"""" + root.as_uri() + """\" as App
import \"""" + (root/'components').as_uri() + """\" as Components
Window {
 width: 520; height: 740; visible: true
 App.AppearanceStore { id: store }
 Components.IconChooser { id: chooser; store: store }
 Timer {
  interval: 100; running: store.ready && !store.busy; repeat: false
  onTriggered: {
   chooser.openForBar(\"fixture\",\"phone\");
   console.log(\"REJECT_BAR\",chooser.resolvedDraft.mode === \"preset\" && chooser.resolvedDraft.value === \"phone\");
   chooser.openForDevice(\"fixture\",\"Advertised\",\"phone\");
   console.log(\"REJECT_DEVICE\",chooser.resolvedDraft.mode === \"preset\" && chooser.resolvedDraft.value === \"phone\");
   var snapshot = JSON.parse(JSON.stringify(store.snapshot));
   snapshot.bar_icon = {mode:\"automatic\"};
   snapshot.devices[\"kdeconnect:fixture\"].icon = {mode:\"preset\",value:\"laptop\"};
   store.snapshot = snapshot;
   chooser.openForBar(\"fixture\",\"phone\");
   console.log(\"FOLLOW_OVERRIDE\",chooser.resolvedDraft.value === \"laptop\" && chooser.resolvedDraft.value === store.barIcon(\"fixture\",\"phone\").value);
   chooser.openForBar(\"other\",\"desktop\");
   console.log(\"FOLLOW_TYPE\",chooser.resolvedDraft.value === \"desktop\" && chooser.resolvedDraft.value === store.barIcon(\"other\",\"desktop\").value);
   Qt.quit();
  }
 }
 Timer { interval: 4000; running: true; onTriggered: Qt.quit() }
}
""")
        env = dict(self.env, QT_QPA_PLATFORM='offscreen', XDG_RUNTIME_DIR=str(self.home))
        env.pop('WAYLAND_DISPLAY', None)
        result = subprocess.run(['qs','-p',str(wrapper)], capture_output=True, text=True, env=env, timeout=7)
        output = result.stdout + result.stderr
        for label in ('REJECT_BAR','REJECT_DEVICE','FOLLOW_OVERRIDE','FOLLOW_TYPE'):
            self.assertIn(label+' true', output, output)
        for error in ('ReferenceError','TypeError','Unable to assign','Failed to load'):
            self.assertNotIn(error, output, output)

    def test_explicit_syncthing_link_preserves_alias(self):
        self.call('update', action='device', device_id='a', alias='Phone', icon={'mode':'inherit'})
        self.assertFalse(self.call('update', action='link', device_id='a', syncthing_device_id='same name')['ok'])
        identity = '-'.join(['AAAAAAA']*8)
        result = self.call('update', action='link', device_id='a', syncthing_device_id=identity)
        self.assertTrue(result['ok'], result)
        record = result['snapshot']['devices']['kdeconnect:a']
        self.assertEqual(record['alias'], 'Phone')
        self.assertEqual(record['syncthing_device_id'], identity)
        self.assertIsNone(self.call('update', action='link', device_id='a', syncthing_device_id=None)['snapshot']['devices']['kdeconnect:a']['syncthing_device_id'])


if __name__ == '__main__':
    unittest.main()
