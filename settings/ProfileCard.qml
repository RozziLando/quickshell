import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.services
import qs.widgets

Rectangle {
    id: root

    readonly property string avatarBase: Quickshell.shellPath("assets/avatar")
    property var avatarFiles: []
    property int avatarTry: 0
    property int avatarVersion: 0
    property string fullName: ""
    readonly property string userName: Quickshell.env("USER") || ""
    property bool saving: false

    height: SettingsUi.u(56)
    radius: SettingsUi.radius
    color: Theme.card
    border.width: 1
    border.color: Theme.cardBorder

    function refreshAvatar() {
        if (!avatarProc.running) avatarProc.running = true
    }

    Process {
        id: avatarProc
        running: true
        command: ["sh", "-c",
            'for e in png jpg jpeg; do [ -f "$1.$e" ] && echo "$1.$e"; done;'
            + ' printf "name\\t%s\\n" "$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f5 | cut -d, -f1)"',
            "sh", root.avatarBase]
        stdout: StdioCollector {
            onStreamFinished: {
                var files = [], name = ""
                text.split("\n").forEach(function (l) {
                    if (l.indexOf("name\t") === 0) name = l.substring(5).trim()
                    else if (l !== "") files.push(l)
                })
                root.fullName = name
                root.avatarTry = 0
                root.avatarFiles = files
            }
        }
    }

    function chooseAvatar() {
        if (saving) return
        SettingsUi.picker.open("image", "Choose your photo", Quickshell.env("HOME") + "/Pictures", function (paths) {
            root.useAvatar(paths[0])
        })
    }

    function useAvatar(path) {
        if (saving || !path) return
        saving = true
        maker.source = Theme.fileUrl(path)
    }

    Item {
        id: makerHost
        x: -width - 10
        width: 512
        height: 512
        visible: maker.source !== ""

        Image {
            id: maker
            anchors.fill: parent
            source: ""
            sourceSize.width: 1024
            sourceSize.height: 1024
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            onStatusChanged: {
                if (status === Image.Ready) Qt.callLater(root.saveAvatar)
                else if (status === Image.Error) {
                    source = ""
                    root.saving = false
                }
            }
        }
    }

    function saveAvatar() {
        var target = avatarBase + ".png"
        var ok = makerHost.grabToImage(function (result) {
            var saved = result.saveToFile(target)
            maker.source = ""
            if (!saved) {
                root.saving = false
                return
            }
            cleanProc.running = true
        }, Qt.size(512, 512))
        if (!ok) {
            maker.source = ""
            saving = false
        }
    }

    Process {
        id: cleanProc
        command: ["sh", "-c", 'rm -f "$1.jpg" "$1.jpeg"', "sh", root.avatarBase]
        onExited: {
            root.saving = false
            root.avatarVersion++
            root.refreshAvatar()
            GreeterSync.sync()
        }
    }

    ClippingRectangle {
        id: avatar
        x: SettingsUi.u(10)
        anchors.verticalCenter: parent.verticalCenter
        width: SettingsUi.u(36)
        height: width
        radius: Theme.round(width)
        color: Theme.highlight

        Image {
            id: avatarImage
            anchors.fill: parent
            source: root.avatarTry < root.avatarFiles.length
                    ? Theme.fileUrl(root.avatarFiles[root.avatarTry]) + "?v=" + root.avatarVersion : ""
            sourceSize.width: Theme.px(avatar.width, avatarImage)
            sourceSize.height: Theme.px(avatar.height, avatarImage)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            visible: status === Image.Ready
            onStatusChanged: if (status === Image.Error) root.avatarTry++
        }

        Text {
            anchors.centerIn: parent
            visible: !avatarImage.visible
            text: root.userName.length > 0 ? root.userName[0].toUpperCase() : "?"
            color: Theme.text
            font.pixelSize: SettingsUi.u(15)
            font.weight: Font.DemiBold
            font.family: Theme.fontFamily
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.45)
            visible: avatarArea.containsMouse || root.saving

            LineIcon {
                anchors.centerIn: parent
                kind: "pencil"
                size: SettingsUi.u(14)
                color: "white"
            }
        }

        MouseArea {
            id: avatarArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.chooseAvatar()
            onContainsMouseChanged: {
                if (containsMouse) SettingsUi.showTip(avatar, "Change photo")
                else SettingsUi.hideTip(avatar)
            }
        }
    }

    Column {
        anchors.left: avatar.right
        anchors.leftMargin: SettingsUi.u(10)
        anchors.right: updateButton.visible ? updateButton.left : parent.right
        anchors.rightMargin: SettingsUi.u(8)
        anchors.verticalCenter: parent.verticalCenter
        spacing: SettingsUi.u(1)

        Text {
            width: parent.width
            text: root.fullName !== "" ? root.fullName : root.userName
            color: Theme.text
            font.pixelSize: SettingsUi.u(11)
            font.weight: Font.DemiBold
            font.family: Theme.fontFamily
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: Updater.running ? "Updating..." : Updater.enabled && Updater.state === "error" ? "Update failed"
                : Updater.available ? "New version" : "Quickshell"
            color: Updater.enabled && Updater.state === "error" ? Theme.warning : Updater.available ? Theme.accent : Theme.textMuted
            font.pixelSize: SettingsUi.u(9)
            font.family: Theme.fontFamily
            elide: Text.ElideRight
        }
    }

    PillButton {
        id: updateButton
        anchors.right: parent.right
        anchors.rightMargin: SettingsUi.u(10)
        anchors.verticalCenter: parent.verticalCenter
        visible: Updater.available || Updater.running || (Updater.enabled && Updater.state === "error")
        primary: true
        busy: Updater.running
        icon: "update"
        text: Updater.running ? "" : Updater.state === "error" ? "Retry" : "Update"
        onClicked: Updater.update()

        HoverHandler {
            onHoveredChanged: {
                if (hovered && Updater.state === "error") SettingsUi.showTip(updateButton, Updater.message)
                else SettingsUi.hideTip(updateButton)
            }
        }
    }

    Component.onDestruction: {
        SettingsUi.hideTip(avatar)
        SettingsUi.hideTip(updateButton)
    }
}
