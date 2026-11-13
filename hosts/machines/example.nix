# Home Manager machine profile: replace names/values with this PC's real ones.
# Not imported by default. GPU and boot/disk configuration belong to NixOS.
{ ... }: {
  jeebis.machine = {
    keyboard = { layout = "jp"; model = "jp106"; };
    touchpad = { tap = true; naturalScroll = true; };
    # outputs."eDP-1" = {
    #   scale = 1.25;
    #   mode = "1920x1080@60";
    #   position = { x = 0; y = 0; };
    #   transform = "normal";
    # };
    # touchOutput = "eDP-1";
  };
}
