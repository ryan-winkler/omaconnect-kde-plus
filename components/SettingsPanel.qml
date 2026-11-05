pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import "../i18n" as Locale

Window {
    id: root
    LayoutMirroring.enabled: Commons.I18n.rightToLeft
    LayoutMirroring.childrenInherit: true
    required property var panel
    readonly property var service: panel ? panel.service : null
    readonly property var device: panel ? panel.device : null
    readonly property var devices: service ? service.devices : []
    readonly property var deviceOptions: deviceSelector.deviceOptions
    readonly property string deviceStatus: deviceSelector.deviceStatus
    readonly property string selectedName: device ? (service && typeof service.displayName === "function" ? service.displayName(device) : device.name) : Locale.Strings.t("settings.noDevice")
    readonly property string selectedId: device ? device.id : ""
    onSelectedIdChanged: if (iconChooser) iconChooser.close()
    readonly property var pages: ["Appearance", "Connections", "Quick actions", "Device features"]
    readonly property var pageKeys: ({
        "Appearance": "appearance",
        "Connections": "connections",
        "Quick actions": "quickActions",
        "Device features": "deviceFeatures"
    })
    function pageTitle(page) { return Locale.Strings.t("settings.page." + pageKeys[page]) }

    FontMetrics {
        id: navigationMetrics
        font.family: Style.font.family
        font.pixelSize: Style.font.body
    }
    readonly property color surfaceColor: Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1)
    property string currentPage: "Appearance"
    signal returnToPanelRequested()
    signal closed()

    title: Locale.Strings.t("settings.title")
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
                text: Locale.Strings.t("settings.title")
                textFormat: Text.PlainText
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.title
                font.bold: true
                wrapMode: Text.Wrap
            }
            SettingsButton {
                id: closeButton
                text: Locale.Strings.t("settings.close")
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
                text: Locale.Strings.t("settings.device")
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
                    var measured = Math.ceil(root.pages.reduce(function(widest, page) {
                        return Math.max(widest, navigationMetrics.advanceWidth(root.pageTitle(page)))
                    }, 0) + Style.space(8) * 2 + Style.normalBorderWidth * 2)
                    return Math.min(Math.max(minimum, measured), root.width * 0.45) + rightPadding
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
                            text: root.pageTitle(modelData)
                            Accessible.name: Locale.Strings.t("settings.pageAccessible").arg(text)
                            Accessible.role: Accessible.RadioButton
                            Accessible.checkable: true
                            Accessible.checked: selected
                            Accessible.onToggleAction: if (actionAvailable) clicked()
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
                // Mirrored Row positions depend on child widths; do not size from x.
                width: parent.width - navigationScroll.width - 1 - parent.spacing * 2
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
                        text: root.pageTitle(root.currentPage)
                        visible: root.currentPage !== "Device features"
                        textFormat: Text.PlainText
                        color: Commons.Color.popups.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.subtitle
                        font.bold: true
                    }
                    Text {
                        width: parent.width
                        text: Locale.Strings.t("settings.scope")
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
                            text: Locale.Strings.t("settings.appearanceHelp")
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            color: Commons.Color.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                        }
                        Text {
                            width: parent.width
                            text: Locale.Strings.t("settings.renameHostHelp")
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            color: Commons.Color.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                        }
                        SettingsButton {
                            width: parent.width
                            text: Locale.Strings.t("settings.barIcon")
                            Accessible.name: text
                            focusable: true
                            foreground: Commons.Color.popups.text
                            onClicked: iconChooser.openForBar(root.device ? root.device.id : "", root.device ? root.device.type : "phone")
                        }
                        SettingsButton {
                            width: parent.width
                            text: Locale.Strings.t("settings.deviceIcon")
                            Accessible.name: text
                            focusable: true
                            foreground: Commons.Color.popups.text
                            enabled: !!root.device
                            onClicked: if (root.device) iconChooser.openForDevice(root.device.id, root.device.name, root.device.type)
                        }
                        Text {
                            width: parent.width
                            visible: !root.device
                            text: Locale.Strings.t("settings.chooseDevice")
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            color: Commons.Color.popups.text
                            font.family: Style.font.family
                            font.pixelSize: Style.font.bodySmall
                        }
                        SettingsButton {
                            width: parent.width
                            text: Locale.Strings.t("settings.iconsGuide")
                            Accessible.name: Locale.Strings.t("settings.iconsGuideAccessible")
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
                                {key: "showBarBattery", label: Locale.Strings.t("settings.batteryIcon"), defaultValue: false, description: Locale.Strings.t("settings.batteryIconHelp")},
                            ]
                        }
                    }
                    Column {
                        width: parent.width
                        visible: root.currentPage === "Connections"
                        spacing: Style.space(12)
                        Text {
                            width: parent.width
                            text: Locale.Strings.t("settings.connectionsHelp")
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
                                {key: "bthHelperPath", label: Locale.Strings.t("settings.bthPath"), defaultValue: "", type: "string", description: Locale.Strings.t("settings.bthPathHelp")}
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
                            preferences: [
                                {key: "useDesktopFileChooser", label: Locale.Strings.t("settings.desktopChooser"), defaultValue: false, description: Locale.Strings.t("settings.desktopChooserHelp")},
                                {key: "reviewFilesBeforeSend", label: Locale.Strings.t("settings.reviewFiles"), defaultValue: false, description: Locale.Strings.t("settings.reviewFilesHelp")},
                                {key: "taskNotificationsEnabled", label: Locale.Strings.t("notice.enabled.label"), defaultValue: true, description: Locale.Strings.t("notice.enabled.help")},
                                {key: "taskNotificationDeviceName", label: Locale.Strings.t("notice.deviceName.label"), defaultValue: false, description: Locale.Strings.t("notice.deviceName.help")},
                                {key: "defaultPingMessage", label: Locale.Strings.t("settings.pingDefault"), defaultValue: "", type: "string", description: Locale.Strings.t("settings.pingDefaultHelp")}
                            ]
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
                                {key: "showBatteryStats", label: Locale.Strings.t("settings.battery"), defaultValue: true, description: Locale.Strings.t("settings.batteryHelp")},
                                {key: "showNetworkStats", label: Locale.Strings.t("settings.mobileNetwork"), defaultValue: true, description: Locale.Strings.t("settings.mobileNetworkHelp")},
                            ]
                        }
                        SectionDisplaySettings { width: parent.width; panel: root.panel; page: "Device features" }
                    }
                    SettingsButton {
                        width: parent.width
                        text: Locale.Strings.t("settings.help." + root.pageKeys[root.currentPage])
                        Accessible.name: Locale.Strings.t("settings.helpAccessible." + root.pageKeys[root.currentPage])
                        Accessible.description: Locale.Strings.t("settings.helpViewer")
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
            text: Locale.Strings.t("settings.back")
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
