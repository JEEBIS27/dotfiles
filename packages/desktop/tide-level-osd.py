"""Share level glyphs between Tide's slider cards and its transient OSD."""
from pathlib import Path
import sys

root = Path(sys.argv[1])


def edit(relative, *replacements):
    path = root / relative
    source = path.read_text()
    for before, after in replacements:
        if source.count(before) != 1:
            raise RuntimeError(f"upstream {relative} changed: {before!r}")
        source = source.replace(before, after)
    path.write_text(source)


edit(
    "qml/island/IslandSystemState.qml",
    ("    signal transientRequested(string icon, real progress, string text)",
     """    signal transientRequested(string icon, real progress, string text)
    signal levelRequested(string kind, real progress)"""),
    ("""                root.transientRequested(
                    root._pendingVolType === "MUTE" ? root.statusIcon("mute") : root.statusIcon("volume"),
                    root._pendingVolVal,
                    ""
                );""",
     """                root.levelRequested(root._pendingVolType === "MUTE" ? "mute" : "volume", root._pendingVolVal);"""),
    ("""        onTriggered: root.transientRequested(
            root.brightnessStatusIcon(root._pendingBrightnessValue),
            root._pendingBrightnessValue,
            ""
        )""",
     """        onTriggered: root.levelRequested("brightness", root._pendingBrightnessValue)"""),
)

edit(
    "DynamicIslandWindow.qml",
    ('        || islandContainer.islandState === "lyrics"\n    readonly property bool autoHideCanHideNow',
     '        || islandContainer.islandState === "lyrics"\n        || islandContainer.levelOsdVisible\n    readonly property bool autoHideCanHideNow'),
    ('islandNormallyVisible || islandPeekTimer.running',
     'islandNormallyVisible || islandPeekTimer.running || islandContainer.levelOsdVisible'),
    ('        property real osdProgress: -1.0',
     '''        property real osdProgress: -1.0
        property string levelOsdKind: ""
        readonly property bool levelOsdVisible: islandState === "split" && levelOsdKind !== ""'''),
    ('splitShowsProgress ? 248 :', 'levelOsdVisible ? 300 : splitShowsProgress ? 248 :'),
    ('''            onTransientRequested: function(icon, progress, text) {''',
     '''            onLevelRequested: function(kind, progress) {
                islandContainer.showTransientCapsule("", progress, "", kind);
            }

            onTransientRequested: function(icon, progress, text) {'''),
    ('''        function showTransientCapsule(icon, progress, customText) {''',
     '''        function showTransientCapsule(icon, progress, customText, levelKind) {'''),
    ('''            if (root.autoHideSuppressesTransientReveal) return;
            if (blocksTransientSplit) return;''',
     '''            if (root.overviewVisible || blocksTransientSplit) return;
            if (!levelKind && root.autoHideSuppressesTransientReveal) return;'''),
    ('''            splitIcon = icon;
            osdCustomText = customText;''',
     '''            levelOsdKind = levelKind || "";
            splitIcon = icon;
            osdCustomText = customText;'''),
    ('''        function clearTransientCapsule() {
            setOsdProgress''',
     '''        function clearTransientCapsule() {
            levelOsdKind = "";
            setOsdProgress'''),
    ('''                        iconText: islandContainer.splitIcon
                        progress: islandContainer.osdProgress''',
     '''                        iconText: islandContainer.splitIcon
                        levelKind: islandContainer.levelOsdKind
                        progress: islandContainer.osdProgress'''),
)

edit(
    "qml/island/OsdLayer.qml",
    ("import IslandBackend", 'import IslandBackend\nimport "../common"'),
    ('    property string iconText: ""', '    property string iconText: ""\n    property string levelKind: ""'),
    ('''        visible: showProgress

        Row''',
     '''        visible: showProgress && levelKind !== ""

        LevelStatusIcon {
            id: levelIcon
            width: 19
            height: 19
            anchors.left: parent.left
            anchors.leftMargin: 19
            anchors.verticalCenter: parent.verticalCenter
            kind: root.levelKind
            value: root.progress
            ink: "#f4f5f7"
        }

        Text {
            id: levelLabel
            anchors.right: parent.right
            anchors.rightMargin: 17
            anchors.verticalCenter: parent.verticalCenter
            width: 44
            horizontalAlignment: Text.AlignRight
            text: root.levelKind === "mute" ? "ミュート" : Math.round(root.progress * 100) + "%"
            color: "#d0d0d6"
            font.family: root.textFontFamily
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        Rectangle {
            anchors.left: levelIcon.right
            anchors.right: levelLabel.left
            anchors.leftMargin: 18
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            height: 6
            radius: 3
            color: "#45ffffff"

            Rectangle {
                width: parent.width * (root.levelKind === "mute" ? 0 : Math.max(0, Math.min(1, root.progress)))
                height: parent.height
                radius: Math.min(height, width) / 2
                color: "#f1f1f4"
            }
        }
    }

    Item {
        x: contentX
        width: parent.width
        height: parent.height
        visible: showProgress && levelKind === ""

        Row'''),
)

edit(
    "qml/controlcenter/ControlCenterLayer.qml",
    ("            iconText: controlCenter.brightnessIconGlyph", '            levelKind: "brightness"'),
    ("            iconText: controlCenter.volumeIconGlyph", '            levelKind: controlCenter.volumeMuted ? "mute" : "volume"'),
)

edit(
    "qml/controlcenter/ControlSliderCard.qml",
    ("import IslandBackend", 'import IslandBackend\nimport "../common"'),
    ('    property string iconText: ""\n    property string iconFontFamily: ""', '    property string levelKind: ""'),
    ('''                Text {
                    anchors.centerIn: parent
                    text: root.iconText
                    color: root.value > 0.15 ? "#575760" : root.textSecondary
                    font.pixelSize: 13
                    font.family: root.iconFontFamily
                }''',
     '''                LevelStatusIcon {
                    anchors.fill: parent
                    kind: root.levelKind
                    value: root.value
                }'''),
    ('''            Rectangle {
                x: sliderTrack.knobX''',
     '''            Rectangle {
                x: sliderTrack.knobX - 1
                y: (parent.height - height) / 2 + 1
                width: root.knobSize + 2
                height: root.knobSize + 1
                radius: height / 2
                color: "#20000000"
            }

            Rectangle {
                x: sliderTrack.knobX'''),
    ('                border.color: "#b8ffffff"', '                border.color: "#929298"'),
)

# Only the slider cards used the old icon font wiring.
path = root / "qml/controlcenter/ControlCenterLayer.qml"
source = path.read_text()
for binding in ('levelKind: "brightness"', 'levelKind: controlCenter.volumeMuted ? "mute" : "volume"'):
    before = f"{binding}\n            iconFontFamily: controlCenter.iconFontFamily"
    if source.count(before) != 1:
        raise RuntimeError(f"upstream slider changed: {binding}")
    source = source.replace(before, binding)
path.write_text(source)
