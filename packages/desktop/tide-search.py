"""Add Niri window and shortcut results to the Tide launcher."""
from pathlib import Path
import sys


root = Path(sys.argv[1])


def edit(relative, replacements):
    path = root / relative
    source = path.read_text()
    for before, after in replacements:
        if source.count(before) != 1:
            raise RuntimeError(f"upstream {relative} changed: {before!r}")
        source = source.replace(before, after)
    path.write_text(source)


edit("shell.qml", [
    ('''        function toggleApplicationLauncher() {''', '''        function toggleSearch(mode: string, payload: string) {
            if (mode !== "keys" && mode !== "windows")
                return;
            const decoded = JSON.parse(payload);
            const entries = typeof decoded === "string" ? JSON.parse(decoded) : decoded;
            if (!Array.isArray(entries))
                return;
            shellRoot.forFocusedWindow(window => window.toggleLauncherSearch(mode, entries));
        }

        function toggleApplicationLauncher() {'''),
])

edit("DynamicIslandWindow.qml", [
    ('''    function toggleApplicationLauncherWindow() {
        if (islandContainer.islandState === "application_launcher")
            islandContainer.smartRestoreState();
        else
            islandContainer.showApplicationLauncher();
    }''', '''    property string launcherSearchMode: "apps"
    property var launcherSearchEntries: []

    function toggleLauncherSearch(mode, entries) {
        const open = islandContainer.islandState === "application_launcher";
        if (open && launcherSearchMode === mode) {
            islandContainer.smartRestoreState();
            return;
        }
        launcherSearchEntries = entries;
        launcherSearchMode = mode;
        if (!open)
            islandContainer.showApplicationLauncher();
        focusApplicationLauncher();
    }

    function toggleApplicationLauncherWindow() {
        toggleLauncherSearch("apps", []);
    }'''),
    ('''                        showCondition: islandContainer.applicationLauncherLayerVisible''',
     '''                        searchMode: root.launcherSearchMode
                        searchEntries: root.launcherSearchEntries
                        showCondition: islandContainer.applicationLauncherLayerVisible'''),
])

edit("qml/island/ApplicationLauncherLayer.qml", [
    ('''    property string query: ""''', '''    property string query: ""
    property string searchMode: "apps"
    property var searchEntries: []
    readonly property bool appMode: searchMode === "apps"
    onSearchModeChanged: {
        searchInput.text = "";
        rebuildApplications();
    }
    onSearchEntriesChanged: {
        if (!appMode)
            rebuildApplications();
    }'''),
    ('''        return !!entry && root.favoriteIds.indexOf''',
     '''        return root.appMode && !!entry && root.favoriteIds.indexOf'''),
    ('''        return !!entry && root.sortFavoriteIds.indexOf''',
     '''        return root.appMode && !!entry && root.sortFavoriteIds.indexOf'''),
    ('''    function toggleFavorite(entry) {
        if (!entry''', '''    function toggleFavorite(entry) {
        if (!root.appMode || !entry'''),
    ('''        const available = DesktopEntries.applications.values;''',
     '''        const available = root.appMode ? DesktopEntries.applications.values : root.searchEntries;'''),
    ('''        const desktopCommand = [];''', '''        if (!root.appMode) {
            if (root.searchMode === "windows" && /^[0-9]+$/.test(entry.id)) {
                root.closeRequested();
                Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", entry.id]);
            }
            return;
        }

        const desktopCommand = [];'''),
    ('''                TextInput {
                    id: searchInput''', '''                Text {
                    anchors.left: searchInput.left
                    anchors.verticalCenter: searchInput.verticalCenter
                    visible: !root.appMode && searchInput.text === ""
                    text: root.searchMode === "keys" ? "キーバインド検索" : "ウィンドウ検索"
                    color: "#a5a6ac"
                    font.family: root.textFontFamily
                    font.pixelSize: 15
                }

                TextInput {
                    id: searchInput'''),
    ('''            cellWidth: 126''', '''            cellWidth: root.appMode ? 126 : 215'''),
    ('''                            source: Quickshell.iconPath(appDelegate.entry.icon, true)''',
     '''                            source: appDelegate.entry.icon ? Quickshell.iconPath(appDelegate.entry.icon, true) : ""'''),
    ('''                        text: appDelegate.entry.name
                        color:''', '''                        text: appDelegate.entry.name || ""
                        textFormat: Text.PlainText
                        color:'''),
    ('''                    FavoriteStar {
                        anchors.top: iconArea.top''', '''                    Text {
                        anchors.top: iconArea.bottom
                        anchors.topMargin: 28
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 8
                        visible: !root.appMode
                        text: appDelegate.entry.comment || ""
                        textFormat: Text.PlainText
                        color: "#a5a6ac"
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        font.family: root.textFontFamily
                        font.pixelSize: 11
                    }

                    FavoriteStar {
                        visible: root.appMode
                        anchors.top: iconArea.top'''),
    ('''                text: root.query === "" ? "没有找到可启动的应用" : "没有找到“" + root.query + "”"''',
     '''                text: root.appMode
                    ? (root.query === "" ? "没有找到可启动的应用" : "没有找到“" + root.query + "”")
                    : "一致する候補がありません"'''),
])
