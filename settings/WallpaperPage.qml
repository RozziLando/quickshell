import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.widgets
import "../services/wallmatch.js" as WallMatch

SettingsPage {
    id: page

    icon: "image"
    title: "Wallpapers & Themes"
    description: "Wallpaper and colors. The pencil links themes and wallpapers."

    readonly property var wallpapers: ThemeManager.wallpapers
    readonly property var themes: ThemeManager.themes.map(function (t) {
        var c = t.colors || {}
        return {
            id: t.id,
            name: t.name,
            colors: c,
            dots: t.terminal && t.terminal.ansi && t.terminal.ansi.length >= 7
                  ? t.terminal.ansi.slice(1, 7) : [c.warning, c.accent, c.text]
        }
    })

    readonly property string currentThemeName: {
        var t = ThemeManager.find(ThemeManager.current)
        return t ? t.name : ThemeManager.current
    }

    property string startedWith: ""
    property bool wallpaperChosen: false
    Timer {
        id: sessionTimer
        interval: 30000
        onTriggered: {
            page.startedWith = ""
            page.wallpaperChosen = false
        }
    }

    onVisibleChanged: if (visible) enter()
    Component.onCompleted: enter()

    property bool settled: false
    Timer {
        id: settleTimer
        interval: 600
        onTriggered: page.settled = true
    }

    function enter() {
        settled = false
        settleTimer.restart()
        startedWith = ""
        wallpaperChosen = false
        ThemeManager.refresh()
        ThemeManager.refreshWallpapers()
        selectCurrentWallpaper()
        selectCurrentTheme()
    }

    function selectWallpaper(name) {
        for (var i = 0; i < wallpapers.length; i++)
            if (wallpapers[i].name === name) { wallpaperList.currentIndex = i; return }
    }
    function selectCurrentWallpaper() {
        Qt.callLater(function () { page.selectWallpaper(ThemeManager.currentWallpaper) })
    }
    function selectTheme(id) {
        for (var i = 0; i < themes.length; i++)
            if (themes[i].id === id) { themeList.currentIndex = i; return }
    }
    function selectCurrentTheme() {
        Qt.callLater(function () { page.selectTheme(ThemeManager.current) })
    }

    Connections {
        target: ThemeManager
        function onCurrentWallpaperChanged() { page.selectCurrentWallpaper() }
        function onCurrentChanged() { page.selectCurrentTheme() }
    }

    function applyWallpaper(item) {
        if (!item) return
        wallpaperChosen = true
        sessionTimer.restart()
        if (startedWith === "") startedWith = "wallpaper"
        ThemeManager.setWallpaper(item.path)
        if (startedWith === "theme") {
            analyzer.cancel()
            return
        }
        var fav = ThemeManager.favoriteThemeFor(item.path)
        if (fav !== "") {
            analyzer.cancel()
            ThemeManager.apply(fav, true)
            selectTheme(fav)
            return
        }
        analyzer.analyze(item.path, function (pixels) {
            var id = ThemeManager.bestThemeFor(pixels, item.path)
            if (id) {
                ThemeManager.apply(id, true)
                page.selectTheme(id)
            }
        })
    }

    function applyTheme(item) {
        if (!item) return
        analyzer.cancel()
        sessionTimer.restart()
        if (startedWith === "") startedWith = "theme"
        var wall = ThemeManager.apply(item.id, wallpaperChosen)
        if (wall) selectWallpaper(wall)
    }

    property var pendingEdit: null

    function editWallpaper(item, anchor) {
        pendingEdit = { item: item, anchor: anchor }
        rankTimer.restart()
        ranker.analyze(item.path, function (pixels) {
            rankTimer.stop()
            page.openWallpaperMenu(WallMatch.rank(pixels, ThemeManager.themes))
        })
    }

    Timer {
        id: rankTimer
        interval: 1500
        onTriggered: {
            ranker.cancel()
            page.openWallpaperMenu([])
        }
    }

    function themeItem(t, detail) {
        return { value: t.id, label: t.name, dots: t.dots, detail: detail || "" }
    }

    function openWallpaperMenu(ranked) {
        var edit = pendingEdit
        pendingEdit = null
        if (!edit || !edit.anchor) return
        var name = edit.item.name
        var items = [{ value: "", label: "Automatic", detail: "matches the colors" }]
        var used = {}
        ranked.slice(0, 3).forEach(function (r) {
            var t = page.findTheme(r.id)
            if (t) {
                items.push(page.themeItem(t, "suggested"))
                used[t.id] = true
            }
        })
        themes.forEach(function (t) { if (!used[t.id]) items.push(page.themeItem(t, "")) })
        SettingsUi.openMenu({
            anchor: edit.anchor,
            title: "Themes for " + name,
            hint: "This wallpaper applies one of these themes.",
            items: items,
            current: ThemeManager.themesFor(name),
            multi: true,
            searchable: true,
            width: SettingsUi.u(280),
            pick: function (list) { Settings.setEntry("wallpaperThemes", name, list) }
        })
    }

    function editTheme(item, anchor) {
        var items = [{ value: "", label: "Automatic", detail: "the theme's own" }]
        wallpapers.forEach(function (w) { items.push({ value: w.name, label: w.name, image: w }) })
        SettingsUi.openMenu({
            anchor: anchor,
            title: "Wallpapers for " + item.name,
            hint: "This theme sets one of these wallpapers.",
            items: items,
            current: ThemeManager.wallpapersFor(item.id),
            multi: true,
            searchable: true,
            width: SettingsUi.u(300),
            pick: function (list) { Settings.setEntry("themeWallpapers", item.id, list) }
        })
    }

    function findTheme(id) {
        for (var i = 0; i < themes.length; i++)
            if (themes[i].id === id) return themes[i]
        return null
    }

    function addWallpapers() {
        SettingsUi.picker.open("images", "Add wallpapers", Quickshell.env("HOME") + "/Pictures", function (paths) {
            copyProc.command = ["sh", "-c",
                'd="$1"; shift; mkdir -p "$d" || exit 1;'
                + ' for f in "$@"; do [ -f "$f" ] || continue;'
                + '  b=$(basename "$f"); t="$d/$b";'
                + '  s="${b%.*}"; e="${b##*.}"; n=0; same="";'
                + '  while [ -e "$t" ]; do'
                + '   if cmp -s "$f" "$t"; then same=1; break; fi;'
                + '   n=$((n + 1)); t="$d/$s-$n.$e";'
                + '  done;'
                + '  if [ -n "$same" ]; then echo "$t"; continue; fi;'
                + '  cp "$f" "$t" && echo "$t";'
                + ' done',
                "sh", Theme.wallpaperDir].concat(paths)
            copyProc.running = true
        })
    }

    property string addedFirst: ""

    Process {
        id: copyProc
        stdout: StdioCollector {
            onStreamFinished: {
                var added = text.split("\n").filter(function (l) { return l !== "" })
                page.addedFirst = added.length > 0 ? added[0].split("/").pop() : ""
                ThemeManager.refreshWallpapers()
            }
        }
    }

    Connections {
        target: ThemeManager
        function onWallpapersChanged() {
            if (page.addedFirst === "") return
            var name = page.addedFirst
            page.addedFirst = ""
            Qt.callLater(function () { page.selectWallpaper(name) })
        }
    }

    property bool hasTransitions: true
    Process {
        running: true
        command: ["sh", "-c", "command -v awww >/dev/null 2>&1 || command -v swww >/dev/null 2>&1"]
        onExited: code => page.hasTransitions = code === 0
    }

    readonly property var transitions: [
        { value: "grow", label: "Grow", detail: "from the center" },
        { value: "outer", label: "Outer", detail: "toward the center" },
        { value: "wave", label: "Wave" },
        { value: "wipe", label: "Wipe" },
        { value: "fade", label: "Fade" },
        { value: "simple", label: "Simple", detail: "quick fade" },
        { value: "left", label: "Left" },
        { value: "right", label: "Right" },
        { value: "top", label: "Top" },
        { value: "bottom", label: "Bottom" },
        { value: "center", label: "Center" },
        { value: "any", label: "Any", detail: "random position" },
        { value: "random", label: "Random", detail: "a different one each time" },
        { value: "none", label: "None", detail: "instant" }
    ]

    overlay: [
        WallpaperAnalyzer { id: analyzer },
        WallpaperAnalyzer { id: ranker }
    ]

    Item {
        width: parent.width
        height: SettingsUi.u(30)

        Row {
            anchors.left: parent.left
            anchors.leftMargin: SettingsUi.u(4)
            anchors.right: addButton.left
            anchors.rightMargin: SettingsUi.u(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: SettingsUi.u(8)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Wallpaper"
                color: Theme.text
                font.pixelSize: SettingsUi.u(12)
                font.weight: Font.DemiBold
                font.family: Theme.fontFamily
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x
                text: ThemeManager.currentWallpaper
                color: Theme.textMuted
                font.pixelSize: SettingsUi.u(10)
                font.family: Theme.fontFamily
                elide: Text.ElideRight
            }
        }

        Rectangle {
            id: addButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: SettingsUi.u(28)
            height: width
            radius: Theme.round(width)
            color: addArea.containsMouse ? Theme.accent : Theme.highlight
            Behavior on color { ColorAnimation { duration: 120 } }

            LineIcon {
                anchors.centerIn: parent
                kind: "plus"
                size: SettingsUi.u(14)
                color: addArea.containsMouse ? Theme.background : Theme.text
            }

            MouseArea {
                id: addArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: page.addWallpapers()
                onContainsMouseChanged: {
                    if (containsMouse) SettingsUi.showTip(addButton, "Add wallpapers to " + SettingsUi.home(Theme.wallpaperDir))
                    else SettingsUi.hideTip(addButton)
                }
            }
        }
    }

    Item {
        width: parent.width
        height: SettingsUi.u(96)

        PathView {
            id: wallpaperList
            readonly property int cardW: SettingsUi.u(150)
            readonly property int step: cardW + SettingsUi.u(12)
            anchors.fill: parent
            clip: true
            model: page.wallpapers
            currentIndex: 0
            pathItemCount: Math.min(count, Math.ceil(width / step) + 2)
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightRangeMode: PathView.StrictlyEnforceRange
            highlightMoveDuration: page.settled ? 220 : 0
            snapMode: PathView.SnapToItem
            path: Path {
                startX: wallpaperList.width / 2 - wallpaperList.pathItemCount * wallpaperList.step / 2
                startY: wallpaperList.height / 2
                PathLine {
                    x: wallpaperList.width / 2 + wallpaperList.pathItemCount * wallpaperList.step / 2
                    y: wallpaperList.height / 2
                }
            }
            onCountChanged: {
                if (!page.settled) settleTimer.restart()
                page.selectCurrentWallpaper()
            }

            Timer { id: wpWheel; interval: 140 }
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    if (wpWheel.running) return
                    var d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                    if (d < 0) wallpaperList.incrementCurrentIndex()
                    else if (d > 0) wallpaperList.decrementCurrentIndex()
                    wpWheel.restart()
                }
            }

            delegate: Item {
                id: wpCard
                required property var modelData
                required property int index
                readonly property bool selected: PathView.isCurrentItem
                readonly property bool active: modelData.name === ThemeManager.currentWallpaper
                readonly property bool paired: ThemeManager.themesFor(modelData.name).length > 0

                width: wallpaperList.cardW
                height: SettingsUi.u(86)
                y: (wallpaperList.height - height) / 2
                opacity: selected ? 1 : 0.55
                Behavior on opacity { NumberAnimation { duration: 160 } }

                WallpaperThumb {
                    anchors.fill: parent
                    radius: SettingsUi.radius
                    wallpaper: wpCard.modelData
                }

                Rectangle {
                    anchors.fill: parent
                    radius: SettingsUi.radius
                    color: "transparent"
                    border.width: wpCard.selected ? 2 : 1
                    border.color: wpCard.selected ? Theme.accent : Qt.rgba(1, 1, 1, 0.08)
                }

                Rectangle {
                    visible: wpCard.active
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: SettingsUi.u(8)
                    width: SettingsUi.u(7)
                    height: width
                    radius: Theme.round(width)
                    color: Theme.accent
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.4)
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (wpCard.selected) page.applyWallpaper(wpCard.modelData)
                        else wallpaperList.currentIndex = wpCard.index
                    }
                }

                PencilButton {
                    id: wpPencil
                    visible: wpCard.selected
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: SettingsUi.u(6)
                    paired: wpCard.paired
                    tip: "Themes for this wallpaper"
                    onClicked: page.editWallpaper(wpCard.modelData, wpPencil)
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: page.wallpapers.length === 0
            text: "No wallpapers in " + SettingsUi.home(Theme.wallpaperDir) + ": add some with +"
            color: Theme.textMuted
            font.pixelSize: SettingsUi.u(10)
            font.family: Theme.fontFamily
        }
    }

    Item {
        width: parent.width
        height: SettingsUi.u(30)

        Row {
            anchors.left: parent.left
            anchors.leftMargin: SettingsUi.u(4)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: SettingsUi.u(8)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Theme"
                color: Theme.text
                font.pixelSize: SettingsUi.u(12)
                font.weight: Font.DemiBold
                font.family: Theme.fontFamily
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - x
                text: page.currentThemeName
                color: Theme.textMuted
                font.pixelSize: SettingsUi.u(10)
                font.family: Theme.fontFamily
                elide: Text.ElideRight
            }
        }
    }

    Item {
        width: parent.width
        height: SettingsUi.u(88)

        PathView {
            id: themeList
            readonly property int cardW: SettingsUi.u(150)
            readonly property int step: cardW + SettingsUi.u(12)
            anchors.fill: parent
            clip: true
            model: page.themes
            currentIndex: 0
            pathItemCount: Math.min(count, Math.ceil(width / step) + 2)
            preferredHighlightBegin: 0.5
            preferredHighlightEnd: 0.5
            highlightRangeMode: PathView.StrictlyEnforceRange
            highlightMoveDuration: page.settled ? 220 : 0
            snapMode: PathView.SnapToItem
            path: Path {
                startX: themeList.width / 2 - themeList.pathItemCount * themeList.step / 2
                startY: themeList.height / 2
                PathLine {
                    x: themeList.width / 2 + themeList.pathItemCount * themeList.step / 2
                    y: themeList.height / 2
                }
            }
            onCountChanged: {
                if (!page.settled) settleTimer.restart()
                page.selectCurrentTheme()
            }

            Timer { id: themeWheel; interval: 140 }
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    if (themeWheel.running) return
                    var d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                    if (d < 0) themeList.incrementCurrentIndex()
                    else if (d > 0) themeList.decrementCurrentIndex()
                    themeWheel.restart()
                }
            }

            delegate: Rectangle {
                id: card
                required property var modelData
                required property int index
                readonly property bool active: modelData.id === ThemeManager.current
                readonly property bool selected: PathView.isCurrentItem
                readonly property var c: modelData.colors
                readonly property bool paired: ThemeManager.wallpapersFor(modelData.id).length > 0

                width: themeList.cardW
                height: SettingsUi.u(78)
                y: (themeList.height - height) / 2
                radius: SettingsUi.radius
                color: c.card || Theme.card
                border.width: selected ? 2 : 1
                border.color: selected ? (c.accent || Theme.accent) : (c.cardBorder || Theme.cardBorder)
                opacity: selected ? 1 : 0.55
                Behavior on opacity { NumberAnimation { duration: 160 } }

                Rectangle {
                    visible: card.active
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: SettingsUi.u(8)
                    width: SettingsUi.u(6)
                    height: width
                    radius: Theme.round(width)
                    color: card.c.accent || Theme.accent
                }

                Column {
                    anchors.centerIn: parent
                    spacing: SettingsUi.u(12)

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: SettingsUi.u(5)
                        Repeater {
                            model: card.modelData.dots
                            delegate: Rectangle {
                                required property var modelData
                                width: SettingsUi.u(13)
                                height: width
                                radius: Theme.round(width)
                                color: modelData || "transparent"
                            }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: card.modelData.id
                        color: card.selected ? (card.c.text || Theme.text) : (card.c.textSecondary || Theme.textSecondary)
                        font.pixelSize: SettingsUi.u(11)
                        font.weight: card.selected ? Font.DemiBold : Font.Normal
                        font.family: Theme.fontFamily
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (card.selected) page.applyTheme(card.modelData)
                        else themeList.currentIndex = card.index
                    }
                }

                PencilButton {
                    id: themePencil
                    visible: card.selected
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: SettingsUi.u(6)
                    paired: card.paired
                    tint: card.c.accent || Theme.accent
                    base: card.c.background || Theme.background
                    ink: card.c.text || Theme.text
                    tip: "Wallpapers for this theme"
                    onClicked: page.editTheme(card.modelData, themePencil)
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: page.themes.length === 0
            text: "No themes found"
            color: Theme.textMuted
            font.pixelSize: SettingsUi.u(10)
            font.family: Theme.fontFamily
        }
    }

    SectionTitle {
        sizeFactor: SettingsUi.factor
        text: "Wallpapers"
    }

    OptionRow {
        title: "Folder"
        info: "Wallpaper folder (png, jpg, webp)."

        Dropdown {
            text: SettingsUi.home(Theme.wallpaperDir)
            icon: "folder"
            onClicked: SettingsUi.picker.open("dir", "Wallpaper folder", Theme.wallpaperDir, function (paths) {
                Settings.set("wallpaperDir", SettingsUi.home(paths[0]))
            })
        }
    }

    OptionRow {
        visible: page.hasTransitions
        title: "Transition"
        info: "Wallpaper change animation."

        Dropdown {
            text: {
                for (var i = 0; i < page.transitions.length; i++)
                    if (page.transitions[i].value === Theme.wallpaperTransition) return page.transitions[i].label
                return Theme.wallpaperTransition
            }
            items: page.transitions
            current: Theme.wallpaperTransition
            menuWidth: SettingsUi.u(240)
            onPicked: value => Settings.set("wallpaperTransition", value)
        }
    }
}
