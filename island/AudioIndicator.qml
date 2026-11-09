import QtQuick
import Quickshell.Services.Pipewire
import qs.services
import qs.widgets

// Stato dell'audio: cuffie (se collegate), muto, volume basso o alto.
// Le cuffie Bluetooth/USB si riconoscono da PipeWire; quelle col jack dalla
// porta attiva, letta con pactl (se non c'è, si riconoscono solo le prime).
Item {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool available: !!(sink && sink.audio)
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    readonly property bool muted: available && (sink.audio.muted || sink.audio.volume <= 0.001)
    readonly property real volume: available ? sink.audio.volume : 0

    // ----- Cuffie Bluetooth / USB (proprietà del dispositivo PipeWire) -----
    readonly property bool headsetDevice: {
        if (!sink) return false
        var p = sink.properties || {}
        var ff = String(p["device.form-factor"] || "").toLowerCase()
        if (["headphone", "headset", "hands-free", "handset"].indexOf(ff) >= 0) return true
        if (String(sink.name).indexOf("bluez_output") === 0) return true
        return /headphone|headset|cuffie/i.test(sink.description || "")
    }

    // ----- Cuffie col jack (porta attiva, da pactl: services/AudioPorts) -----
    onSinkChanged: AudioPorts.refresh()

    readonly property bool headphones: headsetDevice || AudioPorts.headphonePort

    // ----- Icona -----
    LineIcon {
        anchors.centerIn: parent
        size: Math.round(parent.height * 0.62)
        kind: root.headphones ? "headphones"
            : root.muted ? "volume-mute"
            : root.volume < 0.5 ? "volume-low" : "volume"
        // Cuffie in muto: icona attenuata
        color: root.headphones && root.muted ? Theme.textMuted : Theme.text
        visible: root.available
    }
}
