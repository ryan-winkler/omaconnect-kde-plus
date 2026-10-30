pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "components"
import "bridge" as OmaconnectBridge

BarWidget {
    id: root
    moduleName: "Omaconnect.plus"

    // Primary path: the bar host's scoped facade (service-capable under the
    // first-party bar). Fallback: the engine-wide bridge singleton -- under
    // replacement bars the facade's serviceFor() is a deliberate null stub,
    // so widgets they host would otherwise never see the service. The
    // binding re-evaluates on its own when the service publishes (or is
    // torn down). See bridge/Bridge.qml.
    readonly property var service: {
        var viaHost = bar && bar.shell && typeof bar.shell.serviceFor === "function"
            ? bar.shell.serviceFor("Omaconnect.plus") : null
        return viaHost || OmaconnectBridge.Bridge.service
    }
    readonly property var device: service ? service.selectedDevice : null
    readonly property string deviceName: service ? service.displayName(device) : "KDE Connect"
    readonly property bool hasBattery: !!(device && device.reachable && device.capabilities && device.capabilities.battery && device.battery >= 0)
    readonly property bool showBarBattery: !!(root.settings && root.settings.showBarBattery && root.hasBattery)
    readonly property Item button: buttonItem
    readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
    readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

    implicitWidth: buttonItem.implicitWidth
    implicitHeight: barSize

    onBarChanged: injectPanel()
    onSettingsChanged: injectPanel()

    function injectPanel() {
        var target = panelLoader.item
        if (!target) return
        if ("hostWidget" in target) target.hostWidget = root
        if ("anchorItem" in target) target.anchorItem = buttonItem
        if ("bar" in target) target.bar = root.bar
        if ("settings" in target) target.settings = root.settings
    }

    function toggle() {
        if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
    }

    function togglePanel() {
        toggle()
    }

    function open() {
        if (panelLoader.item && panelLoader.item.open) panelLoader.item.open()
    }

    function openSettings() {
        if (panelLoader.item && panelLoader.item.openSettings) panelLoader.item.openSettings()
    }
    function openSendWindow() {
        if (panelLoader.item && panelLoader.item.openSendWindow) panelLoader.item.openSendWindow()
    }

    function close() {
        if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
    }

    function closeForPopoutSwitch() {
        if (panelLoader.item && panelLoader.item.closeForPopoutSwitch) panelLoader.item.closeForPopoutSwitch()
    }

    BarIconButton {
        id: buttonItem
        anchors.fill: parent
        bar: root.bar
        slotSize: Style.bar.iconSlot * (root.showBarBattery && (!root.bar || !root.bar.vertical) ? 2 : 1)
        text: ""
        labelText: root.showBarBattery && root.device ? (root.device.battery + "%") : ""
        iconComponent: Component {
            AppearanceIcon {
                icon: root.service ? root.service.appearance.barIcon(root.device ? root.device.id : "", root.device ? root.device.type : "phone") : ({mode:"preset", value:"phone", render:"glyph"})
                assetBaseUrl: root.service ? root.service.appearance.assetBaseUrl : ""
                foreground: buttonItem.foreground
                fontFamily: buttonItem.fontFamily
            }
        }
        tooltipText: {
            if (iconDrop.containsDrag) return iconDrop.ready ? "Release to review files for " + root.deviceName + ". Nothing sends until you select Send." : iconDrop.instructions
            var name = "Omaconnect KDE Plus · " + root.deviceName
            if (root.device && root.device.name && root.device.name !== name) name += " (" + root.device.name + ")"
            var showBat = !root.settings || root.settings.showBatteryStats !== false
            if (showBat && root.hasBattery && root.device) {
                return name + " (" + root.device.battery + "%)"
            }
            return name
        }

        onPressed: function(b) {
            root.togglePanel()
        }
        Rectangle {
            anchors.fill: parent
            visible: iconDrop.containsDrag
            color: Style.hoverFillFor(buttonItem.foreground, Commons.Color.accent)
            radius: Style.cornerRadius
        }
        FileDropArea {
            id: iconDrop
            objectName: "bar-file-drop-area"
            anchors.fill: parent
            service: root.service
            device: root.device
            onDragReadyEntered: {
                var target = panelLoader.item
                if (target && typeof target.openDropTarget === "function") target.openDropTarget()
                else root.open()
            }
            onFilesStaged: root.openSendWindow()
        }
    }

    IpcHandler {
        target: "Omaconnect.plus"

        function open(): void { root.open() }
        function close(): void { root.close() }
        function show(): void { root.open() }
        function hide(): void { root.close() }
        function toggle(): void { root.togglePanel() }
        function refresh(): void { if (root.service) root.service.refresh(true) }
        function configure(): void { root.openSettings() }
        function sendWindow(): void { root.openSendWindow() }
    }

    Loader {
        id: panelLoader
        active: true
        source: Qt.resolvedUrl("Panel.qml")
        visible: false
        onLoaded: {
            root.injectPanel()
            Qt.callLater(root.injectPanel)
        }
    }
}
