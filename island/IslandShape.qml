import QtQuick
import qs.services

Canvas {
    id: canvas

    property real topRadius: Theme.s(10)
    property real fillet: topRadius
    property real bottomRadius: Theme.s(15)
    property bool outline: true

    onWidthChanged: requestPaint()
    onAvailableChanged: requestPaint()
    onVisibleChanged: if (visible) requestPaint()
    onHeightChanged: requestPaint()
    onTopRadiusChanged: requestPaint()
    onFilletChanged: requestPaint()
    onBottomRadiusChanged: requestPaint()
    onOutlineChanged: requestPaint()

    Connections {
        target: Theme
        function onScaleChanged() { canvas.requestPaint() }
        function onPanelChanged() { canvas.requestPaint() }
        function onGlassChanged() { canvas.requestPaint() }
        function onBorderChanged() { canvas.requestPaint() }
    }

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();

        var w = width;
        var h = height;
        var r_top = topRadius;
        var r_bottom = Math.min(bottomRadius, (w - 2 * r_top) / 2, h / 2);

        ctx.fillStyle = Theme.panel;
        ctx.strokeStyle = Theme.border;
        ctx.lineWidth = 1;

        var f = Math.max(0, Math.min(fillet, r_top));

        ctx.beginPath();
        ctx.moveTo(r_top - f, 0);
        if (f > 0) ctx.arcTo(r_top, 0, r_top, h, f);
        else ctx.lineTo(r_top, 0);
        ctx.lineTo(r_top, h - r_bottom);
        if (r_bottom > 0) ctx.arcTo(r_top, h, w - r_top, h, r_bottom);
        else ctx.lineTo(r_top, h);
        ctx.lineTo(w - r_top - r_bottom, h);
        if (r_bottom > 0) ctx.arcTo(w - r_top, h, w - r_top, 0, r_bottom);
        else ctx.lineTo(w - r_top, h);
        ctx.lineTo(w - r_top, f);
        if (f > 0) ctx.arcTo(w - r_top, 0, w - r_top + f, 0, f);
        else ctx.lineTo(w - r_top, 0);
        ctx.lineTo(w - r_top + f, 0);
        ctx.closePath();

        ctx.fill();
        if (outline) ctx.stroke();
    }
}
