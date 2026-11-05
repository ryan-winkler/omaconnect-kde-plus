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
    screenshot = title == 'Choose a screenshot to review'
    valid_mode = (options.get('multiple') is False and options.get('filters') == [('PNG', [(1, 'image/png')])]
                  if screenshot else options.get('multiple') is True and 'filters' not in options)
    if not valid_mode or options.get('directory') is not False:
        invocation.return_dbus_error('org.test.InvalidOptions', 'Unexpected file chooser options')
        return
    requests.append({'multiple': not screenshot, 'directory': False})
    handle = '/org/freedesktop/portal/desktop/request/' + sender[1:].replace('.', '_') + '/' + options['handle_token']
    invocation.return_value(GLib.Variant('(o)', (handle,)))
    names = ['owned-shot.png'] if screenshot else (['one', 'two'] if len(requests) == 1 else ['slow'])
    uris = [(fixture / name).as_uri() for name in names]
    def respond():
        connection.emit_signal(sender, handle, 'org.freedesktop.portal.Request', 'Response', GLib.Variant('(ua{sv})', (0, {'uris': GLib.Variant('as', uris)})))
        return GLib.SOURCE_REMOVE
    GLib.idle_add(respond)


bus.register_object('/org/freedesktop/portal/desktop', Gio.DBusNodeInfo.new_for_xml(xml).interfaces[0], method, None, None)


def share(connection, sender, path, interface, name, parameters, invocation):
    urls = parameters.unpack()[0]
    with open(os.environ['NATIVE_COMMAND_LOG'], 'a') as out:
        out.write(json.dumps({'tool': 'kdeconnect-share', 'args': [path.split('/')[-2], *urls]}) + '\n')
    GLib.timeout_add(4000 if urls[-1].endswith('/slow') else 100, lambda: (invocation.return_value(None), False)[-1])


# File shares go over D-Bus, as kdeconnect-cli --share does; the fake logs each call.
bus.call_sync('org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus', 'RequestName', GLib.Variant('(su)', ('org.kde.kdeconnect', 0)), None, Gio.DBusCallFlags.NONE, 1000, None)
share_xml = '<node><interface name="org.kde.kdeconnect.device.share"><method name="shareUrls"><arg type="as" direction="in"/></method></interface></node>'
for device in ('A', 'B'):
    bus.register_object('/modules/kdeconnect/devices/' + device + '/share', Gio.DBusNodeInfo.new_for_xml(share_xml).interfaces[0], share, None, None)
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
