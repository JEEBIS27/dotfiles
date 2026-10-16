local colors = require("utils.colors")
local palette = colors.palette

local M = {
  -- Kanagawaの色を、各UIが同じ色で参照する。
  colors = {
    normal = palette.waveBlue2 or "#2D4F67",
    copy = palette.yellow,
    delete = palette.red,
    insert = palette.sky,
    visual = palette.oniViolet,
  },
  line_opacity = {
    normal = 0.78,
    copy = 0.4,
    delete = 0.4,
    insert = 0.4,
    visual = 0.45,
  },
}

function M.get_scene(mode, operator)
  if mode:sub(1, 2) == "no" and vim.v.operator ~= "" then
    operator = vim.v.operator
  end

  if operator == "d" or operator == "c" then
    return "delete"
  elseif operator == "y" then
    return "copy"
  elseif mode:sub(1, 1) == "i" or mode:sub(1, 1) == "R" then
    return "insert"
  elseif mode:sub(1, 1) == "v" or mode:sub(1, 1) == "V" or mode:sub(1, 1) == "\22" then
    return "visual"
  end
  return "normal"
end

function M.background(scene)
  return colors.alpha_blend(M.colors[scene], palette.base, M.line_opacity[scene])
end

-- modes.nvim向けの既存オプション形式。Normal色は他のUI用。
function M.modes_opts()
  return {
    colors = {
      copy = M.colors.copy,
      delete = M.colors.delete,
      insert = M.colors.insert,
      visual = M.colors.visual,
    },
    line_opacity = {
      copy = M.line_opacity.copy,
      delete = M.line_opacity.delete,
      insert = M.line_opacity.insert,
      visual = M.line_opacity.visual,
    },
  }
end

return M
