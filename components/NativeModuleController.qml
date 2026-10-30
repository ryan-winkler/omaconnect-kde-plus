pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

QtObject {
    id: root
    required property var service
    property var modules: []
    property bool active: false
    readonly property var device: service ? service.selectedDevice : null
    readonly property string peerId: device ? String(device.id || "") : ""
    readonly property bool ready: active && !!service && service.daemonAvailable === true
        && !!device && device.paired === true && /^[A-Za-z0-9][A-Za-z0-9_]{0,127}$/.test(peerId)
    readonly property var pluginIds: {
        var ids = []
        if (!Array.isArray(modules) || modules.length > 256) return ids
        for (var i = 0; i < modules.length; ++i) {
            var id = modules[i] ? modules[i].id : null
            if (typeof id === "string" && /^[A-Za-z0-9_][A-Za-z0-9_.-]{0,127}$/.test(id) && ids.indexOf(id) < 0) ids.push(id)
        }
        return ids
    }
    property var enabledStates: ({})
    property string message: ""
    property string error: ""
    readonly property bool busy: inFlight
    property bool inFlight: false
    property bool queuedRead: false
    property int generation: 0
    property var job: null
    property bool oversized: false
    readonly property string helperPath: decodeURIComponent(Qt.resolvedUrl("../scripts/native_settings.py").toString().replace(/^file:\/\//, ""))

    function known(id) { return Object.prototype.hasOwnProperty.call(enabledStates, id) && typeof enabledStates[id] === "boolean" }
    function invalidate() {
        generation += 1
        enabledStates = ({})
        message = ""
        error = ""
        queuedRead = ready && pluginIds.length > 0
        // Writes retain their original target. Never cancel and replay a write.
        if (inFlight && job && job.operation === "read") process.running = false
        pump.restart()
    }
    onPeerIdChanged: invalidate()
    onReadyChanged: invalidate()
    onPluginIdsChanged: invalidate()

    function refresh() {
        if (!ready || !pluginIds.length) return false
        queuedRead = true
        if (!inFlight) pump.restart()
        return true
    }
    function setEnabled(id, enabled) {
        if (!ready || inFlight || pluginIds.indexOf(id) < 0 || !known(id) || typeof enabled !== "boolean") return false
        if (enabledStates[id] === enabled) return false
        queuedRead = false
        start({operation:"set", peerId:peerId, pluginId:id, enabled:enabled})
        return true
    }
    function start(request) {
        if (!ready || inFlight) return
        job = {operation:request.operation, peerId:request.peerId, pluginId:request.pluginId || "",
            ids:request.operation === "read" ? request.pluginIds.slice() : [request.pluginId], generation:generation}
        process.payload = JSON.stringify(request)
        oversized = false
        inFlight = true
        message = request.operation === "read" ? "Reading native feature settings…" : "Updating native feature setting…"
        error = ""
        process.stdinEnabled = true
        process.running = true
    }
    function parseReply(text, currentJob) {
        if (oversized || text.length > 65536) return null
        var value
        try { value = JSON.parse(text) } catch (exception) { return null }
        if (!value || Array.isArray(value) || Object.keys(value).sort().join(",") !== "enabled,error,peerId,state"
            || value.peerId !== currentJob.peerId || !value.enabled || Array.isArray(value.enabled)
            || typeof value.enabled !== "object" || typeof value.error !== "string") return null
        var ids = Object.keys(value.enabled)
        if (ids.length > currentJob.ids.length) return null
        for (var i = 0; i < ids.length; ++i)
            if (currentJob.ids.indexOf(ids[i]) < 0 || typeof value.enabled[ids[i]] !== "boolean") return null
        if (value.state === "observed") {
            if (ids.length !== currentJob.ids.length) return null
            if (value.error !== "" && !(currentJob.operation === "set" && value.error === "readback-mismatch")) return null
        } else if (value.state === "unknown") {
            if (currentJob.operation !== "set" || value.error !== "submission-unknown" || ids.length) return null
        } else if (value.state === "failed") {
            if (["invalid-input", "provider-unavailable", "capability-unavailable"].indexOf(value.error) < 0) return null
            if (currentJob.operation === "set" && ids.length) return null
        } else return null
        return value
    }
    function finish(code) {
        var finished = job
        inFlight = false
        job = null
        if (finished && finished.generation === generation && ready && finished.peerId === peerId) {
            var reply = parseReply(output.text.trim(), finished)
            if (reply && code !== 0 && reply.state === "observed" && reply.error === "") reply = null
            var states = finished.operation === "read" ? ({}) : Object.assign({}, enabledStates)
            if (reply) {
                var ids = Object.keys(reply.enabled)
                for (var i = 0; i < ids.length; ++i) states[ids[i]] = reply.enabled[ids[i]]
            }
            if (finished.operation === "set" && (!reply || reply.state !== "observed")) delete states[finished.pluginId]
            enabledStates = states
            error = reply ? reply.error : finished.operation === "set" ? "submission-unknown" : "provider-unavailable"
            message = error === "submission-unknown" ? "Change unconfirmed. Refresh native settings before you try again."
                : error === "readback-mismatch" ? "KDE Connect reports a different value. The observed setting is shown."
                : error ? "Native settings unavailable. Refresh to read the current state."
                : finished.operation === "set" ? "Native setting confirmed." : "Native settings are current."
        }
        if (queuedRead) pump.restart()
    }
    readonly property Timer pump: Timer {
        interval: 0
        onTriggered: {
            if (!root.inFlight && root.queuedRead && root.ready && root.pluginIds.length) {
                root.queuedRead = false
                root.start({operation:"read", peerId:root.peerId, pluginIds:root.pluginIds})
            }
        }
    }
    readonly property Process process: Process {
        command: ["/usr/bin/timeout", "--kill-after=1", "6", "/usr/bin/python3", root.helperPath]
        property string payload: ""
        stdinEnabled: true
        onStarted: { write(payload); payload = ""; stdinEnabled = false }
        stdout: StdioCollector {
            id: output
            waitForEnd: false
            onDataChanged: if (text.length > 65536) { root.oversized = true; root.process.running = false }
        }
        stderr: StdioCollector {
            waitForEnd: false
            onDataChanged: if (text.length > 65536) { root.oversized = true; root.process.running = false }
        }
        onExited: function(code) { root.finish(code) }
    }
}
