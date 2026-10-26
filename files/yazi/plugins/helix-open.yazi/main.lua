-- Split actions apply only to the chooser launched by Helix's helper.
local is_directory = ya.sync(function()
  local hovered = cx.active.current.hovered
  return #cx.active.selected == 0 and hovered and hovered.cha.is_dir
end)

return {
  entry = function(_, job)
    local state = os.getenv("HELIX_YAZI_FILE")
    if os.getenv("HELIX_YAZI_CHOOSER") ~= "1" or not state then
      return ya.emit("open", {})
    end
    if is_directory() then return ya.emit("enter", {}) end

    local mode = job.args[1]
    if mode ~= "vsplit" and mode ~= "hsplit" then return end
    local ok, err = fs.write(Url(state .. ".mode"), mode)
    if not ok then
      return ya.notify({ title = "Helix", content = tostring(err), level = "error", timeout = 5 })
    end
    ya.emit("open", {})
  end,
}
