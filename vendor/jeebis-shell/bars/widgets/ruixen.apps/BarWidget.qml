import "../../../ShellConfig.js" as ShellConfig
import QtQuick
import Quickshell.Hyprland
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
  function incomingBlocked(key, floating) {
    var revision = transferRevision
    var move = transfers[key]
    // Keep the destination's regular icon suppressed through split and fade.
    // splitFinished removes the transfer only after the source delegate is gone.
    return !!move && move.toFloating === floating
  }
  function isLayerTransfer(key, fromFloating) {
    var move = transfers[key]
    return !!move && move.fromFloating === fromFloating
  }
  function syncTransfers(snapshot) {
    if (syncingTransfers) return
    syncingTransfers = true
    var archive = ({}), next = Object.assign({}, transfers)
    var sameWorkspace = transferWorkspace === workspaceId
    if (!sameWorkspace) next = ({})
    for (var i = 0; i < snapshot.length; ++i) {
      var current = snapshot[i]
      archive[current.address] = current
      var previous = layerArchive[current.address]
      if (!groupsReady || !sameWorkspace || !previous || previous.floating === current.floating
          || previous.workspaceId !== workspaceId || current.workspaceId !== workspaceId) continue
      var key = current.key
      if (next[key]) {
        group(false).cancelLayerTransfer(key)
        group(true).cancelLayerTransfer(key)
        delete next[key]
      }
      // If another window still owns the source icon, retain it there and add
      // the destination icon from the neighboring edge. This is still a layer
      // transfer, not a generic new-app arrival from the far side.
      var sourceStillUsed = snapshot.some(function(w) {
        return w.address !== current.address && w.key === key && w.workspaceId === root.workspaceId && w.floating === previous.floating
      })
      var source = group(previous.floating)
      if (sourceStillUsed) {
        group(current.floating).queueTransferArrival(key, !previous.floating)
      } else if (!source.hasDisplayedKey(key)) {
        // The source row can lose the icon before the transfer snapshot is
        // processed, while its separate departure capsule is still visible.
        // Adopt that in-flight departure instead of starting a second capsule
        // immediately at the destination.
        var departurePhase = source.departurePhase(key)
        if (departurePhase >= 0) {
          next[key] = { fromFloating: previous.floating, toFloating: current.floating,
            started: departurePhase > 0 }
          source.markLayerDeparture(key, previous.floating ? -1 : 1)
        } else {
          // There is no source rendering left to hand off from. Preserve the
          // neighboring-edge direction rather than using a generic arrival.
          group(current.floating).queueTransferArrival(key, !previous.floating)
        }
      } else {
        next[key] = { fromFloating: previous.floating, toFloating: current.floating, started: false }
        source.queueLayerDeparture(key, previous.floating ? -1 : 1)
      }
    }
    layerArchive = archive
    transferWorkspace = workspaceId
    if (JSON.stringify(transfers) !== JSON.stringify(next)) { transfers = next; transferRevision++ }
    syncingTransfers = false
  }
  function splitStarted(key, fromFloating) {
    var move = transfers[key]
    if (!move || move.fromFloating !== fromFloating || move.started) return
    var next = Object.assign({}, transfers)
    next[key] = { fromFloating: move.fromFloating, toFloating: move.toFloating, started: true }
    transfers = next
    transferRevision++
    // Keep the destination absent while the source delegate is splitting and
    // fading. finishDeparture() calls splitFinished only after it is removed.
  }
  function splitFinished(key, fromFloating) {
    var move = transfers[key]
    if (!move || move.fromFloating !== fromFloating) return
    var next = Object.assign({}, transfers)
    delete next[key]
    transfers = next
    transferRevision++
    // The source ghost has now been removed, so the destination can enter
    // from its neighboring edge without a duplicate icon or extra width.
    group(move.toFloating).queueTransferArrival(key, !fromFloating)
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
