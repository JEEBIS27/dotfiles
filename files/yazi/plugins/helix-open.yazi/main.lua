-- Explicit chooser handoff also handles binary/archive files without running
-- their normal opener. Outside Helix, keep the ordinary open behavior.
local targets = ya.sync(function()
  local result = {}
  for _, file in pairs(cx.active.selected) do
    if not file.cha.is_dir then result[#result + 1] = tostring(file.url) end
  end
  if #cx.active.selected == 0 then
    local file = cx.active.current.hovered
    if file and file.cha.is_dir then return {}, true end
    if file then result[1] = tostring(file.url) end
  end
  return result, false
end)
return {
  entry = function(_, job)
    local state, selection = os.getenv("HELIX_YAZI_FILE"), os.getenv("HELIX_YAZI_SELECTION")
    if os.getenv("HELIX_YAZI_CHOOSER") ~= "1" or not state or not selection then
      return ya.emit("open", {})
    end
    local mode = job.args[1]
    if mode ~= "vsplit" and mode ~= "hsplit" then return end
    local files, directory = targets()
    if directory then return ya.emit("enter", {}) end
    if #files == 0 then return end
    local ok, err = fs.write(Url(state .. ".mode"), mode)
    if ok then ok, err = fs.write(Url(selection), table.concat(files, "\n") .. "\n") end
    if not ok then
      return ya.notify({ title = "Helix", content = tostring(err), level = "error", timeout = 5 })
    end
    ya.emit("quit", {})
  end,
}
