import QtQuick
import qs.services

Item {
    id: root
    required property var displayPage
    property real sizeFactor: 1.0
    function u(value) { return Theme.s(value * sizeFactor) }

    height: canvas.height

    property var layout: []
    property bool edited: false

    function logicalSize(m) {
        var w = m.scale > 0 ? Math.round(m.width / m.scale) : m.width
        var h = m.scale > 0 ? Math.round(m.height / m.scale) : m.height
        return m.transform % 2 === 1 ? { w: h, h: w } : { w: w, h: h }
    }

    function reset() {
        layout = displayPage.monitors.filter(function (m) {
            return !m.disabled && displayPage.mirrorOf(m) === ""
        }).map(function (m) {
            var s = logicalSize(m)
            return { name: m.name, label: displayPage.isInternal(m) ? "Built-in" : m.name,
                     internal: displayPage.isInternal(m), x: m.x, y: m.y, w: s.w, h: s.h }
        })
        edited = false
    }
    Component.onCompleted: reset()
    Connections {
        target: root.displayPage
        function onMonitorsChanged() { if (!root.edited) root.reset() }
    }

    function overlaps(a, b) {
        return a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y
    }

    function along(p, oStart, oLen, dLen, snapDist) {
        var minOverlap = Math.min(oLen, dLen) / 4
        p = Math.max(oStart - dLen + minOverlap, Math.min(oStart + oLen - minOverlap, p))
        var marks = [oStart, oStart + (oLen - dLen) / 2, oStart + oLen - dLen]
        for (var i = 0; i < marks.length; i++)
            if (Math.abs(p - marks[i]) <= snapDist) return Math.round(marks[i])
        return Math.round(p)
    }

    function snap(name, px, py) {
        var d = null, others = []
        layout.forEach(function (l) { if (l.name === name) d = l; else others.push(l) })
        if (!d || others.length === 0) return null
        var snapDist = u(12) / Math.max(0.0001, k)
        var best = null, bestDist = Infinity
        others.forEach(function (o) {
            var cands = [
                { x: o.x + o.w, y: along(py, o.y, o.h, d.h, snapDist) },
                { x: o.x - d.w, y: along(py, o.y, o.h, d.h, snapDist) },
                { x: along(px, o.x, o.w, d.w, snapDist), y: o.y + o.h },
                { x: along(px, o.x, o.w, d.w, snapDist), y: o.y - d.h }
            ]
            cands.forEach(function (c) {
                var box = { x: c.x, y: c.y, w: d.w, h: d.h }
                if (others.some(function (q) { return overlaps(box, q) })) return
                var dist = Math.hypot(c.x - px, c.y - py)
                if (dist < bestDist) { bestDist = dist; best = c }
            })
        })
        return best
    }

    function drop(name, px, py) {
        var p = snap(name, px, py)
        var next = layout.map(function (l) {
            var c = Object.assign({}, l)
            if (p && c.name === name) { c.x = p.x; c.y = p.y }
            return c
        })
        var mx = Math.min.apply(null, next.map(function (l) { return l.x }))
        var my = Math.min.apply(null, next.map(function (l) { return l.y }))
        next.forEach(function (l) { l.x -= mx; l.y -= my })
        layout = next
        edited = displayPage.monitors.some(function (m) {
            return next.some(function (l) { return l.name === m.name && (l.x !== m.x || l.y !== m.y) })
        })
    }

    function apply() {
        var specs = layout.map(function (l) {
            var m = displayPage.monitors.filter(function (x) { return x.name === l.name })[0]
            return displayPage.on(m, l.x + "x" + l.y)
        })
        edited = false
        displayPage.change(specs)
    }

    readonly property var bounds: {
        if (layout.length === 0) return { x: 0, y: 0, w: 1, h: 1 }
        var x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity
        layout.forEach(function (l) {
            x0 = Math.min(x0, l.x); y0 = Math.min(y0, l.y)
            x1 = Math.max(x1, l.x + l.w); y1 = Math.max(y1, l.y + l.h)
        })
        return { x: x0, y: y0, w: Math.max(1, x1 - x0), h: Math.max(1, y1 - y0) }
    }
    readonly property int pad: u(18)
    readonly property real k: Math.min((canvas.width - 2 * pad) / bounds.w,
                                       (canvas.height - 2 * pad - u(24)) / bounds.h)

    Rectangle {
        id: canvas
        width: parent.width
        height: root.u(140)
        radius: root.u(22)
        color: Theme.track
        clip: true

        readonly property real ox: (width - root.bounds.w * root.k) / 2
        readonly property real oy: (height - root.u(24) - root.bounds.h * root.k) / 2

        Repeater {
            model: root.layout
            delegate: Rectangle {
                id: box
                required property var modelData
                x: canvas.ox + (modelData.x - root.bounds.x) * root.k
                y: canvas.oy + (modelData.y - root.bounds.y) * root.k
                width: modelData.w * root.k
                height: modelData.h * root.k
                radius: root.u(6)
                color: area.drag.active ? Theme.accent : Theme.highlight
                border.width: 1
                border.color: modelData.internal ? Theme.accent : Theme.cardBorder
                z: area.drag.active ? 1 : 0

                Text {
                    anchors.centerIn: parent
                    width: parent.width - root.u(6)
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: box.modelData.label
                    color: area.drag.active ? Theme.background : Theme.text
                    font.pixelSize: root.u(9)
                    font.bold: true
                    font.family: Theme.fontFamily
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    preventStealing: true
                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    drag.target: box
                    drag.minimumX: 0
                    drag.minimumY: 0
                    drag.maximumX: canvas.width - box.width
                    drag.maximumY: canvas.height - box.height
                    property real startX: 0
                    property real startY: 0
                    onPressed: { startX = box.x; startY = box.y }
                    onReleased: {
                        if (Math.abs(box.x - startX) < 2 && Math.abs(box.y - startY) < 2) return
                        root.drop(box.modelData.name,
                                  (box.x - canvas.ox) / root.k + root.bounds.x,
                                  (box.y - canvas.oy) / root.k + root.bounds.y)
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.u(6)
            visible: !root.edited
            text: "Drag the displays to arrange them"
            color: Theme.textMuted
            font.pixelSize: root.u(9)
            font.family: Theme.fontFamily
        }

        Row {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: root.u(8)
            visible: root.edited
            spacing: root.u(6)
            z: 2

            Repeater {
                model: [
                    { label: "Reset", apply: false },
                    { label: "Apply", apply: true }
                ]
                delegate: Rectangle {
                    id: btn
                    required property var modelData
                    width: root.u(60)
                    height: root.u(22)
                    radius: height / 2
                    color: modelData.apply ? Theme.accent
                         : (btnArea.containsMouse ? Theme.surface : Theme.highlight)

                    Text {
                        anchors.centerIn: parent
                        text: btn.modelData.label
                        color: btn.modelData.apply ? Theme.background : Theme.text
                        font.pixelSize: root.u(10)
                        font.bold: true
                        font.family: Theme.fontFamily
                    }
                    MouseArea {
                        id: btnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: btn.modelData.apply ? root.apply() : root.reset()
                    }
                }
            }
        }
    }
}
