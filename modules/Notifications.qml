import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import Quickshell.Hyprland
import qs.services
import qs.widgets

Item {
    id: root
    required property var island
    anchors.fill: parent

    readonly property string ownerId: "notif"
    readonly property bool shown: island.owner === ownerId

    readonly property int minW: Theme.s(200)
    readonly property int maxW: Theme.s(420)
    readonly property int minH: Theme.s(44)
    readonly property int maxH: Theme.s(110)
    readonly property int hPad: Theme.s(28)
    readonly property int topPad: Theme.s(12)
    readonly property int bottomPad: Theme.s(16)
    readonly property int iconSize: Theme.s(36)
    readonly property int iconGap: Theme.s(12)
    readonly property int lineGap: Theme.s(2)
    readonly property int maxBodyLines: 3

    property Notification current: null
    property int currentHistoryId: -1
    property string nApp: ""
    property string nSummary: ""
    property string nBody: ""
    property string nIcon: ""
    property bool nRound: false

    property alias history: historyModel
    property int historySeq: 0
    ListModel { id: historyModel }

    function addToHistory(n) {
        historySeq += 1
        historyModel.insert(0, {
            nid: historySeq,
            app: n.appName,
            summary: n.summary,
            body: n.body,
            icon: historyIconFor(n),
            rounded: historyIconFor(n) === imageFor(n),
            desktopEntry: n.desktopEntry || ""
        })
        if (historyModel.count > 30)
            historyModel.remove(30, historyModel.count - 30)
        return historySeq
    }

    function removeFromHistory(id) {
        for (var i = 0; i < historyModel.count; i++) {
            if (historyModel.get(i).nid === id) {
                historyModel.remove(i)
                return
            }
        }
    }

    readonly property bool hasIcon: nIcon !== ""
    readonly property int iconBlock: hasIcon ? iconSize + iconGap : 0

    readonly property bool showApp: !hasIcon && nApp !== ""
                                    && nApp.toLowerCase() !== "notify-send"

    readonly property int maxTextW: maxW - 2 * hPad - iconBlock
    readonly property int minTextW: Math.max(Theme.s(60), minW - 2 * hPad - iconBlock)

    readonly property int textW: Math.ceil(Math.max(minTextW,
        Math.min(maxTextW, Math.max(sMeasure.advanceWidth, bMeasure.advanceWidth,
                                    showApp ? aMeasure.advanceWidth : 0) + Theme.s(4))))

    readonly property int textH: Math.ceil(
        (showApp ? aMeasure.height + lineGap : 0)
        + sMeasure.height
        + (nBody !== "" ? lineGap + bBox.implicitHeight : 0))

    readonly property int wantedW: Math.max(minW,
        Math.min(maxW, textW + iconBlock + 2 * hPad))
    readonly property int wantedH: Math.max(minH,
        Math.min(maxH, Math.max(textH, hasIcon ? iconSize : 0) + topPad + bottomPad))

    onWantedWChanged: if (shown) island.open(ownerId, wantedW, wantedH)
    onWantedHChanged: if (shown) island.open(ownerId, wantedW, wantedH)

    TextMetrics {
        id: aMeasure
        text: root.nApp
        font.pixelSize: Theme.s(9)
        font.family: Theme.fontFamily
    }
    TextMetrics {
        id: sMeasure
        text: root.nSummary
        font.pixelSize: Theme.s(13)
        font.bold: true
        font.family: Theme.fontFamily
    }
    TextMetrics {
        id: bMeasure
        text: root.nBody.replace(/\n/g, " ")
        font.pixelSize: Theme.s(11)
        font.family: Theme.fontFamily
    }
    Text {
        id: bBox
        visible: false
        width: root.textW
        text: root.nBody
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        maximumLineCount: root.maxBodyLines
        font.pixelSize: Theme.s(11)
        font.family: Theme.fontFamily
    }

    readonly property string iconScheme: "image://icon/"

    function imageFor(n) {
        var img = n.image || ""
        if (img.startsWith(iconScheme + "/")) return "file://" + img.substring(iconScheme.length)
        if (img.startsWith(iconScheme)) return ""
        if (img.startsWith("/")) return "file://" + img
        return img
    }

    function iconFor(n) {
        var img = imageFor(n)
        return img !== "" ? img : appIconFor(n)
    }

    function historyIconFor(n) {
        var img = imageFor(n)
        return img !== "" && !img.startsWith("image://") ? img : appIconFor(n)
    }

    function appIconFor(n) {
        var ic = n.appIcon
        var img = n.image || ""
        if ((!ic || ic === "") && img.startsWith(iconScheme) && !img.startsWith(iconScheme + "/"))
            ic = img.substring(iconScheme.length)
        if (ic && ic !== "") {
            if (ic.startsWith("file://")) return ic
            if (ic.startsWith("/")) return "file://" + ic
            var p = Quickshell.iconPath(ic, true)
            if (p !== "") return p
        }
        var keys = [n.desktopEntry, ic, n.appName]
        for (var i = 0; i < keys.length; i++) {
            if (!keys[i] || keys[i] === "" || String(keys[i]).indexOf("/") >= 0) continue
            var entry = DesktopEntries.heuristicLookup(keys[i])
            if (entry && entry.icon && entry.icon !== "") {
                var q = Quickshell.iconPath(entry.icon, true)
                if (q !== "") return q
            }
        }
        return ""
    }

    function focusApp(desktopEntry, appName) {
        var keys = []
        function add(k) {
            if (!k) return
            k = String(k).toLowerCase().replace(/\.desktop$/, "")
            if (k !== "" && keys.indexOf(k) < 0) keys.push(k)
        }
        add(desktopEntry)
        add(appName)
        var entry = DesktopEntries.heuristicLookup(desktopEntry || appName || "")
        if (entry) {
            add(entry.id)
            add(entry.startupClass)
        }
        if (keys.length === 0) return

        var re = "(?i)^(" + keys.map(function (k) {
            return k.replace(/[.*+?^${}()|[\]\\"]/g, "\\$&")
        }).join("|") + ")$"

        if (Hyprland.usingLua)
            Hyprland.dispatch('hl.dsp.focus({ window = "class:'
                              + re.replace(/\\/g, "\\\\") + '" })')
        else
            Hyprland.dispatch("focuswindow class:" + re)
    }

    function activate(n) {
        var desktopEntry = n.desktopEntry
        var appName = n.appName
        var action = null
        var actions = n.actions || []
        for (var i = 0; i < actions.length; i++)
            if (actions[i].identifier === "default") action = actions[i]

        if (action) action.invoke()
        else n.dismiss()
        focusApp(desktopEntry, appName)
    }

    function show(n) {
        var old = current
        current = n
        fill(n)
        island.open(ownerId, wantedW, wantedH)
        if (old && old !== n) old.expire()
    }

    function fill(n) {
        nApp = n.appName
        nSummary = n.summary
        nBody = n.body
        nIcon = iconFor(n)
        nRound = imageFor(n) !== ""

        if (n.appName.toLowerCase() === "notify-send")
            hideTimer.interval = 1500
        else
            hideTimer.interval = n.expireTimeout > 0
                ? Math.max(1500, Math.min(10000, n.expireTimeout)) : 4000
        hideTimer.restart()
    }

    function refreshCurrent() {
        var n = current
        if (!n) return
        fill(n)
        for (var i = 0; i < historyModel.count; i++) {
            if (historyModel.get(i).nid === currentHistoryId) {
                historyModel.set(i, {
                    app: n.appName,
                    summary: n.summary,
                    body: n.body,
                    icon: historyIconFor(n),
                    rounded: historyIconFor(n) === imageFor(n)
                })
                break
            }
        }
    }

    function hide() {
        hideTimer.stop()
        var n = current
        current = null
        island.close(ownerId)
        if (n) n.expire()
    }

    Timer {
        id: hideTimer
        onTriggered: {
            if (root.island.hovered && root.shown) restart()
            else root.hide()
        }
    }

    Connections {
        target: root.current
        function onClosed() {
            hideTimer.stop()
            root.current = null
            root.island.close(root.ownerId)
        }
        function onSummaryChanged() { Qt.callLater(root.refreshCurrent) }
        function onBodyChanged() { Qt.callLater(root.refreshCurrent) }
        function onAppIconChanged() { Qt.callLater(root.refreshCurrent) }
        function onImageChanged() { Qt.callLater(root.refreshCurrent) }
    }

    NotificationServer {
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        keepOnReload: true

        onNotification: n => {
            n.tracked = true
            var historyId = root.addToHistory(n)

            if (root.island.owner === "" || root.island.owner === "media"
                || root.island.owner === "osd"
                || root.island.owner === root.ownerId) {
                root.show(n)
                root.currentHistoryId = historyId
            } else {
                n.expire()
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: root.iconGap

        visible: root.shown
        FadeIn { active: root.shown; pause: 160; duration: 220 }

        IconImage {
            id: appLogo
            backer.sourceSize.width: Theme.px(appLogo.actualSize, appLogo)
            backer.sourceSize.height: Theme.px(appLogo.actualSize, appLogo)
            visible: root.hasIcon && !root.nRound
            anchors.verticalCenter: parent.verticalCenter
            implicitSize: root.iconSize
            source: root.nRound ? "" : root.nIcon
        }
        ClippingRectangle {
            visible: root.hasIcon && root.nRound
            anchors.verticalCenter: parent.verticalCenter
            width: root.iconSize
            height: root.iconSize
            radius: width / 2
            color: Theme.surface
            Image {
                anchors.fill: parent
                source: root.nRound ? root.nIcon : ""
                sourceSize: Qt.size(Theme.px(root.iconSize, parent), Theme.px(root.iconSize, parent))
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        Column {
            width: root.textW
            spacing: root.lineGap

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: root.showApp
                text: root.nApp
                color: Theme.textSecondary
                font.pixelSize: Theme.s(9)
                font.family: Theme.fontFamily
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.nSummary
                textFormat: Text.PlainText
                color: Theme.text
                font.pixelSize: Theme.s(13)
                font.bold: true
                font.family: Theme.fontFamily
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: root.nBody !== ""
                text: root.nBody
                textFormat: Text.PlainText
                color: Theme.textSoft
                font.pixelSize: Theme.s(11)
                font.family: Theme.fontFamily
                wrapMode: Text.Wrap
                maximumLineCount: root.maxBodyLines
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.shown
        onClicked: {
            var n = root.current
            if (n) {
                root.removeFromHistory(root.currentHistoryId)
                root.activate(n)
            }
            root.hide()
        }
    }
}
