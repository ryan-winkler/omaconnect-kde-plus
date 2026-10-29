pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit

Column {
    id: root
    required property var panel
    spacing: Style.space(6)
    property string message: ""
    property bool configuration: false
    readonly property bool busy: opener.running || preferences.running
    readonly property bool tailscaleEnabled: valueFor("networkTailscaleEnabled")
    readonly property bool bthEnabled: valueFor("networkBthEnabled")
    readonly property bool wireguardEnabled: valueFor("networkWireguardEnabled")
    readonly property string helperPath: localScript("open_network_owner.py")
    readonly property var providers: [
        {key: "networkTailscaleEnabled", label: "Tailscale", description: "Adds an Open Tailscale panel button. Then save the other device's Tailscale IP under Manage saved addresses.", help: "https://tailscale.com/docs/how-to/quickstart"},
        {key: "networkBthEnabled", label: "MikroTik Back to Home", description: "Adds Automatic, On and Off buttons when your Back to Home script is installed. Then save the other device's BTH IP under Manage saved addresses.", help: "https://manual.mikrotik.com/docs/network-management/cloud/back-to-home/"},
        {key: "networkWireguardEnabled", label: "Other WireGuard profiles", description: "Adds an Open WireGuard profiles button for NetworkManager. Then save the other device's VPN IP under Manage saved addresses.", help: "https://www.wireguard.com/quickstart/"}
    ]
    function localScript(name) {
        return decodeURIComponent(Qt.resolvedUrl("../scripts/" + name).toString().replace(/^file:\/\//, ""))
    }
    function valueFor(key) { return !!(panel && panel.getSetting(key, false) === true) }
    function savePreference(key, enabled) {
        if (busy || !providers.some(function(p) { return p.key === key }) || typeof enabled !== "boolean") return
        message = "Saving display setting…"
        preferences.payload = JSON.stringify({key: key, enabled: enabled})
        preferences.running = true
    }
    function openOwner(owner) {
        if (busy || (owner === "tailscale" ? !tailscaleEnabled : owner === "wireguard" ? !wireguardEnabled : true)) return
        message = "Opening the existing network manager…"
        opener.command = ["/usr/bin/timeout", "5", "/usr/bin/python3", helperPath, owner]
        opener.running = true
    }
    function feedback(code, text, oversized) {
        var result
        try { result = !oversized ? JSON.parse(text) : null } catch (_) { result = null }
        return result && typeof result.ok === "boolean" && typeof result.message === "string" && result.message.length < 512
            && (code === 0) === result.ok ? result.message : "Request was not confirmed. Check the saved setting and try again."
    }
    Column {
        width: parent.width
        visible: root.configuration
        spacing: Style.space(8)
        Text {
            width: parent.width
            text: "Turn on the VPN tools you use. These switches only show or hide buttons in Devices. They never connect or disconnect a VPN."
            textFormat: Text.PlainText
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.Wrap
        }
        Repeater {
            model: root.providers
            delegate: Column {
                required property var modelData
                width: parent.width
                spacing: Style.space(4)
                Kit.Toggle {
                    width: parent.width
                    label: "Show " + modelData.label + (root.valueFor(modelData.key) ? ": On" : ": Off")
                    Accessible.role: Accessible.CheckBox
                    Accessible.name: "Show " + modelData.label
                    Accessible.checkable: true
                    Accessible.checked: checked
                    enabled: !root.busy
                    foreground: Commons.Color.popups.text
                    checked: root.valueFor(modelData.key)
                    onClicked: root.savePreference(modelData.key, !root.valueFor(modelData.key))
                }
                Text {
                    width: parent.width
                    text: modelData.description
                    textFormat: Text.PlainText
                    color: Commons.Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    wrapMode: Text.Wrap
                }
                Kit.Button {
                    width: parent.width
                    text: modelData.label + " help ↗"
                    Accessible.name: "Open official " + modelData.label + " help in your browser"
                    focusable: true
                    foreground: Commons.Color.popups.text
                    onClicked: Qt.openUrlExternally(modelData.help)
                }
            }
        }
    }
    Kit.Button {
        width: parent.width
        visible: !root.configuration && root.tailscaleEnabled
        focusable: true
        foreground: Commons.Color.popups.text
        text: "Open Tailscale panel"
        Accessible.name: text
        enabled: !root.busy
        onClicked: root.openOwner("tailscale")
    }
    Kit.Button {
        width: parent.width
        visible: !root.configuration && root.wireguardEnabled
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
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.Wrap
    }
    Process {
        id: preferences
        property string payload: ""
        property bool oversized: false
        command: ["/usr/bin/timeout", "5", "/usr/bin/python3", root.localScript("network_preferences.py")]
        stdinEnabled: true
        onStarted: { oversized = false; write(payload); stdinEnabled = false }
        stdout: StdioCollector {
            id: preferenceReply
            waitForEnd: false
            onDataChanged: if (text.length > 8192) { preferences.oversized = true; preferences.running = false }
        }
        onExited: function(code) {
            root.message = root.feedback(code, preferenceReply.text, oversized)
            stdinEnabled = true
        }
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
        onExited: function(code) { root.message = root.feedback(code, reply.text, oversized) }
    }
}
