import QtQuick
import qs.services
import qs.widgets

Item {
    id: piece

    property string kind: ""
    property bool tile: true
    property real k: 1
    function f(v) { return SettingsUi.u(v * 0.79 * k) }

    readonly property var tileMeta: Controls.tileInfo[kind] || ({ slots: 1, label: kind, icon: "" })
    readonly property var sectionMeta: Controls.sectionInfo[kind] || ({ label: kind, icon: "" })
    readonly property bool wide: tile && tileMeta.slots === 2

    function sectionHeight(id) {
        if (id === "notifications") return f(64)
        if (id === "search" || id === "apps") return f(44)
        return f(60)
    }

    implicitWidth: tile ? (wide ? f(150) : f(48)) : f(260)
    implicitHeight: tile ? f(54) : sectionHeight(kind)

    Rectangle {
        visible: piece.tile && !piece.wide
        anchors.centerIn: parent
        width: piece.f(48)
        height: width
        radius: Theme.round(width)
        color: Theme.card
        border.width: 1
        border.color: Theme.cardBorder

        LineIcon {
            anchors.centerIn: parent
            kind: piece.tileMeta.icon
            size: Math.round(parent.width * 0.42)
            color: Theme.text
        }
    }

    Rectangle {
        visible: piece.wide
        anchors.fill: parent
        radius: Math.min(Theme.radius, height / 2)
        color: Theme.card
        border.width: 1
        border.color: Theme.cardBorder

        Rectangle {
            id: badge
            x: piece.f(8)
            anchors.verticalCenter: parent.verticalCenter
            width: parent.height - 2 * piece.f(8)
            height: width
            radius: Theme.round(width)
            color: Theme.accent

            LineIcon {
                anchors.centerIn: parent
                kind: piece.tileMeta.icon
                size: Math.round(parent.width * 0.5)
                color: Theme.background
            }
        }

        Column {
            anchors.left: badge.right
            anchors.leftMargin: piece.f(10)
            anchors.right: parent.right
            anchors.rightMargin: piece.f(8)
            anchors.verticalCenter: parent.verticalCenter

            Text {
                width: parent.width
                text: piece.tileMeta.label
                color: Theme.text
                font.pixelSize: piece.f(12)
                font.bold: true
                font.family: Theme.fontFamily
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: piece.kind === "network" && !Controls.hasWifi ? "Connected" : "On"
                color: Theme.textSecondary
                font.pixelSize: piece.f(10)
                font.family: Theme.fontFamily
                elide: Text.ElideRight
            }
        }
    }

    Rectangle {
        visible: !piece.tile
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.card
        border.width: 1
        border.color: Theme.cardBorder

        readonly property bool slider: ["audio", "display", "keyboard"].indexOf(piece.kind) >= 0

        Text {
            visible: parent.slider || piece.kind === "notifications"
            x: piece.f(14)
            y: piece.f(9)
            text: piece.sectionMeta.label
            color: piece.kind === "notifications" ? Theme.textSecondary : Theme.text
            font.pixelSize: piece.f(piece.kind === "notifications" ? 10 : 11)
            font.bold: piece.kind !== "notifications"
            font.family: Theme.fontFamily
        }

        Rectangle {
            visible: parent.slider
            x: piece.f(10)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: piece.f(10)
            width: parent.width - 2 * piece.f(10)
            height: piece.f(20)
            radius: Theme.round(height)
            color: Theme.track

            Rectangle {
                width: parent.width * 0.62
                height: parent.height
                radius: parent.radius
                color: Theme.accent
            }

            LineIcon {
                x: piece.f(7)
                anchors.verticalCenter: parent.verticalCenter
                kind: piece.sectionMeta.icon
                size: piece.f(12)
                color: Theme.background
            }
        }

        Text {
            visible: piece.kind === "notifications"
            anchors.centerIn: parent
            anchors.verticalCenterOffset: piece.f(8)
            text: "No notifications"
            color: Theme.textMuted
            font.pixelSize: piece.f(10)
            font.family: Theme.fontFamily
        }

        Row {
            visible: piece.kind === "search" || piece.kind === "apps"
            x: piece.f(14)
            anchors.verticalCenter: parent.verticalCenter
            spacing: piece.f(10)

            LineIcon {
                anchors.verticalCenter: parent.verticalCenter
                kind: piece.kind === "search" ? "search" : "app"
                size: piece.f(16)
                color: Theme.textMuted
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: piece.kind === "search" ? "Search" : "Background apps"
                color: piece.kind === "search" ? Theme.textMuted : Theme.textSecondary
                font.pixelSize: piece.f(piece.kind === "search" ? 13 : 11)
                font.family: Theme.fontFamily
            }
        }
    }
}
