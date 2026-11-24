import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Item {
    id: root

    property color tint: Theme.accent
    property var info: ({})

    Process {
        running: true
        command: ["sh", Quickshell.shellPath("scripts/sysinfo.sh"), Quickshell.shellDir, "logo"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = {}
                text.split("\n").forEach(function (line) {
                    var tab = line.indexOf("\t")
                    if (tab > 0) out[line.substring(0, tab)] = line.substring(tab + 1).trim()
                })
                root.info = out
            }
        }
    }

    property int logoTry: 0
    property string cleanLogo: ""

    FileView {
        path: root.info.logofile && /\.svg$/i.test(root.info.logofile) ? root.info.logofile : ""
        printErrors: false
        onLoaded: root.cleanLogo = "data:image/svg+xml;charset=utf-8," + encodeURIComponent(root.withoutMarks(text()))
    }

    function withoutMarks(svg) {
        var vb = svg.match(/viewBox="\s*([-\d.]+)[\s,]+([-\d.]+)[\s,]+([-\d.]+)[\s,]+([-\d.]+)/)
        if (!vb) return svg
        var x0 = parseFloat(vb[1]), y0 = parseFloat(vb[2]), w = parseFloat(vb[3]), h = parseFloat(vb[4])
        return svg.replace(/<path\b[^>]*\/>/g, function (tag) {
            var d = (tag.match(/\sd="([^"]*)"/) || [])[1] || ""
            var m = d.match(/^\s*[mM]\s*([-\d.]+)[\s,]+([-\d.]+)/)
            if (!m || d.length > 400) return tag
            var x = parseFloat(m[1]), y = parseFloat(m[2])
            return x > x0 + 0.85 * w && y > y0 + 0.75 * h ? "" : tag
        })
    }

    readonly property var logoSources: {
        var out = []
        if (cleanLogo !== "") out.push(cleanLogo)
        if (info.logofile) out.push(Theme.fileUrl(info.logofile))
        var names = [info.logo || ""]
        if (info.osid) names.push(info.osid + "-logo", "distributor-logo-" + info.osid)
        names.forEach(function (name) {
            var icon = name !== "" ? Quickshell.iconPath(name, true) : ""
            if (icon !== "" && out.indexOf(icon) < 0) out.push(icon)
        })
        return out
    }
    onLogoSourcesChanged: logoTry = 0

    readonly property int supersample: Math.max(2, Math.min(4, Math.ceil(128 / Math.max(1, Math.min(width, height)))))

    Image {
        id: logo
        anchors.fill: parent
        source: root.logoTry < root.logoSources.length ? root.logoSources[root.logoTry] : ""
        sourceSize.width: Theme.px(width * root.supersample, root)
        sourceSize.height: Theme.px(height * root.supersample, root)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        visible: false
        onStatusChanged: {
            if (status === Image.Error) root.logoTry++
            else if (status === Image.Ready) logoCanvas.prepare()
            else logoCanvas.requestPaint()
        }
    }

    Canvas {
        id: logoCanvas
        width: root.width * root.supersample
        height: root.height * root.supersample
        scale: 1 / root.supersample
        transformOrigin: Item.TopLeft
        layer.enabled: true
        layer.smooth: true
        layer.mipmap: true
        renderTarget: Canvas.Image
        renderStrategy: Canvas.Immediate
        property string loaded: ""
        property color tint: root.tint
        onTintChanged: requestPaint()
        onImageLoaded: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        readonly property string key: Math.random().toString(36).slice(2, 10)

        function prepare() {
            if (logo.status !== Image.Ready) return
            var src = String(logo.source)
            var url = src.indexOf("data:") === 0 ? src + "#" + key
                    : src + (src.indexOf("?") >= 0 ? "&" : "?") + "k=" + key
            if (url !== loaded) {
                if (loaded !== "") unloadImage(loaded)
                loaded = url
            }
            if (isImageLoaded(url)) requestPaint()
            else loadImage(url)
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            if (logo.status !== Image.Ready || loaded === "" || !isImageLoaded(loaded)) return
            var iw = logo.implicitWidth, ih = logo.implicitHeight
            if (iw <= 0 || ih <= 0) return
            var k = Math.min(width / iw, height / ih)
            var dw = Math.round(iw * k), dh = Math.round(ih * k)
            ctx.drawImage(loaded, Math.round((width - dw) / 2), Math.round((height - dh) / 2), dw, dh)
            var img = ctx.getImageData(0, 0, width, height)
            var w = img.width, h = img.height, d = img.data, alpha = [], i
            for (i = 0; i < d.length; i += 4) {
                var mx = Math.max(d[i], d[i + 1], d[i + 2]), mn = Math.min(d[i], d[i + 1], d[i + 2])
                var light = Math.max(0, Math.min(1, (mx / 255 - 0.72) / 0.2))
                var plain = 1 - Math.max(0, Math.min(1, ((mx > 0 ? (mx - mn) / mx : 0) - 0.12) / 0.2))
                alpha.push(Math.round(d[i + 3] * (1 - light * plain) / 255 * 48) / 48)
            }
            ctx.clearRect(0, 0, width, height)
            for (var y = 0; y < h; y++) {
                var x = 0
                while (x < w) {
                    var av = alpha[y * w + x], x2 = x + 1
                    while (x2 < w && alpha[y * w + x2] === av) x2++
                    if (av > 0) {
                        ctx.fillStyle = Qt.rgba(tint.r, tint.g, tint.b, av)
                        ctx.fillRect(x, y, x2 - x, 1)
                    }
                    x = x2
                }
            }
        }
    }

    LineIcon {
        anchors.centerIn: parent
        visible: logo.status !== Image.Ready
        kind: "monitor"
        size: Math.round(Math.min(root.width, root.height) * 0.76)
        color: root.tint
    }
}
