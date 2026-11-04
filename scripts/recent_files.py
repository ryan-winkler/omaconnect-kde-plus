#!/usr/bin/env python3
"""Bounded native recent-file selection; no transfer, file content or history.

Adapts the search roots, recent-first order and native menu from Jitendra Dara's
OmaConnect scripts/pick_file.sh at upstream commit cd72bfd286b80dbebdaa160f7793097bb590fbfb
(MIT; see LICENSE).
Plus validates one explicit selection through the existing portal boundary.
"""
import json
import os
from pathlib import Path
import selectors
import signal
import stat
import subprocess
import tempfile
import time
import unicodedata

ROOT_NAMES = ('Downloads', 'Documents', 'Pictures', 'Videos', 'Desktop')
EXTENSIONS = frozenset(('jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'avif', 'svg',
                        'mp4', 'mov', 'm4v', 'mkv', 'webm', 'avi', 'mp3', 'flac',
                        'wav', 'm4a', 'ogg', 'opus', 'pdf', 'txt', 'docx', 'xlsx',
                        'pptx', 'odt', 'ods', 'csv', 'json', 'md', 'epub', 'zip',
                        'tar', 'gz', 'bz2', 'xz', '7z', 'zst', 'apk', 'iso'))
MENU = 'omarchy-menu-select'
PROMPT = 'Select file to send'
OPTION_BUDGET = 64 * 1024
MAX_SCAN_ENTRIES = 20000
SCAN_SECONDS = 2
MENU_SECONDS = 120
MAX_OUTPUT = 4097  # One Linux path plus the menu's optional terminal newline.


class RecentError(Exception):
    pass


class Cancelled(Exception):
    pass


def _plain_path(value):
    # Native menu rows cannot represent separators or bidi/control text safely.
    """Check whether a bounded path can form one unambiguous native menu row."""
    return (len(os.fsencode(value)) <= 4096 and
            not any(unicodedata.category(c).startswith('C') or c in '\u2028\u2029'
                    for c in value))


def _candidates(home, cancelled):
    """Collect recent supported files within scan, depth and serialized option limits."""
    deadline = time.monotonic() + SCAN_SECONDS
    remaining = MAX_SCAN_ENTRIES
    found = []
    for name in ROOT_NAMES:
        root = home / name
        if root.is_symlink():
            continue
        pending = [(root, 0)]
        while pending and remaining > 0 and time.monotonic() < deadline:
            if cancelled():
                raise Cancelled()
            directory, depth = pending.pop()
            try:
                with os.scandir(directory) as entries:
                    for entry in entries:
                        if cancelled():
                            raise Cancelled()
                        if remaining <= 0 or time.monotonic() >= deadline:
                            break
                        remaining -= 1
                        if entry.name.startswith('.'):
                            continue
                        try:
                            info = entry.stat(follow_symlinks=False)
                            if stat.S_ISDIR(info.st_mode) and depth < 3:
                                pending.append((Path(entry.path), depth + 1))
                            elif (stat.S_ISREG(info.st_mode) and
                                  Path(entry.name).suffix[1:].lower() in EXTENSIONS and
                                  _plain_path(entry.path)):
                                found.append((info.st_mtime_ns, entry.path))
                        except OSError:
                            continue
            except OSError:
                continue
    # json.dumps with ASCII escaping conservatively bounds JSON::PP's UTF-8
    # options array and each argv copy in the native menu wrapper's payload.
    options, size = [], 2
    for _, path in sorted(found, key=lambda item: (-item[0], item[1])):
        cost = len(json.dumps(path, ensure_ascii=True).encode('ascii')) + bool(options)
        if size + cost > OPTION_BUDGET:
            continue
        options.append(path)
        size += cost
    return options


def _stop_group(process):
    # Always target the group, even if its wrapper exited with a child alive.
    """Terminate wrapper descendants and reap the wrapper before removing its files."""
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        process.wait(timeout=.15)
    except subprocess.TimeoutExpired:
        pass
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait()
    process.stdout.close()


def _menu(options, cancelled, label):
    # Recipient text is display-only. It cannot add menu rows or command flags.
    """Return one offered path and remove private result files on every exit."""
    label = label if isinstance(label, str) else ''
    label = ' '.join(''.join(' ' if unicodedata.category(c).startswith('C')
                               or c in '\u2028\u2029' else c
                               for c in label[:256]).split())[:80]
    prompt = PROMPT + (' to ' + label if label else '')
    # The shell menu outlives its wrapper. Removing this private parent after
    # group cleanup prevents a stale native selection from recreating result
    # files, even when its visible menu still needs dismissal with Escape.
    with tempfile.TemporaryDirectory(prefix='omaconnect-menu-') as directory:
        try:
            process = subprocess.Popen([MENU, prompt, *options, '--', '--width', '800',
                                        '--maxheight', '500'], stdin=subprocess.DEVNULL,
                                       stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                       start_new_session=True,
                                       env=dict(os.environ, TMPDIR=directory))
        except OSError:
            raise RecentError('recent-files-unavailable') from None
        deadline = time.monotonic() + MENU_SECONDS
        output = bytearray()
        try:
            with selectors.DefaultSelector() as selector:
                selector.register(process.stdout, selectors.EVENT_READ)
                while True:
                    if cancelled():
                        raise Cancelled()
                    remaining = deadline - time.monotonic()
                    if remaining <= 0:
                        raise RecentError('recent-files-timeout')
                    if not selector.select(min(.05, remaining)):
                        continue
                    chunk = os.read(process.stdout.fileno(), min(8192, MAX_OUTPUT + 1 - len(output)))
                    if not chunk:
                        break
                    output.extend(chunk)
                    if len(output) > MAX_OUTPUT:
                        raise RecentError('source-path-rejected')
            while process.poll() is None:
                if cancelled():
                    raise Cancelled()
                if time.monotonic() >= deadline:
                    raise RecentError('recent-files-timeout')
                time.sleep(.01)
            if cancelled() or process.returncode == 1:
                raise Cancelled()
            if process.returncode:
                raise RecentError('recent-files-unavailable')
            try:
                selected = bytes(output).decode('utf-8').removesuffix('\n')
            except UnicodeError:
                raise RecentError('source-path-rejected') from None
            if selected not in options:
                raise RecentError('source-path-rejected')
            return selected
        finally:
            _stop_group(process)


def choose_recent(label=''):
    """Return the portal selection contract without opening the portal or sending."""
    cancelled = False

    def stop(*unused):
        """Record cancellation for the scan and menu to observe safely."""
        nonlocal cancelled
        cancelled = True

    previous = signal.signal(signal.SIGTERM, stop)
    try:
        options = _candidates(Path.home(), lambda: cancelled)
        if cancelled:
            raise Cancelled()
        if not options:
            raise RecentError('recent-files-empty')
        selected = _menu(options, lambda: cancelled, label)
        if cancelled:
            raise Cancelled()
        from portal_files import inspect_uris
        files = inspect_uris([Path(selected).as_uri()])
        if cancelled:
            raise Cancelled()
        return {'state': 'selected', 'files': files}
    except Cancelled:
        return {'state': 'cancelled', 'files': []}
    except RecentError as error:
        return {'state': 'failed', 'error': str(error)}
    except (OSError, ValueError, UnicodeError):
        return {'state': 'failed', 'error': 'source-path-rejected'}
    finally:
        signal.signal(signal.SIGTERM, previous)
