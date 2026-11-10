import QtQuick
import Quickshell.Services.Pipewire
import qs.services
import qs.widgets

Item {
    id: root
    required property var island
    anchors.fill: parent

    readonly property string ownerId: "osd"
    readonly property bool shown: island.owner === ownerId

    readonly property real sizeFactor: 0.968
    function u(value) { return Theme.s(value * sizeFactor) }

    readonly property int sliderH: u(24)
    readonly property int topPad: island.floating ? Math.floor((island.idleH - sliderH) / 2) : u(12)
    readonly property int bottomPad: island.floating ? island.idleH - sliderH - topPad : u(16)
    readonly property int sidePad: island.floating ? island.topRadius + topPad : u(24)
    readonly property int openWidth: u(280)
    readonly property int openHeight: topPad + sliderH + bottomPad

    property int timeout: 1500

    property string kind: "volume"

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool audioAvailable: !!(sink && sink.audio)
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    property bool ready: false
    Timer {
        interval: 2500
        running: true
        onTriggered: root.ready = true
    }

    property bool sinkSwitching: false
    onSinkChanged: {
        sinkSwitching = true
        sinkSettle.restart()
    }
    Timer {
        id: sinkSettle
        interval: 800
        onTriggered: root.sinkSwitching = false
    }

    Connections {
        target: root.audioAvailable ? root.sink.audio : null
        function onVolumeChanged() { if (!root.sinkSwitching) root.show("volume") }
        function onMutedChanged() { if (!root.sinkSwitching) root.show("volume") }
    }

    Connections {
        target: Brightness
        function onDisplayChangedExternally() { root.show("display") }
        function onKeyboardChangedExternally() { root.show("keyboard") }
    }

    function show(which) {
        if (!ready) return
        var o = island.owner
        if (o !== "" && o !== ownerId && o !== "media" && o !== "notif") return

        kind = which
        island.open(ownerId, openWidth, openHeight)
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: root.timeout
        onTriggered: {
            if (root.island.hovered || slider.dragging) restart()
            else root.island.close(root.ownerId)
        }
    }

    MiniSlider {
        id: slider
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: root.sidePad
            rightMargin: root.sidePad
            topMargin: root.topPad
        }
        height: root.sliderH
        sizeFactor: root.sizeFactor
        showPercent: false

        icon: root.kind === "volume" ? "volume"
              : root.kind === "display" ? "sun" : "keyboard"
        value: root.kind === "volume" ? (root.audioAvailable ? root.sink.audio.volume : 0)
             : root.kind === "display" ? Brightness.displayLevel : Brightness.keyboardLevel
        muted: root.kind === "volume" && root.audioAvailable && root.sink.audio.muted

        onMoved: value => {
            if (root.kind === "volume") {
                if (root.audioAvailable)
                    root.sink.audio.volume = Math.max(0, Math.min(1, value))
            } else if (root.kind === "display") {
                Brightness.setDisplay(value)
            } else {
                Brightness.setKeyboard(value)
            }
            hideTimer.restart()
        }
        onIconClicked: {
            if (root.kind === "volume" && root.audioAvailable) root.sink.audio.muted = !root.sink.audio.muted
        }

        visible: root.shown
        FadeIn { active: root.shown; pause: 120; duration: 180 }
    }
}
