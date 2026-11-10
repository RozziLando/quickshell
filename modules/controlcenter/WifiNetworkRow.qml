import QtQuick
import Quickshell.Networking
import qs.services
import qs.widgets

ListRow {
    id: row
    required property var modelData
    required property var owner
    readonly property var net: modelData

    sizeFactor: row.owner.sizeFactor
    icon: "wifi"
    iconLevel: row.owner.level(net)
    title: net.name
    selected: net.connected
    trailingIcon: row.owner.secured(net) && !net.connected ? "lock" : ""
    hasExtra: row.owner.passwordFor === net
    onClicked: row.owner.activate(net)

    Connections {
        target: row.net
        function onConnectionFailed(reason) {
            if (!row.owner.secured(row.net) || row.owner.enterprise(row.net)) return
            if (reason !== ConnectionFailReason.NoSecrets
                    && reason !== ConnectionFailReason.WifiAuthTimeout
                    && reason !== ConnectionFailReason.WifiClientFailed) return
            row.owner.errorFor = row.net
            row.owner.askPassword(row.net)
        }
    }

    Rectangle {
        visible: row.owner.passwordFor === row.net
        width: parent.width
        height: row.owner.u(30)
        radius: height / 2
        color: Theme.track

        onVisibleChanged: if (visible) { pwInput.text = ""; focusLater.restart() }
        Timer {
            id: focusLater
            interval: 80
            onTriggered: pwInput.forceActiveFocus()
        }

        TextInput {
            id: pwInput
            anchors {
                fill: parent
                leftMargin: row.owner.u(14)
                rightMargin: row.owner.u(14)
            }
            verticalAlignment: TextInput.AlignVCenter
            echoMode: TextInput.Password
            color: Theme.text
            selectionColor: Theme.selection
            font.pixelSize: row.owner.u(11)
            font.family: Theme.fontFamily
            clip: true

            Keys.onReturnPressed: row.owner.submit(row.net, text)
            Keys.onEnterPressed: row.owner.submit(row.net, text)
            Keys.onEscapePressed: event => {
                row.owner.passwordFor = null
                event.accepted = true
                row.owner.forceActiveFocus()
            }
        }

        Text {
            anchors.left: pwInput.left
            anchors.verticalCenter: parent.verticalCenter
            visible: pwInput.text === ""
            text: row.owner.errorFor === row.net ? "Wrong password, try again" : "Password"
            color: Theme.textMuted
            font.pixelSize: row.owner.u(11)
            font.family: Theme.fontFamily
        }
    }
}
