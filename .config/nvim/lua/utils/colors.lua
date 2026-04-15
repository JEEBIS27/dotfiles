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

local palette = fallback_palette
local ok, kanagawa_colors = pcall(require, "kanagawa.colors")
if ok and kanagawa_colors and kanagawa_colors.setup then
  local colors = kanagawa_colors.setup({ theme = "dragon" })
  local p = colors.palette
  palette = vim.tbl_extend("force", p, {
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

M.palette = palette

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
