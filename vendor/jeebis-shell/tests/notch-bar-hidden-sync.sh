#!/usr/bin/env bash
# Jeebis: presentation is owned by the bar and published atomically to the notch.
set -Eeuo pipefail
repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$repo_dir" <<'CHECK'
from pathlib import Path
import sys
r=Path(sys.argv[1]);b=r/'bars/v2/ruixen.bar';n=r/'bars/widgets/ruixen.notch'
control=(b/'JeebisBarVisibility.qml').read_text();overlay=(n/'Overlay.qml').read_text();window=(n/'NotchWindow.qml').read_text();panel=(b/'BarPanel.qml').read_text()
assert '/bar-visibility.json' in control and '/bar-visibility.json' in overlay
assert 'atomicWrites: true' in control
assert 'mode.target === "bar"' in control
assert 'leftShown' in control and 'rightShown' in control
assert 'root.barShown = state.notchShown === true' in overlay
assert 'barRevealProgress > 0' in window and 'barRevealProgress > 0' in panel
assert 'Translate {' in window and 'transform: JeebisIslandTranslate' in panel
assert 'JeebisNotchRevealScale {' in window
assert 'root.barIslandsMode = state.target' in overlay
assert 'blocking: false' in window and 'z: 10000' in window
assert 'ExclusionMode.Ignore' in panel
assert 'barRoot.barReservesSpace' in (b/'JeebisBarReservation.qml').read_text()
edge=(b/'JeebisBarRevealEdge.qml').read_text()
assert 'barRoot.barAutoHide' in edge
assert 'implicitHeight: 1' in edge
assert 'notchClearance' not in edge
assert 'height: edge.height' in edge
assert 'width: !barWindow.barRoot.islandsMode && barWindow.barRoot.barRevealProgress > 0 ? barWindow.width : 0' in panel
print('Visibility sync: one authority, shared state, slide-out lifetime and independent reservation passed.')
CHECK
