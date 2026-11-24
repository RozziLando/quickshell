import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Bluetooth
import qs.services
import qs.widgets
import qs.island

Item {
    id: barItem

    required property string kind
    required property var stage
    property Item pill: null

    readonly property bool vertical: Theme.barVertical
    readonly property int thick: stage.itemSize
    readonly property int pad: Theme.s(8)

    readonly property int length: {
        if (kind === "clock") return (vertical ? clockColumn.implicitHeight : clockRow.implicitWidth) + 2 * pad
        if (kind === "workspaces") return wsBox.count * wsBox.dot + Math.max(0, wsBox.count - 1) * wsBox.gap
            + (wsBox.active >= 0 ? wsBox.dot : 0) + 2 * pad
        return thick
    }

    visible: !(kind === "power" && stage.powerOpen)
    implicitWidth: vertical ? thick : length
    implicitHeight: vertical ? length : thick
    Behavior on implicitWidth { enabled: barItem.kind === "workspaces" && barItem.stage.settled; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { enabled: barItem.kind === "workspaces" && barItem.stage.settled; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    readonly property bool veiled: !!pill && pill.activeOwner !== "" && !ccMode
    FadeIn { active: !barItem.veiled; pause: 100; duration: 250 }

    readonly property bool hovered: hover.hovered
    HoverHandler { id: hover }

    Component.onCompleted: stage.registerItem(kind, barItem)
    Component.onDestruction: stage.unregisterItem(kind, barItem)

    Rectangle {
        anchors.centerIn: parent
        width: barItem.vertical ? barItem.thick - Theme.s(6) : barItem.length - Theme.s(4)
        height: barItem.vertical ? barItem.length - Theme.s(4) : barItem.thick - Theme.s(6)
        radius: Math.min(Theme.radius, Math.min(width, height) / 2)
        color: Theme.highlight
        opacity: hover.hovered && barItem.clickable && !(barItem.pill && barItem.pill.activeOwner !== "") ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    readonly property bool clickable: kind !== "workspaces" && (kind !== "clock" || Theme.controlCenter)

    Rectangle {
        visible: barItem.kind === "notifications" && barItem.stage.notificationCount > 0
        x: barItem.width / 2 + barItem.iconSize * 0.18
        y: barItem.height / 2 - barItem.iconSize * 0.5
        width: Theme.s(6)
        height: width
        radius: Theme.round(width)
        color: Theme.accent
    }

    MouseArea {
        anchors.fill: parent
        enabled: barItem.clickable
        cursorShape: Qt.PointingHandCursor
        onClicked: barItem.stage.activate(barItem.kind, barItem)
    }

    readonly property real iconSize: Math.round(thick * 0.5)

    LineIcon {
        anchors.centerIn: parent
        visible: ["search", "themes", "power", "display", "bluetooth", "network", "notifications"].indexOf(barItem.kind) >= 0
        size: barItem.iconSize
        kind: ({
            "search": "search",
            "themes": "palette",
            "power": "power",
            "display": "sun",
            "bluetooth": "bluetooth",
            "network": Controls.hasWifi ? "wifi" : "ethernet",
            "notifications": "bell"
        })[barItem.kind] || ""
        level: barItem.kind === "network" && Controls.hasWifi ? barItem.wifiLevel : -1
        color: barItem.kind === "bluetooth" && !barItem.bluetoothOn ? Theme.textMuted
             : barItem.kind === "network" && Controls.hasWifi && !Networking.wifiEnabled ? Theme.textMuted
             : Theme.text
    }

    readonly property bool bluetoothOn: !!(Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled)

    readonly property int wifiLevel: {
        if (kind !== "network" || !Networking.wifiEnabled) return 0
        var devices = Networking.devices.values
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].type !== DeviceType.Wifi) continue
            var nets = devices[i].networks.values
            for (var j = 0; j < nets.length; j++)
                if (nets[j].connected) return Math.max(1, Math.min(3, Math.ceil(nets[j].signalStrength * 3)))
        }
        return 0
    }

    AudioIndicator {
        visible: barItem.kind === "audio"
        anchors.centerIn: parent
        width: barItem.thick * 0.8
        height: barItem.thick * 0.8
    }

    BatteryIndicator {
        visible: barItem.kind === "sysmon"
        anchors.centerIn: parent
        width: barItem.thick * 0.8
        height: barItem.thick * 0.8
    }

    Loader {
        anchors.centerIn: parent
        active: barItem.kind === "logo"
        sourceComponent: DistroLogo {
            width: Math.round(barItem.thick * 0.62)
            height: width
        }
    }

    property string timeText: ""
    property string dateText: ""
    property var dateParts: []

    function updateClock() {
        var now = new Date()
        timeText = Qt.formatDateTime(now, "hh:mm")
        var parts = []
        if (Theme.clockWeekday) parts.push(Qt.locale("en_US").dayName(now.getDay(), Locale.ShortFormat))
        if (Theme.clockDay) parts.push(Qt.formatDateTime(now, "dd"))
        if (Theme.clockMonth) parts.push(Qt.locale("en_US").monthName(now.getMonth(), Locale.ShortFormat))
        var joined = parts.join(" ")
        if (joined === dateText && parts.length === dateParts.length) return
        dateParts = parts
        dateText = joined
    }

    Timer {
        running: barItem.kind === "clock"
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: barItem.updateClock()
    }

    Connections {
        target: Theme
        enabled: barItem.kind === "clock"
        function onClockWeekdayChanged() { barItem.updateClock() }
        function onClockDayChanged() { barItem.updateClock() }
        function onClockMonthChanged() { barItem.updateClock() }
    }

    readonly property bool islandClock: !!pill && pill.islandLike && !vertical
    readonly property bool ccMode: kind === "clock" && !!pill && pill.activeOwner === "control"
    readonly property var ccDate: {
        var t = timeText
        var now = new Date()
        return { weekday: Qt.locale("en_US").dayName(now.getDay(), Locale.ShortFormat),
                 day: Qt.formatDateTime(now, "d") + " " + Qt.locale("en_US").monthName(now.getMonth(), Locale.ShortFormat) }
    }

    readonly property real ccTarget: {
        if (!ccMode || !stage || !stage.mainPanel) return 0
        var f = stage.mainPanel.bloomFull
        if (f.width <= 0 || f.height <= 0) return 0
        var c = mapToItem(stage.contentItem, width / 2, height / 2)
        return vertical ? f.y + f.height / 2 - c.y : f.x + f.width / 2 - c.x
    }
    property real ccShift: ccTarget
    Behavior on ccShift { NumberAnimation { duration: 380; easing.type: Easing.OutCubic } }

    Row {
        id: clockRow
        visible: barItem.kind === "clock" && !barItem.vertical
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: barItem.ccShift
        spacing: Theme.s(8)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: barItem.dateText !== ""
            text: barItem.dateText
            color: Theme.textSecondary
            font.pixelSize: Theme.s(12)
            font.family: Theme.fontFamily
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: barItem.islandClock ? -Theme.s(1) : 0
            text: barItem.timeText
            color: Theme.text
            font.pixelSize: barItem.islandClock ? Theme.s(15) : Theme.s(13.5)
            font.bold: true
            font.family: Theme.fontFamily
            font.features: { "tnum": 1 }
        }
    }

    Text {
        visible: barItem.kind === "clock"
        x: barItem.vertical ? (barItem.width - width) / 2 : clockRow.x - Theme.s(8) - width
        y: barItem.vertical ? clockColumn.y - Theme.s(4) - height : (barItem.height - height) / 2
        text: barItem.ccDate.weekday
        color: Theme.accent
        font.pixelSize: barItem.vertical ? Theme.s(10) : Theme.s(11.5)
        font.weight: Font.DemiBold
        font.family: Theme.fontFamily
        FadeIn { active: barItem.ccMode; pause: 100; duration: 250 }
    }

    Text {
        visible: barItem.kind === "clock"
        x: barItem.vertical ? (barItem.width - width) / 2 : clockRow.x + clockRow.width + Theme.s(8)
        y: barItem.vertical ? clockColumn.y + clockColumn.height + Theme.s(4) : (barItem.height - height) / 2
        text: barItem.vertical ? barItem.ccDate.day.split(" ").join("\n") : barItem.ccDate.day
        horizontalAlignment: Text.AlignHCenter
        color: Theme.accent
        font.pixelSize: barItem.vertical ? Theme.s(10) : Theme.s(11.5)
        font.weight: Font.DemiBold
        font.family: Theme.fontFamily
        FadeIn { active: barItem.ccMode; pause: 100; duration: 250 }
    }

    Column {
        id: clockColumn
        visible: barItem.kind === "clock" && barItem.vertical
        anchors.centerIn: parent
        anchors.verticalCenterOffset: barItem.ccShift
        spacing: Theme.s(1)

        Repeater {
            model: barItem.vertical && barItem.kind === "clock" ? barItem.timeText.split(":") : []
            delegate: Text {
                required property string modelData
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData
                color: Theme.text
                font.pixelSize: Theme.s(13.5)
                font.bold: true
                font.family: Theme.fontFamily
                font.features: { "tnum": 1 }
            }
        }
        Item { width: 1; height: barItem.dateParts.length > 0 ? Theme.s(4) : 0 }
        Repeater {
            model: barItem.vertical && barItem.kind === "clock" ? barItem.dateParts : []
            delegate: Text {
                required property string modelData
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData
                color: Theme.textSecondary
                font.pixelSize: Theme.s(10)
                font.family: Theme.fontFamily
            }
        }
    }

    Item {
        id: wsBox
        visible: barItem.kind === "workspaces"
        anchors.fill: parent

        readonly property int dot: Theme.s(7)
        readonly property int gap: Theme.s(6)
        readonly property var monitor: barItem.stage.hyprMonitor
        function windowsOf(w) {
            var n = w.toplevels ? w.toplevels.values.length : 0
            if (n === 0 && w.lastIpcObject && w.lastIpcObject.windows) n = w.lastIpcObject.windows
            return n
        }
        readonly property int activeId: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
        readonly property var span: {
            if (barItem.kind !== "workspaces") return { ids: [], busy: {} }
            var ids = [], busy = {}
            Hyprland.workspaces.values.forEach(function (w) {
                if (w.id <= 0) return
                if (wsBox.monitor && w.monitor && w.monitor !== wsBox.monitor) return
                if (wsBox.windowsOf(w) > 0) {
                    busy[w.id] = true
                    ids.push(w.id)
                }
            })
            if (wsBox.activeId > 0 && ids.indexOf(wsBox.activeId) < 0) ids.push(wsBox.activeId)
            ids.sort(function (a, b) { return a - b })
            if (Theme.showEmptyWorkspaces && ids.length > 1) {
                var all = []
                for (var i = ids[0]; i <= ids[ids.length - 1]; i++) all.push(i)
                ids = all
            }
            return { ids: ids, busy: busy }
        }
        readonly property int count: span.ids.length
        readonly property int active: span.ids.indexOf(activeId)

        ListModel { id: wsModel }
        function syncDots() {
            while (wsModel.count < count) wsModel.append({})
            while (wsModel.count > count) wsModel.remove(wsModel.count - 1)
        }
        onCountChanged: syncDots()
        Component.onCompleted: syncDots()

        Grid {
            x: barItem.vertical ? (parent.width - width) / 2 : barItem.pad
            y: barItem.vertical ? barItem.pad : (parent.height - height) / 2
            columns: barItem.vertical ? 1 : Math.max(1, wsBox.count)
            spacing: wsBox.gap

            Repeater {
                model: wsModel
                delegate: Rectangle {
                    id: wsDot
                    required property int index
                    readonly property int wsId: wsBox.span.ids[index] || 0
                    readonly property bool current: index === wsBox.active
                    readonly property bool busy: !!wsBox.span.busy[wsId]
                    property bool shown: false
                    Component.onCompleted: shown = true
                    readonly property real full: current ? 2 * wsBox.dot : wsBox.dot
                    width: barItem.vertical ? wsBox.dot : (shown ? full : 0)
                    height: barItem.vertical ? (shown ? full : 0) : wsBox.dot
                    radius: Theme.round(Math.min(wsBox.dot, Math.max(1, Math.min(width, height))))
                    color: current ? Theme.accent : (wsArea.containsMouse ? Theme.text : Theme.textMuted)
                    opacity: current || busy || wsArea.containsMouse || !Theme.showEmptyWorkspaces ? 1 : 0.45
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                    Behavior on color { ColorAnimation { duration: 200 } }

                    MouseArea {
                        id: wsArea
                        anchors.fill: parent
                        anchors.margins: -Theme.s(4)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: barItem.stage.goToWorkspace(wsDot.wsId)
                    }
                }
            }
        }
    }
}
