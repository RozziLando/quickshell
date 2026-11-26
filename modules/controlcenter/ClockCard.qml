import QtQuick
import qs.services

Item {
    id: root

    property real sizeFactor: 1.0
    function u(value) { return Theme.s(value * sizeFactor) }
    property bool active: visible

    property date now: new Date()
    readonly property bool narrow: width < u(250)
    readonly property var locale: Qt.locale("en_US")

    Timer {
        interval: 1000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Text {
        id: time
        anchors.left: parent.left
        anchors.leftMargin: root.narrow ? (parent.width - width) / 2 : root.u(16)
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: root.narrow ? -root.u(8) : 0
        text: Qt.formatDateTime(root.now, "hh:mm")
        color: Theme.text
        font.pixelSize: root.narrow ? root.u(20) : root.u(28)
        font.bold: true
        font.family: Theme.fontFamily
        font.features: { "tnum": 1 }
    }

    Column {
        visible: !root.narrow
        anchors.right: parent.right
        anchors.rightMargin: root.u(16)
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.u(2)

        Text {
            anchors.right: parent.right
            text: root.locale.dayName(root.now.getDay(), Locale.LongFormat)
            color: Theme.accent
            font.pixelSize: root.u(13)
            font.weight: Font.DemiBold
            font.family: Theme.fontFamily
        }
        Text {
            anchors.right: parent.right
            text: root.now.getDate() + " " + root.locale.monthName(root.now.getMonth(), Locale.LongFormat)
                + " " + root.now.getFullYear()
            color: Theme.textSecondary
            font.pixelSize: root.u(11)
            font.family: Theme.fontFamily
        }
    }

    Text {
        visible: root.narrow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: time.bottom
        anchors.topMargin: root.u(1)
        width: parent.width - root.u(12)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        text: root.locale.dayName(root.now.getDay(), Locale.ShortFormat) + " "
            + root.now.getDate() + " " + root.locale.monthName(root.now.getMonth(), Locale.ShortFormat)
        color: Theme.accent
        font.pixelSize: root.u(11)
        font.weight: Font.DemiBold
        font.family: Theme.fontFamily
    }
}
