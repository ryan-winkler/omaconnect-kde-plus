#!/usr/bin/env python3
"""One-shot portal chooser and KDE submission boundary. No payload bytes or history."""
import json
import os
from pathlib import Path
import signal
import stat
import subprocess
import sys
import uuid
from urllib.parse import unquote, urlsplit

MAX_FILES = 100
MAX_BYTES = 2 ** 40
MAX_INPUT = 512 * 1024
SUBMISSION_TIMEOUT = 15


def emit(value):
    encoded = json.dumps(value, ensure_ascii=True, separators=(',', ':'))
    if len(encoded) > MAX_INPUT:
        encoded = json.dumps({'state': 'failed', 'error': 'selection-limit'})
    print(encoded, flush=True)


def inspect_file(path):
    if not isinstance(path, str) or not path.startswith('/') or '\0' in path or len(os.fsencode(path)) > 4096:
        raise ValueError('source-path-rejected')
    # Nonblocking prevents a FIFO/device from hanging the shell. O_NOFOLLOW rejects
    # a final symlink; fstat checks the opened object, never a filename extension.
    try:
        before = os.lstat(path)
        if not stat.S_ISREG(before.st_mode):
            raise ValueError('source-path-rejected')
        fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW | os.O_CLOEXEC)
        try:
            value = os.fstat(fd)
            if not stat.S_ISREG(value.st_mode) or value.st_size > MAX_BYTES or (before.st_dev, before.st_ino) != (value.st_dev, value.st_ino):
                raise ValueError('source-path-rejected')
        finally:
            os.close(fd)
    except OSError:
        raise ValueError('source-path-rejected') from None
    return {'path': path, 'name': Path(path).name, 'size': value.st_size,
            'device': str(value.st_dev), 'inode': str(value.st_ino),
            'mtimeNs': str(value.st_mtime_ns), 'ctimeNs': str(value.st_ctime_ns)}


def inspect_uris(uris):
    if not isinstance(uris, list) or not 1 <= len(uris) <= MAX_FILES:
        raise ValueError('selection-limit')
    files, seen, total = [], set(), 0
    for uri in uris:
        if not isinstance(uri, str) or len(uri) > 16384:
            raise ValueError('source-path-rejected')
        parsed = urlsplit(uri)
        if parsed.scheme != 'file' or parsed.netloc not in ('', 'localhost') or parsed.query or parsed.fragment:
            raise ValueError('source-path-rejected')
        try:
            path = unquote(parsed.path, errors='strict')
        except (UnicodeError, ValueError):
            raise ValueError('source-path-rejected') from None
        item = inspect_file(path)
        key = (item['device'], item['inode'])
        if key in seen:
            continue
        seen.add(key)
        total += item['size']
        if total > MAX_BYTES:
            raise ValueError('selection-limit')
        files.append(item)
    return files


def validate_file(expected):
    if not isinstance(expected, dict):
        raise ValueError('source-path-rejected')
    actual = inspect_file(expected.get('path'))
    if any(expected.get(key) != actual[key] for key in ('size', 'device', 'inode', 'mtimeNs', 'ctimeNs')):
        raise ValueError('source-changed')
    return actual


def choose():
    from gi.repository import Gio, GLib
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    token = 'omaconnect_' + uuid.uuid4().hex
    request_path = '/org/freedesktop/portal/desktop/request/' + bus.get_unique_name()[1:].replace('.', '_') + '/' + token
    loop, result = GLib.MainLoop(), {'state': 'failed', 'error': 'portal-unavailable'}

    def response(connection, sender, path, interface, member, parameters):
        if path != request_path:
            return
        code, values = parameters.unpack()
        result.clear()
        if code == 1:
            result.update(state='cancelled', files=[])
        elif code != 0:
            result.update(state='failed', error='portal-unavailable')
        else:
            try:
                result.update(state='selected', files=inspect_uris(values.get('uris')))
            except (ValueError, TypeError) as error:
                result.update(state='failed', error=str(error))
        loop.quit()

    subscription = bus.signal_subscribe('org.freedesktop.portal.Desktop', 'org.freedesktop.portal.Request', 'Response', None, None, Gio.DBusSignalFlags.NONE, response)

    def close_request(*unused):
        try:
            bus.call_sync('org.freedesktop.portal.Desktop', request_path, 'org.freedesktop.portal.Request', 'Close', None, None, Gio.DBusCallFlags.NONE, 1000, None)
        except GLib.Error:
            pass
        result.clear()
        result.update(state='cancelled', files=[])
        loop.quit()
        return GLib.SOURCE_REMOVE

    signal.signal(signal.SIGTERM, close_request)
    try:
        reply = bus.call_sync('org.freedesktop.portal.Desktop', '/org/freedesktop/portal/desktop', 'org.freedesktop.portal.FileChooser', 'OpenFile', GLib.Variant('(ssa{sv})', ('', 'Select files to send', {'handle_token': GLib.Variant('s', token), 'multiple': GLib.Variant('b', True), 'directory': GLib.Variant('b', False), 'modal': GLib.Variant('b', True)})), GLib.VariantType.new('(o)'), Gio.DBusCallFlags.NONE, 5000, None)
        request_path = reply.unpack()[0]
        GLib.timeout_add_seconds(120, close_request)
        loop.run()
    finally:
        bus.signal_unsubscribe(subscription)
    emit(result)


def submit(payload):
    child = None
    attempted = False
    cancelled = False

    def stop(*unused):
        nonlocal cancelled
        cancelled = True
        if child is not None and child.poll() is None:
            try:
                os.killpg(child.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass

    signal.signal(signal.SIGTERM, stop)
    peer = payload.get('peerId')
    if not isinstance(peer, str) or not peer or len(peer) > 256 or any(ord(c) < 32 for c in peer):
        raise ValueError('identity-mismatch')
    validate_file(payload.get('file'))
    if cancelled:
        emit({'state': 'cancelled_before_submit', 'error': ''})
        return
    try:
        from private_sources import prepared_source
        emit({"event": "preparing"})
        with prepared_source(payload.get("file"), lambda: cancelled) as prepared:
            # The prepared path is protected from a different local writer.
            # Shared sources use a retained descriptor-backed snapshot; normal
            # private paths avoid a copy. KDE still owns its later native open.
            emit({'event': 'submitting'})
            attempted = True
            child = subprocess.Popen(['kdeconnect-cli', '-d', peer, '--share', prepared.path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            if cancelled:
                stop()
            try:
                code = child.wait(timeout=SUBMISSION_TIMEOUT)
                state = 'request_accepted' if code == 0 else 'submission_failed'
                error = '' if code == 0 else 'submission-failed'
            except subprocess.TimeoutExpired:
                stop()
                state, error = 'submission_unknown', 'submission-unknown'
            # stop() also services timeout; only an external cancel changes this flag.
            if cancelled and state != 'submission_unknown':
                state, error = 'cancellation_unconfirmed', 'cancellation-unconfirmed'
    except ValueError as preparation_error:
        if str(preparation_error) == "cancelled-before-submit" and not attempted:
            state, error = "cancelled_before_submit", ""
        else:
            raise
    except FileNotFoundError:
        state, error = 'submission_failed', 'provider-missing'
    except OSError:
        state, error = ('submission_unknown', 'submission-unknown') if attempted else ('submission_failed', 'submission-failed')
    finally:
        if child is not None and child.poll() is None:
            try:
                child.wait(timeout=1)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait()
    emit({'state': state, 'error': error})


def main():
    mode = sys.argv[1] if len(sys.argv) == 2 else ''
    try:
        if mode == 'choose':
            choose()
        elif mode in ('inspect', 'submit'):
            raw = sys.stdin.buffer.readline(MAX_INPUT + 1)
            if len(raw) > MAX_INPUT:
                raise ValueError('selection-limit')
            value = json.loads(raw)
            if mode == 'inspect':
                emit({'state': 'selected', 'files': inspect_uris(value)})
            else:
                submit(value)
        else:
            raise ValueError('source-path-rejected')
    except ValueError as error:
        code = str(error)
        allowed = ('source-path-rejected', 'source-changed', 'selection-limit', 'identity-mismatch', 'source-preparation-failed')
        emit({'state': 'failed', 'error': code if code in allowed else 'source-path-rejected'})
        return 1
    except (OSError, ImportError, TypeError, KeyError):
        # No remote strings, filenames, stderr, or exception details cross out.
        emit({'state': 'failed', 'error': 'source-path-rejected' if mode != 'choose' else 'portal-unavailable'})
        return 1
    except Exception:
        emit({'state': 'failed', 'error': 'portal-unavailable' if mode == 'choose' else 'submission-unknown'})
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
