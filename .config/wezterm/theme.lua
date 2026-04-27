local wezterm = require("wezterm")

local M = {}

M.available = { "tokyonight", "kanagawa", "catppuccin" }
M.default = "tokyonight"
M.state_file = (os.getenv("HOME") or "/tmp") .. "/.wezterm-theme.txt"

local aliases = {
  ["tokyo"] = "tokyonight",
  ["tokyonight"] = "tokyonight",
  ["kanagawa"] = "kanagawa",
  ["kanagawa-dragon"] = "kanagawa",
  ["dragon"] = "kanagawa",
  ["cat"] = "catppuccin",
  ["catppuccin"] = "catppuccin",
  ["mocha"] = "catppuccin",
}

local scheme_candidates = {
  tokyonight = {
    "tokyonight_moon",
    "tokyonight_night",
    "Tokyo Night Moon",
    "Tokyo Night",
    "tokyonight",
  },
  kanagawa = {
    "Kanagawa Dragon (Gogh)",
    "Kanagawa Dragon",
    "kanagawabones",
  },
  catppuccin = {
    "Catppuccin Mocha",
    "catppuccin-mocha",
    "Catppuccin",
  },
}

local function normalize(name)
  if not name or name == "" then
    return nil
  end
  return aliases[string.lower(name)]
end

local function read_saved_theme()
  local f = io.open(M.state_file, "r")
  if not f then
    return nil
  end
  local line = f:read("*l")
  f:close()
  return normalize(line)
end

local function save_theme(name)
  local f = io.open(M.state_file, "w")
  if not f then
    return
  end
  f:write(name .. "\n")
  f:close()
end

local function first_existing_scheme(candidates)
  local builtin = wezterm.color.get_builtin_schemes()
  for _, s in ipairs(candidates) do
    if builtin[s] then
      return s
    end
  end
  return nil
end

function M.resolve_scheme(theme_name)
  local name = normalize(theme_name) or M.default
  local candidates = scheme_candidates[name] or {}
  local scheme = first_existing_scheme(candidates)
  if scheme then
    return name, scheme
  end

  for _, fallback_name in ipairs(M.available) do
    local fallback_candidates = scheme_candidates[fallback_name] or {}
    local fallback_scheme = first_existing_scheme(fallback_candidates)
    if fallback_scheme then
      return fallback_name, fallback_scheme
    end
  end

  return "kanagawa", "Kanagawa Dragon (Gogh)"
end

local function colors_from_scheme(scheme_name)
  local builtin = wezterm.color.get_builtin_schemes()
  return builtin[scheme_name] or {}
end

function M.theme_from_scheme(scheme_name)
  for name, candidates in pairs(scheme_candidates) do
    for _, candidate in ipairs(candidates) do
      if candidate == scheme_name then
        return name
      end
    end
  end
  return nil
end

function M.current(window)
  local overrides = window and window:get_config_overrides() or nil
  local scheme = overrides and overrides.color_scheme or nil
  local from_scheme = M.theme_from_scheme(scheme)
  if from_scheme then
    return from_scheme
  end
  return read_saved_theme() or M.default
end

function M.next(current_theme)
  local current = normalize(current_theme) or M.default
  local idx = 1
  for i, name in ipairs(M.available) do
    if name == current then
      idx = i
      break
    end
  end
  return M.available[(idx % #M.available) + 1]
end

function M.apply_to_config(config, theme_name)
  local name, scheme = M.resolve_scheme(theme_name)
  local colors = colors_from_scheme(scheme)
  config.color_scheme = scheme
  config.window_background_gradient = {
    colors = { colors.background or "#181616" },
  }
  return name, scheme
end

function M.apply_to_window(window, theme_name)
  local name, scheme = M.resolve_scheme(theme_name)
  local colors = colors_from_scheme(scheme)
  local overrides = window:get_config_overrides() or {}
  overrides.color_scheme = scheme
  overrides.window_background_gradient = {
    colors = { colors.background or "#181616" },
  }
  window:set_config_overrides(overrides)
  save_theme(name)
  return name, scheme
end

function M.load_initial()
  local saved = read_saved_theme() or M.default
  local name = normalize(saved) or M.default
  return name
end

function M.colors_for_config(cfg)
  local scheme = cfg and cfg.color_scheme or nil
  if not scheme then
    local _, resolved = M.resolve_scheme(read_saved_theme() or M.default)
    scheme = resolved
  end
  return colors_from_scheme(scheme)
end

return M
