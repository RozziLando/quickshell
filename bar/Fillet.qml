import QtQuick
import qs.services

Item {
    id: piece

    property real size: 0
    property string corner: "tr"
    property color fill: Theme.panel

    width: size
    height: size
    visible: size > 0
    clip: true
    rotation: corner === "br" ? 90 : corner === "bl" ? 180 : corner === "tl" ? 270 : 0

    readonly property real span: 2 * size + 2
    readonly property real band: size + 2

    Rectangle {
        x: piece.size - piece.span - piece.band
        y: -piece.band
        width: piece.span + 2 * piece.band
        height: piece.span + 2 * piece.band
        radius: piece.size + piece.band
        color: "transparent"
        border.width: piece.band
        border.color: piece.fill
    }
}
