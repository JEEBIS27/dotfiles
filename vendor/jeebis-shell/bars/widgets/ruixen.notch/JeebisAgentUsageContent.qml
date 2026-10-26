// Copyright (c) 2026 Jeebis. SPDX-License-Identifier: MIT
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "JeebisAgentUsageModel.js" as Usage

Item {
  id: root
  property bool active: false
  property color textColor: "white"
  property color muted: "gray"
  property color accent: "skyblue"
  property string fontFamily: "monospace"
  property var records: ({})
  property string selected: "codex"
  readonly property var record: records[selected] || null
  readonly property var modelRows: Usage.models(record)
  readonly property var recentDays: Usage.days(record)
  readonly property string usageDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/agents/usage/"
  onActiveChanged: if (active) refresh()
  function refresh() { if (active && !collector.running) collector.running = true }
  function resetText(value) {
    var date = new Date(String(value || ""))
    return isNaN(date.getTime()) ? "不明" : Qt.formatDateTime(date, "MM/dd HH:mm")
  }
  Process { id: collector; command: ["omarchy-agent-usage-update"] }
  Timer { interval: 60000; repeat: true; running: root.active; onTriggered: root.refresh() }
  Repeater {
    model: ["codex", "claude", "fireworks"]
    Item {
      id: recordLoader
      required property string modelData
      FileView {
        path: root.usageDir + recordLoader.modelData + ".json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
          var next = Object.assign({}, root.records)
          next[recordLoader.modelData] = Usage.parse(text())
          root.records = next
        }
        onLoadFailed: {
          var next = Object.assign({}, root.records)
          delete next[recordLoader.modelData]; root.records = next
        }
      }
    }
  }
  Flickable {
    id: scroll
    anchors.fill: parent
    contentWidth: width
    contentHeight: content.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ColumnLayout {
      id: content
      width: parent.width
      spacing: 10
      RowLayout {
        Layout.fillWidth: true
        Label { text: "Agent使用状況"; font.pixelSize: 20; Layout.fillWidth: true }
        Action { text: collector.running ? "更新中…" : "更新"; onTriggered: root.refresh() }
      }
      RowLayout {
        Repeater {
          model: ["codex", "claude", "fireworks"]
          Action {
            required property string modelData
            text: root.records[modelData] ? String(root.records[modelData].name || modelData) : modelData
            chosen: root.selected === modelData
            onTriggered: root.selected = modelData
          }
        }
      }
      Label {
        Layout.fillWidth: true
        color: root.muted
        text: root.record ? String(root.record.tierLabel || "プラン情報なし") + "  ·  更新 " + root.resetText(root.record.updatedAt) : "使用記録がありません。Agentを利用後に更新してください。"
      }
      Label {
        Layout.fillWidth: true
        visible: !!root.record && (!!root.record.usageStatusText || (root.record.ready === false && !!root.record.authHelpText))
        text: root.record ? [root.record.usageStatusText, root.record.ready === false ? root.record.authHelpText : ""].filter(function(v) { return !!v }).join("\n") : ""
      }
      RowLayout {
        Layout.fillWidth: true
        Stat { title: "今日のトークン"; value: root.record && root.record.hasLocalStats !== false ? Usage.format(root.record.todayTotalTokens) : "—" }
        Stat { title: "記録範囲の累計トークン"; value: root.record && root.record.hasLocalStats !== false ? Usage.format(Usage.total(root.record)) : "—" }
        Stat { title: "今日のプロンプト / セッション"; value: root.record && root.record.hasPromptStats !== false ? Usage.format(root.record.todayPrompts) + " / " + Usage.format(root.record.todaySessions) : "—" }
      }
      Label { text: "利用枠（使用済み）"; font.pixelSize: 16 }
      Label { visible: !root.record || !(root.record.limits || []).length; text: "Limit情報は未取得です。トークン数からLimit残量は推定しません。"; color: root.muted; Layout.fillWidth: true }
      Repeater {
        model: root.record ? (root.record.limits || []) : []
        ColumnLayout {
          required property var modelData
          Layout.fillWidth: true
          RowLayout {
            Layout.fillWidth: true
            Label { Layout.fillWidth: true; text: String(parent.parent.modelData.label || "Limit") }
            Label { text: Math.round(Math.max(0, Math.min(1, Number(parent.parent.modelData.percent || 0))) * 100) + "%  ·  リセット " + root.resetText(parent.parent.modelData.resetsAt) }
          }
          Rectangle {
            Layout.fillWidth: true; height: 5; radius: 2.5
            color: Qt.rgba(root.textColor.r, root.textColor.g, root.textColor.b, 0.12)
            Rectangle { width: parent.width * Math.max(0, Math.min(1, Number(parent.parent.modelData.percent || 0))); height: parent.height; radius: 2.5; color: root.accent }
          }
        }
      }
      Label { text: "過去7日間のトークン"; font.pixelSize: 16 }
      Repeater {
        model: root.recentDays
        RowLayout {
          required property var modelData
          Layout.fillWidth: true
          Label { text: String(parent.modelData.date || ""); Layout.preferredWidth: 110 }
          Rectangle {
            Layout.fillWidth: true; height: 8; radius: 4
            color: Qt.rgba(root.textColor.r,root.textColor.g,root.textColor.b,0.08)
            Rectangle {
              height: parent.height; radius: 4; color: root.accent
              width: parent.width * Usage.count(parent.parent.modelData.messageCount) / Math.max(1, root.recentDays.reduce(function(m,d) { return Math.max(m,Usage.count(d.messageCount)) },0))
            }
          }
          Label { text: Usage.format(parent.modelData.messageCount); Layout.preferredWidth: 110; horizontalAlignment: Text.AlignRight }
        }
      }
      Label { text: "モデル別（収集済み記録の累計）"; font.pixelSize: 16 }
      Repeater {
        model: root.modelRows
        Rectangle {
          required property var modelData
          Layout.fillWidth: true
          implicitHeight: modelContent.implicitHeight + 16
          radius: 10
          color: Qt.rgba(root.textColor.r,root.textColor.g,root.textColor.b,0.06)
          ColumnLayout {
            id: modelContent
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
            Label { Layout.fillWidth: true; text: parent.parent.modelData.name + "  ·  " + Usage.format(parent.parent.modelData.total) }
            Label {
              Layout.fillWidth: true; color: root.muted
              text: "入力 " + Usage.format(parent.parent.modelData.input) + "   出力 " + Usage.format(parent.parent.modelData.output)
                + "   キャッシュ読込 " + Usage.format(parent.parent.modelData.cacheRead) + "   書込 " + Usage.format(parent.parent.modelData.cacheWrite)
            }
          }
        }
      }
      Label {
        Layout.fillWidth: true; color: root.muted
        text: "ローカルAgent収集記録の集計です。ChatGPTのWeb利用など収集対象外の利用は含みません。更新時刻・取得状態もあわせて確認してください。"
      }
    }
  }
  Rectangle {
    anchors.right: parent.right
    width: 3
    height: scroll.height * Math.min(1, scroll.height / Math.max(1, scroll.contentHeight))
    y: Math.max(0, Math.min(scroll.height - height, scroll.contentY * scroll.height / Math.max(1, scroll.contentHeight)))
    radius: 1.5
    color: root.muted
    opacity: scroll.moving ? 0.8 : 0.3
    visible: scroll.contentHeight > scroll.height
  }
  component Label: Text {
    color: root.textColor
    font.family: root.fontFamily
    font.pixelSize: 12
    wrapMode: Text.Wrap
  }
  component Action: Rectangle {
    id: action
    property string text
    property bool chosen: false
    signal triggered()
    implicitWidth: caption.implicitWidth + 24
    implicitHeight: 32
    radius: 12
    color: chosen ? root.accent : Qt.rgba(root.textColor.r,root.textColor.g,root.textColor.b,0.08)
    Label { id: caption; anchors.centerIn: parent; text: action.text; color: action.chosen ? (root.accent.hslLightness > .5 ? "#181818" : "white") : root.textColor }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: action.triggered() }
  }
  component Stat: Rectangle {
    id: stat
    property string title
    property string value
    Layout.fillWidth: true
    implicitHeight: 75
    radius: 12
    color: Qt.rgba(root.textColor.r,root.textColor.g,root.textColor.b,0.06)
    Column {
      anchors { left: parent.left; right: parent.right; margins: 10; verticalCenter: parent.verticalCenter }
      spacing: 6
      Label { text: stat.title; color: root.muted; font.pixelSize: 10 }
      Label { text: stat.value; font.pixelSize: 17; color: root.accent }
    }
  }
}
