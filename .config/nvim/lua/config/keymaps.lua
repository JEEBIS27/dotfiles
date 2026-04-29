-- ===================================
-- キーマッピング
-- ===================================

-- 保存と終了
vim.keymap.set('n', '<A-q>', '<cmd>qa<CR>', { desc = 'Neovimを終了' })  -- [ノーマル] ファイルを終了
vim.keymap.set('n', '<A-S-q>', '<cmd>qa!<CR>', { desc = 'Neovimを終了' })  -- [ノーマル] ファイルを終了
vim.keymap.set('n', '<Space>', function()
  local ok, suggestion = pcall(require, 'copilot.suggestion')
  if ok then
    suggestion.toggle_auto_trigger()
    local state = vim.b.copilot_suggestion_auto_trigger
    if state == nil then
      local ok_config, copilot_config = pcall(require, 'copilot.config')
      state = ok_config and copilot_config.suggestion.auto_trigger or false
    end
    vim.notify((state and 'ON' or 'OFF') .. ' Copilot suggestion auto_trigger', vim.log.levels.INFO)
  end
end, { desc = 'Copilot提案の自動表示をトグル' })
vim.keymap.set('n', '<C-s>', '<cmd>update<CR>', { desc = '保存' })  -- [ノーマル] ファイルを保存（変更があれば）
vim.keymap.set('i', '<C-s>', '<C-o><cmd>update<CR><Esc>', { desc = '保存' })  -- [挿入] ファイルを保存
vim.keymap.set('v', '<C-s>', '<Esc><cmd>update<CR>gv', { desc = '保存' })  -- [ビジュアル] ファイルを保存して選択を維持
vim.keymap.set('n', '<C-S-s>', '<cmd>update!<CR>', { desc = '保存' })  -- [ノーマル] ファイルを強制保存
vim.keymap.set('i', '<C-S-s>', '<C-o><cmd>update!<CR><Esc>', { desc = '保存' })  -- [挿入] ファイルを強制保存
vim.keymap.set('v', '<C-S-s>', '<Esc><cmd>update!<CR>gv', { desc = '保存' })  -- [ビジュアル] ファイルを強制保存して選択を維持
vim.keymap.set('n', '<C-n>', '<cmd>ene | startinsert<CR>', { desc = '新規ファイル作成' })  -- [ノーマル] ファイルを新規作成
vim.keymap.set('i', '<C-n>', '<Esc><cmd>ene | startinsert<CR>', { desc = '新規ファイル作成' })  -- [挿入] ファイルを新規作成
vim.keymap.set('v', '<C-n>', '<Esc><cmd>ene | startinsert<CR>', { desc = '新規ファイル作成' })  -- [ビジュアル] ファイルを新規作成

-- 単語選択
vim.keymap.set('v', 'v', 'V', { desc = '行選択' })  -- [ビジュアル] 行選択

-- 削除はブラックホールレジスタを使い、ペースト用レジスタを汚さない
vim.keymap.set({ 'n', 'v' }, 'x', '"_x', { desc = '削除（レジスタに保存しない）' })
vim.keymap.set({ 'n', 'v' }, '<Del>', '"_x', { desc = '削除（レジスタに保存しない）' })

-- oil.nvim でファイルエクスプローラーを開く
vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "親ディレクトリを開く" })  -- [ノーマル] oil.nvimでカレントディレクトリを開く

-- テーマ切り替え
vim.keymap.set("n", "<leader>tt", "<cmd>ThemeToggle<CR>", { desc = "テーマを順番に切り替え" })
vim.keymap.set("n", "<leader>tl", "<cmd>ThemeList<CR>", { desc = "利用可能テーマ一覧を表示" })

-- 検索ハイライトを消去
vim.keymap.set('n', '<Esc>', ':noh<CR>', { silent = true, desc = '検索ハイライトを消去' })  -- [ノーマル] 検索ハイライトを消去

-- カーソル移動
vim.keymap.set('n', '<C-Left>', 'b', { desc = 'prev 単語単位で移動（左）' })
vim.keymap.set('n', '<C-Right>', 'w', { desc = 'next 単語単位で移動（右）' })
vim.keymap.set('n', '<C-Up>', 'ge', { desc = 'prev 単語末尾に移動（左）' })
vim.keymap.set('n', '<C-Down>', 'e', { desc = 'next 単語末尾に移動（右）' })
vim.keymap.set('n', '<C-S-Left>', 'B', { desc = 'prev 単語単位で移動（左）' })
vim.keymap.set('n', '<C-S-Right>', 'W', { desc = 'next 単語単位で移動（右）' })
vim.keymap.set('n', '<C-S-Up>', 'gE', { desc = 'prev 単語末尾に移動（左）' })
vim.keymap.set('n', '<C-S-Down>', 'E', { desc = 'next 単語末尾に移動（右）' })
vim.keymap.set('i', '<C-Left>', '<C-o>b', { desc = 'prev 単語単位で移動（左）' })
vim.keymap.set('i', '<C-Right>', '<C-o>w', { desc = 'next 単語単位で移動（右）' })
vim.keymap.set('i', '<C-Up>', '<C-o>ge', { desc = 'prev 単語末尾に移動（左）' })
vim.keymap.set('i', '<C-Down>', '<C-o>e', { desc = 'next 単語末尾に移動（右）' })
vim.keymap.set('i', '<C-S-Left>', '<C-o>B', { desc = 'prev 単語単位で移動（左）' })
vim.keymap.set('i', '<C-S-Right>', '<C-o>W', { desc = 'next 単語単位で移動（右）' })
vim.keymap.set('i', '<C-S-Up>', '<C-o>gE', { desc = 'prev 単語末尾に移動（左）' })
vim.keymap.set('i', '<C-S-Down>', '<C-o>E', { desc = 'next 単語末尾に移動（右）' })
vim.keymap.set('v', '<C-Left>', 'b', { desc = 'prev 単語単位で移動（左）' })
vim.keymap.set('v', '<C-Right>', 'w', { desc = 'next 単語単位で移動（右）' })
vim.keymap.set('v', '<C-Up>', 'ge', { desc = 'prev 単語末尾に移動（左）' })
vim.keymap.set('v', '<C-Down>', 'e', { desc = 'next 単語末尾に移動（右）' })
vim.keymap.set('v', '<C-S-Left>', 'B', { desc = 'prev 単語単位で移動（左）' })
vim.keymap.set('v', '<C-S-Right>', 'W', { desc = 'next 単語単位で移動（右）' })
vim.keymap.set('v', '<C-S-Up>', 'gE', { desc = 'prev 単語末尾に移動（左）' })
vim.keymap.set('v', '<C-S-Down>', 'E', { desc = 'next 単語末尾に移動（右）' })

-- Alt ↑/↓でスクロール
vim.keymap.set('n', '<A-Up>', '<C-u>', { desc = '半ページ上へスクロール' })
vim.keymap.set('n', '<A-Down>', '<C-d>', { desc = '半ページ下へスクロール' })
vim.keymap.set('n', '<A-S-Up>', '<C-b>', { desc = '1ページ上へスクロール' })
vim.keymap.set('n', '<A-S-Down>', '<C-f>', { desc = '1ページ下へスクロール' })

-- PgUp/PgDn のスクロール量を半ページ（<C-u>/<C-d>相当）に変更
vim.keymap.set('n', '<PageUp>', '<C-u>', { desc = '半ページ上へスクロール' })
vim.keymap.set('n', '<PageDown>', '<C-d>', { desc = '半ページ下へスクロール' })
vim.keymap.set('n', '<S-PageUp>', '<C-b>', { desc = '1ページ上へスクロール' })
vim.keymap.set('n', '<S-PageDown>', '<C-f>', { desc = '1ページ下へスクロール' })

-- ウィンドウ移動
vim.keymap.set('n', '<A-Left>', '<C-w>h', { desc = 'prev ウィンドウへ移動（左）' })
vim.keymap.set('n', '<A-Right>', '<C-w>l', { desc = 'next ウィンドウへ移動（右）' })

-- ウィンドウ入れ替え（番号指定）
-- WezTerm: Ctrl+Alt+Shift++ → PaneSelect SwapWithActive
vim.keymap.set('n', '<A-+>', '<C-w>x', { desc = '2つのウィンドウを入れ替え' })

-- リサイズモード
-- WezTerm: Ctrl+Alt+= → resize_pane key table
do
  local function deactivate()
    pcall(vim.keymap.del, 'n', 'h')
    pcall(vim.keymap.del, 'n', 'l')
    vim.keymap.set('n', 'j', 'gj', { desc = '下へ移動（表示行）' })
    vim.keymap.set('n', 'k', 'gk', { desc = '上へ移動（表示行）' })
    pcall(vim.keymap.del, 'n', '<Left>')
    pcall(vim.keymap.del, 'n', '<Right>')
    pcall(vim.keymap.del, 'n', '<Up>')
    pcall(vim.keymap.del, 'n', '<Down>')
    pcall(vim.keymap.del, 'n', '<CR>')
    pcall(vim.keymap.del, 'n', '<Esc>')
    vim.notify('resize mode: 終了', vim.log.levels.INFO)
  end

  vim.keymap.set('n', '<A-=>', function()
    vim.notify('resize mode: hjkl / ←→↑↓ でリサイズ、Enter / Esc で終了', vim.log.levels.INFO)
    vim.keymap.set('n', 'h',       '<C-w><',   { desc = 'リサイズ: 左に縮小' })
    vim.keymap.set('n', 'l',       '<C-w>>',   { desc = 'リサイズ: 右に拡大' })
    vim.keymap.set('n', 'k',       '<C-w>+',   { desc = 'リサイズ: 上に拡大' })
    vim.keymap.set('n', 'j',       '<C-w>-',   { desc = 'リサイズ: 下に縮小' })
    vim.keymap.set('n', '<Left>',  '<C-w><',   { desc = 'リサイズ: 左に縮小' })
    vim.keymap.set('n', '<Right>', '<C-w>>',   { desc = 'リサイズ: 右に拡大' })
    vim.keymap.set('n', '<Up>',    '<C-w>+',   { desc = 'リサイズ: 上に拡大' })
    vim.keymap.set('n', '<Down>',  '<C-w>-',   { desc = 'リサイズ: 下に縮小' })
    vim.keymap.set('n', '<CR>',    deactivate, { desc = 'リサイズモードを終了' })
    vim.keymap.set('n', '<Esc>',   deactivate, { desc = 'リサイズモードを終了' })
  end, { desc = 'リサイズモードに入る' })
end

-- バッファ移動
vim.keymap.set('n', '<C-q>', '<cmd>bdelete<cr>', { desc = 'バッファを閉じる' })  -- [ノーマル] カレントバッファを閉じる

-- TABで次のバッファ
vim.keymap.set('n', '<Tab>', '<cmd>bn<CR>', { desc = '次のバッファ' })  -- [ノーマル] 次のバッファへ切り替え
vim.keymap.set('n', '<S-Tab>', '<cmd>bp<CR>', { desc = '前のバッファ' })  -- [ノーマル] 前のバッファへ切り替え

-- Top Pickers & Explorer
vim.keymap.set('n', '<C-f>', function() Snacks.picker.smart() end, { desc = "Smart Find Files" } )
vim.keymap.set('n', '<C-b>', function() Snacks.picker.buffers() end, { desc = "Buffers" } )
vim.keymap.set('n', '<C-g>', function() Snacks.picker.grep() end, { desc = "Grep" } )
vim.keymap.set('n', '<C-e>', function() Snacks.explorer() end, { desc = "File Explorer" } )
vim.keymap.set('n', '<C-S-f>', function() Snacks.picker.recent() end, { desc = "Recent" } )
-- git
vim.keymap.set('n', '<C-l>', function() Snacks.picker.git_log() end, { desc = "Git Log" } )
vim.keymap.set('n', '<C-d>', function() Snacks.picker.git_diff() end, { desc = "Git Diff" } )

-- 行の移動（表示行単位）
vim.keymap.set('n', 'j', 'gj', { desc = '下へ移動（表示行）' })  -- [ノーマル] 表示行単位で下へ移動
vim.keymap.set('n', 'k', 'gk', { desc = '上へ移動（表示行）' })  -- [ノーマル] 表示行単位で上へ移動

-- 現在行を画面上から任意行（Noiceのcmdline_popup高さと合わせる）に配置
vim.keymap.set('n', 'zz', function()
  local target_row = 7
  local view = vim.fn.winsaveview()
  view.topline = math.max(1, view.lnum - (target_row - 1))
  vim.fn.winrestview(view)
end, { desc = '現在行を上から7行目に配置' })

-- インデント調整後も選択を維持
vim.keymap.set('v', '<', '<gv', { desc = 'インデントを減らす' })  -- [ビジュアル] インデントを減らして選択を維持
vim.keymap.set('v', '>', '>gv', { desc = 'インデントを増やす' })  -- [ビジュアル] インデントを増やして選択を維持

-- 選択したテキストを移動
vim.keymap.set('v', 'J', ":m '>+1<CR>gv=gv", { desc = '選択行を下に移動' })  -- [ビジュアル] 選択行を1行下へ移動
vim.keymap.set('v', 'K', ":m '<-2<CR>gv=gv", { desc = '選択行を上に移動' })  -- [ビジュアル] 選択行を1行上へ移動
vim.keymap.set('v', '<S-Down>', ":m '>+1<CR>gv=gv", { desc = '選択行を下に移動' })  -- [ビジュアル] 選択行を1行下へ移動
vim.keymap.set('v', '<S-Up>', ":m '<-2<CR>gv=gv", { desc = '選択行を上に移動' })  -- [ビジュアル] 選択行を1行上へ移動
