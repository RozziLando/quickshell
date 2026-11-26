import QtQuick
import qs.services
import qs.widgets

Item {
    id: d

    function f(v) { return SettingsUi.u(v * 0.79) }

    property var grid: []
    property var lower: []
    property var gridPool: []
    property var bottomPool: []

    signal gridEdited(var list)
    signal bottomEdited(var list)
    signal widthsEdited(var map)

    readonly property int panelW: Math.min(f(436), width)
    readonly property int pad: f(14)
    readonly property int gap: f(10)
    readonly property int tileH: f(54)
    readonly property int innerW: panelW - 2 * pad
    readonly property int emptyH: f(44)
    readonly property real unit: (innerW + gap) / Controls.maxSlots

    width: parent ? parent.width : 0
    height: layoutColumn.implicitHeight

    property string dragId: ""
    property bool dragTile: true
    property bool dragFromPanel: false
    property real dragX: 0
    property real dragY: 0
    property real grabX: 0
    property real grabY: 0
    property real ghostW: 0
    property real ghostH: 0
    property string zone: ""
    property var target: null
    property int index: -1
    property string resizeId: ""
    property var resizeWidths: ({})
    property bool rejected: false
    property real frozenLower: 0
    readonly property var widths: resizeId !== "" ? resizeWidths : (Theme.controlWidths || {})
    readonly property bool dragGrid: dragId !== "" && Controls.isGrid(dragId)

    Timer {
        id: rejectTimer
        interval: 900
        onTriggered: d.rejected = false
    }
    function reject() {
        rejected = true
        rejectTimer.restart()
    }

    function heightOf(id) {
        if (Controls.isTile(id)) return tileH
        if (id === "notifications") return f(64)
        if (id === "search" || id === "apps") return f(44)
        return f(60)
    }

    function withSpans(list, widths) {
        return list.map(function (e) { return { id: e.id, row: e.row, col: e.col, span: Controls.spanOf(e.id, widths) } })
    }

    readonly property int maxRow: {
        var m = -1
        grid.forEach(function (e) { m = Math.max(m, e.row) })
        return m
    }
    readonly property int rowsShown: Math.min(Controls.maxRows, Math.max(1, maxRow + 2))
    readonly property var entries: withSpans(grid, widths)
    readonly property var geom: Controls.gridLayout(entries, innerW, gap, heightOf, rowsShown, tileH)

    readonly property var shownBottom: dragId !== "" && !dragGrid
        ? (zone === "bottom" ? inserted(lower, dragId, index) : without(lower, dragId)) : lower
    function bottomLayout(list) {
        var y = 0, out = {}
        list.forEach(function (id) {
            out[id] = { y: y, h: d.heightOf(id) }
            y += d.heightOf(id) + d.gap
        })
        out.total = Math.max(0, y - gap)
        return out
    }
    readonly property var bottomGeom: bottomLayout(shownBottom)
    readonly property var baseBottomGeom: bottomLayout(lower)

    function without(list, id) {
        return list.filter(function (x) { return x !== id })
    }

    function inserted(list, id, i) {
        var l = without(list, id)
        l.splice(Math.max(0, Math.min(i, l.length)), 0, id)
        return l
    }

    function cellsWithout(id) {
        var cells = {}
        entries.forEach(function (e) { if (e.id !== id) Controls.occupy(cells, e.row, e.col, e.span, e.id) })
        return cells
    }

    function rowAt(py) {
        var best = 0
        for (var r = 0; r < rowsShown; r++) {
            var y = geom.rows[r]
            if (y === undefined) continue
            if (py >= y - gap / 2) best = r
        }
        return best
    }

    function placeTarget(id, row, left) {
        var span = Controls.spanOf(id, widths)
        var col = Math.max(0, Math.min(Controls.maxSlots - span, Math.round(left / unit)))
        var cells = cellsWithout(id)
        if (Controls.fits(cells, row, col, span)) return { row: row, col: col, span: span, valid: true }
        for (var step = 1; step < Controls.maxSlots; step++) {
            for (var sgn = -1; sgn <= 1; sgn += 2) {
                var c = col + sgn * step
                if (c >= 0 && c + span <= Controls.maxSlots && Controls.fits(cells, row, c, span))
                    return { row: row, col: c, span: span, valid: true }
            }
        }
        return { row: row, col: col, span: span, valid: false }
    }

    function begin(id, tile, fromPanel, gx, gy, w, h) {
        dragId = id
        dragTile = tile
        dragFromPanel = fromPanel
        ghostW = Controls.isGrid(id) ? Controls.spanOf(id, widths) * unit - gap : innerW
        ghostH = heightOf(id)
        frozenLower = Math.max(emptyH, baseBottomGeom.total
            + (!Controls.isGrid(id) && !fromPanel ? heightOf(id) + (lower.length > 0 ? gap : 0) : 0))
        grabX = Math.min(gx, ghostW)
        grabY = Math.min(gy, ghostH)
    }

    function move(x, y) {
        dragX = x
        dragY = y
        var p = panel.mapFromItem(d, x, y)
        var tol = f(24)
        if (p.x < -tol || p.y < -tol || p.x > panel.width + tol || p.y > panel.height + tol) {
            zone = "out"
            target = null
            index = -1
            return
        }
        if (dragGrid) {
            var g = gridArea.mapFromItem(d, x - grabX, y - grabY + ghostH / 2)
            zone = "grid"
            target = placeTarget(dragId, rowAt(g.y), g.x)
        } else {
            var b = bottomArea.mapFromItem(d, x, y)
            var base = without(lower, dragId), lay = bottomLayout(base), n = 0
            base.forEach(function (id) { if (lay[id].y + lay[id].h / 2 < b.y) n++ })
            zone = "bottom"
            index = n
        }
    }

    function finish() {
        if (zone === "grid" && target) {
            if (target.valid) {
                var list = grid.filter(function (e) { return e.id !== d.dragId })
                    .map(function (e) { return { id: e.id, row: e.row, col: e.col } })
                list.push({ id: dragId, row: target.row, col: target.col })
                gridEdited(list)
            } else {
                reject()
            }
        } else if (zone === "bottom") {
            bottomEdited(inserted(lower, dragId, index))
        } else if (zone === "out" && dragFromPanel) {
            remove(dragId, dragTile)
        }
        cancel()
    }

    function cancel() {
        dragId = ""
        zone = ""
        target = null
        index = -1
    }

    function add(id, tile) {
        if (Controls.isGrid(id)) {
            var spot = Controls.firstFree(entries, id, widths)
            if (!spot) {
                reject()
                return
            }
            var list = grid.map(function (e) { return { id: e.id, row: e.row, col: e.col } })
            list.push({ id: id, row: spot.row, col: spot.col })
            gridEdited(list)
        } else {
            bottomEdited(lower.concat([id]))
        }
    }

    function remove(id, tile) {
        if (Controls.isGrid(id))
            gridEdited(grid.filter(function (e) { return e.id !== id })
                .map(function (e) { return { id: e.id, row: e.row, col: e.col } }))
        else bottomEdited(without(lower, id))
    }

    function beginResize(id) {
        var m = {}, src = Theme.controlWidths || {}
        for (var k in src) m[k] = src[k]
        resizeWidths = m
        resizeId = id
    }

    function resizeTo(id, right) {
        var e = null
        grid.forEach(function (x) { if (x.id === id) e = x })
        if (!e) return
        var limit = Controls.maxSlots - e.col
        grid.forEach(function (x) {
            if (x.id !== id && x.row === e.row && x.col > e.col) limit = Math.min(limit, x.col - e.col)
        })
        var slots = Math.round((right - e.col * unit + gap) / unit)
        slots = Math.max(Controls.minSpan(id), Math.min(limit, slots))
        if (Controls.spanOf(id, resizeWidths) === slots) return
        var m = {}
        for (var k in resizeWidths) m[k] = resizeWidths[k]
        if (slots === Controls.defaultSpan(id)) delete m[id]
        else m[id] = slots
        resizeWidths = m
    }

    function endResize() {
        if (resizeId === "") return
        var m = resizeWidths
        resizeId = ""
        widthsEdited(m)
    }

    Column {
        id: layoutColumn
        width: parent.width
        spacing: SettingsUi.u(8)

        Rectangle {
            id: panel
            anchors.horizontalCenter: parent.horizontalCenter
            width: d.panelW
            height: d.pad + d.geom.total + d.gap + bottomArea.height + d.pad
            radius: Theme.radius + d.pad * Theme.roundness
            color: Theme.panel
            border.width: d.rejected ? 2 : 1
            border.color: d.rejected ? Theme.warning : d.dragId !== "" && d.zone !== "out" ? Theme.accent : Theme.border
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Item {
                id: gridArea
                x: d.pad
                y: d.pad
                width: d.innerW
                height: d.geom.total

                Repeater {
                    model: d.rowsShown * Controls.maxSlots
                    delegate: Rectangle {
                        required property int index
                        readonly property int row: Math.floor(index / Controls.maxSlots)
                        readonly property int col: index % Controls.maxSlots
                        x: col * d.unit
                        y: d.geom.rows[row] !== undefined ? d.geom.rows[row] : 0
                        width: d.unit - d.gap
                        height: d.geom.heights[row] !== undefined ? d.geom.heights[row] : d.tileH
                        radius: Math.min(Theme.radius, width / 2)
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.cardBorder
                        opacity: d.dragGrid || d.resizeId !== "" ? 0.9 : 0.35
                        Behavior on opacity { NumberAnimation { duration: 140 } }
                    }
                }

                Rectangle {
                    readonly property var t: d.target
                    visible: d.zone === "grid" && t !== null
                    x: t ? t.col * d.unit : 0
                    y: t && d.geom.rows[t.row] !== undefined ? d.geom.rows[t.row] : 0
                    width: t ? t.span * d.unit - d.gap : 0
                    height: t && d.geom.heights[t.row] !== undefined ? d.geom.heights[t.row] : d.tileH
                    radius: Math.min(Theme.radius, height / 2)
                    color: "transparent"
                    border.width: 2
                    border.color: t && t.valid ? Theme.accent : Theme.warning
                }

                Repeater {
                    model: Controls.gridOrder
                    delegate: CCPiece {
                        id: piece
                        required property string modelData
                        readonly property var g: d.geom[modelData]
                        kind: modelData
                        tile: Controls.isTile(modelData)
                        outline: grip.containsMouse || sizer.containsMouse || sizer.pressed
                        visible: g !== undefined
                        x: g ? g.x : 0
                        y: g ? g.y : 0
                        width: g ? g.w : 0
                        height: g ? g.h : 0
                        opacity: modelData === d.dragId ? 0.35 : 1
                        Behavior on width {
                            enabled: d.resizeId !== ""
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }

                        DragGrip {
                            id: grip
                            designer: d
                            itemId: piece.modelData
                            tile: piece.tile
                            fromPanel: true
                        }

                        RemoveBadge {
                            active: (grip.containsMouse || sizer.containsMouse) && d.dragId === "" && d.resizeId === ""
                            onClicked: d.remove(piece.modelData, piece.tile)
                        }

                        MouseArea {
                            id: sizer
                            readonly property bool can: Controls.resizable.indexOf(piece.modelData) >= 0
                            visible: can && d.dragId === ""
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: d.f(14)
                            hoverEnabled: true
                            preventStealing: true
                            cursorShape: Qt.SizeHorCursor
                            onPressed: d.beginResize(piece.modelData)
                            onPositionChanged: mouse => {
                                if (!pressed) return
                                var p = mapToItem(gridArea, mouse.x, mouse.y)
                                d.resizeTo(piece.modelData, p.x)
                            }
                            onReleased: d.endResize()
                            onCanceled: d.endResize()

                            Rectangle {
                                anchors.centerIn: parent
                                width: d.f(4)
                                height: Math.min(d.f(22), parent.height * 0.5)
                                radius: Theme.round(width)
                                color: sizer.pressed ? Theme.accent : Theme.textMuted
                                opacity: sizer.containsMouse || sizer.pressed || grip.containsMouse ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 140 } }
                            }
                        }
                    }
                }
            }

            Item {
                id: bottomArea
                x: d.pad
                y: d.pad + d.geom.total + d.gap
                width: d.innerW
                height: d.dragId !== "" ? Math.max(d.frozenLower, d.bottomGeom.total) : Math.max(d.emptyH, d.bottomGeom.total)

                Rectangle {
                    anchors.fill: parent
                    visible: d.shownBottom.length === 0
                    radius: Theme.radius
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.cardBorder

                    Text {
                        anchors.centerIn: parent
                        text: "Lists go here"
                        color: Theme.textMuted
                        font.pixelSize: d.f(11)
                        font.family: Theme.fontFamily
                    }
                }

                Repeater {
                    model: Controls.bottomOrder
                    delegate: CCPiece {
                        id: lowerPiece
                        required property string modelData
                        readonly property bool held: modelData === d.dragId && d.dragFromPanel
                        readonly property var g: d.bottomGeom[modelData] || (held ? d.baseBottomGeom[modelData] : undefined)
                        kind: modelData
                        tile: false
                        visible: g !== undefined
                        y: g ? g.y : 0
                        width: d.innerW
                        height: g ? g.h : 0
                        opacity: modelData !== d.dragId ? 1 : d.bottomGeom[modelData] ? 0.35 : 0
                        Behavior on y {
                            enabled: d.dragId !== ""
                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }

                        DragGrip {
                            id: lowerGrip
                            designer: d
                            itemId: lowerPiece.modelData
                            tile: false
                            fromPanel: true
                        }

                        RemoveBadge {
                            active: lowerGrip.containsMouse && d.dragId === ""
                            onClicked: d.remove(lowerPiece.modelData, false)
                        }
                    }
                }
            }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: d.rejected ? "No room there"
                : d.dragId !== "" && d.zone === "out" && d.dragFromPanel ? "Release to remove"
                : d.resizeId !== "" ? "Sliders: 3–6 places, clock: 2–6"
                : "Drag items in or out. Drag the right edge of a slider or the clock to resize it"
            color: d.rejected ? Theme.warning : Theme.textMuted
            font.pixelSize: SettingsUi.u(9)
            font.family: Theme.fontFamily
            wrapMode: Text.WordWrap
        }

        Rectangle {
            visible: d.gridPool.length > 0 || d.bottomPool.length > 0
            width: parent.width
            height: poolColumn.implicitHeight + 2 * SettingsUi.u(12)
            radius: SettingsUi.radius
            color: Theme.card
            border.width: 1
            border.color: Theme.cardBorder

            Column {
                id: poolColumn
                x: SettingsUi.u(12)
                y: SettingsUi.u(12)
                width: parent.width - 2 * SettingsUi.u(12)
                spacing: SettingsUi.u(8)

                Text {
                    visible: d.gridPool.length > 0
                    text: "Top"
                    color: Theme.textSecondary
                    font.pixelSize: SettingsUi.u(10)
                    font.weight: Font.DemiBold
                    font.family: Theme.fontFamily
                }

                Flow {
                    visible: d.gridPool.length > 0
                    width: parent.width
                    spacing: d.gap

                    Repeater {
                        model: d.gridPool
                        delegate: CCPiece {
                            id: poolItem
                            required property string modelData
                            kind: modelData
                            tile: Controls.isTile(modelData)
                            outline: true
                            width: tile ? implicitWidth : Math.min(d.f(200), parent.width)
                            opacity: modelData === d.dragId ? 0.35 : 1

                            DragGrip {
                                designer: d
                                itemId: poolItem.modelData
                                tile: poolItem.tile
                            }
                        }
                    }
                }

                Text {
                    visible: d.bottomPool.length > 0
                    text: "Bottom"
                    color: Theme.textSecondary
                    font.pixelSize: SettingsUi.u(10)
                    font.weight: Font.DemiBold
                    font.family: Theme.fontFamily
                }

                Flow {
                    visible: d.bottomPool.length > 0
                    width: parent.width
                    spacing: d.gap

                    Repeater {
                        model: d.bottomPool
                        delegate: CCPiece {
                            id: poolLower
                            required property string modelData
                            kind: modelData
                            tile: false
                            width: Math.min(d.f(260), (parent.width - d.gap) / 2)
                            opacity: modelData === d.dragId ? 0.35 : 1

                            DragGrip {
                                designer: d
                                itemId: poolLower.modelData
                                tile: false
                            }
                        }
                    }
                }
            }
        }
    }

    CCPiece {
        visible: d.dragId !== ""
        z: 100
        kind: d.dragId
        tile: d.dragTile
        outline: true
        x: d.dragX - d.grabX
        y: d.dragY - d.grabY
        width: d.ghostW
        height: d.ghostH
        opacity: 0.92
        scale: 1.04
    }
}
