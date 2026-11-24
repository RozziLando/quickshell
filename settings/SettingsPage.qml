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
                        radius: Theme.round(width)
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

    Item {
        id: scrollTrack
        visible: flick.contentHeight > flick.height + 1
        anchors.right: parent.right
        y: page.pad
        width: SettingsUi.u(12)
        height: flick.height

        readonly property real size: Math.max(SettingsUi.u(24), flick.visibleArea.heightRatio * height)
        readonly property real range: Math.max(1, flick.contentHeight - flick.height)
        readonly property bool active: scrollArea.containsMouse || scrollArea.pressed

        function scrollTo(y) {
            var f = (y - size / 2) / Math.max(1, height - size)
            flick.contentY = Math.max(0, Math.min(range, f * range))
        }

        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: SettingsUi.u(4)
            y: Math.max(0, Math.min(scrollTrack.height - scrollTrack.size,
                                    flick.contentY / scrollTrack.range * (scrollTrack.height - scrollTrack.size)))
            width: scrollTrack.active ? SettingsUi.u(7) : SettingsUi.u(4)
            height: scrollTrack.size
            radius: Theme.round(width)
            color: scrollTrack.active ? Theme.textSecondary : Theme.textMuted
            opacity: scrollTrack.active || flick.moving ? 0.8 : 0.3
            Behavior on width { NumberAnimation { duration: 120 } }
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        MouseArea {
            id: scrollArea
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => scrollTrack.scrollTo(mouse.y)
            onPositionChanged: mouse => { if (pressed) scrollTrack.scrollTo(mouse.y) }
        }
    }
}
