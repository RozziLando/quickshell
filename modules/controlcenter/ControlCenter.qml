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

    function shownHere(id) {
        if (id === "display") return root.showDisplay
        if (id === "keyboard") return root.showKeyboard
        return true
    }
    readonly property var gridEntries: Controls.grid.filter(function (e) { return root.shownHere(e.id) })
    readonly property var bottomIds: Controls.bottom.filter(function (id) { return root.itemHeight(id) > 0 })
    readonly property var sections: Controls.sections.filter(shownHere)
    readonly property bool hasTiles: Controls.tiles.length > 0

    function sectionItem(id) {
        return ({
            "audio": volumeSlider,
            "display": displaySlider,
            "keyboard": keyboardSlider,
            "notifications": notifCard,
            "search": searchCard,
            "apps": appsCard,
            "clock": clockCard
        })[id] || null
    }

    function itemHeight(id) {
        if (Controls.isTile(id)) return tileH
        var item = sectionItem(id)
        return item ? item.height : 0
    }

    readonly property int innerW: openWidth - 2 * sidePad
    readonly property var sectionLayout: {
        var out = Controls.gridLayout(gridEntries, innerW, gap, itemHeight)
        var y = out.total > 0 ? out.total + gap : 0, last = out.total
        bottomIds.forEach(function (id) {
            out[id] = { x: 0, y: y, w: root.innerW, h: root.itemHeight(id) }
            last = y + root.itemHeight(id)
            y = last + root.gap
        })
        out.total = last
        return out
    }

    function sectionShown(id) { return sectionLayout[id] !== undefined }
    function sectionY(id) { return sectionLayout[id] ? sectionLayout[id].y : 0 }
    function sectionX(id) { return sectionLayout[id] ? sectionLayout[id].x : 0 }
    function sectionW(id) { return sectionLayout[id] ? sectionLayout[id].w : innerW }

    readonly property int mainH: Math.max(root.u(20), sectionLayout.total)
    readonly property int pageH: pageLoader.item && pageLoader.item.naturalHeight !== undefined
        ? Math.max(root.u(160), Math.min(root.u(500), pageLoader.item.naturalHeight)) : mainH
    readonly property int openHeight: topPad + (page !== "" ? pageH : mainH) + bottomPad

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
        var none = false
        try { none = Networking.backend === NetworkBackendType.None } catch (e) {}
        if (none) return "Unknown"
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

        Item {
            visible: root.hasTiles
            anchors.fill: parent

            Repeater {
                model: Controls.tiles
                delegate: Loader {
                    required property string modelData
                    readonly property var g: root.sectionLayout[modelData]
                    visible: g !== undefined
                    x: g ? g.x : 0
                    y: g ? g.y : 0
                    width: g ? g.w : 0
                    height: root.tileH
                    sourceComponent: Controls.tileInfo[modelData].slots === 2 ? wideTile : circleTile
                    property string tileId: modelData
                    property int wideW: width
                }
            }

            Component {
                id: wideTile
                ToggleTile {
                    readonly property string tileId: parent ? parent.tileId : ""
                    readonly property bool net: tileId === "network"
                    readonly property bool mode: tileId === "powermode"
                    sizeFactor: root.sizeFactor
                    cornerRadius: root.cardRadius
                    width: parent ? parent.wideW : 0
                    height: root.tileH
                    kind: mode ? Controls.powerMode.icon : net ? (root.hasWifi ? "wifi" : "ethernet") : "bluetooth"
                    title: mode ? "Power" : net ? (root.hasWifi ? "Wi-Fi" : "Ethernet") : "Bluetooth"
                    subtitle: mode ? Controls.powerMode.label : net ? (root.hasWifi ? root.wifiStatus : root.wiredStatus) : root.bluetoothStatus
                    active: mode ? true : net ? (root.hasWifi ? root.wifiOn : root.wiredConnected) : root.bluetoothOn
                    onToggled: {
                        if (mode) Controls.cyclePower()
                        else if (!net) root.toggleBluetooth()
                        else if (root.hasWifi) root.toggleWifi()
                    }
                    onClicked: {
                        if (mode) Controls.cyclePower()
                        else if (!net) root.openPage("bluetooth")
                        else if (root.hasWifi) root.openPage("wifi")
                    }
                }
            }

            Component {
                id: circleTile
                Item {
                    id: circleSlot
                    readonly property string tileId: parent ? parent.tileId : ""

                    CircleButton {
                        anchors.centerIn: parent
                        kind: Controls.tileInfo[circleSlot.tileId] ? Controls.tileInfo[circleSlot.tileId].icon : ""
                        size: root.circleSize
                        onClicked: root.activateTile(circleSlot.tileId)
                    }
                }
            }
        }

        ControlSlider {
            sizeFactor: root.sizeFactor
            id: volumeSlider
            x: root.sectionX("audio")
            y: root.sectionY("audio")
            width: root.sectionW("audio")
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
            x: root.sectionX("display")
            y: root.sectionY("display")
            visible: root.sectionShown("display")
            onDetailsClicked: root.openPage("display")
            width: root.sectionW("display")
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
            x: root.sectionX("keyboard")
            y: root.sectionY("keyboard")
            showDetails: false
            visible: root.sectionShown("keyboard")
            width: root.sectionW("keyboard")
            height: root.sliderCardH
            title: "Keyboard"
            icon: "keyboard"
            value: root.keyboardLevel
            available: root.keyboardAvailable
            onMoved: value => root.setKeyboard(value)
        }

        NotificationCard {
            id: notifCard
            x: root.sectionX("notifications")
            y: root.sectionY("notifications")
            visible: root.sectionShown("notifications")
            width: root.sectionW("notifications")
            notifications: root.notifications
            sizeFactor: root.sizeFactor
            cardRadius: root.cardRadius
            onActivated: root.island.close(root.ownerId)
        }

        BackgroundApps {
            id: appsCard
            x: root.sectionX("apps")
            width: root.sectionW("apps")
            y: root.sectionY("apps")
            here: Controls.appsInControl
            active: root.shown
            radius: root.cardRadius
            sizeFactor: root.sizeFactor
        }

        ClockCard {
            id: clockCard
            x: root.sectionX("clock")
            y: root.sectionY("clock")
            visible: root.sectionShown("clock")
            active: root.shown
            width: root.sectionW("clock")
            height: root.sliderCardH
            sizeFactor: root.sizeFactor
        }


        Card {
            id: searchCard
            x: root.sectionX("search")
            y: root.sectionY("search")
            visible: root.sectionShown("search")
            width: root.sectionW("search")
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
