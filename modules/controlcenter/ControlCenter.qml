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
import qs.modules.system

Item {
    id: root
    required property var island
    required property var launcher
    required property var notifications
    required property var power
    width: shown ? parent.width : openWidth
    height: shown ? parent.height : openHeight

    readonly property string ownerId: "control"
    readonly property bool shown: island.owner === ownerId

    readonly property bool typeToSearch: sectionShown("search")
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
    readonly property int searchH: root.u(44)
    readonly property int cardRadius: Theme.radius
    readonly property int panelRadius: cardRadius + edgePad * Theme.roundness

    readonly property var batteryDevice: UPower.displayDevice
    readonly property bool desktop: !(batteryDevice && batteryDevice.ready
                                      && batteryDevice.isLaptopBattery && batteryDevice.isPresent)
    readonly property bool hasBluetooth: !!btAdapter
    readonly property bool showDisplay: !desktop || Theme.displayOnDesktop
    readonly property bool showKeyboard: !desktop && keyboardAvailable

    readonly property var sections: Controls.sections.filter(function (id) {
        if (id === "display") return root.showDisplay
        if (id === "keyboard") return root.showKeyboard
        return true
    })
    readonly property bool hasTiles: Controls.tiles.length > 0

    function sectionItem(id) {
        return ({
            "audio": volumeSlider,
            "display": displaySlider,
            "keyboard": keyboardSlider,
            "notifications": notifCard,
            "search": searchCard,
            "apps": appsCard
        })[id] || null
    }

    readonly property var sectionLayout: {
        var y = hasTiles ? tileH + gap : 0, out = {}, last = 0
        for (var i = 0; i < sections.length; i++) {
            var item = sectionItem(sections[i])
            if (!item) continue
            var h = sections[i] === "apps" ? appsCard.height : item.height
            if (h <= 0) continue
            out[sections[i]] = y
            y += h + gap
            last = y - gap
        }
        out.total = Math.max(hasTiles ? tileH : 0, last)
        return out
    }

    function sectionShown(id) { return sectionLayout[id] !== undefined }

    readonly property int openHeight: topPad + Math.max(root.u(20), sectionLayout.total) + bottomPad

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
        || (pageLoader.item && pageLoader.item.busy === true)

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
            if (root.page !== "" && pageLoader.item) pageLoader.item.forceActiveFocus()
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
        }
    }

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled
    }

    function toggleBluetooth() {
        if (btAdapter) btAdapter.enabled = !btAdapter.enabled
    }

    function activateTile(id) {
        if (id === "launcher") root.launcher.openMode(0)
        else if (id === "themes") root.launcher.openMode(1)
        else if (id === "screenshot") root.takeScreenshot()
        else if (id === "power") root.power.open()
        else if (id === "settings") {
            island.close(ownerId)
            Controls.settingsRequested("")
        }
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
            } else if (root.shown) {
                closeTimer.restart()
            }
        }
    }

    readonly property bool allowed: Theme.controlCenter
    onAllowedChanged: if (!allowed && shown) island.close(ownerId)

    function toggle() {
        if (shown) {
            island.close(ownerId)
            return
        }
        if (!allowed) return
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

    Item {
        id: mainArea
        anchors {
            fill: parent
            topMargin: root.topPad
            bottomMargin: root.bottomPad
            leftMargin: root.sidePad
            rightMargin: root.sidePad
        }

        visible: root.shown && root.page === ""
        FadeIn { active: (root.shown && root.page === ""); pause: 160; duration: 220 }

        Row {
            id: topRow
            visible: root.hasTiles
            width: parent.width
            height: root.tileH
            spacing: root.gap

            readonly property int tiles: Controls.tiles.filter(function (id) { return Controls.tileInfo[id].slots === 2 }).length
            readonly property int circles: Controls.tiles.length - tiles
            readonly property int tileW: tiles > 0
                ? (width - circles * root.circleSize - (tiles + circles - 1) * spacing) / tiles : 0
            readonly property int usedW: tiles > 0 ? width
                : circles * root.circleSize + Math.max(0, circles - 1) * spacing
            x: (parent.width - usedW) / 2

            Repeater {
                model: Controls.tiles
                delegate: Loader {
                    required property string modelData
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: Controls.tileInfo[modelData].slots === 2 ? wideTile : circleTile
                    property string tileId: modelData
                }
            }

            Component {
                id: wideTile
                ToggleTile {
                    readonly property string tileId: parent ? parent.tileId : ""
                    readonly property bool net: tileId === "network"
                    sizeFactor: root.sizeFactor
                    cornerRadius: root.cardRadius
                    width: topRow.tileW
                    height: root.tileH
                    kind: net ? (root.hasWifi ? "wifi" : "ethernet") : "bluetooth"
                    title: net ? (root.hasWifi ? "Wi-Fi" : "Ethernet") : "Bluetooth"
                    subtitle: net ? (root.hasWifi ? root.wifiStatus : root.wiredStatus) : root.bluetoothStatus
                    active: net ? (root.hasWifi ? root.wifiOn : root.wiredConnected) : root.bluetoothOn
                    onToggled: {
                        if (!net) root.toggleBluetooth()
                        else if (root.hasWifi) root.toggleWifi()
                    }
                    onClicked: {
                        if (!net) root.openPage("bluetooth")
                        else if (root.hasWifi) root.openPage("wifi")
                    }
                }
            }

            Component {
                id: circleTile
                CircleButton {
                    readonly property string tileId: parent ? parent.tileId : ""
                    kind: Controls.tileInfo[tileId] ? Controls.tileInfo[tileId].icon : ""
                    size: root.circleSize
                    onClicked: root.activateTile(tileId)
                }
            }
        }

        ControlSlider {
            sizeFactor: root.sizeFactor
            id: volumeSlider
            y: root.sectionLayout["audio"] || 0
            width: parent.width
            height: root.sliderCardH
            visible: root.sectionShown("audio")
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
            y: root.sectionLayout["display"] || 0
            visible: root.sectionShown("display")
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
            y: root.sectionLayout["keyboard"] || 0
            showDetails: false
            visible: root.sectionShown("keyboard")
            width: parent.width
            height: root.sliderCardH
            title: "Keyboard"
            icon: "keyboard"
            value: root.keyboardLevel
            available: root.keyboardAvailable
            onMoved: value => root.setKeyboard(value)
        }

        NotificationCard {
            id: notifCard
            y: root.sectionLayout["notifications"] || 0
            visible: root.sectionShown("notifications")
            width: parent.width
            notifications: root.notifications
            sizeFactor: root.sizeFactor
            cardRadius: root.cardRadius
            onActivated: root.island.close(root.ownerId)
        }

        BackgroundApps {
            id: appsCard
            y: root.sectionLayout["apps"] || 0
            here: Controls.appsInControl
            active: root.shown
            radius: root.cardRadius
            sizeFactor: root.sizeFactor
        }

        Card {
            id: searchCard
            y: root.sectionLayout["search"] || 0
            visible: root.sectionShown("search")
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

    Component {
        id: wifiComponent
        WifiPage {
            sizeFactor: root.sizeFactor
            onBack: root.closePage()
            onKeyboardWanted: root.requestKeyboard()
        }
    }
    Component {
        id: bluetoothComponent
        BluetoothPage {
            sizeFactor: root.sizeFactor
            onBack: root.closePage()
        }
    }
    Component {
        id: audioComponent
        AudioPage {
            sizeFactor: root.sizeFactor
            onBack: root.closePage()
        }
    }
    Component {
        id: displayComponent
        DisplayPage {
            sizeFactor: root.sizeFactor
            onBack: root.closePage()
        }
    }

    Loader {
        id: pageLoader
        anchors {
            fill: parent
            topMargin: root.topPad
            bottomMargin: root.bottomPad
            leftMargin: root.sidePad
            rightMargin: root.sidePad
        }
        active: root.page !== ""
        sourceComponent: ({ "wifi": wifiComponent, "bluetooth": bluetoothComponent,
                            "audio": audioComponent, "display": displayComponent })[root.page] || null
        visible: root.shown && root.page !== ""
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
    }
}
