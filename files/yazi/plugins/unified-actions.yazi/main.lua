--- @since 26.8.15
--- @sync entry
return {
  entry = function(_, job)
    local selected, wanted = cx.active.selected, {}
    for _, file in pairs(selected) do wanted[tostring(file.url)] = true end
    if next(wanted) == nil and cx.active.current.hovered then
      wanted[tostring(cx.active.current.hovered.url)] = true
    end
    local same, count = cx.yanked.is_cut, 0
    for _, file in pairs(cx.yanked) do
      count = count + 1
      if not wanted[tostring(file.url or file)] then same = false end
    end
    local size = 0
    for _ in pairs(wanted) do size = size + 1 end
    same = same and count == size
    if job.args[1] ~= "force-cut" and same then
      ya.emit("unyank", {})
    else
      ya.emit("yank", { cut = true })
    end
  end,
}
