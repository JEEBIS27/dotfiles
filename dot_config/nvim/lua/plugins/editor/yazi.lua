return {
  {
    "mikavilpas/yazi.nvim",
    version = "*",
    event = "VeryLazy",
    dependencies = {
      { "nvim-lua/plenary.nvim", lazy = true },
    },
    opts = {
      -- Yazi本体のキー設定を維持し、Oilと同じ<C-v>だけ縦分割で開く。
      keymaps = {
        show_help = false,
        open_file_in_vertical_split = "<c-v>",
        open_file_in_horizontal_split = false,
        open_file_in_tab = false,
        grep_in_directory = false,
        replace_in_directory = false,
        cycle_open_buffers = false,
        copy_relative_path_to_selected_files = false,
        send_to_quickfix_list = false,
        change_working_directory = false,
        open_and_pick_window = false,
      },
      open_for_directories = true,
      change_neovim_cwd_on_close = false,
    },
    init = function()
      -- ディレクトリを開く処理をnetrwからYaziへ渡す。
      vim.g.loaded_netrwPlugin = 1
    end,
  },
}
