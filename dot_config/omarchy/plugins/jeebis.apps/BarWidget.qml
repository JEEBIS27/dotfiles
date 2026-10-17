import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "../jeebis.bar/AgentModel.js" as AgentModel

BarWidget {
  id: root
  moduleName: "jeebis.apps"

  readonly property real iconSpacing: Style.space(5)
  readonly property var appItems: collectOpenApps()
  property var displayedApps: []
  onAppItemsChanged: Qt.callLater(root.syncApplications)

  property var focusOrder: ({})
  property int focusSerial: 0

  function clientIdentity(client) {
    var ipc = client.lastIpcObject || ({})
    return String((client.wayland && client.wayland.appId) || ipc["class"] || ipc.initialClass || "").trim()
  }

  function addressKey(address) {
    return String(address || "").toLowerCase().replace(/^0x/, "")
  }

  function focusApp(identity) {
    var workspace = Hyprland.focusedWorkspace
    if (!workspace || !workspace.toplevels) return
    var clients = workspace.toplevels.values || []
    var selected = null
    var bestRank = -Infinity
    for (var i = 0; i < clients.length; i++) {
      var client = clients[i]
      if (!client || clientIdentity(client).toLowerCase() !== String(identity).toLowerCase()) continue
      var ipc = client.lastIpcObject || ({})
      var remembered = focusOrder[addressKey(client.address)]
      var history = Number(ipc.focusHistoryID)
      var rank = remembered !== undefined ? remembered : -(isFinite(history) && history >= 0 ? history : 1000000)
      if (!selected || rank > bestRank) { selected = client; bestRank = rank }
    }
    if (!selected) return
    if (selected.wayland) {
      selected.wayland.activate()
    } else {
      var address = addressKey(selected.address)
      if (!/^[0-9a-f]+$/.test(address)) return
      Hyprland.dispatch(Hyprland.usingLua
        ? "hl.dsp.focus({ window = 'address:0x" + address + "' })"
        : "focuswindow address:0x" + address)
    }
  }

  property bool trackingReady: false
  property bool revealActive: false
  property bool hoverHeld: false
  property bool hoverExitGrace: false
  property int revealSerial: 0

  function setHoverHeld(held) {
    if (hoverHeld === held) return
    hoverHeld = held
    hideTimer.stop()
    revealActive = false
    if (held) {
      hoverExitTimer.stop()
      hoverExitGrace = false
    } else {
      hoverExitGrace = true
      hoverExitTimer.restart()
    }
  }

  Timer {
    id: hoverExitTimer
    interval: 150
    onTriggered: root.hoverExitGrace = false
  }

  // Track windows, not unique app icons: another window of the same app also
  // restarts the timer. Titles and focus changes inside a workspace do not.
  readonly property string windowSignature: {
    var workspace = Hyprland.focusedWorkspace
    if (!workspace || !workspace.toplevels) return ""
    var clients = workspace.toplevels.values || []
    var addresses = []
    for (var i = 0; i < clients.length; i++) addresses.push(String(clients[i].address))
    addresses.sort()
    return String(workspace.id) + ":" + addresses.join(",")
  }

  function reveal(durationMs) {
    root.revealSerial++
    if (root.hoverHeld || root.hoverExitGrace) return
    root.revealActive = true
    hideTimer.interval = durationMs === undefined ? 2000 : Math.max(1, Number(durationMs))
    hideTimer.restart()
  }

  onWindowSignatureChanged: {
    if (root.trackingReady) root.reveal()
    Qt.callLater(root.syncApplications)
  }
  Component.onCompleted: root.syncApplications()

  Timer {
    id: hideTimer
    interval: 2000
    onTriggered: root.revealActive = false
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event && event.name === "activewindowv2") {
        var address = root.addressKey(event.data)
        if (address) {
          var order = Object.assign({}, root.focusOrder)
          order[address] = ++root.focusSerial
          root.focusOrder = order
        }
      }
      if (event && event.name === "closewindow") {
        root.rememberClose(event.data)
        var order = Object.assign({}, root.focusOrder)
        delete order[root.addressKey(event.data)]
        root.focusOrder = order
      }
      // Workspace commands emit this even when the target is already focused.
      if (event && event.name === "custom" && String(event.data) === "jeebis.apps.reveal")
        root.reveal()
    }
  }

  // Stable ListModel entries keep each arrival's own one-second timer alive.
  ListModel { id: arrivals }
  property int arrivalRevision: 0
  property int arrivalGeometryRevision: 0
  property var knownApplications: ({})
  property var awaitingApplications: ({})
  property int trackedWorkspaceId: 0
  readonly property var globalWindows: {
    var clients = Hyprland.toplevels.values
    var windows = []
    for (var i = 0; i < clients.length; i++) {
      var client = clients[i]
      if (!client || AgentModel.kind(client)) continue
      windows.push({ address: root.addressKey(client.address), key: root.clientIdentity(client).toLowerCase(),
        workspaceId: client.workspace ? client.workspace.id : 0 })
    }
    return windows
  }
  onGlobalWindowsChanged: Qt.callLater(root.syncApplications)

  ListModel { id: departures }
  property int departureRevision: 0
  property int departureGeometryRevision: 0
  property var windowArchive: ({})
  property var appMetadataCache: ({})
  property var closedCandidates: []

  function departureIndex(key) {
    var revision = departureRevision
    for (var i = 0; i < departures.count; i++) if (departures.get(i).appKey === key) return i
    return -1
  }
  function rememberClose(address) {
    var record = windowArchive[root.addressKey(address)]
    if (!record || record.workspaceId !== currentWorkspaceId) return
    var metadata = appMetadataCache[record.key]
    if (!metadata) return
    var candidates = closedCandidates.slice()
    candidates.push({ address: root.addressKey(address), appKey: record.key, identity: metadata.identity, appName: metadata.name, icon: metadata.icon })
    closedCandidates = candidates
    Qt.callLater(root.syncApplications)
  }
  function syncDepartures(liveKeys, applications) {
    for (var i = departures.count - 1; i >= 0; i--) {
      if (liveKeys[departures.get(i).appKey]) { departures.remove(i); departureRevision++ }
    }
    var candidates = closedCandidates
    var deferred = []
    var liveAddresses = ({})
    for (var w = 0; w < globalWindows.length; w++) liveAddresses[globalWindows[w].address] = true
    closedCandidates = []
    for (var j = 0; j < candidates.length; j++) {
      var candidate = candidates[j]
      var key = candidate.appKey
      // Wait for both compositor models to reflect the close event.
      if (liveAddresses[candidate.address]) { deferred.push(candidate); continue }
      // One application icon represents all its windows on this workspace.
      if (applications[String(currentWorkspaceId) + ":" + key] || departureIndex(key) >= 0) continue
      if (liveKeys[key]) { deferred.push(candidate); continue }
      var pendingIndex = arrivalIndex(key)
      var pendingItem = pendingIndex >= 0 ? arrivalRepeater.itemAt(pendingIndex) : null
      departures.append({ appKey: key, identity: candidate.identity, appName: candidate.appName, icon: candidate.icon,
        phase: pendingIndex >= 0 ? 1 : 0, skipSplit: pendingIndex >= 0,
        initialX: pendingItem ? pendingItem.x : 0, initialOpacity: pendingItem ? pendingItem.entryProgress : 1 })
      departureRevision++
      root.reveal()
    }
    closedCandidates = deferred
  }
  function beginDeparture(key) {
    var index = departureIndex(key)
    if (index < 0) return
    departures.setProperty(index, "phase", 1)
    departureRevision++
    updateDisplayedApps()
  }
  function finishDeparture(key) {
    var index = departureIndex(key)
    if (index < 0) return
    departures.remove(index)
    departureRevision++
    updateDisplayedApps()
    root.reveal(1000)
  }
  readonly property real departureExtent: {
    var revision = departureGeometryRevision
    var count = departureRepeater.count
    var extent = 0
    for (var i = 0; i < count; i++) {
      var item = departureRepeater.itemAt(i)
      if (item && item.phase > 0) extent = Math.max(extent, item.x + item.width)
    }
    return extent
  }

  function arrivalIndex(key) {
    var revision = arrivalRevision
    for (var i = 0; i < arrivals.count; i++) if (arrivals.get(i).appKey === key) return i
    return -1
  }
  function isPending(identity) { return arrivalIndex(String(identity).toLowerCase()) >= 0 }
  function updateDisplayedApps() {
    var eligible = []
    for (var i = 0; i < appItems.length; i++) {
      var app = appItems[i]
      var index = arrivalIndex(app.identity.toLowerCase())
      if (index < 0 || arrivals.get(index).phase === 1) eligible.push(app)
    }
    // Retain a closed app in the row until its split animation starts.
    for (var d = 0; d < departures.count; d++) {
      var departing = departures.get(d)
      if (departing.phase === 0) eligible.push({ identity: departing.identity, name: departing.appName, icon: departing.icon })
    }
    var ordered = []
    var added = ({})
    for (var j = 0; j < displayedApps.length; j++) {
      var key = displayedApps[j].identity.toLowerCase()
      for (var k = 0; k < eligible.length; k++) {
        if (eligible[k].identity.toLowerCase() === key) {
          ordered.push(eligible[k]); added[key] = true; break
        }
      }
    }
    for (var n = 0; n < eligible.length; n++) {
      var key = eligible[n].identity.toLowerCase()
      if (!added[key]) ordered.push(eligible[n])
    }
    // Preserve old icons through the normal final exit animation.
    if (ordered.length > 0 || arrivals.count > 0 || departures.count > 0 || trackedWorkspaceId !== currentWorkspaceId)
      displayedApps = ordered
  }
  readonly property int currentWorkspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
  function syncApplications() {
    var snapshot = globalWindows
    var nextApplications = ({})
    var archive = Object.assign({}, windowArchive)
    var newKeys = trackedWorkspaceId === currentWorkspaceId ? Object.assign({}, awaitingApplications) : ({})
    for (var i = 0; i < snapshot.length; i++) {
      var window = snapshot[i]
      if (!window.key) continue
      archive[window.address] = { address: window.address, key: window.key,
        workspaceId: window.workspaceId, seenAt: Date.now() }
      // Presence is scoped to each workspace. Another workspace's copy does
      // not suppress the arrival of this workspace's first window of the app.
      var scopedKey = String(window.workspaceId) + ":" + window.key
      nextApplications[scopedKey] = true
      if (trackingReady && !knownApplications[scopedKey] && window.workspaceId === currentWorkspaceId)
        newKeys[window.key] = Date.now()
    }
    if (trackedWorkspaceId !== currentWorkspaceId) {
      arrivals.clear()
      arrivalRevision++
      departures.clear()
      departureRevision++
      closedCandidates = []
      displayedApps = []
    }
    var liveKeys = ({})
    for (var j = 0; j < appItems.length; j++) liveKeys[appItems[j].identity.toLowerCase()] = true
    root.syncDepartures(liveKeys, nextApplications)
    for (var k = arrivals.count - 1; k >= 0; k--) {
      if (!liveKeys[arrivals.get(k).appKey]) { arrivals.remove(k); arrivalRevision++ }
    }
    for (var n = 0; n < appItems.length; n++) {
      var app = appItems[n]
      var key = app.identity.toLowerCase()
      if (newKeys[key] && Date.now() - newKeys[key] < 2000 && arrivalIndex(key) < 0) {
        arrivals.append({ appKey: key, identity: app.identity, appName: app.name, icon: app.icon, phase: 0 })
        arrivalRevision++
        delete newKeys[key]
      }
    }
    for (var pendingKey in newKeys)
      if (!nextApplications[String(currentWorkspaceId) + ":" + pendingKey] || Date.now() - newKeys[pendingKey] >= 2000) delete newKeys[pendingKey]
    awaitingApplications = newKeys
    for (var archivedAddress in archive)
      if (Date.now() - Number(archive[archivedAddress].seenAt || 0) > 3000) delete archive[archivedAddress]
    windowArchive = archive
    var metadata = Object.assign({}, appMetadataCache)
    for (var m = 0; m < appItems.length; m++) metadata[appItems[m].identity.toLowerCase()] = appItems[m]
    appMetadataCache = metadata
    knownApplications = nextApplications
    updateDisplayedApps()
    trackedWorkspaceId = currentWorkspaceId
    trackingReady = true
  }
  function beginMerge(key) {
    var index = arrivalIndex(key)
    if (index < 0) return
    arrivals.setProperty(index, "phase", 1)
    arrivalRevision++
    updateDisplayedApps()
  }
  function finishMerge(key) {
    var index = arrivalIndex(key)
    if (index < 0) return
    arrivals.remove(index)
    arrivalRevision++
    updateDisplayedApps()
    root.reveal(1000)
  }
  function targetX(key) {
    for (var i = 0; i < displayedApps.length; i++)
      if (displayedApps[i].identity.toLowerCase() === key) return i * (Style.bar.iconSlot + iconSpacing)
    return mainIslandWidth
  }

  readonly property int mainAppCount: {
    var revision = arrivalRevision
    var count = 0
    for (var i = 0; i < appItems.length; i++) {
      var index = arrivalIndex(appItems[i].identity.toLowerCase())
      if (index < 0 || arrivals.get(index).phase === 1) count++
    }
    for (var d = 0; d < departures.count; d++) if (departures.get(d).phase === 0) count++
    return count
  }
  readonly property bool islandRequested: !vertical
    && (revealActive || hoverHeld || hoverExitGrace || arrivals.count > 0 || departures.count > 0) && mainAppCount > 0
  property real islandRevealProgress: islandRequested ? 1 : 0
  property real contentWidth: displayedApps.length * Style.bar.iconSlot
    + Math.max(0, displayedApps.length - 1) * iconSpacing
  readonly property real mainIslandWidth: contentWidth * islandRevealProgress
  readonly property real arrivalExtent: {
    var revision = arrivalGeometryRevision
    var count = arrivalRepeater.count
    var extent = 0
    for (var i = 0; i < count; i++) {
      var item = arrivalRepeater.itemAt(i)
      if (item) extent = Math.max(extent, item.x + item.width)
    }
    return extent
  }
  // The invisible hit target retains the final icon-row width while hidden.
  readonly property real hoverTargetWidth: appItems.length > 0 || departures.count > 0
    ? Math.max(appItems.length * Style.bar.iconSlot + Math.max(0, appItems.length - 1) * iconSpacing,
        arrivalExtent, departureExtent, mainIslandWidth) : 0

  visible: islandRevealProgress > 0 || arrivals.count > 0 || departures.count > 0
  clip: false
  implicitWidth: Math.max(mainIslandWidth, arrivalExtent, departureExtent)
  implicitHeight: visible ? barSize : 0

  Behavior on islandRevealProgress {
    NumberAnimation { duration: 240; easing.type: Easing.InOutCubic }
  }
  Behavior on contentWidth {
    NumberAnimation { duration: arrivals.count > 0 || departures.count > 0 ? 320 : 180; easing.type: Easing.InOutCubic }
  }

  function desktopEntryForClient(identity, title) {
    var entries = DesktopEntries.applications.values || []
    var cleanTitle = String(title || "").trim().toLowerCase()

    // Chromium WebApps often report the browser's app id as their identity,
    // while their generated desktop entry is named after the WebApp.
    if (cleanTitle) {
      for (var i = 0; i < entries.length; i++) {
        var candidate = entries[i]
        var name = String((candidate && candidate.name) || "").trim().toLowerCase()
        if (name && (cleanTitle === name || cleanTitle.indexOf(name + " - ") === 0 || cleanTitle.indexOf(name + " — ") === 0))
          return candidate
      }
    }

    var entry = DesktopEntries.byId(identity)
    if (!entry) entry = DesktopEntries.heuristicLookup(identity)
    if (!entry && cleanTitle) entry = DesktopEntries.heuristicLookup(title)
    return entry
  }

  function collectOpenApps() {
    var workspace = Hyprland.focusedWorkspace
    if (!workspace || !workspace.toplevels) return []

    var clients = workspace.toplevels.values || []
    var seen = ({})
    var result = []

    for (var i = 0; i < clients.length; i++) {
      var client = clients[i]
      if (!client) continue

      var identity = root.clientIdentity(client)
      if (!identity) continue

      var key = identity.toLowerCase()
      // Dedicated Agent apps are represented by the separate Agent capsule.
      if (AgentModel.kind(client) !== "") continue
      if (seen[key]) continue
      seen[key] = true

      var entry = root.desktopEntryForClient(identity, client.title)
      var icon = entry && entry.icon ? String(entry.icon) : identity
      var name = entry && entry.name ? String(entry.name) : String(client.title || identity)

      result.push({
        identity: identity,
        name: name,
        icon: icon
      })
    }

    return result
  }

  function iconSource(icon) {
    return Quickshell.iconPath(String(icon || "application-x-executable"), true)
  }

  Row {
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    spacing: root.iconSpacing
    opacity: root.islandRevealProgress
    scale: 0.9 + 0.1 * root.islandRevealProgress
    transformOrigin: Item.Left
    Repeater {
      model: root.displayedApps
      WidgetButton {
        required property var modelData
        readonly property bool pending: root.isPending(modelData.identity)
        bar: root.bar
        text: ""
        labelVisible: false
        hasVisualContent: true
        interactive: !pending && root.departureIndex(modelData.identity.toLowerCase()) < 0
        tooltipText: modelData.name
        onPressed: function(button) {
          if (button === Qt.LeftButton) root.focusApp(modelData.identity)
        }
        fixedWidth: Style.bar.iconSlot
        fixedHeight: root.barSize
        horizontalMargin: 0
        verticalPadding: 0
        Image {
          anchors.centerIn: parent
          width: Style.bar.iconCanvas
          height: Style.bar.iconCanvas
          source: root.iconSource(modelData.icon)
          visible: !parent.pending
          fillMode: Image.PreserveAspectFit
          smooth: true
          mipmap: true
        }
      }
    }
  }

  Repeater {
    id: arrivalRepeater
    model: arrivals
    onItemAdded: root.arrivalGeometryRevision++
    onItemRemoved: root.arrivalGeometryRevision++
    delegate: Item {
      id: arrival
      required property int index
      required property string appKey
      required property string identity
      required property string appName
      required property string icon
      required property int phase
      property real mergeProgress: 0
      property real entryProgress: 0
      property real mergeStartX: 0
      readonly property real restingX: (root.mainIslandWidth > 0 ? root.mainIslandWidth + Style.space(16) : 0)
        + index * (Style.bar.iconSlot + Style.space(16))
      x: phase === 1 ? mergeStartX + (root.targetX(appKey) - mergeStartX) * mergeProgress : restingX
      width: Style.bar.iconSlot
      height: root.barSize
      anchors.verticalCenter: parent.verticalCenter
      opacity: entryProgress
      z: 5
      Component.onCompleted: { entryAnimation.start(); dwell.start() }
      NumberAnimation { id: entryAnimation; target: arrival; property: "entryProgress"; to: 1; duration: 180; easing.type: Easing.OutCubic }
      Timer {
        id: dwell
        interval: 1000
        onTriggered: {
          arrival.mergeStartX = arrival.x
          root.beginMerge(arrival.appKey)
          mergeAnimation.start()
        }
      }
      NumberAnimation {
        id: mergeAnimation
        target: arrival
        property: "mergeProgress"
        to: 1
        duration: 320
        easing.type: Easing.InOutCubic
        onFinished: root.finishMerge(arrival.appKey)
      }
      Rectangle {
        x: -Style.space(8)
        width: parent.width + Style.space(16)
        anchors.verticalCenter: parent.verticalCenter
        height: root.barSize * (0.84 + 0.16 * arrival.entryProgress)
        radius: height / 2
        color: root.bar ? Qt.rgba(root.bar.background.r, root.bar.background.g, root.bar.background.b, 0.94) : Color.background
        border.width: 1
        border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
        opacity: 1 - arrival.mergeProgress
      }
      WidgetButton {
        anchors.fill: parent
        bar: root.bar
        text: ""
        labelVisible: false
        hasVisualContent: true
        tooltipText: arrival.appName
        fixedWidth: Style.bar.iconSlot
        fixedHeight: root.barSize
        horizontalMargin: 0
        verticalPadding: 0
        onPressed: function(button) {
          if (button === Qt.LeftButton) root.focusApp(arrival.identity)
        }
        Image {
          anchors.centerIn: parent
          width: Style.bar.iconCanvas
          height: Style.bar.iconCanvas
          source: root.iconSource(arrival.icon)
          fillMode: Image.PreserveAspectFit
          smooth: true
          mipmap: true
        }
      }
    }
  }
  Repeater {
    id: departureRepeater
    model: departures
    onItemAdded: root.departureGeometryRevision++
    onItemRemoved: root.departureGeometryRevision++
    delegate: Item {
      id: departure
      required property int index
      required property string appKey
      required property string appName
      required property string icon
      required property int phase
      required property bool skipSplit
      required property real initialX
      required property real initialOpacity
      property real splitProgress: 0
      property real lifeOpacity: initialOpacity
      property real startX: initialX
      property real endX: initialX
      x: skipSplit ? initialX : startX + (endX - startX) * splitProgress
      width: Style.bar.iconSlot
      height: root.barSize
      anchors.verticalCenter: parent.verticalCenter
      visible: phase > 0
      opacity: lifeOpacity
      scale: 0.86 + 0.14 * lifeOpacity
      z: 6
      Component.onCompleted: {
        if (skipSplit) fadeOut.start()
        else showBeforeSplit.start()
      }
      Timer {
        id: showBeforeSplit
        interval: 400
        onTriggered: {
          departure.startX = root.targetX(departure.appKey)
          root.beginDeparture(departure.appKey)
          var remainingWidth = root.displayedApps.length * Style.bar.iconSlot
            + Math.max(0, root.displayedApps.length - 1) * root.iconSpacing
          departure.endX = Math.max(remainingWidth, root.arrivalExtent) + Style.space(16)
            + departure.index * (Style.bar.iconSlot + Style.space(16))
          splitAnimation.start()
        }
      }
      NumberAnimation {
        id: splitAnimation
        target: departure
        property: "splitProgress"
        to: 1
        duration: 320
        easing.type: Easing.InOutCubic
        onFinished: fadeOut.start()
      }
      NumberAnimation {
        id: fadeOut
        target: departure
        property: "lifeOpacity"
        to: 0
        duration: 240
        easing.type: Easing.InCubic
        onFinished: {
          var key = departure.appKey
          Qt.callLater(root.finishDeparture, key)
        }
      }
      Rectangle {
        x: -Style.space(8)
        width: parent.width + Style.space(16)
        anchors.verticalCenter: parent.verticalCenter
        height: root.barSize
        radius: height / 2
        color: root.bar ? Qt.rgba(root.bar.background.r, root.bar.background.g, root.bar.background.b, 0.94) : Color.background
        border.width: 1
        border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.22)
        opacity: departure.skipSplit ? 1 : departure.splitProgress
      }
      Image {
        anchors.centerIn: parent
        width: Style.bar.iconCanvas
        height: Style.bar.iconCanvas
        source: root.iconSource(departure.icon)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
      }
    }
  }

}
