-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

-- Omarchy's bootstrap keeps path setup out of this user config.
local home = os.getenv("HOME")
package.path = home .. "/.config/?.lua;" .. package.path
local desktop = require("jeebis.desktop")
desktop.bootstrap()

-- Disable all Omarchy default bindings. Add your own in hypr/bindings.lua.
-- omarchy_default_bindings = false
--
-- Or disable only bindings for Omarchy's preinstalled apps/web apps while
-- keeping core window-manager bindings:
-- omarchy_preinstalled_bindings = false

-- Load Omarchy defaults.
desktop.defaults()

-- Put your personal overrides in these files. They're loaded after Omarchy's
-- defaults so package updates can improve the defaults without rewriting your
-- ~/.config/hypr files.
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
-- Personal geometry and pre-Ruixen window motion take precedence.
require("jeebis.curvature")
require("hypr.window-animations")
require("hypr.autostart")

-- Toggle config flags dynamically.
desktop.toggles()

-- Add any other personal Hyprland configuration below.
-- o.window("qemu", { workspace = "5" })

hl.config({
    misc = {
        -- Keep application minimum-size hints from forcing tiled windows
        -- outside their layout cells. Keyboard resize limits are handled in bindings.lua.
        size_limits_tiled = false,
    },
})
