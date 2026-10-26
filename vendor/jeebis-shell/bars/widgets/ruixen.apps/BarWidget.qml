import "../../../ShellConfig.js" as ShellConfig
import QtQuick
import Quickshell.Hyprland
import qs.Commons
import qs.Ui as Ui
import "WindowOrder.js" as WindowOrder

Ui.BarWidget {
  id: root
  moduleName: "ruixen.apps"
  property bool detachedEntry: false
  property bool hoverHeld: false
  property bool groupsReady: false
  property bool syncingTransfers: false
  property var layerArchive: ({})
  property var transfers: ({})
  property int transferRevision: 0
  property int transferWorkspace: 0
  property int transferSerial: 0
  readonly property bool transferActive: transferVisuals.count > 0
  ListModel { id: transferVisuals }
  readonly property int workspaceId: WindowOrder.logicalWorkspaceId(Hyprland.focusedWorkspace)
  readonly property real padding: ShellConfig.islandPadding
  readonly property bool hasApplications: tiledSurface.group.appItems.length > 0 || floatingSurface.group.appItems.length > 0
  readonly property real islandRevealProgress: Math.max(tiledSurface.group.presentationProgress, floatingSurface.group.presentationProgress)
  readonly property real centeringWidth: implicitWidth
  readonly property bool centerRepositioning: tiledSurface.group.recentering || floatingSurface.group.recentering
  readonly property bool entryExiting: !tiledSurface.group.presentationRequested && !floatingSurface.group.presentationRequested
  readonly property real mainIslandWidth: 0
  readonly property real mainIslandOffsetX: 0
  readonly property int revealSerial: tiledSurface.group.revealSerial + floatingSurface.group.revealSerial
  readonly property real hoverTargetWidth: implicitWidth
  implicitWidth: tiledSurface.width + floatingSurface.width + (tiledSurface.width > 0 && floatingSurface.width > 0 ? ShellConfig.islandGap : 0)
  implicitHeight: ShellConfig.islandHeight
  visible: implicitWidth > 0

  function group(floating) { return floating ? floatingSurface.group : tiledSurface.group }
  function setHoverHeld(held) { hoverHeld = held; group(false).setHoverHeld(held); group(true).setHoverHeld(held) }
  function reveal(durationMs) { group(false).reveal(durationMs); group(true).reveal(durationMs) }
  // One proxy owns the moving icon for the entire journey. Neither the normal
  // close animation nor the normal new-app animation participates in a move.
  function transferIndex(key) {
    for (var i = 0; i < transferVisuals.count; i++)
      if (transferVisuals.get(i).appKey === key) return i
    return -1
  }
  function iconInFlight(key, floating) {
    var revision = transferRevision
    var move = transfers[key]
    return !!move && ((move.toFloating === floating && !move.destinationUsed)
      || (move.fromFloating === floating && !move.sourceUsed))
  }
  function moving(key) {
    var revision = transferRevision
    return !!transfers[key]
  }
  function transferTargetX(key, floating) {
    var destination = group(floating)
    return destination.parent.x + destination.x + destination.renderedIconX(key)
  }
  function finishTransfer(key, serial) {
    var move = transfers[key]
    if (!move || move.serial !== serial) return
    var next = Object.assign({}, transfers)
    delete next[key]
    transfers = next
    transferRevision++
    var index = transferIndex(key)
    if (index >= 0) transferVisuals.remove(index)
  }
  function syncTransfers(snapshot) {
    if (syncingTransfers) return
    syncingTransfers = true
    var archive = ({}), next = Object.assign({}, transfers)
    var sameWorkspace = transferWorkspace === workspaceId
    if (!sameWorkspace) { next = ({}); transferVisuals.clear() }
    // Closed windows and workspace changes cancel their proxy, never relaunch it.
    for (var key in next) {
      var move = next[key]
      if (!snapshot.some(function(w) { return w.address === move.address && w.key === key && w.workspaceId === root.workspaceId })) {
        var removed = transferIndex(key)
        if (removed >= 0) transferVisuals.remove(removed)
        delete next[key]
      }
    }
    for (var i = 0; i < snapshot.length; ++i) {
      var current = snapshot[i]
      archive[current.address] = current
      var previous = layerArchive[current.address]
      if (!groupsReady || !sameWorkspace || !previous || previous.floating === current.floating
          || previous.workspaceId !== workspaceId || current.workspaceId !== workspaceId) continue
      var key = current.key
      var source = group(previous.floating)
      var destinationUsed = snapshot.some(function(w) {
        var old = root.layerArchive[w.address]
        return w.address !== current.address && w.key === key && w.workspaceId === root.workspaceId
          && old && old.floating === current.floating
      })
      var sourceUsed = snapshot.some(function(w) {
        return w.address !== current.address && w.key === key && w.workspaceId === root.workspaceId && w.floating === previous.floating
      })
      var index = transferIndex(key)
      var proxy = index >= 0 ? transferRepeater.itemAt(index) : null
      var startX = proxy ? proxy.x : source.mapToItem(root, source.renderedIconX(key), 0).x
      var app = source.appMetadataCache[key] || group(current.floating).appMetadataCache[key]
      if (!app) continue
      group(false).cancelLayerTransfer(key)
      group(true).cancelLayerTransfer(key)
      if (sourceUsed && destinationUsed) {
        if (index >= 0) transferVisuals.remove(index)
        delete next[key]
        continue
      }
      var serial = ++transferSerial
      next[key] = { address: current.address, fromFloating: previous.floating, toFloating: current.floating,
        sourceUsed: sourceUsed, destinationUsed: destinationUsed, serial: serial }
      var record = { appKey: key, appIcon: app.icon, startX: startX, toFloating: current.floating, serial: serial }
      if (index >= 0) transferVisuals.set(index, record)
      else transferVisuals.append(record)
      source.reveal(ShellConfig.appTransfer.settledMs)
      group(current.floating).reveal(ShellConfig.appTransfer.settledMs)
    }
    layerArchive = archive
    transferWorkspace = workspaceId
    if (JSON.stringify(transfers) !== JSON.stringify(next)) { transfers = next; transferRevision++ }
    syncingTransfers = false
  }
  Component.onCompleted: groupsReady = true
  Timer {
    interval: ShellConfig.appOrderPollMs
    repeat: true; running: root.groupsReady && Hyprland.toplevels.values.length > 0
    onTriggered: Hyprland.refreshToplevels()
  }
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event && (event.name === "changefloatingmode" || event.name === "movewindowv2")) Hyprland.refreshToplevels()
    }
  }
  GroupSurface { id: tiledSurface; floatingLayer: false; x: 0 }
  GroupSurface {
    id: floatingSurface
    floatingLayer: true
    x: tiledSurface.width + (tiledSurface.width > 0 && width > 0 ? ShellConfig.islandGap : 0)
  }
  Repeater {
    id: transferRepeater
    model: transferVisuals
    JeebisLayerTransfer {
      coordinator: root
      barRoot: root.bar
    }
  }
  component GroupSurface: Item {
    id: surface
    required property bool floatingLayer
    property alias group: member
    width: member.implicitWidth > 0 ? member.implicitWidth + root.padding * 2 : 0
    height: ShellConfig.islandHeight
    // Do not gate visibility by measured width: hidden children measure zero.
    AppCapsule {
      barRoot: root.bar
      enabled: false
      visible: member.mainIslandWidth > 0
      opacity: member.islandRevealProgress
      x: root.padding + member.mainIslandOffsetX - root.padding * member.islandRevealProgress
      y: (parent.height - height) / 2
      width: member.mainIslandWidth + 2 * root.padding * member.islandRevealProgress
      height: ShellConfig.islandHeight * (0.84 + 0.16 * member.islandRevealProgress)
    }
    AppGroup {
      id: member
      x: root.padding
      coordinator: root
      floatingGroup: surface.floatingLayer
      detachedEntry: root.detachedEntry
      bar: root.bar; settings: root.settings
      width: implicitWidth; height: ShellConfig.islandHeight
    }
  }
}
