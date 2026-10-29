local M = {}

-- Edit only this table to move an app. false leaves the key unassigned here.
-- SUPER+ALT opens normally; SUPER+ALT+SHIFT opens the SAME app at full width.
-- H/J/K/L are reserved for movement. G/S/T retain existing desktop operations.
local APP_KEYS = {
    RETURN = "terminal",
    SPACE = "browser",
    A = "activity",
    B = "slides",
    C = "chatgpt",
    D = "codex",
    E = "sheets",
    F = "files",
    G = false, -- Window grouping
    H = false, -- Movement
    I = "slack",
    J = false, -- Movement / toggle window split
    K = false, -- Movement / keybindings menu
    L = false, -- Movement
    M = "spotify",
    N = "editor",
    O = "obsidian",
    P = false,
    Q = "calendar",
    R = "teams",
    S = false, -- Scratchpad
    T = false, -- Theme cycle
    U = "youtube",
    V = false,
    W = "docs",
    X = "localsend",
    Y = "yazi",
    Z = "zathura",
}
M.keys = APP_KEYS

local function matches(app, window)
    for _, class in ipairs(app.classes) do
        if (window.class or ""):lower() == class:lower()
            or (window.initial_class or window.initialClass or ""):lower() == class:lower() then
            return true
        end
    end
    return false
end

local function set_full_width(window, workspace)
    hl.dispatch(hl.dsp.focus({ window = window }))
    if window.fullscreen == 2 then return end
    if not window.floating and workspace.tiled_layout == "scrolling" then
        hl.dispatch(hl.dsp.layout("colresize 1"))
    else
        hl.dispatch(hl.dsp.window.fullscreen({
            window = window, mode = "maximized", action = "set",
            layout_aware = not window.floating,
        }))
    end
end

local generation = 0
local function launch(app, full_width)
    generation = generation + 1
    local request = generation
    local workspace = hl.get_active_workspace()
    local existing = {}
    if workspace and full_width then
        for _, window in ipairs(hl.get_workspace_windows(workspace.id)) do
            existing[window.address] = true
        end
    end
    hl.dispatch(hl.dsp.exec_cmd(app.command))
    if not full_width or not workspace then return end

    -- Match the launched app, never whichever window happens to be focused.
    -- Single-instance apps may activate an existing window instead of opening one.
    local attempts = 0
    local function await_window()
        if request ~= generation then return end
        local current = hl.get_active_workspace()
        if not current or current.id ~= workspace.id then return end
        attempts = attempts + 1
        for _, window in ipairs(hl.get_workspace_windows(workspace.id)) do
            if not existing[window.address] and matches(app, window) then
                set_full_width(window, current)
                return
            end
        end
        local active = hl.get_active_window()
        if attempts >= 8 and active and active.workspace.id == workspace.id and matches(app, active) then
            set_full_width(active, current)
            return
        end
        if attempts < 150 then
            hl.timer(await_window, { timeout = 100, type = "oneshot" })
        else
            hl.dispatch(hl.dsp.exec_cmd("notify-send 'Fullwidth launch' "
                .. o.shell_quote(app.name .. ": window not found on the launch workspace")))
        end
    end
    hl.timer(await_window, { timeout = 100, type = "oneshot" })
end

function M.setup(desktop)
    -- App definitions are separate from key choices. Add new apps here, then
    -- assign their ID in APP_KEYS above. Classes identify the correct window.
    local function app(name, command, ...)
        return { name = name, command = command, classes = { ... } }
    end
    local function webapp(name, url, id)
        local class = "org.jeebis.web." .. id
        -- Chromium may ignore --class when its browser process already exists;
        -- app-mode windows then use their URL-derived class instead.
        local host, path = url:match("^https?://([^/]+)(/.*)$")
        local url_class = "chrome-" .. host .. "_" .. path:gsub("/", "_") .. "-Default"
        return app(name, "omarchy-launch-webapp " .. o.shell_quote(url)
            .. " --new-window --class=" .. class, class, url_class)
    end
    local apps = {
        terminal = app("Terminal", "jeebis-terminal", "rio"),
        browser = app("Browser", desktop.command("browser"), "helium", "chromium", "chromium-browser"),
        activity = app("Activity (btop)", "jeebis-terminal --app-id=org.omarchy.btop -- btop", "org.omarchy.btop"),
        slides = webapp("Google Slides", "https://docs.google.com/presentation", "slides"),
        chatgpt = app("ChatGPT", o.launch("jeebis-chatgpt-new-window"), "chatgpt"),
        codex = app("Codex (TUIOS)", "jeebis-codex-tuios", "org.omarchy.codex"),
        sheets = webapp("Google Sheets", "https://docs.google.com/spreadsheets/", "sheets"),
        files = app("GUI file manager", o.launch("nautilus --new-window"), "org.gnome.Nautilus"),
        slack = app("Slack", o.launch("slack"), "Slack"),
        spotify = app("Spotify", o.launch("spotify"), "spotify"),
        editor = app("Editor (Helix)", "jeebis-terminal --app-id=org.omarchy.hx -- hx", "org.omarchy.hx"),
        obsidian = app("Obsidian", o.launch("obsidian"), "md.obsidian.Obsidian", "obsidian"),
        calendar = webapp("Google Calendar", "https://calendar.google.com/calendar", "calendar"),
        teams = webapp("Teams", "https://teams.cloud.microsoft/", "teams"),
        youtube = app("YouTube", o.launch("gtk-launch chrome-agimnkijcaahngcdmfeangaknmldooml-Default"),
            "crx_agimnkijcaahngcdmfeangaknmldooml", "chrome-agimnkijcaahngcdmfeangaknmldooml-Default"),
        docs = webapp("Google Docs", "https://docs.google.com/document", "docs"),
        localsend = app("LocalSend", o.launch("localsend"), "localsend", "localsend_app"),
        yazi = app("Yazi", o.launch([[jeebis-terminal --app-id=org.omarchy.yazi -- "$HOME/.nix-profile/bin/fish" -i -c '__jeebis_yazi; exec "$HOME/.nix-profile/bin/fish" -i']]), "org.omarchy.yazi"),
        zathura = app("Zathura", o.launch("zathura"), "org.pwmt.zathura", "Zathura"),
    }

    -- Also usable from hyprctl eval for a targeted launch without synthesizing keys.
    function M.launch_key(key, full_width)
        local id = assert(APP_KEYS[key], "Unassigned app key: " .. tostring(key))
        launch(assert(apps[id], "Unknown app ID: " .. tostring(id)), full_width == true)
    end

    -- Remove old aliases (including inherited Browser / private / Editor binds).
    for _, key in ipairs({
        "SUPER + N", "SUPER + Y", "SUPER + SHIFT + B", "SUPER + SHIFT + N",
        "SUPER + ALT + RETURN", "SUPER + SHIFT + ALT + RETURN",
        "SUPER + ALT + D", "SUPER + SHIFT + ALT + D",
        "SUPER + ALT + F", "SUPER + SHIFT + ALT + F",
        "SUPER + SHIFT + ALT + B", "SUPER + CTRL + SHIFT + T",
    }) do
        hl.unbind(key)
    end

    local keys = {}
    for key in pairs(APP_KEYS) do table.insert(keys, key) end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local id = APP_KEYS[key]
        if id then
            local definition = assert(apps[id], "Unknown app ID: " .. tostring(id))
            for _, full_width in ipairs({ false, true }) do
                local binding = "SUPER + ALT + " .. (full_width and "SHIFT + " or "") .. key
                hl.unbind(binding)
                desktop.bind(binding, definition.name .. (full_width and " (Fullwidth)" or ""),
                    function() M.launch_key(key, full_width) end)
            end
        end
    end
end

return M
