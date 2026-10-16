-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
o.bind("SUPER + SHIFT + S", "Capture Screenshot", "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Omarchy's default resize keys use physical keycodes 20/21 (the top-row
-- minus/equal keys), not the EQUAL/MINUS keysym names.
for _, modifiers in ipairs({
    "SUPER",
    "SUPER + SHIFT",
    "SUPER + ALT",
    "SUPER + SHIFT + ALT",
    "SUPER + CTRL",
    "SUPER + CTRL + SHIFT",
}) do
    hl.unbind(modifiers .. " + code:20")
    hl.unbind(modifiers .. " + code:21")
end

-- Tiled window size bounds as fractions of the monitor's usable dimensions.
-- 0.25 means one quarter; 0.75 means three quarters.
local MIN_WINDOW_RATIO = 0.25
local MAX_WINDOW_RATIO = 0.75
local RESIZE_STEP = 50

-- Scroll時、フォーカス列の左右位置に応じて通常リサイズ方向を反転する。
-- trueで有効、falseで無効。
local SCROLL_RESIZE_DIRECTION_BY_FOCUS = false

-- Monitor width/height are reported in output pixels; window geometry uses
-- logical pixels. Convert before comparing ratios (especially with scale > 1).
local function logical_monitor_size(monitor)
    local scale = monitor.scale or 1
    if scale <= 0 then
        scale = 1
    end
    return monitor.width / scale, monitor.height / scale
end

local directions = {
    {
        key = "LEFT", vim = "H", direction = "l", scroll_direction = "l",
        resize = { x = -RESIZE_STEP }, scroll_resize = { x = -RESIZE_STEP },
    },
    {
        key = "DOWN", vim = "J", direction = "d", scroll_direction = "l",
        resize = { y = RESIZE_STEP }, scroll_resize = { x = -RESIZE_STEP },
    },
    {
        key = "UP", vim = "K", direction = "u", scroll_direction = "r",
        resize = { y = -RESIZE_STEP }, scroll_resize = { x = RESIZE_STEP },
    },
    {
        key = "RIGHT", vim = "L", direction = "r", scroll_direction = "r",
        resize = { x = RESIZE_STEP }, scroll_resize = { x = RESIZE_STEP },
    },
}

local function is_scrolling()
    local workspace = hl.get_active_workspace()
    return workspace and workspace.tiled_layout == "scrolling"
end

local function focus_direction(item)
    local direction = is_scrolling() and item.scroll_direction or item.direction

    if is_scrolling() then
        hl.dispatch(hl.dsp.layout("focus " .. direction))
    else
        hl.dispatch(hl.dsp.focus({ direction = direction }))
    end
end

local function swap_direction(item)
    local direction = is_scrolling() and item.scroll_direction or item.direction
    hl.dispatch(hl.dsp.window.swap({ direction = direction }))
end

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

local function resize(item, target_ratio)
    local monitor = hl.get_active_monitor()
    local active = hl.get_active_window()
    if not monitor or not active then
        return
    end

    if is_scrolling() then
        local logical_width = logical_monitor_size(monitor)
        if logical_width <= 0 then
            return
        end

        local current = active.size.x / logical_width
        local requested = target_ratio and (target_ratio - current)
            or (item.scroll_resize.x or 0) / logical_width

        -- Scrolling columns resize from the focused column's side. Reverse the
        -- delta when the closest neighboring column is to the left, so the
        -- same key expands/shrinks the shared boundary consistently.
        local workspace = hl.get_active_workspace()
        local nearest_x_distance = math.huge
        local nearest_is_left = false
        if workspace then
            for _, other in ipairs(hl.get_workspace_windows(workspace.id)) do
                if not other.floating and other.address ~= active.address then
                    local active_center_x = active.at.x + active.size.x / 2
                    local other_center_x = other.at.x + other.size.x / 2
                    local dx = other_center_x - active_center_x
                    if math.abs(dx) > 1 and math.abs(dx) < nearest_x_distance then
                        nearest_x_distance = math.abs(dx)
                        nearest_is_left = dx < 0
                    end
                end
            end
        end
        if target_ratio then
            local target = clamp(target_ratio, MIN_WINDOW_RATIO, MAX_WINDOW_RATIO)
            -- Scrolling's colresize accepts an absolute column-width ratio.
            -- Use it directly so window gaps don't skew the measured surface width.
            hl.dispatch(hl.dsp.layout("colresize " .. string.format("%.4f", target)))
            return
        end

        if SCROLL_RESIZE_DIRECTION_BY_FOCUS and nearest_is_left then
            requested = -requested
        end

        local next_ratio = clamp(current + requested, MIN_WINDOW_RATIO, MAX_WINDOW_RATIO)
        local amount = string.format("%+.4f", next_ratio - current)
        if amount ~= "+0.0000" and amount ~= "-0.0000" then
            hl.dispatch(hl.dsp.layout("colresize " .. amount))
        end
        return
    end

    local amount = item.resize
    local axis = target_ratio and "x" or ((amount.x or 0) ~= 0 and "x" or "y")
    local logical_width, logical_height = logical_monitor_size(monitor)
    local dimension = axis == "x" and logical_width or logical_height
    local workspace = hl.get_active_workspace()
    local tiled = {}
    if workspace then
        for _, window in ipairs(hl.get_workspace_windows(workspace.id)) do
            if not window.floating then
                table.insert(tiled, window)
            end
        end
    end

    local delta = target_ratio and (target_ratio * dimension - active.size.x) or (amount[axis] or 0)
    if #tiled > 1 and dimension > 0 then
        local min_size = MIN_WINDOW_RATIO * dimension
        local max_size = MAX_WINDOW_RATIO * dimension
        local low_delta = min_size - active.size[axis]
        local high_delta = max_size - active.size[axis]
        local active_start = active.at[axis]
        local active_end = active_start + active.size[axis]
        local cross_axis = axis == "x" and "y" or "x"
        local active_cross_start = active.at[cross_axis]
        local active_cross_end = active_cross_start + active.size[cross_axis]

        -- Bound all touching Dwindle neighbors as well as the focused window.
        -- This keeps the opposite pane from crossing 0.75 when this pane shrinks.
        for _, other in ipairs(tiled) do
            if other.address ~= active.address then
                local other_start = other.at[axis]
                local other_end = other_start + other.size[axis]
                local other_cross_start = other.at[cross_axis]
                local other_cross_end = other_cross_start + other.size[cross_axis]
                local overlaps = math.min(active_cross_end, other_cross_end) > math.max(active_cross_start, other_cross_start)
                local adjacent = math.abs(active_end - other_start) <= 32 or math.abs(other_end - active_start) <= 32

                if overlaps and adjacent then
                    low_delta = math.max(low_delta, other.size[axis] - max_size)
                    high_delta = math.min(high_delta, other.size[axis] - min_size)
                end
            end
        end
        delta = clamp(delta, low_delta, high_delta)
    end
    if delta ~= 0 then
        hl.dispatch(hl.dsp.window.resize({
            x = axis == "x" and delta or 0,
            y = axis == "y" and delta or 0,
            relative = true,
        }))
    end
end

local function rightmost_column_is_full_width()
    if not is_scrolling() then
        return false
    end

    local monitor = hl.get_active_monitor()
    local active = hl.get_active_window()
    local workspace = hl.get_active_workspace()
    if not monitor or not active or not workspace then
        return false
    end

    local logical_width = logical_monitor_size(monitor)
    if logical_width <= 0 or active.size.x < logical_width * 0.9 then
        return false
    end

    local active_center_x = active.at.x + active.size.x / 2
    for _, other in ipairs(hl.get_workspace_windows(workspace.id)) do
        if not other.floating and other.address ~= active.address then
            local other_center_x = other.at.x + other.size.x / 2
            if other_center_x < active_center_x then
                return true
            end
        end
    end
    return false
end

local function move_to_previous_column_if_full_width_rightmost(was_full_width_rightmost)
    if not was_full_width_rightmost then
        return
    end

    local monitor = hl.get_active_monitor()
    local active = hl.get_active_window()
    if not monitor or not active then
        return
    end

    local logical_width = logical_monitor_size(monitor)
    -- Pan the scrolling view, then restore focus to the same window in case
    -- the layout selects a neighboring column while moving.
    hl.dispatch(hl.dsp.layout("move +" .. tostring(math.floor(logical_width / 2))))
    hl.dispatch(hl.dsp.focus({ window = active }))
end

-- SUPER + F 系: 最大化、通常のFullscreen、50%幅へ戻す
hl.unbind("SUPER + F")
o.bind("SUPER + F", "Toggle column fullscreen", function()
    local restore_rightmost_column = rightmost_column_is_full_width()
    hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
    if restore_rightmost_column then
        resize({ scroll_resize = { x = 0 }, resize = { x = 0 } }, 0.5)
        move_to_previous_column_if_full_width_rightmost(restore_rightmost_column)
    end
end)

hl.unbind("SUPER + SHIFT + F")
o.bind(
    "SUPER + SHIFT + F",
    "Toggle fullscreen",
    hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" })
)

-- 既定のSUPER + ALT + F (Full width) を、どちらのタイルレイアウトでも50%幅へ
hl.unbind("SUPER + ALT + F")
o.bind("SUPER + ALT + F", "Reset window width to 50%", function()
    local restore_rightmost_column = rightmost_column_is_full_width()
    resize({ scroll_resize = { x = 0 }, resize = { x = 0 } }, 0.5)
    move_to_previous_column_if_full_width_rightmost(restore_rightmost_column)
end)

for _, item in ipairs(directions) do
    -- SUPER + 矢印、および SUPER + H/J/K/L: フォーカス移動
    hl.unbind("SUPER + " .. item.key)
    hl.unbind("SUPER + " .. item.vim)
    o.bind("SUPER + " .. item.key, nil, function() focus_direction(item) end)
    o.bind("SUPER + " .. item.vim, nil, function() focus_direction(item) end)

    -- SUPER + SHIFT + 矢印、および SUPER + SHIFT + H/J/K/L: ウィンドウ交換
    hl.unbind("SUPER + SHIFT + " .. item.key)
    hl.unbind("SUPER + SHIFT + " .. item.vim)
    o.bind("SUPER + SHIFT + " .. item.key, nil, function() swap_direction(item) end)
    o.bind("SUPER + SHIFT + " .. item.vim, nil, function() swap_direction(item) end)

    -- SUPER + CTRL + H/J/K/L で拡張・縮小
    hl.unbind("SUPER + CTRL + " .. item.vim)
    o.bind("SUPER + CTRL + " .. item.vim, nil, function()
        resize(item)
    end)

    -- SUPER + CTRL + 矢印キーにも同じリサイズを割り当てる
    hl.unbind("SUPER + CTRL + " .. item.key)
    o.bind("SUPER + CTRL + " .. item.key, nil, function()
        resize(item)
    end)

end

-- 上のリサイズ割り当てと重なる既定機能を別キーへ移動
o.bind("SUPER + ALT + CTRL + H", "Hardware menu", "omarchy-menu toggle hardware")
o.bind("SUPER + ALT + CTRL + K", "Herdr keybindings", "omarchy-menu-herdr-keybindings")

-- H/J/K/L にあった既定機能を Shift 付きへ移し
o.bind("SUPER + SHIFT + ALT + J", "Toggle window split", hl.dsp.layout("togglesplit"))
o.bind("SUPER + SHIFT + ALT + K", "Keybindings", "omarchy-menu-keybindings")
o.bind("SUPER + SHIFT + ALT + L", "Toggle workspace layout", "omarchy-hyprland-workspace-layout-toggle")
