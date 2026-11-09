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

    // ---------- Limiti (scalati) ----------
    readonly property int minW: Theme.s(200)
    readonly property int maxW: Theme.s(420)
    readonly property int minH: Theme.s(44)
    readonly property int maxH: Theme.s(110)
    readonly property int hPad: Theme.s(28)       // margine laterale
    readonly property int topPad: Theme.s(12)
    readonly property int bottomPad: Theme.s(16)
    readonly property int iconSize: Theme.s(36)
    readonly property int iconGap: Theme.s(12)
    readonly property int lineGap: Theme.s(2)
    readonly property int maxBodyLines: 3

    // ---------- Stato ----------
    property Notification current: null
    property int currentHistoryId: -1
    property string nApp: ""
    property string nSummary: ""
    property string nBody: ""
    property string nIcon: ""
    // L'icona è un'immagine della notifica (avatar): si mostra rotonda
    property bool nRound: false

    // ---------- Storico (usato dal centro di controllo) ----------
    property alias history: historyModel
    property int historySeq: 0
    ListModel { id: historyModel }

    // Aggiunge una voce e ne restituisce l'identificatore
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

    // ---------- Misure ----------
    readonly property bool hasIcon: nIcon !== ""
    readonly property int iconBlock: hasIcon ? iconSize + iconGap : 0

    // Il nome dell'app si mostra solo se manca l'icona (e non per notify-send)
    readonly property bool showApp: !hasIcon && nApp !== ""
                                    && nApp.toLowerCase() !== "notify-send"

    readonly property int maxTextW: maxW - 2 * hPad - iconBlock
    readonly property int minTextW: Math.max(Theme.s(60), minW - 2 * hPad - iconBlock)

    // Larghezza del testo: segue la riga più lunga, entro i limiti
    // (+ un piccolo margine: arrotondando per difetto il titolo finiva in "…")
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

    // Se le misure cambiano mentre la notifica è visibile, adatta la pillola
    onWantedWChanged: if (shown) island.open(ownerId, wantedW, wantedH)
    onWantedHChanged: if (shown) island.open(ownerId, wantedW, wantedH)

    // Misuratori invisibili (stessi font dei testi veri)
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
        // Testo semplice: il server non dichiara il markup (le app mandano
        // testo puro) e il testo ricco caricherebbe <img> anche dalla rete
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        maximumLineCount: root.maxBodyLines
        font.pixelSize: Theme.s(11)
        font.family: Theme.fontFamily
    }

    // ---------- Icona ----------
    // Quickshell mette in "image" sia l'immagine della notifica sia il logo
    // passato per nome (notify-send -i firefox):
    //   image://icon/<nome>     logo dell'app (nome di un'icona del tema)
    //   image://icon//<file>    file (es. hint image-path): avatar
    //   image://qsimage/...     immagine inviata dentro la notifica: avatar
    // L'avatar, come da specifica, ha la precedenza sul logo (le chat mandano
    // entrambi) e si mostra rotondo.
    readonly property string iconScheme: "image://icon/"

    function imageFor(n) {
        var img = n.image || ""
        if (img.startsWith(iconScheme + "/")) return "file://" + img.substring(iconScheme.length)
        if (img.startsWith(iconScheme)) return ""          // è un logo
        if (img.startsWith("/")) return "file://" + img
        return img
    }

    function iconFor(n) {
        var img = imageFor(n)
        return img !== "" ? img : appIconFor(n)
    }

    // Storico: "image://qsimage" esiste solo finché la notifica è viva, poi
    // resterebbe un riquadro vuoto. Lì si tiene un file, oppure il logo
    function historyIconFor(n) {
        var img = imageFor(n)
        return img !== "" && !img.startsWith("image://") ? img : appIconFor(n)
    }

    // Logo dell'app
    function appIconFor(n) {
        var ic = n.appIcon
        // Logo passato come "image://icon/<nome>" (vedi sopra)
        var img = n.image || ""
        if ((!ic || ic === "") && img.startsWith(iconScheme) && !img.startsWith(iconScheme + "/"))
            ic = img.substring(iconScheme.length)
        if (ic && ic !== "") {
            if (ic.startsWith("file://")) return ic
            if (ic.startsWith("/")) return "file://" + ic
            var p = Quickshell.iconPath(ic, true)
            if (p !== "") return p
        }
        // Ripiego: cerca l'app tra i file .desktop (il nome dell'icona chiesta
        // è spesso quello del file, es. "brave-browser" -> Icon=brave-desktop)
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

    // ---------- Torna all'app che ha mandato la notifica ----------
    // Cerca la finestra per classe (desktop entry, nome app, StartupWMClass)
    // e la porta in primo piano tramite l'IPC di Hyprland.
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

        // Le versioni di Hyprland con config Lua usano una sintassi diversa
        if (Hyprland.usingLua)
            Hyprland.dispatch('hl.dsp.focus({ window = "class:'
                              + re.replace(/\\/g, "\\\\") + '" })')
        else
            Hyprland.dispatch("focuswindow class:" + re)
    }

    // Click su una notifica: avvisa l'app (azione "default") e la porta avanti
    function activate(n) {
        var desktopEntry = n.desktopEntry
        var appName = n.appName
        var action = null
        var actions = n.actions || []
        for (var i = 0; i < actions.length; i++)
            if (actions[i].identifier === "default") action = actions[i]

        // invoke() chiude già la notifica (se non è "resident")
        if (action) action.invoke()
        else n.dismiss()
        focusApp(desktopEntry, appName)
    }

    // ---------- Logica ----------
    function show(n) {
        var old = current
        current = n
        fill(n)
        island.open(ownerId, wantedW, wantedH)
        if (old && old !== n) old.expire()
    }

    // Testi, icona e durata della notifica mostrata
    function fill(n) {
        nApp = n.appName
        nSummary = n.summary
        nBody = n.body
        nIcon = iconFor(n)
        nRound = imageFor(n) !== ""

        // Durata: notify-send 1500 ms; le altre app usano la propria oppure
        // 4000 ms se non ne specificano una. expireTimeout arriva in
        // millisecondi (come da specifica, anche se la documentazione di
        // Quickshell dice secondi); limitata, così l'isola non resta occupata
        if (n.appName.toLowerCase() === "notify-send")
            hideTimer.interval = 1500
        else
            hideTimer.interval = n.expireTimeout > 0
                ? Math.max(1500, Math.min(10000, n.expireTimeout)) : 4000
        hideTimer.restart()
    }

    // Notifica aggiornata dall'app mentre è visibile (stesso id, es. un
    // download che avanza): Quickshell cambia l'oggetto senza mandarne uno
    // nuovo. Si rinfrescano testi, icona, durata e la voce nello storico
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
        // Col puntatore sopra resta (si sta leggendo), come OSD e player
        onTriggered: {
            if (root.island.hovered && root.shown) restart()
            else root.hide()
        }
    }

    // Notifica chiusa da fuori (es. dall'app stessa)
    Connections {
        target: root.current
        function onClosed() {
            hideTimer.stop()
            root.current = null
            root.island.close(root.ownerId)
        }
        // Più proprietà cambiano insieme: un solo aggiornamento
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

            // Cede il posto al player, ma non interrompe launcher e centro di controllo
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

    // ---------- Contenuto ----------
    Row {
        anchors.centerIn: parent
        spacing: root.iconGap

        // Si nasconde di colpo, compare in dissolvenza
        visible: root.shown
        // Si nasconde subito, ricompare in dissolvenza dopo una pausa
        FadeIn { active: root.shown; pause: 160; duration: 220 }

        // Logo dell'app così com'è; avatar ritagliato a cerchio
        IconImage {
            id: appLogo
            // Pixel veri del monitor (vedi Theme.px)
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

            // Nome dell'app: solo se manca l'icona
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
                // Aperta con un click: non resta nello storico
                root.removeFromHistory(root.currentHistoryId)
                root.activate(n)
            }
            root.hide()
        }
    }
}