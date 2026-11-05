"""Exercise the scoped image-preview window without a host display or provider."""
import json
import struct
import unittest
import zlib

if __package__:
    from . import test_native_ui as native_ui
else:
    import test_native_ui as native_ui


class ImagePreviewUi(unittest.TestCase):
    def configure_fixture(self, fixture, plugin, home, fake_bin):
        """Create readable local PNGs and inject only the owned fixture path."""
        def chunk(kind, data):
            return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
        image = (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', 1, 1, 8, 2, 0, 0, 0))
                 + chunk(b'IDAT', zlib.compress(b'\x00\x80\xc0\x70')) + chunk(b'IEND', b''))
        for name in ['preview-one.png', 'preview-second #?.png']:
            (fixture / name).write_bytes(image)
        qml = fixture / 'shell.qml'
        qml.write_text(qml.read_text().replace('FIXTURE_PATH', str(fixture)))
        (fixture / 'commands.jsonl').write_text('')

    def assert_fixture(self, fixture, home, output, calls):
        """UI navigation and explicit confirmation must not reach a provider."""
        self.assertIn('IMAGE_PREVIEW_PASS', output, output)
        self.assertIn('IMAGE_PREVIEW_KEYBOARD_PASS', output, output)
        self.assertTrue(all(row['tool'] in ('fc-match', 'hyprctl') for row in calls), calls)
        self.assertEqual(json.loads((fixture / 'portal-receipt.json').read_text()), [])

    def test_native_preview_browsing_explicit_confirmation_and_scoped_close(self):
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture = 'image_preview_ui.qml'
        runner.force_offscreen = True
        runner.configure_fixture = self.configure_fixture
        runner.assert_fixture = self.assert_fixture
        runner.test_actual_service_bar_panel_and_controls()


if __name__ == '__main__':
    unittest.main()
