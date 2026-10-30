"""Native module state uses bounded calls and an isolated fake provider only."""
import importlib.util
import io
import json
from pathlib import Path
import threading
import time
from types import SimpleNamespace
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('native_settings', ROOT / 'scripts/native_settings.py')
settings = importlib.util.module_from_spec(spec)
spec.loader.exec_module(settings)
GIO = SimpleNamespace(DBusCallFlags=SimpleNamespace(NO_AUTO_START=2))
GLIB = SimpleNamespace(Variant=lambda signature, value: (signature, value))


class Reply:
    def __init__(self, value): self.value = value
    def unpack(self): return self.value


class Bus:
    def __init__(self, paired=True, reachable=False, fail=None, ignore_write=False, malformed=False, delay=0):
        self.paired, self.reachable = paired, reachable
        self.fail, self.ignore_write, self.malformed, self.delay = fail, ignore_write, malformed, delay
        self.values = {'kdeconnect_share': True, 'kdeconnect_clipboard': False}
        self.calls = []
        self.lock = threading.Lock()
        self.active = self.maximum = 0

    def call_sync(self, service, path, interface, method, args, result_type, flags, timeout, cancellable):
        with self.lock:
            self.calls.append((service, path, interface, method, args, flags, timeout))
        if method == 'GetAll':
            return Reply(({'isPaired': self.paired, 'isReachable': self.reachable},))
        plugin = args[1][0]
        if self.fail in (method, plugin):
            raise TimeoutError('private error must not escape')
        if method == 'isPluginEnabled':
            with self.lock:
                self.active += 1
                self.maximum = max(self.maximum, self.active)
            time.sleep(self.delay)
            with self.lock:
                self.active -= 1
            return Reply(('yes',) if self.malformed else (self.values.get(plugin, False),))
        if method == 'setPluginEnabled':
            if not self.ignore_write:
                self.values[plugin] = args[1][1]
            return Reply(())
        raise AssertionError(method)


def read_request(ids=None):
    return {'operation': 'read', 'peerId': 'peer_123', 'pluginIds': ids or ['kdeconnect_share', 'kdeconnect_clipboard']}


def set_request(enabled=True):
    return {'operation': 'set', 'peerId': 'peer_123', 'pluginId': 'kdeconnect_clipboard', 'enabled': enabled}


class NativeSettingsTests(unittest.TestCase):
    def operate(self, bus, request, **options):
        result = settings.operate(bus, GIO, GLIB, None, request, **options)
        self.assertTrue(all(call[0] == 'org.kde.kdeconnect' and call[1] == '/modules/kdeconnect/devices/peer_123' and call[5] == 2 and 1 <= call[6] <= 1500 for call in bus.calls))
        return result

    def test_reads_native_values_for_paired_offline_peer(self):
        bus = Bus(reachable=False)
        result = self.operate(bus, read_request())
        self.assertEqual(result, {'state': 'observed', 'peerId': 'peer_123', 'enabled': bus.values, 'error': ''})
        self.assertEqual(bus.calls[0][2:5], ('org.freedesktop.DBus.Properties', 'GetAll', ('(s)', ('org.kde.kdeconnect.device',))))
        self.assertTrue(all(call[3] in ('GetAll', 'isPluginEnabled') for call in bus.calls))

    def test_unpaired_peer_never_reads_or_writes_modules(self):
        for request in (read_request(), set_request()):
            bus = Bus(paired=False)
            self.assertEqual(self.operate(bus, request)['error'], 'capability-unavailable')
            self.assertEqual(len(bus.calls), 1)

    def test_read_batch_is_parallel_and_at_most_eight_workers(self):
        bus = Bus(delay=.01)
        result = self.operate(bus, read_request(['native_' + str(i) for i in range(24)]))
        self.assertEqual(result['state'], 'observed')
        self.assertEqual(len(result['enabled']), 24)
        self.assertGreater(bus.maximum, 1)
        self.assertLessEqual(bus.maximum, 8)

    def test_partial_failure_preserves_only_observed_values(self):
        result = self.operate(Bus(fail='kdeconnect_share'), read_request())
        self.assertEqual(result['state'], 'failed')
        self.assertEqual(result['enabled'], {'kdeconnect_clipboard': False})
        self.assertEqual(result['error'], 'provider-unavailable')

    def test_malformed_native_values_never_become_boolean_state(self):
        result = self.operate(Bus(malformed=True), read_request())
        self.assertEqual(result['state'], 'failed')
        self.assertEqual(result['enabled'], {})

    def test_set_uses_fixed_native_method_then_actual_readback(self):
        bus = Bus()
        result = self.operate(bus, set_request())
        self.assertEqual(result, {'state': 'observed', 'peerId': 'peer_123', 'enabled': {'kdeconnect_clipboard': True}, 'error': ''})
        self.assertEqual([call[3] for call in bus.calls], ['GetAll', 'setPluginEnabled', 'isPluginEnabled'])
        self.assertEqual(bus.calls[1][4], ('(sb)', ('kdeconnect_clipboard', True)))

    def test_readback_mismatch_reports_actual_state_without_retry(self):
        bus = Bus(ignore_write=True)
        result = self.operate(bus, set_request())
        self.assertEqual(result['state'], 'observed')
        self.assertEqual(result['enabled'], {'kdeconnect_clipboard': False})
        self.assertEqual(result['error'], 'readback-mismatch')
        self.assertEqual(sum(call[3] == 'setPluginEnabled' for call in bus.calls), 1)

    def test_mutation_or_readback_timeout_is_unknown_without_retry(self):
        for fail in ('setPluginEnabled', 'isPluginEnabled'):
            bus = Bus(fail=fail)
            result = self.operate(bus, set_request())
            self.assertEqual(result['state'], 'unknown')
            self.assertEqual(result['error'], 'submission-unknown')
            self.assertEqual(result['enabled'], {})
            self.assertEqual(sum(call[3] == 'setPluginEnabled' for call in bus.calls), 1)

    def test_expired_deadline_never_calls_provider(self):
        for request in (read_request(), set_request()):
            bus = Bus()
            result = self.operate(bus, request, deadline=time.monotonic() - 1)
            self.assertEqual(result['state'], 'failed')
            self.assertEqual(bus.calls, [])

    def test_strict_json_and_request_bounds(self):
        for request in (read_request(), set_request(), read_request(['native_' + str(i) for i in range(256)])):
            self.assertEqual(settings.read_request(io.BytesIO(json.dumps(request).encode())), request)
        invalid = [None, [], {}, {**read_request(), 'extra': True}, {**read_request(), 'pluginIds': []},
                   read_request(['same', 'same']), read_request(['native_' + str(i) for i in range(257)]),
                   {**read_request(), 'pluginIds': [1]}, {**read_request(), 'peerId': '../peer'},
                   {**set_request(), 'enabled': 1}, {**set_request(), 'pluginId': '../module'},
                   {**set_request(), 'pluginId': 'a' * 129}, {**set_request(), 'operation': 'shell'}]
        for value in invalid:
            with self.subTest(value=str(value)[:60]), self.assertRaises(settings.RequestError):
                settings.read_request(io.BytesIO(json.dumps(value).encode()))
        for raw in (b'', b'\xff', b'{}{}', b'{"peerId":"a","peerId":"b"}', b'x' * 65537):
            with self.subTest(raw=raw[:50]), self.assertRaises(settings.RequestError):
                settings.read_request(io.BytesIO(raw))

    def test_main_json_and_total_cancellation_budget(self):
        bus = Bus()
        gio = SimpleNamespace(**GIO.__dict__, Cancellable=mock.Mock(), BusType=SimpleNamespace(SESSION=1), bus_get_sync=lambda *_: bus)
        modules = {'gi': SimpleNamespace(require_version=lambda *_: None), 'gi.repository': SimpleNamespace(Gio=gio, GLib=GLIB)}
        output = io.StringIO()
        with mock.patch.dict(settings.sys.modules, modules), mock.patch.dict(settings.os.environ, {'DBUS_SESSION_BUS_ADDRESS': 'fake-private-bus'}), \
                mock.patch.object(settings.sys, 'stdin', SimpleNamespace(buffer=io.BytesIO(json.dumps(read_request()).encode()))), \
                mock.patch.object(settings.sys, 'stdout', output), mock.patch.object(settings.threading, 'Timer') as timer:
            self.assertEqual(settings.main(), 0)
            self.assertEqual(json.loads(output.getvalue())['state'], 'observed')
            timer.assert_called_once_with(5, gio.Cancellable.return_value.cancel)
            timer.return_value.start.assert_called_once_with()
            timer.return_value.cancel.assert_called_once_with()


if __name__ == '__main__':
    unittest.main()
