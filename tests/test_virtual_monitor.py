"""Native virtual-monitor requests use fixed D-Bus calls and fake providers."""
import importlib.util
import io
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('virtual_monitor', ROOT / 'scripts/virtual_monitor.py')
monitor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(monitor)


class Reply:
    def __init__(self, value): self.value = value
    def unpack(self): return self.value


class Bus:
    def __init__(self, active=False, available=True, paired=True, accepted=True):
        self.active, self.available, self.paired, self.accepted = active, available, paired, accepted
        self.calls = []

    def call_sync(self, service, path, interface, method, args, result_type, flags, timeout, cancellable):
        self.calls.append((service, path, interface, method, args, flags, timeout))
        if method == 'GetAll':
            data = {'active': self.active, 'isVirtualMonitorAvailable': self.available} if path.endswith('/virtualmonitor') else {'isPaired': self.paired, 'isReachable': True}
            return Reply((data,))
        if method == 'requestVirtualMonitor':
            self.active = self.accepted
            return Reply((self.accepted,))
        if method == 'stop':
            self.active = False
            return Reply(())
        raise AssertionError(method)


class VirtualMonitorTests(unittest.TestCase):
    def operate(self, bus, operation):
        gio = SimpleNamespace(DBusCallFlags=SimpleNamespace(NO_AUTO_START=2))
        glib = SimpleNamespace(Variant=lambda signature, value: (signature, value))
        monitor.operate(bus, gio, glib, None, 'peer_123', operation)
        self.assertTrue(all(call[0] == 'org.kde.kdeconnect' and call[1].startswith('/modules/kdeconnect/devices/peer_123') and call[5:] == (2, 1500) for call in bus.calls))

    def test_start_then_stop_uses_native_methods(self):
        bus = Bus()
        self.operate(bus, 'start')
        self.assertTrue(bus.active)
        self.assertEqual(bus.calls[-1][3], 'requestVirtualMonitor')
        self.operate(bus, 'stop')
        self.assertFalse(bus.active)
        self.assertEqual(bus.calls[-1][3], 'stop')

    def test_start_never_restarts_an_existing_session(self):
        bus = Bus(active=True)
        self.operate(bus, 'start')
        self.assertEqual([call[3] for call in bus.calls], ['GetAll', 'GetAll'])

    def test_native_failure_or_missing_prerequisites_is_not_acceptance(self):
        for bus in (Bus(available=False), Bus(paired=False), Bus(accepted=False)):
            with self.subTest(bus=bus), self.assertRaisesRegex(monitor.RequestError, 'capability-unavailable'):
                self.operate(bus, 'start')

    def test_input_is_bounded_and_cannot_select_arbitrary_bus_methods(self):
        self.assertEqual(monitor.read_request(io.BytesIO(b'{"peerId":"peer_123","operation":"start"}\n')), ('peer_123', 'start'))
        for raw in (b'{"peerId":"../peer","operation":"start"}', b'{"peerId":"peer","operation":"shell"}', b'{"peerId":"peer","operation":"stop","extra":true}', b'x' * 513):
            with self.subTest(raw=raw[:50]), self.assertRaises(monitor.RequestError):
                monitor.read_request(io.BytesIO(raw))


if __name__ == '__main__': unittest.main()
