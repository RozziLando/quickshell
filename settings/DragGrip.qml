import QtQuick
import qs.services

MouseArea {
    id: grip

    required property var designer
    property string itemId: ""
    property bool tile: true
    property bool fromPanel: false

    anchors.fill: parent
    hoverEnabled: true
    preventStealing: true
    cursorShape: designer.dragId !== "" ? Qt.ClosedHandCursor : Qt.OpenHandCursor

    property point start: Qt.point(0, 0)
    property bool moved: false

    onPressed: mouse => {
        start = Qt.point(mouse.x, mouse.y)
        moved = false
    }
    onPositionChanged: mouse => {
        if (!pressed) return
        if (!moved && Math.abs(mouse.x - start.x) + Math.abs(mouse.y - start.y) < SettingsUi.u(6)) return
        var p = mapToItem(designer, mouse.x, mouse.y)
        if (!moved) {
            moved = true
            designer.begin(itemId, tile, fromPanel, start.x, start.y, parent.width, parent.height)
        }
        designer.move(p.x, p.y)
    }
    onReleased: {
        if (moved) designer.finish()
        else if (!fromPanel) designer.add(itemId, tile)
        moved = false
    }
    onCanceled: {
        if (moved) designer.cancel()
        moved = false
    }
}
