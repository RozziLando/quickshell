import QtQuick
import qs.services

Item {
    id: root

    property real from: 0
    property real to: 1
    property real step: 0.05
    property var values: []
    property real value: 0

    signal committed(real value)

    readonly property bool dragging: area.pressed
    property real dragValue: value
    property bool pending: false
    readonly property real shown: dragging || pending ? dragValue : value

    onValueChanged: pending = false

    Timer {
        id: pendingEnd
        interval: 1500
        onTriggered: root.pending = false
    }

    width: parent ? parent.width : 0
    height: SettingsUi.u(18)

    function frac(v) {
        if (values.length > 1) {
            var best = 0
            for (var i = 1; i < values.length; i++)
                if (Math.abs(values[i] - v) < Math.abs(values[best] - v)) best = i
            return best / (values.length - 1)
        }
        return to > from ? Math.max(0, Math.min(1, (v - from) / (to - from))) : 0
    }

    function fromFrac(f) {
        f = Math.max(0, Math.min(1, f))
        if (values.length > 1) return values[Math.round(f * (values.length - 1))]
        var v = from + Math.round(f * (to - from) / step) * step
        return Math.round(Math.max(from, Math.min(to, v)) * 1000) / 1000
    }

    Rectangle {
        id: track
        anchors.fill: parent
        radius: Math.min(SettingsUi.radius, height / 2)
        color: Theme.track

        Rectangle {
            readonly property real pos: root.frac(root.shown)
            height: parent.height
            radius: parent.radius
            width: Math.max(height, height + pos * (parent.width - height))
            color: Theme.accent
            Behavior on width {
                enabled: !root.dragging
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: SettingsUi.u(3)
                anchors.verticalCenter: parent.verticalCenter
                width: parent.height - SettingsUi.u(6)
                height: width
                radius: Theme.round(width)
                color: Theme.background
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.topMargin: -SettingsUi.u(4)
        anchors.bottomMargin: -SettingsUi.u(4)
        preventStealing: true
        cursorShape: Qt.PointingHandCursor

        function at(x) {
            var h = track.height
            return root.fromFrac((x - h / 2) / Math.max(1, track.width - h))
        }
        onPressed: mouse => { root.dragValue = at(mouse.x) }
        onPositionChanged: mouse => { if (pressed) root.dragValue = at(mouse.x) }
        onReleased: {
            if (root.dragValue === root.value) return
            root.pending = true
            pendingEnd.restart()
            root.committed(root.dragValue)
        }
    }
}
