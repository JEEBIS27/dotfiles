import QtQuick
import QtQuick.Effects

Item {
    id: transition
    default property alias content: foreground.data
    required property string presentation
    required property string edgePanel
    required property real edgeExit
    required property bool animate
    readonly property bool accelerated: GraphicsInfo.api !== GraphicsInfo.Software
    property bool ready: false
    property bool firstLive: true
    property string renderedEdge: ""
    property real blend: 1
    readonly property bool showingPrevious: blend < 0.4
    readonly property real defocus: Math.max(edgeExit, showingPrevious ? blend / 0.4 : (1 - blend) / 0.6)

    Component.onCompleted: {
        renderedEdge = edgePanel
        ready = true
    }
    onPresentationChanged: {
        if (!ready) return
        const samePlacement = edgePanel === renderedEdge
        renderedEdge = edgePanel
        fade.stop()
        if (!animate) {
            blend = 1
            return
        }
        // Freeze the texture currently on screen before the next frame. The
        // other texture is free to render the destination's live controls.
        if (!showingPrevious) firstLive = !firstLive
        blend = accelerated && samePlacement ? 0 : 0.4
        fade.start()
    }

    NumberAnimation {
        id: fade
        target: transition
        property: "blend"
        to: 1
        duration: transition.showingPrevious ? 225 : 135
    }

    Item {
        id: foreground
        anchors.fill: parent
        opacity: transition.accelerated ? 1 : 1 - transition.defocus
    }

    ShaderEffectSource {
        id: first
        width: viewport.width
        height: viewport.height
        property rect viewport
        Binding on viewport {
            when: first.live
            value: Qt.rect(0, 0, foreground.width, foreground.height)
            restoreMode: Binding.RestoreNone
        }
        sourceRect: viewport
        visible: false
        sourceItem: transition.accelerated ? foreground : null
        hideSource: transition.accelerated
        live: transition.firstLive
    }
    ShaderEffectSource {
        id: second
        width: viewport.width
        height: viewport.height
        property rect viewport
        Binding on viewport {
            when: second.live
            value: Qt.rect(0, 0, foreground.width, foreground.height)
            restoreMode: Binding.RestoreNone
        }
        sourceRect: viewport
        visible: false
        sourceItem: transition.accelerated ? foreground : null
        hideSource: transition.accelerated
        live: !transition.firstLive
    }

    MultiEffect {
        readonly property bool useFirst: transition.firstLive !== transition.showingPrevious
        width: source.width
        height: source.height
        anchors.horizontalCenter: parent.horizontalCenter
        visible: transition.accelerated
        source: useFirst ? first : second
        opacity: 1 - transition.defocus
        blurEnabled: true
        blurMax: 10
        blur: transition.defocus
    }
}
