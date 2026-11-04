#!/usr/bin/env python3
"""Inspect native KDE Connect SFTP shares, then open one reviewed local URI.

KDE Connect 26.08.2 plugins/sftp/sftpplugin.h owns the fixed D-Bus API.
No storage path, transport, mount directory or file manager is invented here.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import signal
import stat
import sys
import threading
import time

from send_text import unique_object

MAX_INPUT = MAX_OUTPUT = 16384
MAX_SHARES = 16
TOTAL_SECONDS = 27
SERVICE = "org.kde.kdeconnect"
DEVICE = "org.kde.kdeconnect.device"
SFTP = DEVICE + ".sftp"
FIELDS = {"peerId", "providerOwner", "path", "name", "mountPath",
          "mountIdentity", "rootIdentity", "advertisements"}


class BrowseError(Exception):
    """Only fixed public error codes may cross the helper boundary."""


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, ensure_ascii=True, sort_keys=True,
                                     separators=(",", ":")).encode()).hexdigest()


def valid_path(value):
    return (isinstance(value, str) and value.startswith("/") and len(value) <= 4096
            and not any(ord(c) < 32 or 0xD800 <= ord(c) <= 0xDFFF for c in value)
            and os.path.normpath(value) == value and "//" not in value)


def validate_location(value, peer):
    if (not isinstance(value, dict) or set(value) != FIELDS
            or value["peerId"] != peer
            or not isinstance(value["providerOwner"], str)
            or not re.fullmatch(r":[0-9]+\.[0-9]+", value["providerOwner"])
            or not valid_path(value["path"]) or not valid_path(value["mountPath"])
            or not isinstance(value["name"], str) or not 1 <= len(value["name"]) <= 160
            or any(ord(c) < 32 for c in value["name"])
            or any(not isinstance(value[k], str) or not re.fullmatch(r"[0-9a-f]{64}", value[k])
                   for k in ("mountIdentity", "rootIdentity", "advertisements"))):
        raise BrowseError("invalid-input")
    return value


def read_request(stream):
    raw = stream.readline(MAX_INPUT + 1)
    try:
        if not raw or len(raw) > MAX_INPUT:
            raise ValueError()
        value = json.loads(raw.decode("utf-8"), object_pairs_hook=unique_object,
                           parse_constant=lambda unused: (_ for _ in ()).throw(ValueError()))
        if (not isinstance(value, dict) or value.get("operation") not in ("prepare", "open")
                or set(value) != ({"peerId", "operation", "location"} if value["operation"] == "open"
                                  else {"peerId", "operation"})
                or not isinstance(value["peerId"], str)
                or not re.fullmatch(r"[A-Za-z0-9_]{1,128}", value["peerId"])):
            raise ValueError()
        if value["operation"] == "open":
            validate_location(value["location"], value["peerId"])
        return value
    except (ValueError, UnicodeError, RecursionError, TypeError):
        raise BrowseError("invalid-input") from None


def mount_record(mount):
    """Read only kernel mount metadata. An existing local folder is insufficient."""
    with open("/proc/self/mountinfo", "r", encoding="utf-8") as stream:
        data = stream.read(1024 * 1024 + 1)
    if len(data) > 1024 * 1024:
        raise BrowseError("storage-unavailable")
    records = []
    for line in data.splitlines():
        parts = line.split()
        if len(parts) < 10 or "-" not in parts:
            continue
        unescaped = re.sub(r"\\([0-7]{3})", lambda match: chr(int(match[1], 8)), parts[4])
        separator = parts.index("-")
        if unescaped == mount and separator + 2 < len(parts):
            # Native KDE Connect's Unix mounter uses sshfs. Reject unrelated mounts.
            if parts[separator + 1] != "fuse.sshfs":
                raise BrowseError("storage-unavailable")
            records.append(parts)
    if len(records) != 1:
        raise BrowseError("storage-unavailable")
    return records[0]


def inspect_paths(mount, roots):
    """Keep all blocking filesystem probes in this bounded helper process."""
    if not valid_path(mount) or mount == "/":
        raise BrowseError("storage-unavailable")
    try:
        mount_path = Path(mount)
        if str(mount_path.resolve(strict=True)) != mount or not mount_path.is_dir():
            raise BrowseError("storage-unavailable")
        record = mount_record(mount)
        mounted = mount_path.stat(follow_symlinks=False)
        if not stat.S_ISDIR(mounted.st_mode):
            raise BrowseError("storage-unavailable")
        mount_identity = fingerprint([record, mounted.st_dev, mounted.st_ino])
        result = {}
        for root in roots:
            if not valid_path(root):
                raise BrowseError("storage-unavailable")
            path = Path(root)
            if (not path.is_relative_to(mount_path) or str(path.resolve(strict=True)) != root
                    or not path.is_dir()):
                raise BrowseError("storage-unavailable")
            item = path.stat(follow_symlinks=False)
            if not stat.S_ISDIR(item.st_mode) or item.st_dev != mounted.st_dev:
                raise BrowseError("storage-unavailable")
            result[root] = fingerprint([item.st_dev, item.st_ino])
        if mount_record(mount) != record:
            raise BrowseError("location-changed")
        return mount_identity, result
    except (OSError, RuntimeError, ValueError):
        raise BrowseError("storage-unavailable") from None


class NativeStorage:
    def __init__(self, peer, cancelled, deadline):
        if not os.environ.get("DBUS_SESSION_BUS_ADDRESS"):
            raise BrowseError("provider-unavailable")
        from gi.repository import Gio, GLib
        self.Gio, self.GLib = Gio, GLib
        self.cancelled, self.deadline = cancelled, deadline
        self.peer, self.path = peer, "/modules/kdeconnect/devices/" + peer
        self.bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        self.owner = self.call("/org/freedesktop/DBus", "org.freedesktop.DBus", "GetNameOwner",
                               "(s)", (SERVICE,), "(s)", destination="org.freedesktop.DBus")[0]

    def check_cancelled(self):
        if self.cancelled.is_set():
            raise BrowseError("cancelled")
        if time.monotonic() >= self.deadline:
            raise BrowseError("storage-timeout")

    def call(self, path, interface, member, signature=None, values=(), reply="()",
             timeout=5000, destination=None):
        self.check_cancelled()
        Gio, GLib = self.Gio, self.GLib
        try:
            result = self.bus.call_sync(destination or self.owner, path, interface, member,
                                        GLib.Variant(signature, values) if signature else None,
                                        GLib.VariantType.new(reply), Gio.DBusCallFlags.NO_AUTO_START,
                                        max(1, min(timeout, int((self.deadline - time.monotonic()) * 1000))), None)
            self.check_cancelled()
            return result.unpack()
        except GLib.Error as error:
            remote = Gio.DBusError.get_remote_error(error)
            if remote in {"org.freedesktop.DBus.Error.ServiceUnknown", "org.freedesktop.DBus.Error.NameHasNoOwner"}:
                code = "provider-unavailable"
            elif remote in {"org.freedesktop.DBus.Error.UnknownObject", "org.freedesktop.DBus.Error.UnknownInterface", "org.freedesktop.DBus.Error.UnknownMethod"}:
                code = "capability-unavailable"
            elif (remote in {"org.freedesktop.DBus.Error.NoReply", "org.freedesktop.DBus.Error.Timeout", "org.freedesktop.DBus.Error.TimedOut"}
                  or error.matches(Gio.io_error_quark(), Gio.IOErrorEnum.TIMED_OUT)):
                code = "storage-timeout"
            else:
                code = "storage-unavailable"
            raise BrowseError(code) from None

    def check_owner(self):
        owner = self.call("/org/freedesktop/DBus", "org.freedesktop.DBus", "GetNameOwner",
                          "(s)", (SERVICE,), "(s)", destination="org.freedesktop.DBus")[0]
        if owner != self.owner:
            raise BrowseError("location-changed")

    def check_peer(self):
        properties = self.call(self.path, "org.freedesktop.DBus.Properties", "GetAll",
                               "(s)", (DEVICE,), "(a{sv})")[0]
        if properties.get("isPaired") is not True:
            raise BrowseError("peer-unpaired")
        if properties.get("isReachable") is not True:
            raise BrowseError("peer-offline")
        loaded = self.call(self.path, DEVICE, "loadedPlugins", reply="(as)")[0]
        if "kdeconnect_sftp" not in loaded:
            raise BrowseError("capability-unavailable")

    def locations(self):
        path = self.path + "/sftp"
        if self.call(path, SFTP, "isMounted", reply="(b)")[0] is not True:
            raise BrowseError("storage-unavailable")
        mount = self.call(path, SFTP, "mountPoint", reply="(s)")[0]
        shares = self.call(path, SFTP, "getDirectories", reply="(a{sv})")[0]
        if not shares:
            raise BrowseError("no-shares")
        if len(shares) > MAX_SHARES:
            raise BrowseError("share-limit")
        if any(not valid_path(path) or not isinstance(name, str) or not 1 <= len(name) <= 160
               or any(ord(c) < 32 or 0xD800 <= ord(c) <= 0xDFFF for c in name)
               for path, name in shares.items()):
            raise BrowseError("storage-unavailable")
        mount_identity, roots = inspect_paths(mount, shares)
        advertised = fingerprint(shares)
        return [{"peerId": self.peer, "providerOwner": self.owner, "path": path, "name": shares[path],
                 "mountPath": mount, "mountIdentity": mount_identity,
                 "rootIdentity": roots[path], "advertisements": advertised} for path in sorted(shares)]


def launch_uri(uri):
    from gi.repository import Gio, GLib
    try:
        if Gio.AppInfo.get_default_for_type("inode/directory", False) is None:
            raise BrowseError("opener-unavailable")
        if not Gio.AppInfo.launch_default_for_uri(uri, None):
            raise BrowseError("opener-unavailable")
    except GLib.Error:
        raise BrowseError("opener-unavailable") from None


def execute(request, cancelled, deadline):
    native = NativeStorage(request["peerId"], cancelled, deadline)
    native.check_peer()
    if request["operation"] == "prepare":
        if not native.call(native.path + "/sftp", SFTP, "mountAndWait", reply="(b)", timeout=20000)[0]:
            raise BrowseError("mount-failed")
        native.check_peer()
        return {"state": "prepared", "error": "", "peerId": request["peerId"], "locations": native.locations()}
    expected = request["location"]
    if expected["providerOwner"] != native.owner or expected not in native.locations():
        raise BrowseError("location-changed")
    identity, roots = inspect_paths(expected["mountPath"], [expected["path"]])
    if identity != expected["mountIdentity"] or roots[expected["path"]] != expected["rootIdentity"]:
        raise BrowseError("location-changed")
    # Filesystem probes can block. Recheck live peer and well-known ownership
    # afterward, while all device calls remain pinned to the captured connection.
    native.check_peer()
    native.check_owner()
    native.check_cancelled()
    # Validation and desktop launch are separate, non-atomic operations.
    # Once the desktop has accepted a launch, cancellation cannot recall its window.
    launch_uri(Path(expected["path"]).as_uri())
    return {"state": "opened", "error": ""}


def emit(value):
    encoded = json.dumps(value, ensure_ascii=True, separators=(",", ":"))
    if len(encoded) > MAX_OUTPUT:
        value = {"state": "failed", "error": "share-limit"}
        encoded = '{"state":"failed","error":"share-limit"}'
    print(encoded, flush=True)
    return int(value["state"] == "failed")


def main():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    cancelled, done = threading.Event(), threading.Event()
    signal.signal(signal.SIGTERM, lambda *unused: cancelled.set())
    signal.signal(signal.SIGINT, lambda *unused: cancelled.set())
    result = []
    deadline = time.monotonic() + TOTAL_SECONDS

    def run():
        try:
            if len(sys.argv) != 1:
                raise BrowseError("invalid-input")
            result.append(execute(read_request(sys.stdin.buffer), cancelled, deadline))
        except BrowseError as error:
            result.append({"state": "failed", "error": str(error)})
        except (ImportError, ValueError):
            result.append({"state": "failed", "error": "provider-unavailable"})
        except Exception:
            result.append({"state": "failed", "error": "storage-unavailable"})
        finally:
            done.set()

    # A daemon worker bounds even stalled FUSE probes or bus connection setup.
    threading.Thread(target=run, daemon=True).start()
    while not done.wait(0.02):
        if cancelled.is_set() or time.monotonic() >= deadline:
            timed_out = not cancelled.is_set()
            cancelled.set()
            emit({"state": "failed", "error": "storage-timeout" if timed_out else "cancelled"})
            return 1
    return emit(result[0])


if __name__ == "__main__":
    raise SystemExit(main())
