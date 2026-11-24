import QtQuick
import Quickshell.Widgets
import qs.services
import qs.widgets

Card {
    id: card

    required property var notifications
    property real sizeFactor: 1.0
    function u(value) { return Theme.s(value * sizeFactor) }
    property real maxVisible: 2.5
    property int cardRadius: Theme.radius
    property bool framed: true

    signal activated()

    readonly property bool hasNotifications: notifications.history.count > 0
    readonly property int notifItemH: u(56)
    readonly property int notifSpacing: u(6)
    readonly property real notifVisible: Math.min(notifications.history.count, maxVisible)
    readonly property int notifListH: Math.round(notifVisible * notifItemH
        + Math.max(0, Math.ceil(notifVisible) - 1) * notifSpacing)
    readonly property int preferredHeight: framed
        ? (hasNotifications ? u(100) - notifItemH + notifListH : u(38))
        : u(34) + u(10) + (hasNotifications ? notifListH : u(40))

    function arrivalText(time) {
        if (!(time > 0)) return ""
        var d = new Date(time)
        return d.toDateString() === new Date().toDateString()
            ? Qt.formatDateTime(d, "hh:mm") : Qt.formatDateTime(d, "dd/MM")
    }

    height: preferredHeight
    radius: cardRadius
    color: framed ? Theme.card : "transparent"
    border.width: framed ? 1 : 0

    Item {
        id: notifTop
        anchors {
            top: parent.top
            topMargin: card.framed ? card.u(10) : 0
            left: parent.left
            right: parent.right
            leftMargin: card.framed ? card.u(16) : card.u(4)
            rightMargin: card.framed ? card.u(16) : card.u(4)
        }
        height: card.framed ? card.u(18) : card.u(34)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Notifications" + (card.notifications.history.count > 1
                                 ? "  ·  " + card.notifications.history.count : "")
            color: card.framed ? Theme.textSecondary : Theme.text
            font.pixelSize: card.framed ? card.u(10) : card.u(15)
            font.bold: !card.framed
            font.family: Theme.fontFamily
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: card.notifications.history.count > 0
            text: "Clear all"
            color: Theme.textMuted
            font.pixelSize: card.u(10)
            font.family: Theme.fontFamily

            MouseArea {
                anchors.fill: parent
                anchors.margins: -card.u(6)
                onClicked: card.notifications.history.clear()
            }
        }
    }

    ListView {
        id: notifList
        visible: card.hasNotifications
        anchors {
            top: notifTop.bottom
            topMargin: card.framed ? card.u(6) : card.u(10)
            left: parent.left
            right: parent.right
            leftMargin: card.framed ? card.u(10) : 0
            rightMargin: card.framed ? card.u(10) : 0
        }
        height: card.notifListH
        clip: true
        spacing: card.notifSpacing
        model: card.notifications.history
        boundsBehavior: Flickable.StopAtBounds

        delegate: Card {
            id: entry
            required property int index
            required property string app
            required property string summary
            required property string body
            required property string icon
            required property string desktopEntry
            required property bool rounded
            required property real time

            width: ListView.view.width
            height: card.notifItemH
            radius: card.framed ? Math.max(0, card.cardRadius - card.u(10)) : Theme.radius
            color: card.framed ? (entryArea.containsMouse ? Theme.highlight : Theme.surface)
                               : (entryArea.containsMouse ? Theme.surface : Theme.card)
            border.color: card.framed ? "transparent" : Theme.cardBorder

            MouseArea {
                id: entryArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    card.notifications.focusApp(entry.desktopEntry, entry.app)
                    card.activated()
                }
            }

            Item {
                id: avatar
                width: card.u(30)
                height: card.u(30)
                anchors {
                    left: parent.left
                    leftMargin: card.u(12)
                    verticalCenter: parent.verticalCenter
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.round(width)
                    visible: !iconBox.visible
                    color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)

                    Text {
                        anchors.centerIn: parent
                        text: entry.app !== "" ? entry.app.charAt(0).toUpperCase() : "?"
                        color: Theme.accent
                        font.pixelSize: card.u(11)
                        font.bold: true
                        font.family: Theme.fontFamily
                    }
                }

                ClippingRectangle {
                    id: iconBox
                    anchors.fill: parent
                    radius: entry.rounded ? Theme.round(width) : 0
                    color: "transparent"
                    visible: entry.icon !== "" && iconImage.status === Image.Ready

                    Image {
                        id: iconImage
                        anchors.fill: parent
                        source: entry.icon
                        sourceSize.width: Theme.px(card.u(30), iconImage)
                        sourceSize.height: Theme.px(card.u(30), iconImage)
                        fillMode: entry.rounded ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                        asynchronous: true
                    }
                }
            }

            Column {
                anchors {
                    left: avatar.right
                    leftMargin: card.u(10)
                    right: timeText.left
                    rightMargin: card.u(6)
                    verticalCenter: parent.verticalCenter
                }

                Text {
                    width: parent.width
                    text: entry.app
                    color: Theme.textMuted
                    font.pixelSize: card.u(9)
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: entry.summary
                    textFormat: Text.PlainText
                    color: Theme.text
                    font.pixelSize: card.u(11)
                    font.bold: true
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    visible: entry.body !== ""
                    text: entry.body.replace(/\n/g, " ")
                    textFormat: Text.PlainText
                    color: Theme.textSoft
                    font.pixelSize: card.u(10)
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                }
            }

            Text {
                id: timeText
                anchors {
                    right: closeButton.left
                    rightMargin: card.u(6)
                    verticalCenter: parent.verticalCenter
                }
                text: card.arrivalText(entry.time)
                color: Theme.textMuted
                font.pixelSize: card.u(9)
                font.family: Theme.fontFamily
            }

            Item {
                id: closeButton
                width: card.u(16)
                height: card.u(16)
                anchors {
                    right: parent.right
                    rightMargin: card.u(14)
                    verticalCenter: parent.verticalCenter
                }

                LineIcon {
                    anchors.centerIn: parent
                    kind: "close"
                    size: card.u(10)
                    color: Theme.textMuted
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -card.u(5)
                    onClicked: card.notifications.history.remove(entry.index)
                }
            }
        }
    }

    Text {
        x: card.framed ? notifTop.x + notifTop.width - width : (card.width - width) / 2
        y: card.framed ? notifTop.y + (notifTop.height - height) / 2 : notifTop.height + card.u(10) + (card.u(40) - height) / 2
        visible: !card.hasNotifications
        text: "No notifications"
        color: Theme.textMuted
        font.pixelSize: card.u(10)
        font.family: Theme.fontFamily
    }
}
