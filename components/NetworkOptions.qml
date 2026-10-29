pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit

Column {
    id: root
    spacing: Style.space(6)
    property string message: ""
    readonly property bool busy: opener.running
    readonly property string helperPath: decodeURIComponent(Qt.resolvedUrl("../scripts/open_network_owner.py").toString().replace(/^file:\/\//, ""))

    function openOwner(owner) {
        if (busy || ["tailscale", "wireguard"].indexOf(owner) < 0) return
        message = "Opening the existing network manager…"
        opener.command = ["/usr/bin/timeout", "5", "/usr/bin/python3", helperPath, owner]
        opener.running = true
    }
    Text {
        width: parent.width
        text: "Tailscale · Back to Home · WireGuard"
        textFormat: Text.PlainText
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
        wrapMode: Text.Wrap
    }
    Text {
        width: parent.width
        text: "Use any existing connection, then save its peer IP under Manage saved addresses. Back to Home uses the reviewed controller below. Tailscale and other WireGuard profiles stay with their native managers."
        textFormat: Text.PlainText
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
    }
    Kit.Button {
        width: parent.width
        focusable: true
        foreground: Commons.Color.popups.text
        text: "Open Tailscale panel"
        Accessible.name: text
        enabled: !root.busy
        onClicked: root.openOwner("tailscale")
    }
    Kit.Button {
        width: parent.width
        focusable: true
        foreground: Commons.Color.popups.text
        text: "Open WireGuard profiles"
        Accessible.name: text
        enabled: !root.busy
        onClicked: root.openOwner("wireguard")
    }
    Text {
        width: parent.width
        visible: text !== ""
        text: root.message
        textFormat: Text.PlainText
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
    }
    Process {
        id: opener
        property bool oversized: false
        onStarted: oversized = false
        stdout: StdioCollector {
            id: reply
            waitForEnd: false
            onDataChanged: if (text.length > 8192) { opener.oversized = true; opener.running = false }
        }
        onExited: function(code) {
            var result
            try { result = !oversized ? JSON.parse(reply.text) : null } catch (_) { result = null }
            root.message = result && typeof result.ok === "boolean" && typeof result.message === "string" && result.message.length < 512
                ? result.message : "Network manager unavailable. Use your existing VPN app."
        }
    }
}
