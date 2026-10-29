#!/usr/bin/python3
"""Bounded KDE customDevices reconciliation. No discovery, daemon start or pairing.

Each stdin JSON request contains <=32 explicitly approved changes. Metadata belongs
to this fork; KDE remains the address owner. The owner lock serializes fork writers.
# ponytail: KDE has no CAS; unrelated simultaneous writers can still race between
# the last read and Set. Retry twice, preserve observed external entries, and report
# conflicts. A globally atomic guarantee requires an owner-side KDE API.
"""
import fcntl
import ipaddress
import json
import os
from pathlib import Path
import re
import selectors
import signal
import stat
import subprocess
import sys
import tempfile
import time

MAX_BYTES = 262144
MAX_ROWS = 256
BUSCTL = "/usr/bin/busctl"
DEST = "org.kde.kdeconnect"
OBJECT = "/modules/kdeconnect"
INTERFACE = "org.kde.kdeconnect.daemon"
SOURCES = ("manual", "bth", "wireguard", "tailscale")
TAILSCALE_IPV4 = ipaddress.ip_network("100.64.0.0/10")
PRIVATE = tuple(ipaddress.ip_network(n) for n in ("10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "fc00::/7"))


class AddressError(Exception):
    pass


def private_address(value, host_route=False, source="manual"):
    if not isinstance(value, str) or len(value) > 80 or "%" in value:
        raise AddressError("address-invalid")
    try:
        if host_route:
            interface = ipaddress.ip_interface(value)
            if interface.network.prefixlen != interface.max_prefixlen:
                raise ValueError()
            address = interface.ip
        else:
            address = ipaddress.ip_address(value)
    except ValueError:
        raise AddressError("address-invalid") from None
    if address.is_loopback or address.is_link_local or address.is_multicast or address.is_unspecified or not (any(address.version == n.version and address in n for n in PRIVATE) or (source == "tailscale" and address.version == 4 and address in TAILSCALE_IPV4)):
        raise AddressError("address-not-private")
    if source == "bth" and address.version == 6:
        raise AddressError("bth-ipv6-disabled")
    return str(address)


def peer_id(value):
    if not isinstance(value, str) or not re.fullmatch(r"[A-Za-z0-9_.:-]{1,256}", value):
        raise AddressError("peer-invalid")
    return value


def changes_from(request):
    if not isinstance(request, dict) or set(request) - {"changes"}:
        raise AddressError("request-invalid")
    changes = request.get("changes", [])
    if not isinstance(changes, list) or len(changes) > 32:
        raise AddressError("batch-limit")
    result = []
    for item in changes:
        if not isinstance(item, dict) or item.get("op") not in ("add", "remove", "auto"):
            raise AddressError("request-invalid")
        op = item["op"]
        source = item.get("source", "manual")
        if source not in SOURCES:
            raise AddressError("source-invalid")
        address = private_address(item.get("address"), source=source)
        peer = peer_id(item.get("peer_id"))
        if op in ("add", "auto") and item.get("approved") is not True:
            raise AddressError("approval-required")
        if op in ("add", "auto") and type(item.get("auto_discover", False)) is not bool:
            raise AddressError("request-invalid")
        if type(item.get("remove_from_kde", False)) is not bool:
            raise AddressError("request-invalid")
        if item.get("remove_from_kde") and item.get("approved") is not True:
            raise AddressError("approval-required")
        result.append(dict(item, peer_id=peer, address=address, source=source))
    return result


def bounded_command(argv, deadline):
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise AddressError("address-timeout")
    try:
        process = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError:
        raise AddressError("provider-missing") from None
    output = bytearray()
    complete = False
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ)
            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0 or not selector.select(remaining):
                    raise AddressError("address-timeout")
                chunk = os.read(process.stdout.fileno(), 8192)
                if not chunk:
                    break
                output.extend(chunk)
                if len(output) > MAX_BYTES:
                    raise AddressError("provider-output-limit")
        if process.wait(timeout=max(.001, deadline-time.monotonic())) != 0:
            raise AddressError("provider-unavailable")
        complete = True
    except subprocess.TimeoutExpired:
        raise AddressError("address-timeout") from None
    finally:
        if not complete:
            # This process owns a new session. Reap descendants as well as a shell
            # wrapper, including when that wrapper exited before its child.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        process.wait()
        process.stdout.close()
    return bytes(output)


class KdeBus:
    def __init__(self, deadline):
        self.deadline = deadline

    def read(self):
        raw = bounded_command([BUSCTL, "--user", "--auto-start=no", "--json=short", "get-property", DEST, OBJECT, INTERFACE, "customDevices"], self.deadline)
        try:
            data = json.loads(raw)
            addresses = data["data"]
            if data["type"] != "as" or not isinstance(addresses, list) or len(addresses) > MAX_ROWS:
                raise ValueError()
            if any(not isinstance(a, str) or not a or len(a) > 1024 or any(ord(c) < 32 for c in a) for a in addresses):
                raise ValueError()
            return addresses
        except (ValueError, KeyError, TypeError):
            raise AddressError("provider-reply-invalid") from None

    def write(self, addresses):
        bounded_command([BUSCTL, "--user", "--auto-start=no", "set-property", DEST, OBJECT, INTERFACE, "customDevices", "as", str(len(addresses)), *addresses], self.deadline)


def load_metadata(directory):
    path = directory / "addresses.json"
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC)
    except FileNotFoundError:
        return []
    except OSError:
        raise AddressError("metadata-invalid") from None
    try:
        with os.fdopen(fd, "rb") as source:
            info = os.fstat(source.fileno())
            if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077 or info.st_size > MAX_BYTES:
                raise AddressError("metadata-invalid")
            document = json.loads(source.read(MAX_BYTES+1))
        if document.get("schema_version") != 1 or not isinstance(document.get("addresses"), list) or len(document["addresses"]) > MAX_ROWS:
            raise ValueError()
        rows = document["addresses"]
        seen = set()
        for row in rows:
            if not isinstance(row, dict) or set(row) != {"peer_id", "address", "source", "auto_discover", "manual_baseline"} or row["source"] not in SOURCES or type(row["auto_discover"]) is not bool or type(row["manual_baseline"]) is not bool:
                raise ValueError()
            key = (peer_id(row["peer_id"]), private_address(row["address"], source=row["source"]))
            if key in seen:
                raise ValueError()
            seen.add(key)
        return rows
    except (ValueError, TypeError, KeyError, AttributeError, AddressError):
        raise AddressError("metadata-invalid") from None


def save_metadata(directory, rows):
    data = json.dumps({"schema_version": 1, "addresses": rows}, separators=(",", ":")).encode()
    if len(data) > MAX_BYTES:
        raise AddressError("metadata-limit")
    fd, name = tempfile.mkstemp(prefix=".addresses-", dir=directory)
    try:
        with os.fdopen(fd, "wb") as target:
            target.write(data)
            target.flush()
            os.fsync(target.fileno())
        os.replace(name, directory / "addresses.json")
    finally:
        if os.path.exists(name):
            os.unlink(name)


def reconcile_rows(rows, changes, current):
    rows = [dict(row) for row in rows]
    removal = set()
    # A batch must not erase baseline proof by removing/re-adding its own row.
    baseline = {r["address"]: any(x["manual_baseline"] for x in rows if x["address"] == r["address"]) for r in rows}
    for change in changes:
        address = change["address"]
        found = next((r for r in rows if r["peer_id"] == change["peer_id"] and r["address"] == address), None)
        if change["op"] == "remove":
            if found:
                rows.remove(found)
                if change.get("remove_from_kde") and not baseline.get(address, True):
                    removal.add(address)
        elif change["op"] == "auto":
            if not found:
                raise AddressError("metadata-missing")
            found["auto_discover"] = change["auto_discover"]
        elif found:
            found.update(source=change["source"], auto_discover=change.get("auto_discover", False))
        else:
            rows.append({"peer_id": change["peer_id"], "address": address, "source": change["source"], "auto_discover": change.get("auto_discover", False), "manual_baseline": baseline.get(address, address in current)})
    if len(rows) > MAX_ROWS:
        raise AddressError("candidate-limit")
    referenced = {row["address"] for row in rows}
    desired = [a for a in current if a not in removal or a in referenced]
    for row in rows:
        if row["address"] not in desired:
            desired.append(row["address"])
    if len(desired) > MAX_ROWS:
        raise AddressError("candidate-limit")
    return rows, desired


def manage(request, directory, bus=None):
    changes = changes_from(request)
    deadline = time.monotonic() + 5
    bus = bus or KdeBus(deadline)
    directory = Path(directory)
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    info = directory.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise AddressError("metadata-permissions")
    lock = os.open(directory / "addresses.lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        info = os.fstat(lock)
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
            raise AddressError("metadata-permissions")
        while True:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() >= deadline:
                    raise AddressError("address-busy") from None
                time.sleep(.02)
        original = load_metadata(directory)
        for attempt in range(3):
            current = bus.read()
            rows, desired = reconcile_rows(original, changes, current)
            if not changes:
                # Opening the panel reads metadata only. Registration needs approval
                # or a provider refresh with an existing approved managed record.
                desired = current
            if bus.read() != current:
                continue
            if desired != current:
                bus.write(desired)
            observed = bus.read()
            if observed != desired:
                continue
            if changes:
                save_metadata(directory, rows)
            return {"schema_version": 1, "ok": True, "error": "", "custom_addresses": observed, "addresses": [dict(r, registered=r["address"] in observed) for r in rows]}
        raise AddressError("address-conflict")
    finally:
        os.close(lock)


def main():
    try:
        raw = sys.stdin.buffer.read(MAX_BYTES+1)
        if len(raw) > MAX_BYTES:
            raise AddressError("request-limit")
        request = json.loads(raw)
        data_home = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
        if not data_home.is_absolute():
            raise AddressError("metadata-path-invalid")
        result = manage(request, data_home / "ryan.omaconnect")
    except AddressError as error:
        result = {"schema_version": 1, "ok": False, "error": str(error)}
    except (ValueError, OSError):
        result = {"schema_version": 1, "ok": False, "error": "address-unavailable"}
    print(json.dumps(result, separators=(",", ":")))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
