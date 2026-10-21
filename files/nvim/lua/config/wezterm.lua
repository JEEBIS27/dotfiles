-- Publish the current file label to the hosting WezTerm pane.
if vim.env.TERM_PROGRAM ~= "WezTerm" and not vim.env.WEZTERM_PANE then
  return
end

local function send(label)
  local sequence = "\027]1337;SetUserVar=NVIM_TAB_LABEL=" .. vim.base64.encode(label) .. "\007"
  if vim.env.TMUX then
    sequence = "\027Ptmux;" .. sequence:gsub("\027", "\027\027") .. "\027\\"
  end
  if vim.api.nvim_ui_send then
    vim.api.nvim_ui_send(sequence)
  else
    io.stdout:write(sequence)
    io.stdout:flush()
  end
end

local function update()
  local name = vim.api.nvim_buf_get_name(0)
  if vim.bo.buftype ~= "" or name == "" then
    send("")
    return
  end
  local filename = vim.fn.fnamemodify(name, ":t")
  local icon = "󰈔"
  local ok, devicons = pcall(require, "nvim-web-devicons")
  if ok then
    icon = devicons.get_icon(filename, vim.fn.fnamemodify(name, ":e"))
      or devicons.get_icon_by_filetype(vim.bo.filetype, { default = true })
      or icon
  end
  send(icon .. " " .. filename)
end

local group = vim.api.nvim_create_augroup("WezTermFileLabel", { clear = true })
vim.api.nvim_create_autocmd({ "VimEnter", "BufEnter", "BufFilePost", "FileType", "VimResume" }, {
  group = group,
  callback = function() vim.schedule(update) end,
})
vim.api.nvim_create_autocmd({ "VimLeavePre", "VimSuspend" }, {
  group = group,
  callback = function() send("") end,
})
