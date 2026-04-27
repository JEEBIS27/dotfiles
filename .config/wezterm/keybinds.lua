local wezterm = require("wezterm")
local act = wezterm.action

-- Show which key table is active in the status area
wezterm.on("update-right-status", function(window, pane)
  local name = window:active_key_table()
  if name then
    name = "TABLE: " .. name
  end
  window:set_right_status(name or "")
end)

return {
  keys = {
    {
      -- workspaceの切り替え
      key = "w",
      mods = "LEADER",
      action = act.ShowLauncherArgs({ flags = "WORKSPACES", title = "Select workspace" }),
    },
    {
      --workspaceの名前変更
      key = "$",
      mods = "LEADER",
      action = act.PromptInputLine({
        description = "(wezterm) Set workspace title:",
        action = wezterm.action_callback(function(win, pane, line)
          if line then
            wezterm.mux.rename_workspace(wezterm.mux.get_active_workspace(), line)
          end
        end),
      }),
    },
    {
      key = "W",
      mods = "LEADER|SHIFT",
      action = act.PromptInputLine({
        description = "(wezterm) Create new workspace:",
        action = wezterm.action_callback(function(window, pane, line)
          if line then
            window:perform_action(
              act.SwitchToWorkspace({
                name = line,
              }),
              pane
            )
          end
        end),
      }),
    },
    -- Tab移動
    { key = "Tab", mods = "CTRL", action = act.ActivateTabRelative(1) },
    { key = "Tab", mods = "SHIFT|CTRL", action = act.ActivateTabRelative(-1) },
    -- Tab入れ替え
    { key = "{", mods = "LEADER", action = act({ MoveTabRelative = -1 }) },
    -- Tab新規作成
    { key = "t", mods = "CTRL", action = act.SpawnCommandInNewTab({ domain = "CurrentPaneDomain", cwd = "~" }) },
    -- Tabを閉じる
    { key = "w", mods = "CTRL|SHIFT", action = act({ CloseCurrentTab = { confirm = false } }) },

    -- コピーモード
    { key = 'x', mods = 'CTRL|SHIFT', action = act.ActivateKeyTable{ name = 'copy_mode', one_shot =false }, },
    { key = "x", mods = "CTRL|SHIFT", action = act.ActivateCopyMode },
    -- コピー
    { key = "c", mods = "CTRL|SHIFT", action = act.CopyTo("Clipboard") },
    -- 貼り付け
    { key = "v", mods = "CTRL|SHIFT", action = act.PasteFrom("Clipboard") },

    -- Pane作成 leader + \ or /
    { key = "\\", mods = "CTRL|ALT", action = act.SplitVertical({ domain = "CurrentPaneDomain", cwd = "~" }) },
    { key = "/", mods = "CTRL|ALT", action = act.SplitPane({ direction = "Right", size = { Percent = 50 }, command = { domain = "CurrentPaneDomain", cwd = "~" } }) },
    -- AI Chat を開始する Ctrl+Shift+i
    { key = "i", mods = "CTRL|SHIFT", action = act.SplitPane({ direction = "Right", size = { Percent = 33 }, command = { args = { "zsh", "-i", "-c", "chat" }, domain = "CurrentPaneDomain", cwd = "~" } }) },
    -- Paneを閉じる leader + x
    { key = "w", mods = "CTRL", action = act({ CloseCurrentPane = { confirm = false } }) },
    -- Pane移動 leader + hlkj
    { key = "LeftArrow", mods = "CTRL|ALT", action = act.ActivatePaneDirection("Left") },
    { key = "RightArrow", mods = "CTRL|ALT", action = act.ActivatePaneDirection("Right") },
    { key = "UpArrow", mods = "CTRL|ALT", action = act.ActivatePaneDirection("Up") },
    { key = "DownArrow", mods = "CTRL|ALT", action = act.ActivatePaneDirection("Down") },
    -- Pane選択・入れ替え（2ペインなら即入れ替え、3つ以上なら番号選択）
    {
      key = "+",
      mods = "CTRL|ALT|SHIFT",
      action = wezterm.action_callback(function(window, pane)
        local panes = window:active_tab():panes()
        if #panes <= 2 then
          window:perform_action(wezterm.action.RotatePanes("Clockwise"), pane)
        else
          window:perform_action(act.PaneSelect({ mode = "SwapWithActive", alphabet = "1234567890" }), pane)
        end
      end),
    },
    -- Paneサイズ変更
    { key = "=", mods = "CTRL|ALT", action = act.ActivateKeyTable({ name = "resize_pane", one_shot = false }) },

    -- フォントサイズ切替
    { key = "=", mods = "CTRL", action = act.IncreaseFontSize },
    { key = "-", mods = "CTRL", action = act.DecreaseFontSize },
    -- フォントサイズのリセット
    { key = "0", mods = "CTRL", action = act.ResetFontSize },

    -- 背景透過度トグル Alt+o (完全透明 ↔ 前の状態)
    {
      key = "o",
      mods = "ALT",
      action = wezterm.action_callback(function(win, pane)
        if CURRENT_OPACITY_INDEX == 3 then
          -- 完全透明から前の状態に戻す
          CURRENT_OPACITY_INDEX = STATE_BEFORE_FULL_TRANSPARENT
        else
          -- 前の状態を記録して完全透明に
          STATE_BEFORE_FULL_TRANSPARENT = CURRENT_OPACITY_INDEX
          CURRENT_OPACITY_INDEX = 3
        end
        local state = OPACITY_STATES[CURRENT_OPACITY_INDEX]
        win:set_config_overrides({
          window_background_opacity = state.opacity,
          win32_system_backdrop = state.backdrop
        })
      end),
    },

    -- 背景透過度トグル Alt+Shift+o (非透明 ↔ 半透明)
    {
      key = "o",
      mods = "ALT|SHIFT",
      action = wezterm.action_callback(function(win, pane)
        if CURRENT_OPACITY_INDEX == 1 then
          CURRENT_OPACITY_INDEX = 2  -- 半透明から非透明へ
        else
          CURRENT_OPACITY_INDEX = 1  -- 非透明から半透明へ
        end
        STATE_BEFORE_FULL_TRANSPARENT = CURRENT_OPACITY_INDEX
        local state = OPACITY_STATES[CURRENT_OPACITY_INDEX]
        win:set_config_overrides({
          window_background_opacity = state.opacity,
          win32_system_backdrop = state.backdrop
        })
      end),
    },
    -- テーマ切り替え Alt+t
    { key = "t", mods = "ALT", action = act.EmitEvent("theme-toggle") },
    -- 現在テーマ表示 Alt+Shift+t
    { key = "t", mods = "ALT|SHIFT", action = act.EmitEvent("theme-show") },

    -- タブ切替 Alt + 数字
    { key = "1", mods = "ALT", action = act.ActivateTab(0) },
    { key = "2", mods = "ALT", action = act.ActivateTab(1) },
    { key = "3", mods = "ALT", action = act.ActivateTab(2) },
    { key = "4", mods = "ALT", action = act.ActivateTab(3) },
    { key = "5", mods = "ALT", action = act.ActivateTab(4) },
    { key = "6", mods = "ALT", action = act.ActivateTab(5) },
    { key = "7", mods = "ALT", action = act.ActivateTab(6) },
    { key = "8", mods = "ALT", action = act.ActivateTab(7) },
    { key = "9", mods = "ALT", action = act.ActivateTab(-1) },

    -- 設定再読み込み
    { key = "r", mods = "SHIFT|CTRL", action = act.ReloadConfiguration },
  },
  -- キーテーブル
  -- https://wezfurlong.org/wezterm/config/key-tables.html
  key_tables = {
    -- Paneサイズ調整 leader + s
    resize_pane = {
      { key = "LeftArrow",  action = act.AdjustPaneSize({ "Left", 1 }) },
      { key = "RightArrow", action = act.AdjustPaneSize({ "Right", 1 }) },
      { key = "UpArrow",    action = act.AdjustPaneSize({ "Up", 1 }) },
      { key = "DownArrow",  action = act.AdjustPaneSize({ "Down", 1 }) },
      { key = "h", action = act.AdjustPaneSize({ "Left", 1 }) },
      { key = "l", action = act.AdjustPaneSize({ "Right", 1 }) },
      { key = "k", action = act.AdjustPaneSize({ "Up", 1 }) },
      { key = "j", action = act.AdjustPaneSize({ "Down", 1 }) },

      -- Cancel the mode by pressing escape
      { key = "Enter", action = "PopKeyTable" },
    },
    activate_pane = {
      { key = "LeftArrow",  action = act.ActivatePaneDirection("Left") },
      { key = "RightArrow", action = act.ActivatePaneDirection("Right") },
      { key = "UpArrow",    action = act.ActivatePaneDirection("Up") },
      { key = "DownArrow",  action = act.ActivatePaneDirection("Down") },
      { key = "h", action = act.ActivatePaneDirection("Left") },
      { key = "l", action = act.ActivatePaneDirection("Right") },
      { key = "k", action = act.ActivatePaneDirection("Up") },
      { key = "j", action = act.ActivatePaneDirection("Down") },
    },
    -- copyモード Ctrl+Shift+X
    copy_mode = {
      -- 移動
      { key = "LeftArrow",  mods = "NONE", action = act.CopyMode("MoveLeft") },
      { key = "DownArrow",  mods = "NONE", action = act.CopyMode("MoveDown") },
      { key = "UpArrow",    mods = "NONE", action = act.CopyMode("MoveUp") },
      { key = "RightArrow", mods = "NONE", action = act.CopyMode("MoveRight") },
      { key = "h", mods = "NONE", action = act.CopyMode("MoveLeft") },
      { key = "j", mods = "NONE", action = act.CopyMode("MoveDown") },
      { key = "k", mods = "NONE", action = act.CopyMode("MoveUp") },
      { key = "l", mods = "NONE", action = act.CopyMode("MoveRight") },
      -- 最初と最後に移動
      { key = "^",    mods = "NONE", action = act.CopyMode("MoveToStartOfLineContent") },
      { key = "$",    mods = "NONE", action = act.CopyMode("MoveToEndOfLineContent") },
      { key = "Home", mods = "NONE", action = act.CopyMode("MoveToStartOfLineContent") },
      { key = "End",  mods = "NONE", action = act.CopyMode("MoveToEndOfLineContent") },
      -- 左端に移動
      { key = "0", mods = "NONE", action = act.CopyMode("MoveToStartOfLine") },
      { key = "o", mods = "NONE", action = act.CopyMode("MoveToSelectionOtherEnd") },
      { key = "O", mods = "NONE", action = act.CopyMode("MoveToSelectionOtherEndHoriz") },
      --
      { key = ";", mods = "NONE", action = act.CopyMode("JumpAgain") },
      -- 単語ごと移動
      { key = "w", mods = "NONE", action = act.CopyMode("MoveForwardWord") },
      { key = "b", mods = "NONE", action = act.CopyMode("MoveBackwardWord") },
      { key = "e", mods = "NONE", action = act.CopyMode("MoveForwardWordEnd") },
      -- ジャンプ機能 t f
      { key = "t", mods = "NONE", action = act.CopyMode({ JumpForward = { prev_char = true } }) },
      { key = "f", mods = "NONE", action = act.CopyMode({ JumpForward = { prev_char = false } }) },
      { key = "T", mods = "NONE", action = act.CopyMode({ JumpBackward = { prev_char = true } }) },
      { key = "F", mods = "NONE", action = act.CopyMode({ JumpBackward = { prev_char = false } }) },
      -- 一番下へ
      { key = "G",    mods = "NONE", action = act.CopyMode("MoveToScrollbackBottom") },
      { key = "End",  mods = "CTRL", action = act.CopyMode("MoveToScrollbackBottom") },
      -- 一番上へ
      { key = "g",    mods = "NONE", action = act.CopyMode("MoveToScrollbackTop") },
      { key = "Home", mods = "CTRL", action = act.CopyMode("MoveToScrollbackTop") },
      -- viweport
      { key = "H", mods = "NONE", action = act.CopyMode("MoveToViewportTop") },
      { key = "L", mods = "NONE", action = act.CopyMode("MoveToViewportBottom") },
      { key = "M", mods = "NONE", action = act.CopyMode("MoveToViewportMiddle") },
      -- スクロール
      { key = "b",      mods = "CTRL", action = act.CopyMode("PageUp") },
      { key = "f",      mods = "CTRL", action = act.CopyMode("PageDown") },
      { key = "PageUp", mods = "NONE", action = act.CopyMode("PageUp") },
      { key = "PageDown", mods = "NONE", action = act.CopyMode("PageDown") },
      { key = "d", mods = "CTRL", action = act.CopyMode({ MoveByPage = 0.5 }) },
      { key = "u", mods = "CTRL", action = act.CopyMode({ MoveByPage = -0.5 }) },
      -- 範囲選択モード
      { key = "v", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Cell" }) },
      { key = "v", mods = "CTRL", action = act.CopyMode({ SetSelectionMode = "Block" }) },
      { key = "V", mods = "NONE", action = act.CopyMode({ SetSelectionMode = "Line" }) },
      -- コピー
      { key = "y", mods = "NONE", action = act.CopyTo("Clipboard") },

      -- コピーモードを終了
      {
        key = "Enter",
        mods = "NONE",
        action = act.Multiple({ { CopyTo = "ClipboardAndPrimarySelection" }, { CopyMode = "Close" } }),
      },
      { key = "Escape", mods = "NONE", action = act.CopyMode("Close") },
      { key = "c", mods = "CTRL", action = act.CopyMode("Close") },
      { key = "q", mods = "NONE", action = act.CopyMode("Close") },
    },
  },
}
