# Workspace island

Only actual positive-ID Hyprland workspaces are shown. One workspace hides the island; two or more reveal it, so the minimum visible dot count is two. Scratchpads do not count.

The last dots are retained through the 240 ms exit animation. Width changes between visible workspace counts animate for 220 ms. The host bar reads `islandRevealProgress` to animate the capsule background and padding on the same timeline.

CPU and launch spinners still belong to the workspace performing the work. Clicking a dot continues to reveal the app island, including a repeated selection of the current workspace.
