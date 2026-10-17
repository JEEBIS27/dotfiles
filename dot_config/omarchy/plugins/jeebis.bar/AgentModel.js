// Match dedicated application IDs, never generic terminal titles.
function identity(client) {
  if (!client) return ""
  var ipc = client.lastIpcObject || ({})
  return String((client.wayland && client.wayland.appId) || ipc["class"] || ipc.initialClass || "").trim().toLowerCase()
}
function kind(client) {
  var id = identity(client)
  if (id === "chatgpt") return "chatgpt"
  if (id === "org.omarchy.codex") return "codex"
  return ""
}
