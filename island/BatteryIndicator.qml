import QtQuick
import Quickshell.Services.UPower
import qs.services
import qs.widgets

Item {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool available: !!(device && device.ready
                                         && device.isLaptopBattery && device.isPresent)

    readonly property real level: {
        if (!available) return 0
        var p = device.percentage
        return Math.max(0, Math.min(1, p > 1 ? p / 100 : p))
    }
    readonly property bool plugged: available && !UPower.onBattery

    readonly property real bodyW: Math.round(width * 0.58)
    readonly property real bodyH: Math.round(height * 0.38)
    readonly property real nubW: Math.max(2, Math.round(width * 0.06))

    LineIcon {
        anchors.centerIn: parent
        visible: !root.available
        kind: "cpu"
        size: Math.round(parent.height * 0.62)
        color: Theme.text
    }

    Rectangle {
        id: body
        visible: root.available
        width: root.bodyW
        height: root.bodyH
        x: Math.round((root.width - width) / 2)
        anchors.verticalCenter: parent.verticalCenter
        radius: Math.round(height * 0.28)
        color: "transparent"
        border.width: Math.max(1, Math.round(root.height * 0.05))
        border.color: Theme.text

        Rectangle {
            readonly property real inset: body.border.width + Math.max(1, Math.round(root.height * 0.04))
            visible: !root.plugged
            x: inset
            y: inset
            height: parent.height - 2 * inset
            width: Math.max(0, (parent.width - 2 * inset) * root.level)
            radius: Math.max(1, body.radius - inset)
            color: Theme.text
            Behavior on width { NumberAnimation { duration: 300 } }
        }

        Canvas {
            id: bolt
            anchors.centerIn: parent
            visible: root.plugged
            width: parent.height * 0.95
            height: parent.height * 0.95
            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()
                ctx.scale(width / 24, height / 24)
                ctx.beginPath()
                ctx.moveTo(13.5, 1.5); ctx.lineTo(4.5, 13.5); ctx.lineTo(11, 13.5)
                ctx.lineTo(9.5, 22.5); ctx.lineTo(19.5, 10); ctx.lineTo(13, 10)
                ctx.closePath()
                ctx.fillStyle = Theme.text.toString()
                ctx.fill()
            }
            Connections {
                target: Theme
                function onTextChanged() { bolt.requestPaint() }
            }
        }
    }

    Rectangle {
        visible: root.available
        anchors.left: body.right
        anchors.verticalCenter: body.verticalCenter
        width: root.nubW
        height: Math.round(body.height * 0.42)
        radius: width / 2
        color: Theme.text
    }
}
