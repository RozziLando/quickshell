import QtQuick
import qs.services
import qs.widgets

Item {
    id: d

    property var lists: ({ start: [], center: [], end: [] })
    property var pool: []
    property bool pills: false
    property bool dividers: pills
    readonly property var zones: ["start", "center", "end"]
    readonly property var names: Theme.barVertical ? ["Top", "Center", "Bottom"] : ["Left", "Center", "Right"]

    signal edited(var lists)

    width: parent ? parent.width : 0
    height: column.implicitHeight

    readonly property int barH: SettingsUi.u(40)
    readonly property int pad: SettingsUi.u(10)
    readonly property int gap: SettingsUi.u(2)

    function itemWidth(id) {
        if (Controls.isSplit(id)) return d.dividers ? SettingsUi.u(14) : 0
        if (id === "clock") return SettingsUi.u(62)
        if (id === "workspaces") return SettingsUi.u(58)
        return SettingsUi.u(34)
    }

    property string dragId: ""
    property bool dragFromBar: false
    property real dragX: 0
    property real dragY: 0
    property real grabX: 0
    property real grabY: 0
    property string zone: ""
    property int index: -1

    function without(list, id) {
        return list.filter(function (x) { return x !== id })
    }

    function strip(l, id) {
        return { start: without(l.start, id), center: without(l.center, id), end: without(l.end, id) }
    }

    function placed(l, id, z, i) {
        var out = strip(l, id)
        out[z].splice(Math.max(0, Math.min(i, out[z].length)), 0, id)
        return out
    }

    readonly property var preview: dragId === "" ? lists
        : zone !== "" && zone !== "out" ? placed(lists, dragId, zone, index) : strip(lists, dragId)

    function zoneWidth(list) {
        var w = 0
        list.forEach(function (id) { w += d.itemWidth(id) })
        return w + Math.max(0, list.length - 1) * gap
    }

    function layout(l) {
        var W = mock.width, out = {}
        var x = pad
        l.start.forEach(function (id) { out[id] = { x: x, w: d.itemWidth(id), zone: "start" }; x += d.itemWidth(id) + d.gap })
        x = (W - zoneWidth(l.center)) / 2
        l.center.forEach(function (id) { out[id] = { x: x, w: d.itemWidth(id), zone: "center" }; x += d.itemWidth(id) + d.gap })
        x = W - pad - zoneWidth(l.end)
        l.end.forEach(function (id) { out[id] = { x: x, w: d.itemWidth(id), zone: "end" }; x += d.itemWidth(id) + d.gap })
        return out
    }

    readonly property var splitIds: {
        var out = []
        d.zones.forEach(function (z) { d.lists[z].forEach(function (id) { if (Controls.isSplit(id)) out.push(id) }) })
        if (Controls.isSplit(d.dragId) && out.indexOf(d.dragId) < 0) out.push(d.dragId)
        return out
    }

    readonly property string freshSplit: {
        var n = 0
        d.zones.forEach(function (z) {
            d.lists[z].forEach(function (id) {
                if (Controls.isSplit(id)) n = Math.max(n, parseInt(id.substring(5)))
            })
        })
        return "split" + (n + 1)
    }

    readonly property var pillRects: {
        if (!d.pills) return []
        var out = [], l = d.preview, g = d.geom
        d.zones.forEach(function (z) {
            var cur = null
            l[z].forEach(function (id) {
                if (Controls.isSplit(id)) {
                    if (!d.dividers) return
                    if (cur) out.push(cur)
                    cur = null
                    return
                }
                var r = g[id]
                if (!r) return
                if (!cur) cur = { x: r.x, r: r.x + r.w, zone: z }
                else cur.r = r.x + r.w
            })
            if (cur) out.push(cur)
        })
        return out
    }

    readonly property var geom: layout(preview)
    readonly property var baseGeom: layout(lists)

    function begin(id, tile, fromBar, gx, gy, w, h) {
        dragId = id
        dragFromBar = fromBar
        grabX = gx
        grabY = gy
    }

    function move(x, y) {
        dragX = x
        dragY = y
        var p = mock.mapFromItem(d, x, y)
        var tol = SettingsUi.u(26)
        if (p.x < -tol || p.y < -tol || p.x > mock.width + tol || p.y > mock.height + tol) {
            zone = "out"
            index = -1
            return
        }
        var z = p.x < mock.width / 3 ? "start" : p.x < 2 * mock.width / 3 ? "center" : "end"
        var base = strip(lists, dragId), lay = layout(base), n = 0
        base[z].forEach(function (id) { if (lay[id].x + lay[id].w / 2 < p.x) n++ })
        zone = z
        index = n
    }

    function finish() {
        if (zone !== "" && zone !== "out") edited(placed(lists, dragId, zone, index))
        else if (zone === "out" && dragFromBar) edited(strip(lists, dragId))
        cancel()
    }

    function cancel() {
        dragId = ""
        zone = ""
        index = -1
    }

    function add(id) {
        var out = strip(lists, id)
        out.end.push(id)
        edited(out)
    }

    function remove(id) {
        edited(strip(lists, id))
    }

    component BarGlyph: Item {
        id: glyph
        property string kind: ""

        Rectangle {
            anchors.centerIn: parent
            visible: Controls.isSplit(glyph.kind)
            width: SettingsUi.u(2)
            height: SettingsUi.u(18)
            radius: width / 2
            color: Theme.textMuted
        }
        LineIcon {
            anchors.centerIn: parent
            visible: ["clock", "workspaces", "logo", "audio", "sysmon"].indexOf(glyph.kind) < 0 && !Controls.isSplit(glyph.kind)
            kind: ({
                "search": "search", "themes": "palette", "power": "power", "display": "sun",
                "bluetooth": "bluetooth", "network": Controls.hasWifi ? "wifi" : "ethernet",
                "notifications": "bell"
            })[glyph.kind] || ""
            size: SettingsUi.u(15)
            color: Theme.text
        }
        LineIcon {
            anchors.centerIn: parent
            visible: glyph.kind === "audio" || glyph.kind === "sysmon"
            kind: glyph.kind === "audio" ? "volume" : "cpu"
            size: SettingsUi.u(15)
            color: Theme.text
        }
        Text {
            anchors.centerIn: parent
            visible: glyph.kind === "clock"
            text: "21:40"
            color: Theme.text
            font.pixelSize: SettingsUi.u(12)
            font.bold: true
            font.family: Theme.fontFamily
        }
        Row {
            anchors.centerIn: parent
            visible: glyph.kind === "workspaces"
            spacing: SettingsUi.u(4)
            Repeater {
                model: 4
                delegate: Rectangle {
                    required property int index
                    width: index === 1 ? SettingsUi.u(12) : SettingsUi.u(6)
                    height: SettingsUi.u(6)
                    radius: Theme.round(height)
                    color: index === 1 ? Theme.accent : Theme.textMuted
                }
            }
        }
        Loader {
            anchors.centerIn: parent
            active: glyph.kind === "logo"
            sourceComponent: DistroLogo {
                width: SettingsUi.u(18)
                height: SettingsUi.u(18)
            }
        }
    }

    Column {
        id: column
        width: parent.width
        spacing: SettingsUi.u(8)

        Item {
            width: parent.width
            height: d.barH + SettingsUi.u(18)

            Rectangle {
                id: mock
                y: SettingsUi.u(18)
                width: parent.width
                height: d.barH
                radius: Theme.barStyle === "floating" || d.pills ? Math.min(Theme.radius, height / 2)
                      : Math.min(Theme.radius, height / 2) / 2
                readonly property bool bare: d.pills || Theme.barStyle === "transparent"
                color: bare ? "transparent" : Theme.panel
                border.width: d.dragId !== "" && d.zone !== "out" ? 2 : 1
                border.color: d.dragId !== "" && d.zone !== "out" ? Theme.accent : bare ? Theme.cardBorder : Theme.border

                Repeater {
                    model: d.pillRects
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool joined: Theme.barStyle === "pillsAttached"
                        readonly property bool flushStart: joined && modelData.zone === "start"
                        readonly property bool flushEnd: joined && modelData.zone === "end"
                        x: flushStart ? 0 : modelData.x - SettingsUi.u(4)
                        y: joined ? 0 : SettingsUi.u(4)
                        width: (flushEnd ? mock.width : modelData.r + SettingsUi.u(4)) - x
                        height: mock.height - (joined ? SettingsUi.u(4) : SettingsUi.u(8))
                        radius: joined ? Math.min(Theme.radius, height / 2) : Theme.round(height)
                        topLeftRadius: joined ? (flushStart ? mock.radius : 0) : radius
                        topRightRadius: joined ? (flushEnd ? mock.radius : 0) : radius
                        bottomLeftRadius: joined && flushStart ? 0 : radius
                        bottomRightRadius: joined && flushEnd ? 0 : radius
                        color: Theme.panel
                        border.width: 1
                        border.color: Theme.border
                        Behavior on x { enabled: d.dragId !== ""; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on width { enabled: d.dragId !== ""; NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    }
                }

                Repeater {
                    model: 3
                    delegate: Rectangle {
                        required property int index
                        visible: d.dragId !== ""
                        x: index * mock.width / 3 + SettingsUi.u(3)
                        y: SettingsUi.u(3)
                        width: mock.width / 3 - SettingsUi.u(6)
                        height: mock.height - SettingsUi.u(6)
                        radius: Math.min(Theme.radius, height / 2)
                        color: d.zone === d.zones[index] ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14) : "transparent"
                        border.width: 1
                        border.color: d.zone === d.zones[index] ? Theme.accent : Theme.cardBorder
                    }
                }

                Repeater {
                    model: Controls.barKinds.concat(d.splitIds)
                    delegate: Item {
                        id: barPiece
                        required property string modelData
                        readonly property bool held: modelData === d.dragId && d.dragFromBar
                        readonly property var g: d.geom[modelData] || (held ? d.baseGeom[modelData] : undefined)
                        visible: g !== undefined && (d.dividers || !Controls.isSplit(modelData))
                        x: g ? g.x : 0
                        width: g ? g.w : 0
                        height: mock.height
                        opacity: modelData !== d.dragId ? 1 : d.geom[modelData] ? 0.35 : 0
                        Behavior on x {
                            enabled: d.dragId !== ""
                            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: SettingsUi.u(6)
                            anchors.bottomMargin: SettingsUi.u(6)
                            radius: Math.min(Theme.radius, height / 2)
                            color: Theme.highlight
                            opacity: barGrip.containsMouse && d.dragId === "" ? 1 : 0
                        }

                        BarGlyph {
                            anchors.fill: parent
                            kind: barPiece.modelData
                        }

                        DragGrip {
                            id: barGrip
                            designer: d
                            itemId: barPiece.modelData
                            fromPanel: true
                        }

                        RemoveBadge {
                            y: SettingsUi.u(1)
                            active: barGrip.containsMouse && d.dragId === ""
                            onClicked: d.remove(barPiece.modelData)
                        }
                    }
                }
            }

            Repeater {
                model: 3
                delegate: Text {
                    required property int index
                    x: index === 0 ? SettingsUi.u(4) : index === 1 ? (parent.width - width) / 2 : parent.width - width - SettingsUi.u(4)
                    text: d.names[index]
                    color: d.zone === d.zones[index] ? Theme.accent : Theme.textMuted
                    font.pixelSize: SettingsUi.u(9)
                    font.family: Theme.fontFamily
                }
            }
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: d.dragId !== "" && d.zone === "out" && d.dragFromBar ? "Release to remove"
                : d.dividers ? "Drag items into the bar; a divider starts a new pill"
                : "Drag items into the bar, drag them out to remove them"
            color: Theme.textMuted
            font.pixelSize: SettingsUi.u(9)
            font.family: Theme.fontFamily
        }

        Rectangle {
            visible: d.pool.length > 0 || d.dividers
            width: parent.width
            height: poolFlow.implicitHeight + 2 * SettingsUi.u(10)
            radius: SettingsUi.radius
            color: Theme.card
            border.width: 1
            border.color: Theme.cardBorder

            Flow {
                id: poolFlow
                x: SettingsUi.u(10)
                y: SettingsUi.u(10)
                width: parent.width - 2 * SettingsUi.u(10)
                spacing: SettingsUi.u(6)

                Rectangle {
                    id: splitChip
                    visible: d.dividers
                    width: splitRow.implicitWidth + 2 * SettingsUi.u(12)
                    height: SettingsUi.u(32)
                    radius: Math.min(Theme.radius, height / 2)
                    color: splitGrip.containsMouse ? Theme.surface : Theme.highlight
                    opacity: d.dragId === d.freshSplit ? 0.35 : 1

                    Row {
                        id: splitRow
                        anchors.centerIn: parent
                        spacing: SettingsUi.u(6)
                        BarGlyph {
                            anchors.verticalCenter: parent.verticalCenter
                            width: SettingsUi.u(10)
                            height: SettingsUi.u(18)
                            kind: d.freshSplit
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "New pill"
                            color: Theme.text
                            font.pixelSize: SettingsUi.u(10)
                            font.family: Theme.fontFamily
                        }
                    }

                    DragGrip {
                        id: splitGrip
                        designer: d
                        itemId: d.freshSplit
                    }
                }

                Repeater {
                    model: d.pool
                    delegate: Rectangle {
                        id: chip
                        required property string modelData
                        width: chipRow.implicitWidth + 2 * SettingsUi.u(12)
                        height: SettingsUi.u(32)
                        radius: Math.min(Theme.radius, height / 2)
                        color: poolGrip.containsMouse ? Theme.surface : Theme.highlight
                        opacity: modelData === d.dragId ? 0.35 : 1

                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: SettingsUi.u(6)
                            BarGlyph {
                                anchors.verticalCenter: parent.verticalCenter
                                width: chip.modelData === "clock" || chip.modelData === "workspaces" ? SettingsUi.u(48) : SettingsUi.u(18)
                                height: SettingsUi.u(18)
                                kind: chip.modelData
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: (Controls.barInfo[chip.modelData] || {}).label || chip.modelData
                                color: Theme.text
                                font.pixelSize: SettingsUi.u(10)
                                font.family: Theme.fontFamily
                            }
                        }

                        DragGrip {
                            id: poolGrip
                            designer: d
                            itemId: chip.modelData
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        visible: d.dragId !== ""
        z: 100
        x: d.dragX - width / 2
        y: d.dragY - height / 2
        width: d.dragId !== "" ? d.itemWidth(d.dragId) : 0
        height: d.barH - SettingsUi.u(8)
        radius: Math.min(Theme.radius, height / 2)
        color: Theme.panel
        border.width: 1
        border.color: Theme.accent
        opacity: 0.95

        BarGlyph {
            anchors.fill: parent
            kind: d.dragId
        }
    }
}
