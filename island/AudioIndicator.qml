import QtQuick
import Quickshell.Services.Pipewire
import qs.services
import qs.widgets

Item {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool available: !!(sink && sink.audio)
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    readonly property bool muted: available && (sink.audio.muted || sink.audio.volume <= 0.001)
    readonly property real volume: available ? sink.audio.volume : 0

    readonly property bool headsetDevice: {
        if (!sink) return false
        var p = sink.properties || {}
        var ff = String(p["device.form-factor"] || "").toLowerCase()
        if (["headphone", "headset", "hands-free", "handset"].indexOf(ff) >= 0) return true
        if (String(sink.name).indexOf("bluez_output") === 0) return true
        return /headphone|headset|cuffie/i.test(sink.description || "")
    }

    onSinkChanged: AudioPorts.refresh()

    readonly property bool headphones: headsetDevice || AudioPorts.headphonePort

    LineIcon {
        anchors.centerIn: parent
        size: Math.round(parent.height * 0.62)
        kind: root.headphones ? "headphones"
            : root.muted ? "volume-mute"
            : root.volume < 0.5 ? "volume-low" : "volume"
        color: root.headphones && root.muted ? Theme.textMuted : Theme.text
        visible: root.available
    }
}
