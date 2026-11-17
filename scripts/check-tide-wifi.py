"""Exercise the real libnm/libnma dialog against an isolated mock NetworkManager.

Needs PyGObject, python-dbusmock, dbus-python and Gtk/NM/NMA typelibs.
No real connections are read, saved, activated or disconnected.
"""
import importlib.util
import os
from pathlib import Path
import sys
import subprocess
import unittest
from unittest.mock import patch

os.environ['LC_ALL'] = 'C'
import gi
import dbus
from dbusmock import DBusTestCase

gi.require_version('Gtk', '3.0')
gi.require_version('NMA', '1.0')
gi.require_version('NM', '1.0')
from gi.repository import GLib, Gtk, NM

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('wifi', Path(os.environ.get('TIDE_WIFI_SOURCE', ROOT/'packages/desktop/tide-wifi.py')))
wifi = importlib.util.module_from_spec(spec)
spec.loader.exec_module(wifi)


class WifiTests(DBusTestCase):
    @classmethod
    def setUpClass(cls):
        super().setUpClass()
        cls.start_system_bus()
        cls.server, cls.manager = cls.spawn_server_template('networkmanager', {}, stdout=subprocess.DEVNULL)
        cls.mock = dbus.Interface(cls.manager, 'org.freedesktop.DBus.Mock')
        cls.device = cls.mock.AddWiFiDevice('wifi0', 'wlan0', 30)
        dev = cls.get_dbus(True).get_object('org.freedesktop.NetworkManager', cls.device)
        dbus.Interface(dev, 'org.freedesktop.DBus.Mock').AddProperties(
            'org.freedesktop.NetworkManager.Device', {'Capabilities': dbus.UInt32(1)})
        cls.paths = {}
        for i, (name, flags) in enumerate([('enterprise', 0x200), ('personal', 0x100), ('sae', 0x400), ('owe', 0x800), ('open', 0)]):
            cls.paths[name] = cls.mock.AddAccessPoint(cls.device, name, 'Test-'+name,
                '02:00:00:00:00:%02x' % i, 2, 2412, 54000, 80, flags | (0x88 if flags else 0))

    @classmethod
    def tearDownClass(cls):
        cls.server.terminate()
        cls.server.wait(timeout=5)
        super().tearDownClass()

    def assert_dialog(self, kind, expected):
        choices = []
        original = Gtk.Dialog.run

        def run(dialog):
            def walk(widget):
                if isinstance(widget, Gtk.ComboBox):
                    model = widget.get_model()
                    index = widget.get_active()
                    if model is not None and index >= 0:
                        value = model[index][0]
                        if isinstance(value, str): choices.append(value)
                if isinstance(widget, Gtk.Container):
                    for child in widget.get_children(): walk(child)
            walk(dialog)
            GLib.timeout_add(80, lambda: dialog.response(Gtk.ResponseType.CANCEL) or False)
            return original(dialog)

        with patch.object(Gtk.Dialog, 'run', run), patch.object(sys, 'argv',
                ['wifi', str(self.device), str(self.paths[kind]), '--preview']):
            self.assertEqual(wifi.main(), 0)
        self.assertTrue(any(expected in text for text in choices), choices)
        if kind == 'enterprise':
            self.assertFalse(any('Personal' in text for text in choices), choices)
        print('PASS', kind, choices)

    def test_enterprise(self): self.assert_dialog('enterprise', 'Enterprise')
    def test_personal(self): self.assert_dialog('personal', 'Personal')
    def test_sae(self): self.assert_dialog('sae', 'WPA3')
    def test_owe(self): self.assert_dialog('owe', 'Enhanced Open')
    def test_open(self): self.assert_dialog('open', 'None')

    def test_incompatible_saved_profile(self):
        client = NM.Client.new(None)
        dev = client.get_device_by_path(self.device)
        ap = next(a for a in dev.get_access_points() if a.get_path() == self.paths['enterprise'])
        def connection(key, timestamp):
            c = NM.SimpleConnection.new()
            general = NM.SettingConnection.new()
            general.props.id = 'same-ssid'
            general.props.type = '802-11-wireless'
            general.props.timestamp = timestamp
            c.add_setting(general)
            wireless = NM.SettingWireless.new()
            wireless.props.ssid = ap.get_ssid()
            c.add_setting(wireless)
            security = NM.SettingWirelessSecurity.new()
            security.props.key_mgmt = key
            c.add_setting(security)
            if key == 'wpa-eap':
                eap = NM.Setting8021x.new()
                eap.add_eap_method('peap')
                eap.props.identity = 'test'
                c.add_setting(eap)
            return c
        wrong = connection('wpa-psk', 999)
        correct = connection('wpa-eap', 1)
        class Device:
            def get_available_connections(self):return [wrong, correct]
        self.assertEqual(wifi.compatible_connections(Device(), ap), [correct])


if __name__ == '__main__': unittest.main()
