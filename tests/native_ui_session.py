"""Private-session fake portal driver. Called only by test_native_ui.py."""
import json
import os
from pathlib import Path
import subprocess
import sys
from gi.repository import Gio, GLib

fixture = Path(sys.argv[1])
bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
bus.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus', 'RequestName', GLib.Variant('(su)', ('org.freedesktop.portal.Desktop', 0)), None, Gio.DBusCallFlags.NONE, 1000, None)
xml = '<node><interface name="org.freedesktop.portal.FileChooser"><method name="OpenFile"><arg type="s" direction="in"/><arg type="s" direction="in"/><arg type="a{sv}" direction="in"/><arg type="o" direction="out"/></method></interface></node>'
requests = []


def method(connection, sender, path, interface, name, parameters, invocation):
    parent, title, options = parameters.unpack()
    if options.get('multiple') is not True or options.get('directory') is not False or 'filters' in options:
        invocation.return_dbus_error('org.test.InvalidOptions', 'Expected all-file multiselect')
        return
    requests.append({'multiple': True, 'directory': False})
    handle = '/org/freedesktop/portal/desktop/request/' + sender[1:].replace('.', '_') + '/' + options['handle_token']
    invocation.return_value(GLib.Variant('(o)', (handle,)))
    names = ['one', 'two'] if len(requests) == 1 else ['slow']
    uris = [(fixture / name).as_uri() for name in names]
    def respond():
        connection.emit_signal(sender, handle, 'org.freedesktop.portal.Request', 'Response', GLib.Variant('(ua{sv})', (0, {'uris': GLib.Variant('as', uris)})))
        return GLib.SOURCE_REMOVE
    GLib.idle_add(respond)


bus.register_object('/org/freedesktop/portal/desktop', Gio.DBusNodeInfo.new_for_xml(xml).interfaces[0], method, None, None)
loop = GLib.MainLoop()
process = subprocess.Popen(['/usr/bin/quickshell', '--no-color', '-p', str(fixture)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def done():
    if process.poll() is None:
        return GLib.SOURCE_CONTINUE
    output, error = process.communicate()
    print(output, end='')
    print(error, file=sys.stderr, end='')
    (fixture / 'portal-receipt.json').write_text(json.dumps(requests))
    loop.quit()
    return GLib.SOURCE_REMOVE


GLib.timeout_add(30, done)
GLib.timeout_add_seconds(18, lambda: (process.kill(), loop.quit(), False)[-1])
loop.run()
if process.returncode is None:
    output, error = process.communicate()
    print(output, end='')
    print(error, file=sys.stderr, end='')
raise SystemExit(process.returncode or 0)
