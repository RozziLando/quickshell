import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services

PanelWindow {
    id: edge
    required property var island

    screen: island.screen
    reloadableId: "edge-" + (island.screen ? island.screen.name : "none")
    visible: !island.remapping && island.autoHide && island.autoHidden && !island.fullscreen

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: island.peek ? island.reservedHeight + gapTop
                                : Math.max(3, Theme.s(3))
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-edge"

    property int gapTop: 0
    Process {
        id: gapsProc
        running: true
        command: ["hyprctl", "-j", "getoption", "general:gaps_out"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const o = JSON.parse(text)
                    const v = parseInt(String(o.css !== undefined ? o.css : o.int).trim().split(/\s+/)[0])
                    edge.gapTop = isNaN(v) ? 0 : v
                } catch (e) {}
            }
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") gapsProc.running = true
        }
    }

    Item {
        anchors.fill: parent
        HoverHandler { id: hover }
    }

    Binding {
        target: edge.island
        property: "edgeStripHovered"
        value: hover.hovered && edge.visible
    }
}
