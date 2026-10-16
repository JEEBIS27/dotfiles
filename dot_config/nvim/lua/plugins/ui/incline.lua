return {
  "b0o/incline.nvim",
  event = { "VeryLazy" },
  opts = function()
    local devicons = require("nvim-web-devicons")
    local colors = require("utils.colors")
    local palette = colors.palette
    local mode_style = require("utils.mode_colors")

    local function get_incline_background(props)
      if not props.focused then return "none" end

      local mode = vim.api.nvim_get_mode().mode
      local operator = _G._my_statuscolumn_operator
      local scene = mode_style.get_scene(mode, operator)
      return mode_style.background(scene)
    end

    local fg_active = palette.text
    local fg_inactive = palette.overlay0
    local icons = { error = "󰅚 ", warn = "󰀪 ", hint = "󰌶 ", info = " " }
    local diag_colors = {
      error = palette.red,
      warn = palette.peach,
      hint = palette.springBlue,
      info = palette.dragonBlue2,
    }

    --- @param props { buf: number, win: number, focused: boolean }
    local function get_diagnostic_label(props, bg)
      local label = {}

        for severity, icon in pairs(icons) do
          local n = #vim.diagnostic.get(props.buf, { severity = vim.diagnostic.severity[string.upper(severity)] })
          if n > 0 then
            table.insert(label, {
              icon .. n .. " ",
              guifg = props.focused and diag_colors[severity] or fg_inactive,
              guibg = bg,
            })
          end
        end
      if #label > 0 then
        table.insert(label, { "┊ ", guifg = fg_inactive, guibg = bg })
      end
      return label
    end

    local get_display_filename_and_dirname = require("plugins.ui.incline.get_display_filename_and_dirname")

    -- based on https://github.com/b0o/incline.nvim/discussions/32
    --- @param props { buf: number, win: number, focused: boolean }
    local function render(props)
      local filename, dirname = get_display_filename_and_dirname(props.buf)
      local item_bg = get_incline_background(props)

      local ft_icon, ft_color = devicons.get_icon_color(filename)

      local isReadonly = vim.bo[props.buf].readonly

      local fg_filename = props.focused and fg_active or fg_inactive

      return {
        { props.focused and "" or "", guifg = item_bg, guibg = "none" },
        { get_diagnostic_label(props, item_bg) },
        {
          (ft_icon and ft_icon .. " " or ""),
          guifg = props.focused and (ft_color or fg_active) or fg_inactive,
          guibg = item_bg,
        },
        {
          (isReadonly and " " or ""),
          guifg = fg_filename,
          guibg = item_bg,
        },
        {
          dirname and dirname .. "/" or "",
          guifg = props.focused and fg_active or fg_inactive,
          guibg = item_bg,
        },
        {
          filename,
          guifg = fg_filename,
          gui = props.focused and "bold" or "",
          guibg = item_bg,
        },
        {
          vim.bo[props.buf].modified and " ●" or "",
          guifg = props.focused and palette.peach or fg_inactive,
          guibg = item_bg,
        },
        { props.focused and "" or "", guifg = item_bg, guibg = "none" },
      }
    end

    return {
      highlight = {
        groups = {
          InclineNormal = { guibg = "none", guifg = fg_active },
          InclineNormalNC = { guibg = "none", guifg = fg_inactive },
        },
      },
      window = {
        options = {
          winblend = 0,
        },
        placement = {
          horizontal = "right",
          vertical = "bottom",
        },
        margin = { horizontal = 0, vertical = 0 },
        padding = 0,
      },
      render = render,
    }
  end,
}
