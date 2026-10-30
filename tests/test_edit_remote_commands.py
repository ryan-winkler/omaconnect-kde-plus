"""Command-editor requests use fixed calls against a fake native provider."""
import importlib.util
import io
import json
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('edit_remote_commands', ROOT / 'scripts/edit_remote_commands.py')
editor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(editor)


class Reply:
    def __init__(self, value): self.value = value
    def unpack(self): return self.value


class Bus:
    def __init__(self, paired=True, reachable=True, can_add=True, fail_method=None, edit_reply=()):
        self.paired, self.reachable, self.can_add = paired, reachable, can_add
        self.fail_method, self.edit_reply = fail_method, edit_reply
        self.calls = []

    def call_sync(self, service, path, interface, method, args, result_type, flags, timeout, cancellable):
        self.calls.append((service, path, interface, method, args, flags, timeout))
        if method == self.fail_method:
            raise TimeoutError('private provider detail')
        if method == 'GetAll':
            data = {'canAddCommand': self.can_add} if path.endswith('/remotecommands') else {'isPaired': self.paired, 'isReachable': self.reachable}
            return Reply((data,))
        if method == 'editCommands':
            return Reply(self.edit_reply)
        raise AssertionError(method)


class EditRemoteCommandsTests(unittest.TestCase):
    def operate(self, bus):
        gio = SimpleNamespace(DBusCallFlags=SimpleNamespace(NO_AUTO_START=2))
        glib = SimpleNamespace(Variant=lambda signature, value: (signature, value))
        editor.operate(bus, gio, glib, None, 'peer_123')

    def test_exact_device_and_fixed_native_editor_request(self):
        bus = Bus()
        self.operate(bus)
        base = '/modules/kdeconnect/devices/peer_123'
        self.assertEqual(bus.calls, [
            ('org.kde.kdeconnect', base, 'org.freedesktop.DBus.Properties', 'GetAll', ('(s)', ('org.kde.kdeconnect.device',)), 2, 1500),
            ('org.kde.kdeconnect', base + '/remotecommands', 'org.freedesktop.DBus.Properties', 'GetAll', ('(s)', (editor.INTERFACE,)), 2, 1500),
            ('org.kde.kdeconnect', base + '/remotecommands', editor.INTERFACE, 'editCommands', None, 2, 1500),
        ])

    def test_unpaired_offline_or_unsupported_never_requests_editor(self):
        for options in ({'paired': False}, {'reachable': False}, {'can_add': False}, {'can_add': None}, {'can_add': 1}):
            bus = Bus(**options)
            with self.subTest(options=options), self.assertRaisesRegex(editor.RequestError, '^capability-unavailable$'):
                self.operate(bus)
            self.assertFalse(any(call[3] == 'editCommands' for call in bus.calls))

    def test_read_failure_and_uncertain_submission_are_distinct(self):
        for bus, expected in ((Bus(fail_method='GetAll'), 'provider-unavailable'), (Bus(fail_method='editCommands'), 'submission-unknown'), (Bus(edit_reply=(True,)), 'submission-unknown')):
            with self.subTest(expected=expected), self.assertRaisesRegex(editor.RequestError, '^' + expected + '$'):
                self.operate(bus)

    def test_input_is_bounded_and_cannot_select_a_method_or_path(self):
        self.assertEqual(editor.read_request(io.BytesIO(b'{"peerId":"peer_123"}\n')), 'peer_123')
        for raw in (b'', b'null', b'[]', b'{"peerId":true}', b'{"peerId":"../peer"}', b'{"peerId":"peer-id"}', b'{"peerId":"peer","method":"shell"}', b'{"peerId":"peer","peerId":"other"}', b'x' * 513, b'{"peerId":"' + b'a' * 129 + b'"}', b'{"peerId":"\xff"}'):
            with self.subTest(raw=raw[:50]), self.assertRaises(editor.RequestError):
                editor.read_request(io.BytesIO(raw))

    def test_json_result_and_total_cancellation_budget(self):
        for bus, expected_code, expected in (
            (Bus(), 0, {'state': 'request_accepted', 'error': ''}),
            (Bus(fail_method='editCommands'), 1, {'state': 'failed', 'error': 'submission-unknown'}),
        ):
            gio = SimpleNamespace(DBusCallFlags=SimpleNamespace(NO_AUTO_START=2),
                                  Cancellable=mock.Mock(), BusType=SimpleNamespace(SESSION=1),
                                  bus_get_sync=lambda *_: bus)
            glib = SimpleNamespace(Variant=lambda signature, value: (signature, value))
            modules = {'gi': SimpleNamespace(require_version=lambda *_: None),
                       'gi.repository': SimpleNamespace(Gio=gio, GLib=glib)}
            output = io.StringIO()
            with self.subTest(expected=expected), mock.patch.dict(editor.sys.modules, modules), \
                    mock.patch.dict(editor.os.environ, {'DBUS_SESSION_BUS_ADDRESS': 'private-fake-bus'}), \
                    mock.patch.object(editor.sys, 'stdin', SimpleNamespace(buffer=io.BytesIO(b'{"peerId":"peer_123"}'))), \
                    mock.patch.object(editor.sys, 'stdout', output), \
                    mock.patch.object(editor.threading, 'Timer') as timer:
                self.assertEqual(editor.main(), expected_code)
                self.assertEqual(json.loads(output.getvalue()), expected)
                timer.assert_called_once_with(5, gio.Cancellable.return_value.cancel)
                timer.return_value.start.assert_called_once_with()
                timer.return_value.cancel.assert_called_once_with()


if __name__ == '__main__':
    unittest.main()
