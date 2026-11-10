import QtQuick
import QtQuick.Effects
import qs.services

MultiEffect {
    readonly property bool dark: Theme.darkShadow

    shadowEnabled: true
    shadowColor: dark ? "#90000000" : Theme.glow
    shadowBlur: dark ? 0.7 : 0.35
    blurMax: dark ? 24 : 12
    shadowHorizontalOffset: 0
    shadowVerticalOffset: dark ? Theme.s(3) : 0
    autoPaddingEnabled: true
}
