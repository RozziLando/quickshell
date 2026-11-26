import QtQuick
import QtQuick.Effects
import qs.services

RectangularShadow {
    property bool drop: true
    readonly property bool dark: Theme.darkShadow

    visible: Theme.shadowEnabled
    opacity: Theme.glass ? Theme.glassOpacity : 1
    color: dark ? "#90000000" : Theme.glow
    blur: dark ? 17 : 4
    spread: 0
    offset.x: 0
    offset.y: dark && drop ? Theme.s(3) : 0
}
