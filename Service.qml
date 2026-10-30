import QtQuick
import Quickshell.Io
import "bridge" as OmaconnectBridge

Item {
    id: root

    property bool panelOpened: false
    property var appearance: appearanceStore
    property var discovery: discoveryController
    property string ownerPanelMessage: ""
    AppearanceStore { id: appearanceStore }
    DiscoveryController {
        id: discoveryController
        panelOpened: root.panelOpened
        selectedDeviceId: controller.selectedDeviceId
        onRefreshRequested: controller.refresh(false)
    }
    Process {
        id: ownerPanel
        command: ["/usr/bin/timeout", "4", "/usr/bin/omarchy-shell", "shell", "summon", "io.github.ilyazar.syncthing", "{}"]
        stdout: StdioCollector { id: ownerReply; waitForEnd: false; onDataChanged: if (text.length > 8192) ownerPanel.running = false }
        onExited: function(code) {
            root.ownerPanelMessage = code === 0 && ownerReply.text.trim() === "ok" ? "Opened the existing Syncthing panel." : "Syncthing panel unavailable. Enable the existing Syncshell plugin first."
        }
    }
    function openSyncthingPanel() {
        if (!ownerPanel.running) {
            ownerPanelMessage = "Opening the existing Syncthing panel…"
            ownerPanel.running = true
        }
    }
    // Syncthing keeps its own API key; Plus only asks its CLI about one linked device.
    property string syncthingDeviceId: ""
    property string syncthingState: ""  // "paused", "active", "unknown", or "" before a read
    property bool syncthingBusy: false
    property string pendingSyncthingRead: ""
    Process {
        id: syncthingPause
        property string requested: ""
        property bool oversized: false
        command: ["/usr/bin/timeout", "--kill-after=1", "4", "/usr/bin/syncthing", "cli", "config", "devices", root.syncthingDeviceId, "paused"].concat(requested ? ["set", requested] : ["get"])
        onStarted: oversized = false
        stdout: StdioCollector {
            id: syncthingReply
            waitForEnd: false
            onDataChanged: if (text.length > 2048) { syncthingPause.oversized = true; syncthingPause.running = false }
        }
        onExited: function(code) {
            var reply = syncthingReply.text.trim(), changed = requested !== ""
            requested = ""
            if (changed) {
                // A failed or timed-out set can still have changed Syncthing.
                // Reconcile that target before serving the latest selection.
                Qt.callLater(function() { root.startSyncthingRead(root.syncthingDeviceId) })
                return
            }
            root.syncthingState = code !== 0 || oversized ? "unknown"
                : reply === "true" ? "paused" : reply === "false" ? "active" : "unknown"
            var next = root.pendingSyncthingRead
            root.pendingSyncthingRead = ""
            if (next) Qt.callLater(function() { root.startSyncthingRead(next) })
            else root.syncthingBusy = false
        }
    }
    function validSyncthingId(id) { return typeof id === "string" && /^[A-Z2-7]{7}(?:-[A-Z2-7]{7}){7}$/.test(id) }
    function startSyncthingRead(id) {
        syncthingBusy = true
        syncthingDeviceId = id
        syncthingState = ""
        syncthingPause.requested = ""
        syncthingPause.running = true
    }
    function readSyncthingPause(id) {
        if (!validSyncthingId(id)) return false
        if (syncthingBusy) { pendingSyncthingRead = id; return true }
        startSyncthingRead(id)
        return true
    }
    function setSyncthingPaused(id, paused) {
        if (syncthingBusy || !validSyncthingId(id) || id !== syncthingDeviceId || typeof paused !== "boolean"
                || (syncthingState !== "paused" && syncthingState !== "active")) return false
        syncthingBusy = true
        syncthingPause.requested = paused ? "true" : "false"
        syncthingPause.running = true
        return true
    }
    // Fixed app route; the helper rechecks presence and detaches all standard streams.
    readonly property string quickShareHelper: decodeURIComponent(Qt.resolvedUrl("scripts/open_quick_share.py").toString().replace(/^file:\/\//, ""))
    property bool quickShareAvailable: false
    readonly property bool quickShareOpening: quickShareLaunch.running
    property string quickShareMessage: ""
    property bool quickShareFailed: false
    onPanelOpenedChanged: if (panelOpened && !quickShareCheck.running) quickShareCheck.running = true
    Process {
        id: quickShareCheck
        command: ["/usr/bin/timeout", "5", "/usr/bin/python3", root.quickShareHelper, "--check"]
        onExited: function(code) { root.quickShareAvailable = code === 0 }
    }
    Process {
        id: quickShareLaunch
        command: ["/usr/bin/timeout", "5", "/usr/bin/python3", root.quickShareHelper, "--open"]
        onExited: function(code) {
            root.quickShareFailed = code !== 0
            root.quickShareMessage = code === 0 ? "RQuickShare launch requested. Check its window or tray icon."
                : "RQuickShare could not open. Check that r-quick-share is installed and try again."
            if (code !== 0) root.quickShareAvailable = false
        }
    }
    function openQuickShare() {
        if (!quickShareAvailable || quickShareLaunch.running) return false
        quickShareMessage = "Opening RQuickShare…"
        quickShareFailed = false
        quickShareLaunch.running = true
        return true
    }
    function displayName(device) { return device ? appearanceStore.displayName(device.id, device.name) : "KDE Connect" }
    property alias selection: controller.selection
    property alias selectionBytes: controller.selectionBytes
    property alias selectionError: controller.selectionError
    property alias selectionState: controller.selectionState
    property alias draftTarget: controller.draftTarget
    property alias operations: controller.operations
    property alias activeOperation: controller.activeOperation
    property alias operationBusy: controller.operationBusy
    function chooseFiles(id) { return controller.chooseFiles(id) }
    function stageDroppedFiles(id, urls) { return controller.stageDroppedFiles(id, urls) }
    function submitSelection() { return controller.submitSelection() }
    function cancelDraft() { return controller.cancelDraft() }
    function clearOperations() { return controller.clearOperations() }
    function cancelOperation() { return controller.cancelOperation() }

    property string omarchyPath: ""
    property var shell: null
    property var manifest: null
    property var pluginRegistry: null

    Component.onCompleted: {
        // Publish for widgets hosted by replacement bars, whose `bar.shell`
        // facade cannot resolve plugin services. See bridge/Bridge.qml;
        // the host facade stays the primary path.
        OmaconnectBridge.Bridge.service = root
        quickShareCheck.running = true
    }

    // Unpublish so a widget falling back to the bridge never binds to a
    // dying instance.
    Component.onDestruction: {
        if (OmaconnectBridge.Bridge.service === root) {
            OmaconnectBridge.Bridge.service = null
        }
    }

    KdeConnectController {
        id: controller
    }

    property alias daemonAvailable: controller.daemonAvailable
    property alias sessionBusAvailable: controller.sessionBusAvailable
    property alias scanning: controller.scanning
    property alias discoveryState: controller.discoveryState
    property alias discoveryMessage: controller.discoveryMessage
    property alias actionState: controller.actionState
    property alias actionMessage: controller.actionMessage
    property alias actionError: controller.actionError
    property alias nativeAppOpening: controller.nativeAppOpening
    property alias nativeAppMessage: controller.nativeAppMessage
    property alias nativeAppFailed: controller.nativeAppFailed
    property alias devices: controller.devices
    property alias reachableDevices: controller.reachableDevices
    property alias selectedDeviceId: controller.selectedDeviceId
    property alias selectedDevice: controller.selectedDevice
    property alias incomingPairRequest: controller.incomingPairRequest
    property alias remoteCommands: controller.remoteCommands
    property alias commandsLoading: controller.commandsLoading
    property alias pendingPairing: controller.pendingPairing
    property alias fileBusy: controller.fileBusy
    property alias fileTransferState: controller.fileTransferState
    property alias fileTransferMessage: controller.fileTransferMessage
    property alias fileTransferError: controller.fileTransferError
    property alias tailscaleInstalled: controller.tailscaleInstalled
    property alias tailscaleRunning: controller.tailscaleRunning
    property alias tailscaleLoading: controller.tailscaleLoading
    property alias tailscaleStatus: controller.tailscaleStatus
    property alias localTailscaleAddress: controller.localTailscaleAddress
    property alias tailscalePeers: controller.tailscalePeers
    property alias customAddresses: controller.customAddresses
    property alias customAddressesReady: controller.customAddressesReady
    property alias addressBusy: controller.addressBusy
    property alias mediaState: controller.mediaState
    property alias mediaLoading: controller.mediaLoading

    function refresh(forceNetwork) {
        controller.refresh(forceNetwork)
    }

    function selectDevice(id) {
        controller.selectDevice(id)
    }

    function clearActionState() {
        controller.clearActionState()
    }

    function setPendingPairing(id, state) {
        controller.setPendingPairing(id, state)
    }

    function pingDevice(id, text) {
        return controller.pingDevice(id, text)
    }

    function shareText(id, text) {
        return controller.shareText(id, text)
    }

    function fetchRemoteCommands(id) {
        return controller.fetchRemoteCommands(id)
    }

    function executeRemoteCommand(id, key) {
        return controller.executeRemoteCommand(id, key)
    }

    function pairDevice(id) {
        return controller.pairDevice(id)
    }

    function unpairDevice(id) {
        return controller.unpairDevice(id)
    }

    function acceptPairing(id) {
        return controller.acceptPairing(id)
    }

    function rejectPairing(id) {
        return controller.rejectPairing(id)
    }

    function ringDevice(id) {
        return controller.ringDevice(id)
    }

    function sendClipboard(id) {
        return controller.sendClipboard(id)
    }

    function startFileSelection(id) {
        return controller.startFileSelection(id)
    }

    function cancelFileSelection() {
        return controller.cancelFileSelection()
    }

    function cancelFileTransfer() {
        return controller.cancelFileTransfer()
    }

    function sendFile(id, path) {
        return controller.sendFile(id, path)
    }

    function openSmsApp(id) {
        return controller.openSmsApp(id)
    }

    function openKdeConnectApp(pluginId) {
        return controller.openKdeConnectApp(pluginId)
    }
    function toggleVirtualMonitor(id) { return controller.toggleVirtualMonitor(id) }
    function editRemoteCommands(id) { return controller.editRemoteCommands(id) }

    function refreshTailscale() {
        controller.refreshTailscale()
    }

    function addCustomAddress(address) {
        return controller.addCustomAddress(address)
    }

    function removeCustomAddress(address) {
        return controller.removeCustomAddress(address)
    }

    function filteredTailscalePeers(query) {
        return controller.filteredTailscalePeers(query)
    }

    function addressError(address) {
        return controller.addressError(address)
    }

    function formatVerificationKey(key) {
        return controller.formatVerificationKey(key)
    }

    function deviceOverviewStatus(device) {
        return controller.deviceOverviewStatus(device)
    }

    function deviceTypeIcon(type) {
        return controller.deviceTypeIcon(type)
    }

    function deviceBatteryText(device, showBattery, showNetwork) {
        return controller.deviceBatteryText(device, showBattery, showNetwork)
    }

    function deviceBatteryIcon(device) {
        return controller.deviceBatteryIcon(device)
    }

    function deviceNetworkIcon(device) {
        return controller.deviceNetworkIcon(device)
    }

    function fetchMediaStatus(id) {
        return controller.fetchMediaStatus(id)
    }

    function requestPlayerList(id) {
        return controller.requestPlayerList(id)
    }

    function mediaPlayPause(id) {
        return controller.mediaPlayPause(id)
    }

    function mediaNext(id) {
        return controller.mediaNext(id)
    }

    function mediaPrevious(id) {
        return controller.mediaPrevious(id)
    }

    function mediaSelectPlayer(id, playerName) {
        return controller.mediaSelectPlayer(id, playerName)
    }
}
