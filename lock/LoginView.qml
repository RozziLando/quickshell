import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.services
import qs.widgets

Item {
    id: root

    property url backgroundSource: ""
    property string userName: ""
    property var avatarSources: []
    property int avatarTry: 0
    onAvatarSourcesChanged: avatarTry = 0
    property bool busy: false
    property string errorText: ""
    property bool showPower: false
    property bool showLogin: true
    property bool takeFocus: showLogin
    property string sharedText: ""
    signal textTyped(string text)
    onSharedTextChanged: if (field.text !== sharedText) field.text = sharedText
    property bool blurred: Theme.lockBlur

    signal submitted(string password)
    signal powerAction(string action)

    property real sizeFactor: 0.765

    readonly property var referenceScreen: {
        var list = Quickshell.screens
        for (var i = 0; i < list.length; i++)
            if (Theme.monitor !== "" && list[i].name === Theme.monitor) return list[i]
        for (i = 0; i < list.length; i++)
            if (/^(eDP|LVDS|DSI)/.test(list[i].name)) return list[i]
        return list.length > 0 ? list[0] : null
    }
    readonly property real referenceLong: referenceScreen ? Math.max(referenceScreen.width, referenceScreen.height) : Math.max(width, height)
    readonly property real referenceShort: referenceScreen ? Math.min(referenceScreen.width, referenceScreen.height) : Math.min(width, height)
    readonly property real unit: Math.max(0.6, Math.min(referenceLong / 1440, referenceShort / 900))
    function v(value) { return Math.round(value * unit * Theme.scale * sizeFactor) }

    readonly property color fg: "#ffffff"

    property bool capsLock: false
    property var capsFiles: []
    property var capsOn: ({})
    Process {
        running: true
        command: ["sh", "-c", 'for f in /sys/class/leds/*::capslock/brightness; do [ -r "$f" ] && echo "$f"; done; true']
        stdout: StdioCollector {
            onStreamFinished: root.capsFiles = text.split("\n").filter(function (l) { return l !== "" })
        }
    }
    Instantiator {
        id: capsViews
        model: root.capsFiles
        delegate: FileView {
            required property string modelData
            path: modelData
            printErrors: false
            onLoaded: {
                var s = Object.assign({}, root.capsOn)
                s[modelData] = /[1-9]/.test(text())
                root.capsOn = s
                root.capsLock = Object.keys(s).some(function (k) { return s[k] })
            }
        }
    }
    Timer {
        interval: 400
        repeat: true
        running: root.visible && capsViews.count > 0
        onTriggered: {
            for (var i = 0; i < capsViews.count; i++) capsViews.objectAt(i).reload()
        }
    }
    function fail(message) {
        errorText = message
        field.text = ""
        shake.restart()
        field.forceActiveFocus()
    }

    Component.onCompleted: if (takeFocus) field.forceActiveFocus()

    Item {
        id: backdrop
        anchors.fill: parent

        Rectangle {
            anchors.fill: parent
            color: "#101014"
        }

        Image {
            id: bg
            anchors.fill: parent
            source: root.blurred ? "" : root.backgroundSource
            fillMode: Image.PreserveAspectCrop
            cache: false
            asynchronous: false
            mipmap: true
            visible: !root.blurred
        }

        Image {
            id: bgSmall
            anchors.fill: parent
            source: root.blurred ? root.backgroundSource : ""
            sourceSize.width: Math.max(64, Math.round(root.width / 8))
            fillMode: Image.PreserveAspectCrop
            cache: false
            asynchronous: false
            smooth: true
            visible: false
        }

        MultiEffect {
            anchors.fill: parent
            source: bgSmall
            visible: root.blurred && bgSmall.status === Image.Ready
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            saturation: 0.15
            brightness: -0.08
        }

        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: 0.22
            visible: root.blurred
        }
    }

    property date now: new Date()
    Timer {
        interval: 1000
        repeat: true
        running: root.visible
        onTriggered: root.now = new Date()
    }

    Text {
        id: dateText
        visible: root.showLogin
        x: Math.round((parent.width - width) / 2)
        y: Math.round(parent.height * 0.08)
        text: root.now.toLocaleDateString(Qt.locale("en_US"), "ddd d MMMM")
        color: root.fg
        opacity: 0.9
        font.pixelSize: root.v(24)
        font.weight: Font.DemiBold
        font.styleName: ""
        font.family: Theme.fontFamily
    }

    Item {
        id: timeBox
        visible: root.showLogin
        x: Math.round((parent.width - width) / 2)
        y: dateText.y + dateText.height - root.v(6)
        width: digits.implicitWidth
        height: digits.implicitHeight

        readonly property string timeText: Qt.formatTime(root.now, "hh:mm")

        Text {
            id: digits
            visible: false
            renderType: Text.CurveRendering
            layer.enabled: true
            layer.smooth: true
            layer.textureSize: Qt.size(width * 2, height * 2)
            text: timeBox.timeText
            color: "white"
            font.pixelSize: root.v(192)
            font.weight: Font.Bold
            font.styleName: ""
            font.family: Qt.fontFamilies().indexOf("Inter Display") >= 0 ? "Inter Display" : Theme.fontFamily
            font.letterSpacing: -root.v(1)
            font.features: { "tnum": 1 }
        }

        ShaderEffectSource {
            id: behind
            anchors.fill: parent
            visible: false
            sourceItem: backdrop
            sourceRect: Qt.rect(timeBox.x, timeBox.y, timeBox.width, timeBox.height)
            live: true
        }

        MultiEffect {
            anchors.fill: parent
            source: behind
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1.0
            blurMax: 48
            brightness: 0.32
            saturation: 0.35
            maskEnabled: true
            maskSource: digits
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.1
        }

        Text {
            anchors.fill: parent
            text: timeBox.timeText
            color: Qt.rgba(1, 1, 1, 0.3)
            renderType: Text.CurveRendering
            font: digits.font
        }
    }

    Column {
        id: loginColumn
        opacity: root.showLogin ? 1 : 0
        x: Math.round((parent.width - width) / 2)
        y: Math.round(parent.height * (root.showPower ? 0.84 : 0.88) - height)
        spacing: root.v(12)

        ClippingRectangle {
            x: Math.round((parent.width - width) / 2)
            width: root.v(88)
            height: width
            radius: width / 2
            color: Qt.rgba(1, 1, 1, 0.18)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.25)

            Image {
                id: avatar
                anchors.fill: parent
                source: root.avatarTry < root.avatarSources.length
                        ? root.avatarSources[root.avatarTry] : ""
                onStatusChanged: if (status === Image.Error) root.avatarTry++
                sourceSize.width: Theme.px(root.v(88), avatar)
                sourceSize.height: Theme.px(root.v(88), avatar)
                smooth: false
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }

            Text {
                anchors.centerIn: parent
                visible: !avatar.visible
                text: root.userName.length > 0 ? root.userName[0].toUpperCase() : ""
                color: root.fg
                font.pixelSize: root.v(36)
                font.weight: Font.DemiBold
                font.family: Theme.fontFamily
            }
        }

        Item { width: 1; height: root.v(10) }

        Item {
            x: Math.round((parent.width - width) / 2)
            width: root.v(247)
            height: root.v(37)

            Rectangle {
                id: pill
                width: parent.width
                height: parent.height
                radius: height / 2
                color: Qt.rgba(1, 1, 1, 0.16)
                border.width: 1
                border.color: field.activeFocus ? Qt.rgba(1, 1, 1, 0.4) : Qt.rgba(1, 1, 1, 0.22)

                SequentialAnimation {
                    id: shake
                    loops: 1
                    NumberAnimation { target: pill; property: "x"; to: -root.v(10); duration: 50 }
                    NumberAnimation { target: pill; property: "x"; to: root.v(10); duration: 70 }
                    NumberAnimation { target: pill; property: "x"; to: -root.v(6); duration: 60 }
                    NumberAnimation { target: pill; property: "x"; to: root.v(6); duration: 60 }
                    NumberAnimation { target: pill; property: "x"; to: 0; duration: 50 }
                }

                TextInput {
                    id: field
                    anchors.fill: parent
                    anchors.leftMargin: root.v(17)
                    anchors.rightMargin: root.v(39)
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    color: root.fg
                    selectionColor: Theme.accent
                    font.pixelSize: root.v(14)
                    font.family: Theme.fontFamily
                    font.letterSpacing: root.v(1)
                    enabled: !root.busy
                    focus: true
                    clip: true

                    onTextEdited: {
                        root.errorText = ""
                        root.textTyped(text)
                    }
                    onAccepted: if (text.length > 0) root.submitted(text)

                    Text {
                        y: Math.round((parent.height - height) / 2)
                        visible: field.text.length === 0
                        text: "Enter Password"
                        color: root.fg
                        opacity: 0.55
                        font.pixelSize: root.v(14)
                        font.family: Theme.fontFamily
                    }
                }

                Rectangle {
                    x: parent.width - width - root.v(4)
                    y: Math.round((parent.height - height) / 2)
                    width: parent.height - root.v(9)
                    height: width
                    radius: width / 2
                    color: Qt.rgba(1, 1, 1, field.text.length > 0 ? 0.28 : 0.12)
                    opacity: root.busy ? 0.5 : 1

                    Text {
                        x: Math.round((parent.width - width) / 2)
                        y: Math.round((parent.height - height) / 2) - root.v(1)
                        text: root.busy ? "…" : "→"
                        color: root.fg
                        font.pixelSize: root.v(15)
                        font.family: Theme.fontFamily
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (field.text.length > 0 && !root.busy) root.submitted(field.text)
                    }
                }
            }
        }

        Text {
            x: Math.round((parent.width - width) / 2)
            height: root.v(16)
            text: root.errorText !== "" ? root.errorText
                : root.capsLock ? "Caps Lock is on" : ""
            color: root.fg
            opacity: 0.85
            font.pixelSize: root.v(12)
            font.family: Theme.fontFamily
        }
    }

    Row {
        visible: root.showPower && root.showLogin
        x: Math.round((parent.width - width) / 2)
        y: Math.round(parent.height * 0.96 - height)
        spacing: root.v(12)

        Repeater {
            model: [
                { id: "sleep", label: "Sleep", icon: "sleep" },
                { id: "reboot", label: "Restart", icon: "reboot" },
                { id: "poweroff", label: "Shut Down", icon: "power" }
            ]

            delegate: Column {
                id: action
                required property var modelData
                width: root.v(76)
                spacing: root.v(6)

                Rectangle {
                    x: Math.round((parent.width - width) / 2)
                    width: root.v(40)
                    height: width
                    radius: width / 2
                    color: Qt.rgba(1, 1, 1, area.containsMouse ? 0.26 : 0.16)

                    LineIcon {
                        anchors.centerIn: parent
                        kind: action.modelData.icon
                        size: root.v(18)
                        color: root.fg
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.powerAction(action.modelData.id)
                    }
                }

                Text {
                    x: Math.round((parent.width - width) / 2)
                    text: action.modelData.label
                    color: root.fg
                    opacity: 0.85
                    font.pixelSize: root.v(11)
                    font.family: Theme.fontFamily
                }
            }
        }
    }
}
