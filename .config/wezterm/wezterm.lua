local wezterm = require("wezterm")
local config = wezterm.config_builder()
local theme = require("theme")

-- 透過度と背景装置の状態管理（グローバル）
OPACITY_STATES = {
  { opacity = 1.0, backdrop = "Tabbed" },    -- 非透明
  { opacity = 0.75, backdrop = "Acrylic" },  -- 半透明
  { opacity = 0.5, backdrop = "Disable" }    -- 完全透明
}
CURRENT_OPACITY_INDEX = 1
STATE_BEFORE_FULL_TRANSPARENT = 1  -- 完全透明に入る前の状態

-- マウスを無効化
config.disable_default_mouse_bindings = true

config.automatically_reload_config = true
config.font = wezterm.font("HackGen35 Console NF")
config.font_size = 14.0
config.use_ime = true
config.window_background_opacity = 1.0
-- 背景画像を有効化
-- config.background = background
config.win32_system_backdrop = "Tabbed"
local initial_theme = theme.load_initial()
theme.apply_to_config(config, initial_theme)
-- 保持する行数
config.scrollback_lines = 3500

-- スクロールを有効化
config.enable_scroll_bar = true
config.mouse_wheel_scrolls_tabs = true
config.window_close_confirmation = "NeverPrompt"
config.default_domain = 'WSL:Ubuntu'
local mux = wezterm.mux
wezterm.on("gui-startup", function()
  local tab, pane, window = mux.spawn_window{}
  window:gui_window():maximize()
end)
----------------------------------------------------
-- Tab
----------------------------------------------------
-- タイトルバーを非表示
config.window_decorations = "RESIZE"
-- タブバーの表示
config.show_tabs_in_tab_bar = true
-- タブが一つの時は非表示
config.hide_tab_bar_if_only_one_tab = true
-- falseにするとタブバーの透過が効かなくなる
-- config.use_fancy_tab_bar = false

-- タブバーの透過
config.window_frame = {
  inactive_titlebar_bg = "none",
  active_titlebar_bg = "none",
}
-- タブバーを背景色に合わせる

-- タブの追加ボタンを非表示
config.show_new_tab_button_in_tab_bar = false

-- タブの閉じるボタンを非表示
config.show_close_tab_button_in_tabs = false

-- タブ同士の境界線を非表示
config.colors = {
  tab_bar = {
    inactive_tab_edge = "none",
  },
}

-- タブの形をカスタマイズ
-- タブの左側の装飾
local SOLID_LEFT_ARROW = wezterm.nerdfonts.ple_lower_right_triangle
-- タブの右側の装飾
local SOLID_RIGHT_ARROW = wezterm.nerdfonts.ple_upper_left_triangle

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
  local current_colors = theme.colors_for_config(config)
  local tab_bar = current_colors.tab_bar or {}
  local inactive_tab = tab_bar.inactive_tab or {}
  local active_tab = tab_bar.active_tab or {}
  local active_bg = "#F4A259"
  local background = inactive_tab.bg_color or "#A9A9A4"
  local foreground = inactive_tab.fg_color or "#FAF3ED"
  local edge_background = "none"
  if tab.is_active then
    background = active_bg
    foreground = active_tab.fg_color or current_colors.background or "#181616"
  end
  local edge_foreground = background
  local title = "          "
  return {
    { Background = { Color = edge_background } },
    { Foreground = { Color = edge_foreground } },
    { Text = SOLID_LEFT_ARROW },
    { Background = { Color = background } },
    { Foreground = { Color = foreground } },
    { Text = title },
    { Background = { Color = edge_background } },
    { Foreground = { Color = edge_foreground } },
    { Text = SOLID_RIGHT_ARROW },
  }
end)

wezterm.on("theme-toggle", function(window, pane)
  local next_theme = theme.next(theme.current(window))
  local applied_theme = theme.apply_to_window(window, next_theme)
  window:toast_notification("WezTerm Theme", "Theme: " .. applied_theme, nil, 2500)
end)

wezterm.on("theme-show", function(window, pane)
  window:toast_notification("WezTerm Theme", "Current theme: " .. theme.current(window), nil, 2500)
end)

----------------------------------------------------
-- keybinds
----------------------------------------------------
config.disable_default_key_bindings = true
config.keys = require("keybinds").keys
config.key_tables = require("keybinds").key_tables
config.leader = { key = "k", mods = "CTRL", timeout_milliseconds = 2000 }

return config
