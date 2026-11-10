import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.services
import qs.widgets

SubPage {
    id: page

    title: "Audio"

    property int dragCount: 0
    readonly property bool busy: dragCount > 0
    onVisibleChanged: if (!visible) dragCount = 0

    readonly property var nodes: Pipewire.nodes.values

    readonly property var outputs: nodes.filter(function (n) {
        return n.audio && n.isSink && !n.isStream
    })
    readonly property var inputs: nodes.filter(function (n) {
        return n.audio && !n.isSink && !n.isStream
    })
    readonly property var apps: nodes.filter(function (n) {
        return n.audio && n.isStream && n.isSink
    })

    PwObjectTracker { objects: page.visible ? page.nodes : [] }

    function deviceName(n) {
        return n.description || n.nickname || n.name
    }

    function appName(n) {
        var p = n.properties || {}
        return p["application.name"] || n.description || n.name
    }

    function appIcon(n) {
        var p = n.properties || {}
        var app = appName(n)
        var names = [p["application.icon-name"], p["application.process.binary"],
                     app ? app.toLowerCase() : ""]
        for (var i = 0; i < names.length; i++) {
            if (!names[i]) continue
            var path = Quickshell.iconPath(names[i], true)
            if (path !== "") return path
        }
        var entry = DesktopEntries.heuristicLookup(appName(n))
        if (entry && entry.icon) return Quickshell.iconPath(entry.icon, true)
        return ""
    }

    component VolumeBar: MiniSlider {
        required property var node
        width: parent.width
        value: node.audio ? node.audio.volume : 0
        muted: node.audio ? node.audio.muted : false
        onMoved: v => { if (node.audio) node.audio.volume = Math.max(0, Math.min(1, v)) }
        onIconClicked: if (node.audio) node.audio.muted = !node.audio.muted
    }

    SectionTitle {
        sizeFactor: page.sizeFactor
        text: "Output"
    }
    Repeater {
        model: page.outputs
        delegate: ListRow {
            id: outRow
            required property var modelData
            readonly property bool current: Pipewire.defaultAudioSink === modelData
            sizeFactor: page.sizeFactor
            icon: "volume"
            title: page.deviceName(modelData)
            selected: current
            trailingIcon: current ? "check" : ""
            hasExtra: true
            onClicked: Pipewire.preferredDefaultAudioSink = modelData

            VolumeBar {
                node: outRow.modelData
                sizeFactor: page.sizeFactor
                onDraggingChanged: page.dragCount += dragging ? 1 : -1
                Component.onDestruction: if (dragging) page.dragCount--
            }
        }
    }

    SectionTitle {
        sizeFactor: page.sizeFactor
        text: "Input"
    }
    Repeater {
        model: page.inputs
        delegate: ListRow {
            id: inRow
            required property var modelData
            readonly property bool current: Pipewire.defaultAudioSource === modelData
            sizeFactor: page.sizeFactor
            icon: "mic"
            title: page.deviceName(modelData)
            selected: current
            trailingIcon: current ? "check" : ""
            hasExtra: true
            onClicked: Pipewire.preferredDefaultAudioSource = modelData

            VolumeBar {
                node: inRow.modelData
                sizeFactor: page.sizeFactor
                icon: "mic"
                onDraggingChanged: page.dragCount += dragging ? 1 : -1
                Component.onDestruction: if (dragging) page.dragCount--
            }
        }
    }
    Text {
        visible: page.inputs.length === 0
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "No input devices"
        color: Theme.textMuted
        font.pixelSize: page.u(10)
        font.family: Theme.fontFamily
    }

    SectionTitle {
        sizeFactor: page.sizeFactor
        text: "Applications"
    }
    Repeater {
        model: page.apps
        delegate: ListRow {
            id: appRow
            required property var modelData
            readonly property var props: modelData.properties || {}
            sizeFactor: page.sizeFactor
            icon: "app"
            iconSource: page.appIcon(modelData)
            title: page.appName(modelData)
            subtitle: props["media.name"] || ""
            clickable: false
            hasExtra: true

            VolumeBar {
                node: appRow.modelData
                sizeFactor: page.sizeFactor
                onDraggingChanged: page.dragCount += dragging ? 1 : -1
                Component.onDestruction: if (dragging) page.dragCount--
            }
        }
    }
    Text {
        visible: page.apps.length === 0
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: "No apps playing audio"
        color: Theme.textMuted
        font.pixelSize: page.u(10)
        font.family: Theme.fontFamily
    }
}
