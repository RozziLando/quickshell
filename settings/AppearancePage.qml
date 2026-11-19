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
        text: "Text and icons"
    }

    OptionRow {
        title: "Font"
        info: "Font of the whole shell. The list shows every font installed on this computer."

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

    OptionRow {
        title: "Icons"
        info: "Style of the icons. The shell uses the Phosphor icon set: every Phosphor weight found in assets/fonts or installed on the computer is listed. Classic draws simple line icons."

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

    SectionTitle {
        sizeFactor: SettingsUi.factor
        text: "Island"
    }

    Row {
        width: parent.width
        spacing: SettingsUi.u(6)

        Repeater {
            model: [
                { value: "floating", label: "Floating", info: "Detached from the top edge, with the side circles" },
                { value: "attached", label: "Attached", info: "Joined to the top edge of the screen" }
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

                    readonly property int islandW: SettingsUi.u(70)
                    readonly property int islandH: SettingsUi.u(14)

                    Rectangle {
                        visible: styleCard.modelData.value === "floating"
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: SettingsUi.u(7)
                        width: preview.islandW
                        height: preview.islandH
                        radius: height / 2
                        color: styleCard.current ? Theme.accent : Theme.textMuted
                    }
                    Repeater {
                        model: styleCard.modelData.value === "floating" ? [-1, 1] : []
                        delegate: Rectangle {
                            required property int modelData
                            width: preview.islandH
                            height: width
                            radius: width / 2
                            y: SettingsUi.u(7)
                            x: preview.width / 2 + modelData * (preview.islandW / 2 + SettingsUi.u(5) + width / 2) - width / 2
                            color: styleCard.current ? Theme.accent : Theme.textMuted
                            opacity: 0.7
                        }
                    }

                    Rectangle {
                        visible: styleCard.modelData.value === "attached"
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: -radius
                        width: preview.islandW + SettingsUi.u(16)
                        height: preview.islandH + SettingsUi.u(6) + radius
                        radius: SettingsUi.u(9)
                        color: styleCard.current ? Theme.accent : Theme.textMuted
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
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: styleCard.modelData.info
                        color: Theme.textSecondary
                        font.pixelSize: SettingsUi.u(9)
                        font.family: Theme.fontFamily
                        wrapMode: Text.WordWrap
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
        title: "Minimal"
        info: "At rest the island shows only the clock; the other icons appear when the mouse is over it."
        key: "minimal"
        checked: Theme.minimalIsland
    }

    ToggleRow {
        title: "Auto hide"
        info: "The island hides when windows are open. Move the mouse to the top edge of the screen to bring it back."
        key: "autoHide"
        checked: Theme.autoHide
    }

    ToggleRow {
        title: "Glow"
        info: "A soft glow in the color of the theme around the island and the windows. When the dark shadow is also on, the shadow covers it."
        key: "glowEnabled"
        checked: Theme.glowEnabled
    }

    ToggleRow {
        title: "Dark shadow"
        info: "A classic dark shadow around the island and the windows. When it is on it replaces the glow."
        key: "darkShadow"
        checked: Theme.darkShadow
    }

    SectionTitle {
        sizeFactor: SettingsUi.factor
        text: "Glass"
    }

    ToggleRow {
        title: "Glass"
        info: "Translucent island and panels: what is behind them shows through."
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
