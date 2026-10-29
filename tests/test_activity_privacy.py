import http.server
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading
import unittest

ROOT=Path(__file__).resolve().parents[1]
FIXTURE=ROOT/"tests/security_activity_ui.qml"

class ActivityPrivacy(unittest.TestCase):
 @unittest.skipUnless(shutil.which('quickshell') and shutil.which('dbus-run-session') and Path('/usr/share/omarchy/shell/Ui').is_dir(), 'native runtime absent')
 def test_actual_activity_keeps_peer_markup_plain_and_does_not_fetch_or_log_url(self):
  hits=[]
  class Handler(http.server.BaseHTTPRequestHandler):
   def do_GET(self):hits.append(self.path);self.send_response(404);self.end_headers()
   def log_message(self,*unused):pass
  server=http.server.ThreadingHTTPServer(("127.0.0.1",0),Handler)
  thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
  try:
   for hostile in (False,True):
    with self.subTest(hostile=hostile),tempfile.TemporaryDirectory(prefix="omaconnect-activity-probe-") as temporary:
     hits.clear();fixture=Path(temporary)
     for name in ("Commons","Ui"):(fixture/name).symlink_to(Path("/usr/share/omarchy/shell")/name)
     (fixture/"components").symlink_to(ROOT/"components");(fixture/"TransferModel.js").symlink_to(ROOT/"TransferModel.js")
     (fixture/"runtime").mkdir(mode=0o700);shutil.copyfile(FIXTURE,fixture/"shell.qml")
     uri=f"http://127.0.0.1:{server.server_port}/owned-activity-image?token=OWNED-ACTIVITY-SENTINEL"
     peer=f'<img src="{uri}">Owned peer' if hostile else "Owned peer"
     env={"PATH":"/usr/bin","HOME":temporary,"XDG_CONFIG_HOME":temporary+"/config","XDG_DATA_HOME":temporary+"/data","XDG_CACHE_HOME":temporary+"/cache","XDG_RUNTIME_DIR":temporary+"/runtime","DBUS_SYSTEM_BUS_ADDRESS":"unix:path="+temporary+"/no-system-bus","QT_QPA_PLATFORM":"offscreen","QT_QUICK_BACKEND":"software","LANG":"C.UTF-8","SECURITY_ACTIVITY_PEER":peer}
     result=subprocess.run(["/usr/bin/dbus-run-session","--","/usr/bin/quickshell","--no-color","-p",temporary],env=env,text=True,capture_output=True,timeout=8)
     output=result.stdout+result.stderr
     self.assertEqual(result.returncode,0,output);self.assertIn("ACTIVITY_STATE_PASS",output,output);self.assertNotIn("ACTIVITY_STATE_FAIL",output,output)
     leaked=uri in output or "OWNED-ACTIVITY-SENTINEL" in output
     plain="ACTIVITY_PLAIN_FORMAT true" in output
     self.assertEqual((len(hits),leaked,plain if hostile else True),(0,False,True),"Expected zero URL requests, no URL/token logs, plain hostile peer text, and truthful accepted/unknown state")
  finally:server.shutdown();server.server_close();thread.join()

if __name__=="__main__":unittest.main()
