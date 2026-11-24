import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.widgets

SettingsPage {
    id: page

    icon: "palette"
    title: "Appearance"
    description: "Fonts, icons, the shape of the island and its effects."

    readonly property var animationItems: [
        { value: "pop", label: "Pop", detail: "springs out of its item" },
        { value: "slide", label: "Slide", detail: "glides in from its side" },
        { value: "zoom", label: "Zoom", detail: "grows from its item" },
        { value: "unfold", label: "Unfold", detail: "opens like a menu" },
        { value: "fade", label: "Fade" },
        { value: "none", label: "None" }
    ]
    readonly property var speedItems: [
        { value: "relaxed", label: "Relaxed" },
        { value: "normal", label: "Normal" },
        { value: "snappy", label: "Snappy" }
    ]
    function labelOf(items, value) {
        for (var i = 0; i < items.length; i++) if (items[i].value === value) return items[i].label
        return value
    }

    readonly property var fontItems: {
        var seen = {}
        return Qt.fontFamilies().filter(function (f) {
            if (seen[f] || f === "" || f.charAt(0) === "." || /^Phosphor(-\w+)?$/.test(f)) return false
            seen[f] = true
            return true
        }).sort(function (a, b) { return a.localeCompare(b) }).map(function (f) {
            return { value: f, label: f, sample: "Aa", sampleFont: f }
        })
    }

    property var iconFiles: []

    Process {
        running: true
        command: ["sh", "-c", 'for f in "$1"/Phosphor*.ttf; do [ -f "$f" ] && basename "$f" .ttf; done; true',
                  "sh", Quickshell.shellPath("assets/fonts")]
        stdout: StdioCollector {
            onStreamFinished: page.iconFiles = text.split("\n").filter(function (l) {
                return /^Phosphor(-[A-Za-z]+)?$/.test(l) && !/Duotone/i.test(l)
            })
        }
    }

    Instantiator {
        id: iconLoaders
        model: page.iconFiles
        delegate: FontLoader {
            required property string modelData
            source: "file://" + Quickshell.shellPath("assets/fonts/" + modelData + ".ttf")
            onStatusChanged: if (status === FontLoader.Ready) page.loadedFonts++
            Component.onCompleted: if (status === FontLoader.Ready) page.loadedFonts++
        }
    }
    property int loadedFonts: 0

    function loadedFamily(name) {
        for (var i = 0; i < iconLoaders.count; i++) {
            var l = iconLoaders.objectAt(i)
            if (l && l.modelData === name && l.status === FontLoader.Ready) return l.name
        }
        return Qt.fontFamilies().indexOf(name) >= 0 ? name : ""
    }

    readonly property string sample: [0xe270, 0xe6c8, 0xe4ea, 0xe0da].map(function (c) {
        return String.fromCharCode(c)
    }).join(" ")

    readonly property var iconItems: {
        var ready = loadedFonts
        var names = iconFiles.slice()
        Qt.fontFamilies().forEach(function (f) {
            if (/^Phosphor(-[A-Za-z]+)?$/.test(f) && !/Duotone/i.test(f) && names.indexOf(f) < 0) names.push(f)
        })
        var weight = { "Thin": 1, "Light": 2, "Regular": 3, "Bold": 4, "Fill": 5 }
        var out = names.map(function (n) {
            var style = n === "Phosphor" ? "Regular" : n.substring(9)
            var family = page.loadedFamily(n)
            return { value: n === "Phosphor" ? "phosphor" : n.toLowerCase(), label: "Phosphor " + style,
                     sample: family !== "" ? page.sample : "", sampleFont: family, order: weight[style] || 9 }
        })
        out.sort(function (a, b) { return a.order - b.order || a.label.localeCompare(b.label) })
        out.push({ value: "classic", label: "Classic", detail: "drawn lines" })
        return out
    }

    readonly property string currentIcon: {
        var v = String(Theme.iconFont || "phosphor").toLowerCase()
        return v === "phosphor-regular" ? "phosphor" : v
    }

    SectionTitle {
        sizeFactor: SettingsUi.factor
        text: "Shape"
    }

    SliderRow {
        title: "Corner radius"
        info: "Roundness of every corner of the shell: island, bar, panels, cards, buttons. Lower values turn the circles into rounded squares, 0 makes everything square."
        from: 0
        to: 30
        step: 1
        value: Theme.cornerBase
        format: function (v) { return Theme.s(v) + " px" }
        onCommitted: v => Settings.set("cornerRadius", Math.round(v))

        actions: [
            IconButton {
                visible: Theme.cornerBase !== 15
                icon: "reboot"
                tip: "Back to the default radius"
                onClicked: Settings.set("cornerRadius", 15)
            },
            PillButton {
                readonly property bool remembered: SettingsUi.hyprMemory.rounding !== undefined
                height: SettingsUi.u(24)
                icon: Theme.hyprRounding ? (remembered ? "reboot" : "close") : "monitor"
                text: Theme.hyprRounding ? (remembered ? "Undo" : "Unlink") : "Hyprland"
                tip: Theme.hyprRounding
                    ? (remembered ? "Give the windows of Hyprland back the corners they had before"
                                  : "Stop following this radius: Hyprland goes back to its own config")
                    : "Round the windows of Hyprland like the shell, and keep them in sync"
                onClicked: Theme.hyprRounding ? SettingsUi.undoHypr("rounding") : SettingsUi.linkHypr("rounding")
            }
        ]
    }

    SliderRow {
        title: "Distance from the edges"
        info: "Space between the floating island or the floating bar and the edges of the screen, at the top and at the sides."
        from: 0
        to: 30
        step: 1
        value: Theme.edgeGapBase
        format: function (v) { return Theme.s(v) + " px" }
        onCommitted: v => Settings.set("edgeGap", Math.round(v))

        actions: [
            IconButton {
                visible: Theme.edgeGapBase !== 5
                icon: "reboot"
                tip: "Back to the default distance"
                onClicked: Settings.set("edgeGap", 5)
            },
            PillButton {
                readonly property bool remembered: SettingsUi.hyprMemory.gaps !== undefined
                height: SettingsUi.u(24)
                icon: Theme.hyprGaps ? (remembered ? "reboot" : "close") : "monitor"
                text: Theme.hyprGaps ? (remembered ? "Undo" : "Unlink") : "Hyprland"
                tip: Theme.hyprGaps
                    ? (remembered ? "Give Hyprland back the outer gaps it had before"
                                  : "Stop following this distance: Hyprland goes back to its own config")
                    : "Set the outer gaps of Hyprland (windows to screen edges) to this distance, and keep them in sync"
                onClicked: Theme.hyprGaps ? SettingsUi.undoHypr("gaps") : SettingsUi.linkHypr("gaps")
            }
        ]
    }

    SectionTitle {
        sizeFactor: SettingsUi.factor
        text: "Text and icons"
    }

    OptionRow {
        title: "Font"
        info: "Font of the whole shell. The list shows every font installed on this computer."

        Row {
            spacing: SettingsUi.u(8)

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: Theme.fontFamily !== "Inter"
                icon: "reboot"
                tip: "Back to the default font (Inter)"
                onClicked: Settings.set("fontFamily", "Inter")
            }

            Dropdown {
                text: Theme.fontFamily
                textFont: Theme.fontFamily
                items: page.fontItems
                current: Theme.fontFamily
                searchable: true
                menuWidth: SettingsUi.u(280)
                onPicked: value => Settings.set("fontFamily", value)
            }
        }
    }

    OptionRow {
        title: "Icons"
        info: "Style of the icons. The shell uses the Phosphor icon set: every Phosphor weight found in assets/fonts or installed on the computer is listed. Classic draws simple line icons."

        Row {
            spacing: SettingsUi.u(8)

            IconButton {
                anchors.verticalCenter: parent.verticalCenter
                visible: page.currentIcon !== "phosphor"
                icon: "reboot"
                tip: "Back to the default icons (Phosphor Regular)"
                onClicked: Settings.set("iconFont", "phosphor")
            }

            Dropdown {
                text: {
                    for (var i = 0; i < page.iconItems.length; i++)
                        if (page.iconItems[i].value === page.currentIcon) return page.iconItems[i].label
                    return Theme.iconFont
                }
                items: page.iconItems
                current: page.currentIcon
                menuWidth: SettingsUi.u(240)
                onPicked: value => Settings.set("iconFont", value)
            }
        }
    }

    SectionTitle {
        sizeFactor: SettingsUi.factor
        text: "Layout"
    }

    Row {
        width: parent.width
        spacing: SettingsUi.u(6)

        ChoiceCard {
            id: islandCard
            width: (parent.width - SettingsUi.u(6)) / 2
            title: "Island"
            current: !Theme.barMode
            onClicked: Settings.set("layout", "island")

            MiniBar {
                kind: Theme.floatingIsland ? "islandFloating" : "islandAttached"
                ink: islandCard.current ? Theme.accent : Theme.textMuted
            }
        }

        ChoiceCard {
            id: barCard
            width: (parent.width - SettingsUi.u(6)) / 2
            title: "Bar"
            current: Theme.barMode
            onClicked: Settings.set("layout", "bar")

            MiniBar {
                kind: Theme.barStyle
                ink: barCard.current ? Theme.accent : Theme.textMuted
            }
        }
    }

    SectionTitle {
        visible: !Theme.barMode
        sizeFactor: SettingsUi.factor
        text: "Island"
    }

    Row {
        visible: !Theme.barMode
        width: parent.width
        spacing: SettingsUi.u(6)

        Repeater {
            model: [
                { value: "floating", label: "Floating" },
                { value: "attached", label: "Attached" }
            ]

            delegate: Rectangle {
                id: styleCard
                required property var modelData
                readonly property bool current: (Theme.floatingIsland ? "floating" : "attached") === modelData.value

                width: (parent.width - SettingsUi.u(6)) / 2
                height: preview.height + caption.implicitHeight + 3 * SettingsUi.u(12)
                radius: SettingsUi.radius
                color: styleArea.containsMouse && !current ? Theme.surface : Theme.card
                border.width: current ? 2 : 1
                border.color: current ? Theme.accent : Theme.cardBorder
                Behavior on color { ColorAnimation { duration: 120 } }

                Rectangle {
                    id: preview
                    x: SettingsUi.u(12)
                    y: SettingsUi.u(12)
                    width: parent.width - 2 * SettingsUi.u(12)
                    height: SettingsUi.u(64)
                    radius: SettingsUi.radius
                    color: Theme.track
                    clip: true

                    MiniBar {
                        kind: styleCard.modelData.value === "floating" ? "islandFloating" : "islandAttached"
                        ink: styleCard.current ? Theme.accent : Theme.textMuted
                    }
                }

                Column {
                    id: caption
                    anchors.top: preview.bottom
                    anchors.topMargin: SettingsUi.u(10)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 2 * SettingsUi.u(12)
                    spacing: SettingsUi.u(2)

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: styleCard.modelData.label
                        color: styleCard.current ? Theme.accent : Theme.text
                        font.pixelSize: SettingsUi.u(11)
                        font.weight: Font.DemiBold
                        font.family: Theme.fontFamily
                    }
                }

                MouseArea {
                    id: styleArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: styleCard.current ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: if (!styleCard.current) Settings.set("islandStyle", styleCard.modelData.value)
                }
            }
        }
    }

    ToggleRow {
        visible: !Theme.barMode
        title: "Minimal"
        info: "At rest the island shows only the clock; the other icons appear when the mouse is over it."
        key: "minimal"
        checked: Theme.minimalIsland
    }

    ToggleRow {
        visible: !Theme.barMode
        title: "Full audio panel"
        info: "The audio button of the island opens the playing media together with all the outputs, inputs and app volumes, like the bar. Off: it opens only the media player."
        key: "audioPanel"
        checked: Theme.audioPanel
    }

    SectionTitle {
        visible: Theme.barMode
        sizeFactor: SettingsUi.factor
        text: "Bar"
    }

    ToggleRow {
        visible: Theme.barMode && Theme.barStyle !== "transparent" && !Theme.barPills
        title: "Panels fused to the bar"
        info: "The panels of the bar buttons grow out of the bar. Off: they open as separate floating cards, next to their button, like the notifications."
        key: "barFused"
        checked: Theme.barFused
    }

    Grid {
        visible: Theme.barMode
        width: parent.width
        columns: 3
        spacing: SettingsUi.u(6)

        Repeater {
            model: [
                { value: "floating", label: "Floating" },
                { value: "attached", label: "Attached" },
                { value: "integrated", label: "Integrated" },
                { value: "transparent", label: "Transparent" },
                { value: "pills", label: "Pills" },
                { value: "pillsAttached", label: "Attached pills" }
            ]

            delegate: ChoiceCard {
                id: styleChoice
                required property var modelData
                width: (parent.width - 2 * SettingsUi.u(6)) / 3
                previewHeight: SettingsUi.u(48)
                title: modelData.label
                current: Theme.barStyle === modelData.value
                onClicked: {
                    var v = modelData.value
                    Settings.edit(function (s) {
                        var was = s.barStyle === "transparent"
                        if (v === "transparent" && !was && s.glass !== true) {
                            s.glass = true
                            s.glassAuto = true
                        } else if (v !== "transparent" && was && s.glassAuto === true) {
                            s.glass = false
                            s.glassAuto = false
                        }
                        s.barStyle = v
                    })
                }

                readonly property color ink: current ? Theme.accent : Theme.textMuted

                MiniBar {
                    kind: styleChoice.modelData.value
                    ink: styleChoice.ink
                }
            }
        }
    }

    ToggleRow {
        visible: Theme.barMode && Theme.barStyle === "integrated"
        title: "Curved ends"
        info: "The ends of the bar curve into the sides of the monitor. Off: the bar is a straight strip along the whole edge."
        key: "barCurves"
        checked: Theme.barCurves
    }

    ToggleRow {
        visible: Theme.barMode && ((Theme.barStyle === "integrated" && Theme.barCurves) || Theme.barStyle === "pillsAttached")
        title: "Screen frame"
        info: "A thin frame of the bar color around the whole screen, with rounded inner corners."
        key: "barFrame"
        checked: Theme.barFrame
    }

    SliderRow {
        visible: Theme.barMode && (Theme.barStyle === "floating" || Theme.barStyle === "attached")
        title: "Bar width"
        info: "Length of the bar along its edge, as a share of the screen. It never gets shorter than its items."
        from: 20
        to: 100
        step: 5
        value: Theme.barLength * 100
        format: function (v) { return Math.round(v) + "%" }
        onCommitted: v => Settings.set("barLength", Math.round(v))
    }

    OptionRow {
        visible: Theme.barMode
        title: "Position"
        info: "Edge of the screen where the bar sits."

        Segmented {
            options: [
                { value: "top", label: "Top" }, { value: "bottom", label: "Bottom" },
                { value: "left", label: "Left" }, { value: "right", label: "Right" }
            ]
            current: Theme.barPosition
            onPicked: value => Settings.set("barPosition", value)
        }
    }

    SectionTitle {
        visible: Theme.barMode
        sizeFactor: SettingsUi.factor
        text: "Bar items"
    }

    BarDesigner {
        visible: Theme.barMode
        lists: Controls.barSections
        pills: Theme.barPills
        dividers: Theme.barStyle === "pills"
        pool: Controls.barKinds.filter(function (k) {
            var s = Controls.barSections
            return Controls.barAvailable(k) && s.start.indexOf(k) < 0 && s.center.indexOf(k) < 0 && s.end.indexOf(k) < 0
        })
        onEdited: lists => Settings.set("barItems", { start: lists.start, center: lists.center, end: lists.end })
    }

    ToggleRow {
        visible: Theme.barMode
        title: "Weekday in the clock"
        info: "Shows the day of the week next to the time, e.g. Sun."
        key: "clockWeekday"
        checked: Theme.clockWeekday
    }

    ToggleRow {
        visible: Theme.barMode
        title: "Day in the clock"
        info: "Shows the day of the month next to the time, e.g. 22."
        key: "clockDay"
        checked: Theme.clockDay
    }

    ToggleRow {
        visible: Theme.barMode
        title: "Month in the clock"
        info: "Shows the month next to the time, e.g. Nov."
        key: "clockMonth"
        checked: Theme.clockMonth
    }

    ToggleRow {
        visible: Theme.barMode
        title: "Show empty workspaces"
        info: "Bar workspaces: also show the empty workspaces between the used ones, as dimmer dots. Off: only the workspaces with windows and the current one."
        key: "showEmptyWorkspaces"
        checked: Theme.showEmptyWorkspaces
    }

    OptionRow {
        visible: Theme.barMode
        title: "Notifications"
        subtitle: Theme.toastSeparate ? "Where notifications appear" : "Where notifications, volume, brightness and media appear"
        info: "With the bar, the popups appear in this place of the screen. With pills they grow the pill on that side, or the pill of the bell."

        ToastPicker {
            current: Theme.toastPosition
            onPicked: value => Settings.set("toastPosition", value)
        }
    }

    ToggleRow {
        visible: Theme.barMode
        title: "Separate positions"
        info: "Off: notifications, media and the volume and brightness bar appear in the same place. On: each of the three has its own place."
        key: "toastSeparate"
        checked: Theme.toastSeparate
    }

    OptionRow {
        visible: Theme.barMode && Theme.toastSeparate
        title: "Media"
        subtitle: "Where the media player appears"
        info: "The media player that appears when a song changes or with the media keys."

        ToastPicker {
            current: Theme.mediaPosition
            onPicked: value => Settings.set("mediaPosition", value)
        }
    }

    OptionRow {
        visible: Theme.barMode && Theme.toastSeparate
        title: "Volume and brightness"
        subtitle: "Where the volume and brightness bar appears"
        info: "The bar that appears when the volume or the brightness changes."

        ToastPicker {
            current: Theme.osdPosition
            onPicked: value => Settings.set("osdPosition", value)
        }
    }

    OptionRow {
        visible: Theme.barMode
        title: "Card animation"
        info: "How the panels that appear on their own come in: the launcher in the middle of the screen, the panels not fused to the bar and the notifications, media and volume cards."

        Dropdown {
            text: page.labelOf(page.animationItems, Theme.popupAnimation)
            items: page.animationItems
            current: Theme.popupAnimation
            menuWidth: SettingsUi.u(240)
            onPicked: value => Settings.set("popupAnimation", value)
        }
    }

    OptionRow {
        visible: Theme.barMode && Theme.popupAnimation !== "none"
        title: "Animation speed"
        info: "Speed of the card animation."

        Dropdown {
            readonly property string value: Theme.popupSpeed > 1 ? "relaxed" : Theme.popupSpeed < 1 ? "snappy" : "normal"
            text: page.labelOf(page.speedItems, value)
            items: page.speedItems
            current: value
            menuWidth: SettingsUi.u(180)
            onPicked: value => Settings.set("popupSpeed", value)
        }
    }

    SectionTitle {
        sizeFactor: SettingsUi.factor
        text: "Effects"
    }

    ToggleRow {
        title: "Auto hide"
        info: "The island or the bar hides when windows are open. Move the mouse to its edge of the screen to bring it back."
        key: "autoHide"
        checked: Theme.autoHide
    }

    ToggleRow {
        title: "Glow"
        info: "A soft glow in the color of the theme around the island or the bar and the windows. When the dark shadow is also on, the shadow covers it."
        key: "glowEnabled"
        checked: Theme.glowEnabled
    }

    ToggleRow {
        title: "Dark shadow"
        info: "A classic dark shadow around the island or the bar and the windows. When it is on it replaces the glow."
        key: "darkShadow"
        checked: Theme.darkShadow
    }

    SectionTitle {
        sizeFactor: SettingsUi.factor
        text: "Glass"
    }

    ToggleRow {
        title: "Glass"
        info: "Liquid glass: translucent, blurred surfaces with a light-catching rim. Bar and panels melt into one piece."
        key: "glass"
        checked: Theme.glass
    }

    SliderRow {
        active: Theme.glass
        title: "Glass opacity"
        info: "How opaque the glass is: lower values let more of the background show through."
        from: 0.3
        to: 1
        step: 0.05
        value: Theme.glassOpacity
        format: function (v) { return Math.round(v * 100) + "%" }
        onCommitted: v => Settings.set("glassOpacity", Math.round(v * 100) / 100)
    }
}
