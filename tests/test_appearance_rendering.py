"""Check rendered icon pixels, including the software scene graph."""
import json
from pathlib import Path
import struct
import unittest
import zlib

if __package__:
    from . import test_native_ui as native_ui
else:
    import test_native_ui as native_ui


def rgba_pixels(path):
    """Decode Qt's non-interlaced RGBA PNG receipts without another dependency."""
    raw = path.read_bytes()
    offset, packed = 8, b''
    while offset < len(raw):
        length = struct.unpack('>I', raw[offset:offset+4])[0]
        kind, data = raw[offset+4:offset+8], raw[offset+8:offset+8+length]
        if kind == b'IHDR':
            width, height, depth, color, _, _, interlace = struct.unpack('>IIBBBBB', data)
            assert (depth, color, interlace) == (8, 6, 0)
        if kind == b'IDAT':
            packed += data
        offset += length + 12
    decoded = zlib.decompress(packed)
    stride, offset, previous, pixels = width*4, 0, bytearray(width*4), []
    for _ in range(height):
        method = decoded[offset]
        row = bytearray(decoded[offset+1:offset+1+stride])
        for index in range(stride):
            left, above, upper_left = (row[index-4] if index >= 4 else 0), previous[index], (previous[index-4] if index >= 4 else 0)
            prediction = left + above - upper_left
            distances = [abs(prediction-value) for value in (left, above, upper_left)]
            paeth = (left, above, upper_left)[distances.index(min(distances))]
            row[index] = (row[index] + (0, left, above, (left+above)//2, paeth)[method]) % 256
        pixels.extend(tuple(row[index:index+4]) for index in range(0, stride, 4))
        previous, offset = row, offset+stride+1
    return pixels


class AppearanceRenderingTests(unittest.TestCase):
    def test_installed_shapes_follow_foreground_and_custom_colours_stay(self):
        """Prove theme tint preserves silhouettes and explicit image colours."""
        if not Path('/usr/share/icons/Adwaita/symbolic/devices/computer-symbolic.svg').is_file() or not Path('/usr/share/icons/hicolor/scalable/apps/kdeconnect.svg').is_file():
            self.skipTest('installed Adwaita test assets absent')
        runner = native_ui.NativeUi('test_actual_service_bar_panel_and_controls')
        runner.qml_fixture = 'appearance_rendering_ui.qml'
        runner.force_offscreen = True

        def configure(fixture, plugin, home, fake_bin):
            (fixture / 'commands.jsonl').write_text('')
            assets = fixture / 'assets'
            assets.mkdir()
            (assets / ('a'*64 + '.svg')).write_text('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><circle cx="32" cy="32" r="24" fill="#e02030"/></svg>')

        def assert_pixels(fixture, home, output, calls):
            """Reject blank masks, placeholder blocks and unwanted colour changes."""
            self.assertEqual(json.loads((fixture/'portal-receipt.json').read_text()), [])
            self.assertTrue(all(call['tool'] == 'fc-match' or (call['tool'] == 'hyprctl' and call['args'][:2] == ['-j', 'getoption']) for call in calls), calls)
            masks = []
            for index in (0, 1, 4):
                dark, light = [rgba_pixels(fixture / (label+'-'+str(index)+'.png')) for label in ('dark', 'light')]
                mask = [pixel[3] for pixel in dark]
                self.assertGreater(sum(alpha > 0 for alpha in mask), 100, 'loaded symbolic icon must draw pixels')
                self.assertLess(sum(alpha > 0 for alpha in mask), len(mask)*.8, 'retain the source silhouette and transparent background')
                self.assertEqual(mask, [pixel[3] for pixel in light])
                # PNG unpremultiplication can round antialiased edges by one.
                self.assertTrue(all(all(abs(channel-240) <= 1 for channel in pixel[:3]) for pixel in dark if pixel[3] > 128))
                self.assertTrue(all(all(abs(channel-32) <= 1 for channel in pixel[:3]) for pixel in light if pixel[3] > 128))
                masks.append(mask)
            self.assertNotEqual(masks[0], masks[1], 'installed desktop and phone must remain distinct')
            replaced = rgba_pixels(fixture / 'replaced-0.png')
            self.assertEqual([pixel[3] for pixel in replaced], masks[1], 'changing icons must clear the previous shape')
            custom = [rgba_pixels(fixture / (label+'-2.png')) for label in ('dark', 'light')]
            self.assertEqual(custom[0], custom[1], 'explicit custom colours must survive a theme change')
            self.assertTrue(any(pixel[:3] == (224, 32, 48) and pixel[3] > 128 for pixel in custom[0]))
            application = [rgba_pixels(fixture / (label+'-3.png')) for label in ('dark', 'light')]
            self.assertEqual(application[0], application[1], 'a full-colour installed icon must not become a foreground-colour block')
            colours = {pixel[:3] for pixel in application[0] if pixel[3] > 250}
            self.assertGreater(len(colours), 20, 'native application artwork must keep its internal colours and detail')

        runner.configure_fixture = configure
        runner.assert_fixture = assert_pixels
        runner.test_actual_service_bar_panel_and_controls()


if __name__ == '__main__':
    unittest.main()
