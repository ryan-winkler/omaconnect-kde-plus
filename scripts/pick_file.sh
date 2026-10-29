#!/usr/bin/env bash
set -eu
# One normal desktop chooser. All regular file types are available.
exec python3 "$(dirname -- "${BASH_SOURCE[0]}")/portal_files.py" choose
