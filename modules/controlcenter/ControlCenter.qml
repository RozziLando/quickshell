import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Services.UPower
import qs.services
import qs.widgets

Item {
    id: root
    required property var island
    required property var launcher
    required property var notifications
    required property var power
    anchors.fill: parent

    readonly property string ownerId: "control"
    readonly property bool shown: island.owner === ownerId

    property bool typeToSearch: true
    property string screenshotCommand:
        'g="$(slurp)" || exit 0; grim -g "$g" - | wl-copy --type image/png'

    readonly property real sizeFactor: 0.79
    function u(value) { return Theme.s(value * sizeFactor) }

    readonly property int openWidth: root.u(436)
    readonly property int edgePad: root.u(14)
    readonly property int sidePad: edgePad + island.topRadius
    readonly property int topPad: edgePad
    readonly property int bottomPad: edgePad
    readonly property int gap: root.u(10)
    readonly property int tileH: root.u(54)
    readonly property int circleSize: root.u(48)
    readonly property int sliderCardH: root.u(60)
    readonly property bool hasNotifications: notifications.history.count > 0
    readonly property int notifItemH: root.u(56)
    readonly property int notifSpacing: root.u(6)
    readonly property real notifVisible: Math.min(notifications.history.count, 2.5)
    readonly property int notifListH: Math.round(notifVisible * notifItemH
        + Math.max(0, Math.ceil(notifVisible) - 1) * notifSpacing)
    readonly property int notifCardH: hasNotifications ? root.u(100) - notifItemH + notifListH
                                                       : root.u(38)
    readonly property int searchH: 2 * cardRadius
    readonly property int cardRadius: root.u(22)
    readonly property int panelRadius: cardRadius + edgePad

    readonly property var batteryDevice: UPower.displayDevice
    readonly property bool desktop: !(batteryDevice && batteryDevice.ready
                                      && batteryDevice.isLaptopBattery && batteryDevice.isPresent)
    readonly property bool hasBluetooth: !!btAdapter
    readonly property bool showDisplay: !desktop
    readonly property bool showKeyboard: !desktop && keyboardAvailable

    readonly property int sliderCount: 1 + (showDisplay ? 1 : 0) + (showKeyboard ? 1 : 0)
    readonly property int openHeight: topPad + tileH + sliderCount * sliderCardH
        + notifCardH + searchH + (sliderCount + 2) * gap + bottomPad

    onOpenHeightChanged: if (shown) island.open(ownerId, openWidth, openHeight,
                                                typeToSearch || island.wantsKeyboard)

    readonly property bool wifiOn: Networking.wifiEnabled
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothOn: !!(btAdapter && btAdapter.enabled)

    readonly property bool hasWifi: {
        var devices = Networking.devices.values
        for (var i = 0; i < devices.length; i++)
            if (devices[i].type === DeviceType.Wifi) return true
        return false
    }
    readonly property bool wiredConnected: {
        var devices = Networking.devices.values
        for (var i = 0; i < devices.length; i++)
            if (devices[i].type === DeviceType.Wired && devices[i].connected) return true
        return false
    }
    readonly property string wiredStatus: {
        if (Networking.backend === NetworkBackendType.None) return "Unknown"
        return wiredConnected ? "Connected" : "Offline"
    }

    readonly property string wifiStatus: {
        if (!wifiOn) return "Off"
        var devices = Networking.devices.values
        for (var i = 0; i < devices.length; i++) {
            if (devices[i].type !== DeviceType.Wifi) continue
            var nets = devices[i].networks.values
            for (var j = 0; j < nets.length; j++)
                if (nets[j].connected) return nets[j].name
        }
        return "On"
    }
    readonly property string bluetoothStatus: {
        if (!bluetoothOn) return "Off"
        var devices = btAdapter.devices.values
        var names = []
        for (var i = 0; i < devices.length; i++)
            if (devices[i].connected) names.push(devices[i].name)
        if (names.length === 0) return "On"
        return names.length === 1 ? names[0] : names[0] + " +" + (names.length - 1)
    }
    readonly property real displayLevel: Brightness.displayLevel
    readonly property bool displayAvailable: Brightness.displayAvailable
    readonly property real keyboardLevel: Brightness.keyboardLevel
    readonly property bool keyboardAvailable: Brightness.keyboardAvailable

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool audioAvailable: !!(sink && sink.audio)
    PwObjectTracker { objects: root.sink ? [root.sink] : [] }

    readonly property bool busy: volumeSlider.dragging
        || displaySlider.dragging || keyboardSlider.dragging
        || wifiPage.busy || audioPage.busy || displayPage.busy

    property string page: ""

    function openPage(name) {
        page = name
        pageFocusTimer.restart()
    }

    function closePage() {
        page = ""
        focusTimer.restart()
    }

    Timer {
        id: pageFocusTimer
        interval: 60
        onTriggered: {
            if (root.page === "wifi") wifiPage.forceActiveFocus()
            else if (root.page === "bluetooth") bluetoothPage.forceActiveFocus()
            else if (root.page === "audio") audioPage.forceActiveFocus()
            else if (root.page === "display") displayPage.forceActiveFocus()
        }
    }

    function requestKeyboard() {
        if (shown) island.open(ownerId, openWidth, openHeight, true)
    }

    function refresh() {
        Brightness.refresh()
    }

    onShownChanged: {
        if (shown) {
            refresh()
            focusTimer.restart()
        } else {
            page = ""
            if (island.openHovered) reopenBlocked = true
        }
    }

    property bool reopenBlocked: false

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled
    }

    function toggleBluetooth() {
        if (btAdapter) btAdapter.enabled = !btAdapter.enabled
    }

    function takeScreenshot() {
        island.close(ownerId)
        Quickshell.execDetached(["sh", "-c", "sleep 0.5; " + screenshotCommand])
    }

    function setVolume(value) {
        if (audioAvailable)
            sink.audio.volume = Math.max(0, Math.min(1, value))
    }

    function toggleMute() {
        if (audioAvailable) sink.audio.muted = !sink.audio.muted
    }

    function setDisplay(value) {
        Brightness.setDisplay(value)
    }

    function setKeyboard(value) {
        Brightness.setKeyboard(value)
    }

    Connections {
        target: root.island
        function onHoveredChanged() {
            if (root.island.hovered) {
                closeTimer.stop()
            } else {
                openTimer.stop()
                if (root.shown) closeTimer.restart()
            }
        }
        function onOpenHoveredChanged() {
            if (!root.island.openHovered) root.reopenBlocked = false
            else if (root.island.owner === "" && !root.reopenBlocked) openTimer.restart()
        }
        function onOwnerChanged() {
            if (root.island.owner === "" && root.island.openHovered && !root.reopenBlocked)
                openTimer.restart()
        }
    }

    function toggle() {
        if (shown) {
            island.close(ownerId)
            return
        }
        island.open(ownerId, openWidth, openHeight, typeToSearch, panelRadius)
        island.grabOwner = ownerId
    }

    IpcHandler {
        target: "controlcenter"
        function toggle(): void { root.toggle() }
    }

    IpcHandler {
        target: "screenshot"
        function region(): void { root.takeScreenshot() }
        function screen(): void {
            root.island.close(root.ownerId)
            var mon = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
            Quickshell.execDetached(["sh", "-c",
                'sleep 0.5; grim ' + (mon !== "" ? '-o "$1" ' : '') + '- | wl-copy --type image/png',
                "sh", mon])
        }
        function save(): void {
            root.island.close(root.ownerId)
            var mon = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
            Quickshell.execDetached(["sh", "-c",
                'sleep 0.5; d=$(xdg-user-dir PICTURES 2>/dev/null); [ -n "$d" ] && [ "$d" != "$HOME" ] || d="$HOME/Pictures"; '
                + 'mkdir -p "$d"; f="$d/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"; '
                + 'grim ' + (mon !== "" ? '-o "$1" ' : '') + '"$f" && wl-copy --type image/png < "$f"',
                "sh", mon])
        }
    }

    Timer {
        id: openTimer
        interval: 250
        onTriggered: {
            if (root.island.openHovered && root.island.owner === "" && !root.reopenBlocked)
                root.island.open(root.ownerId, root.openWidth, root.openHeight,
                                 root.typeToSearch, root.panelRadius)
        }
    }

    Timer {
        id: closeTimer
        interval: 300
        onTriggered: {
            if (root.busy) restart()
            else root.island.close(root.ownerId)
        }
    }

    Timer {
        id: focusTimer
        interval: 60
        onTriggered: if (root.typeToSearch) searchInput.forceActiveFocus()
    }

    Column {
        anchors {
            fill: parent
            topMargin: root.topPad
            bottomMargin: root.bottomPad
            leftMargin: root.sidePad
            rightMargin: root.sidePad
        }
        spacing: root.gap

        visible: root.shown && root.page === ""
        FadeIn { active: (root.shown && root.page === ""); pause: 160; duration: 220 }

        Row {
            id: topRow
            width: parent.width
            height: root.tileH
            spacing: root.gap

            readonly property int tiles: root.hasBluetooth ? 2 : 1
            readonly property int circles: root.hasBluetooth ? 2 : 4
            readonly property int tileW: (width - circles * root.circleSize
                                          - (tiles + circles - 1) * spacing) / tiles

            ToggleTile {
                sizeFactor: root.sizeFactor
                cornerRadius: root.cardRadius
                width: topRow.tileW
                height: root.tileH
                kind: root.hasWifi ? "wifi" : "ethernet"
                title: root.hasWifi ? "Wi-Fi" : "Ethernet"
                subtitle: root.hasWifi ? root.wifiStatus : root.wiredStatus
                active: root.hasWifi ? root.wifiOn : root.wiredConnected
                onToggled: if (root.hasWifi) root.toggleWifi()
                onClicked: if (root.hasWifi) root.openPage("wifi")
            }
            ToggleTile {
                visible: root.hasBluetooth
                sizeFactor: root.sizeFactor
                cornerRadius: root.cardRadius
                width: topRow.tileW
                height: root.tileH
                kind: "bluetooth"
                title: "Bluetooth"
                subtitle: root.bluetoothStatus
                active: root.bluetoothOn
                onToggled: root.toggleBluetooth()
                onClicked: root.openPage("bluetooth")
            }
            CircleButton {
                visible: !root.hasBluetooth
                kind: "grid"
                size: root.circleSize
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.launcher.openMode(0)
            }
            CircleButton {
                visible: !root.hasBluetooth
                kind: "palette"
                size: root.circleSize
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.launcher.openMode(1)
            }
            CircleButton {
                kind: "screenshot"
                size: root.circleSize
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.takeScreenshot()
            }
            CircleButton {
                kind: "power"
                size: root.circleSize
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.power.open()
            }
        }

        ControlSlider {
            sizeFactor: root.sizeFactor
            id: volumeSlider
            width: parent.width
            height: root.sliderCardH
            title: "Audio"
            icon: root.audioAvailable && root.sink.audio.muted ? "volume-mute" : "volume"
            value: root.audioAvailable ? root.sink.audio.volume : 0
            muted: root.audioAvailable && root.sink.audio.muted
            available: root.audioAvailable
            iconClickable: true
            onMoved: value => root.setVolume(value)
            onIconClicked: root.toggleMute()
            onDetailsClicked: root.openPage("audio")
        }

        ControlSlider {
            sizeFactor: root.sizeFactor
            id: displaySlider
            visible: root.showDisplay
            onDetailsClicked: root.openPage("display")
            width: parent.width
            height: root.sliderCardH
            title: "Display"
            icon: "sun"
            value: root.displayLevel
            available: root.displayAvailable
            onMoved: value => root.setDisplay(value)
        }

        ControlSlider {
            sizeFactor: root.sizeFactor
            id: keyboardSlider
            showDetails: false
            visible: root.showKeyboard
            width: parent.width
            height: root.sliderCardH
            title: "Keyboard"
            icon: "keyboard"
            value: root.keyboardLevel
            available: root.keyboardAvailable
            onMoved: value => root.setKeyboard(value)
        }

        Card {
            width: parent.width
            height: root.notifCardH
            radius: root.cardRadius

            Item {
                id: notifTop
                anchors {
                    top: parent.top
                    topMargin: root.u(10)
                    left: parent.left
                    right: parent.right
                    leftMargin: root.u(16)
                    rightMargin: root.u(16)
                }
                height: root.u(18)

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notifications" + (root.notifications.history.count > 1
                                         ? "  ·  " + root.notifications.history.count : "")
                    color: Theme.textSecondary
                    font.pixelSize: root.u(10)
                    font.family: Theme.fontFamily
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: root.notifications.history.count > 0
                    text: "Clear all"
                    color: Theme.textMuted
                    font.pixelSize: root.u(10)
                    font.family: Theme.fontFamily

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -root.u(6)
                        onClicked: root.notifications.history.clear()
                    }
                }
            }

            ListView {
                id: notifList
                visible: root.hasNotifications
                anchors {
                    top: notifTop.bottom
                    topMargin: root.u(6)
                    left: parent.left
                    right: parent.right
                    leftMargin: root.u(10)
                    rightMargin: root.u(10)
                }
                height: root.notifListH
                clip: true
                spacing: root.notifSpacing
                model: root.notifications.history
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

                    width: ListView.view.width
                    height: root.notifItemH
                    radius: root.cardRadius - root.u(10)
                    color: entryArea.containsMouse ? Theme.highlight : Theme.surface
                    border.color: "transparent"

                    MouseArea {
                        id: entryArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            root.notifications.focusApp(entry.desktopEntry, entry.app)
                            root.island.close(root.ownerId)
                        }
                    }

                    Item {
                        id: avatar
                        width: root.u(30)
                        height: root.u(30)
                        anchors {
                            left: parent.left
                            leftMargin: root.u(12)
                            verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            visible: !iconBox.visible
                            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22)

                            Text {
                                anchors.centerIn: parent
                                text: entry.app !== "" ? entry.app.charAt(0).toUpperCase() : "?"
                                color: Theme.accent
                                font.pixelSize: root.u(11)
                                font.bold: true
                                font.family: Theme.fontFamily
                            }
                        }

                        ClippingRectangle {
                            id: iconBox
                            anchors.fill: parent
                            radius: entry.rounded ? width / 2 : 0
                            color: "transparent"
                            visible: entry.icon !== "" && iconImage.status === Image.Ready

                            Image {
                                id: iconImage
                                anchors.fill: parent
                                source: entry.icon
                                sourceSize.width: Theme.px(root.u(30), iconImage)
                                sourceSize.height: Theme.px(root.u(30), iconImage)
                                fillMode: entry.rounded ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                                asynchronous: true
                            }
                        }
                    }

                    Column {
                        anchors {
                            left: avatar.right
                            leftMargin: root.u(10)
                            right: closeButton.left
                            rightMargin: root.u(6)
                            verticalCenter: parent.verticalCenter
                        }

                        Text {
                            width: parent.width
                            text: entry.app
                            color: Theme.textMuted
                            font.pixelSize: root.u(9)
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: entry.summary
                            textFormat: Text.PlainText
                            color: Theme.text
                            font.pixelSize: root.u(11)
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
                            font.pixelSize: root.u(10)
                            font.family: Theme.fontFamily
                            elide: Text.ElideRight
                        }
                    }

                    Item {
                        id: closeButton
                        width: root.u(16)
                        height: root.u(16)
                        anchors {
                            right: parent.right
                            rightMargin: root.u(14)
                            verticalCenter: parent.verticalCenter
                        }

                        LineIcon {
                            anchors.centerIn: parent
                            kind: "close"
                            size: root.u(10)
                            color: Theme.textMuted
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -root.u(5)
                            onClicked: root.notifications.history.remove(entry.index)
                        }
                    }
                }
            }

            Text {
                anchors.right: notifTop.right
                anchors.verticalCenter: notifTop.verticalCenter
                visible: !root.hasNotifications
                text: "No notifications"
                color: Theme.textMuted
                font.pixelSize: root.u(10)
                font.family: Theme.fontFamily
            }
        }

        Card {
            width: parent.width
            height: root.searchH
            radius: root.cardRadius

            LineIcon {
                id: searchIcon
                anchors.left: parent.left
                anchors.leftMargin: root.u(14)
                anchors.verticalCenter: parent.verticalCenter
                kind: "search"
                size: root.u(16)
                color: Theme.textMuted
            }

            TextInput {
                id: searchInput
                anchors {
                    fill: parent
                    leftMargin: root.u(40)
                    rightMargin: root.u(16)
                }
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text
                selectionColor: Theme.selection
                font.pixelSize: root.u(14)
                font.family: Theme.fontFamily
                clip: true

                onTextChanged: {
                    if (text !== "") {
                        var typed = text
                        text = ""
                        root.launcher.openWithText(typed)
                    }
                }

                Keys.onEscapePressed: root.island.close(root.ownerId)
            }

            Text {
                anchors.left: searchInput.left
                anchors.verticalCenter: parent.verticalCenter
                visible: searchInput.text === ""
                text: "Search"
                color: Theme.textMuted
                font.pixelSize: root.u(14)
                font.family: Theme.fontFamily
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.launcher.openWithText("")
            }
        }
    }

    WifiPage {
        id: wifiPage
        anchors {
            fill: parent
            topMargin: root.topPad
            bottomMargin: root.bottomPad
            leftMargin: root.sidePad
            rightMargin: root.sidePad
        }
        sizeFactor: root.sizeFactor
        visible: root.shown && root.page === "wifi"
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        onBack: root.closePage()
        onKeyboardWanted: root.requestKeyboard()
    }

    BluetoothPage {
        id: bluetoothPage
        anchors {
            fill: parent
            topMargin: root.topPad
            bottomMargin: root.bottomPad
            leftMargin: root.sidePad
            rightMargin: root.sidePad
        }
        sizeFactor: root.sizeFactor
        visible: root.shown && root.page === "bluetooth"
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        onBack: root.closePage()
    }

    AudioPage {
        id: audioPage
        anchors {
            fill: parent
            topMargin: root.topPad
            bottomMargin: root.bottomPad
            leftMargin: root.sidePad
            rightMargin: root.sidePad
        }
        sizeFactor: root.sizeFactor
        visible: root.shown && root.page === "audio"
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        onBack: root.closePage()
    }

    DisplayPage {
        id: displayPage
        anchors {
            fill: parent
            topMargin: root.topPad
            bottomMargin: root.bottomPad
            leftMargin: root.sidePad
            rightMargin: root.sidePad
        }
        sizeFactor: root.sizeFactor
        visible: root.shown && root.page === "display"
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        onBack: root.closePage()
    }
}
