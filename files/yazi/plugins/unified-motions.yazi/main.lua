--- @since 26.8.15
local jump = ya.sync(function(_, count)
  ya.emit("arrow", { count - 1 - cx.active.current.cursor })
end)
return {
  entry = function(_, job)
    local count = tonumber(job.args[1])
    if not count or count < 1 then return end
    -- These actual keys are generated from the same layout as Helix.
    local down, up = job.args.down or "j", job.args.up or "k"
    local next_, previous = job.args.next or "w", job.args.previous or "e"
    local keys = {}
    for digit = 0, 9 do keys[#keys + 1] = { on = tostring(digit) } end
    for _, key in ipairs({ down, up, next_, previous, "<Down>", "<Up>", "g", "G" }) do
      keys[#keys + 1] = { on = key }
    end
    while true do
      local choice = ya.which({ cands = keys, silent = true })
      if not choice then return end
      local key = keys[choice].on
      local digit = tonumber(key)
      if digit then count = math.min(count * 10 + digit, 999999999)
      elseif key == down or key == next_ or key == "<Down>" then ya.emit("arrow", { count }); return
      elseif key == up or key == previous or key == "<Up>" then ya.emit("arrow", { -count }); return
      elseif key == "G" then jump(count); return
      elseif key == "g" then
        local target = ya.which({ cands = { { on = up }, { on = down } }, silent = true })
        if target == 1 then jump(count) elseif target == 2 then ya.emit("arrow", { "bot" }) end
        return
      end
    end
  end,
}
