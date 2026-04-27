local M = {}

local fallback_palette = {
  -- Kanagawa (dragon) core colors
  oniViolet = "#957FB8",
  springBlue = "#7FB4CA",
  springGreen = "#98BB6C",
  dragonRed = "#c4746e",
  dragonOrange = "#b6927b",
  dragonYellow = "#c4b28a",
  dragonBlue2 = "#8ba4b0",
  dragonViolet = "#8992a7",
  dragonWhite = "#c5c9c5",
  dragonGray = "#a6a69c",
  dragonGray2 = "#9e9b93",
  dragonGray3 = "#7a8382",
  dragonBlack0 = "#0d0c0c",
  dragonBlack2 = "#1D1C19",
  dragonBlack3 = "#181616",
  dragonBlack4 = "#282727",
  dragonBlack5 = "#393836",
  sumiInk5 = "#363646",

  -- Compatibility aliases used by existing config
  mauve = "#8992a7",
  red = "#c4746e",
  peach = "#b6927b",
  yellow = "#c4b28a",
  green = "#98BB6C",
  sky = "#7FB4CA",
  blue = "#8ba4b0",
  text = "#c5c9c5",
  overlay2 = "#a6a69c",
  overlay1 = "#9e9b93",
  overlay0 = "#7a8382",
  surface2 = "#393836",
  surface1 = "#393836",
  surface0 = "#282727",
  base = "#181616",
  mantle = "#1D1C19",
  crust = "#0d0c0c",
}

local function build_kanagawa_palette()
  local ok, kanagawa_colors = pcall(require, "kanagawa.colors")
  if not (ok and kanagawa_colors and kanagawa_colors.setup) then
    return nil
  end

  local colors = kanagawa_colors.setup({ theme = "dragon" })
  local p = colors.palette
  return vim.tbl_extend("force", p, {
    mauve = p.dragonViolet,
    red = p.dragonRed,
    peach = p.dragonOrange,
    yellow = p.dragonYellow,
    green = p.dragonGreen or p.springGreen,
    sky = p.springBlue,
    blue = p.dragonBlue2,
    text = p.dragonWhite,
    overlay2 = p.dragonGray,
    overlay1 = p.dragonGray2,
    overlay0 = p.dragonGray3,
    surface2 = p.dragonBlack5,
    surface1 = p.dragonBlack5,
    surface0 = p.dragonBlack4,
    base = p.dragonBlack3,
    mantle = p.dragonBlack2,
    crust = p.dragonBlack0,
  })
end

local function build_tokyonight_palette()
  local ok, tokyonight_colors = pcall(require, "tokyonight.colors")
  if not (ok and tokyonight_colors and tokyonight_colors.setup) then
    return nil
  end

  local c = tokyonight_colors.setup({ style = "moon" })
  return {
    oniViolet = c.magenta or c.purple or "#bb9af7",
    springBlue = c.cyan or c.blue or "#7dcfff",
    springGreen = c.green or "#9ece6a",
    dragonRed = c.red or "#f7768e",
    dragonOrange = c.orange or "#ff9e64",
    dragonYellow = c.yellow or "#e0af68",
    dragonBlue2 = c.blue or "#7aa2f7",
    dragonViolet = c.purple or c.magenta or "#bb9af7",
    dragonWhite = c.fg or "#c0caf5",
    dragonGray = c.fg_gutter or c.dark5 or "#737aa2",
    dragonGray2 = c.comment or c.dark3 or "#565f89",
    dragonGray3 = c.dark3 or "#545c7e",
    dragonBlack0 = c.bg_dark or "#1f2335",
    dragonBlack2 = c.bg_dark or "#1f2335",
    dragonBlack3 = c.bg or "#222436",
    dragonBlack4 = c.bg_highlight or c.bg_visual or "#2f334d",
    dragonBlack5 = c.bg_highlight or "#2f334d",
    sumiInk5 = c.comment or c.dark3 or "#565f89",
    mauve = c.purple or c.magenta or "#bb9af7",
    red = c.red or "#f7768e",
    peach = c.orange or "#ff9e64",
    yellow = c.yellow or "#e0af68",
    green = c.green or "#9ece6a",
    sky = c.cyan or c.blue or "#7dcfff",
    blue = c.blue or "#7aa2f7",
    text = c.fg or "#c0caf5",
    overlay2 = c.fg_gutter or c.dark5 or "#737aa2",
    overlay1 = c.comment or c.dark3 or "#565f89",
    overlay0 = c.dark3 or "#545c7e",
    surface2 = c.bg_highlight or "#2f334d",
    surface1 = c.bg_highlight or "#2f334d",
    surface0 = c.bg_visual or c.bg_highlight or "#2f334d",
    base = c.bg or "#222436",
    mantle = c.bg_dark or "#1f2335",
    crust = c.bg_dark or "#1f2335",
  }
end

local function build_catppuccin_palette()
  local ok, catppuccin_palette = pcall(require, "catppuccin.palettes")
  if not (ok and catppuccin_palette and catppuccin_palette.get_palette) then
    return nil
  end

  local c = catppuccin_palette.get_palette("mocha")
  return {
    oniViolet = c.mauve or "#cba6f7",
    springBlue = c.sky or c.sapphire or "#89dceb",
    springGreen = c.green or "#a6e3a1",
    dragonRed = c.red or "#f38ba8",
    dragonOrange = c.peach or "#fab387",
    dragonYellow = c.yellow or "#f9e2af",
    dragonBlue2 = c.blue or "#89b4fa",
    dragonViolet = c.mauve or "#cba6f7",
    dragonWhite = c.text or "#cdd6f4",
    dragonGray = c.overlay2 or "#9399b2",
    dragonGray2 = c.overlay1 or "#7f849c",
    dragonGray3 = c.overlay0 or "#6c7086",
    dragonBlack0 = c.crust or "#11111b",
    dragonBlack2 = c.mantle or "#181825",
    dragonBlack3 = c.base or "#1e1e2e",
    dragonBlack4 = c.surface0 or "#313244",
    dragonBlack5 = c.surface1 or "#45475a",
    sumiInk5 = c.overlay1 or "#7f849c",
    mauve = c.mauve or "#cba6f7",
    red = c.red or "#f38ba8",
    peach = c.peach or "#fab387",
    yellow = c.yellow or "#f9e2af",
    green = c.green or "#a6e3a1",
    sky = c.sky or c.sapphire or "#89dceb",
    blue = c.blue or "#89b4fa",
    text = c.text or "#cdd6f4",
    overlay2 = c.overlay2 or "#9399b2",
    overlay1 = c.overlay1 or "#7f849c",
    overlay0 = c.overlay0 or "#6c7086",
    surface2 = c.surface2 or "#585b70",
    surface1 = c.surface1 or "#45475a",
    surface0 = c.surface0 or "#313244",
    base = c.base or "#1e1e2e",
    mantle = c.mantle or "#181825",
    crust = c.crust or "#11111b",
  }
end

function M.refresh_palette()
  local colors_name = string.lower(vim.g.colors_name or "")
  local palette = nil
  if colors_name:find("tokyonight") then
    palette = build_tokyonight_palette()
  elseif colors_name:find("kanagawa") then
    palette = build_kanagawa_palette()
  elseif colors_name:find("catppuccin") then
    palette = build_catppuccin_palette()
  end

  if not palette then
    palette = build_kanagawa_palette() or build_tokyonight_palette() or build_catppuccin_palette() or fallback_palette
  end

  M.palette = palette
  return palette
end

M.palette = M.refresh_palette()

local palette_group = vim.api.nvim_create_augroup("UserThemePaletteRefresh", { clear = true })
vim.api.nvim_create_autocmd("ColorScheme", {
  group = palette_group,
  callback = function()
    M.refresh_palette()
  end,
  desc = "テーマ変更時にカラーパレットを更新",
})

---@alias RGB { r: number, g: number, b: number }

---Converts a hex color code to RGB
---@param hex string Color code in '#RRGGBB' format
---@return RGB
function M.hex_to_rgb(hex)
  hex = hex:gsub("^#", "")
  if #hex ~= 6 then
    error("Invalid hex color code. Must be in the format #RRGGBB")
  end
  local r = tonumber(hex:sub(1, 2), 16)
  local g = tonumber(hex:sub(3, 4), 16)
  local b = tonumber(hex:sub(5, 6), 16)
  return { r = r, g = g, b = b }
end

---Converts RGB to a hex color code
---@param color RGB
---@return string Color code in '#RRGGBB' format
function M.rgb_to_hex(color)
  local function component_to_hex(c)
    return string.format("%02x", math.floor(c + 0.5))
  end
  local r = component_to_hex(color.r)
  local g = component_to_hex(color.g)
  local b = component_to_hex(color.b)
  return "#" .. r .. g .. b
end

---Performs alpha blending
---@param foreground string Foreground color in '#RRGGBB' format
---@param background string Background color in '#RRGGBB' format
---@param alpha number Alpha value between 0 and 1
---@return string Blended color in '#RRGGBB' format
function M.alpha_blend(foreground, background, alpha)
  -- Check if inputs are in the correct format
  if type(foreground) ~= "string" or type(background) ~= "string" then
    error("foreground and background must be strings in the format #RRGGBB")
  end

  local fg = M.hex_to_rgb(foreground)
  local bg = M.hex_to_rgb(background)

  -- Clamp alpha value between 0 and 1
  alpha = math.max(0, math.min(1, alpha))

  local r = fg.r * alpha + bg.r * (1 - alpha)
  local g = fg.g * alpha + bg.g * (1 - alpha)
  local b = fg.b * alpha + bg.b * (1 - alpha)

  return M.rgb_to_hex({ r = r, g = g, b = b })
end

return M
