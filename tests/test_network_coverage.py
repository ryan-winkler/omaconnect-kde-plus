"""Provider coverage uses fake buses and launchers; no host network actions."""
import importlib.util
from pathlib import Path
import sys
import shutil
import subprocess
import unittest
from unittest.mock import patch

SCRIPTS = Path(__file__).parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))
try:
    import manage_addresses as addresses
    import open_network_owner as owners
finally:
    sys.path.pop(0)


class NetworkCoverage(unittest.TestCase):
    def test_tailscale_shared_range_requires_explicit_source(self):
        for value in ["100.64.0.1", "100.127.255.254"]:
            self.assertEqual(addresses.private_address(value, source="tailscale"), value)
            for source in ["manual", "bth", "wireguard"]:
                with self.assertRaises(addresses.AddressError):
                    addresses.private_address(value, source=source)
        for value in ["100.63.255.255", "100.128.0.1", "8.8.8.8", "100.64.0.0/10", "100.64.1.1;id", "fe80::1%eth0"]:
            with self.assertRaises(addresses.AddressError):
                addresses.private_address(value, source="tailscale")

    def test_tailscale_add_auto_remove_keep_explicit_source(self):
        import tempfile
        class Bus:
            current = ["external-existing"]
            def read(self): return self.current[:]
            def write(self, values): self.current = values[:]
        bus = Bus()
        base = {"peer_id":"fixture", "address":"100.80.1.2", "source":"tailscale", "approved":True}
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary) / "data"
            result = addresses.manage({"changes":[dict(base, op="add", auto_discover=False)]}, directory, bus)
            self.assertEqual(result["addresses"][0]["source"], "tailscale")
            result = addresses.manage({"changes":[dict(base, op="auto", auto_discover=True)]}, directory, bus)
            self.assertTrue(result["addresses"][0]["auto_discover"])
            result = addresses.manage({"changes":[dict(base, op="remove", remove_from_kde=True)]}, directory, bus)
            self.assertEqual(result["addresses"], [])
            self.assertEqual(bus.current, ["external-existing"])

    def test_existing_private_wireguard_and_bth_policy_remains(self):
        for source in addresses.SOURCES:
            self.assertEqual(addresses.private_address("10.8.0.4", source=source), "10.8.0.4")
        with self.assertRaisesRegex(addresses.AddressError, "bth-ipv6-disabled"):
            addresses.private_address("fd00::4", source="bth")
        self.assertEqual(addresses.private_address("fd7a:115c:a1e0::4", source="tailscale"), "fd7a:115c:a1e0::4")

    def test_tailscale_opens_exact_existing_panel_only_on_ok(self):
        with patch.object(owners, "bounded_command", return_value=b"ok\n") as command:
            self.assertTrue(owners.open_owner("tailscale")["ok"])
            self.assertEqual(command.call_args.args[0], ["/usr/bin/omarchy-shell", "shell", "summon", "omarchy.tailscale", "{}"])
        with patch.object(owners, "bounded_command", return_value=b"unknown\n"):
            self.assertFalse(owners.open_owner("tailscale")["ok"])

    def test_wireguard_opens_native_editor_without_profile_or_toggle(self):
        with patch.object(owners.Path, "is_file", return_value=True), patch.object(owners.subprocess, "Popen") as launch:
            self.assertTrue(owners.open_owner("wireguard")["ok"])
            self.assertEqual(launch.call_args.args, (["/usr/bin/nm-connection-editor"],))
        with patch.object(owners.Path, "is_file", return_value=False), patch.object(owners.subprocess, "Popen") as launch:
            self.assertFalse(owners.open_owner("wireguard")["ok"])
            launch.assert_not_called()

    def test_unknown_owner_never_launches(self):
        with patch.object(owners.subprocess, "Popen") as launch, patch.object(owners, "bounded_command") as command:
            self.assertFalse(owners.open_owner("wireguard; id")["ok"])
            launch.assert_not_called()
            command.assert_not_called()

    @unittest.skipUnless(shutil.which("node"), "Node model-check runtime absent")
    def test_qml_response_model_keeps_tailscale_provenance(self):
        model = SCRIPTS.parent / "DiscoveryModel.js"
        code = r'''const fs = require("node:fs"), vm = require("node:vm"), assert = require("node:assert/strict");
const ctx = {}; vm.createContext(ctx);
vm.runInContext(fs.readFileSync(process.argv[1], "utf8").replace(/^\.pragma library\s*/, ""), ctx);
const row = {peer_id:"fixture", address:"100.80.1.2", source:"tailscale", auto_discover:true, manual_baseline:false, registered:true};
const reply = {schema_version:1, ok:true, addresses:[row], custom_addresses:[row.address]};
const parsed = ctx.parse(JSON.stringify(reply));
assert.equal(parsed.addresses[0].source, "tailscale");
assert.equal(ctx.approvedChanges(parsed.addresses)[0].source, "tailscale");
row.source = "unknown"; assert.equal(ctx.parse(JSON.stringify(reply)), null);
'''
        result = subprocess.run(["node", "-e", code, str(model)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
