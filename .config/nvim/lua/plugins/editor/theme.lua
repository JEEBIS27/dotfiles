return {
  {
    "folke/tokyonight.nvim",
    priority = 1000,
    lazy = false,
    dependencies = {
      "rebelot/kanagawa.nvim",
      "catppuccin/nvim",
    },
    config = function()
      require('kanagawa').setup({
        compile = false,
        undercurl = true,
        commentStyle = { italic = true },
        functionStyle = {},
        keywordStyle = { italic = true},
        statementStyle = { bold = true },
        typeStyle = {},
        transparent = true,
        dimInactive = false,
        terminalColors = true,
        colors = {
          palette = {},
          theme = { wave = {}, lotus = {}, dragon = {}, all = {} },
        },
        overrides = function(colors)
          return {
            Normal = { bg = "none" },
            NormalNC = { bg = "none" },
            NormalFloat = { bg = "none" },
            FloatBorder = { bg = "none" },
            SignColumn = { bg = "none" },
            EndOfBuffer = { bg = "none" },
          }
        end,
        theme = "dragon",  -- "wave" (dark), "dragon" (dark), "lotus" (light)
        background = {
          dark = "wave",
          light = "lotus"
        },
      })

      require("tokyonight").setup({
        style = "moon",
        transparent = true,
        styles = {
          sidebars = "transparent",
          floats = "transparent",
        },
      })

      require("catppuccin").setup({
        flavour = "mocha",
        transparent_background = true,
      })

      require("config.theme").setup()
    end,
  },
}
