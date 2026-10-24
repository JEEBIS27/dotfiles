// Shared application identity, including terminal sub-app labels.
// No applications are excluded or assigned a special Agent role.
function identity(client) {
  if (!client) return ""
  var ipc = client.lastIpcObject || ({})
  return String((client.wayland && client.wayland.appId) || ipc["class"] || ipc.initialClass || "").trim().toLowerCase()
}
function terminalApplication(client) {
  return identity(client) === "org.omarchy.codex" ? "codex" : ""
}
function applicationIdentity(client) {
  var app = terminalApplication(client)
  if (app) return "rio:" + app
  var ipc = client.lastIpcObject || ({})
  return String((client.wayland && client.wayland.appId) || ipc["class"] || ipc.initialClass || "").trim()
}
