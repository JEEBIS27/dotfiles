import QtQuick
import QtMultimedia
import IslandBackend
import Quickshell
import Quickshell.Io

Scope {
    id: hub
    property var items: []
    property var history: []
    property var drafts: ({})
    property string outputKind: ""
    property var outputs: []
    property string errorText: ""
    property double clock: Date.now()
    property double awakeUntil: 0
    readonly property bool awake: awakeUntil < 0 || awakeUntil > clock
    readonly property bool recording: recorder.recorderState === MediaRecorder.RecordingState
    property bool startingRecording: false
    property double recordingStarted: 0
    property bool silent: false
    property double lastUnsilenced: 0
    onSilentChanged: if (!silent) lastUnsilenced = Date.now()
    function send(command) {
        if (broker.running) broker.write(JSON.stringify(command) + "\n")
    }
    readonly property int notificationDuration: UserConfig.durations.notificationDurationMs
    onNotificationDurationChanged: send({op: "duration", ms: notificationDuration})
    function report(message) {
        errorText = message
        errorTimeout.restart()
    }
    function toggleRecording() {
        if (recording || startingRecording) {
            startingRecording = false
            recorder.stop()
            capture.active = false
        } else {
            startingRecording = true
            startCapture.restart()
        }
    }
    Timer {
        id: startCapture
        interval: 400
        onTriggered: if (hub.startingRecording) capture.active = true
    }
    CaptureSession {
        screenCapture: ScreenCapture {
            id: capture
            onActiveChanged: if (active && hub.startingRecording) recorder.record()
            onErrorOccurred: (error, message) => {
                hub.startingRecording = false
                capture.active = false
                hub.report(message)
            }
        }
        recorder: MediaRecorder {
            id: recorder
            onRecorderStateChanged: {
                if (hub.recording) {
                    hub.recordingStarted = Date.now()
                    hub.startingRecording = false
                }
            }
            onErrorOccurred: (error, message) => {
                hub.startingRecording = false
                capture.active = false
                hub.report(message)
            }
        }
    }
    Timer { interval: 1000; repeat: true; running: true; onTriggered: hub.clock = Date.now() }
    Timer { id: errorTimeout; interval: 5500; onTriggered: hub.errorText = "" }
    Timer { id: retry; interval: 750; onTriggered: broker.running = true }
    Process {
        id: broker
        command: ["tide-activity", "serve"]
        onStarted: hub.send({op: "duration", ms: hub.notificationDuration})
        stdinEnabled: true
        running: true
        stdout: SplitParser {
            onRead: data => {
                const msg = JSON.parse(data)
                if (msg.items !== undefined) {
                    const pending = new Set(msg.items.filter(row => row.token).map(row => row.token))
                    for (const token of Object.keys(hub.drafts))
                        if (!pending.has(token)) delete hub.drafts[token]
                    hub.items = msg.items
                    hub.history = msg.history
                }
                if (msg.outputs !== undefined) {
                    hub.outputKind = msg.outputKind
                    hub.outputs = msg.outputs
                }
                if (msg.error) hub.report(msg.error)
            }
        }
        onExited: {
            hub.items = []
            retry.restart()
        }
    }
}
