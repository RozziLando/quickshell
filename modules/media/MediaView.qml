import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.services
import qs.widgets

// Vista del media player (copertina, titoli, barra, controlli, più player
// con la rotella), usata dal player che scende dall'isola
// (aperto dai tasti o dal cerchio sinistro).
Item {
    id: root

    // Dimensione: 1 = misura del player dell'isola
    property real sizeFactor: 1.0
    function u(value) { return Theme.s(value * sizeFactor) }

    // true mentre è visibile: aggiorna la posizione del brano
    property bool active: visible

    readonly property int coverSize: u(68)

    function time(seconds) {
        var s = Math.max(0, Math.floor(seconds))
        var m = Math.floor(s / 60)
        s = s % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    // ---------- Selezione del player ----------
    property var players: Mpris.players.values
    readonly property int playerCount: players.length
    property int index: 0

    property var player: playerCount > 0
        ? players[Math.min(index, playerCount - 1)]
        : null


    readonly property bool multi: playerCount > 1

    function pickPlaying() {
        for (var i = 0; i < players.length; i++)
            if (players[i].isPlaying) return i
        return 0
    }

    function step(delta) {
        if (playerCount < 2) return
        index = (index + delta + playerCount) % playerCount
    }

    // ---------- Logo dell'app (ripiego per la copertina) ----------
    function appIconFor(p) {
        if (!p) return ""
        var keys = [p.desktopEntry, p.identity]
        for (var i = 0; i < keys.length; i++) {
            var k = keys[i]
            if (!k || k === "") continue
            var entry = DesktopEntries.heuristicLookup(k)
            if (entry && entry.icon && entry.icon !== "") {
                var path = Quickshell.iconPath(entry.icon, true)
                if (path !== "") return path
            }
        }
        // Ultimo tentativo: il nome del desktop entry come nome icona
        if (p.desktopEntry && p.desktopEntry !== "") {
            var q = Quickshell.iconPath(p.desktopEntry, true)
            if (q !== "") return q
        }
        return ""
    }

    readonly property string fallbackIcon: appIconFor(player)

    // Se diminuiscono i player, resta su uno valido
    onPlayerCountChanged: if (index >= playerCount && playerCount > 0) index = playerCount - 1

    // Aggiorna la posizione di riproduzione mentre il brano suona
    Timer {
        interval: 1000
        repeat: true
        running: root.active && root.player && root.player.isPlaying
        onTriggered: root.player.positionChanged()
    }

    // Evita che il touchpad scorra troppi player in un colpo solo
    Timer {
        id: wheelCooldown
        interval: 220
    }

    // ---------- Interfaccia ----------
        // Rotella: cambia player
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                if (!root.multi || wheelCooldown.running) return
                root.step(event.angleDelta.y < 0 ? 1 : -1)
                wheelCooldown.restart()
            }
        }

        // ----- Player -----
        Row {
            id: playerRow
            width: parent.width
            height: root.coverSize
            // Con un solo player resta centrato, con più player sale per far posto ai puntini
            y: root.multi ? 0 : (root.height - height) / 2
            spacing: root.u(16)

            // ----- Copertina (con ripiego sul logo dell'app) -----
            ClippingRectangle {
                width: root.coverSize
                height: root.coverSize
                radius: root.u(12)
                color: Theme.surface

                // Copertina nuova, scaricata in background: quando è pronta
                // sostituisce quella mostrata. Così cambiando brano resta la
                // copertina precedente finché non arriva la nuova (niente
                // lampo del logo dell'app nel mezzo)
                Image {
                    id: incoming
                    visible: false
                    source: root.player ? root.player.trackArtUrl : ""
                    // Decodifica alla misura che serve (pixel veri del
                    // monitor, vedi Theme.px), non a 640 px
                    sourceSize: Qt.size(Theme.px(root.coverSize, incoming), Theme.px(root.coverSize, incoming))
                    asynchronous: true
                    onStatusChanged: {
                        if (status === Image.Ready) art.source = source
                        else if (status === Image.Error) art.source = ""
                    }
                    // Nessuna copertina per il nuovo brano o player
                    onSourceChanged: if (source.toString() === "") art.source = ""
                }

                // Copertina mostrata (stessa immagine, già in cache)
                Image {
                    id: art
                    anchors.fill: parent
                    sourceSize: incoming.sourceSize
                    fillMode: Image.PreserveAspectCrop
                    visible: source.toString() !== "" && status === Image.Ready
                }

                // Logo dell'app se la copertina manca, è in caricamento o ha dato errore
                IconImage {
                    id: playerLogo
                    anchors.centerIn: parent
                    // Pixel veri del monitor (vedi Theme.px)
                    backer.sourceSize.width: Theme.px(playerLogo.actualSize, playerLogo)
                    backer.sourceSize.height: Theme.px(playerLogo.actualSize, playerLogo)
                    implicitSize: Math.round(root.coverSize * 0.58)
                    source: root.fallbackIcon
                    visible: !art.visible && root.fallbackIcon !== ""
                }

                // Ultimo ripiego: nessuna copertina e nessun logo
                Text {
                    anchors.centerIn: parent
                    visible: !art.visible && root.fallbackIcon === ""
                    text: "♪"
                    color: Theme.textMuted
                    font.pixelSize: Math.round(root.coverSize * 0.41)
                }
            }

            // ----- Testi, barra e controlli -----
            Column {
                width: parent.width - root.coverSize - playerRow.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.u(3)

                Text {
                    width: parent.width
                    text: root.player ? root.player.trackTitle : "Nothing playing"
                    color: Theme.text
                    font.pixelSize: root.u(13)
                    font.bold: true
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: root.player ? root.player.trackArtist : ""
                    color: Theme.textSecondary
                    font.pixelSize: root.u(11)
                    font.family: Theme.fontFamily
                    elide: Text.ElideRight
                }

                // Barra di avanzamento (cliccabile per spostarsi nel brano)
                Item {
                    width: parent.width
                    height: root.u(12)

                    Rectangle {
                        id: track
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: root.u(4)
                        radius: height / 2
                        color: Theme.highlight

                        Rectangle {
                            height: parent.height
                            radius: height / 2
                            color: Theme.accent
                            width: {
                                var p = root.player
                                if (!p || !p.lengthSupported || p.length <= 0) return 0
                                return track.width * Math.min(1, p.position / p.length)
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.player && root.player.canSeek && root.player.lengthSupported
                        onClicked: mouse => {
                            root.player.position = (mouse.x / width) * root.player.length
                        }
                    }
                }

                // Controlli (icone disegnate: non dipendono dai font installati)
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: root.u(18)

                    Repeater {
                        model: [
                            { kind: "previous", enabled: root.player && root.player.canGoPrevious },
                            { kind: root.player && root.player.isPlaying ? "pause" : "play",
                              enabled: !!root.player },
                            { kind: "next", enabled: root.player && root.player.canGoNext }
                        ]

                        delegate: Item {
                            id: ctrl
                            required property var modelData
                            required property int index
                            width: root.u(16)
                            height: width

                            LineIcon {
                                anchors.centerIn: parent
                                kind: ctrl.modelData.kind
                                size: ctrl.index === 1 ? root.u(14) : root.u(12)
                                color: ctrl.modelData.enabled ? Theme.text : Theme.textDisabled
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -root.u(6)
                                enabled: ctrl.modelData.enabled
                                onClicked: {
                                    if (ctrl.index === 0) root.player.previous()
                                    else if (ctrl.index === 1) root.player.togglePlaying()
                                    else root.player.next()
                                }
                            }
                        }
                    }
                }
            }
        }

        // ----- Nome del player + puntini (solo con più player) -----
        Row {
            visible: root.multi
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            height: root.u(12)
            spacing: root.u(10)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.player ? root.player.identity : ""
                color: Theme.textMuted
                font.pixelSize: root.u(10)
                font.family: Theme.fontFamily
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.u(6)

                Repeater {
                    model: root.playerCount

                    delegate: Rectangle {
                        required property int index
                        width: index === root.index ? root.u(14) : root.u(6)
                        height: root.u(6)
                        radius: root.u(3)
                        color: index === root.index ? Theme.text : Theme.textDisabled

                        Behavior on width { NumberAnimation { duration: 150 } }
                        Behavior on color { ColorAnimation { duration: 150 } }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -root.u(5)
                            onClicked: root.index = parent.index
                        }
                    }
                }
            }
        }
}
