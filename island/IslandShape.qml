import QtQuick
import qs.services

Canvas {
    id: canvas

    property real topRadius: Theme.s(10)
    property real bottomRadius: Theme.s(15)
    property bool outline: true

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onTopRadiusChanged: requestPaint()
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
        ctx.strokeStyle = Theme.glass ? Theme.glassEdge : Theme.border;
        ctx.lineWidth = 1;

        ctx.beginPath();
        ctx.moveTo(0, 0);
        ctx.arcTo(r_top, 0, r_top, h, r_top);
        ctx.lineTo(r_top, h - r_bottom);
        ctx.arcTo(r_top, h, w - r_top, h, r_bottom);
        ctx.lineTo(w - r_top - r_bottom, h);
        ctx.arcTo(w - r_top, h, w - r_top, 0, r_bottom);
        ctx.lineTo(w - r_top, r_top);
        ctx.arcTo(w - r_top, 0, w, 0, r_top);
        ctx.lineTo(w, 0);
        ctx.closePath();

        ctx.fill();
        if (outline) ctx.stroke();
    }
}
