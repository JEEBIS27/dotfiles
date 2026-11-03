-- Restore the shell-owned orientation after local monitor rules on every reload.
-- The file contains monitor/touch metadata only; no captured screen image.
local state = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
local restore = loadfile(state .. "/jeebis-shell/display-rotation.lua")
if restore then restore() end
