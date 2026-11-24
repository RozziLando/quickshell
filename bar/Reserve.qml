import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: reserve

    required property string edge
    property int size: 0

    anchors {
        top: edge !== "bottom"
        bottom: edge !== "top"
        left: edge !== "right"
        right: edge !== "left"
    }
    implicitWidth: Math.max(1, size)
    implicitHeight: Math.max(1, size)
    exclusiveZone: size
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "quickshell-reserve"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
}
