"""Real media component, private HOME/bus and an owned loopback server only."""
import http.server
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading
import unittest

ROOT = Path(__file__).resolve().parents[1]
OMARCHY_SHELL = Path('/usr/share/omarchy/shell')


class SecurityBoundaries(unittest.TestCase):
    @unittest.skipUnless(shutil.which('quickshell') and shutil.which('dbus-run-session')
                         and (OMARCHY_SHELL/'Ui').is_dir(), 'native runtime absent')
    def test_provider_album_art_and_markup_never_fetch_or_log_urls(self):
        requests = []

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                requests.append(self.path)
                self.send_response(404)
                self.end_headers()

            def log_message(self, *args):
                pass

        server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            for expanded in (False, True):
                with self.subTest(expanded=expanded), tempfile.TemporaryDirectory(prefix='omaconnect-security-') as temporary:
                    requests.clear()
                    fixture = Path(temporary)
                    (fixture/'Commons').symlink_to(OMARCHY_SHELL/'Commons')
                    (fixture/'Ui').symlink_to(OMARCHY_SHELL/'Ui')
                    (fixture/'components').symlink_to(ROOT/'components')
                    (fixture/'runtime').mkdir(mode=0o700)
                    shutil.copyfile(ROOT/'tests/security_media_ui.qml', fixture/'shell.qml')
                    art = f'http://127.0.0.1:{server.server_port}/owned-art?token=OWNED-ART-SENTINEL'
                    title = f'<img src="http://127.0.0.1:{server.server_port}/owned-text?token=OWNED-TEXT-SENTINEL">'
                    env = {'PATH':'/usr/bin', 'HOME':temporary,
                           'XDG_CONFIG_HOME':temporary+'/config', 'XDG_DATA_HOME':temporary+'/data',
                           'XDG_CACHE_HOME':temporary+'/cache', 'XDG_RUNTIME_DIR':temporary+'/runtime',
                           'DBUS_SYSTEM_BUS_ADDRESS':'unix:path='+temporary+'/no-system-bus',
                           'QT_QPA_PLATFORM':'offscreen', 'QT_QUICK_BACKEND':'software', 'LANG':'C.UTF-8',
                           'SECURITY_FIXTURE_EXPANDED':'1' if expanded else '0',
                           'SECURITY_FIXTURE_ART':art, 'SECURITY_FIXTURE_TITLE':title}
                    result = subprocess.run(['/usr/bin/dbus-run-session','--','/usr/bin/quickshell',
                                             '--no-color','-p',temporary], env=env, text=True,
                                            capture_output=True, timeout=8)
                    output = result.stdout+result.stderr
                    self.assertEqual(result.returncode, 0, output)
                    self.assertIn('SECURITY_MEDIA_PASS', output, output)
                    self.assertNotIn('SECURITY_MEDIA_FAIL', output, output)
                    leaked = any(private in output for private in
                                 (art, 'OWNED-ART-SENTINEL', 'OWNED-TEXT-SENTINEL'))
                    self.assertEqual((len(requests), leaked), (0, False),
                                     'Expected no provider URL request and no URL/token in shell output')
        finally:
            server.shutdown()
            server.server_close()
            thread.join()


if __name__ == '__main__':
    unittest.main()
