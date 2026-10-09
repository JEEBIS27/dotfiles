return {

  -- Toggleterm: 統合ターミナル（VSCode風）
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
      require("toggleterm").setup({
        size = 16,  -- ターミナルの高さ
        open_mapping = [[<C-z>]],  -- VSCode風: Ctrl+zで開く
        hide_numbers = true,
        shade_filetypes = {},
        shade_terminals = true,
        shading_factor = 2,
        start_in_insert = true,
        insert_mappings = true,
        terminal_mappings = true,
        persist_size = true,
        persist_mode = true,
        direction = "float",  -- "vertical" | "horizontal" | "tab" | "float"
        close_on_exit = true,
        shell = vim.o.shell,
        float_opts = {
          border = "rounded",
          winblend = 0,
          highlights = {
            border = "Normal",
            background = "Normal",
          },
        },
      })

      -- ターミナルの便利なコマンド
      vim.api.nvim_create_user_command("VTerminal", ":1ToggleTerm", {})
      vim.api.nvim_create_user_command("HTerminal", ":2ToggleTerm direction=horizontal", {})

      -- ターミナルモードでのキーマップ
      local opts = { noremap = true }
      vim.keymap.set('t', '<C-z>', '<C-z><C-n>', opts)  -- <Esc>の代わりに使用可能
      vim.keymap.set('t', '<C-w>', '<C-z><C-n><C-w>', opts)  -- ウィンドウ操作
    end,
  },

  -- treesj: コードブロックの分割・結合
  {
    'Wansmer/treesj',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    keys = { { 'gm', desc = 'コードブロックを分割/結合' } },
    opts = {},
  },
}
