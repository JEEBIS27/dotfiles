// Only these controls have secondary actions. Other buttons retain their
// normal click behavior and no longer open the global theme selector.
function actionFor(moduleName) {
  if (moduleName === "jeebis.theme") return "theme-cycle"
  if (moduleName === "omarchy.agents") return "chatgpt"
  if (moduleName === "jeebis.workspaces" || moduleName === "omarchy.workspaces") return "overview"
  if (moduleName === "jeebis.clock" || moduleName === "omarchy.clock") return "calendar"
  return ""
}
