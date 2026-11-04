pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

// One native mount handoff. Send drafts and transfer operations have separate owners.
Item {
    id: root
    property string selectedPeerId: ""
    property var device: null
    state: "idle"
    property string message: ""
    property var locations: []
    property string capturedPeerId: ""
    property int generation: 0
    property bool inFlight: false
    readonly property bool busy: inFlight || state === "preparing" || state === "opening"
    readonly property string helperPath: decodeURIComponent(Qt.resolvedUrl("../scripts/browse_phone_files.py").toString().replace(/^file:\/\//, ""))

    function currentPeer() {
        return !!device && device.id === selectedPeerId && device.paired === true && device.reachable === true
    }
    function validLocation(value) {
        return !!value && typeof value === "object" && value.peerId === capturedPeerId
            && typeof value.name === "string" && value.name.length > 0 && value.name.length <= 160
            && !/[\x00-\x1f]/.test(value.name)
            && typeof value.path === "string" && value.path.length <= 4096 && value.path[0] === "/"
            && typeof value.mountPath === "string" && value.mountPath.length <= 4096 && value.mountPath[0] === "/"
            && typeof value.providerOwner === "string" && /^:[0-9]+\.[0-9]+$/.test(value.providerOwner)
            && [value.mountIdentity,value.rootIdentity,value.advertisements].every(function(item) {
                return typeof item === "string" && /^[0-9a-f]{64}$/.test(item)
            })
    }
    function errorText(code) {
        var messages = {
            "invalid-input": "Phone files request rejected. Choose the phone and try again.",
            "provider-unavailable": "KDE Connect is unavailable. Open native KDE Connect.",
            "peer-unpaired": "Pair this phone in native KDE Connect, then try again.",
            "peer-offline": "The phone is offline. Reconnect it and try again.",
            "capability-unavailable": "Enable Filesystem expose in the phone's KDE Connect settings.",
            "mount-failed": "KDE Connect could not mount phone storage. Check native KDE Connect.",
            "no-shares": "The phone shares no folders. Check its Filesystem expose settings.",
            "share-limit": "The shared folder list is too large. Use native KDE Connect.",
            "location-changed": "Phone storage changed. Select Browse phone files again.",
            "storage-timeout": "Phone storage did not respond in time. Try again.",
            "opener-unavailable": "Set a default file manager, then try again.",
            "cancelled": "Browse cancelled. A file manager already opening can still appear.",
            "storage-unavailable": "Phone storage could not be verified. Try again or open native KDE Connect."
        }
        return messages[code] || messages["storage-unavailable"]
    }
    function fail(code) {
        locations = []
        state = "failed"
        message = errorText(code)
    }
    function browse(id) {
        if (busy || !currentPeer() || id !== selectedPeerId) return false
        generation++
        capturedPeerId = id
        locations = []
        start("prepare", null)
        return true
    }
    function start(operation, location) {
        if (inFlight || worker.running || !currentPeer() || capturedPeerId !== selectedPeerId) return false
        var request = {peerId:capturedPeerId, operation:operation}
        if (operation === "open") request.location = location
        worker.payload = JSON.stringify(request) + "\n"
        worker.targetGeneration = generation
        worker.targetPeer = capturedPeerId
        worker.operation = operation
        worker.oversized = false
        worker.stdinEnabled = true
        inFlight = true
        state = operation === "prepare" ? "preparing" : "opening"
        message = operation === "prepare" ? "Preparing phone storage…" : "Opening phone files…"
        worker.running = true
        return true
    }
    function choose(index) {
        if (state !== "choosing" || busy || !Number.isInteger(index) || index < 0 || index >= locations.length) return false
        var location = locations[index]
        if (!validLocation(location)) { fail("invalid-input"); return false }
        return start("open", location)
    }
    function cancel(silent) {
        var opening = state === "opening"
        generation++
        locations = []
        capturedPeerId = ""
        state = silent ? "idle" : "cancelled"
        message = silent ? "" : opening ? errorText("cancelled") : "Browse cancelled."
        if (worker.running) { worker.signal(15); killTimer.restart() }
    }
    function finish(code) {
        killTimer.stop()
        inFlight = false
        worker.payload = ""
        worker.stdinEnabled = true
        if (worker.targetGeneration !== generation || worker.targetPeer !== selectedPeerId || !currentPeer()) return
        var result
        try { result = !worker.oversized && reply.text.length <= 16384 ? JSON.parse(reply.text) : null } catch (_) { result = null }
        if (!result || code !== 0 || result.state === "failed") {
            fail(result && typeof result.error === "string" ? result.error : code === 124 || code === 137 ? "storage-timeout" : "storage-unavailable")
            return
        }
        if (worker.operation === "open") {
            if (result.state !== "opened") { fail("storage-unavailable"); return }
            locations = []
            state = "opened"
            message = "File manager launch requested. Check the file manager window."
            return
        }
        if (result.state !== "prepared" || result.peerId !== capturedPeerId || !Array.isArray(result.locations)
                || result.locations.length < 1 || result.locations.length > 16 || !result.locations.every(root.validLocation)) {
            fail("storage-unavailable")
            return
        }
        locations = result.locations
        state = "choosing"
        message = locations.length === 1 ? "Phone storage ready…" : "Choose a shared folder."
        if (locations.length === 1) {
            var preparedGeneration = generation
            Qt.callLater(function() {
                if (root.generation === preparedGeneration && root.state === "choosing" && root.currentPeer()) root.choose(0)
            })
        }
    }
    onSelectedPeerIdChanged: cancel(true)
    onDeviceChanged: {
        if (capturedPeerId !== "" && !currentPeer()) cancel(true)
    }
    Component.onDestruction: if (worker.running) worker.signal(15)

    Timer { id: killTimer; interval: 1000; onTriggered: if (worker.running) worker.signal(9) }
    Process {
        id: worker
        property string payload: ""
        property int targetGeneration: -1
        property string targetPeer: ""
        property string operation: ""
        property bool oversized: false
        command: ["/usr/bin/timeout", "--kill-after=1", "30", "/usr/bin/python3", root.helperPath]
        stdinEnabled: true
        onStarted: {
            if (targetGeneration === root.generation && targetPeer === root.selectedPeerId && root.currentPeer()) write(payload)
            else { signal(15); killTimer.restart() }
            payload = ""
            stdinEnabled = false
        }
        stdout: StdioCollector {
            id: reply
            waitForEnd: false
            onDataChanged: if (text.length > 16384 && !worker.oversized) {
                worker.oversized = true
                worker.signal(15)
                killTimer.restart()
            }
        }
        stderr: StdioCollector {
            waitForEnd: false
            onDataChanged: if (text.length > 2048 && !worker.oversized) {
                worker.oversized = true
                worker.signal(15)
                killTimer.restart()
            }
        }
        onExited: function(code) { root.finish(code) }
        onRunningChanged: if (!running) Qt.callLater(function() {
            if (!worker.running && root.inFlight) root.finish(-1)
        })
    }
}
