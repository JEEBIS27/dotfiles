// Only actual regular workspaces belong in the switcher. Scratchpads use
// negative IDs and do not count toward the two-workspace visibility threshold.
function activeIds(workspaces, focusedId) {
  var ids = []
  var values = workspaces || []
  for (var i = 0; i < values.length; i++) {
    var id = Number(values[i].id)
    if (isFinite(id) && id > 0 && ids.indexOf(id) === -1) ids.push(id)
  }
  var focused = Number(focusedId)
  if (isFinite(focused) && focused > 0 && ids.indexOf(focused) === -1) ids.push(focused)
  ids.sort(function(a, b) { return a - b })
  return ids
}

function shouldShow(ids) {
  return ids.length >= 2
}
