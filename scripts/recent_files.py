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
SHELL = 'omarchy-shell'
PROMPT = 'Select file to send'
PREVIEW_LABEL = 'Image previews…'
PREVIEW_EXTENSIONS = frozenset(('jpg', 'jpeg', 'png', 'webp', 'gif'))
MAX_PREVIEW_FILES = 200
PREVIEW_ROW_BUDGET = 48 * 1024
OPTION_BUDGET = 64 * 1024
MAX_SCAN_ENTRIES = 20000
SCAN_SECONDS = 2
MENU_SECONDS = 120
MAX_OUTPUT = 4097  # One Linux path plus the menu's optional terminal newline.


class RecentError(Exception):
    pass


class Cancelled(Exception):
    pass


def _file_row(path):
    """Add a native display glyph without changing the path returned by the menu."""
    extension = Path(path).suffix[1:].lower()
    groups = ((('jpg', 'jpeg', 'png', 'webp', 'gif', 'heic', 'avif', 'svg'), '\uf03e'),
              (('mp4', 'mov', 'm4v', 'mkv', 'webm', 'avi'), '\uf008'),
              (('mp3', 'flac', 'wav', 'm4a', 'ogg', 'opus'), '\uf001'),
              (('zip', 'tar', 'gz', 'bz2', 'xz', '7z', 'zst', 'iso', 'apk'), '\uf1c6'),
              (('pdf',), '\uf1c1'), (('docx', 'odt'), '\uf1c2'),
              (('xlsx', 'ods', 'csv'), '\uf1c3'), (('pptx',), '\uf1c4'))
    glyph = next((icon for extensions, icon in groups if extension in extensions), '\uf15c')
    return glyph + '\t' + path


def _preview_options(options):
    """Bound native raster rows and keep the newest path for each duplicate basename."""
    images, names, size = [], set(), 0
    for path in options:
        candidate = Path(path)
        if candidate.suffix[1:].lower() not in PREVIEW_EXTENSIONS or candidate.name in names:
            continue
        cost = len(json.dumps(path + '\n', ensure_ascii=True).encode('ascii'))
        if size + cost > PREVIEW_ROW_BUDGET:
            continue
        images.append(path)
        names.add(candidate.name)
        size += cost
        if len(images) == MAX_PREVIEW_FILES:
            break
    return images


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
    roots = set()
    for name in ROOT_NAMES:
        if cancelled():
            raise Cancelled()
        if remaining <= 0 or time.monotonic() >= deadline:
            break
        # Conventional folders can be aliases after a storage move. Resolve
        # only this starting root; entry.stat below still rejects nested links.
        try:
            root = (home / name).resolve(strict=True)
        except (OSError, RuntimeError):
            continue
        if root in roots:
            continue
        roots.add(root)
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
    # Reserve the optional preview route as well as each rendered glyph/TAB row.
    options, size = [], 3 + len(json.dumps('\uf03e\t' + PREVIEW_LABEL, ensure_ascii=True))
    for _, path in sorted(found, key=lambda item: (-item[0], item[1])):
        cost = len(json.dumps(_file_row(path), ensure_ascii=True).encode('ascii')) + bool(options)
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


def _read_output(process, cancelled, deadline):
    """Read one bounded native reply while observing cancellation and the phase deadline."""
    output = bytearray()
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
    if cancelled():
        raise Cancelled()
    try:
        return bytes(output).decode('utf-8').removesuffix('\n')
    except UnicodeError:
        raise RecentError('source-path-rejected') from None


def _menu(options, cancelled, label):
    # Recipient text is display-only. It cannot add menu rows or command flags.
    """Return one offered path and remove private result files on every exit."""
    label = label if isinstance(label, str) else ''
    label = ' '.join(''.join(' ' if unicodedata.category(c).startswith('C')
                               or c in '\u2028\u2029' else c
                               for c in label[:256]).split())[:80]
    prompt = PROMPT + (' to ' + label if label else '')
    images = _preview_options(options)
    rows = [_file_row(path) for path in options]
    if images:
        rows.insert(0, '\uf03e\t' + PREVIEW_LABEL)
    # The shell menu outlives its wrapper. Removing this private parent after
    # group cleanup prevents a stale native selection from recreating result
    # files, even when its visible menu still needs dismissal with Escape.
    with tempfile.TemporaryDirectory(prefix='omaconnect-menu-') as directory:
        try:
            process = subprocess.Popen([MENU, prompt, *rows, '--', '--width', '800',
                                        '--maxheight', '500'], stdin=subprocess.DEVNULL,
                                       stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                       start_new_session=True,
                                       env=dict(os.environ, TMPDIR=directory))
        except OSError:
            raise RecentError('recent-files-unavailable') from None
        deadline = time.monotonic() + MENU_SECONDS
        try:
            selected = _read_output(process, cancelled, deadline)
            if process.returncode == 1:
                raise Cancelled()
            if process.returncode:
                raise RecentError('recent-files-unavailable')
            if selected not in options and not (images and selected == PREVIEW_LABEL):
                raise RecentError('source-path-rejected')
        finally:
            _stop_group(process)
    return _image_menu(images, cancelled) if selected == PREVIEW_LABEL else selected


def _image_menu(images, cancelled):
    """Choose from exact bounded raster paths through the existing native overlay."""
    with tempfile.TemporaryDirectory(prefix='omaconnect-images-') as directory:
        selection, done = Path(directory) / 'selection', Path(directory) / 'done'
        payload = json.dumps({'imageRows': '\n'.join(images), 'selectionFile': str(selection),
                              'doneFile': str(done), 'showLabels': True, 'filterable': True},
                             ensure_ascii=True, separators=(',', ':'))
        if not images or len(payload.encode('ascii')) > OPTION_BUDGET:
            raise RecentError('recent-files-unavailable')
        if cancelled():
            raise Cancelled()
        deadline = time.monotonic() + MENU_SECONDS
        try:
            process = subprocess.Popen([SHELL, 'shell', 'summon', 'omarchy.image-picker', payload],
                                       stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                       stderr=subprocess.DEVNULL, start_new_session=True)
        except OSError:
            raise RecentError('recent-files-unavailable') from None
        try:
            reply = _read_output(process, cancelled, deadline)
        finally:
            # The IPC wrapper is short-lived; clean its group now, before
            # waiting on the persistent shell's result, to avoid stale PGIDs.
            _stop_group(process)
        if process.returncode or reply != 'ok':
            raise RecentError('recent-files-unavailable')
        while not done.exists():
            if cancelled():
                raise Cancelled()
            if time.monotonic() >= deadline:
                raise RecentError('recent-files-timeout')
            time.sleep(.05)
        if cancelled():
            raise Cancelled()
        if time.monotonic() >= deadline:
            raise RecentError('recent-files-timeout')
        try:
            with selection.open('rb') as stream:
                raw = stream.read(MAX_OUTPUT + 1)
        except FileNotFoundError:
            raise Cancelled() from None
        if not raw:
            raise Cancelled()
        if len(raw) > MAX_OUTPUT:
            raise RecentError('source-path-rejected')
        try:
            selected = raw.decode('utf-8').removesuffix('\n')
        except UnicodeError:
            raise RecentError('source-path-rejected') from None
        if selected not in images:
            raise RecentError('source-path-rejected')
        return selected


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
