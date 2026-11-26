import QtQuick
import qs.services
import qs.widgets
import qs.modules.controlcenter

Item {
    id: root
    required property var island
    property bool full: true
    width: shown ? parent.width : openWidth
    height: shown ? parent.height : openHeight

    readonly property string ownerId: "clockpanel"
    readonly property bool shown: island.owner === ownerId

    readonly property real sizeFactor: 0.79
    function u(value) { return Theme.s(value * sizeFactor) }

    readonly property var parts: Controls.clockParts(full)
    readonly property bool useful: parts.length > 0
    readonly property bool hasDate: parts.indexOf("day") >= 0 || parts.indexOf("month") >= 0
    readonly property bool hasWeekday: parts.indexOf("weekday") >= 0

    readonly property int pad: u(14)
    readonly property int openWidth: (full ? u(300) : u(220)) + 2 * pad + 2 * island.topRadius
    readonly property int openHeight: (full ? u(60) : (hasWeekday && hasDate ? u(44) : u(28))) + 2 * pad

    property date now: new Date()
    readonly property var locale: Qt.locale("en_US")
    readonly property string dateLine: {
        var out = []
        if (parts.indexOf("day") >= 0) out.push(now.getDate())
        if (parts.indexOf("month") >= 0) out.push(locale.monthName(now.getMonth(), Locale.LongFormat))
        if (hasDate) out.push(now.getFullYear())
        return out.join(" ")
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.shown && !root.full
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    function toggle() {
        if (shown) {
            island.close(ownerId)
            return
        }
        if (!useful) return
        island.open(ownerId, openWidth, openHeight, false)
        island.grabOwner = ownerId
    }

    onOpenHeightChanged: if (shown) island.open(ownerId, openWidth, openHeight, false)
    onUsefulChanged: if (!useful && shown) island.close(ownerId)

    Connections {
        target: root.island
        function onHoveredChanged() {
            if (root.island.hovered) closeTimer.stop()
            else if (root.shown) closeTimer.restart()
        }
    }

    Timer {
        id: closeTimer
        interval: 250
        onTriggered: root.island.close(root.ownerId)
    }

    Item {
        anchors.fill: parent
        anchors.margins: root.pad
        anchors.leftMargin: root.pad + root.island.topRadius
        anchors.rightMargin: root.pad + root.island.topRadius
        visible: root.shown
        FadeIn { active: root.shown; pause: 140; duration: 220 }

        ClockCard {
            visible: root.full
            anchors.fill: parent
            sizeFactor: root.sizeFactor
            active: root.shown && root.full
        }

        Column {
            visible: !root.full
            anchors.centerIn: parent
            spacing: root.u(2)

            Text {
                visible: root.hasWeekday
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.locale.dayName(root.now.getDay(), Locale.LongFormat)
                color: Theme.accent
                font.pixelSize: root.u(15)
                font.weight: Font.DemiBold
                font.family: Theme.fontFamily
            }
            Text {
                visible: root.hasDate
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.dateLine
                color: root.hasWeekday ? Theme.textSecondary : Theme.text
                font.pixelSize: root.hasWeekday ? root.u(12) : root.u(15)
                font.weight: root.hasWeekday ? Font.Normal : Font.DemiBold
                font.family: Theme.fontFamily
            }
        }
    }
}
