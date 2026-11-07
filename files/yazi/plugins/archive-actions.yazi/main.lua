--- @since 26.8.15
local targets = ya.sync(function()
  local result = {}
  for _, file in pairs(cx.active.selected) do
    if not file.cha.is_dir then result[#result + 1] = tostring(file.url) end
  end
  if #cx.active.selected == 0 then
    local file = cx.active.current.hovered
    if file and not file.cha.is_dir then result[1] = tostring(file.url) end
  end
  return result
end)
return {
  entry = function()
    local files = targets()
    for i, path in ipairs(files) do
      ya.task("plugin", { "extract", args = { path, "", noisy = #files == 1 }, track = i == 1 })
        :name("Extract " .. path):spawn()
    end
  end,
}
