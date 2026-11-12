import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.services
import qs.widgets

Item {
    id: root
    required property var island
    anchors.fill: parent

    readonly property string ownerId: "launcher"
    readonly property bool shown: island.owner === ownerId

    readonly property real sizeFactor: 0.81
    function u(value) { return Theme.s(value * sizeFactor) }

    readonly property int openWidth: root.u(640)
    readonly property int innerRadius: root.u(17)
    readonly property int panelRadius: innerRadius + edgePad
    readonly property int edgePad: root.u(14)
    readonly property int rowWidth: openWidth - 2 * (edgePad + island.topRadius)
    readonly property int openHeight: mode === "themes" ? root.u(44 + 222) + 2 * edgePad
                                                        : root.u(340)
    onOpenHeightChanged: {
        if (!shown) return
        resizeGuard.restart()
        grabActive = false
        island.open(ownerId, openWidth, openHeight, true, panelRadius)
    }
    Timer { id: resizeGuard; interval: 400 }

    property string terminal: Quickshell.env("TERMINAL") || "kitty"
    Process {
        running: !Quickshell.env("TERMINAL")
        command: ["sh", "-c", "for t in kitty foot alacritty wezterm ghostty ptyxis"
                  + " gnome-terminal kgx konsole xfce4-terminal xterm; do"
                  + " command -v \"$t\" >/dev/null 2>&1 && { echo \"$t\"; exit; }; done"]
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() !== "") root.terminal = text.trim()
        }
    }

    readonly property var modes: [
        { id: "apps",   icon: "grid",    placeholder: "Search apps..." },
        { id: "themes", icon: "palette", placeholder: "Search wallpapers and themes..." }
    ]
    property int modeIndex: 0
    readonly property string mode: modes[modeIndex].id

    function nextMode(step) {
        modeIndex = (modeIndex + step + modes.length) % modes.length
        list.currentIndex = 0
        if (mode === "themes") enterThemes(false)
        search.forceActiveFocus()
    }

    function enterThemes(deferSelect) {
        ThemeManager.refresh()
        ThemeManager.refreshWallpapers()
        focusRow = "wallpapers"
        selectCurrentWallpaper()
        if (deferSelect) {
            themeList.currentIndex = 0
            selectLater.restart()
        } else {
            selectCurrentTheme()
        }
    }
    Timer {
        id: selectLater
        interval: 150
        onTriggered: if (root.shown && root.mode === "themes") root.selectCurrentTheme()
    }

    function toggle() {
        if (shown) { island.close(ownerId); return }
        modeIndex = 0
        island.open(ownerId, openWidth, openHeight, true, panelRadius)
    }

    property string initialText: ""

    property int pendingMode: 0
    property bool switchedIn: false
    function openMode(index) {
        pendingMode = index
        switchedIn = island.owner !== "" && island.owner !== ownerId
        modeIndex = index
        island.open(ownerId, openWidth, openHeight, true, panelRadius)
    }

    function openWithText(value) {
        initialText = value
        modeIndex = 0
        island.open(ownerId, openWidth, openHeight, true, panelRadius)
    }

    onShownChanged: {
        if (shown) {
            wallpaperChosen = false
            startedWith = ""
            search.text = initialText
            search.cursorPosition = search.text.length
            initialText = ""
            if (pendingMode !== 0) {
                if (mode === "themes") enterThemes(!switchedIn)
                pendingMode = 0
            } else {
                modeIndex = 0
            }
            list.currentIndex = 0
            focusTimer.restart()
        } else {
            list.pointerX = -1
            list.pointerY = -1
            grabActive = false
            switchedIn = false
            selectLater.stop()
            pendingMode = 0
        }
    }

    Timer {
        id: focusTimer
        interval: 60
        onTriggered: search.forceActiveFocus()
    }

    property bool grabActive: false
    Timer {
        id: grabDelay
        interval: 200
        running: root.shown && !root.grabActive
        onTriggered: root.grabActive = root.shown
    }

    HyprlandFocusGrab {
        windows: [root.island]
        active: root.grabActive
        onCleared: {
            if (resizeGuard.running) return
            if (root.shown) root.island.close(root.ownerId)
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle() }
    }

    function inTerminal(args) {
        var name = terminal.split("/").pop()
        if (["kitty", "foot", "footclient"].indexOf(name) >= 0)
            return [terminal].concat(args)
        if (["gnome-terminal", "kgx", "ptyxis", "gnome-console"].indexOf(name) >= 0)
            return [terminal, "--"].concat(args)
        if (name === "wezterm")
            return [terminal, "start", "--"].concat(args)
        if (name === "xfce4-terminal")
            return [terminal, "-x"].concat(args)
        return [terminal, "-e"].concat(args)
    }

    FileView {
        id: usageFile
        path: Quickshell.statePath("launcher-usage.json")
        onLoadFailed: error => writeAdapter()
        adapter: JsonAdapter {
            id: usage
            property var counts: ({})
        }
    }

    function useCount(id) {
        return usage.counts[id] || 0
    }

    function recordUse(id) {
        var c = Object.assign({}, usage.counts)
        c[id] = (c[id] || 0) + 1
        usage.counts = c
        usageFile.writeAdapter()
    }

    function filterApps(query) {
        var apps = DesktopEntries.applications.values
        var q = query.trim().toLowerCase()
        var out = []

        for (var i = 0; i < apps.length; i++) {
            var a = apps[i]
            if (a.noDisplay) continue

            var score = -1
            if (q === "") {
                score = 0
            } else {
                var name = a.name.toLowerCase()
                var extra = ((a.genericName || "") + " " + (a.comment || "") + " "
                             + (a.keywords ? a.keywords.join(" ") : "")).toLowerCase()
                if (name.startsWith(q)) score = 0
                else if (name.indexOf(q) >= 0) score = 1
                else if (extra.indexOf(q) >= 0) score = 2
            }
            if (score >= 0) out.push({ e: a, score: score, uses: useCount(a.id) })
        }

        out.sort(function (x, y) {
            if (x.score !== y.score) return x.score - y.score
            if (x.uses !== y.uses) return y.uses - x.uses
            return x.e.name.localeCompare(y.e.name)
        })

        return out.map(function (o) {
            return {
                kind: "app",
                title: o.e.name,
                subtitle: "",
                iconKind: "grid",
                entry: o.e
            }
        })
    }

    function filterThemes(query) {
        var q = query.trim().toLowerCase()
        return ThemeManager.themes.filter(function (t) {
            return q === "" || t.name.toLowerCase().indexOf(q) >= 0 || t.id.indexOf(q) >= 0
        }).map(function (t) {
            var c = t.colors || {}
            return {
                kind: "theme",
                id: t.id,
                title: t.name,
                colors: c,
                dots: t.terminal && t.terminal.ansi && t.terminal.ansi.length >= 7
                      ? t.terminal.ansi.slice(1, 7)
                      : [c.warning, c.accent, c.text]
            }
        })
    }

    readonly property var wallpaperResults: {
        var q = search.text.trim().toLowerCase()
        return ThemeManager.wallpapers.filter(function (w) {
            return q === "" || w.name.toLowerCase().indexOf(q) >= 0
        })
    }

    function selectWallpaper(name) {
        var r = wallpaperResults
        for (var i = 0; i < r.length; i++)
            if (r[i].name === name) { wallpaperList.currentIndex = i; return }
    }

    function selectCurrentWallpaper() {
        Qt.callLater(function () {
            var r = wallpaperResults
            for (var i = 0; i < r.length; i++) {
                if (r[i].name === ThemeManager.currentWallpaper) {
                    wallpaperList.currentIndex = i
                    return
                }
            }
        })
    }

    Connections {
        target: ThemeManager
        function onCurrentWallpaperChanged() { if (root.mode === "themes") root.selectCurrentWallpaper() }
    }

    property string focusRow: "wallpapers"

    property bool wallpaperChosen: false
    property string startedWith: ""

    function applyWallpaper(item) {
        if (!item) return
        wallpaperChosen = true
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
        analyzer.analyze(Theme.fileUrl(item.path), item.path)
    }

    Canvas {
        id: analyzer
        width: 64
        height: 36
        opacity: 0.01
        z: -1
        property string source: ""
        property string path: ""

        function analyze(url, file) {
            if (source !== "" && source !== url) unloadImage(source)
            source = url
            path = file
            if (isImageLoaded(url)) requestPaint()
            else loadImage(url)
        }

        function cancel() {
            if (source !== "") unloadImage(source)
            source = ""
            path = ""
        }

        onImageLoaded: if (source !== "" && isImageLoaded(source)) requestPaint()

        onPaint: {
            if (source === "" || !isImageLoaded(source)) return
            var ctx = getContext("2d")
            ctx.reset()
            ctx.drawImage(source, 0, 0, width, height)
            var d = ctx.getImageData(0, 0, width, height).data
            unloadImage(source)
            source = ""
            var id = ThemeManager.bestThemeFor(d, path)
            if (id) {
                ThemeManager.apply(id, true)
                root.selectTheme(id)
            }
        }
    }

    function selectTheme(id) {
        var r = filterThemes(search.text)
        for (var i = 0; i < r.length; i++)
            if (r[i].id === id) { themeList.currentIndex = i; return }
    }

    function selectCurrentTheme() {
        var r = filterThemes(search.text)
        for (var i = 0; i < r.length; i++)
            if (r[i].id === ThemeManager.current) { themeList.currentIndex = i; return }
        themeList.currentIndex = 0
    }

    readonly property var results: mode === "apps" ? filterApps(search.text)
                                                   : filterThemes(search.text)
    readonly property var activeList: mode !== "themes" ? list
        : focusRow === "wallpapers" ? wallpaperList : themeList

    function activate() {
        if (mode === "themes" && focusRow === "wallpapers") {
            applyWallpaper(wallpaperResults[wallpaperList.currentIndex])
        } else {
            launch(results[activeList.currentIndex])
        }
    }

    function launch(item) {
        if (!item) return
        if (item.kind === "theme") {
            analyzer.cancel()
            if (startedWith === "") startedWith = "theme"
            var wall = ThemeManager.apply(item.id, wallpaperChosen)
            if (wall) selectWallpaper(wall)
            return
        }
        if (item.kind === "app") {
            recordUse(item.entry.id)
            if (item.entry.runInTerminal)
                Quickshell.execDetached(inTerminal(item.entry.command))
            else
                item.entry.execute()
        }
        island.close(ownerId)
    }

    Column {
        anchors {
            fill: parent
            topMargin: root.edgePad
            leftMargin: root.edgePad + root.island.topRadius
            rightMargin: root.edgePad + root.island.topRadius
            bottomMargin: root.edgePad
        }
        spacing: root.u(10)

        visible: root.shown
        FadeIn { active: root.shown; instant: root.switchedIn; pause: 140; duration: 200 }

        Item {
            width: parent.width
            height: root.u(34)

            Rectangle {
                id: searchBox
                anchors.left: appsButton.right
                anchors.leftMargin: root.u(8)
                anchors.right: appearanceButton.left
                anchors.rightMargin: root.u(8)
                height: parent.height
                radius: height / 2
                color: Theme.surface

                LineIcon {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: root.u(14)
                    anchors.verticalCenter: parent.verticalCenter
                    kind: "search"
                    size: root.u(15)
                    color: Theme.textMuted
                }

                TextInput {
                    id: search
                    anchors {
                        fill: parent
                        leftMargin: root.u(38)
                        rightMargin: root.u(16)
                    }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    selectionColor: Theme.selection
                    font.pixelSize: root.u(14)
                    font.family: Theme.fontFamily
                    clip: true

                    onTextChanged: {
                        list.currentIndex = 0
                        themeList.currentIndex = 0
                        wallpaperList.currentIndex = 0
                    }

                    Keys.onEscapePressed: root.island.close(root.ownerId)
                    Keys.onDownPressed: {
                        if (root.mode === "themes") root.focusRow = "themes"
                        else root.activeList.incrementCurrentIndex()
                    }
                    Keys.onUpPressed: {
                        if (root.mode === "themes") root.focusRow = "wallpapers"
                        else root.activeList.decrementCurrentIndex()
                    }
                    Keys.onRightPressed: event => {
                        if (root.mode === "themes") root.activeList.incrementCurrentIndex()
                        else event.accepted = false
                    }
                    Keys.onLeftPressed: event => {
                        if (root.mode === "themes") root.activeList.decrementCurrentIndex()
                        else event.accepted = false
                    }
                    Keys.onReturnPressed: root.activate()
                    Keys.onEnterPressed: root.activate()
                    Keys.onTabPressed: root.nextMode(1)
                    Keys.onBacktabPressed: root.nextMode(-1)

                    Keys.onPressed: event => {
                        if (event.modifiers & Qt.ControlModifier) {
                            if (event.key === Qt.Key_N) {
                                root.activeList.incrementCurrentIndex(); event.accepted = true
                            } else if (event.key === Qt.Key_P) {
                                root.activeList.decrementCurrentIndex(); event.accepted = true
                            }
                        }
                    }
                }

                Text {
                    anchors.left: search.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: search.text === ""
                    text: root.modes[root.modeIndex].placeholder
                    color: Theme.textMuted
                    font.pixelSize: root.u(14)
                    font.family: Theme.fontFamily
                }
            }

            Rectangle {
                id: appsButton
                readonly property bool current: root.modeIndex === 0
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: root.u(34)
                height: width
                radius: width / 2
                color: current ? Theme.accent
                     : (appsButtonArea.containsMouse ? Theme.highlight : Theme.surface)
                Behavior on color { ColorAnimation { duration: 150 } }

                LineIcon {
                    anchors.centerIn: parent
                    kind: "grid"
                    size: root.u(15)
                    color: appsButton.current ? Theme.background : Theme.text
                }

                MouseArea {
                    id: appsButtonArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.nextMode(0 - root.modeIndex)
                }
            }

            Rectangle {
                id: appearanceButton
                readonly property bool current: root.modeIndex === 1
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: root.u(34)
                height: width
                radius: width / 2
                color: current ? Theme.accent
                     : (appearanceButtonArea.containsMouse ? Theme.highlight : Theme.surface)
                Behavior on color { ColorAnimation { duration: 150 } }

                LineIcon {
                    anchors.centerIn: parent
                    kind: "palette"
                    size: root.u(15)
                    color: appearanceButton.current ? Theme.background : Theme.text
                }

                MouseArea {
                    id: appearanceButtonArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.nextMode(1 - root.modeIndex)
                }
            }

        }

        Item {
            width: parent.width
            height: parent.height - root.u(44)

            ListView {
                id: list
                property real pointerX: -1
                property real pointerY: -1
                anchors.fill: parent
                visible: root.mode === "apps"
                clip: true
                spacing: root.u(2)
                model: root.mode === "apps" ? root.results : []
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds
                highlightMoveDuration: 80

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property string iconSource: modelData.entry
                        ? Quickshell.iconPath(modelData.entry.icon, true) : ""

                    width: list.width
                    height: root.u(40)
                    radius: root.innerRadius
                    color: ListView.isCurrentItem ? Theme.highlight : "transparent"

                    Row {
                        anchors {
                            fill: parent
                            leftMargin: root.u(10)
                            rightMargin: root.u(10)
                        }
                        spacing: root.u(12)

                        Item {
                            anchors.verticalCenter: parent.verticalCenter
                            width: root.u(24)
                            height: root.u(24)

                            IconImage {
                                id: appIcon
                                anchors.fill: parent
                                backer.sourceSize.width: Theme.px(appIcon.actualSize, appIcon)
                                backer.sourceSize.height: Theme.px(appIcon.actualSize, appIcon)
                                visible: row.iconSource !== ""
                                source: row.iconSource || ""
                            }
                            LineIcon {
                                anchors.centerIn: parent
                                visible: row.iconSource === ""
                                kind: row.modelData.iconKind
                                size: root.u(18)
                                color: Theme.textSecondary
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - root.u(40)

                            Text {
                                width: parent.width
                                text: row.modelData.title
                                color: Theme.text
                                font.pixelSize: root.u(13)
                                font.family: Theme.fontFamily
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                visible: row.modelData.subtitle !== ""
                                text: row.modelData.subtitle
                                color: Theme.textMuted
                                font.pixelSize: root.u(10)
                                font.family: Theme.fontFamily
                                elide: Text.ElideMiddle
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onPositionChanged: mouse => {
                            var p = mapToItem(null, mouse.x, mouse.y)
                            var moved = list.pointerX >= 0 && (p.x !== list.pointerX || p.y !== list.pointerY)
                            list.pointerX = p.x
                            list.pointerY = p.y
                            if (moved) list.currentIndex = row.index
                        }
                        onClicked: root.launch(row.modelData)
                    }
                }
            }

            Text {
                x: root.u(4)
                visible: root.mode === "themes"
                text: "Wallpaper"
                color: root.focusRow === "wallpapers" ? Theme.text : Theme.textMuted
                font.pixelSize: root.u(12)
                font.weight: Font.DemiBold
                font.family: Theme.fontFamily
            }

            PathView {
                id: wallpaperList
                readonly property int cardW: root.u(150)
                readonly property int step: cardW + root.u(12)
                width: root.rowWidth
                x: Math.round((parent.width - width) / 2)
                height: root.u(86)
                y: root.u(22)
                visible: root.mode === "themes"
                clip: true
                model: root.mode === "themes" ? root.wallpaperResults : []
                currentIndex: 0
                pathItemCount: Math.min(count, Math.ceil(width / step) + 2)
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: 220
                snapMode: PathView.SnapToItem
                path: Path {
                    startX: wallpaperList.width / 2 - wallpaperList.pathItemCount * wallpaperList.step / 2
                    startY: wallpaperList.height / 2
                    PathLine {
                        x: wallpaperList.width / 2 + wallpaperList.pathItemCount * wallpaperList.step / 2
                        y: wallpaperList.height / 2
                    }
                }
                onCountChanged: root.selectCurrentWallpaper()

                Timer { id: wpWheelCooldown; interval: 140 }
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        if (wpWheelCooldown.running) return
                        root.focusRow = "wallpapers"
                        var d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                        if (d < 0) wallpaperList.incrementCurrentIndex()
                        else if (d > 0) wallpaperList.decrementCurrentIndex()
                        wpWheelCooldown.restart()
                    }
                }

                delegate: Item {
                    id: wpCard
                    required property var modelData
                    required property int index
                    readonly property bool selected: PathView.isCurrentItem
                    readonly property bool active: modelData.name === ThemeManager.currentWallpaper

                    width: wallpaperList.cardW
                    height: wallpaperList.height
                    opacity: selected ? 1 : 0.55
                    Behavior on opacity { NumberAnimation { duration: 160 } }

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: root.innerRadius
                        color: Theme.surface

                        Image {
                            id: thumbImage
                            property bool fromThumb: wpCard.modelData.hasThumb
                            anchors.fill: parent
                            source: Theme.fileUrl(fromThumb ? wpCard.modelData.thumb
                                                            : wpCard.modelData.path)
                            readonly property int needW: Theme.px(wallpaperList.cardW, thumbImage)
                            readonly property int needH: Theme.px(wallpaperList.height, thumbImage)
                            sourceSize: fromThumb ? undefined : Qt.size(needW, needH)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            onStatusChanged: {
                                if (status === Image.Error && fromThumb) {
                                    fromThumb = false
                                    return
                                }
                                if (status !== Image.Ready || wpCard.modelData.thumb === "") return
                                if (fromThumb) {
                                    if (implicitWidth + 1 < needW || implicitHeight + 1 < needH)
                                        fromThumb = false
                                    return
                                }
                                var file = wpCard.modelData.thumb
                                grabToImage(function (result) { result.saveToFile(file) },
                                            Qt.size(needW, needH))
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: root.innerRadius
                        color: "transparent"
                        border.width: wpCard.selected && root.focusRow === "wallpapers" ? 2 : 1
                        border.color: wpCard.selected && root.focusRow === "wallpapers"
                                      ? Theme.accent : Qt.rgba(1, 1, 1, 0.08)
                    }
                    Rectangle {
                        visible: wpCard.active
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: root.u(8)
                        width: root.u(7)
                        height: width
                        radius: width / 2
                        color: Theme.accent
                        border.width: 1
                        border.color: Qt.rgba(0, 0, 0, 0.4)
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.focusRow = "wallpapers"
                            if (wpCard.selected) root.applyWallpaper(wpCard.modelData)
                            else wallpaperList.currentIndex = wpCard.index
                        }
                    }
                }
            }

            Text {
                x: root.u(4)
                y: root.u(122)
                visible: root.mode === "themes"
                text: "Theme"
                color: root.focusRow === "themes" ? Theme.text : Theme.textMuted
                font.pixelSize: root.u(12)
                font.weight: Font.DemiBold
                font.family: Theme.fontFamily
            }

            PathView {
                id: themeList
                readonly property int cardW: root.u(150)
                readonly property int step: cardW + root.u(12)
                width: root.rowWidth
                x: Math.round((parent.width - width) / 2)
                height: root.u(78)
                y: root.u(144)
                visible: root.mode === "themes"
                clip: true
                model: root.mode === "themes" ? root.results : []
                currentIndex: 0
                pathItemCount: Math.min(count, Math.ceil(width / step) + 2)
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: 220
                snapMode: PathView.SnapToItem
                path: Path {
                    startX: themeList.width / 2 - themeList.pathItemCount * themeList.step / 2
                    startY: themeList.height / 2
                    PathLine {
                        x: themeList.width / 2 + themeList.pathItemCount * themeList.step / 2
                        y: themeList.height / 2
                    }
                }

                Timer { id: wheelCooldown; interval: 140 }
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        if (wheelCooldown.running) return
                        root.focusRow = "themes"
                        var d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                        if (d < 0) themeList.incrementCurrentIndex()
                        else if (d > 0) themeList.decrementCurrentIndex()
                        wheelCooldown.restart()
                    }
                }

                delegate: Rectangle {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property bool active: modelData.id === ThemeManager.current
                    readonly property bool selected: PathView.isCurrentItem
                    readonly property var c: modelData.colors

                    width: themeList.cardW
                    height: themeList.height
                    radius: root.innerRadius
                    color: c.card
                    border.width: selected && root.focusRow === "themes" ? 2 : 1
                    border.color: selected && root.focusRow === "themes" ? c.accent : c.cardBorder
                    opacity: selected ? 1 : 0.55
                    Behavior on opacity { NumberAnimation { duration: 160 } }

                    Rectangle {
                        visible: card.active
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: root.u(8)
                        width: root.u(6)
                        height: width
                        radius: width / 2
                        color: card.c.accent
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: root.u(12)

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: root.u(5)
                            Repeater {
                                model: card.modelData.dots
                                delegate: Rectangle {
                                    required property var modelData
                                    width: root.u(13)
                                    height: width
                                    radius: width / 2
                                    color: modelData || "transparent"
                                }
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: card.modelData.id
                            color: card.selected ? card.c.text : card.c.textSecondary
                            font.pixelSize: root.u(11)
                            font.weight: card.selected ? Font.DemiBold : Font.Normal
                            font.family: Theme.fontFamily
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.focusRow = "themes"
                            if (card.selected) root.launch(card.modelData)
                            else themeList.currentIndex = card.index
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: root.u(24)
                visible: root.mode === "apps" && root.results.length === 0
                text: "No apps found"
                color: Theme.textMuted
                font.pixelSize: root.u(12)
                font.family: Theme.fontFamily
            }

            Text {
                anchors.centerIn: wallpaperList
                visible: root.mode === "themes" && root.wallpaperResults.length === 0
                text: "No wallpapers found"
                color: Theme.textMuted
                font.pixelSize: root.u(12)
                font.family: Theme.fontFamily
            }
            Text {
                anchors.centerIn: themeList
                visible: root.mode === "themes" && root.results.length === 0
                text: "No themes found"
                color: Theme.textMuted
                font.pixelSize: root.u(12)
                font.family: Theme.fontFamily
            }
        }
    }
}
