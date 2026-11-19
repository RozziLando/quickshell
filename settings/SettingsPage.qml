import QtQuick
import Quickshell
import qs.services
import qs.widgets

Item {
    id: page

    property string icon: ""
    property string title: ""
    property string description: ""
    property bool showHeader: true

    default property alias content: body.data
    property alias overlay: overlayHost.data
    property alias flickable: flick

    readonly property int pad: SettingsUi.u(14)

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.topMargin: page.pad
        anchors.bottomMargin: page.pad
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        onMovementStarted: SettingsUi.tip = null

        Column {
            id: column
            x: page.pad
            width: flick.width - 2 * page.pad
            spacing: SettingsUi.u(6)

            Rectangle {
                visible: page.showHeader
                width: parent.width
                height: headerColumn.implicitHeight + 2 * SettingsUi.u(12)
                radius: SettingsUi.radius
                color: Theme.card
                border.width: 1
                border.color: Theme.cardBorder

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onPressed: mouse => {
                        var w = page.QsWindow.window
                        if (!w || !w.startSystemMove || !w.startSystemMove()) mouse.accepted = false
                    }
                }

                Column {
                    id: headerColumn
                    anchors.centerIn: parent
                    width: parent.width - 2 * SettingsUi.u(24)
                    spacing: SettingsUi.u(4)

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: SettingsUi.u(40)
                        height: width
                        radius: width / 2
                        color: Theme.accent

                        LineIcon {
                            anchors.centerIn: parent
                            kind: page.icon
                            size: SettingsUi.u(19)
                            color: Theme.background
                        }
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: page.title
                        color: Theme.text
                        font.pixelSize: SettingsUi.u(14)
                        font.bold: true
                        font.family: Theme.fontFamily
                    }

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        visible: page.description !== ""
                        text: page.description
                        color: Theme.textSecondary
                        font.pixelSize: SettingsUi.u(10)
                        font.family: Theme.fontFamily
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Column {
                id: body
                width: parent.width
                spacing: SettingsUi.u(6)
            }
        }
    }

    Item {
        id: overlayHost
        width: 0
        height: 0
    }

    Rectangle {
        visible: flick.contentHeight > flick.height + 1
        anchors.right: parent.right
        anchors.rightMargin: SettingsUi.u(4)
        readonly property real track: flick.height
        readonly property real size: Math.max(SettingsUi.u(24), flick.visibleArea.heightRatio * track)
        y: page.pad + Math.max(0, Math.min(track - size,
                                           flick.contentY / Math.max(1, flick.contentHeight - flick.height) * (track - size)))
        width: SettingsUi.u(4)
        height: size
        radius: width / 2
        color: Theme.textMuted
        opacity: flick.moving ? 0.7 : 0.3
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }
}
