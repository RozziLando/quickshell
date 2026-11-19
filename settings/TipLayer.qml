import QtQuick
import qs.services

Item {
    id: tipLayer

    anchors.fill: parent
    readonly property var tip: SettingsUi.tip
    visible: tip !== null && tipText.text !== ""

    function u(v) { return SettingsUi.u(v) }

    property real pointX: 0
    property real pointY: 0
    property real anchorH: 0

    onTipChanged: {
        if (!tip || !tip.anchor) return
        tipText.text = tip.text
        var a = tip.anchor
        var p = a.mapToItem(tipLayer, a.width / 2, 0)
        pointX = p.x
        pointY = p.y
        anchorH = a.height
    }

    Rectangle {
        id: bubble
        x: Math.max(tipLayer.u(8), Math.min(tipLayer.pointX - width / 2, tipLayer.width - width - tipLayer.u(8)))
        y: tipLayer.pointY - height - tipLayer.u(8) >= tipLayer.u(8) ? tipLayer.pointY - height - tipLayer.u(8)
                                                           : tipLayer.pointY + tipLayer.anchorH + tipLayer.u(8)
        width: Math.min(tipLayer.u(260), tipText.implicitWidth + 2 * tipLayer.u(12))
        height: tipText.implicitHeight + 2 * tipLayer.u(8)
        radius: SettingsUi.radius
        color: Theme.background
        border.width: 1
        border.color: Theme.cardBorder

        Text {
            id: tipText
            x: tipLayer.u(12)
            y: tipLayer.u(8)
            width: Math.min(tipLayer.u(236), implicitWidth)
            wrapMode: Text.WordWrap
            color: Theme.textSoft
            font.pixelSize: tipLayer.u(9.5)
            font.family: Theme.fontFamily
            lineHeight: 1.15
        }
    }
}
