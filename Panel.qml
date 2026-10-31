pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Window
import QtQml.Models as Models
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "./components"
import "bridge" as OmaconnectBridge
import "ActionCatalog.js" as Actions

Panel {
    id: root
    moduleName: "omaconnect.plus"
    ipcTarget: "omaconnect.plus"
    manageIpc: false

    property var anchorItem: hostWidget && hostWidget.button ? hostWidget.button : null
    property var hostWidget: null
    readonly property var barIdentity: hostWidget || root
    readonly property Item focusTarget: keyCatcher

    // hostWidget.service already carries the bridge fallback (see
    // BarWidget.qml); the bridge here covers standalone instantiation with
    // no host widget. See bridge/Bridge.qml.
    readonly property var service: hostWidget && hostWidget.service ? hostWidget.service : (bar && bar.shell && typeof bar.shell.serviceFor === "function" ? (bar.shell.serviceFor("omaconnect.plus") || OmaconnectBridge.Bridge.service) : OmaconnectBridge.Bridge.service)
    readonly property var device: service ? service.selectedDevice : null
    readonly property string deviceName: service ? service.displayName(device) : "KDE Connect"
    readonly property var incomingRequest: service ? service.incomingPairRequest : null
    readonly property var sectionCatalog: sectionCatalogModel
    property bool deviceDetailsExpanded: getSetting("devicesStartExpanded", true)
    property bool actionsExpanded: getSetting("actionsStartExpanded", true)
    property bool inlineSendExpanded: getSetting("inlineSendStartExpanded", false)
    property bool nativeFeaturesExpanded: getSetting("nativeFeaturesStartExpanded", false)
    property bool informationExpanded: getSetting("informationStartExpanded", false)
    property bool dropActionRevealed: false
    PanelSectionCatalog {
        id: sectionCatalogModel
        storedOrder: root.getSetting("sectionOrder", "")
        expectedIds: {
            var ids = []
            for (var i = 0; i < sectionItems.count; i++) ids.push(sectionItems.get(i).sectionId)
            return ids
        }
        onOrderChanged: Qt.callLater(root.reorderSections)
        onReadyChanged: if (ready) { root.restoreSectionExpansion(); Qt.callLater(root.reorderSections) }
    }
    readonly property var sectionExpansionFields: ({devices:"deviceDetailsExpanded", actions:"actionsExpanded", drop:"inlineSendExpanded", native:"nativeFeaturesExpanded", information:"informationExpanded", media:"mediaExpanded", commands:"commandsExpanded", connections:"networkControlsExpanded", addresses:"addressesExpanded", syncthing:"syncthingExpanded"})
    function sectionExpanded(id) {
        var fields = sectionExpansionFields
        return fields[id] ? root[fields[id]] : false
    }
    function setSectionExpanded(id, value) {
        var fields = sectionExpansionFields
        if (fields[id] && typeof value === "boolean") root[fields[id]] = value
    }
    function toggleSection(id) { setSectionExpanded(id, !sectionExpanded(id)) }
    function restoreSectionExpansion() {
        if (!sectionCatalogModel.ready) return
        sectionCatalogModel.entries.forEach(function(entry) {
            var value = root.getSetting(entry.expandedKey, entry.defaultExpanded)
            root.setSectionExpanded(entry.id, typeof value === "boolean" ? value : entry.defaultExpanded)
        })
    }
    function sectionFlag(id) {
        var entry = sectionCatalogModel.entry(id)
        // Missing metadata must not reveal optional controls or start providers.
        if (!entry) return id === "devices"
        if (!entry.visibilityKey) return true
        var value = getSetting(entry.visibilityKey, entry.defaultVisible)
        return typeof value === "boolean" ? value : entry.defaultVisible
    }
    function sectionVisible(id) {
        if (!sectionFlag(id) && !(id === "drop" && dropActionRevealed) && !(id === "actions" && activeComposer !== "none") && !(id === "media" && mediaActionRevealed) && !(id === "commands" && commandsActionRevealed)) return false
        if (id === "actions") return availableActions.length > 0 || activeComposer !== "none"
        if (id === "information") return !!device
        if (id === "media") return mediaPlayerVisible
        if (id === "commands") return remoteCommandsVisible
        if (id === "connections") return networkControlsVisible
        return true
    }
    function sectionBodyVisible(id) { return sectionVisible(id) && (sectionExpanded(id) || (id === "actions" && activeComposer !== "none")) }
    function sectionTitle(id) { var entry = sectionCatalogModel.entry(id); return entry ? entry.label : id }
    function sectionHelp(id) { var entry = sectionCatalogModel.entry(id); return entry ? entry.description : "" }
    function reorderSections() {
        if (!sectionCatalogModel.ready) return
        var wanted = sectionCatalogModel.order
        for (var i = 0; i < wanted.length; i++) {
            for (var from = i; from < sectionItems.count; from++) {
                if (sectionItems.get(from).sectionId === wanted[i]) {
                    if (from !== i) sectionItems.move(from, i, 1)
                    break
                }
            }
        }
        if (dropActionRevealed && opened) Qt.callLater(function() { root.scrollSectionIntoView("drop") })
        else Qt.callLater(root.revealDailyFocus)
    }
    function revealDailyFocus() {
        if (!root.opened) return
        var window = scrollView.Window.window
        var item = window ? window.activeFocusItem : null
        var viewport = scrollView.contentItem
        if (!item || !viewport) return
        var ancestor = item
        while (ancestor && ancestor !== viewport) ancestor = ancestor.parent
        if (!ancestor) return
        var position = item.mapToItem(scrollView, 0, 0)
        var offset = position.y < 0 ? position.y
            : Math.max(0, position.y + item.height - scrollView.availableHeight)
        if (offset !== 0) viewport.contentY = Math.max(0, Math.min(viewport.contentY + offset,
            Math.max(0, scrollView.contentHeight - scrollView.availableHeight)))
    }
    Connections {
        target: scrollView.Window.window
        function onActiveFocusItemChanged() { Qt.callLater(root.revealDailyFocus) }
    }
    function scrollSectionIntoView(id) {
        // Reveal and ObjectModel moves can arrive before the positioners' next
        // polish. Settle their geometry before using the viewport's limits.
        for (var layoutIndex = 0; layoutIndex < sectionItems.count; layoutIndex++) {
            var section = sectionItems.get(layoutIndex)
            if (typeof section.forceLayout === "function") section.forceLayout()
        }
        deviceGroups.forceLayout()
        contentColumn.forceLayout()
        var viewport = scrollView.contentItem
        if (!viewport || !("contentY" in viewport)) return
        for (var i = 0; i < sectionItems.count; i++) {
            var item = sectionItems.get(i)
            if (item.sectionId !== id || !item.visible) continue
            var position = item.mapToItem(scrollView, 0, 0)
            viewport.contentY = Math.max(0, Math.min(viewport.contentY + position.y, Math.max(0, scrollView.contentHeight - scrollView.availableHeight)))
            return
        }
    }
    function openDropTarget() {
        currentView = "Devices"
        root.open()
        dropActionRevealed = true
        setSectionExpanded("drop", true)
        Qt.callLater(function() { root.scrollSectionIntoView("drop") })
    }

    property bool commandsActionRevealed: false
    property bool mediaActionRevealed: false
    readonly property bool remoteCommandsVisible: !!(device && device.paired && device.reachable && device.capabilities && device.capabilities.commands && (commandsActionRevealed || getSetting("showRemoteCommands", true)))
    readonly property bool mediaPlayerVisible: !!(device && device.paired && device.reachable && device.capabilities && device.capabilities.media && (mediaActionRevealed || getSetting("showMediaPlayer", true)))
    readonly property bool networkVisible: false

    readonly property bool savedAddressesVisible: getSetting("showSavedAddresses", true)
    readonly property bool syncthingVisible: getSetting("showSyncthingLinks", false)
    readonly property bool networkControlsVisible: getSetting("showNetworkControls", true) && (networkOptions.tailscaleEnabled || networkOptions.bthEnabled || networkOptions.wireguardEnabled)
    property bool networkControlsExpanded: getSetting("networkStartExpanded", false)
    property bool addressesExpanded: getSetting("addressesStartExpanded", false)
    property bool syncthingExpanded: getSetting("syncthingStartExpanded", false)
    property string currentView: "Devices"
    readonly property var viewNames: ["Devices", "Send", "Activity"]
    readonly property bool navigationAtTop: getSetting("navigationAtTop", false) === true
    readonly property var settingsWindow: preferencesWindow
    function openSettings(page) { preferencesWindow.openSettings(page || "Appearance"); root.close() }
    function openDeviceSettings(id) {
        if (!service || !service.devices.some(function(entry) { return entry.id === id })) return false
        selectDevice(id)
        openSettings("Device features")
        return true
    }
    function openSendWindow() { root.close(); sendWindow.openSend() }
    onOpenedChanged: {
        if (service) service.panelOpened = opened
        if (!opened) { dailyNavigation.closeMenu(); dropActionRevealed = false }
        if (opened) {
            root.restoreSectionExpansion()
            mediaActionRevealed = false
            commandsActionRevealed = false
            mediaExpanded = getSetting("mediaStartExpanded", false)
            commandsExpanded = getSetting("commandsStartExpanded", false)
            addressesExpanded = getSetting("addressesStartExpanded", false)
            syncthingExpanded = getSetting("syncthingStartExpanded", false)
            networkControlsExpanded = getSetting("networkStartExpanded", false)
        }
    }
    onCurrentViewChanged: { root.cursorActive = false; if (currentView !== "Devices") root.activeComposer = "none" }

    property string focusSection: "devices"
    property int selectedIndex: 0
    property int actionSelectedIndex: 0
    property bool cursorActive: false
    property bool mediaExpanded: getSetting("mediaStartExpanded", false)
    property int mediaControlIndex: 1
    property bool commandsExpanded: getSetting("commandsStartExpanded", false)
    property int commandSelectedIndex: 0
    property bool networkExpanded: false
    property int networkSelectedIndex: 0
    property string unpairConfirmingId: ""

    property string activeComposer: "none"
    property string draftPing: ""
    property string draftText: ""
    property string composerError: ""

    readonly property var availableActions: Actions.available(root.getSetting("quickActionsOrder", Actions.DEFAULT_ORDER), root.device)


    readonly property var visibleSections: {
        var order = sectionCatalogModel.order
        var list = []
        for (var i = 0; i < order.length; i++) {
            var id = order[i]
            if (!root.sectionVisible(id)) continue
            if (id === "devices" || id === "media" || id === "commands" || (id === "actions" && actionsExpanded)) list.push(id)
        }
        return list.length ? list : ["devices"]
    }

    onAvailableActionsChanged: {
        var acts = availableActions
        if (acts.length > 0) {
            actionSelectedIndex = Math.max(0, Math.min(acts.length - 1, actionSelectedIndex))
        } else {
            actionSelectedIndex = 0
            if (focusSection === "actions") focusSection = "devices"
        }
    }

    onVisibleSectionsChanged: {
        if (visibleSections.indexOf(focusSection) === -1) {
            focusSection = visibleSections.length > 0 ? visibleSections[0] : "devices"
        }
    }

    onMediaPlayerVisibleChanged: {
        if (!mediaPlayerVisible && focusSection === "media") {
            focusSection = availableActions.length > 0 ? "actions" : "devices"
        }
    }

    onRemoteCommandsVisibleChanged: {
        if (!remoteCommandsVisible && focusSection === "commands") {
            focusSection = availableActions.length > 0 ? "actions" : "devices"
        }
    }

    onNetworkVisibleChanged: {
        if (!networkVisible && focusSection === "network") {
            focusSection = availableActions.length > 0 ? "actions" : "devices"
        }
    }

    onDraftPingChanged: {
        if (composerSection && composerSection.pingInput && composerSection.pingInput.text !== draftPing) {
            composerSection.pingInput.text = draftPing
        }
    }

    onDraftTextChanged: {
        if (composerSection && composerSection.textInput && composerSection.textInput.text !== draftText) {
            composerSection.textInput.text = draftText
        }
    }

    Connections {
        target: root.service
        function onDevicesChanged() {
            var list = root.service ? root.service.devices : []
            if (!list.length) {
                root.selectedIndex = 0
                return
            }
            root.selectedIndex = Math.max(0, Math.min(list.length - 1, root.selectedIndex))
        }
    }

    function open() {
        if (unpairConfirmingId) cancelUnpairConfirm(unpairConfirmingId)
        unpairConfirmingId = ""
        root.controller.show()
        if (service && device && device.paired && device.reachable && device.capabilities && device.capabilities.media) {
            service.fetchMediaStatus(device.id)
            if (typeof service.requestPlayerList === "function") service.requestPlayerList(device.id)
        }
    }

    function close() {
        if (unpairConfirmingId) cancelUnpairConfirm(unpairConfirmingId)
        unpairConfirmingId = ""
        root.controller.hide()
    }

    function toggle() {
        root.opened ? close() : open()
    }

    function closeForPopoutSwitch() {
        if (unpairConfirmingId) cancelUnpairConfirm(unpairConfirmingId)
        unpairConfirmingId = ""
        root.popoutSwitchClosing = true
        root.close()
        Qt.callLater(function() { root.popoutSwitchClosing = false })
    }

    function getSetting(key, defaultValue) {
        if (key === "showTroubleshooting") return false
        if (!settings || typeof settings !== "object") return defaultValue
        if (key in settings && settings[key] !== undefined && settings[key] !== null) {
            return settings[key]
        }
        return defaultValue
    }

    function getNetworkItemCount() {
        if (!networkExpanded) return 1
        var peers = (service && service.tailscaleRunning && networkSection) ? networkSection.filteredPeers.length : 0
        var saved = (service && service.customAddresses) ? service.customAddresses.length : 0
        return 1 + peers + saved
    }

    function navigateNextSection() {
        var idx = visibleSections.indexOf(focusSection)
        if (idx === -1) idx = 0
        var nextIdx = (idx + 1) % visibleSections.length
        root.focusSection = visibleSections[nextIdx]
        if (root.focusSection === "actions") actionSelectedIndex = 0
        else if (root.focusSection === "media") mediaControlIndex = mediaExpanded ? 0 : 1
        else if (root.focusSection === "commands") commandSelectedIndex = 0
        else if (root.focusSection === "network") networkSelectedIndex = 0
    }

    function navigatePrevSection() {
        var idx = visibleSections.indexOf(focusSection)
        if (idx === -1) idx = 0
        var prevIdx = (idx - 1 + visibleSections.length) % visibleSections.length
        root.focusSection = visibleSections[prevIdx]
        if (root.focusSection === "actions") actionSelectedIndex = Math.max(0, availableActions.length - 1)
        else if (root.focusSection === "media") mediaControlIndex = mediaExpanded ? 2 : 1
        else if (root.focusSection === "commands") {
            var cmds = (service && service.remoteCommands) ? service.remoteCommands : []
            commandSelectedIndex = commandsExpanded ? Math.max(0, cmds.length - 1) : 0
        } else if (root.focusSection === "network") {
            networkSelectedIndex = networkExpanded ? Math.max(0, getNetworkItemCount() - 1) : 0
        }
    }

    // NOTE: PanelKeyCatcher consumes h/j/k/l and the arrow keys into
    // moveRequested(dx, dy) -- they never reach onTextKey. All directional
    // navigation must live in these move functions, called from
    // onMoveRequested below. onTextKey keeps delegating here only so
    // Shift+letter (e.g. "J", which arrives as text) behaves the same.
    function moveDown() {
        if (focusSection === "devices") {
            var devList = (service && service.devices) ? service.devices : []
            if (devList.length > 0 && selectedIndex < devList.length - 1) select(1)
            else navigateNextSection()
        } else if (focusSection === "commands" && commandsExpanded) {
            var cmdList = (service && service.remoteCommands) ? service.remoteCommands : []
            if (cmdList.length > 0 && commandSelectedIndex < cmdList.length - 1) selectCommand(1)
            else navigateNextSection()
        } else if (focusSection === "network" && networkExpanded) {
            if (networkSelectedIndex < getNetworkItemCount() - 1) networkSelectedIndex++
            else navigateNextSection()
        } else {
            navigateNextSection()
        }
    }

    function moveUp() {
        if (focusSection === "devices") {
            if (selectedIndex > 0) select(-1)
            else navigatePrevSection()
        } else if (focusSection === "commands" && commandsExpanded) {
            if (commandSelectedIndex > 0) selectCommand(-1)
            else navigatePrevSection()
        } else if (focusSection === "network" && networkExpanded) {
            if (networkSelectedIndex > 0) networkSelectedIndex--
            else navigatePrevSection()
        } else {
            navigatePrevSection()
        }
    }

    function moveRight() {
        if (focusSection === "actions") {
            if (actionSelectedIndex < availableActions.length - 1) actionSelectedIndex++
            else navigateNextSection()
        } else if (focusSection === "media") {
            if (mediaExpanded && mediaControlIndex < 2) mediaControlIndex++
            else navigateNextSection()
        } else {
            navigateNextSection()
        }
    }

    function moveLeft() {
        if (focusSection === "actions") {
            if (actionSelectedIndex > 0) actionSelectedIndex--
            else navigatePrevSection()
        } else if (focusSection === "media") {
            if (mediaExpanded && mediaControlIndex > 0) mediaControlIndex--
            else navigatePrevSection()
        } else {
            navigatePrevSection()
        }
    }

    function triggerAction(actionId) {
        if (!(actionId === "file" && service && service.fileBusy) && !Actions.ready(actionId, device, service)) return
        if (actionId === "plus-settings") { openSettings(); return }
        if (actionId === "quick-share") { service.openQuickShare(); return }
        var entry = Actions.entry(actionId)
        if (entry && entry.handoff && actionId !== "sms") {
            if (service) service.openKdeConnectApp()
            return
        }
        if (!service || !device) return
        if (actionId === "external-monitor") { service.toggleVirtualMonitor(device.id); return }
        if (actionId === "ring") service.ringDevice(device.id)
        else if (actionId === "clipboard") service.sendClipboard(device.id)
        else if (actionId === "file") {
            if (service.fileBusy) service.cancelFileTransfer()
            else { root.currentView = "Send"; service.startFileSelection(device.id) }
        }
        else if (actionId === "sms") service.openSmsApp(device.id)
        else if (actionId === "ping") {
            if (activeComposer === "ping") closeComposer()
            else openComposer("ping")
        }
        else if (actionId === "text") {
            if (activeComposer === "text") closeComposer()
            else openComposer("text")
        }
        else if (actionId === "media") {
            currentView = "Devices"
            mediaActionRevealed = true
            mediaExpanded = true
            service.fetchMediaStatus(device.id)
            service.requestPlayerList(device.id)
        }
        else if (actionId === "media-previous") service.mediaPrevious(device.id)
        else if (actionId === "media-play-pause") service.mediaPlayPause(device.id)
        else if (actionId === "media-next") service.mediaNext(device.id)
        else if (actionId === "commands") {
            currentView = "Devices"
            commandsActionRevealed = true
            commandsExpanded = true
            service.fetchRemoteCommands(device.id)
        }
    }

    function requestUnpairConfirm(id) {
        if (unpairConfirmingId && unpairConfirmingId !== id) cancelUnpairConfirm(unpairConfirmingId)
        unpairConfirmingId = id
        if (service && typeof service.setPendingPairing === "function") service.setPendingPairing(id, "unpair_confirm")
    }

    function cancelUnpairConfirm(id) {
        if (!id || unpairConfirmingId === id) unpairConfirmingId = ""
        if (service && id && typeof service.setPendingPairing === "function") service.setPendingPairing(id, "")
    }

    function confirmUnpair(id) {
        if (unpairConfirmingId && unpairConfirmingId !== id) return
        unpairConfirmingId = ""
        if (service) service.unpairDevice(id)
    }

    function selectDevice(id) {
        if (!service) return
        if (unpairConfirmingId && unpairConfirmingId !== id) cancelUnpairConfirm(unpairConfirmingId)
        unpairConfirmingId = ""
        resetComposer()
        mediaActionRevealed = false
        commandsActionRevealed = false
        commandSelectedIndex = 0
        commandsExpanded = getSetting("commandsStartExpanded", false)
        mediaControlIndex = 1
        if (focusSection === "ping" || focusSection === "text") focusSection = availableActions.length > 0 ? "actions" : "devices"
        service.selectDevice(id)
        var list = service.devices || []
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === String(id)) {
                selectedIndex = i
                break
            }
        }
        var acts = availableActions
        if (acts.length > 0) {
            actionSelectedIndex = Math.max(0, Math.min(acts.length - 1, actionSelectedIndex))
        } else {
            actionSelectedIndex = 0
            if (focusSection === "actions") focusSection = "devices"
        }
    }

    function select(delta) {
        var list = service ? service.devices : []
        if (!list.length) return
        selectedIndex = Math.max(0, Math.min(list.length - 1, selectedIndex + delta))
        if (cursorActive) selectDevice(list[selectedIndex].id)
    }

    function openComposer(type) {
        if (type !== "ping" && type !== "text") return
        if (!service || !device || !device.paired || !device.reachable) {
            composerError = "Device must be paired and reachable"
            if (service) {
                service.actionState = "blocked"
                service.actionError = "Device must be paired and reachable"
                service.actionMessage = ""
            }
            return
        }
        var caps = device.capabilities || {}
        if (type === "ping" && !caps.ping) {
            composerError = "Ping not supported by device"
            if (service) {
                service.actionState = "blocked"
                service.actionError = "Ping not supported by device"
                service.actionMessage = ""
            }
            return
        }
        if (type === "text" && !caps.text) {
            composerError = "Text share not supported by device"
            if (service) {
                service.actionState = "blocked"
                service.actionError = "Text share not supported by device"
                service.actionMessage = ""
            }
            return
        }
        composerError = ""
        activeComposer = type
        if (type === "ping") {
            if (!draftPing) {
                var defPing = root.getSetting("defaultPingMessage", "")
                if (defPing) draftPing = defPing
            }
            focusSection = "ping"
            Qt.callLater(function() { if (composerSection && composerSection.pingInput) composerSection.pingInput.forceActiveFocus() })
        } else if (type === "text") {
            focusSection = "text"
            Qt.callLater(function() { if (composerSection && composerSection.textInput) composerSection.textInput.forceActiveFocus() })
        }
    }

    function closeComposer(restorePanelFocus) {
        activeComposer = "none"
        composerError = ""
        focusSection = availableActions.length > 0 ? "actions" : "devices"
        if (restorePanelFocus !== false && keyCatcher) keyCatcher.forceActiveFocus()
    }

    function resetComposer() {
        activeComposer = "none"
        draftPing = ""
        draftText = ""
        composerError = ""
    }

    function submitPing() {
        var val = draftPing.trim()
        if (!val) {
            composerError = "Message cannot be empty"
            if (service) {
                service.actionState = "blocked"
                service.actionError = "Message cannot be empty"
                service.actionMessage = ""
            }
            return false
        }
        if (service && device) {
            var success = service.pingDevice(device.id, val)
            if (success) {
                draftPing = ""
                closeComposer()
            } else {
                composerError = (service && service.actionError) ? service.actionError : "Failed to send ping"
            }
            return success
        }
        composerError = "Service unavailable"
        return false
    }

    function submitText() {
        var val = draftText.trim()
        if (!val) {
            composerError = "Message cannot be empty"
            if (service) {
                service.actionState = "blocked"
                service.actionError = "Message cannot be empty"
                service.actionMessage = ""
            }
            return false
        }
        if (service && device) {
            var success = service.shareText(device.id, val)
            if (success) {
                draftText = ""
                closeComposer()
            } else {
                composerError = (service && service.actionError) ? service.actionError : "Failed to share text"
            }
            return success
        }
        composerError = "Service unavailable"
        return false
    }

    function toggleMediaExpanded() {
        mediaExpanded = !mediaExpanded
        mediaControlIndex = 1
        if (mediaExpanded && service && device && device.capabilities && device.capabilities.media) {
            service.fetchMediaStatus(device.id)
            if (typeof service.requestPlayerList === "function") service.requestPlayerList(device.id)
        }
    }

    function toggleCommandsExpanded() {
        commandsExpanded = !commandsExpanded
        if (commandsExpanded && service && device && device.capabilities && device.capabilities.commands) {
            service.fetchRemoteCommands(device.id)
        }
    }

    function selectCommand(delta) {
        var list = (service && service.remoteCommands) ? service.remoteCommands : []
        if (!list.length) return
        commandSelectedIndex = Math.max(0, Math.min(list.length - 1, commandSelectedIndex + delta))
    }

    function toggleNetworkExpanded() {
        networkExpanded = !networkExpanded
        networkSelectedIndex = 0
        if (networkExpanded && service) {
            service.refreshTailscale()
        }
    }

    function activate() {
        if (focusSection === "devices") {
            var list = service ? service.devices : []
            var dev = list[selectedIndex]
            if (dev && service) {
                selectDevice(dev.id)
                var pending = (service.pendingPairing && service.pendingPairing[dev.id]) ? service.pendingPairing[dev.id] : ""
                if (root.unpairConfirmingId === dev.id || pending === "unpair_confirm") {
                    root.confirmUnpair(dev.id)
                } else if (!dev.paired) {
                    if (pending === "requesting") {
                        service.setPendingPairing(dev.id, "")
                        if (typeof service.clearActionState === "function") service.clearActionState()
                    } else {
                        service.pairDevice(dev.id)
                    }
                } else {
                    if (pending !== "removing") root.requestUnpairConfirm(dev.id)
                }
            }
        } else if (focusSection === "refresh") {
            if (service) service.refresh(true)
        } else if (focusSection === "actions") {
            var acts = availableActions
            if (acts.length > 0) {
                var actIdx = Math.max(0, Math.min(acts.length - 1, actionSelectedIndex))
                triggerAction(acts[actIdx])
            }
        } else if (focusSection === "ring" && service && device) {
            service.ringDevice(device.id)
        } else if (focusSection === "clipboard" && service && device) {
            service.sendClipboard(device.id)
        } else if (focusSection === "file" && service && device) {
            root.currentView = "Send"
            service.startFileSelection(device.id)
        } else if (focusSection === "ping") {
            if (activeComposer === "ping") submitPing()
            else openComposer("ping")
        } else if (focusSection === "text") {
            if (activeComposer === "text") submitText()
            else openComposer("text")
        } else if (focusSection === "media" && service && device) {
            if (!device.paired || !device.reachable || !device.capabilities || !device.capabilities.media) return
            if (!mediaExpanded) toggleMediaExpanded()
            else if (!mediaPlayerSection.hasMedia) return
            else if (mediaControlIndex === 0) service.mediaPrevious(device.id)
            else if (mediaControlIndex === 2) service.mediaNext(device.id)
            else service.mediaPlayPause(device.id)
        } else if (focusSection === "commands" && service && device) {
            if (!commandsExpanded) {
                toggleCommandsExpanded()
            } else if (service.remoteCommands.length > 0) {
                var idx = Math.max(0, Math.min(service.remoteCommands.length - 1, commandSelectedIndex))
                var cmd = service.remoteCommands[idx]
                if (cmd) service.executeRemoteCommand(device.id, cmd.key)
            } else {
                service.fetchRemoteCommands(device.id)
            }
        } else if (focusSection === "network" && service) {
            if (!networkExpanded || networkSelectedIndex === 0) {
                toggleNetworkExpanded()
            } else {
                var peers = (service.tailscaleRunning && networkSection) ? networkSection.filteredPeers : []
                if (networkSelectedIndex <= peers.length) {
                    var peer = peers[networkSelectedIndex - 1]
                    if (peer && service) service.addCustomAddress(peer.address)
                } else {
                    var savedIdx = networkSelectedIndex - 1 - peers.length
                    var saved = service.customAddresses ? service.customAddresses : []
                    if (savedIdx < saved.length && service) service.removeCustomAddress(saved[savedIdx])
                }
            }
        }
    }

    KeyboardPanel {
        id: panel
        anchorItem: root.anchorItem
        owner: root.barIdentity
        bar: root.bar
        open: root.opened
        focusTarget: root.currentView === "Devices" ? keyCatcher : dailyNavigation.focusItem
        contentWidth: panel.fittedContentWidth(Style.space(380))
        contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight + dailyNavigation.implicitHeight + Style.space(8))

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent

            blocked: !keyCatcher.activeFocus || dailyNavigation.menuOpen || root.currentView !== "Devices" || root.activeComposer !== "none" || !!(composerSection && ((composerSection.pingInput && composerSection.pingInput.activeFocus) || (composerSection.textInput && composerSection.textInput.activeFocus))) || !!(networkSection && networkSection.addressInput && networkSection.addressInput.activeFocus)
            onMoveRequested: function(dx, dy) {
                if (root.activeComposer !== "none") return
                if (!root.cursorActive) {
                    root.cursorActive = true
                    return
                }
                if (dy > 0) root.moveDown()
                else if (dy < 0) root.moveUp()
                else if (dx > 0) root.moveRight()
                else if (dx < 0) root.moveLeft()
            }
            onActivateRequested: root.activate()
            onCloseRequested: {
                if (root.unpairConfirmingId) root.cancelUnpairConfirm(root.unpairConfirmingId)
                else if (root.activeComposer !== "none") root.closeComposer()
                else root.close()
            }
            onTabRequested: function(direction) {
                // Enter the form's normal Tab chain; all daily controls must be reachable.
                var entry = dailyNavigation.focusItem
                entry.forceActiveFocus(direction < 0 ? Qt.BacktabFocusReason : Qt.TabFocusReason)
            }
            onTextKey: function(value) {
                if (root.activeComposer !== "none") return
                if (!root.cursorActive) root.cursorActive = true
                var key = String(value).toLowerCase()
                if (key === "r" && root.service) {
                    root.service.refresh(true)
                } else if (key === "j" || key === "down") {
                    root.moveDown()
                } else if (key === "k" || key === "up") {
                    root.moveUp()
                } else if (key === "l" || key === "right") {
                    root.moveRight()
                } else if (key === "h" || key === "left") {
                    root.moveLeft()
                } else if (key === "p" && root.focusSection === "devices") {
                    var listP = root.service ? root.service.devices : []
                    var devP = listP[root.selectedIndex]
                    if (devP && !devP.paired && root.service) {
                        var pendP = (root.service.pendingPairing && root.service.pendingPairing[devP.id]) ? root.service.pendingPairing[devP.id] : ""
                        if (pendP !== "requesting") root.service.pairDevice(devP.id)
                    }
                } else if (key === "u" && root.focusSection === "devices") {
                    var listU = root.service ? root.service.devices : []
                    var devU = listU[root.selectedIndex]
                    if (devU && devU.paired && root.service) {
                        var pendU = (root.service.pendingPairing && root.service.pendingPairing[devU.id]) ? root.service.pendingPairing[devU.id] : ""
                        if (pendU !== "removing") root.requestUnpairConfirm(devU.id)
                    }
                } else if (key === "y" && root.unpairConfirmingId) {
                    var listY = root.service ? root.service.devices : []
                    var devY = listY[root.selectedIndex]
                    if (devY && devY.id === root.unpairConfirmingId) root.confirmUnpair(root.unpairConfirmingId)
                } else if (key === "c" || key === "escape") {
                    var targetIdC = root.unpairConfirmingId || (root.service ? root.service.selectedDeviceId : "")
                    if (root.unpairConfirmingId || (root.service && targetIdC && root.service.pendingPairing && root.service.pendingPairing[targetIdC] === "unpair_confirm")) {
                        root.cancelUnpairConfirm(targetIdC)
                    } else if (root.service && targetIdC && root.service.pendingPairing && root.service.pendingPairing[targetIdC] === "requesting") {
                        root.service.setPendingPairing(targetIdC, "")
                        if (typeof root.service.clearActionState === "function") root.service.clearActionState()
                    }
                }
            }
        }

        CompactNavigation {
            id: dailyNavigation
            width: parent.width
            y: root.navigationAtTop ? 0 : parent.height - height
            menuHeightLimit: Math.max(44, parent.height - height - Style.space(4))
            panel: root
        }

        ScrollView {
            id: scrollView
            objectName: "daily-content-scroll"
            anchors.fill: parent
            anchors.topMargin: root.navigationAtTop ? dailyNavigation.implicitHeight + Style.space(8) : 0
            anchors.bottomMargin: root.navigationAtTop ? 0 : dailyNavigation.implicitHeight + Style.space(8)
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AlwaysOff

            Column {
                id: contentColumn
                objectName: "omaconnect-content"
                width: scrollView.width
                spacing: Style.space(12)
                bottomPadding: Style.space(8)

                Column {
                    width: parent.width
                    visible: root.currentView === "Send"
                    spacing: Style.space(8)
                    Text {
                        width: parent.width
                        text: root.service && root.service.draftTarget ? "Reviewed recipient: " + root.service.draftTarget.peerName + "\nKDE ID: " + root.service.draftTarget.peerId
                            : root.device ? "Selected: " + root.deviceName + "\nKDE ID: " + root.device.id : "Choose a device in Devices first."
                        textFormat: Text.PlainText
                        wrapMode: Text.WrapAnywhere
                        color: Commons.Color.popups.text
                    }
                    Button {
                        focusable: true
                        width: parent.width
                        text: "Choose files"
                        Accessible.name: text
                        enabled: !!root.device && root.device.paired && root.device.reachable && root.device.capabilities && root.device.capabilities.file && root.service && !root.service.operationBusy && root.service.selectionState !== "choosing" && root.service.selectionState !== "draft"
                        onClicked: root.service.chooseFiles(root.device.id)
                    }
                    Button {
                        focusable: true
                        width: parent.width
                        text: "Open Send window"
                        Accessible.name: text
                        onClicked: root.openSendWindow()
                    }
                    FileDropZone { width: parent.width; service: root.service; device: root.device }
                    SendSection { width: parent.width; service: root.service; foreground: Commons.Color.popups.text; fontFamily: Style.font.family }
                }
                ActivitySection { width: parent.width; visible: root.currentView === "Activity"; service: root.service }
                Text {
                    objectName: "daily-section-error"
                    width: parent.width
                    visible: root.currentView === "Devices" && root.sectionCatalog.error !== ""
                    text: root.sectionCatalog.error
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: Commons.Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }
                Column {
                    id: deviceGroups
                    objectName: "device-sections"
                    width: parent.width
                    spacing: Style.space(8)
                    visible: root.currentView === "Devices"
                    Repeater { model: sectionItems }
                    Models.ObjectModel {
                        id: sectionItems
                        DeviceSection {
                            id: deviceSection
                            property string sectionId: "devices"
                            visible: root.sectionVisible(sectionId)
                            panel: root
                            detailsExpanded: root.deviceDetailsExpanded
                            onDetailsToggleRequested: root.toggleSection("devices")
                        }
                        DailySection {
                            sectionId: "actions"
                            title: root.sectionTitle(sectionId)
                            description: root.sectionHelp(sectionId)
                            visible: root.sectionVisible(sectionId)
                            expanded: root.actionsExpanded || root.activeComposer !== "none"
                            onToggleRequested: {
                                var wasExpanded = expanded
                                if (root.activeComposer !== "none") root.closeComposer(false)
                                root.setSectionExpanded(sectionId, !wasExpanded)
                            }
                            ActionToolbar { id: actionToolbar; panel: root; showSectionHeader: false }
                            ComposerSection { id: composerSection; panel: root }
                        }
                        DailySection {
                            sectionId: "drop"
                            title: root.sectionTitle(sectionId)
                            description: root.sectionHelp(sectionId)
                            visible: root.sectionVisible(sectionId)
                            expanded: root.inlineSendExpanded
                            onToggleRequested: root.toggleSection(sectionId)
                            InlineSendSection {
                                id: inlineSendSection
                                panel: root
                                onFilesStaged: {
                                    root.dropActionRevealed = true
                                    root.setSectionExpanded("drop", true)
                                    Qt.callLater(function() { root.scrollSectionIntoView("drop") })
                                }
                            }
                        }
                        DailySection {
                            sectionId: "native"
                            title: root.sectionTitle(sectionId)
                            description: root.sectionHelp(sectionId)
                            visible: root.sectionVisible(sectionId)
                            expanded: root.nativeFeaturesExpanded
                            onToggleRequested: root.toggleSection(sectionId)
                            SettingsButton {
                                width: Math.min(implicitWidth, parent.width)
                                height: Math.max(44, implicitHeight)
                                text: "Device features in Plus"
                                Accessible.name: text
                                tooltipText: "Open local native module controls and their configuration links in Plus settings."
                                foreground: Commons.Color.popups.text
                                focusable: true
                                onClicked: root.openSettings("Device features")
                            }
                            NativeFeaturesSection { width: parent.width; service: root.service }
                        }
                        DailySection {
                            sectionId: "information"
                            title: root.sectionTitle(sectionId)
                            description: root.sectionHelp(sectionId)
                            visible: root.sectionVisible(sectionId)
                            expanded: root.informationExpanded
                            onToggleRequested: root.toggleSection(sectionId)
                            DeviceInformationSection {
                                width: parent.width
                                service: root.service
                                showTitle: false
                                showBattery: root.getSetting("showBatteryStats", true)
                                showCellular: root.getSetting("showNetworkStats", true)
                            }
                        }
                        MediaPlayerSection {
                            id: mediaPlayerSection
                            property string sectionId: "media"
                            visible: root.sectionVisible(sectionId)
                            panel: root
                        }
                        RemoteCommandsSection {
                            id: remoteCommandsSection
                            property string sectionId: "commands"
                            visible: root.sectionVisible(sectionId)
                            panel: root
                        }
                        DailySection {
                            sectionId: "connections"
                            title: root.sectionTitle(sectionId)
                            description: root.sectionHelp(sectionId)
                            visible: root.sectionVisible(sectionId)
                            expanded: root.networkControlsExpanded
                            onToggleRequested: root.toggleSection(sectionId)
                            NetworkOptions { id: networkOptions; width: parent.width; panel: root }
                            BthControlCard {
                                width: parent.width
                                visible: networkOptions.bthEnabled
                                panelOpened: root.opened && root.currentView === "Devices" && root.sectionBodyVisible("connections") && networkOptions.bthEnabled
                                helperPath: root.getSetting("bthHelperPath", "") || (Quickshell.env("HOME") + "/.local/bin/remote-access-mode")
                                property string lastRouteStatus: ""
                                onStatusChanged: {
                                    var current = JSON.stringify(status)
                                    if (current !== lastRouteStatus && root.service) root.service.discovery.routeChanged()
                                    lastRouteStatus = current
                                }
                            }
                        }
                        DailySection {
                            sectionId: "addresses"
                            title: root.sectionTitle(sectionId)
                            description: root.sectionHelp(sectionId)
                            visible: root.sectionVisible(sectionId)
                            expanded: root.addressesExpanded
                            onToggleRequested: root.toggleSection(sectionId)
                            SavedAddressesSection {
                                width: parent.width
                                showTitle: false
                                discovery: root.service ? root.service.discovery : null
                                peerId: root.device ? root.device.id : ""
                            }
                        }
                        DailySection {
                            sectionId: "syncthing"
                            title: root.sectionTitle(sectionId)
                            description: root.sectionHelp(sectionId)
                            visible: root.sectionVisible(sectionId)
                            expanded: root.syncthingExpanded
                            onToggleRequested: root.toggleSection(sectionId)
                            SyncthingLinkSection {
                                panelOpened: root.opened && root.currentView === "Devices" && root.sectionBodyVisible("syncthing")
                                width: parent.width
                                service: root.service
                            }
                        }
                    }
                    Repeater {
                        model: root.service ? [
                            {id:"quick-share", message:root.service.quickShareMessage || "", shown:!(root.sectionBodyVisible("actions") && root.availableActions.length > 0)},
                            {id:"native", message:root.service.nativeAppMessage || "", shown:!root.sectionBodyVisible("native") && !(root.sectionBodyVisible("actions") && root.availableActions.length > 0 && !root.getSetting("showNativeFeatures", true))}
                        ] : []
                        delegate: Text {
                            required property var modelData
                            objectName: "collapsed-launch-status-" + modelData.id
                            width: deviceGroups.width
                            visible: modelData.shown && modelData.message !== ""
                            text: modelData.message
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            color: Commons.Color.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                            Accessible.role: Accessible.StaticText
                            Accessible.name: text
                        }
                    }
                }
                NetworkSection { id: networkSection; visible: false; panel: root }
            }
        }
    }
    SettingsPanel {
        id: preferencesWindow
        panel: root
        onReturnToPanelRequested: { root.currentView = "Devices"; root.open() }
    }
    SendWindow {
        id: sendWindow
        service: root.service
        device: root.device
        onReturnToPanelRequested: { root.currentView = "Devices"; root.open() }
    }

}
