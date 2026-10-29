"""Only launched under dbus-run-session by test_transfer.py."""
import json
import os
import subprocess
from gi.repository import Gio, GLib

bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
bus.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus', 'RequestName', GLib.Variant('(su)', ('org.freedesktop.portal.Desktop', 0)), None, Gio.DBusCallFlags.NONE, 1000, None)
xml = '''<node><interface name="org.freedesktop.portal.FileChooser"><method name="OpenFile"><arg type="s" direction="in"/><arg type="s" direction="in"/><arg type="a{sv}" direction="in"/><arg type="o" direction="out"/></method></interface></node>'''
loop = GLib.MainLoop()
process = None


def method(connection, sender, path, interface, name, parameters, invocation):
    parent, title, options = parameters.unpack()
    assert options['multiple'] is True
    assert options['directory'] is False
    assert 'filters' not in options
    handle = '/org/freedesktop/portal/desktop/request/' + sender[1:].replace('.', '_') + '/' + options['handle_token']
    invocation.return_value(GLib.Variant('(o)', (handle,)))
    def respond():
        connection.emit_signal(sender, handle, 'org.freedesktop.portal.Request', 'Response', GLib.Variant('(ua{sv})', (int(os.environ['TEST_PORTAL_RESPONSE']), {'uris': GLib.Variant('as', json.loads(os.environ['TEST_PORTAL_URIS']))})))
        return GLib.SOURCE_REMOVE
    GLib.idle_add(respond)


info = Gio.DBusNodeInfo.new_for_xml(xml).interfaces[0]
bus.register_object('/org/freedesktop/portal/desktop', info, method, None, None)
process = subprocess.Popen(['python3', os.environ['TEST_PICKER'], 'choose'], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def done():
    if process.poll() is None:
        return GLib.SOURCE_CONTINUE
    output, error = process.communicate()
    print(output, end='')
    if process.returncode:
        raise RuntimeError(error)
    loop.quit()
    return GLib.SOURCE_REMOVE


GLib.timeout_add(20, done)
GLib.timeout_add_seconds(10, lambda: (process.kill(), loop.quit(), False)[-1])
loop.run()
if process.returncode != 0:
    raise SystemExit(1)
