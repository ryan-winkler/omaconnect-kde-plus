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
    readonly property string selectedName: device ? (service && typeof service.displayName === "function" ? service.displayName(device) : device.name) : "No device selected"
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

    function openSettings(page) {
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
        enabled: root.visible && !iconChooser.opened
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
                        text: (root.currentPage === "Appearance" || root.currentPage === "Device features")
                            ? "Selected device: " + root.selectedName + ". These settings apply to this computer only."
                            : "These settings apply to this computer only."
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
                            text: "Icons and names change only how devices look in Plus. Pairing stays the same."
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
                            text: "Choose a device in Devices first to change its icon or local name."
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            color: Commons.Color.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
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
                                {key: "showBarBattery", label: "Show battery beside the bar icon", defaultValue: false, description: "Shows the selected device's charge next to the bar icon when the device reports it."},
                                {key: "showSyncthingLinks", label: "Show Syncthing identity notes", defaultValue: false, description: "Adds a note in Devices that matches this device to its Syncthing ID. It does not sync files."},
                                {key: "syncthingStartExpanded", label: "Start Syncthing notes expanded", defaultValue: false, description: "On shows Syncthing notes when the panel opens, if the notes are shown."}
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
                            preferences: [
                                {key: "showNetworkControls", label: "Show network controls in Devices", defaultValue: true, description: "Shows the buttons for the VPN tools you turned on above."},
                                {key: "networkStartExpanded", label: "Start network controls expanded", defaultValue: true, description: "On shows the network buttons when the panel opens."},
                                {key: "showSavedAddresses", label: "Show saved addresses", defaultValue: true, description: "Shows each device's saved IP addresses in Devices. Hiding them deletes nothing."},
                                {key: "addressesStartExpanded", label: "Start saved addresses expanded", defaultValue: false, description: "On shows saved addresses when the panel opens."},
                                {key: "bthHelperPath", label: "BTH helper path", defaultValue: "", type: "string", description: "Optional. The full path to your Back to Home script. Leave empty to use ~/.local/bin/remote-access-mode."}
                            ]
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
                            preferences: [{key: "defaultPingMessage", label: "Default ping message", defaultValue: "", type: "string", description: "Fills in a new Ping message. You can edit it before you send."}]
                        }
                    }
                    Column {
                        width: parent.width
                        visible: root.currentPage === "Device features"
                        spacing: Style.space(12)
                        Text {
                            width: parent.width
                            text: "Turn device features on or off in KDE Connect. Choose what Plus shows here."
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
                                {key: "showNativeFeatures", label: "Show native feature entry in Devices", defaultValue: true, description: "Adds an All KDE Connect features button in Devices. The full list stays here."},
                                {key: "showBatteryStats", label: "Show battery details", defaultValue: true, description: "Shows charge and charging state when the device reports them."},
                                {key: "showNetworkStats", label: "Show cellular connection details", defaultValue: true, description: "Shows the phone's mobile network type and signal, not Wi-Fi or VPN."},
                                {key: "showMediaPlayer", label: "Show media controls", defaultValue: true, description: "Shows play, pause and skip for music or video on the device."},
                                {key: "mediaStartExpanded", label: "Start media expanded", defaultValue: true, description: "On shows the full player when the panel opens. Off shows a short summary."},
                                {key: "showRemoteCommands", label: "Show remote commands", defaultValue: true, description: "Shows the commands you set up in the device's KDE Connect Run commands settings."},
                                {key: "commandsStartExpanded", label: "Start remote commands expanded", defaultValue: false, description: "On shows your remote commands when the panel opens."}
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
