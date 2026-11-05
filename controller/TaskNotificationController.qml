pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import qs.Commons as Commons

// Desktop notices report final Plus requests. KDE owns delivery and history.
Item {
    id: root
    property bool includeDeviceName: false
    property bool panelOpened: false
    property bool sendWindowOpened: false
    readonly property bool suppressed: !enabled || panelOpened || sendWindowOpened
    property string message: ""
    property var pending: []
    property bool inFlight: false
    property int policyGeneration: 0
    readonly property string helperPath: decodeURIComponent(Qt.resolvedUrl("../scripts/task_notification.py").toString().replace(/^file:\/\//, ""))
    Commons.Translations { id: strings; directory: Qt.resolvedUrl("../i18n") }

    onSuppressedChanged: if (suppressed) { pending = []; policyGeneration++ }
    onIncludeDeviceNameChanged: { pending = []; policyGeneration++ }

    function notify(operation) {
        if (suppressed || !operation) return false
        var keys = {
            request_accepted: "accepted", submission_failed: "failed",
            submission_unknown: "unknown", cancelled_before_submit: "cancelled",
            cancellation_unconfirmed: "unconfirmed"
        }
        var key = keys[operation.state]
        if (typeof key !== "string") return false
        var payload = {
            summary: strings.t("notice." + key + ".title"),
            body: strings.t("notice." + key + ".body"),
            includeDeviceName: includeDeviceName,
            deviceName: includeDeviceName && typeof operation.peerName === "string" && operation.peerName !== operation.peerId
                ? Array.from(operation.peerName).slice(0, 128).join("") : ""
        }
        // ponytail: keep only the latest three waiting outcomes; Activity keeps all 50.
        pending = pending.concat([payload]).slice(-3)
        Qt.callLater(root.startNext)
        return true
    }

    function startNext() {
        if (suppressed) { pending = []; return }
        if (inFlight || sender.running || !pending.length) return
        sender.payload = JSON.stringify(pending[0]) + "\n"
        pending = pending.slice(1)
        sender.oversized = false
        sender.discarded = false
        sender.targetGeneration = policyGeneration
        inFlight = true
        sender.stdinEnabled = true
        sender.running = true
    }

    function finished(ok) {
        if (!inFlight) return
        inFlight = false
        sender.payload = ""
        sender.stdinEnabled = true
        message = ok ? "" : strings.t("notice.unavailable")
        Qt.callLater(root.startNext)
    }

    Process {
        id: sender
        property string payload: ""
        property bool oversized: false
        property bool discarded: false
        property int targetGeneration: -1
        command: ["/usr/bin/timeout", "--kill-after=1", "5", "/usr/bin/python3", root.helperPath]
        stdinEnabled: true
        onStarted: {
            discarded = root.suppressed || targetGeneration !== root.policyGeneration
            if (!discarded) write(payload)
            payload = ""
            stdinEnabled = false
        }
        onRunningChanged: if (!running) Qt.callLater(function() { if (!sender.running) root.finished(sender.discarded) })
        stdout: StdioCollector {
            id: reply
            waitForEnd: false
            onDataChanged: if (text.length > 2048) { sender.oversized = true; sender.running = false }
        }
        stderr: StdioCollector {
            waitForEnd: false
            onDataChanged: if (text.length > 2048) { sender.oversized = true; sender.running = false }
        }
        onExited: function(code) {
            var result
            try { result = !oversized ? JSON.parse(reply.text) : null } catch (_) { result = null }
            root.finished(discarded || (code === 0 && !!result && result.ok === true))
        }
    }
}
