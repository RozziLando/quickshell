import QtQuick
import qs.services

Rectangle {
    color: Theme.panel
    border.width: Theme.glass || Theme.shadowEnabled ? 0 : 1
    border.color: Theme.border
    layer.enabled: Theme.glass && visible
    layer.effect: LiquidGlass {}
}
