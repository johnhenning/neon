"""Runtime selection must work without Xcode-created default simulators."""
import json
import pathlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import ios_smoke

from ios_smoke import select_simulator


class SimulatorSelectionTests(unittest.TestCase):
    def setUp(self):
        self.phone = {'identifier': 'com.apple.CoreSimulator.SimDeviceType.iPhone-Duo',
                      'name': 'iPhone Duo', 'productFamily': 'iPhone'}
        self.pad = {'identifier': 'com.apple.CoreSimulator.SimDeviceType.iPad-Pro',
                    'name': 'iPad Pro', 'productFamily': 'iPad'}
        self.regular_phone = dict(self.phone, identifier='com.apple.CoreSimulator.SimDeviceType.iPhone',
                                  name='iPhone', minRuntimeVersionString='27.0.0')
        self.types = [self.phone, self.regular_phone, self.pad]
        self.runtimes = [
            {'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-27-0',
             'name': 'iOS 27.0', 'version': '27.0', 'isAvailable': True,
             'supportedDeviceTypes': [self.regular_phone, self.pad]},
            {'identifier': 'com.apple.CoreSimulator.SimRuntime.iOS-27-1',
             'name': 'iOS 27.1', 'version': '27.1', 'isAvailable': True,
             'supportedDeviceTypes': [self.phone]},
        ]

    def test_latest_compatible_runtime_per_family_without_default_devices(self):
        self.assertEqual(select_simulator(self.runtimes, self.types, 'iPhone'),
                         (self.runtimes[1], self.phone))
        self.assertEqual(select_simulator(self.runtimes, self.types, 'iPad'),
                         (self.runtimes[0], self.pad))

    def test_creates_and_cleans_disposable_devices_without_listing_defaults(self):
        calls = []

        def run(*args):
            calls.append(args)
            if args == ('list', 'runtimes', '-j'):
                return json.dumps({'runtimes': self.runtimes})
            if args == ('list', 'devicetypes', '-j'):
                return json.dumps({'devicetypes': self.types})
            if args[0] == 'create':
                return args[1]
            if args[0] == 'boot':
                # Stop before booting or exercising any UI, but verify cleanup.
                raise subprocess.CalledProcessError(1, args)
            return ''

        with tempfile.TemporaryDirectory() as directory:
            with patch.object(ios_smoke, 'run', side_effect=run), patch.object(
                    ios_smoke.sys, 'argv', ['ios_smoke.py', '/tmp/Neon.app', directory]):
                with self.assertRaises(SystemExit):
                    ios_smoke.main()
            self.assertTrue((pathlib.Path(directory) / 'iPad-failure.txt').exists())
        for family, runtime, kind in [('iPhone', self.runtimes[1], self.phone),
                                      ('iPad', self.runtimes[0], self.pad)]:
            self.assertIn(('create', f'Neon CI {family}', kind['identifier'],
                           runtime['identifier']), calls)
            self.assertIn(('shutdown', f'Neon CI {family}'), calls)
            self.assertIn(('delete', f'Neon CI {family}'), calls)
        self.assertFalse(any(call[:2] == ('list', 'devices') for call in calls))

    def test_unavailable_runtime_is_not_selected(self):
        self.runtimes[1]['isAvailable'] = False
        self.assertEqual(select_simulator(self.runtimes, self.types, 'iPhone')[0],
                         self.runtimes[0])

    def test_device_type_identifier_resolves_family_without_display_name_matching(self):
        self.runtimes[1]['supportedDeviceTypes'] = [
            {'deviceTypeIdentifier': self.phone['identifier'], 'name': 'Different display name'}]
        self.assertEqual(select_simulator(self.runtimes, self.types, 'iPhone')[1], self.phone)

    def test_missing_family_reports_useful_error(self):
        with self.assertRaisesRegex(ValueError, 'No available iOS runtime supports iPad'):
            select_simulator(self.runtimes[1:], self.types, 'iPad')

    def test_unsupported_global_type_is_not_assumed_compatible(self):
        self.runtimes[0]['supportedDeviceTypes'] = []
        with self.assertRaises(ValueError):
            select_simulator(self.runtimes, self.types, 'iPad')


if __name__ == '__main__':
    unittest.main()
