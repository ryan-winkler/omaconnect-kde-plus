"""Owned private-bus SFTP fixture. No mount, phone access or desktop app launch."""
import json
import os
from pathlib import Path
import sys
import tempfile
import threading
import time

import gi
gi.require_version("Gio", "2.0")
gi.require_version("GLib", "2.0")
from gi.repository import Gio, GLib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import browse_phone_files as helper

mode = sys.argv[1]
PEER = "Owned_phone_123"
temporary = tempfile.TemporaryDirectory()
mount = Path(temporary.name) / "mounted phone"
mount.mkdir()
root = mount / "shared #one"
root.mkdir()
other = mount / "second"
other.mkdir()
outside = Path(temporary.name) / "outside"
outside.mkdir()
link = mount / "link"
link.symlink_to(outside, target_is_directory=True)
record = ["42", "2", "0:99", "/", str(mount), "rw", "-", "fuse.sshfs", "owned", "rw"]
opened, calls, results = [], [], []
cancelled = threading.Event()
mount_reads = 0
visibility_failures = {
    "mount-visibility-cancelled": "cancelled",
    "owner-replaced-during-visibility": "location-changed",
    "offline-during-visibility": "peer-offline",
}


def mount_record(path):
    global mount_reads, reachable
    mount_reads += 1
    delay_first_probe = mode == "mount-visible-late" or mode in visibility_failures
    if mode == "mount-never-visible" or (mount_reads == 1 and delay_first_probe):
        if mode == "mount-visibility-cancelled":
            cancelled.set()
        elif mode == "owner-replaced-during-visibility":
            change_owner(True)
        elif mode == "offline-during-visibility":
            reachable = False
        raise helper.MountNotVisible(path)
    return list(record)


helper.mount_record = mount_record
helper.launch_uri = lambda uri: opened.append(uri)
paired, reachable, mounted = mode != "unpaired", mode != "offline", mode != "nonmount"
shares = {str(root): "Shared storage"}
if mode == "multiple":
    shares[str(other)] = "Other storage"
elif mode == "no-shares":
    shares = {}
elif mode == "escape":
    shares = {str(outside): "Untrusted name"}
elif mode == "symlink":
    shares = {str(link): "Untrusted name"}
elif mode == "share-limit":
    shares = {str(mount / str(index)): "Storage" for index in range(17)}
elif mode == "remote-name":
    shares = {str(root): "<b>Phone</b>"}

bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
loop = GLib.MainLoop()
held = []


def change_owner(replacement):
    """Release or replace the private-bus provider name while retaining the old connection."""
    bus.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "ReleaseName",
                  GLib.Variant("(s)", (helper.SERVICE,)), GLib.VariantType.new("(u)"),
                  Gio.DBusCallFlags.NO_AUTO_START, 1000, None)
    if replacement:
        connection = Gio.DBusConnection.new_for_address_sync(
            os.environ["DBUS_SESSION_BUS_ADDRESS"],
            Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT | Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION,
            None, None)
        held.append(connection)
        connection.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "RequestName",
                             GLib.Variant("(su)", (helper.SERVICE, 0)), GLib.VariantType.new("(u)"),
                             Gio.DBusCallFlags.NO_AUTO_START, 1000, None)
        owner = bus.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "GetNameOwner",
                              GLib.Variant("(s)", (helper.SERVICE,)), GLib.VariantType.new("(s)"),
                              Gio.DBusCallFlags.NO_AUTO_START, 1000, None).unpack()[0]
        assert owner == connection.get_unique_name() and owner != bus.get_unique_name()
    else:
        owned = bus.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "NameHasOwner",
                             GLib.Variant("(s)", (helper.SERVICE,)), GLib.VariantType.new("(b)"),
                             Gio.DBusCallFlags.NO_AUTO_START, 1000, None).unpack()[0]
        assert not owned


inspect_paths = helper.inspect_paths
probe_count = 0


def inspect_and_change_state(mount_path, roots):
    """Inject owner or reachability changes after the final blocking path probe."""
    global probe_count, reachable
    result = inspect_paths(mount_path, roots)
    probe_count += 1
    # Prepare probes once; open probes advertised roots and then the selected root.
    # Change live state after that final blocking probe, while the old unique
    # D-Bus connection remains alive and can still answer every device request.
    if probe_count == 3:
        if mode in ("owner-lost-during-probe", "owner-replaced-during-probe"):
            change_owner(mode == "owner-replaced-during-probe")
        elif mode == "offline-during-probe":
            reachable = False
    return result


helper.inspect_paths = inspect_and_change_state


def method(connection, sender, path, interface, member, parameters, invocation):
    """Serve fake native storage methods and inject bounded timeout, cancellation and error cases."""
    global reachable
    calls.append((path, interface, member))
    if mode == "timeout" and member == "loadedPlugins":
        held.append(invocation)
        return
    if mode == "remote-error" and member == "mountAndWait":
        invocation.return_dbus_error("org.example.Rejected", "PRIVATE REMOTE DIAGNOSTIC")
        return
    if mode == "unsupported-method" and member == "isMounted":
        invocation.return_dbus_error("org.freedesktop.DBus.Error.UnknownMethod", "PRIVATE REMOTE DIAGNOSTIC")
        return
    if member == "mountAndWait" and mode == "cancelled-mount":
        cancelled.set()
    if member == "mountAndWait" and mode == "offline-during-mount":
        reachable = False
    reply, value = {
        "loadedPlugins": ("(as)", ([] if mode == "unsupported" else ["kdeconnect_sftp"],)),
        "mountAndWait": ("(b)", (mode != "mount-failed",)),
        "isMounted": ("(b)", (mounted,)),
        "mountPoint": ("(s)", (str(mount),)),
        "getDirectories": ("(a{sv})", ({path: GLib.Variant("s", name) for path, name in shares.items()},)),
    }[member]
    invocation.return_value(GLib.Variant(reply, value))


def prop(connection, sender, path, interface, name):
    """Report the fixture's mutable pairing or reachability state to native property reads."""
    return GLib.Variant("b", paired if name == "isPaired" else reachable)


if mode != "unavailable":
    bus.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "RequestName",
                  GLib.Variant("(su)", (helper.SERVICE, 0)), GLib.VariantType.new("(u)"),
                  Gio.DBusCallFlags.NO_AUTO_START, 1000, None)
    device = '<node><interface name="org.kde.kdeconnect.device"><property name="isPaired" type="b" access="read"/><property name="isReachable" type="b" access="read"/><method name="loadedPlugins"><arg type="as" direction="out"/></method></interface></node>'
    storage = '<node><interface name="org.kde.kdeconnect.device.sftp">' + ''.join(
        '<method name="' + member + '"><arg type="' + signature + '" direction="out"/></method>'
        for member, signature in [("mountAndWait", "b"), ("isMounted", "b"), ("mountPoint", "s"), ("getDirectories", "a{sv}")]) + '</interface></node>'
    path = "/modules/kdeconnect/devices/" + PEER
    bus.register_object(path, Gio.DBusNodeInfo.new_for_xml(device).interfaces[0], method, prop, None)
    bus.register_object(path + "/sftp", Gio.DBusNodeInfo.new_for_xml(storage).interfaces[0], method, None, None)


def run():
    """Exercise prepare then open against temporary roots and verify each injected mode's exact outcome."""
    global paired, reachable, mounted, shares
    started = time.monotonic()
    error = None
    try:
        prepared = helper.execute({"peerId": PEER, "operation": "prepare"}, cancelled, started + 27)
        assert mode not in visibility_failures, "Prepare accepted an invalidated mount"
        assert prepared["state"] == "prepared"
        locations = prepared["locations"]
        assert len(locations) == (2 if mode == "multiple" else 1)
        assert not opened, "prepare launched an application"
        selected = next(item for item in locations if item["path"] == str(root))
        if mode == "changed-advertisement":
            shares[str(other)] = "New root"
        elif mode == "changed-name":
            shares[str(root)] = "Changed name"
        elif mode == "stale-mount":
            record[0] = "99"
        elif mode == "stale-root":
            root.rename(mount / "old")
            root.mkdir()
        elif mode == "offline-open":
            reachable = False
        elif mode == "unpaired-open":
            paired = False
        elif mode == "unmounted-open":
            mounted = False
        elif mode == "owner-changed":
            selected["providerOwner"] = ":999.999"
        elif mode == "cancelled":
            cancelled.set()
        elif mode == "missing-opener":
            def reject(uri):
                raise helper.BrowseError("opener-unavailable")
            helper.launch_uri = reject
        opened_result = helper.execute({"peerId": PEER, "operation": "open", "location": selected}, cancelled, started + 27)
        assert opened_result == {"state": "opened", "error": ""}
        assert opened == [root.as_uri()]
        assert sum(call[2] == "mountAndWait" for call in calls) == 1, "open remounted"
    except helper.BrowseError as failure:
        error = str(failure)
    except Exception as failure:
        results.append({"passed": False, "error": type(failure).__name__, "detail": str(failure)})
        GLib.idle_add(loop.quit)
        return
    expected = {
        "offline": "peer-offline", "unpaired": "peer-unpaired", "unsupported": "capability-unavailable",
        "unsupported-method": "capability-unavailable", "unavailable": "provider-unavailable",
        "timeout": "storage-timeout", "no-shares": "no-shares", "share-limit": "share-limit",
        "escape": "storage-unavailable", "symlink": "storage-unavailable", "nonmount": "storage-unavailable",
        "mount-failed": "mount-failed", "remote-error": "storage-unavailable",
        "mount-never-visible": "storage-unavailable", **visibility_failures,
        "changed-advertisement": "location-changed", "changed-name": "location-changed",
        "stale-mount": "location-changed", "stale-root": "location-changed", "owner-changed": "location-changed",
        "offline-open": "peer-offline", "unpaired-open": "peer-unpaired", "unmounted-open": "storage-unavailable",
        "cancelled": "cancelled", "missing-opener": "opener-unavailable",
        "cancelled-mount": "cancelled", "offline-during-mount": "peer-offline",
        "owner-lost-during-probe": "provider-unavailable",
        "owner-replaced-during-probe": "location-changed", "offline-during-probe": "peer-offline",
    }.get(mode)
    passed = error == expected and (not opened if expected else len(opened) == 1)
    if mode == "timeout":
        passed = passed and 4.5 <= time.monotonic() - started < 6.5
    if mode in ("mount-visible-late", "mount-never-visible") or mode in visibility_failures:
        passed = passed and sum(call[2] == "mountAndWait" for call in calls) == 1
    if mode == "mount-never-visible":
        passed = passed and helper.MOUNT_VISIBILITY_SECONDS <= time.monotonic() - started < 2
    results.append({"passed": passed, "error": error, "mode": mode})
    GLib.idle_add(loop.quit)


GLib.idle_add(lambda: (threading.Thread(target=run, daemon=True).start(), False)[1])
GLib.timeout_add_seconds(9, loop.quit)
loop.run()
temporary.cleanup()
print(json.dumps(results[0] if results else {"passed": False, "error": "fixture-timeout"}))
raise SystemExit(0 if results and results[0]["passed"] else 1)
