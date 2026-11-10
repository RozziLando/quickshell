import QtQuick
import qs.services

Canvas {
    id: root
    property string kind: ""
    property color color: Theme.text
    property int size: Theme.s(20)
    property int level: -1

    width: size
    height: size

    readonly property string glyph: Icons.glyph(kind, level)
    onGlyphChanged: requestPaint()

    Text {
        anchors.centerIn: parent
        visible: root.glyph !== ""
        text: root.glyph
        color: root.color
        font.family: Icons.family
        font.pixelSize: root.size
        renderType: Text.QtRendering
    }

    onKindChanged: requestPaint()
    onLevelChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        if (root.glyph !== "") return
        ctx.scale(width / 24, height / 24)

        var c = color.toString()
        ctx.strokeStyle = c
        ctx.fillStyle = c
        ctx.lineWidth = 2
        ctx.lineCap = "round"
        ctx.lineJoin = "round"

        var i, a

        switch (kind) {
        case "wifi":
            for (i = 0; i < 3; i++) {
                ctx.globalAlpha = (level < 0 || i < level) ? 1 : 0.2
                ctx.beginPath(); ctx.arc(12, 19, 5.5 + 4 * i, 1.25 * Math.PI, 1.75 * Math.PI); ctx.stroke()
            }
            ctx.globalAlpha = 1
            ctx.beginPath(); ctx.arc(12, 19.5, 1.4, 0, 2 * Math.PI); ctx.fill()
            break

        case "bluetooth":
            ctx.beginPath()
            ctx.moveTo(7, 7); ctx.lineTo(17, 17); ctx.lineTo(12, 22)
            ctx.lineTo(12, 2); ctx.lineTo(17, 7); ctx.lineTo(7, 17)
            ctx.stroke()
            break

        case "screenshot":
            ctx.beginPath(); ctx.moveTo(4, 9); ctx.lineTo(4, 4); ctx.lineTo(9, 4); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(15, 4); ctx.lineTo(20, 4); ctx.lineTo(20, 9); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(20, 15); ctx.lineTo(20, 20); ctx.lineTo(15, 20); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(9, 20); ctx.lineTo(4, 20); ctx.lineTo(4, 15); ctx.stroke()
            ctx.beginPath(); ctx.arc(12, 12, 2.5, 0, 2 * Math.PI); ctx.stroke()
            break

        case "power":
            ctx.beginPath(); ctx.arc(12, 12.5, 8, -0.22 * Math.PI, 1.22 * Math.PI, false); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(12, 3); ctx.lineTo(12, 12); ctx.stroke()
            break

        case "volume":
        case "volume-low":
        case "volume-mute":
            ctx.beginPath()
            ctx.moveTo(4, 9); ctx.lineTo(8, 9); ctx.lineTo(13, 5)
            ctx.lineTo(13, 19); ctx.lineTo(8, 15); ctx.lineTo(4, 15)
            ctx.closePath(); ctx.fill()
            if (kind === "volume" || kind === "volume-low") {
                ctx.beginPath(); ctx.arc(13, 12, 4.5, -0.3 * Math.PI, 0.3 * Math.PI); ctx.stroke()
                if (kind === "volume") {
                    ctx.beginPath(); ctx.arc(13, 12, 8, -0.34 * Math.PI, 0.34 * Math.PI); ctx.stroke()
                }
            } else {
                ctx.beginPath(); ctx.moveTo(16.5, 9.5); ctx.lineTo(21.5, 14.5); ctx.stroke()
                ctx.beginPath(); ctx.moveTo(21.5, 9.5); ctx.lineTo(16.5, 14.5); ctx.stroke()
            }
            break

        case "sun":
            ctx.beginPath(); ctx.arc(12, 12, 4, 0, 2 * Math.PI); ctx.stroke()
            for (i = 0; i < 8; i++) {
                a = i * Math.PI / 4
                ctx.beginPath()
                ctx.moveTo(12 + Math.cos(a) * 7.5, 12 + Math.sin(a) * 7.5)
                ctx.lineTo(12 + Math.cos(a) * 10, 12 + Math.sin(a) * 10)
                ctx.stroke()
            }
            break

        case "keyboard":
            ctx.beginPath(); ctx.rect(2.5, 6.5, 19, 11); ctx.stroke()
            for (i = 0; i < 4; i++)
                ctx.fillRect(5.2 + i * 4.4, 9.4, 1.8, 1.8)
            ctx.beginPath(); ctx.moveTo(7, 14.5); ctx.lineTo(17, 14.5); ctx.stroke()
            break

        case "search":
            ctx.beginPath(); ctx.arc(10.5, 10.5, 6.5, 0, 2 * Math.PI); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(15.3, 15.3); ctx.lineTo(20.5, 20.5); ctx.stroke()
            break

        case "chevron":
            ctx.beginPath(); ctx.moveTo(9, 5); ctx.lineTo(16, 12); ctx.lineTo(9, 19); ctx.stroke()
            break

        case "play":
            ctx.beginPath(); ctx.moveTo(7, 4.5); ctx.lineTo(19, 12); ctx.lineTo(7, 19.5)
            ctx.closePath(); ctx.fill(); ctx.stroke()
            break

        case "pause":
            ctx.fillRect(6, 5, 4, 14)
            ctx.fillRect(14, 5, 4, 14)
            break

        case "next":
        case "previous":
            if (kind === "previous") { ctx.translate(24, 0); ctx.scale(-1, 1) }
            ctx.beginPath(); ctx.moveTo(5, 5.5); ctx.lineTo(15, 12); ctx.lineTo(5, 18.5)
            ctx.closePath(); ctx.fill(); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(19, 5.5); ctx.lineTo(19, 18.5); ctx.stroke()
            break

        case "ethernet":
            ctx.beginPath(); ctx.rect(9, 3, 6, 5); ctx.stroke()
            ctx.beginPath(); ctx.rect(3, 16, 6, 5); ctx.stroke()
            ctx.beginPath(); ctx.rect(15, 16, 6, 5); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(12, 8); ctx.lineTo(12, 12); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(6, 16); ctx.lineTo(6, 12); ctx.lineTo(18, 12)
            ctx.lineTo(18, 16); ctx.stroke()
            break

        case "back":
            ctx.beginPath(); ctx.moveTo(15, 5); ctx.lineTo(8, 12); ctx.lineTo(15, 19); ctx.stroke()
            break

        case "lock":
            ctx.beginPath(); ctx.rect(5, 11, 14, 10); ctx.stroke()
            ctx.beginPath(); ctx.arc(12, 11, 4.5, Math.PI, 2 * Math.PI); ctx.stroke()
            break

        case "mic":
            ctx.beginPath(); ctx.moveTo(9, 6); ctx.lineTo(9, 12); ctx.arc(12, 12, 3, Math.PI, 0, true)
            ctx.lineTo(15, 6); ctx.arc(12, 6, 3, 0, Math.PI, true); ctx.stroke()
            ctx.beginPath(); ctx.arc(12, 12, 6.5, 0, Math.PI); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(12, 18.5); ctx.lineTo(12, 21.5); ctx.stroke()
            break

        case "check":
            ctx.beginPath(); ctx.moveTo(5, 12.5); ctx.lineTo(10, 17.5); ctx.lineTo(19, 7); ctx.stroke()
            break

        case "app":
            ctx.beginPath(); ctx.rect(4, 4, 16, 16); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(4, 9); ctx.lineTo(20, 9); ctx.stroke()
            break

        case "monitor":
            ctx.beginPath(); ctx.rect(3, 4, 18, 12); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(12, 16); ctx.lineTo(12, 20); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(8, 20); ctx.lineTo(16, 20); ctx.stroke()
            break

        case "laptop":
            ctx.beginPath(); ctx.rect(5, 5, 14, 10); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(2.5, 19); ctx.lineTo(21.5, 19); ctx.stroke()
            break

        case "extend":
            ctx.beginPath(); ctx.rect(2, 6, 9, 9); ctx.stroke()
            ctx.beginPath(); ctx.rect(13, 6, 9, 9); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(6.5, 15); ctx.lineTo(6.5, 18.5); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(17.5, 15); ctx.lineTo(17.5, 18.5); ctx.stroke()
            break

        case "mirror":
            ctx.beginPath(); ctx.rect(7, 3, 14, 10); ctx.stroke()
            ctx.beginPath(); ctx.rect(3, 9, 14, 10); ctx.fill()
            ctx.globalCompositeOperation = "destination-out"
            ctx.beginPath(); ctx.rect(5, 11, 10, 6); ctx.fill()
            ctx.globalCompositeOperation = "source-over"
            break

        case "sleep":
            ctx.beginPath()
            ctx.arc(12, 12, 8, 0.3 * Math.PI, 1.7 * Math.PI, false)
            ctx.arc(15.5, 9, 6, 1.5 * Math.PI, 0.55 * Math.PI, true)
            ctx.closePath(); ctx.stroke()
            break

        case "reboot":
            ctx.beginPath(); ctx.arc(12, 12, 7.5, -0.35 * Math.PI, 1.45 * Math.PI, false); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(14.5, 2.8); ctx.lineTo(18.6, 4.9); ctx.lineTo(16.3, 8.8); ctx.stroke()
            break

        case "grid":
            ctx.beginPath(); ctx.rect(4, 4, 6.5, 6.5); ctx.stroke()
            ctx.beginPath(); ctx.rect(13.5, 4, 6.5, 6.5); ctx.stroke()
            ctx.beginPath(); ctx.rect(4, 13.5, 6.5, 6.5); ctx.stroke()
            ctx.beginPath(); ctx.rect(13.5, 13.5, 6.5, 6.5); ctx.stroke()
            break

        case "file":
            ctx.beginPath(); ctx.moveTo(6, 3); ctx.lineTo(14, 3); ctx.lineTo(19, 8)
            ctx.lineTo(19, 21); ctx.lineTo(6, 21); ctx.closePath(); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(14, 3); ctx.lineTo(14, 8); ctx.lineTo(19, 8); ctx.stroke()
            break

        case "folder":
            ctx.beginPath(); ctx.moveTo(3, 6); ctx.lineTo(9, 6); ctx.lineTo(11, 8.5)
            ctx.lineTo(21, 8.5); ctx.lineTo(21, 19); ctx.lineTo(3, 19); ctx.closePath(); ctx.stroke()
            break

        case "terminal":
            ctx.beginPath(); ctx.moveTo(5, 7); ctx.lineTo(10, 12); ctx.lineTo(5, 17); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(12, 17); ctx.lineTo(19, 17); ctx.stroke()
            break

        case "headphones":
            ctx.beginPath(); ctx.arc(12, 13, 8, Math.PI, 2 * Math.PI); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(4, 13); ctx.lineTo(4, 18); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(20, 13); ctx.lineTo(20, 18); ctx.stroke()
            ctx.fillRect(3, 14, 4.5, 6.5)
            ctx.fillRect(16.5, 14, 4.5, 6.5)
            break

        case "palette":
            ctx.beginPath()
            ctx.arc(12, 12, 9, 0.15 * Math.PI, 1.85 * Math.PI)
            ctx.quadraticCurveTo(17, 11, 18.5, 13.5)
            ctx.quadraticCurveTo(19.5, 16, 20.6, 14.8)
            ctx.stroke()
            ctx.beginPath(); ctx.arc(8, 10, 1.4, 0, 2 * Math.PI); ctx.fill()
            ctx.beginPath(); ctx.arc(12, 7, 1.4, 0, 2 * Math.PI); ctx.fill()
            ctx.beginPath(); ctx.arc(9, 15, 1.4, 0, 2 * Math.PI); ctx.fill()
            break
        case "cpu":
            ctx.beginPath(); ctx.roundedRect(6, 6, 12, 12, 2, 2); ctx.stroke()
            ctx.fillRect(9.5, 9.5, 5, 5)
            for (i = 0; i < 3; i++) {
                a = 9 + 3 * i
                ctx.beginPath()
                ctx.moveTo(a, 2.5); ctx.lineTo(a, 6)
                ctx.moveTo(a, 18); ctx.lineTo(a, 21.5)
                ctx.moveTo(2.5, a); ctx.lineTo(6, a)
                ctx.moveTo(18, a); ctx.lineTo(21.5, a)
                ctx.stroke()
            }
            break
        case "close":
            ctx.beginPath(); ctx.moveTo(6, 6); ctx.lineTo(18, 18); ctx.stroke()
            ctx.beginPath(); ctx.moveTo(18, 6); ctx.lineTo(6, 18); ctx.stroke()
            break
        }
    }
}
