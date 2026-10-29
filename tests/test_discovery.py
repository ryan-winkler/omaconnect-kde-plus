"""Exercise the real address boundary; all state and bus tools are substituted."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from concurrent.futures import ThreadPoolExecutor

ROOT = Path(__file__).parents[1]
SPEC = importlib.util.spec_from_file_location("addresses", ROOT / "scripts/manage_addresses.py")
M = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(M)


class FakeBus:
    def __init__(self, addresses=()):
        self.addresses = list(addresses)
        self.writes = []
        self.reads = 0
        self.drift = False

    def read(self):
        self.reads += 1
        if self.drift:
            self.addresses.append("external-%d" % self.reads)
        return self.addresses[:]

    def write(self, addresses):
        self.writes.append(addresses[:])
        self.addresses = addresses[:]


class AddressBoundary(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.directory = Path(self.temp.name) / "Omaconnect.plus"
        self.bus = FakeBus(["192.168.1.2", "external-host"])

    def tearDown(self):
        self.temp.cleanup()

    def run_request(self, changes):
        return M.manage({"changes": changes}, self.directory, self.bus)

    def add(self, address="10.23.0.10", peer="peer-one", **extra):
        return dict(op="add", peer_id=peer, address=address, source="manual", auto_discover=False, approved=True, **extra)

    def test_private_literals_only_and_explicit_approval(self):
        for value in ["8.8.8.8", "100.64.1.2", "127.0.0.1", "::1", "192.168.1.0/24", "--help", "https://10.0.0.1", "10.0.0.1;id", "fe80::1%eth0"]:
            with self.assertRaises(M.AddressError):
                self.run_request([self.add(value)])
        change = self.add(); change["approved"] = False
        with self.assertRaises(M.AddressError):
            self.run_request([change])
        self.assertEqual(self.bus.writes, [])

    def test_batch_preserves_external_entries_and_all_additions(self):
        result = self.run_request([self.add(), self.add("10.23.0.11")])
        self.assertEqual(self.bus.addresses, ["192.168.1.2", "external-host", "10.23.0.10", "10.23.0.11"])
        self.assertEqual(len(self.bus.writes), 1)
        self.assertTrue(all(row["registered"] for row in result["addresses"]))
        self.assertEqual(self.directory.stat().st_mode & 0o777, 0o700)
        self.assertEqual((self.directory / "addresses.json").stat().st_mode & 0o777, 0o600)

    def test_baseline_and_shared_addresses_are_never_removed(self):
        self.run_request([self.add("192.168.1.2"), self.add(), self.add(peer="peer-two")])
        self.run_request([dict(op="remove", peer_id="peer-one", address="192.168.1.2", remove_from_kde=True, approved=True), dict(op="remove", peer_id="peer-one", address="10.23.0.10", remove_from_kde=True, approved=True)])
        self.assertIn("192.168.1.2", self.bus.addresses)
        self.assertIn("10.23.0.10", self.bus.addresses)

    def test_removal_is_metadata_only_until_explicit_review(self):
        self.run_request([self.add()])
        self.run_request([dict(op="remove", peer_id="peer-one", address="10.23.0.10")])
        self.assertIn("10.23.0.10", self.bus.addresses)
        self.run_request([self.add("10.23.0.11")])
        self.run_request([dict(op="remove", peer_id="peer-one", address="10.23.0.11", remove_from_kde=True, approved=True)])
        self.assertNotIn("10.23.0.11", self.bus.addresses)

    def test_changing_external_state_exhausts_two_retries_without_write(self):
        self.bus.drift = True
        with self.assertRaisesRegex(M.AddressError, "conflict"):
            self.run_request([self.add()])
        self.assertEqual(self.bus.writes, [])
        self.assertEqual(self.bus.reads, 6)

    def test_corrupt_metadata_is_preserved_and_blocks_mutation(self):
        self.directory.mkdir(mode=0o700)
        path = self.directory / "addresses.json"
        path.write_text("broken")
        with self.assertRaisesRegex(M.AddressError, "metadata-invalid"):
            self.run_request([self.add()])
        self.assertEqual(path.read_text(), "broken")
        self.assertEqual(self.bus.writes, [])

    def test_limits_and_bad_batches_do_not_mutate(self):
        with self.assertRaises(M.AddressError):
            self.run_request([self.add("10.23.0.%d" % i) for i in range(1, 34)])
        with self.assertRaises(M.AddressError):
            self.run_request([self.add(), self.add("8.8.8.8")])
        self.assertEqual(self.bus.writes, [])

    def test_exact_host_routes_are_candidates_only(self):
        self.assertEqual(M.private_address("10.23.0.10/32", host_route=True), "10.23.0.10")
        for address in ["10.23.0.0/24", "0.0.0.0/0", "fd00::1/128"]:
            with self.assertRaises(M.AddressError):
                M.private_address(address, host_route=True, source="bth")

    def fake_tool(self, body):
        tool = Path(self.temp.name) / "busctl"
        tool.write_text("#!/usr/bin/python3\n" + body)
        tool.chmod(0o700)
        return str(tool)

    def test_real_subprocess_argv_json_and_output_bounds(self):
        old = M.BUSCTL
        try:
            M.BUSCTL = self.fake_tool('import sys, json\nassert sys.argv[1:5] == ["--user", "--auto-start=no", "--json=short", "get-property"]\nprint(json.dumps({"type":"as","data":["external,quote\\\"host", "10.1.1.1"]}))\n')
            self.assertEqual(M.KdeBus(time.monotonic()+1).read(), ['external,quote"host', '10.1.1.1'])
            tool = self.fake_tool('import sys\nsys.stdout.write("x"*262145)\n')
            with self.assertRaisesRegex(M.AddressError, "provider-output-limit"):
                M.bounded_command([tool], time.monotonic()+1)
            tool = self.fake_tool('import time\ntime.sleep(2)\n')
            with self.assertRaisesRegex(M.AddressError, "address-timeout"):
                M.bounded_command([tool], time.monotonic()+.05)
        finally:
            M.BUSCTL = old

    def test_concurrent_writers_are_serialized_by_owner_lock(self):
        old = M.BUSCTL
        state = Path(self.temp.name) / "fake-bus.json"
        state.write_text('["external-host"]')
        try:
            M.BUSCTL = self.fake_tool("import sys,json,time\nfrom pathlib import Path\np=Path("+repr(str(state))+")\na=sys.argv[1:]\nif 'get-property' in a: print(json.dumps({'type':'as','data':json.loads(p.read_text())}))\nelif 'set-property' in a:\n time.sleep(.02)\n i=a.index('as'); assert int(a[i+1])==len(a[i+2:]); p.write_text(json.dumps(a[i+2:]))\nelse: raise SystemExit(2)\n")
            with ThreadPoolExecutor(max_workers=4) as pool:
                results = list(pool.map(lambda i: M.manage({"changes":[self.add("10.23.0.%d" % i)]}, self.directory), range(1,5)))
            self.assertTrue(all(r["ok"] for r in results))
            self.assertEqual(set(json.loads(state.read_text())), {"external-host", "10.23.0.1", "10.23.0.2", "10.23.0.3", "10.23.0.4"})
        finally:
            M.BUSCTL = old

    @unittest.skipUnless(shutil.which("dbus-run-session"), "private D-Bus test tool absent")
    def test_real_busctl_against_private_kde_property(self):
        probe = subprocess.run([sys.executable, "-c", "import gi"], capture_output=True)
        if probe.returncode:
            self.skipTest("Gio fixture runtime absent; helper does not require it")
        env = dict(os.environ, XDG_DATA_HOME=self.temp.name, TEST_KDE_HELPER=str(ROOT / "scripts/manage_addresses.py"))
        result = subprocess.run(["dbus-run-session", "--", sys.executable, __file__, "--fake-session"], env=env, capture_output=True, text=True, timeout=12)
        self.assertEqual(result.returncode, 0, result.stderr)
        reply = json.loads(result.stdout)
        self.assertTrue(reply["ok"])
        self.assertEqual(reply["custom_addresses"], ['external,quote"host', '10.23.0.10', '10.23.0.11'])

    @unittest.skipUnless(shutil.which("quickshell"), "Quickshell runtime absent")
    def test_native_qml_queue_and_disabled_timer_use_owned_fixtures(self):
        fixture = Path(self.temp.name) / "qml"
        fixture.mkdir()
        (fixture / "scripts").mkdir()
        for name in ("DiscoveryController.qml", "DiscoveryModel.js"):
            shutil.copy(ROOT / name, fixture / name)
        log = fixture / "requests.jsonl"
        (fixture / "scripts/manage_addresses.py").write_text('import json,sys\nfrom pathlib import Path\nr=json.load(sys.stdin)\np=Path('+repr(str(log))+')\nwith p.open("a") as f: f.write(json.dumps(r)+"\\n")\nprint(json.dumps({"schema_version":1,"ok":True,"addresses":[{"peer_id":"fixture","address":"10.1.1.1","source":"bth","auto_discover":True,"manual_baseline":False,"registered":True}],"custom_addresses":["10.1.1.1"]}))\n')
        nm = fixture / "nmcli"
        nm.write_text("#!/usr/bin/python3\nimport time\nprint('route changed',flush=True)\ntime.sleep(30)\n")
        nm.chmod(0o700)
        (fixture / "shell.qml").write_text('''import QtQuick
import Quickshell
ShellRoot {
 property int step: 0
 property int ticks: 0
 DiscoveryController { id: discovery; nmMonitorPath: "''' + str(nm) + '''" }
 Timer { interval: 30; repeat: true; running: true; onTriggered: {
  ticks++
  if(ticks > 180) { console.error("FIXTURE_TIMEOUT"); Qt.quit(); return }
  if(step === 0) { discovery.panelOpened=true; step=1 }
  else if(step === 1 && !discovery.busy && discovery.ready) { discovery.autoDiscoveryEnabled=true; step=2 }
  else if(step === 2 && !discovery.busy) { discovery.addAddress("fixture","10.1.1.2","manual",false); discovery.addAddress("fixture","10.1.1.3","manual",false); step=3 }
  else if(step === 3 && !discovery.busy) { discovery.routeChanged(); discovery.routeChanged(); discovery.panelOpened=false; discovery.autoDiscoveryEnabled=false; step=4; ticks=0 }
  else if(step === 4 && ticks > 80) { console.log("FIXTURE_PASS"); Qt.quit() }
 } }
}''')
        env = dict(os.environ, QT_QPA_PLATFORM="offscreen", XDG_CONFIG_HOME=str(fixture / "config"), XDG_CACHE_HOME=str(fixture / "cache"), XDG_STATE_HOME=str(fixture / "state"))
        run = subprocess.run(["dbus-run-session", "--", "quickshell", "--no-color", "-p", str(fixture)], env=env, capture_output=True, text=True, timeout=9)
        self.assertIn("FIXTURE_PASS", run.stdout + run.stderr)
        self.assertNotIn("FIXTURE_TIMEOUT", run.stdout + run.stderr)
        requests = [json.loads(line) for line in log.read_text().splitlines()]
        self.assertEqual(len(requests), 4)
        self.assertEqual(requests[0], {"changes": []})
        self.assertEqual([r["changes"][0]["address"] for r in requests[1:]], ["10.1.1.1", "10.1.1.2", "10.1.1.3"])


def fake_session():
    """Own only a private session; drive the production helper and /usr/bin/busctl."""
    from gi.repository import Gio, GLib
    connection = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    connection.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "RequestName", GLib.Variant("(su)", ("org.kde.kdeconnect", 0)), None, Gio.DBusCallFlags.NONE, 1000, None)
    xml = '<node><interface name="org.kde.kdeconnect.daemon"><property name="customDevices" type="as" access="readwrite"/></interface></node>'
    info = Gio.DBusNodeInfo.new_for_xml(xml).interfaces[0]
    values = ['external,quote"host']

    def get_prop(*_args):
        return GLib.Variant("as", values)

    def set_prop(_connection, _sender, _path, _interface, _name, value):
        values[:] = value.unpack()
        return True

    connection.register_object("/modules/kdeconnect", info, None, get_prop, set_prop)
    request = {"changes": [dict(op="add", peer_id="fixture-peer", address=address, source="bth", auto_discover=True, approved=True) for address in ("10.23.0.10", "10.23.0.11")]}
    process = subprocess.Popen([sys.executable, os.environ["TEST_KDE_HELPER"]], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    process.stdin.write(json.dumps(request))
    process.stdin.close()
    loop = GLib.MainLoop()

    def done():
        if process.poll() is None:
            return True
        print(process.stdout.read(), end="")
        loop.quit()
        return False

    GLib.timeout_add(20, done)
    GLib.timeout_add_seconds(8, lambda: (process.kill(), loop.quit(), False)[-1])
    loop.run()
    return process.returncode or 0


if __name__ == "__main__":
    if "--fake-session" in sys.argv:
        sys.exit(fake_session())
    unittest.main()
