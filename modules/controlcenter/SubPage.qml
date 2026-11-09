import QtQuick
import qs.services
import qs.widgets

// Pagina di dettaglio del centro di controllo: freccia per tornare indietro,
// titolo, interruttore opzionale a destra e contenuto scorrevole
Item {
    id: root

    property real sizeFactor: 1.0
    function u(value) { return Theme.s(value * sizeFactor) }

    property string title: ""
    property bool showSwitch: false
    property bool switchOn: false

    signal back()
    signal switchToggled()

    // Tutto ciò che si mette dentro <SubPage> va nella colonna scorrevole
    default property alias content: body.data

    // Torna in cima ogni volta che la pagina viene aperta
    onVisibleChanged: if (visible) scrollToTop()
    function scrollToTop() { flick.contentY = 0 }

    Keys.onEscapePressed: root.back()

    // ----- Intestazione -----
    Item {
        id: header
        width: parent.width
        height: root.u(34)

        Rectangle {
            id: backButton
            width: root.u(32)
            height: width
            radius: width / 2
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: backArea.containsMouse ? Theme.surface : Theme.card
            border.width: 1
            border.color: Theme.cardBorder
            Behavior on color { ColorAnimation { duration: 150 } }

            LineIcon {
                anchors.centerIn: parent
                kind: "back"
                size: root.u(16)
                color: Theme.text
            }

            MouseArea {
                id: backArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.back()
            }
        }

        Text {
            anchors.left: backButton.right
            anchors.leftMargin: root.u(12)
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            color: Theme.text
            font.pixelSize: root.u(15)
            font.bold: true
            font.family: Theme.fontFamily
        }

        Switch {
            visible: root.showSwitch
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            sizeFactor: root.sizeFactor
            checked: root.switchOn
            onToggled: root.switchToggled()
        }
    }

    // ----- Contenuto -----
    Flickable {
        id: flick
        anchors {
            top: header.bottom
            topMargin: root.u(10)
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: body
            width: flick.width
            spacing: root.u(6)
        }
    }
}
