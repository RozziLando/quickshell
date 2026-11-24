import QtQuick
import qs.services
import qs.widgets

Item {
    id: shape

    required property var stage
    property rect box: Qt.rect(0, 0, 0, 0)
    property bool flushStart: false
    property bool flushEnd: false
    property real radius: Theme.radius

    readonly property string side: stage.barEdge
    readonly property bool upright: side === "left" || side === "right"
    readonly property int f: stage.pillFillet
    readonly property int lead: flushStart ? 0 : f
    readonly property int tail: flushEnd ? 0 : f
    readonly property int e: flushStart || flushEnd ? f : 0
    readonly property real boxAlong: upright ? box.height : box.width
    readonly property real boxDepth: upright ? box.width : box.height
    readonly property real alongLen: lead + boxAlong + tail
    readonly property real depthLen: boxDepth + 1 + e
    readonly property real r: Math.max(0, Math.min(radius, boxAlong / 2, boxDepth / 2))

    x: upright ? (side === "left" ? box.x - 1 : box.x - e) : box.x - lead
    y: upright ? box.y - lead : (side === "top" ? box.y - 1 : box.y - e)
    width: upright ? depthLen : alongLen
    height: upright ? alongLen : depthLen

    function place(a, d, al, dl) {
        if (side === "top") return Qt.rect(a, d, al, dl)
        if (side === "bottom") return Qt.rect(a, depthLen - d - dl, al, dl)
        if (side === "left") return Qt.rect(d, a, dl, al)
        return Qt.rect(depthLen - d - dl, a, dl, al)
    }

    function corner(a, d) {
        var h, v
        if (side === "top" || side === "bottom") {
            h = a === "start" ? "l" : "r"
            v = (d === "edge") === (side === "top") ? "t" : "b"
        } else {
            v = a === "start" ? "t" : "b"
            h = (d === "edge") === (side === "left") ? "l" : "r"
        }
        return v + h
    }

    function bodyRadius(c) {
        var a, d
        if (side === "top" || side === "bottom") {
            a = c.charAt(1) === "l" ? "start" : "end"
            d = (c.charAt(0) === "t") === (side === "top") ? "edge" : "inner"
        } else {
            a = c.charAt(0) === "t" ? "start" : "end"
            d = (c.charAt(1) === "l") === (side === "left") ? "edge" : "inner"
        }
        if (d === "edge") return 0
        if (a === "start" && flushStart) return 0
        if (a === "end" && flushEnd) return 0
        return r
    }

    readonly property rect bodyRect: place(lead, 0, boxAlong, boxDepth + 1)

    Rectangle {
        x: shape.bodyRect.x
        y: shape.bodyRect.y
        width: shape.bodyRect.width
        height: shape.bodyRect.height
        color: Theme.panel
        topLeftRadius: shape.bodyRadius("tl")
        topRightRadius: shape.bodyRadius("tr")
        bottomLeftRadius: shape.bodyRadius("bl")
        bottomRightRadius: shape.bodyRadius("br")
    }

    Fillet {
        readonly property rect g: shape.place(0, 1, shape.f, shape.f)
        visible: !shape.flushStart && shape.f > 0
        x: g.x
        y: g.y
        size: shape.f
        corner: shape.corner("end", "edge")
    }
    Fillet {
        readonly property rect g: shape.place(shape.lead + shape.boxAlong, 1, shape.f, shape.f)
        visible: !shape.flushEnd && shape.f > 0
        x: g.x
        y: g.y
        size: shape.f
        corner: shape.corner("start", "edge")
    }
    Fillet {
        readonly property rect g: shape.place(0, shape.boxDepth + 1, shape.e, shape.e)
        visible: shape.flushStart && shape.e > 0
        x: g.x
        y: g.y
        size: shape.e
        corner: shape.corner("start", "edge")
    }
    Fillet {
        readonly property rect g: shape.place(shape.lead + shape.boxAlong - shape.e, shape.boxDepth + 1, shape.e, shape.e)
        visible: shape.flushEnd && shape.e > 0
        x: g.x
        y: g.y
        size: shape.e
        corner: shape.corner("end", "edge")
    }

    layer.enabled: Theme.glass && visible
    layer.effect: LiquidGlass {
        outside: Qt.vector4d(shape.side === "left" || (!shape.upright && shape.flushStart) ? 1 : 0,
                             shape.side === "top" || (shape.upright && shape.flushStart) ? 1 : 0,
                             shape.side === "right" || (!shape.upright && shape.flushEnd) ? 1 : 0,
                             shape.side === "bottom" || (shape.upright && shape.flushEnd) ? 1 : 0)
    }
}
