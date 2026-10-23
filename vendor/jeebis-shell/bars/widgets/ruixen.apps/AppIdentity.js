// Shared application identity, including terminal sub-app labels.
// No applications are excluded or assigned a special Agent role.
function identity(client) {
  if (!client) return ""
  var ipc = client.lastIpcObject || ({})
  return String((client.wayland && client.wayland.appId) || ipc["class"] || ipc.initialClass || "").trim().toLowerCase()
}
function terminalApplication(client) {
  var id = identity(client)
  if (id !== "org.wezfurlong.wezterm" && id !== "wezterm" && id !== "org.omarchy.codex") return ""
  var match = /^(Neovim|Yazi|Codex) · WezTerm(?: — |$)/.exec(String(client.title || ""))
  var names = { Neovim: "nvim", Yazi: "yazi", Codex: "codex" }
  return match ? names[match[1]] : ""
}
function applicationIdentity(client) {
  var app = terminalApplication(client)
  if (app) return "wezterm:" + app
  var ipc = client.lastIpcObject || ({})
  return String((client.wayland && client.wayland.appId) || ipc["class"] || ipc.initialClass || "").trim()
}
