function position(client) {
  var ipc = client.lastIpcObject || ({})
  var at = ipc.at || [0, 0]
  return { x: Number(at[0]) || 0, y: Number(at[1]) || 0 }
}
function spatial(clients) {
  return Array.prototype.slice.call(clients || []).sort(function(a, b) {
    var left = position(a), right = position(b)
    return left.x - right.x || left.y - right.y || String(a.address).localeCompare(String(b.address))
  })
}
function logicalWorkspaceId(workspace) {
  if (!workspace) return 0
  var name = String(workspace.name || "")
  var prefix = "special:jeebis-floats-"
  if (name.indexOf(prefix) === 0) {
    var encoded = name.slice(prefix.length)
    if (/^(?:[0-9a-f]{2})+$/i.test(encoded)) {
      var home = ""
      for (var i = 0; i < encoded.length; i += 2)
        home += String.fromCharCode(parseInt(encoded.slice(i, i + 2), 16))
      var id = Number(home)
      if (isFinite(id) && id > 0) return id
    }
  }
  return Number(workspace.id) || 0
}

// Jeebis: move one application's entire block to the target icon's slot.
function reorderPlan(windows, identities, source, target) {
  var from = identities.indexOf(source), to = identities.indexOf(target)
  if (from < 0 || to < 0 || from === to) return []
  var order = identities.slice()
  order.splice(to, 0, order.splice(from, 1)[0])
  var desired = []
  for (var i = 0; i < order.length; i++)
    for (var j = 0; j < windows.length; j++)
      if (windows[j].identity === order[i]) desired.push(windows[j].address)
  return desired
}
function reorderScript(windows, desired, floating) {
  if (!desired.length || windows.length !== desired.length) return ""
  function quoted(value) {
    var address = String(value)
    if (!/^(?:0x)?[0-9a-f]+$/i.test(address)) throw Error("Invalid window address")
    return JSON.stringify(address.indexOf("0x") === 0 ? address : "0x" + address)
  }
  var current = windows.map(function(w) { return quoted(w.address) })
  var wanted = desired.map(quoted)
  return 'local current={' + current.join(',') + '}; local wanted={' + wanted.join(',') + '}; '
    + 'local ws={}; for _,w in ipairs(hl.get_windows({mapped=true})) do ws[w.address]=w end; '
    + 'for _,a in ipairs(current) do if not ws[a] or ws[a].floating~=' + (floating ? 'true' : 'false') + ' then return end end; '
    + (floating
      ? 'local positions={}; for i,a in ipairs(current) do positions[i]={x=ws[a].at.x,y=ws[a].at.y} end; for i,a in ipairs(wanted) do hl.dispatch(hl.dsp.window.move({window=ws[a],x=positions[i].x,y=positions[i].y,relative=false})) end'
      : 'for i,a in ipairs(wanted) do if current[i]~=a then local j=i+1; while current[j]~=a do j=j+1 end; hl.dispatch(hl.dsp.window.swap({window=ws[current[i]],target=ws[a]})); current[i],current[j]=current[j],current[i] end end')
}
