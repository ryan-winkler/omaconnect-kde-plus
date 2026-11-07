#!/usr/bin/env python3
"""One-shot portal chooser and KDE submission boundary. No persistent history.

Modes: choose, choose-screenshot, inspect, submit, and sweep (expired share copies at startup).
Shared sources can use private descriptor-backed snapshots during submission.
"""
import json
import os
from pathlib import Path
import resource
import signal
import stat
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


def choose(title='Select files to send', screenshot_only=False):
    """Return one portal result and close a cancelled request after registration."""
    from gi.repository import Gio, GLib
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    token = 'omaconnect_' + uuid.uuid4().hex
    request_path = '/org/freedesktop/portal/desktop/request/' + bus.get_unique_name()[1:].replace('.', '_') + '/' + token
    loop, result = GLib.MainLoop(), {'state': 'failed', 'error': 'portal-unavailable'}
    resolved = False
    request_opened = close_attempted = False
    timeout_id = startup_id = 0

    def response(connection, sender, path, interface, member, parameters):
        """Accept the first matching response without replacing a cancellation."""
        nonlocal resolved
        if resolved or path != request_path:
            return
        resolved = True
        code, values = parameters.unpack()
        result.clear()
        if code == 1:
            result.update(state='cancelled', files=[])
        elif code != 0:
            result.update(state='failed', error='portal-unavailable')
        else:
            try:
                files = inspect_uris(values.get('uris'))
                if screenshot_only and (len(files) != 1 or Path(files[0]['name']).suffix.lower() != '.png'):
                    raise ValueError('source-path-rejected')
                result.update(state='selected', files=files)
            except (ValueError, TypeError) as error:
                result.update(state='failed', error=str(error))
        loop.quit()

    subscription = bus.signal_subscribe('org.freedesktop.portal.Desktop', 'org.freedesktop.portal.Request', 'Response', None, None, Gio.DBusSignalFlags.NONE, response)

    def close_registered_request():
        """Close the returned portal handle at most once after registration."""
        nonlocal close_attempted
        if not request_opened or close_attempted:
            return
        # OpenFile has now returned the registered handle. Do not guess its path
        # or send a second Close if a signal interrupts the synchronous call.
        close_attempted = True
        try:
            bus.call_sync('org.freedesktop.portal.Desktop', request_path, 'org.freedesktop.portal.Request', 'Close', None, None, Gio.DBusCallFlags.NONE, 1000, None)
        except GLib.Error:
            pass

    def close_request(*unused):
        """Latch cancellation before closing an existing or pending portal request."""
        nonlocal resolved
        if resolved:
            return GLib.SOURCE_REMOVE
        # Latch before Close or an outstanding OpenFile can dispatch callbacks.
        resolved = True
        result.clear()
        result.update(state='cancelled', files=[])
        loop.quit()
        close_registered_request()
        return GLib.SOURCE_REMOVE

    def expire_request():
        """Cancel an unanswered request when its selection deadline expires."""
        nonlocal timeout_id
        timeout_id = 0
        return close_request()

    def check_startup():
        """Stop the loop if cancellation occurred immediately before loop startup."""
        nonlocal startup_id
        startup_id = 0
        # Covers a signal between the resolved check and MainLoop.run().
        if resolved:
            loop.quit()
        return GLib.SOURCE_REMOVE

    previous_signal = signal.signal(signal.SIGTERM, close_request)
    try:
        if not resolved:
            options = {
                'handle_token': GLib.Variant('s', token),
                'multiple': GLib.Variant('b', not screenshot_only),
                'directory': GLib.Variant('b', False),
                'modal': GLib.Variant('b', True),
            }
            if screenshot_only:
                options['filters'] = GLib.Variant('a(sa(us))', [('PNG', [(1, 'image/png')])])
                pictures = GLib.get_user_special_dir(GLib.UserDirectory.DIRECTORY_PICTURES)
                default_folder = Path(pictures or Path.home() / 'Pictures') / 'Screenshots'
                folder = (os.environ.get('OMASNAP_SCREENSHOT_DIR')
                          or os.environ.get('OMARCHY_SCREENSHOT_DIR') or str(default_folder))
                if os.path.isabs(folder) and os.path.isdir(folder) and len(os.fsencode(folder)) <= 4096:
                    options['current_folder'] = GLib.Variant('ay', os.fsencode(folder) + b'\0')
            reply = bus.call_sync('org.freedesktop.portal.Desktop', '/org/freedesktop/portal/desktop',
                                  'org.freedesktop.portal.FileChooser', 'OpenFile',
                                  GLib.Variant('(ssa{sv})', ('', title, options)),
                                  GLib.VariantType.new('(o)'), Gio.DBusCallFlags.NONE, 5000, None)
            request_path = reply.unpack()[0]
            request_opened = True
            # SIGTERM during OpenFile is deferred until the real handle exists.
            if resolved and result.get('state') == 'cancelled':
                close_registered_request()
            if not resolved:
                timeout_id = GLib.timeout_add_seconds(120, expire_request)
                startup_id = GLib.idle_add(check_startup)
                if not resolved:
                    loop.run()
    except GLib.Error:
        if not resolved:
            raise
    finally:
        if timeout_id:
            GLib.source_remove(timeout_id)
        if startup_id:
            GLib.source_remove(startup_id)
        bus.signal_unsubscribe(subscription)
        signal.signal(signal.SIGTERM, previous_signal)
    emit(result)


def submit(payload):
    attempted = False
    cancelled = False

    def stop(*unused):
        nonlocal cancelled
        cancelled = True

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
        from send_text import SHARE_URLS, SubmissionError, call
        emit({"event": "preparing"})
        with prepared_source(payload.get("file"), lambda: cancelled) as prepared:
            # The prepared path is protected from a different local writer.
            # Shared sources use a retained descriptor-backed snapshot; normal
            # private paths avoid a copy. KDE still owns its later native open.
            # The path goes over D-Bus, as kdeconnect-cli does, never into argv.
            if cancelled:
                raise ValueError('cancelled-before-submit')
            emit({'event': 'submitting'})
            attempted = True
            try:
                call(peer, SHARE_URLS, [Path(prepared.path).as_uri()],
                     int(SUBMISSION_TIMEOUT * 1000), lambda: cancelled)
                state, error = 'request_accepted', ''
            except SubmissionError as failure:
                state, error = {'submission-unknown': ('submission_unknown', 'submission-unknown'),
                                'provider-unavailable': ('submission_failed', 'provider-missing'),
                                'invalid-input': ('submission_failed', 'identity-mismatch')}.get(
                                    str(failure), ('submission_failed', 'submission-failed'))
            # Only SIGTERM sets this flag; the deadline alone stays submission_unknown.
            if cancelled:
                state, error = 'cancellation_unconfirmed', 'cancellation-unconfirmed'
    except ValueError as preparation_error:
        if str(preparation_error) == "cancelled-before-submit" and not attempted:
            state, error = "cancelled_before_submit", ""
        else:
            raise
    except OSError:
        state, error = ('submission_unknown', 'submission-unknown') if attempted else ('submission_failed', 'submission-failed')
    emit({'state': state, 'error': error})


def main():
    """Dispatch bounded chooser, inspection and submission requests with fixed errors."""
    args = sys.argv[1:]
    mode = args[0] if args else ''
    try:
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
        if mode in ('choose', 'choose-screenshot'):
            if len(args) == 1 and mode == 'choose':
                choose()
            elif len(args) == 2 and 0 < len(args[1]) <= 160 and args[1].isprintable():
                choose(args[1], screenshot_only=mode == 'choose-screenshot')
            else:
                raise ValueError('source-path-rejected')
        elif len(args) != 1:
            raise ValueError('source-path-rejected')
        elif mode == 'recent':
            from recent_files import choose_recent
            raw = sys.stdin.buffer.readline(2049)
            request = json.loads(raw) if len(raw) <= 2048 else None
            if (not isinstance(request, dict) or 'recipient' not in request
                    or request.keys() - {'recipient', 'title', 'previewLabel'}
                    or not all(isinstance(value, str) for value in request.values())):
                raise ValueError('source-path-rejected')
            emit(choose_recent(request['recipient'], request.get('title', ''), request.get('previewLabel', '')))
        elif mode == 'sweep':
            from private_sources import sweep_expired
            sweep_expired()
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
        allowed = ('source-path-rejected', 'source-changed', 'selection-limit', 'identity-mismatch', 'source-preparation-failed', 'recent-files-unavailable', 'recent-files-empty', 'recent-files-timeout')
        emit({'state': 'failed', 'error': code if code in allowed else 'source-path-rejected'})
        return 1
    except (OSError, ImportError, TypeError, KeyError):
        # No remote strings, filenames, stderr, or exception details cross out.
        emit({'state': 'failed', 'error': 'source-path-rejected' if mode not in ('choose', 'choose-screenshot') else 'portal-unavailable'})
        return 1
    except Exception:
        emit({'state': 'failed', 'error': 'portal-unavailable' if mode in ('choose', 'choose-screenshot') else 'submission-unknown'})
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
