local M = {}

function M.auto_trigger_enabled(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local override = vim.b[bufnr].copilot_suggestion_auto_trigger
  if override ~= nil then return override end

  local ok, config = pcall(require, "copilot.config")
  return ok and config.suggestion.auto_trigger == true or false
end

return M
