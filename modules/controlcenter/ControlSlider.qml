import QtQuick
import qs.services
import qs.widgets

Card {
    id: root

    property real sizeFactor: 1.0
    function u(value) { return Theme.s(value * sizeFactor) }

    property string title: ""
    property string icon: ""
    property real value: 0
    property bool available: true
    property bool muted: false
    property bool iconClickable: false
    property bool showDetails: true

    signal moved(real value)
    signal iconClicked()
    signal detailsClicked()

    property bool dragging: false
    property real dragValue: 0
    readonly property real shownValue: Math.max(0, Math.min(1, dragging ? dragValue : value))
    property real animValue: shownValue
    Behavior on animValue {
        enabled: !root.dragging && root.visible
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    radius: root.u(22)
    opacity: available ? 1 : 0.4

    function setFromX(x) {
        dragValue = Math.max(0, Math.min(1, x / track.width))
        if (!throttle.running) throttle.start()
    }

    Timer {
        id: throttle
        interval: 100
        onTriggered: root.moved(root.dragValue)
    }

    readonly property real headerH: track.y

    Text {
        anchors {
            left: parent.left
            leftMargin: root.u(16)
            verticalCenter: parent.top
            verticalCenterOffset: root.headerH / 2
        }
        verticalAlignment: Text.AlignVCenter
        text: root.title
        color: Theme.text
        font.pixelSize: root.u(12)
        font.bold: true
        font.family: Theme.fontFamily
    }

    Rectangle {
        visible: root.showDetails
        width: root.u(18)
        height: width
        radius: width / 2
        anchors {
            right: parent.right
            rightMargin: root.u(10)
        }
        y: Math.round((root.headerH - height) / 2)
        color: chevronArea.containsMouse ? Theme.highlight : Theme.surface

        LineIcon {
            anchors.centerIn: parent
            kind: "chevron"
            size: root.u(9)
            color: Theme.textSecondary
        }

        MouseArea {
            id: chevronArea
            anchors.fill: parent
            anchors.margins: -root.u(4)
            hoverEnabled: true
            onClicked: root.detailsClicked()
        }
    }

    Rectangle {
        id: track
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            leftMargin: root.u(10)
            rightMargin: root.u(10)
            bottomMargin: root.u(8)
        }
        height: root.u(24)
        radius: height / 2
        color: Theme.track

        Rectangle {
            id: fill
            height: parent.height
            radius: height / 2
            width: root.animValue <= 0.001 ? 0 : Math.max(height, root.animValue * track.width)
            color: root.muted ? Theme.textDisabled : Theme.accent
        }

        LineIcon {
            anchors.left: parent.left
            anchors.leftMargin: root.u(10)
            anchors.verticalCenter: parent.verticalCenter
            size: root.u(13)
            kind: root.icon
            color: fill.width > root.u(28) ? Theme.background : Theme.text
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.available
            onPressed: mouse => {
                root.dragging = true
                root.setFromX(mouse.x)
            }
            onPositionChanged: mouse => {
                if (pressed) root.setFromX(mouse.x)
            }
            onReleased: {
                throttle.stop()
                root.moved(root.dragValue)
                root.dragging = false
            }
            onCanceled: {
                throttle.stop()
                root.dragging = false
            }
        }

        MouseArea {
            visible: root.iconClickable
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: root.u(34)
            onClicked: root.iconClicked()
        }
    }

    property real wheelAcc: 0
    WheelHandler {
        enabled: root.available
        onWheel: event => {
            root.wheelAcc += event.angleDelta.y
            var steps = Math.trunc(root.wheelAcc / 120)
            if (steps === 0) return
            root.wheelAcc -= steps * 120
            root.moved(Math.max(0, Math.min(1, Math.min(1, root.value) + steps * 0.05)))
        }
    }
}
