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
        onStatusChanged: if (status === Image.Error) root.logoTry++
    }

    ShaderEffect {
        x: (root.width - width) / 2
        y: (root.height - height) / 2
        width: logo.paintedWidth
        height: logo.paintedHeight
        visible: logo.status === Image.Ready
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
