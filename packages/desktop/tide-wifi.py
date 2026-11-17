"""Use NetworkManager's Wi-Fi dialog with the selected AP, never a guessed PSK."""
import argparse
import getpass
import sys
import uuid


def compatible_connections(device, access_point):
    """SSID alone cannot distinguish Enterprise, Personal, or open profiles."""
    return sorted(
        (c for c in device.get_available_connections() if access_point.connection_valid(c)),
        key=lambda c: c.get_setting_connection().get_timestamp(), reverse=True,
    )



def enable_eap_negotiation(setting):
    """Offer only TLS tunnels compatible with the configured inner credentials.

    Let wpa_supplicant accept the server's EAP request instead of NAKing PEAP
    simply because a saved password profile happened to specify FAST. Never
    invent client certificates, PACs, inner methods, or weaker TLS/CA settings.
    """
    if setting is None:
        return False
    methods = [setting.get_eap_method(i) for i in range(setting.get_num_eap_methods())]
    if (not methods or not set(methods) <= {'peap', 'ttls', 'fast'}
            or setting.get_phase2_auth() != 'mschapv2'
            or setting.get_phase2_autheap()
            or setting.get_pac_file()
            or setting.get_client_cert_scheme() != 0
            or setting.get_private_key_scheme() != 0):
        return False
    changed = False
    for method in ('peap', 'ttls'):
        if method not in methods:
            setting.add_eap_method(method)
            changed = True
    return changed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('device')
    parser.add_argument('access_point')
    parser.add_argument('--preview', action='store_true', help='Show dialog without saving or connecting')
    args = parser.parse_args()

    import gi
    gi.require_version('Gtk', '3.0')
    gi.require_version('NM', '1.0')
    gi.require_version('NMA', '1.0')
    from gi.repository import GLib, Gtk, NM, NMA

    client = NM.Client.new(None)
    device = client.get_device_by_path(args.device)
    if not isinstance(device, NM.DeviceWifi):
        raise RuntimeError('The selected Wi-Fi device is no longer available.')
    ap = next((a for a in device.get_access_points() if a.get_path() == args.access_point), None)
    if ap is None or ap.get_ssid() is None:
        raise RuntimeError('The selected Wi-Fi network is no longer available. Refresh the list.')

    ssid = NM.utils_ssid_to_utf8(ap.get_ssid().get_data())
    saved = compatible_connections(device, ap)
    loop = GLib.MainLoop()
    errors = []

    def timed_out():
        errors.append('Authentication timed out. Check the identity, EAP method and certificates.')
        loop.quit()
        return False

    def wait_for_activation():
        timer = GLib.timeout_add_seconds(120, timed_out)
        loop.run()
        if GLib.MainContext.default().find_source_by_id(timer):
            GLib.source_remove(timer)

    def finish(source, result, adding):
        try:
            active = (source.add_and_activate_connection_finish(result) if adding
                      else source.activate_connection_finish(result))
            # The async method finishes before authentication/DHCP. Stay alive
            # until NM reports the outcome, and surface authentication failures.
            def changed(connection, state, reason):
                if state == NM.ActiveConnectionState.ACTIVATED:
                    loop.quit()
                elif state == NM.ActiveConnectionState.DEACTIVATED:
                    errors.append('Connection failed: ' + str(reason.value_nick))
                    loop.quit()
            active.connect('state-changed', changed)
            changed(active, active.get_state(), NM.ActiveConnectionStateReason.UNKNOWN)
        except GLib.Error as error:
            errors.append(error.message)
            loop.quit()

    if saved and not args.preview:
        connection = saved[0]
        if enable_eap_negotiation(connection.get_setting_802_1x()):
            def updated(source, result, unused):
                try:
                    source.commit_changes_finish(result)
                    client.activate_connection_async(connection, device, ap.get_path(), None, finish, False)
                except GLib.Error as error:
                    errors.append(error.message)
                    loop.quit()
            connection.commit_changes_async(True, None, updated, None)
        else:
            client.activate_connection_async(connection, device, ap.get_path(), None, finish, False)
        wait_for_activation()
    else:
        connection = NM.SimpleConnection.new()
        general = NM.SettingConnection.new()
        general.props.id = ssid
        general.props.uuid = str(uuid.uuid4())
        general.props.type = '802-11-wireless'
        general.props.autoconnect = True
        general.add_permission('user', getpass.getuser(), None)
        connection.add_setting(general)
        wireless = NM.SettingWireless.new()
        wireless.props.ssid = ap.get_ssid()
        wireless.props.mode = 'infrastructure'
        connection.add_setting(wireless)
        # libnma filters security choices using the real AP and device flags.
        # It also supplies EAP methods, identities, CA and client certificates.
        dialog = NMA.WifiDialog.new(client, connection, device, ap, False)
        if dialog is None:
            raise RuntimeError('Unable to open the Wi-Fi authentication dialog.')
        dialog.set_title('Wi-Fi — ' + ssid)
        response = dialog.run()
        if response == Gtk.ResponseType.OK and not args.preview:
            configured, selected_device, selected_ap = dialog.get_connection()
            enable_eap_negotiation(configured.get_setting_802_1x())
            # Reject a profile inconsistent with the AP before touching NM.
            if not ap.connection_valid(configured):
                errors.append('The selected authentication method does not match this network.')
            else:
                client.add_and_activate_connection_async(
                    configured, selected_device, selected_ap.get_path(), None, finish, True)
                dialog.hide()
                wait_for_activation()
        dialog.destroy()

    if errors:
        message = Gtk.MessageDialog(
            message_type=Gtk.MessageType.ERROR, buttons=Gtk.ButtonsType.CLOSE,
            text='Unable to connect to ' + ssid,
        )
        message.format_secondary_text(errors[0])
        message.run()
        message.destroy()
        return 1
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as error:
        # Do not print connection settings or secrets.
        print('Wi-Fi: ' + str(error), file=sys.stderr)
        sys.exit(1)
