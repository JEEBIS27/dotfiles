# Application island

Clicking an app icon focuses its most recently used window in the current
workspace. Focus order is tracked from Hyprland activewindowv2 events, with
focusHistoryID as the initial fallback. Closed windows are resolved afresh at
click time. Activation uses the native Wayland toplevel API, with a Hyprland
Lua/legacy dispatcher fallback for clients without a Wayland toplevel.

ChatGPT windows are excluded from application icons because the separate Agent
capsule represents ChatGPT. Window tracking remains intact for automatic reveals.

CLI Codex (org.omarchy.codex) is excluded alongside ChatGPT. Both are recognized
by the shared ../jeebis.bar/AgentModel.js module.

## Direct hover and new-app arrivals

The host keeps an invisible hover target covering this workspace's full icon-row
width, even when the capsule is hidden. It excludes Agent apps as before.

The application snapshot is tracked separately for every workspace. The first
window of an app appearing on the focused workspace gets an arrival even if the
app is already running elsewhere (including a window moved into this workspace).
Switching to a workspace with existing apps, additional windows of an app already
on that workspace, and initial shell startup use the normal reveal. New applications opened on the focused workspace each
get a separate capsule to the right for 1000 ms (`dwell` timer). During the next
320 ms (`mergeAnimation`) their icon slides into a reserved position in the main
capsule while the separate background fades into it. The main icon is hidden
until handoff completes, preventing duplicate icons. Independent ListModel
entries preserve each app's timer during simultaneous launches. Closing an app
or switching workspace cancels pending arrivals for that workspace. After merging, the main capsule automatically stays visible for 1000 ms; pointer
hover still holds it open. Other automatic reveals keep their usual two seconds.
Arrival content spacing uses Style.space(16), matching the other islands. The
original click-to-focus behavior also works on incoming icons.

Tuning in BarWidget.qml:
- `hoverExitTimer.interval`: pointer exit grace (preserves the user's current value).
- `dwell.interval`: separate capsule dwell time, currently 1000 ms.
- `mergeAnimation.duration`: merge duration, currently 320 ms.

The widget exports `mainIslandWidth` separately from the total arrival width so
the host draws only the committed capsule; arrivals paint their own backgrounds.

## Closed-app departures

A `closewindow` event for the current workspace queues a departure only when
that app's final window on the workspace has closed. Window moves and workspace
switches do not count as closes. Agent apps remain excluded. Cached metadata
keeps the closed icon in the main row for 400 ms (`showBeforeSplit.interval`),
letting a hidden island first reveal. The icon then detaches right over 320 ms
(`splitAnimation.duration`) into its own capsule, fading/shrinking away over
240 ms (`fadeOut.duration`). Until detachment, the closed icon is noninteractive.
Remaining apps stay visible through the animation and for one second afterward.
An app closed before its arrival has merged fades out from its incoming capsule
instead. Reopening the app or changing workspace cancels its pending departure.
Stable ListModel entries give simultaneous departures independent timelines.
