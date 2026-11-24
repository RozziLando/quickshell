import QtQuick
import qs.services

Canvas {
    id: canvas

    property string edge: "top"
    property real depth: Theme.s(38)
    property real ear: Theme.radius
    property real earStart: ear
    property real earEnd: ear
    property bool outline: true
    property color fill: Theme.panel

    onWidthChanged: requestPaint()
    onAvailableChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()
    onHeightChanged: requestPaint()
    onEdgeChanged: requestPaint()
    onDepthChanged: requestPaint()
    onEarStartChanged: requestPaint()
    onEarEndChanged: requestPaint()
    onOutlineChanged: requestPaint()
    onFillChanged: requestPaint()

    Connections {
        target: Theme
        function onGlassChanged() { canvas.requestPaint() }
        function onBorderChanged() { canvas.requestPaint() }
    }

    function frame(ctx) {
        var W = width, H = height
        if (edge === "bottom") {
            ctx.translate(0, H)
            ctx.scale(1, -1)
        } else if (edge === "left") {
            ctx.transform(0, 1, 1, 0, 0, 0)
        } else if (edge === "right") {
            ctx.transform(0, 1, -1, 0, W, 0)
        }
        return edge === "left" || edge === "right" ? H : W
    }

    function inner(ctx, L, t, rs, re, start) {
        if (start) ctx.moveTo(L, t + re)
        else ctx.lineTo(L, t + re)
        if (re > 0) ctx.arcTo(L, t, L - re, t, re)
        else ctx.lineTo(L, t)
        ctx.lineTo(rs, t)
        if (rs > 0) ctx.arcTo(0, t, 0, t + rs, rs)
        else ctx.lineTo(0, t)
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        if (width <= 0 || height <= 0) return
        ctx.save()
        var L = frame(ctx)
        var t = depth
        var rs = Math.max(0, Math.min(earStart, L / 4)), re = Math.max(0, Math.min(earEnd, L / 4))
        ctx.fillStyle = fill
        ctx.beginPath()
        ctx.moveTo(0, 0)
        ctx.lineTo(L, 0)
        inner(ctx, L, t, rs, re, false)
        ctx.closePath()
        ctx.fill()
        if (outline) {
            ctx.strokeStyle = Theme.border
            ctx.lineWidth = 1
            ctx.beginPath()
            inner(ctx, L, t, rs, re, true)
            ctx.stroke()
        }
        ctx.restore()
    }
}
