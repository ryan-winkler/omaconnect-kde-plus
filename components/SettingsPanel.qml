pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit

Window {
    id: root
    required property var panel
    readonly property var service: panel ? panel.service : null
    readonly property var device: panel ? panel.device : null
    readonly property var devices: service ? service.devices : []
    readonly property var deviceOptions: devices.map(function(entry) {
        var name = root.deviceName(entry)
        var duplicate = root.devices.some(function(other) { return other.id !== entry.id && root.deviceName(other) === name })
        return {value: entry.id, label: name + (duplicate ? " [" + entry.id + "]" : "") + " · " + root.deviceState(entry)}
    })
    readonly property int deviceIndex: {
        for (var i = 0; i < devices.length; i++) if (device && devices[i].id === device.id) return i
        return -1
    }
    readonly property string deviceStatus: {
        if (!service) return "KDE Connect is unavailable. Open KDE Connect to check its setup."
        if (devices.length === 0) {
            if (service.scanning || service.discoveryState === "starting") return "Checking KDE Connect for devices…"
            if (!service.daemonAvailable) return service.discoveryMessage || "KDE Connect is unavailable. Open it to check its setup."
            return "No devices found. Open KDE Connect to pair a device."
        }
        if (!device) return "Choose a device above."
        return root.deviceState(device) + ". Switching also changes the device in Devices."
    }
    readonly property string selectedName: device ? (service && typeof service.displayName === "function" ? service.displayName(device) : device.name) : "No device selected"
    readonly property string selectedId: device ? device.id : ""
    onSelectedIdChanged: if (iconChooser) iconChooser.close()
    onDeviceOptionsChanged: if (deviceSelector) deviceSelector.popup.close()
    readonly property var pages: ["Appearance", "Connections", "Quick actions", "Device features"]
    readonly property color surfaceColor: Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1)
    property string currentPage: "Appearance"
    signal returnToPanelRequested()
    signal closed()

    title: "Omaconnect KDE Plus Settings"
    objectName: "omaconnect-settings-window"
    width: 720
    height: 640
    minimumWidth: 520
    minimumHeight: 440
    visible: false
    transientParent: null
    flags: Qt.Window
    modality: Qt.NonModal
    color: root.surfaceColor

    function deviceName(entry) {
        return service && typeof service.displayName === "function" ? service.displayName(entry) : entry.name
    }
    function deviceState(entry) {
        return !entry.paired ? "Not paired" : entry.reachable ? "Connected" : "Offline"
    }
    function selectSettingsDevice(id) {
        // Resolve the stable ID again: discovery may replace or reorder the list.
        if (!panel || !devices.some(function(entry) { return entry.id === id }) || (device && device.id === id)) return
        iconChooser.close()
        panel.selectDevice(id)
    }

    function openSettings(page) {
        deviceSelector.popup.close()
        currentPage = pages.indexOf(page) >= 0 ? page : "Appearance"
        visible = true
        raise()
        requestActivate()
        Qt.callLater(function() {
            var item = navigation.itemAt(root.pages.indexOf(root.currentPage))
            if (item) item.forceActiveFocus()
        })
    }
    function closeSettings() {
        deviceSelector.popup.close()
        iconChooser.close()
        visible = false
    }
    onVisibleChanged: if (!visible) root.closed()
    onCurrentPageChanged: {
        if (pageScroll.contentItem && "contentY" in pageScroll.contentItem) pageScroll.contentItem.contentY = 0
    }
    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: root.visible && !iconChooser.opened && !deviceSelector.popup.visible
        onActivated: root.closeSettings()
    }

    Rectangle {
        // A filled native surface also keeps content captures honest.
        anchors.fill: parent
        color: root.surfaceColor
    }
    Column {
        id: frame
        anchors.fill: parent
        anchors.margins: Style.spacing.panelPadding
        spacing: Style.space(12)
        Row {
            width: parent.width
            spacing: Style.space(12)
            Text {
                width: parent.width - closeButton.width - parent.spacing
                text: "Omaconnect KDE Plus Settings"
                textFormat: Text.PlainText
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
                wrapMode: Text.Wrap
            }
            Kit.Button {
                id: closeButton
                text: "Close"
                Accessible.name: "Close Plus settings"
                focusable: true
                foreground: Commons.Color.popups.text
                onClicked: root.closeSettings()
            }
        }
        Column {
            id: deviceContext
            width: parent.width
            spacing: Style.space(4)
            Text {
                text: "Device"
                textFormat: Text.PlainText
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
            }
            Controls.ComboBox {
                id: deviceSelector
                objectName: "settings-device-selector"
                width: parent.width
                height: Math.max(44, Style.spacing.controlHeight)
                model: root.deviceOptions
                textRole: "label"
                valueRole: "value"
                currentValue: root.selectedId
                displayText: root.deviceIndex >= 0 ? root.deviceOptions[root.deviceIndex].label : "Choose a device"
                enabled: root.devices.length > 0
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                palette.text: Commons.Color.popups.text
                palette.buttonText: Commons.Color.popups.text
                palette.button: root.surfaceColor
                palette.base: root.surfaceColor
                palette.window: root.surfaceColor
                palette.highlight: Commons.Color.accent
                palette.highlightedText: root.surfaceColor
                Accessible.name: "Device"
                Accessible.description: root.deviceStatus
                contentItem: Text {
                    text: deviceSelector.displayText
                    textFormat: Text.PlainText
                    color: Commons.Color.popups.text
                    font: deviceSelector.font
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
                background: Rectangle {
                    color: root.surfaceColor
                    radius: Style.cornerRadius
                    border.width: deviceSelector.activeFocus ? 2 : Style.normalBorderWidth
                    border.color: deviceSelector.activeFocus ? Commons.Color.accent : Commons.Color.popups.border
                }
                delegate: Controls.ItemDelegate {
                    required property var modelData
                    required property int index
                    text: modelData.label
                    Accessible.name: text
                    width: deviceSelector.width
                    height: Math.max(44, implicitHeight)
                    highlighted: deviceSelector.highlightedIndex === index
                    contentItem: Text {
                        text: modelData.label
                        textFormat: Text.PlainText
                        color: Commons.Color.popups.text
                        font: deviceSelector.font
                        wrapMode: Text.WrapAnywhere
                    }
                    background: Rectangle {
                        color: parent.highlighted ? Style.hoverFillFor(Commons.Color.popups.text, Commons.Color.accent) : root.surfaceColor
                    }
                }
                onActivated: function(index) {
                    var option = root.deviceOptions[index]
                    if (option) root.selectSettingsDevice(option.value)
                }
            }
            Text {
                objectName: "settings-device-status"
                width: parent.width
                text: root.deviceStatus
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
            }
        }
        Row {
            width: parent.width
            height: parent.height - y - returnButton.height - frame.spacing
            spacing: Style.space(16)
            Column {
                width: root.width >= 620 ? 160 : 128
                spacing: Style.space(4)
                Repeater {
                    id: navigation
                    model: root.pages
                    delegate: Kit.Button {
                        required property string modelData
                        width: parent.width
                        text: modelData
                        Accessible.name: "Settings: " + modelData
                        Accessible.role: Accessible.RadioButton
                        Accessible.checkable: true
                        Accessible.checked: selected
                        selected: root.currentPage === modelData
                        focusable: true
                        leftAlign: true
                        foreground: Commons.Color.popups.text
                        onClicked: root.currentPage = modelData
                    }
                }
            }
            Rectangle {
                width: 1
                height: parent.height
                color: Commons.Color.popups.border
            }
            Controls.ScrollView {
                id: pageScroll
                objectName: "settings-page-scroll"
                width: parent.width - x
                height: parent.height
                clip: true
                // Reserve space so the native overlay scrollbar cannot cover text.
                rightPadding: Style.space(12)
                contentWidth: availableWidth
                Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
                Controls.ScrollBar.vertical.policy: pageScroll.contentHeight > pageScroll.availableHeight ? Controls.ScrollBar.AlwaysOn : Controls.ScrollBar.AlwaysOff
                Column {
                    width: pageScroll.availableWidth
                    spacing: Style.space(12)
                    Text {
                        width: parent.width
                        text: root.currentPage
                        textFormat: Text.PlainText
                        color: Commons.Color.popups.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.subtitle
                        font.bold: true
                    }
                    Text {
                        width: parent.width
                        text: "Plus preferences apply to this computer."
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        color: Commons.Color.popups.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                    }
                    Column {
                        width: parent.width
                        visible: root.currentPage === "Appearance"
                        spacing: Style.space(8)
                        Text {
                            width: parent.width
                            text: "Icons and local names change how devices look here. KDE Connect keeps their identity and pairing."
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            color: Commons.Color.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                        }
                        Kit.Button {
                            width: parent.width
                            text: "Change bar icon"
                            Accessible.name: text
                            focusable: true
                            foreground: Commons.Color.popups.text
                            onClicked: iconChooser.openForBar(root.device ? root.device.id : "", root.device ? root.device.type : "phone")
                        }
                        Kit.Button {
                            width: parent.width
                            text: "Change selected device icon and alias"
                            Accessible.name: text
                            focusable: true
                            foreground: Commons.Color.popups.text
                            enabled: !!root.device
                            onClicked: if (root.device) iconChooser.openForDevice(root.device.id, root.device.name, root.device.type)
                        }
                        Text {
                            width: parent.width
                            visible: !root.device
                            text: "Choose a device above to change its icon or local name."
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            color: Commons.Color.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.caption
                        }
                        Kit.Button {
                            width: parent.width
                            text: "Icon and contribution guide ↗"
                            Accessible.name: "Open the local icon and contribution guide"
                            focusable: true
                            foreground: Commons.Color.popups.text
                            onClicked: Qt.openUrlExternally(Qt.resolvedUrl("../docs/ICONS.md"))
                        }
                        PreferenceControls {
                            width: parent.width
                            panel: root.panel
                            preferences: [
                                {key: "showBarBattery", label: "Show battery beside the bar icon", defaultValue: false, description: "Show the selected device’s reported charge beside the icon. Devices without a battery report show no percentage."},
                                {key: "showNetworkControls", label: "Show network controls in Devices", defaultValue: true, description: "Show the providers enabled in Connections. Hiding controls does not disconnect a VPN."},
                                {key: "showSavedAddresses", label: "Show saved addresses", defaultValue: true, description: "Keep approved per-device addresses available for review. Hiding this section keeps saved records and rediscovery preferences."},
                                {key: "showSyncthingLinks", label: "Show Syncthing identity notes", defaultValue: false, description: "Optional reminder that a KDE device and a Syncthing device are the same machine. Opens the existing Syncshell owner; does not show live sync status or share folders."},
                                {key: "networkStartExpanded", label: "Start network controls expanded", defaultValue: true, description: "You can expand or collapse the section in Devices. This sets its state when you open the panel."},
                                {key: "mediaStartExpanded", label: "Start media expanded", defaultValue: true, description: "Choose a compact summary or expanded player when the panel opens."},
                                {key: "commandsStartExpanded", label: "Start remote commands expanded", defaultValue: false, description: "Keep configured remote commands collapsed until needed, or show them when the panel opens."},
                                {key: "addressesStartExpanded", label: "Start saved addresses expanded", defaultValue: false, description: "Applies when saved addresses are shown. Changing this does not approve an address."},
                                {key: "syncthingStartExpanded", label: "Start Syncthing notes expanded", defaultValue: false, description: "Applies when Syncthing identity notes are enabled. Association remains local metadata."}
                            ]
                        }
                    }
                    Column {
                        width: parent.width
                        visible: root.currentPage === "Connections"
                        spacing: Style.space(12)
                        NetworkOptions { width: parent.width; panel: root.panel; configuration: true }
                        PreferenceControls {
                            width: parent.width
                            panel: root.panel
                            preferences: [{key: "bthHelperPath", label: "BTH helper path", defaultValue: "", type: "string", description: "Optional absolute path to the reviewed controller. Leave empty to use ~/.local/bin/remote-access-mode."}]
                        }
                    }
                    Column {
                        width: parent.width
                        visible: root.currentPage === "Quick actions"
                        spacing: Style.space(12)
                        QuickActionsSettings { width: parent.width; panel: root.panel }
                        PreferenceControls {
                            width: parent.width
                            panel: root.panel
                            preferences: [{key: "defaultPingMessage", label: "Default ping message", defaultValue: "", type: "string", description: "Prefill the Ping draft. You can edit it before sending. Ping shows a notification; Ring requests a sound."}]
                        }
                    }
                    Column {
                        width: parent.width
                        visible: root.currentPage === "Device features"
                        spacing: Style.space(12)
                        Text {
                            width: parent.width
                            text: "Native modules and permissions stay in KDE Connect. Plus preferences stay here."
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            color: Commons.Color.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                        }
                        NativeFeaturesSection { width: parent.width; service: root.service; configuration: true }
                        PreferenceControls {
                            width: parent.width
                            panel: root.panel
                            preferences: [
                                {key: "showNativeFeatures", label: "Show native feature entry in Devices", defaultValue: true, description: "The full searchable inventory stays here in Settings, even when the daily entry is hidden."},
                                {key: "showBatteryStats", label: "Show battery details", defaultValue: true, description: "Show charge and charging state when the selected device reports them."},
                                {key: "showNetworkStats", label: "Show cellular connection details", defaultValue: true, description: "Show the device’s reported cellular type and signal. This does not describe Wi-Fi or VPN reachability."},
                                {key: "showMediaPlayer", label: "Show media controls", defaultValue: true, description: "Control a reported media player on the selected device. Open Media in Devices to choose a player."},
                                {key: "showRemoteCommands", label: "Show remote commands", defaultValue: true, description: "Show commands configured on the selected device. Use that device’s KDE Connect Run commands settings to add or edit them."}
                            ]
                        }
                    }
                    Kit.Button {
                        width: parent.width
                        text: "Help with " + root.currentPage.toLowerCase() + " ↗"
                        Accessible.name: "Open the installed task guide for " + root.currentPage.toLowerCase()
                        Accessible.description: "Opens local documentation in your default viewer."
                        focusable: true
                        foreground: Commons.Color.popups.text
                        onClicked: Qt.openUrlExternally(Qt.resolvedUrl("../docs/HELP.md"))
                    }
                    Item { width: 1; height: Style.space(4) }
                }
            }
        }
        Kit.Button {
            id: returnButton
            width: parent.width
            text: "Back to devices"
            Accessible.name: text
            focusable: true
            foreground: Commons.Color.popups.text
            onClicked: { root.closeSettings(); root.returnToPanelRequested() }
        }
    }
    IconChooser {
        id: iconChooser
        parent: root.contentItem
        store: root.service ? root.service.appearance : null
    }
}
