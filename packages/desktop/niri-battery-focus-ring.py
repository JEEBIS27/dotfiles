import sys
from pathlib import Path
from tempfile import NamedTemporaryFile

from gi.repository import Gio, GLib


UPOWER = "org.freedesktop.UPower"
UPOWER_PATH = "/org/freedesktop/UPower"
BATTERY_TYPE = 2
DEFAULT_COLOR = "#7FC8FF"


def focus_ring_color(on_battery, present, device_type, percentage):
    if (
        not on_battery
        or not present
        or device_type != BATTERY_TYPE
        or percentage is None
        or not 0 <= percentage <= 100
    ):
        return DEFAULT_COLOR
    if percentage <= 5:
        return "#FF5D73"
    if percentage <= 15:
        return "#FF9E64"
    if percentage <= 30:
        return "#F5D76E"
    return DEFAULT_COLOR


def write_color(path, color):
    config = f'layout {{ focus-ring {{ active-color "{color}"; }}; }}\n'
    if path.exists() and path.read_text(encoding="utf-8") == config:
        return

    # Niri can reload as soon as the file changes, so publish the whole file at once.
    with NamedTemporaryFile(
        mode="w", encoding="utf-8", dir=path.parent, delete=False
    ) as temporary:
        temporary_path = Path(temporary.name)
        try:
            temporary.write(config)
            temporary.close()
            temporary_path.replace(path)
        finally:
            temporary_path.unlink(missing_ok=True)


def cached_property(proxy, name):
    value = proxy.get_cached_property(name)
    return value.unpack() if value is not None else None


def main(path):
    bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
    upower = Gio.DBusProxy.new_sync(
        bus, Gio.DBusProxyFlags.NONE, None, UPOWER, UPOWER_PATH, UPOWER, None
    )
    battery = Gio.DBusProxy.new_sync(
        bus,
        Gio.DBusProxyFlags.NONE,
        None,
        UPOWER,
        f"{UPOWER_PATH}/devices/DisplayDevice",
        f"{UPOWER}.Device",
        None,
    )
    loop = GLib.MainLoop()
    failure = None

    def update(*_args):
        nonlocal failure
        try:
            color = focus_ring_color(
                cached_property(upower, "OnBattery"),
                cached_property(battery, "IsPresent"),
                cached_property(battery, "Type"),
                cached_property(battery, "Percentage"),
            )
            write_color(path, color)
        except OSError as error:
            failure = error
            loop.quit()

    for proxy in (upower, battery):
        proxy.connect("g-properties-changed", update)
        proxy.connect("notify::g-name-owner", update)
    update()
    if failure is None:
        loop.run()
    if failure is not None:
        raise failure


if __name__ == "__main__":
    main(Path(sys.argv[1]))
