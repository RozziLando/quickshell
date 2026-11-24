import QtQuick
import qs.services
import qs.widgets

Item {
    id: d

    function f(v) { return SettingsUi.u(v * 0.79) }

    property var tiles: []
    property var sections: []
    property var tilePool: []
    property var sectionPool: []

    signal tilesEdited(var list)
    signal sectionsEdited(var list)

    readonly property int panelW: Math.min(f(436), width)
    readonly property int pad: f(14)
    readonly property int gap: f(10)
    readonly property int tileH: f(54)
    readonly property int circle: f(48)
    readonly property int innerW: panelW - 2 * pad
    readonly property int emptyH: f(44)

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
    property int index: -1
    property bool overfull: false

    function without(list, id) {
        return list.filter(function (x) { return x !== id })
    }

    function inserted(list, id, i) {
        var l = without(list, id)
        l.splice(Math.max(0, Math.min(i, l.length)), 0, id)
        return l
    }

    function sectionHeight(id) {
        if (id === "notifications") return f(64)
        if (id === "search" || id === "apps") return f(44)
        return f(60)
    }

    readonly property var shownTiles: dragId !== "" && dragTile
        ? (zone === "tiles" && !overfull ? inserted(tiles, dragId, index) : without(tiles, dragId)) : tiles
    readonly property var shownSections: dragId !== "" && !dragTile
        ? (zone === "sections" ? inserted(sections, dragId, index) : without(sections, dragId)) : sections

    function tileLayout(list) {
        var wide = list.filter(function (id) { return Controls.tileInfo[id].slots === 2 }).length
        var circles = list.length - wide
        var tileW = wide > 0 ? (innerW - circles * circle - (list.length - 1) * gap) / wide : 0
        var used = wide > 0 ? innerW : circles * circle + Math.max(0, circles - 1) * gap
        var x = (innerW - used) / 2, out = {}
        list.forEach(function (id) {
            var w = Controls.tileInfo[id].slots === 2 ? tileW : circle
            out[id] = { x: x, w: w }
            x += w + d.gap
        })
        return out
    }

    function sectionLayout(list) {
        var y = 0, out = {}
        list.forEach(function (id) {
            var h = d.sectionHeight(id)
            out[id] = { y: y, h: h }
            y += h + d.gap
        })
        out.total = Math.max(0, y - gap)
        return out
    }

    readonly property var tileGeom: tileLayout(shownTiles)
    readonly property var sectionGeom: sectionLayout(shownSections)
    readonly property var baseTileGeom: tileLayout(tiles)
    readonly property var baseSectionGeom: sectionLayout(sections)

    function begin(id, tile, fromPanel, gx, gy, w, h) {
        rejectTimer.stop()
        dragId = id
        dragTile = tile
        dragFromPanel = fromPanel
        grabX = gx
        grabY = gy
        ghostW = w
        ghostH = h
    }

    function move(x, y) {
        dragX = x
        dragY = y
        var p = panel.mapFromItem(d, x, y)
        var tol = f(24)
        if (p.x < -tol || p.y < -tol || p.x > panel.width + tol || p.y > panel.height + tol) {
            zone = "out"
            index = -1
            overfull = false
            return
        }
        if (dragTile) {
            var base = without(tiles, dragId), lay = tileLayout(base), n = 0
            var lx = p.x - pad
            base.forEach(function (id) { if (lay[id].x + lay[id].w / 2 < lx) n++ })
            zone = "tiles"
            index = n
            overfull = Controls.slotsOf(inserted(tiles, dragId, n)) > Controls.maxSlots
        } else {
            var sbase = without(sections, dragId), slay = sectionLayout(sbase), m = 0
            var ly = p.y - sectionArea.y
            sbase.forEach(function (id) { if (slay[id].y + slay[id].h / 2 < ly) m++ })
            zone = "sections"
            index = m
            overfull = false
        }
    }

    function finish() {
        if (zone === "tiles" && dragTile && !overfull) tilesEdited(inserted(tiles, dragId, index))
        else if (zone === "sections" && !dragTile) sectionsEdited(inserted(sections, dragId, index))
        else if (zone === "out" && dragFromPanel) {
            if (dragTile) tilesEdited(without(tiles, dragId))
            else sectionsEdited(without(sections, dragId))
        } else if (overfull) rejectTimer.restart()
        cancel()
    }

    function cancel() {
        dragId = ""
        zone = ""
        index = -1
        overfull = false
    }

    function add(id, tile) {
        if (tile) {
            var next = tiles.concat([id])
            if (Controls.slotsOf(next) > Controls.maxSlots) {
                rejectTimer.restart()
                return
            }
            tilesEdited(next)
        } else {
            sectionsEdited(sections.concat([id]))
        }
    }

    function remove(id, tile) {
        if (tile) tilesEdited(without(tiles, id))
        else sectionsEdited(without(sections, id))
    }

    Timer {
        id: rejectTimer
        interval: 800
    }

    Column {
        id: layoutColumn
        width: parent.width
        spacing: SettingsUi.u(8)

        Rectangle {
            id: panel
            anchors.horizontalCenter: parent.horizontalCenter
            width: d.panelW
            height: d.pad + d.tileH + d.gap + Math.max(d.emptyH, d.sectionGeom.total) + d.pad
            radius: Theme.radius + d.pad * Theme.roundness
            color: Theme.panel
            border.width: d.overfull || rejectTimer.running ? 2 : 1
            border.color: d.overfull || rejectTimer.running ? Theme.warning
                        : d.dragId !== "" && d.zone !== "out" ? Theme.accent : Theme.border
            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Item {
                id: tileRow
                x: d.pad
                y: d.pad
                width: d.innerW
                height: d.tileH

                Rectangle {
                    anchors.fill: parent
                    visible: d.shownTiles.length === 0
                    radius: Math.min(Theme.radius, height / 2)
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.cardBorder

                    Text {
                        anchors.centerIn: parent
                        text: "Drag buttons here"
                        color: Theme.textMuted
                        font.pixelSize: d.f(11)
                        font.family: Theme.fontFamily
                    }
                }

                Repeater {
                    model: Controls.tileOrder
                    delegate: CCPiece {
                        id: tilePiece
                        required property string modelData
                        readonly property bool held: modelData === d.dragId && d.dragFromPanel
                        readonly property var g: d.tileGeom[modelData] || (held ? d.baseTileGeom[modelData] : undefined)
                        kind: modelData
                        tile: true
                        visible: g !== undefined
                        x: g ? g.x : 0
                        width: g ? g.w : 0
                        height: d.tileH
                        opacity: modelData !== d.dragId ? 1 : d.tileGeom[modelData] ? 0.35 : 0
                        Behavior on x {
                            enabled: d.dragId !== ""
                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }

                        DragGrip {
                            id: tileGrip
                            designer: d
                            itemId: tilePiece.modelData
                            tile: true
                            fromPanel: true
                        }

                        RemoveBadge {
                            active: tileGrip.containsMouse && d.dragId === ""
                            onClicked: d.remove(tilePiece.modelData, true)
                        }
                    }
                }
            }

            Item {
                id: sectionArea
                x: d.pad
                y: d.pad + d.tileH + d.gap
                width: d.innerW
                height: Math.max(d.emptyH, d.sectionGeom.total)

                Rectangle {
                    anchors.fill: parent
                    visible: d.shownSections.length === 0
                    radius: Theme.radius
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.cardBorder

                    Text {
                        anchors.centerIn: parent
                        text: "Drag sections here"
                        color: Theme.textMuted
                        font.pixelSize: d.f(11)
                        font.family: Theme.fontFamily
                    }
                }

                Repeater {
                    model: Controls.sectionOrder
                    delegate: CCPiece {
                        id: sectionPiece
                        required property string modelData
                        readonly property bool held: modelData === d.dragId && d.dragFromPanel
                        readonly property var g: d.sectionGeom[modelData] || (held ? d.baseSectionGeom[modelData] : undefined)
                        kind: modelData
                        tile: false
                        visible: g !== undefined
                        y: g ? g.y : 0
                        width: d.innerW
                        height: g ? g.h : 0
                        opacity: modelData !== d.dragId ? 1 : d.sectionGeom[modelData] ? 0.35 : 0
                        Behavior on y {
                            enabled: d.dragId !== ""
                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }

                        DragGrip {
                            id: sectionGrip
                            designer: d
                            itemId: sectionPiece.modelData
                            tile: false
                            fromPanel: true
                        }

                        RemoveBadge {
                            active: sectionGrip.containsMouse && d.dragId === ""
                            onClicked: d.remove(sectionPiece.modelData, false)
                        }
                    }
                }
            }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: d.dragId !== "" && d.zone === "out" && d.dragFromPanel ? "Release to remove"
                : rejectTimer.running || d.overfull ? "No room: the top row holds six places, Wi-Fi and Bluetooth take two"
                : "Drag items into the control center, drag them out to remove them"
            color: rejectTimer.running || d.overfull ? Theme.warning : Theme.textMuted
            font.pixelSize: SettingsUi.u(9)
            font.family: Theme.fontFamily
            wrapMode: Text.WordWrap
        }

        Rectangle {
            visible: d.tilePool.length > 0 || d.sectionPool.length > 0
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
                    visible: d.tilePool.length > 0
                    text: "Buttons"
                    color: Theme.textSecondary
                    font.pixelSize: SettingsUi.u(10)
                    font.weight: Font.DemiBold
                    font.family: Theme.fontFamily
                }

                Flow {
                    visible: d.tilePool.length > 0
                    width: parent.width
                    spacing: d.gap

                    Repeater {
                        model: d.tilePool
                        delegate: CCPiece {
                            id: poolTile
                            required property string modelData
                            kind: modelData
                            tile: true
                            opacity: modelData === d.dragId ? 0.35 : 1

                            DragGrip {
                                designer: d
                                itemId: poolTile.modelData
                                tile: true
                            }
                        }
                    }
                }

                Text {
                    visible: d.sectionPool.length > 0
                    text: "Sections"
                    color: Theme.textSecondary
                    font.pixelSize: SettingsUi.u(10)
                    font.weight: Font.DemiBold
                    font.family: Theme.fontFamily
                }

                Flow {
                    visible: d.sectionPool.length > 0
                    width: parent.width
                    spacing: d.gap

                    Repeater {
                        model: d.sectionPool
                        delegate: CCPiece {
                            id: poolSection
                            required property string modelData
                            kind: modelData
                            tile: false
                            width: Math.min(d.f(260), (parent.width - d.gap) / 2)
                            opacity: modelData === d.dragId ? 0.35 : 1

                            DragGrip {
                                designer: d
                                itemId: poolSection.modelData
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
        x: d.dragX - d.grabX
        y: d.dragY - d.grabY
        width: d.ghostW
        height: d.ghostH
        opacity: 0.92
        scale: 1.04
    }
}
