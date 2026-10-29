pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "DiscoveryModel.js" as Model

Item {
    id: root
    property bool panelOpened: false
    property bool autoDiscoveryEnabled: false
    property string selectedDeviceId: ""
    property var addresses: []
    property var customAddresses: []
    property bool ready: false
    property string error: ""
    property var queue: []
    property double backoffUntil: 0
    property bool refreshPending: false
    property bool routeMonitorAvailable: true
    property string nmMonitorPath: "/usr/bin/nmcli"
    readonly property bool busy: helper.running || queue.length > 0
    readonly property string helperPath: decodeURIComponent(Qt.resolvedUrl("scripts/manage_addresses.py").toString().replace(/^file:\/\//, ""))
    signal refreshRequested()

    function batch(changes, automatic) {
        if (!Array.isArray(changes) || changes.length > Model.MAX_BATCH || queue.length >= 8) {
            error = Model.errorText("batch-limit")
            return false
        }
        if (automatic && (!autoDiscoveryEnabled || !panelOpened)) return false
        var copied
        try { copied = JSON.parse(JSON.stringify(changes)) } catch (_) { return false }
        queue = queue.concat([{changes: copied, automatic: !!automatic}])
        pump()
        return true
    }
    function pump() {
        if (helper.running || !queue.length) return
        var next = queue[0]
        queue = queue.slice(1)
        if (next.automatic && (!autoDiscoveryEnabled || !panelOpened)) { pump(); return }
        helper.payload = JSON.stringify({changes: next.changes})
        helper.automatic = next.automatic
        helper.stdinEnabled = true
        helper.running = true
    }
    function addAddress(peerId, address, source, autoDiscover) {
        return batch([{op: "add", peer_id: peerId, address: address, source: source || "manual", auto_discover: !!autoDiscover, approved: true}], false)
    }
    function removeAddress(peerId, address, removeFromKde, source) {
        return batch([{op: "remove", peer_id: peerId, address: address, source: source || "manual", remove_from_kde: !!removeFromKde, approved: !!removeFromKde}], false)
    }
    function setAutoDiscover(peerId, address, enabled, source) {
        return batch([{op: "auto", peer_id: peerId, address: address, source: source || "manual", auto_discover: !!enabled, approved: true}], false)
    }
    function refreshAddresses() {
        if (!busy) batch([], false)
    }
    function requestDiscovery(manual) {
        if (manual) {
            refreshPending = true
            if (!busy) batch([], false)
            return
        }
        if (!Model.canAuto(autoDiscoveryEnabled, panelOpened, addresses, Date.now(), backoffUntil) || busy) return
        var changes = Model.approvedChanges(addresses)
        for (var i=0; i<changes.length; i+=Model.MAX_BATCH) batch(changes.slice(i,i+Model.MAX_BATCH), true)
    }
    // Also accepts the existing BTH public-state event. A local WireGuard
    // interface is not required: the remote phone may own BTH.
    function routeChanged() {
        if (autoDiscoveryEnabled && panelOpened) debounce.restart()
    }
    function stopAutomatic() {
        debounce.stop()
        queue = queue.filter(function(entry) { return !entry.automatic })
        if (helper.running && helper.automatic) helper.running = false
    }
    onAutoDiscoveryEnabledChanged: {
        if (!autoDiscoveryEnabled) stopAutomatic()
        else if (panelOpened) requestDiscovery(false)
    }
    onPanelOpenedChanged: {
        if (panelOpened) { refreshAddresses(); refreshPending = autoDiscoveryEnabled }
        else stopAutomatic()
    }
    Timer {
        id: debounce
        interval: 2000
        onTriggered: root.requestDiscovery(false)
    }
    Timer {
        interval: 60000
        repeat: true
        running: root.autoDiscoveryEnabled && root.panelOpened
        onTriggered: {
            root.requestDiscovery(false)
            if (Date.now() >= root.backoffUntil) root.routeMonitorAvailable = true
        }
    }
    // Optional read-only NM event source. It exists only during opted-in open
    // panels, drops event text, and never changes a NetworkManager property.
    Process {
        id: routeMonitor
        command: [root.nmMonitorPath, "monitor"]
        running: root.panelOpened && root.autoDiscoveryEnabled && root.routeMonitorAvailable
        stdout: SplitParser {
            onRead: function(line) { if (line.length <= 8192) root.routeChanged() }
        }
        onExited: function(code) {
            if (code !== 0 && root.panelOpened && root.autoDiscoveryEnabled) {
                root.routeMonitorAvailable = false
                root.backoffUntil = Date.now() + 300000
            }
        }
    }
    Process {
        id: helper
        property string payload: ""
        property bool automatic: false
        property bool oversized: false
        command: ["/usr/bin/timeout", "5", "/usr/bin/python3", root.helperPath]
        stdinEnabled: true
        onStarted: {
            oversized = false
            write(payload + "\n")
            stdinEnabled = false
        }
        stdout: StdioCollector {
            id: reply
            waitForEnd: false
            onDataChanged: if (text.length > Model.MAX_BYTES) { helper.oversized = true; helper.running = false }
        }
        // Neither private external addresses nor raw stderr are logged.
        onExited: function(code) {
            var result = !oversized ? Model.parse(reply.text) : null
            if (code === 0 && result && result.ok) {
                root.addresses = result.addresses
                root.customAddresses = result.customAddresses
                root.ready = true
                root.error = ""
                if ((automatic && root.queue.length === 0) || root.refreshPending) {
                    if (!automatic || (root.autoDiscoveryEnabled && root.panelOpened)) root.refreshRequested()
                    root.refreshPending = false
                }
            } else {
                root.ready = false
                root.error = result && !result.ok ? result.error : Model.errorText("address-timeout")
                root.backoffUntil = Date.now() + 300000
                root.refreshPending = false
                root.queue = root.queue.filter(function(entry) { return !entry.automatic })
            }
            Qt.callLater(root.pump)
        }
    }
}
