import QtQuick
import qs.services

Canvas {
    id: canvas

    property string edge: "top"
    property real fillet: Theme.s(10)
    property real filletStart: fillet
    property real filletEnd: fillet
    property real radius: Theme.radius
    property real radiusStart: radius
    property real radiusEnd: radius
    property real ear: 0
    property bool earStart: false
    property bool earEnd: false
    property bool outline: true
    property bool flare: false
    property color fill: Theme.panel

    onWidthChanged: requestPaint()
    onAvailableChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()
    onHeightChanged: requestPaint()
    onEdgeChanged: requestPaint()
    onFilletStartChanged: requestPaint()
    onFilletEndChanged: requestPaint()
    onRadiusStartChanged: requestPaint()
    onRadiusEndChanged: requestPaint()
    onEarChanged: requestPaint()
    onEarStartChanged: requestPaint()
    onEarEndChanged: requestPaint()
    onOutlineChanged: requestPaint()
    onFlareChanged: requestPaint()
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
        return edge === "left" || edge === "right" ? { L: H, D: W } : { L: W, D: H }
    }

    function body(ctx, L, D, closed) {
        var e = earStart || earEnd ? Math.max(0, ear) : 0
        var B = D - e
        var fs = Math.max(0, Math.min(filletStart, L / 4))
        var fe = Math.max(0, Math.min(filletEnd, L / 4))
        var es = earStart ? e : 0, ee = earEnd ? e : 0
        var rs = earStart ? 0 : Math.max(0, Math.min(radiusStart, (L - fs - fe) / 2, B))
        var re = earEnd ? 0 : Math.max(0, Math.min(radiusEnd, (L - fs - fe) / 2, B))
        var ds = flare ? Math.min(fs * 0.8, B - rs) : fs
        var de = flare ? Math.min(fe * 0.8, B - re) : fe

        ctx.beginPath()
        ctx.moveTo(0, 0)
        if (fs > 0 && flare) ctx.bezierCurveTo(fs * 0.62, 0, fs, ds * 0.32, fs, ds)
        else if (fs > 0) ctx.arcTo(fs, 0, fs, B, fs)

        if (es > 0) {
            if (closed) ctx.lineTo(fs, B + es)
            else ctx.moveTo(fs, B + es)
            ctx.arcTo(fs, B, fs + es, B, es)
        } else {
            ctx.lineTo(fs, B - rs)
            if (rs > 0) ctx.arcTo(fs, B, L - fe, B, rs)
            else ctx.lineTo(fs, B)
        }

        if (ee > 0) {
            ctx.lineTo(L - fe - ee, B)
            ctx.arcTo(L - fe, B, L - fe, B + ee, ee)
            if (!closed) return
            ctx.lineTo(L - fe, de)
        } else {
            ctx.lineTo(L - fe - re, B)
            if (re > 0) ctx.arcTo(L - fe, B, L - fe, 0, re)
            else ctx.lineTo(L - fe, B)
            ctx.lineTo(L - fe, de)
        }

        if (fe > 0 && flare) ctx.bezierCurveTo(L - fe, de * 0.32, L - fe * 0.62, 0, L, 0)
        else if (fe > 0) ctx.arcTo(L - fe, 0, L, 0, fe)
        else ctx.lineTo(L, 0)
        if (closed) ctx.closePath()
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        if (width <= 0 || height <= 0) return
        ctx.save()
        var size = frame(ctx)
        ctx.fillStyle = fill
        body(ctx, size.L, size.D, true)
        ctx.fill()
        if (outline) {
            ctx.strokeStyle = Theme.border
            ctx.lineWidth = 1
            body(ctx, size.L, size.D, false)
            ctx.stroke()
        }
        ctx.restore()
    }
}
