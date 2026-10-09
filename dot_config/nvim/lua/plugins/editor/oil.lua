return {
  -- oil.nvim: ファイルマネージャー（バッファのように編集可能）
  {
    'stevearc/oil.nvim',
    opts = {
      -- デフォルト設定
      default_file_explorer = false,
      columns = {
        "icon",
        -- "permissions",
        -- "size",
        -- "mtime",
      },
      buf_options = {
        buflisted = false,
        bufhidden = "hide",
      },
      win_options = {
        wrap = false,
        signcolumn = "no",
        cursorcolumn = false,
        foldcolumn = "0",
        spell = false,
        list = false,
        conceallevel = 3,
        concealcursor = "nvic",
      },
      delete_to_trash = false,
      skip_confirm_for_simple_edits = false,
      prompt_save_on_select_new_entry = true,
      cleanup_delay_ms = 2000,
      keymaps = {
        ["g?"] = "actions.show_help", -- ヘルプを表示
        ["<CR>"] = "actions.select", -- ファイル/ディレクトリを開く
        ["<C-v>"] = {
          callback = function()
            local oil = require('oil')
            local entry = oil.get_cursor_entry()
            if not entry then return end
            if entry.type ~= 'file' then
              oil.select()
              return
            end
            local filepath = oil.get_current_dir() .. entry.name
            -- 直前バッファ（oil を開く前に表示していたファイル）を記憶
            local alt_buf = vim.fn.bufnr('#')
            -- 右に vsplit してファイルを開く（フォーカスは右に移動）
            vim.cmd('vsplit ' .. vim.fn.fnameescape(filepath))
            local file_win = vim.api.nvim_get_current_win()
            -- 左（oil）ウィンドウに戻る
            vim.cmd('wincmd p')
            if alt_buf > 0 and vim.api.nvim_buf_is_valid(alt_buf)
              and vim.bo[alt_buf].filetype ~= 'oil' then
              -- 直前のファイルを oil ウィンドウに表示して2分割を維持
              vim.api.nvim_win_set_buf(0, alt_buf)
            else
              -- 直前ファイルなし → oil ウィンドウを閉じる
              pcall(vim.api.nvim_win_close, vim.api.nvim_get_current_win(), false)
            end
            -- ファイルウィンドウにフォーカスを戻す
            if vim.api.nvim_win_is_valid(file_win) then
              vim.api.nvim_set_current_win(file_win)
            end
          end,
          desc = "縦分割で開き oil を閉じる",
        }, -- 縦分割で開く（oil を自動で閉じる）
        ["<C-p>"] = "actions.preview", -- プレビューを表示
        ["<esc>"] = "actions.close", -- oil.nvimを閉じる
        ["<C-r>"] = "actions.refresh", -- 表示を更新する
        ["-"] = "actions.parent", -- 親ディレクトリへ移動
        ["_"] = "actions.open_cwd", -- カレントディレクトリを開く
        ["`"] = "actions.cd", -- カレントディレクトリを変更
        ["~"] = "actions.tcd", -- タブのカレントディレクトリを変更
        ["<C-a>"] = "actions.toggle_hidden", -- 隠しファイルの表示をトグル
      },
      use_default_keymaps = true,
      view_options = {
        show_hidden = false,
        is_hidden_file = function(name, bufnr)
          return vim.startswith(name, ".")
        end,
        is_always_hidden = function(name, bufnr)
          return false
        end,
        sort = {
          { "type", "asc" },
          { "name", "asc" },
        },
      },
    },
    dependencies = { "nvim-tree/nvim-web-devicons" },
  },
}
