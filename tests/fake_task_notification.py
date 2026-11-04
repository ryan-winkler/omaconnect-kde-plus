"""Owned notification bus only. Run through test_task_notifications.py."""
import json
import os
from pathlib import Path
import secrets
import subprocess
import sys
import time
from gi.repository import Gio, GLib

if sys.argv[1] == 'activation':
    Path(os.environ['HOME'], 'UNEXPECTED_ACTIVATION').touch()
    raise SystemExit(1)

mode = sys.argv[1]
root = Path(__file__).resolve().parents[1]
sentinel = 'NOTICE-PRIVATE-' + secrets.token_hex(12)
remote = sentinel + ' \u202e<b>phone</b> &lt;b&gt; https://invalid.test/name\u2069'
request = {'summary': 'File requests accepted', 'body': 'Delivery is unknown.',
           'includeDeviceName': mode == 'detail', 'deviceName': remote if mode == 'detail' else ''}
bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
loop = GLib.MainLoop()
calls, held = [], []
started = time.monotonic()


def method(connection, sender, path, interface, member, parameters, invocation):
    app, replace, icon, summary, body, actions, hints, expire = parameters.unpack()
    calls.append(True)
    assert (path, interface, member, parameters.get_type_string()) == (
        '/org/freedesktop/Notifications', 'org.freedesktop.Notifications', 'Notify', '(susssasa{sv}i)')
    assert (app, replace, icon, summary, actions, expire) == ('Omaconnect KDE Plus', 0, 'kdeconnect', request['summary'], [], -1)
    assert hints['urgency'] == 1 and 'transient' not in hints
    argv = ['/usr/bin/omarchy-shell', 'omaconnect.plus', 'activity']
    assert json.loads(hints['omarchy-exec-argv']) == argv
    assert json.loads(hints['omarchy-actions']) == [{'label': 'Activity', 'argv': argv}]
    assert sentinel.encode() not in Path(f'/proc/{child.pid}/cmdline').read_bytes()
    assert sentinel.encode() not in Path(f'/proc/{child.pid}/environ').read_bytes()
    if mode == 'detail':
        assert sentinel in body and '<' not in body and '&' not in body and 'https:' not in body and '\u202e' not in body
    else:
        assert body == request['body'] and sentinel not in body
    if mode == 'timeout':
        held.append(invocation)
    elif mode == 'failure':
        invocation.return_dbus_error('org.test.Rejected', remote)
    else:
        invocation.return_value(GLib.Variant('(u)', (1,)))


if mode != 'unavailable':
    bus.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus', 'RequestName',
                  GLib.Variant('(su)', ('org.freedesktop.Notifications', 0)), None, Gio.DBusCallFlags.NONE, 1000, None)
    xml = '<node><interface name="org.freedesktop.Notifications"><method name="Notify">' + ''.join(
        '<arg type="'+kind+'" direction="in"/>' for kind in ('s', 'u', 's', 's', 's', 'as', 'a{sv}', 'i')) + '<arg type="u" direction="out"/></method></interface></node>'
    bus.register_object('/org/freedesktop/Notifications', Gio.DBusNodeInfo.new_for_xml(xml).interfaces[0], method, None, None)

child = subprocess.Popen([sys.executable, str(root/'scripts/task_notification.py')],
                         stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
child.stdin.write(json.dumps(request, ensure_ascii=True).encode())
child.stdin.close(); child.stdin = None


def done():
    if child.poll() is None:
        return True
    output, error = child.communicate()
    ok = mode in ('generic', 'detail')
    assert child.returncode == (0 if ok else 1)
    assert json.loads(output) == {'ok': ok} and error == b''
    assert sentinel.encode() not in output+error
    assert len(calls) == (0 if mode == 'unavailable' else 1)
    if mode == 'timeout':
        assert 3 <= time.monotonic()-started < 5
    print(json.dumps({'passed': True, 'mode': mode}), flush=True)
    loop.quit()
    return False


GLib.timeout_add(20, done)
GLib.timeout_add_seconds(6, lambda: (child.kill(), loop.quit(), False)[-1])
loop.run()
raise SystemExit(0 if child.returncode is not None else 1)
