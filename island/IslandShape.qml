import QtQuick
import qs.services

// Forma dell'isola: attaccata al bordo alto dello schermo con due raccordi
// curvi (topRadius) e angoli arrotondati in basso (bottomRadius).
// Usata dalla pillola e dai quadratini ai lati.
Canvas {
    id: canvas

    property real topRadius: Theme.s(10)
    property real bottomRadius: Theme.s(15)
    // Bordo disegnato (false: niente bordo, si usa l'alone SoftGlow)
    property bool outline: true

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onTopRadiusChanged: requestPaint()
    onBottomRadiusChanged: requestPaint()
    onOutlineChanged: requestPaint()

    // Ridisegna se cambiano colori o scala da theme.json
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
        // Il raggio in basso non può superare metà del corpo
        var r_bottom = Math.min(bottomRadius, (w - 2 * r_top) / 2, h / 2);

        // Vetro: sfondo traslucido e bordo chiaro
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
