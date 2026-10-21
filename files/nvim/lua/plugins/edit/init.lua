return {
  -- flash.nvim: f/F/t/T モーション
  {
    'folke/flash.nvim',
    event = 'VeryLazy',
    opts = {
      label = {
        before = true, -- ラベルをジャンプ先の左に表示
        after = false, -- 右には表示しない
      },
      modes = {
        char = {
          enabled = true,
          jump_labels = false, -- f/t はラベルなしで最初の候補へ直接ジャンプ
          char_actions = function() return {} end, -- f/t/F/T の自動繰り返しを無効化
          highlight = {
            backdrop = false,
            matches = false,  -- 候補ハイライトを無効
            groups = { match = 'Normal', current = 'Normal' }, -- ハイライトグループを無色に
          },
        },
      },
    },
    keys = {
      -- s: 文字検索で下にジャンプ
      { 's',  function() require('flash').jump() end, mode = { 'n', 'x', 'o' }, desc = '下にジャンプ' },
      -- S: 文字検索で上にジャンプ
      { 'S', function() require("flash").jump({ search = { forward = false },}) end, mode = { 'n', 'x', 'o' }, desc = '上にジャンプ' },
    },
  },

  -- mini.ai: vi"/va" 等のテキストオブジェクトを複数行に対応
  {
    'echasnovski/mini.ai',
    version = '*',
    event = 'VeryLazy',
    opts = {},
  },

  -- Comment.nvim: gcc/gc でコメントアウト・アンコメント
  {
    'numToStr/Comment.nvim',
    keys = { 'gc', 'gcc', { 'gc', mode = 'x' } },
    opts = {},
  },

  -- vim-repeat: . でプラグイン操作を繰り返せるようにする
  {
    'tpope/vim-repeat',
  },

  -- vim-sandwich: sa/sd/sr でテキストの囲みを追加・削除・置換
  {
    'machakann/vim-sandwich',
    keys = {
      { 'sa', mode = { 'n', 'x' } },
      { 'sd', mode = { 'n', 'x' } },
      { 'sr', mode = { 'n', 'x' } },
      { 'sdb' },
      { 'srb' },
    },
  },

  -- vim-exchange: cx でテキストを入れ替える
  {
    'tommcdo/vim-exchange',
    keys = {
      { 'cx', mode = { 'n', 'x' } },
      { 'cxx' },
      { 'X', mode = 'x' },
    },
  },

  -- dial.nvim: インクリメント・デクリメントを強化
  {
    'monaqa/dial.nvim',
    keys = {
      { '<C-a>', mode = { 'n', 'v' } },
      { '<C-x>', mode = { 'n', 'v' } },
    },
    config = function()
      local augend = require('dial.augend')
      require('dial.config').augends:register_group({
        default = {
          augend.integer.alias.decimal,
          augend.integer.alias.hex,
          augend.date.alias['%Y/%m/%d'],
          augend.constant.alias.bool,
        },
      })
      local map = require('dial.map')
      vim.keymap.set({ 'n', 'v' }, '<C-a>', map.inc_normal(),  { desc = 'インクリメント' })
      vim.keymap.set({ 'n', 'v' }, '<C-x>', map.dec_normal(),  { desc = 'デクリメント' })
    end,
  },
}
