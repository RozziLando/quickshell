import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services
import qs.widgets

Scope {
    id: root

    readonly property string windowTitle: "Quickshell Settings"
    readonly property int baseWidth: 800
    readonly property int baseHeight: 560

    PersistentProperties {
        id: persist
        reloadableId: "quickshellSettings"
        property bool open: false
        property string page: "general"
        onPageChanged: {
            SettingsUi.closeMenu()
            SettingsUi.tip = null
        }
    }

    readonly property var pages: [
        { id: "general", label: "General", icon: "gear" },
        { id: "appearance", label: "Appearance", icon: "palette" },
        { id: "control", label: "Control Center", icon: "sliders" },
        { id: "lock", label: "Login & Lock", icon: "lock" },
        { id: "wallpapers", label: "Wallpapers & Themes", icon: "image" },
        { id: "system", label: "System", icon: "cpu" }
    ]

    function show(page) {
        if (page && pages.some(function (p) { return p.id === page })) persist.page = page
        if (persist.open) {
            focusWindow()
            return
        }
        applyRule()
        persist.open = true
    }

    function hide() {
        SettingsUi.closeMenu()
        SettingsUi.tip = null
        SettingsUi.hyprMemory = ({})
        persist.open = false
    }

    function focusWindow() {
        var selector = "title:^" + windowTitle + "$"
        if (Hyprland.usingLua)
            Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.focus({ window = "' + selector + '" })'])
        else
            Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", selector])
    }

    IpcHandler {
        target: "settings"
        function open(): void { root.show("") }
        function page(name: string): void { root.show(name) }
        function close(): void { root.hide() }
        function toggle(): void {
            if (persist.open) root.hide()
            else root.show("")
        }
    }

    function applyRule() {
        if (!Hyprland.usingLua) {
            ruleProc.command = ["hyprctl", "--batch",
                "keyword windowrule float on, center on, match:title ^(" + windowTitle + ")$"
                + " ; keyword windowrulev2 float, title:^(" + windowTitle + ")$"
                + " ; keyword windowrulev2 center, title:^(" + windowTitle + ")$"]
            ruleProc.running = true
            return
        }
        ruleProc.command = ["hyprctl", "eval",
            'hl.window_rule({ name = "quickshell-settings", match = { class = "^org.quickshell$", title = "^'
            + windowTitle + '$" }, float = true, center = true, rounding = ' + Theme.radius + ' })']
        ruleProc.running = true
    }
    Process { id: ruleProc }

    Component.onCompleted: applyRule()
    Connections {
        target: Controls
        function onSettingsRequested(page) { root.show(page) }
    }
    Connections {
        target: Theme
        function onRadiusChanged() { root.applyRule() }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "configreloaded") root.applyRule()
        }
    }

    LazyLoader {
        active: persist.open

        FloatingWindow {
            id: win

            title: root.windowTitle
            color: Theme.glass ? "transparent" : Theme.panel

            property real fit: 1
            Component.onCompleted: {
                Updater.check(false)
                var m = Hyprland.focusedMonitor
                if (!m || !(m.width > 0) || !(m.scale > 0)) return
                var w = m.width / m.scale, h = m.height / m.scale
                if (m.lastIpcObject && m.lastIpcObject.transform % 2 === 1) {
                    var t = w
                    w = h
                    h = t
                }
                fit = Math.min(0.92 * w / root.baseWidth, 0.9 * h / root.baseHeight)
            }

            readonly property real factor: Math.min(1, fit / Theme.scale)
            Binding {
                target: SettingsUi
                property: "factor"
                value: win.factor
            }

            implicitWidth: SettingsUi.u(root.baseWidth)
            implicitHeight: SettingsUi.u(root.baseHeight)
            minimumSize: Qt.size(implicitWidth, implicitHeight)
            maximumSize: Qt.size(implicitWidth, implicitHeight)

            onVisibleChanged: if (!visible && persist.open) root.hide()

            GlassRect {
                visible: Theme.glass
                anchors.fill: parent
                radius: Theme.radius
            }

            Item {
                id: content
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: {
                    if (SettingsUi.menu) SettingsUi.closeMenu()
                    else root.hide()
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onPressed: mouse => {
                        SettingsUi.closeMenu()
                        SettingsUi.tip = null
                        if (!win.startSystemMove()) mouse.accepted = false
                    }
                }

                Item {
                    id: sidebar
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: SettingsUi.u(214)

                    Text {
                        id: heading
                        x: SettingsUi.u(18)
                        y: SettingsUi.u(18)
                        text: "Settings"
                        color: Theme.text
                        font.pixelSize: SettingsUi.u(16)
                        font.bold: true
                        font.family: Theme.fontFamily
                    }

                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: SettingsUi.u(8)
                        anchors.verticalCenter: heading.verticalCenter
                        width: SettingsUi.u(26)
                        height: width
                        radius: Theme.round(width)
                        color: closeArea.containsMouse ? Theme.warning : Theme.highlight
                        Behavior on color { ColorAnimation { duration: 120 } }

                        LineIcon {
                            anchors.centerIn: parent
                            kind: "close"
                            size: SettingsUi.u(11)
                            color: closeArea.containsMouse ? Theme.background : Theme.textSecondary
                        }

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.hide()
                        }
                    }

                    Column {
                        anchors.top: heading.bottom
                        anchors.topMargin: SettingsUi.u(14)
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: SettingsUi.u(10)
                        anchors.rightMargin: SettingsUi.u(4)
                        spacing: SettingsUi.u(4)

                        Repeater {
                            model: root.pages
                            delegate: Rectangle {
                                id: navItem
                                required property var modelData
                                readonly property bool current: persist.page === modelData.id

                                width: parent.width
                                height: SettingsUi.u(40)
                                radius: SettingsUi.radius
                                color: current ? Theme.card : navArea.containsMouse ? Theme.surface : "transparent"
                                border.width: current ? 1 : 0
                                border.color: Theme.cardBorder
                                Behavior on color { ColorAnimation { duration: 120 } }

                                Rectangle {
                                    id: badge
                                    x: SettingsUi.u(5)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: SettingsUi.u(30)
                                    height: width
                                    radius: Theme.round(width)
                                    color: navItem.current ? Theme.accent : Theme.highlight
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    LineIcon {
                                        anchors.centerIn: parent
                                        kind: navItem.modelData.icon
                                        size: SettingsUi.u(15)
                                        color: navItem.current ? Theme.background : Theme.text
                                    }
                                }

                                Text {
                                    anchors.left: badge.right
                                    anchors.leftMargin: SettingsUi.u(10)
                                    anchors.right: parent.right
                                    anchors.rightMargin: SettingsUi.u(8)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: navItem.modelData.label
                                    color: navItem.current ? Theme.text : Theme.textSoft
                                    font.pixelSize: SettingsUi.u(11)
                                    font.weight: navItem.current ? Font.DemiBold : Font.Normal
                                    font.family: Theme.fontFamily
                                    elide: Text.ElideRight
                                }

                                MouseArea {
                                    id: navArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        SettingsUi.closeMenu()
                                        SettingsUi.tip = null
                                        persist.page = navItem.modelData.id
                                    }
                                }
                            }
                        }
                    }

                    ProfileCard {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: SettingsUi.u(10)
                        anchors.rightMargin: SettingsUi.u(4)
                        anchors.bottomMargin: SettingsUi.u(10)
                    }
                }

                Rectangle {
                    id: panel
                    anchors.left: sidebar.right
                    anchors.leftMargin: SettingsUi.u(6)
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: SettingsUi.u(10)
                    radius: SettingsUi.radius
                    color: Theme.glass ? Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.35) : Theme.background
                    border.width: 1
                    border.color: Theme.cardBorder
                    clip: true

                    Loader {
                        anchors.fill: parent
                        anchors.margins: 1
                        sourceComponent: ({
                            "general": generalPage,
                            "appearance": appearancePage,
                            "control": controlPage,
                            "lock": lockPage,
                            "wallpapers": wallpaperPage,
                            "system": systemPage
                        })[persist.page] || generalPage
                    }

                    Component { id: generalPage; GeneralPage {} }
                    Component { id: appearancePage; AppearancePage {} }
                    Component { id: controlPage; ControlPage {} }
                    Component { id: lockPage; LockPage {} }
                    Component { id: wallpaperPage; WallpaperPage {} }
                    Component { id: systemPage; SystemPage {} }
                }

                FilePicker {
                    id: picker
                    Component.onCompleted: SettingsUi.picker = picker
                }

                MenuLayer { z: 10 }
                TipLayer { z: 11 }
            }
        }
    }
}
