#!/usr/bin/python3
"""Open an existing network owner UI. Never install or toggle a provider."""
import json
from pathlib import Path
import subprocess
import sys

from manage_addresses import AddressError, bounded_command
import time


def open_owner(owner):
    if owner == "tailscale":
        try:
            reply = bounded_command(["/usr/bin/omarchy-shell", "shell", "summon", "omarchy.tailscale", "{}"], time.monotonic() + 4)
            if reply.strip() == b"ok":
                return {"ok": True, "message": "Opened the existing Tailscale panel."}
        except AddressError:
            pass
        return {"ok": False, "message": "Tailscale panel unavailable. Use your existing Tailscale app or CLI. Nothing was installed or connected."}
    if owner == "wireguard":
        # Open profiles only. The native editor owns any later reviewed changes.
        program = "/usr/bin/nm-connection-editor"
        if Path(program).is_file():
            try:
                subprocess.Popen([program], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
                return {"ok": True, "message": "Requested the native NetworkManager profile editor. Select your existing WireGuard profile there."}
            except OSError:
                pass
        return {"ok": False, "message": "NetworkManager profile editor unavailable. Use the manager that owns your WireGuard profile."}
    return {"ok": False, "message": "Unknown network owner. No action ran."}


if __name__ == "__main__":
    result = open_owner(sys.argv[1]) if len(sys.argv) == 2 else open_owner("")
    print(json.dumps(result))
    raise SystemExit(0 if result["ok"] else 1)
