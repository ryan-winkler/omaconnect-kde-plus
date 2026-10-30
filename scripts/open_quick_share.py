#!/usr/bin/python3
"""Open the fixed optional RQuickShare app. Never install it or submit files."""
import os
from pathlib import Path
import subprocess
import sys

PROGRAM = "/usr/bin/rquickshare"


def available():
    return Path(PROGRAM).is_file() and os.access(PROGRAM, os.X_OK)


def main(argv):
    if argv not in (["--check"], ["--open"]):
        print("Use --check or --open. No action ran.", file=sys.stderr)
        return 2
    if not available():
        print("RQuickShare is unavailable. Install r-quick-share with your package manager.", file=sys.stderr)
        return 1
    if argv == ["--open"]:
        try:
            subprocess.Popen([PROGRAM], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True)
        except OSError:
            print("RQuickShare could not start. Check its installation and try again.", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
