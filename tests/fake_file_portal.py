"""Only launched under dbus-run-session by test_transfer.py."""
import json
import os
import signal
import subprocess
from gi.repository import Gio, GLib

bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
bus.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus', 'RequestName', GLib.Variant('(su)', ('org.freedesktop.portal.Desktop', 0)), None, Gio.DBusCallFlags.NONE, 1000, None)
xml = '''<node><interface name="org.freedesktop.portal.FileChooser"><method name="OpenFile"><arg type="s" direction="in"/><arg type="s" direction="in"/><arg type="a{sv}" direction="in"/><arg type="o" direction="out"/></method></interface></node>'''
loop = GLib.MainLoop()
process = None
delayed_cancel = os.environ.get("TEST_PORTAL_DELAYED_CANCEL") == "1"
late_registration = os.environ.get("TEST_PORTAL_LATE_REGISTRATION") == "1"
close_requests = []


def method(connection, sender, path, interface, name, parameters, invocation):
    """Serve an owned chooser request with optional cancellation and registration races."""
    parent, title, options = parameters.unpack()
    assert title == os.environ.get('TEST_PORTAL_TITLE', 'Select files to send')
    assert options['multiple'] is True
    assert options['directory'] is False
    assert 'filters' not in options
    handle = '/org/freedesktop/portal/desktop/request/' + sender[1:].replace('.', '_') + '/' + options['handle_token']
    if late_registration:
        handle += '_registered'
    def respond():
        connection.emit_signal(sender, handle, 'org.freedesktop.portal.Request', 'Response', GLib.Variant('(ua{sv})', (int(os.environ['TEST_PORTAL_RESPONSE']), {'uris': GLib.Variant('as', json.loads(os.environ['TEST_PORTAL_URIS']))})))
        return GLib.SOURCE_REMOVE
    def register_close():
        """Expose the request handle at the configured registration checkpoint."""
        close_info = Gio.DBusNodeInfo.new_for_xml('<node><interface name="org.freedesktop.portal.Request"><method name="Close"/></interface></node>').interfaces[0]

        def close(connection, sender, path, interface, name, parameters, invocation):
            """Record each Close on the actual registered request handle."""
            close_requests.append(path)
            invocation.return_value(None)

        bus.register_object(handle, close_info, close, None, None)

    def reply():
        """Register when required, then return the handle and optional late response."""
        if late_registration:
            register_close()
        invocation.return_value(GLib.Variant('(o)', (handle,)))
        if not delayed_cancel or os.environ.get("TEST_PORTAL_LATE_RESPONSE") == "1":
            GLib.idle_add(respond)
        return GLib.SOURCE_REMOVE

    if delayed_cancel:
        if not late_registration:
            register_close()
        GLib.timeout_add(50, lambda: (process.send_signal(signal.SIGTERM), False)[-1])
        GLib.timeout_add(250, reply)
    else:
        reply()


info = Gio.DBusNodeInfo.new_for_xml(xml).interfaces[0]
bus.register_object('/org/freedesktop/portal/desktop', info, method, None, None)
command = ['python3', os.environ['TEST_PICKER'], 'choose']
if 'TEST_PORTAL_TITLE' in os.environ:
    command.append(os.environ['TEST_PORTAL_TITLE'])
process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


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
if delayed_cancel:
    GLib.timeout_add(1500, lambda: (process.kill(), loop.quit(), False)[-1])
else:
    GLib.timeout_add_seconds(10, lambda: (process.kill(), loop.quit(), False)[-1])
loop.run()
if process.returncode != 0 or (delayed_cancel and len(close_requests) != 1):
    raise SystemExit(1)
