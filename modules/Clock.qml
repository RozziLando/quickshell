import QtQuick
import qs.services
import qs.widgets

Item {
    id: root
    required property var island

    width: parent.width
    height: island.idleH

    readonly property bool shown: island.owner === "" && !island.concealed

    visible: shown
    FadeIn { active: root.shown; pause: 100; duration: 250 }

    Text {
        id: clockText
        anchors.centerIn: parent
        anchors.verticalCenterOffset: island.floating ? 0 : -Theme.s(1)
        color: Theme.text
        font.pixelSize: island.floating ? Theme.s(13.5) : Theme.s(15)
        font.bold: true
        font.family: Theme.fontFamily
        font.features: { "tnum": 1 }

        function updateTime() {
            text = Qt.formatDateTime(new Date(), "hh:mm")
        }
        Component.onCompleted: updateTime()
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: clockText.updateTime()
    }
}
