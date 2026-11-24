import QtQuick
import qs.services

Rectangle {
    id: card

    property string title: ""
    property string subtitle: ""
    property bool current: false
    property int previewHeight: SettingsUi.u(64)
    default property alias preview: previewHost.data

    signal clicked()

    height: previewBox.height + caption.implicitHeight + 3 * SettingsUi.u(12)
    radius: SettingsUi.radius
    color: area.containsMouse && !current ? Theme.surface : Theme.card
    border.width: current ? 2 : 1
    border.color: current ? Theme.accent : Theme.cardBorder
    Behavior on color { ColorAnimation { duration: 120 } }

    Rectangle {
        id: previewBox
        x: SettingsUi.u(12)
        y: SettingsUi.u(12)
        width: parent.width - 2 * SettingsUi.u(12)
        height: card.previewHeight
        radius: SettingsUi.radius
        color: Theme.track
        clip: true

        Item {
            id: previewHost
            anchors.fill: parent
        }
    }

    Column {
        id: caption
        anchors.top: previewBox.bottom
        anchors.topMargin: SettingsUi.u(10)
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 2 * SettingsUi.u(12)
        spacing: SettingsUi.u(2)

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: card.title
            color: card.current ? Theme.accent : Theme.text
            font.pixelSize: SettingsUi.u(11)
            font.weight: Font.DemiBold
            font.family: Theme.fontFamily
        }
        Text {
            width: parent.width
            visible: card.subtitle !== ""
            horizontalAlignment: Text.AlignHCenter
            text: card.subtitle
            color: Theme.textSecondary
            font.pixelSize: SettingsUi.u(9)
            font.family: Theme.fontFamily
            wrapMode: Text.WordWrap
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: card.current ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: if (!card.current) card.clicked()
    }
}
