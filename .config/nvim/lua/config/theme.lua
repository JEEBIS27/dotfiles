local M = {}

M.available = { "tokyonight", "kanagawa", "catppuccin" }
M.default = "tokyonight"

local state_file = vim.fn.stdpath("state") .. "/colorscheme.txt"

local aliases = {
  ["tokyo"] = "tokyonight",
  ["tokyonight"] = "tokyonight",
  ["kanagawa"] = "kanagawa",
  ["kanagawa-dragon"] = "kanagawa",
  ["dragon"] = "kanagawa",
  ["cat"] = "catppuccin",
  ["catppuccin"] = "catppuccin",
  ["mocha"] = "catppuccin",
}

local function normalize(name)
  if not name or name == "" then
    return nil
  end
  return aliases[string.lower(name)]
end

local function read_saved_theme()
  if vim.uv.fs_stat(state_file) == nil then
    return nil
  end
  local lines = vim.fn.readfile(state_file)
  return normalize(lines[1])
end

local function save_theme(name)
  vim.fn.writefile({ name }, state_file)
end

function M.apply(name)
  local theme = normalize(name)
  if not theme then
    error("Unknown theme: " .. tostring(name))
  end

  local scheme_map = {
    tokyonight = "tokyonight",
    kanagawa = "kanagawa",
    catppuccin = "catppuccin",
  }
  local colorscheme = scheme_map[theme]
  vim.cmd.colorscheme(colorscheme)
  M.current = theme
  return theme
end

function M.set(name, opts)
  opts = opts or {}
  local theme = M.apply(name)
  if opts.persist ~= false then
    save_theme(theme)
  end
  if not opts.silent then
    vim.notify("Theme: " .. theme, vim.log.levels.INFO)
  end
  return theme
end

function M.toggle()
  local index = 1
  for i, name in ipairs(M.available) do
    if name == M.current then
      index = i
      break
    end
  end
  local next_theme = M.available[(index % #M.available) + 1]
  return M.set(next_theme)
end

local function list_themes()
  local current = M.current or "unknown"
  vim.notify("Themes: " .. table.concat(M.available, ", ") .. " (current: " .. current .. ")", vim.log.levels.INFO)
end

local function show_current_theme()
  local current = M.current or "unknown"
  vim.notify("Current theme: " .. current, vim.log.levels.INFO)
end

function M.setup_commands()
  if vim.fn.exists(":Theme") == 0 then
    vim.api.nvim_create_user_command("Theme", function(params)
      if params.args == "" then
        show_current_theme()
        return
      end
      local ok, err = pcall(M.set, params.args)
      if not ok then
        vim.notify(err, vim.log.levels.ERROR)
      end
    end, {
      nargs = "?",
      complete = function()
        return M.available
      end,
      desc = "現在テーマ表示 or 変更（Theme / Theme tokyonight など）",
    })
  end

  if vim.fn.exists(":ThemeToggle") == 0 then
    vim.api.nvim_create_user_command("ThemeToggle", function()
      M.toggle()
    end, { desc = "テーマを順番に切り替え" })
  end

  if vim.fn.exists(":ThemeList") == 0 then
    vim.api.nvim_create_user_command("ThemeList", function()
      list_themes()
    end, { desc = "利用可能テーマ一覧を表示" })
  end
end

function M.setup()
  M.setup_commands()
  local requested = read_saved_theme() or M.default
  local ok, err = pcall(M.set, requested, { persist = false, silent = true })
  if not ok then
    vim.notify("Failed to apply theme '" .. tostring(requested) .. "': " .. tostring(err), vim.log.levels.ERROR)
    M.set(M.default, { persist = false, silent = true })
  end
end

return M
