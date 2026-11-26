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
    property bool compact: false
    property bool devicesOpen: false
    onVisibleChanged: if (!visible) {
        dragCount = 0
        devicesOpen = false
    }
    readonly property bool showDevices: !compact || devicesOpen

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
        text: "Applications"
    }
    Repeater {
        model: ScriptModel { values: page.apps }
        delegate: Item {
            id: appRow
            required property var modelData
            readonly property string iconPath: page.appIcon(modelData)
            width: parent.width
            height: page.u(26)

            Image {
                id: appIcon
                visible: appRow.iconPath !== ""
                anchors.left: parent.left
                anchors.leftMargin: page.u(2)
                anchors.verticalCenter: parent.verticalCenter
                width: page.u(20)
                height: width
                source: appRow.iconPath
                sourceSize.width: width * 2
                sourceSize.height: height * 2
                asynchronous: true
                smooth: true
                mipmap: true
            }
            LineIcon {
                visible: appRow.iconPath === ""
                anchors.centerIn: appIcon
                kind: "app"
                size: page.u(16)
                color: Theme.textSecondary
            }

            VolumeBar {
                anchors.left: appIcon.right
                anchors.leftMargin: page.u(8)
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
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

    Item {
        visible: page.compact
        width: parent.width
        height: page.u(4)
    }

    Rectangle {
        id: devicesToggle
        visible: page.compact
        width: parent.width
        height: page.u(40)
        radius: Theme.radius
        color: toggleArea.containsMouse ? Theme.surface : Theme.card
        border.width: 1
        border.color: Theme.cardBorder
        Behavior on color { ColorAnimation { duration: 150 } }

        LineIcon {
            id: toggleIcon
            x: page.u(12)
            anchors.verticalCenter: parent.verticalCenter
            kind: "headphones"
            size: page.u(15)
            color: Theme.text
        }
        Column {
            anchors.left: toggleIcon.right
            anchors.leftMargin: page.u(10)
            anchors.right: toggleChevron.left
            anchors.rightMargin: page.u(8)
            anchors.verticalCenter: parent.verticalCenter

            Text {
                width: parent.width
                text: "Output and input"
                color: Theme.text
                font.pixelSize: page.u(12)
                font.bold: true
                font.family: Theme.fontFamily
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: Pipewire.defaultAudioSink ? page.deviceName(Pipewire.defaultAudioSink) : ""
                visible: text !== ""
                color: Theme.textSecondary
                font.pixelSize: page.u(10)
                font.family: Theme.fontFamily
                elide: Text.ElideRight
            }
        }
        LineIcon {
            id: toggleChevron
            anchors.right: parent.right
            anchors.rightMargin: page.u(12)
            anchors.verticalCenter: parent.verticalCenter
            kind: "chevron"
            size: page.u(11)
            color: Theme.textSecondary
            rotation: page.devicesOpen ? -90 : 90
            Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }
        MouseArea {
            id: toggleArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: page.devicesOpen = !page.devicesOpen
        }
    }

    Column {
        visible: page.showDevices
        width: parent.width
        spacing: page.u(6)

        SectionTitle {
            sizeFactor: page.sizeFactor
            text: "Output"
        }
        Repeater {
            model: ScriptModel { values: page.outputs }
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
            model: ScriptModel { values: page.inputs }
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

    }
}
