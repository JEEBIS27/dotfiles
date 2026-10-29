-- Durations and popin style retained from the 2026-10-21 personal backup.
-- Easing follows ShellConfig.js through the generated jeebis.motion module.
-- Window appearance/disappearance: popin 87%, without Ruixen slide profiles.
hl.config({ animations = { enabled = true } })

local motion = require("jeebis.motion")
hl.animation({ leaf = "global", enabled = true, speed = 10 / (motion.speed or 1), bezier = motion.bounded })
hl.animation({ leaf = "border", enabled = true, speed = 5.39 / (motion.speed or 1), bezier = motion.bounded })
hl.animation({ leaf = "windows", enabled = true, speed = 3.79 / (motion.speed or 1), bezier = motion.curve })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3.79 / (motion.speed or 1), bezier = motion.curve })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1 / (motion.speed or 1), bezier = motion.curve, style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.49 / (motion.speed or 1), bezier = motion.curve, style = "popin 87%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.73 / (motion.speed or 1), bezier = motion.bounded })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.46 / (motion.speed or 1), bezier = motion.bounded })
hl.animation({ leaf = "fade", enabled = true, speed = 3.03 / (motion.speed or 1), bezier = motion.bounded })
hl.animation({ leaf = "fadeSwitch", enabled = false })

-- Jeebis: workspace numbers represent a horizontal row, without wraparound.
-- Larger numbers enter from the right; smaller numbers enter from the left.
hl.config({ animations = { workspace_wraparound = false } })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3.6 / (motion.speed or 1), bezier = motion.curve, style = "slide" })
