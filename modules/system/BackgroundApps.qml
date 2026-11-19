import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.services
import qs.widgets

Rectangle {
    id: root

    property real sizeFactor: 1.0
    function u(value) { return Theme.s(value * sizeFactor) }

    property bool active: false
    readonly property bool wanted: Theme.backgroundApps
    property bool expanded: false
    property var apps: []
    property var appMap: ({})
    property var appKeys: []
    property string signature: ""
    property bool refreshQueued: false

    readonly property int pad: u(8)
    readonly property int headerH: u(30)

    visible: wanted && apps.length > 0
    width: parent ? parent.width : 0
    height: visible ? content.implicitHeight + 2 * pad : 0
    radius: u(16)
    color: Theme.card
    border.width: 1
    border.color: Theme.cardBorder

    onActiveChanged: {
        if (active && wanted) refresh()
        else expanded = false
    }
    onWantedChanged: {
        if (wanted && active) refresh()
        else expanded = false
    }

    function refresh() {
        if (listProc.running) refreshQueued = true
        else listProc.running = true
    }

    function appInfo(cls) {
        var entry = DesktopEntries.heuristicLookup(cls)
        var icon = ""
        if (entry && entry.icon) icon = Quickshell.iconPath(entry.icon, true)
        if (icon === "") icon = Quickshell.iconPath(cls, true)
        if (icon === "") icon = Quickshell.iconPath(cls.toLowerCase(), true)
        return { name: entry && entry.name ? entry.name : cls, icon: icon }
    }

    Process {
        id: listProc
        command: ["hyprctl", "-j", "clients"]
        onRunningChanged: {
            if (!running && root.refreshQueued) {
                root.refreshQueued = false
                running = true
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                var clients
                try { clients = JSON.parse(text) } catch (e) { return }
                var groups = {}, order = []
                clients.forEach(function (c) {
                    var cls = c["class"] || c.initialClass || ""
                    if (cls === "" || !(c.pid > 1)) return
                    var key = cls.toLowerCase()
                    if (!groups[key]) {
                        var info = root.appInfo(cls)
                        groups[key] = { key: key, name: info.name, icon: info.icon, pids: [], titles: [],
                                        focus: "", focusRank: -1 }
                        order.push(key)
                    }
                    var g = groups[key]
                    if (g.pids.indexOf(c.pid) < 0) g.pids.push(c.pid)
                    g.titles.push(c.title || "")
                    var rank = c.focusHistoryID >= 0 ? c.focusHistoryID : 1e6
                    if (g.focus === "" || rank < g.focusRank) {
                        g.focus = c.address
                        g.focusRank = rank
                    }
                })
                var out = order.map(function (k) {
                    var g = groups[k]
                    g.subtitle = g.titles.length > 1 ? g.titles.length + " windows" : g.titles[0]
                    return g
                })
                out.sort(function (a, b) { return a.name.localeCompare(b.name) })
                var sig = JSON.stringify(out)
                if (sig === root.signature) return
                root.signature = sig
                var map = {}
                out.forEach(function (a) { map[a.key] = a })
                root.appMap = map
                root.apps = out
                root.appKeys = out.map(function (a) { return a.key })
                if (out.length === 0) root.expanded = false
            }
        }
    }

    Connections {
        target: Hyprland
        enabled: root.active && root.wanted
        function onRawEvent(event) {
            var n = event.name
            if (n === "openwindow" || n === "closewindow" || n === "windowtitlev2"
                || n === "movewindowv2" || n === "changefloatingmode")
                if (!refreshLater.running) refreshLater.start()
        }
    }

    Timer {
        id: refreshLater
        interval: 150
        onTriggered: root.refresh()
    }

    function focusApp(app) {
        if (app.focus === "") return
        if (Hyprland.usingLua)
            Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.focus({ window = "address:' + app.focus + '" })'])
        else
            Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + app.focus])
    }

    function quit(app) {
        Quickshell.execDetached(["sh", "-c",
            'desc() { for c in $(pgrep -P "$1"); do echo "$c"; desc "$c"; done; };'
            + ' keep=" 1 ";'
            + ' for q in $(pgrep -x quickshell) $(pgrep -x Hyprland) $$; do a=$q;'
            + '  while [ "${a:-1}" -gt 1 ]; do keep="$keep$a "; a=$(ps -o ppid= -p "$a" | tr -d " "); done;'
            + ' done;'
            + ' all="";'
            + ' for p in "$@"; do for x in "$p" $(desc "$p"); do'
            + '  case "$keep" in *" $x "*) ;; *) all="$all $x";; esac;'
            + ' done; done;'
            + ' [ -n "$all" ] || exit 0;'
            + ' kill -TERM $all 2>/dev/null;'
            + ' i=0; while [ $i -lt 30 ]; do alive="";'
            + '  for x in $all; do kill -0 "$x" 2>/dev/null && alive="$alive $x"; done;'
            + '  [ -z "$alive" ] && exit 0; sleep 0.1; i=$((i + 1));'
            + ' done;'
            + ' kill -KILL $alive 2>/dev/null',
            "sh"].concat(app.pids.map(String)))
        refreshLater.restart()
    }

    Column {
        id: content
        x: root.pad
        y: root.pad
        width: parent.width - 2 * root.pad
        spacing: root.u(6)

        Item {
            width: parent.width
            height: root.headerH

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = !root.expanded
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: root.u(6)
                anchors.verticalCenter: parent.verticalCenter
                text: "Background apps · " + root.apps.length
                color: Theme.textSecondary
                font.pixelSize: Theme.s(10)
                font.family: Theme.fontFamily
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: root.u(4)
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.u(6)

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: root.u(4)
                    opacity: root.expanded ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    Repeater {
                        model: ScriptModel { values: root.appKeys.slice(0, 3) }
                        delegate: Item {
                            required property string modelData
                            readonly property string icon: root.appMap[modelData] ? root.appMap[modelData].icon : ""
                            width: root.u(18)
                            height: width

                            IconImage {
                                id: smallIcon
                                anchors.centerIn: parent
                                visible: parent.icon !== ""
                                source: parent.icon
                                implicitSize: root.u(18)
                                backer.sourceSize.width: Theme.px(smallIcon.actualSize, smallIcon)
                                backer.sourceSize.height: Theme.px(smallIcon.actualSize, smallIcon)
                            }
                            LineIcon {
                                anchors.centerIn: parent
                                visible: parent.icon === ""
                                kind: "app"
                                size: root.u(14)
                                color: Theme.textSecondary
                            }
                        }
                    }
                }

                LineIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    kind: "chevron"
                    size: root.u(12)
                    color: Theme.textSecondary
                    rotation: root.expanded ? 90 : 0
                    Behavior on rotation { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }
            }
        }

        ListView {
            id: list
            readonly property int rowH: root.u(32) + 2 * root.u(8)
            visible: root.expanded
            width: parent.width
            height: count > 3 ? Math.round(3.5 * rowH + 3 * spacing)
                              : Math.max(0, count * rowH + (count - 1) * spacing)
            spacing: root.u(6)
            clip: true
            interactive: count > 3
            boundsBehavior: Flickable.StopAtBounds
            model: ScriptModel { values: root.expanded ? root.appKeys : [] }
            delegate: ListRow {
                required property string modelData
                readonly property var app: root.appMap[modelData] || null
                width: ListView.view ? ListView.view.width : 0
                radius: root.radius
                sizeFactor: root.sizeFactor
                icon: "app"
                iconSource: app ? app.icon : ""
                title: app ? app.name : ""
                subtitle: app ? app.subtitle : ""
                clickable: !!app
                onClicked: if (app) root.focusApp(app)
                showRemove: true
                onRemoveClicked: if (app) root.quit(app)
            }
        }
    }
}
