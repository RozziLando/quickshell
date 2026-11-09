import QtQuick
import qs.services

// Titoletto di sezione nelle pagine di dettaglio (es. "Saved")
Item {
    id: root

    property real sizeFactor: 1.0
    function u(value) { return Theme.s(value * sizeFactor) }

    property string text: ""

    width: parent ? parent.width : 0
    height: u(22)

    Text {
        anchors.left: parent.left
        anchors.leftMargin: root.u(4)
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.u(2)
        text: root.text
        color: Theme.textMuted
        font.pixelSize: root.u(10)
        font.family: Theme.fontFamily
    }
}
