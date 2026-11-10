pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var sinks: []
    property string defaultSink: ""
    property bool available: true

    readonly property bool headphonePort: {
        for (var i = 0; i < sinks.length; i++) {
            if (sinks[i].name !== defaultSink) continue
            return /headphone|headset/.test(String(sinks[i].active_port || "").toLowerCase())
        }
        return false
    }

    function refresh() { queryLater.restart() }

    Process {
        id: query
        command: ["sh", "-c", "pactl get-default-sink; pactl -f json list sinks"]
        stdout: StdioCollector {
            onStreamFinished: {
                var nl = text.indexOf("\n")
                if (nl < 0) return
                try {
                    var list = JSON.parse(text.substring(nl + 1))
                    root.defaultSink = text.substring(0, nl).trim()
                    root.sinks = list
                } catch (e) {}
            }
        }
    }

    Timer {
        id: queryLater
        interval: 150
        onTriggered: if (root.available && !query.running) query.running = true
    }

    Process {
        id: subscribe
        running: true
        command: ["sh", "-c", "command -v pactl >/dev/null || exit 127; exec pactl subscribe"]
        stdout: SplitParser {
            onRead: line => { if (/ on (sink|card|server)( |$)/.test(line)) queryLater.restart() }
        }
        onExited: code => {
            if (code === 127) root.available = false
            else restartLater.restart()
        }
    }
    Timer {
        id: restartLater
        interval: 5000
        onTriggered: subscribe.running = true
    }

    Component.onCompleted: refresh()
}
