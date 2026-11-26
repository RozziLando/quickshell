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
                var out = { files: [] }
                text.split("\n").forEach(function (line) {
                    var tab = line.indexOf("\t")
                    if (tab <= 0) return
                    var key = line.substring(0, tab), value = line.substring(tab + 1).trim()
                    if (key === "logofile") out.files.push(value)
                    else out[key] = value
                })
                root.info = out
            }
        }
    }

    property int logoTry: 0
    property int wideTry: -1
    property bool allowWide: false
    property string cleanLogo: ""
    readonly property string firstSvg: {
        var f = info.files || []
        for (var i = 0; i < f.length; i++) if (/\.svg$/i.test(f[i])) return f[i]
        return ""
    }

    FileView {
        path: root.firstSvg
        printErrors: false
        onLoaded: root.cleanLogo = "data:image/svg+xml;charset=utf-8," + encodeURIComponent(root.withoutMarks(text()))
    }

    function withoutMarks(svg) {
        var vb = svg.match(/viewBox="\s*([-\d.]+)[\s,]+([-\d.]+)[\s,]+([-\d.]+)[\s,]+([-\d.]+)/)
        if (!vb) return svg
        var x0 = parseFloat(vb[1]), y0 = parseFloat(vb[2]), w = parseFloat(vb[3]), h = parseFloat(vb[4])
        function num(tag, name, size) {
            var v = (tag.match(new RegExp("\\s" + name + "=\"\\s*([-\\d.]+)(%?)")) || [])
            if (v.length < 2) return NaN
            return v[2] === "%" ? parseFloat(v[1]) / 100 * size : parseFloat(v[1])
        }
        var shapes = (svg.match(/<(path|circle|ellipse|polygon|rect)\b/g) || []).length
        var backdrop = /<(rect|circle)\b[^>]*?(\/>|>\s*<\/(rect|circle)>)/g
        var removed = 0
        svg = svg.replace(backdrop, function (tag) {
            if (shapes - removed <= 1) return tag
            var full = false
            if (/^<rect/.test(tag)) {
                var rx = num(tag, "x", w), ry = num(tag, "y", h)
                var rw = num(tag, "width", w), rh = num(tag, "height", h)
                full = rw >= 0.9 * w && rh >= 0.9 * h
                    && (isNaN(rx) || rx <= x0 + 0.05 * w) && (isNaN(ry) || ry <= y0 + 0.05 * h)
            } else {
                var r = num(tag, "r", Math.min(w, h))
                full = r >= 0.45 * Math.min(w, h)
            }
            if (!full) return tag
            removed++
            return ""
        })
        if (removed > 0) {
            svg = svg.replace(/(fill|stroke)(\s*[:=]\s*["']?)(#[0-9a-fA-F]{3,8}|rgba?\([^)]*\)|[a-zA-Z]+)/g,
                function (m, prop, sep, value) {
                    if (/^(none|transparent|currentColor|inherit|url)$/i.test(value)) return m
                    return prop + sep + "#000"
                })
        }
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
        var files = info.files || []
        files.forEach(function (f) {
            var url = Theme.fileUrl(f)
            if (out.indexOf(url) < 0) out.push(url)
        })
        var names = [info.logo || ""]
        if (info.osid) names.push(info.osid + "-logo", "distributor-logo-" + info.osid)
        names.forEach(function (name) {
            var icon = name !== "" ? Quickshell.iconPath(name, true) : ""
            if (icon !== "" && out.indexOf(icon) < 0) out.push(icon)
        })
        return out
    }
    onLogoSourcesChanged: {
        logoTry = 0
        wideTry = -1
        allowWide = false
    }

    function nextLogo() {
        if (logoTry + 1 < logoSources.length) {
            logoTry++
        } else if (wideTry >= 0 && !allowWide) {
            allowWide = true
            logoTry = wideTry
        } else {
            logoTry = logoSources.length
        }
    }

    Image {
        id: logo
        anchors.fill: parent
        source: root.logoTry < root.logoSources.length ? root.logoSources[root.logoTry] : ""
        sourceSize.width: Theme.px(width * 2, root)
        sourceSize.height: Theme.px(height * 2, root)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
        visible: false
        onStatusChanged: {
            if (status === Image.Error) {
                root.nextLogo()
            } else if (status === Image.Ready && !root.allowWide) {
                var w = implicitWidth, h = implicitHeight
                if (w > 0 && h > 0 && (w / h > 1.35 || h / w > 1.35)) {
                    if (root.wideTry < 0) root.wideTry = root.logoTry
                    root.nextLogo()
                }
            }
        }
    }

    ShaderEffect {
        x: (root.width - width) / 2
        y: (root.height - height) / 2
        width: logo.paintedWidth
        height: logo.paintedHeight
        visible: logo.status === Image.Ready && root.logoTry < root.logoSources.length
        property var source: logo
        property color tint: root.tint
        fragmentShader: Qt.resolvedUrl("shaders/logo.frag.qsb")
    }

    LineIcon {
        anchors.centerIn: parent
        visible: logo.status !== Image.Ready
        kind: "monitor"
        size: Math.round(Math.min(root.width, root.height) * 0.76)
        color: root.tint
    }
}
