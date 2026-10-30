pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons

Window {
    id: root
    required property var panel
    readonly property var service: panel ? panel.service : null
    readonly property var device: panel ? panel.device : null
    readonly property var devices: service ? service.devices : []
    readonly property var deviceOptions: deviceSelector.deviceOptions
    readonly property string deviceStatus: deviceSelector.deviceStatus
    readonly property string selectedName: device ? (service && typeof service.displayName === "function" ? service.displayName(device) : device.name) : "No device selected"
    readonly property string selectedId: device ? device.id : ""
    onSelectedIdChanged: if (iconChooser) iconChooser.close()
    readonly property var pages: ["Appearance", "Connections", "Quick actions", "Device features"]
    FontMetrics {
        id: navigationMetrics
        font.family: Style.font.family
        font.pixelSize: Style.font.body
    }
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
    onActiveFocusItemChanged: Qt.callLater(root.revealFocusedControl)

    function revealFocusedControl() {
        var item = root.activeFocusItem
        if (!item) return
        var scrolls = [pageScroll, navigationScroll]
        for (var i = 0; i < scrolls.length; ++i) {
            var scroll = scrolls[i], viewport = scroll ? scroll.contentItem : null
            if (!viewport) continue
            var ancestor = item
            while (ancestor && ancestor !== viewport) ancestor = ancestor.parent
            if (!ancestor) continue
            var position = item.mapToItem(scroll, 0, 0)
            var offset = position.y < 0 ? position.y
                : Math.max(0, position.y + item.height - scroll.availableHeight)
            if (offset !== 0) viewport.contentY = Math.max(0, Math.min(
                viewport.contentY + offset, scroll.contentHeight - scroll.availableHeight))
            return
        }
    }

    function selectSettingsDevice(id) { deviceSelector.selectDevice(id) }

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
            SettingsButton {
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
            DeviceSwitcher {
                id: deviceSelector
                objectName: "settings-device-selector"
                width: parent.width
                panel: root.panel
                onAboutToSelect: iconChooser.close()
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
            Controls.ScrollView {
                id: navigationScroll
                objectName: "settings-navigation-scroll"
                width: {
                    // Invokable metrics do not establish a font dependency.
                    // Read the font so startup/theme changes remeasure labels.
                    var font = navigationMetrics.font
                    var minimum = root.width >= 620 ? 160 : 128
                    if (!font.family || font.pixelSize <= 0) return minimum + rightPadding
                    return Math.max(minimum, Math.ceil(root.pages.reduce(function(widest, label) {
                        return Math.max(widest, navigationMetrics.advanceWidth(label))
                    }, 0) + Style.space(8) * 2 + Style.normalBorderWidth * 2)) + rightPadding
                }
                height: parent.height
                rightPadding: Style.space(12)
                contentWidth: availableWidth
                clip: true
                Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
                Column {
                    width: navigationScroll.availableWidth
                    spacing: Style.space(4)
                    Repeater {
                        id: navigation
                        model: root.pages
                        delegate: SettingsButton {
                            required property string modelData
                            width: parent.width
                            height: Math.max(44, implicitHeight)
                            text: modelData
                            Accessible.name: "Settings: " + modelData
                            Accessible.role: Accessible.RadioButton
                            Accessible.checkable: true
                            Accessible.checked: selected
                            selected: root.currentPage === modelData
                            focusable: true
                            leftAlign: true
                            horizontalPadding: Style.space(8)
                            foreground: Commons.Color.popups.text
                            onClicked: root.currentPage = modelData
                        }
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
                        visible: root.currentPage !== "Device features"
                        textFormat: Text.PlainText
                        color: Commons.Color.popups.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.subtitle
                        font.bold: true
                    }
                    Text {
                        width: parent.width
                        text: "Plus preferences apply to this computer only."
                        visible: root.currentPage !== "Device features"
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
                            text: "Icons, names and section order change how Plus looks. Pairing stays the same."
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            color: Commons.Color.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                        }
                        Text {
                            width: parent.width
                            text: "To change this computer’s KDE Connect name, open Native KDE Connect settings in Device features, then choose Settings in the native app menu."
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            color: Commons.Color.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                        }
                        SettingsButton {
                            width: parent.width
                            text: "Change bar icon"
                            Accessible.name: text
                            focusable: true
                            foreground: Commons.Color.popups.text
                            onClicked: iconChooser.openForBar(root.device ? root.device.id : "", root.device ? root.device.type : "phone")
                        }
                        SettingsButton {
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
                            font.pixelSize: Style.font.bodySmall
                        }
                        SettingsButton {
                            width: parent.width
                            text: "Icon and contribution guide ↗"
                            Accessible.name: "Open the local icon and contribution guide"
                            focusable: true
                            foreground: Commons.Color.popups.text
                            onClicked: Qt.openUrlExternally(Qt.resolvedUrl("../docs/ICONS.md"))
                        }
                        NavigationSettings { width: parent.width; panel: root.panel }
                        SectionOrderSettings { width: parent.width; panel: root.panel }
                        PreferenceControls {
                            width: parent.width
                            panel: root.panel
                            preferences: [
                                {key: "showBarBattery", label: "Show battery beside the bar icon", defaultValue: false, description: "Shows the selected device's charge next to the bar icon when the device reports it."},
                            ]
                        }
                    }
                    Column {
                        width: parent.width
                        visible: root.currentPage === "Connections"
                        spacing: Style.space(12)
                        Text {
                            width: parent.width
                            text: "These Plus switches only show or hide controls. To enable KDE Connect connection providers, open Native KDE Connect settings in Device features, then choose Settings in the native app menu."
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            color: Commons.Color.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                        }
                        NetworkOptions { width: parent.width; panel: root.panel; configuration: true }
                        PreferenceControls {
                            width: parent.width
                            panel: root.panel
                            preferences: [
                                {key: "bthHelperPath", label: "BTH helper path", defaultValue: "", type: "string", description: "Optional. Use the full path to your Back to Home script, ending in /remote-access-mode. Leave empty to use ~/.local/bin/remote-access-mode."}
                            ]
                        }
                        SectionDisplaySettings { width: parent.width; panel: root.panel; page: "Connections" }
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
                        SectionDisplaySettings { width: parent.width; panel: root.panel; page: "Quick actions" }
                    }
                    Column {
                        width: parent.width
                        visible: root.currentPage === "Device features"
                        spacing: Style.space(12)
                        NativeFeaturesSection { width: parent.width; service: root.service; configuration: true; settingsActive: root.visible && root.currentPage === "Device features" }
                        PreferenceControls {
                            width: parent.width
                            panel: root.panel
                            preferences: [
                                {key: "showBatteryStats", label: "Show battery details", defaultValue: true, description: "Shows charge and charging state when the device reports them."},
                                {key: "showNetworkStats", label: "Show cellular connection details", defaultValue: true, description: "Shows the phone's mobile network type and signal, not Wi-Fi or VPN."},
                            ]
                        }
                        SectionDisplaySettings { width: parent.width; panel: root.panel; page: "Device features" }
                    }
                    SettingsButton {
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
        SettingsButton {
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
