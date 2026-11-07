hl.curve("jeebisLinear", { type = "bezier", points = { {0, 0}, {1, 1} } })
hl.curve("jeebisSmooth", { type = "bezier", points = { {0.3642, 0}, {0.6358, 1} } })
return { curve = "jeebisSmooth", bounded = "jeebisSmooth", preset = "InOutSine", speed = 1.2, floatOverlapDelayMs = 100, floatOverlapThresholdPercent = 90 }
