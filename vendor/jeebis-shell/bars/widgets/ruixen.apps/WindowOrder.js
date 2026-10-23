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
