// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import "../../../ShellConfig.js" as ShellConfig
import "JeebisBarTriggerModel.js" as Model

Item {
  id: root
  signal triggered(string name)
  property bool primed: false
  property var snapshots: ({})
  readonly property var battery: UPower.displayDevice
  readonly property var batterySnapshot: battery && battery.isPresent ? ({present: true,
    percent: Math.round(battery.percentage * 100), charging: battery.state === UPowerDeviceState.Charging}) : ({present: false})
  readonly property var devices: Networking.devices ? Networking.devices.values : []
  readonly property bool connected: devices.some(function(device) {
    return (device.type === DeviceType.Wifi || device.type === DeviceType.Wired) && device.connected
  })
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var audioSnapshot: sink && sink.audio ? ({sink: sink.id, volume: sink.audio.volume, muted: sink.audio.muted}) : null
  PwObjectTracker { objects: root.sink ? [root.sink] : [] }
  function observe(channel, value) {
    if (!primed) return
    var event = Model.changed(channel, snapshots[channel], value, ShellConfig.batteryLowThreshold)
    snapshots[channel] = value
    if (event) triggered(event)
  }
  onBatterySnapshotChanged: observe("battery", batterySnapshot)
  onConnectedChanged: observe("network", connected)
  onAudioSnapshotChanged: observe("audio", audioSnapshot)
  // Let initial service enumeration settle; never interpret startup as an event.
  Timer {
    interval: 1500; running: true
    onTriggered: {
      root.snapshots = {battery: root.batterySnapshot, network: root.connected, audio: root.audioSnapshot}
      root.primed = true
    }
  }
  readonly property string usageDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/agents/usage/"
  property var agentIds: []
  Process {
    id: discoverAgents
    command: ["find", root.usageDir, "-maxdepth", "1", "-type", "f", "-name", "*.json", "-printf", "%f\n"]
    stdout: StdioCollector {
      onStreamFinished: {
        var ids = String(text).trim().split("\n").filter(function(name) { return name.endsWith(".json") }).map(function(name) { return name.slice(0, -5) }).sort()
        if (JSON.stringify(ids) !== JSON.stringify(root.agentIds)) root.agentIds = ids
      }
    }
  }
  Timer { interval: 30000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!discoverAgents.running) discoverAgents.running = true }
  Repeater {
    model: root.agentIds
    Item {
      id: agent
      required property string modelData
      property var record: null
      property var previous: null
      function evaluate() {
        var value = Model.exhausted(record, Date.now())
        if (value === null) return // Preserve baseline across invalid/incomplete writes.
        var event = Model.changed("agent", previous, value, 0)
        previous = value
        if (event) root.triggered(event)
      }
      FileView {
        path: root.usageDir + agent.modelData + ".json"
        watchChanges: true; printErrors: false
        onFileChanged: reload()
        onLoaded: {
          try { agent.record = JSON.parse(text()); agent.evaluate() } catch (error) {}
        }
      }
      Timer { interval: 60000; repeat: true; running: true; onTriggered: agent.evaluate() }
    }
  }
}
