-- Floating focus and visibility stay independent of the tiled layout.
local M = {}
local last_float, last_tile = {}, {}
local sync_pending, busy = false, false
local close_handoff
local BOUNDS_INTERVAL_MS = 20
local closing = {}
local overlap_state = {}
local pointer_drag = false
local saved_no_warps
local initialize_float
local float_config = require("jeebis.motion")
local overlap_delay = float_config.floatOverlapDelayMs or 1000
local overlap_threshold = (float_config.floatOverlapThresholdPercent or 95) / 100
local home_prefix = "jeebis-float-home-"

local function encode(value)
    return (value:gsub(".", function(c) return string.format("%02x", c:byte()) end))
end

local function home_tag(window)
    for _, tag in ipairs(window.tags or {}) do
        if tag:sub(1, #home_prefix) == home_prefix then return tag end
    end
end

local function parked_home(window)
    local tag = home_tag(window)
    if not tag then return end
    return (tag:sub(#home_prefix + 1):gsub("%x%x", function(hex) return string.char(tonumber(hex, 16)) end))
end

local function workspace_selector(ws)
    if ws.id > 0 then return tostring(ws.id) end
    return ws.name:match("^special:") and ws.name or "special:" .. ws.name
end

local function home_of(window)
    return parked_home(window) or (window.workspace and workspace_selector(window.workspace))
end

local suspended_prefix = "jeebis-float-fullscreen-"

local function suspended_mode(window)
    for _, tag in ipairs(window.tags or {}) do
        if tag == suspended_prefix .. "maximized" then return "maximized" end
        if tag == suspended_prefix .. "fullscreen" then return "fullscreen" end
    end
end

local function suspend_fullscreen(window)
    if not window.floating or window.fullscreen == 0 then return end
    local mode = window.fullscreen == 1 and "maximized" or "fullscreen"
    hl.dispatch(hl.dsp.window.tag({ window = window, tag = "+" .. suspended_prefix .. mode }))
    hl.dispatch(hl.dsp.window.fullscreen({ window = window, mode = mode, action = "unset", layout_aware = false }))
end

local function restore_fullscreen(window)
    local mode = suspended_mode(window)
    if not mode then return end
    hl.dispatch(hl.dsp.window.tag({ window = window, tag = "-" .. suspended_prefix .. mode }))
    hl.dispatch(hl.dsp.window.fullscreen({ window = window, mode = mode, action = "set", layout_aware = false }))
end

local function reveal(home)
    for _, window in ipairs(hl.get_windows({ mapped = true })) do
        if parked_home(window) == home then
            local tag = home_tag(window)
            hl.dispatch(hl.dsp.window.tag({ window = window, tag = "-" .. tag }))
            hl.dispatch(hl.dsp.window.move({ window = window, workspace = home, follow = false }))
        end
    end
end

local function remember(window)
    if not window or not window.workspace then return end
    local memory = window.floating and last_float or last_tile
    memory[home_of(window)] = window.address
end

function M.sync()
    if busy or close_handoff or pointer_drag then return end
    busy = true
    local active = hl.get_active_window()
    if not active then busy = false; return end
    local float_home = active and active.floating and home_of(active)
    if float_home then
        reveal(float_home)
        restore_fullscreen(active)
        -- Already active: refocusing here warps the pointer during mouse focus/drag.
        hl.dispatch(hl.dsp.window.alter_zorder({ window = active, mode = "top" }))
    end
    for _, window in ipairs(hl.get_windows({ mapped = true })) do
        -- Leave unrelated scratchpads / show-desktop storage in their own special workspace.
        local workspace = window.workspace
        local in_scope = workspace and (workspace.id > 0
            or (active.workspace and workspace.id == active.workspace.id))
        if in_scope and window.floating and not parked_home(window) and home_of(window) ~= float_home then
            local home = home_of(window)
            if home then
                suspend_fullscreen(window)
                hl.dispatch(hl.dsp.window.tag({ window = window, tag = "+" .. home_prefix .. encode(home) }))
                hl.dispatch(hl.dsp.window.move({
                    window = window, workspace = "special:jeebis-floats-" .. encode(home), follow = false,
                }))
            end
        end
    end
    busy = false
end

local function schedule_sync()
    if busy or sync_pending then return end
    sync_pending = true
    hl.timer(function()
        sync_pending = false
        M.sync()
    end, { timeout = 20, type = "oneshot" })
end

function M.focus(window)
    busy = true
    -- Omarchy transfers fullscreen to a tile when focus changes underneath it.
    -- Suspend the float first so the tile keeps its own layout and size.
    local previous = hl.get_active_window()
    if previous and previous.address ~= window.address then suspend_fullscreen(previous) end
    local home = home_of(window)
    if window.floating and home then
        reveal(home)
        restore_fullscreen(window)
    end
    hl.dispatch(hl.dsp.focus({ window = window }))
    if window.floating then
        hl.dispatch(hl.dsp.window.alter_zorder({ window = window, mode = "top" }))
    end
    busy = false
    remember(window)
    M.sync()
end

local function workspace_windows(workspace, include_hidden)
    local ws = workspace or hl.get_active_special_workspace() or hl.get_active_workspace()
    if not ws then return {}, nil end
    local home = workspace_selector(ws)
    local windows = {}
    for _, window in ipairs(hl.get_windows({ mapped = true })) do
        if home_of(window) == home and (include_hidden or not window.hidden) then table.insert(windows, window) end
    end
    return windows, home
end

M.workspace_windows = workspace_windows

local function recent(windows, address)
    table.sort(windows, function(a, b)
        if a.address == address then return b.address ~= address end
        if b.address == address then return false end
        local ar, br = a.focus_history_id or math.huge, b.focus_history_id or math.huge
        return ar < br or (ar == br and a.address < b.address)
    end)
    return windows[1]
end

function M.toggle_window()
    local active = hl.get_active_window()
    if not active then return end
    local entering = not active.floating
    hl.dispatch(hl.dsp.window.float({ window = active, action = entering and "on" or "off" }))
    if entering then initialize_float(active) end
    M.focus(active)
    schedule_sync()
end

function M.toggle_plane()
    local active = hl.get_active_window()
    if not active then return end
    local windows, ws = workspace_windows()
    if not ws then return end
    local floats, tiles = {}, {}
    for _, window in ipairs(windows) do
        table.insert(window.floating and floats or tiles, window)
    end
    if #floats == 0 then M.toggle_window(); return end
    local target = active.floating and recent(tiles, last_tile[ws])
        or (not active.floating and recent(floats, last_float[ws]))
    if target then M.focus(target) end
end

-- Float navigation always uses screen directions, including on Scrolling.
function M.focus_direction(direction)
    local active = hl.get_active_window()
    if not active or not active.floating then return false end
    local windows = workspace_windows()
    local floats, tiles = {}, {}
    for _, window in ipairs(windows) do
        if window.address ~= active.address then
            table.insert(window.floating and floats or tiles, window)
        end
    end
    local candidates = #floats > 0 and floats or tiles
    local horizontal = direction == "l" or direction == "r"
    local sign = (direction == "r" or direction == "d") and 1 or -1
    local ax, ay = active.at.x + active.size.x / 2, active.at.y + active.size.y / 2
    local target, score
    for _, window in ipairs(candidates) do
        local dx = window.at.x + window.size.x / 2 - ax
        local dy = window.at.y + window.size.y / 2 - ay
        local forward = sign * (horizontal and dx or dy)
        local cross = math.abs(horizontal and dy or dx)
        if forward > 1 then
            local cost = forward + cross * 2
            if not score or cost < score then target, score = window, cost end
        end
    end
    -- A sole float may cover the only tile; still let direction keys leave it.
    if not target and #floats == 0 then target = recent(tiles) end
    if target then M.focus(target) end
    return true
end

local function monitor_bounds(window)
    local monitor = window.monitor or hl.get_active_monitor()
    if not monitor then return end
    local scale = math.max(monitor.scale or 1, 0.01)
    return monitor.x, monitor.y, math.floor(monitor.width / scale), math.floor(monitor.height / scale)
end

local function clamp(value, low, high)
    return math.max(low, math.min(high, value))
end

local function bounded_geometry(window, x, y, width, height)
    local left, top, screen_width, screen_height = monitor_bounds(window)
    if not left then return end
    width = clamp(math.floor(width), 1, screen_width)
    height = clamp(math.floor(height), 1, screen_height)
    x = clamp(math.floor(x), left, left + screen_width - width)
    y = clamp(math.floor(y), top, top + screen_height - height)
    return x, y, width, height
end

local function apply_geometry(window, x, y, width, height)
    x, y, width, height = bounded_geometry(window, x, y, width, height)
    if not x then return end
    if window.size.x ~= width or window.size.y ~= height then
        hl.dispatch(hl.dsp.window.resize({ window = window, x = width, y = height, relative = false }))
    end
    if window.at.x ~= x or window.at.y ~= y then
        hl.dispatch(hl.dsp.window.move({ window = window, x = x, y = y, relative = false }))
    end
end

-- Only compare visible floats on the same workspace; tiles deliberately remain underneath.
-- Intersection is measured against the moving window's own area.
local function overlap_ratio(window, other)
    local width = math.max(0, math.min(window.at.x + window.size.x, other.at.x + other.size.x)
        - math.max(window.at.x, other.at.x))
    local height = math.max(0, math.min(window.at.y + window.size.y, other.at.y + other.size.y)
        - math.max(window.at.y, other.at.y))
    return width * height / math.max(1, window.size.x * window.size.y)
end

local function overlap_target(window, others)
    local target, largest
    for _, other in ipairs(others) do
        local ratio = overlap_ratio(window, other)
        if ratio >= overlap_threshold and (not largest or ratio > largest) then
            target, largest = other, ratio
        end
    end
    return target
end

local function peers(window)
    local result = {}
    for _, other in ipairs(hl.get_workspace_windows(window.workspace.id)) do
        if other.address ~= window.address and other.floating and other.fullscreen == 0
            and not other.hidden and not parked_home(other) then
            table.insert(result, other)
        end
    end
    return result
end

initialize_float = function(window)
    local left, top, sw, sh = monitor_bounds(window)
    if not left then return end
    local w, h = math.floor(sw / math.sqrt(2)), math.floor(sh / math.sqrt(2))
    local x, y = left + math.floor((sw - w) / 2), top + math.floor((sh - h) / 2)
    local others = peers(window)
    for _ = 1, #others + 1 do
        local occupied = false
        for _, other in ipairs(others) do
            if math.abs(x - other.at.x) < 24 and math.abs(y - other.at.y) < 24 then
                occupied = true; break
            end
        end
        if not occupied then break end
        x, y = x + 32, y + 32
        if x + w > left + sw or y + h > top + sh then x, y = left, top end
    end
    apply_geometry(window, x, y, w, h)
end

-- Move along the ray from the other center through our own center.
-- Coincident centers have no direction; use the initial cascade's down-right direction.
local function separate(window, others)
    local other = overlap_target(window, others)
    if not other then return end
    local dx = window.at.x + window.size.x / 2 - other.at.x - other.size.x / 2
    local dy = window.at.y + window.size.y / 2 - other.at.y - other.size.y / 2
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 0.01 then dx, dy, length = 1, 1, math.sqrt(2) end
    dx, dy = dx / length, dy / length
    local _, _, sw, sh = monitor_bounds(window)
    if not sw then return end
    local previous_x, previous_y = window.at.x, window.at.y
    local best
    for distance = 4, math.ceil(math.sqrt(sw * sw + sh * sh)) + 4, 4 do
        local x, y = bounded_geometry(window, window.at.x + dx * distance,
            window.at.y + dy * distance, window.size.x, window.size.y)
        if x == previous_x and y == previous_y then break end
        previous_x, previous_y = x, y
        local proposed = {at = {x = x, y = y}, size = window.size}
        best = {x, y}
        if not overlap_target(proposed, others) then break end
    end
    -- At a screen edge, take the available outward displacement without reversing.
    if best then apply_geometry(window, best[1], best[2], window.size.x, window.size.y) end
end

function M.move(dx, dy)
    local window = hl.get_active_window()
    if not window or not window.floating then return false end
    apply_geometry(window, window.at.x + dx, window.at.y + dy, window.size.x, window.size.y)
    return true
end

function M.resize(dx, dy, ratio)
    local window = hl.get_active_window()
    if not window or not window.floating then return false end
    local _, _, screen_width = monitor_bounds(window)
    if not screen_width then return true end
    local width = ratio and ratio * screen_width or window.size.x + dx
    local height = window.size.y + dy
    local _, _, bounded_width, bounded_height = bounded_geometry(window, window.at.x, window.at.y, width, height)
    local cx, cy = window.at.x + window.size.x / 2, window.at.y + window.size.y / 2
    apply_geometry(window, cx - bounded_width / 2, cy - bounded_height / 2, bounded_width, bounded_height)
    return true
end

function M.toggle_maximize()
    local window = hl.get_active_window()
    if not window or not window.floating then return false end
    hl.dispatch(hl.dsp.window.fullscreen({
        window = window, mode = "maximized", action = "toggle", layout_aware = false,
    }))
    return true
end

-- The compositor enforces the native cap during client and pointer resizes.
hl.window_rule({
    name = "jeebis-floating-screen-size",
    match = { float = true }, max_size = { "monitor_w", "monitor_h" },
})

function M.enforce_bounds()
    if pointer_drag then return end
    local active = hl.get_active_window()
    if not active or not active.floating then return end
    local seen = {}
    for _, window in ipairs(hl.get_workspace_windows(active.workspace.id)) do
        if window.floating and window.fullscreen == 0 and not window.hidden and not parked_home(window) then
            apply_geometry(window, window.at.x, window.at.y, window.size.x, window.size.y)
            seen[window.address] = true
            local geometry = table.concat({window.at.x, window.at.y, window.size.x, window.size.y}, ":")
            local previous = overlap_state[window.address]
            local others = peers(window)
            local nested = overlap_target(window, others) ~= nil
            -- Track only the focused window so a pair never pushes both members.
            if window.address == active.address and nested then
                local elapsed = previous and previous.geometry == geometry and previous.elapsed + BOUNDS_INTERVAL_MS or 0
                overlap_state[window.address] = {geometry = geometry, elapsed = elapsed}
                if elapsed >= overlap_delay then
                    separate(window, others)
                    overlap_state[window.address] = nil
                end
            else overlap_state[window.address] = nil end
        end
    end
    for address in pairs(overlap_state) do if not seen[address] then overlap_state[address] = nil end end
end

-- Wrap the native Super+left drag so warp suppression precedes its anchor capture.
-- Geometry dispatches and focus warps must not fight the compositor's drag anchor.
function M.begin_pointer_drag()
    if pointer_drag then return end
    local active = hl.get_active_window()
    if not active or not active.floating then return end
    pointer_drag = true
    overlap_state = {}
    saved_no_warps = hl.get_config("cursor.no_warps")
    hl.config({ cursor = { no_warps = true } })
end

function M.end_pointer_drag()
    if not pointer_drag then return end
    hl.config({ cursor = { no_warps = saved_no_warps == true } })
    saved_no_warps = nil
    pointer_drag = false
    overlap_state = {}
    schedule_sync()
end

-- Previously the stock Move window binding ran before our separate observer.
-- Keep its native dispatcher, but establish the guard before invoking it.
function M.start_pointer_drag()
    M.begin_pointer_drag()
    hl.dispatch(hl.dsp.window.drag())
end

hl.unbind("SUPER + mouse:272")
hl.bind("SUPER + mouse:272", M.start_pointer_drag, {
    description = "Move window", mouse = true,
})
-- Release still arrives if Super was released before the mouse button.
hl.bind("mouse:272", M.end_pointer_drag, {
    release = true, ignore_mods = true, non_consuming = true,
    description = "Resume float corrections after pointer drag",
})

-- This build has no window geometry event; also constrain mouse drags and app resizes.
hl.timer(M.enforce_bounds, { timeout = BOUNDS_INTERVAL_MS, type = "repeat" })

hl.on("window.close", function(window)
    if not window then return end
    closing[window.address] = true
    local active = hl.get_active_window()
    if not active or active.address ~= window.address then return end
    local home = home_of(window)
    if not home then return end
    local floats, tiles = {}, {}
    for _, other in ipairs(hl.get_windows({ mapped = true })) do
        if other.address ~= window.address and not closing[other.address] and home_of(other) == home then
            table.insert(other.floating and floats or tiles, other)
        end
    end
    if window.floating and #floats == 0 then return end
    if not window.floating and (#tiles > 0 or #floats == 0) then return end
    close_handoff = home
    hl.timer(function()
        local remaining_floats, remaining_tiles = {}, {}
        for _, other in ipairs(hl.get_windows({ mapped = true })) do
            if not closing[other.address] and home_of(other) == home then
                table.insert(other.floating and remaining_floats or remaining_tiles, other)
            end
        end
        close_handoff = nil
        local target
        if window.floating then
            target = recent(remaining_floats, last_float[home])
        elseif #remaining_tiles == 0 then
            target = recent(remaining_floats, last_float[home])
        end
        if target then M.focus(target) else M.sync() end
    end, { timeout = 60, type = "oneshot" })
end)
hl.on("window.destroy", function(window)
    -- Destroy notifications can contain an already invalid window handle.
    local address = window and window.address
    if address then closing[address] = nil end
end)

local function focus_opened_float(address)
    if not address then return end
    hl.timer(function()
        local opened
        for _, candidate in ipairs(hl.get_windows({ mapped = true })) do
            if candidate.address == address then opened = candidate; break end
        end
        local workspace = hl.get_active_workspace()
        if opened and opened.floating and workspace and home_of(opened) == workspace_selector(workspace) then
            M.focus(opened)
        end
    end, { timeout = 120, type = "oneshot" })
end

hl.on("window.active", function(window)
    if busy then return end
    remember(window)
    M.sync()
end)
hl.on("window.open", function(window)
    -- A new window can reuse an address whose destroy handle was invalid.
    local address = window and window.address
    if address then closing[address] = nil; focus_opened_float(address) end
    schedule_sync()
end)
hl.on("window.update_rules", schedule_sync)
hl.on("window.move_to_workspace", schedule_sync)
hl.on("workspace.active", schedule_sync)
hl.on("config.reloaded", schedule_sync)
-- The keybinding scanner supplies callable placeholder tables instead of live APIs.
-- Only inspect windows inside Hyprland; iterating placeholder tags never ends.
if type(hl.get_active_window) == "function" then
    remember(hl.get_active_window())
end
schedule_sync()
return M
