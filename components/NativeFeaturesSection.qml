pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import qs.Commons as Commons
import "../i18n" as Locale

Column {
    id: root
    required property var service
    property bool configuration: false
    property bool settingsActive: false
    property bool informationExpanded: false
    property bool actionsExpanded: false
    property alias searchText: moduleSettings.searchText
    readonly property var device: service ? service.selectedDevice : null
    readonly property var pluginIds: device && device.pluginIds ? device.pluginIds : []
    readonly property var installedModules: nativeMetadata.item ? nativeMetadata.item.modules : []
    readonly property var nativeConfigurations: nativeMetadata.item ? nativeMetadata.item.configurations : []
    readonly property var filteredPluginIds: {
        var query = searchText.trim().toLowerCase()
        return pluginIds.filter(function(id) { return !query || (id + " " + root.taskName(id)).toLowerCase().indexOf(query) !== -1 })
    }
    readonly property var unknownPluginIds: filteredPluginIds.filter(function(id) {
        return !root.installedModules.some(function(entry) { return entry.id === id })
    })
    function taskName(id) {
        var name = nativeMetadata.item ? nativeMetadata.item.displayName(id) : ""
        return name || id
    }
    Loader {
        id: nativeMetadata
        active: root.configuration && root.settingsActive
        visible: false
        source: Qt.resolvedUrl("NativePluginMetadata.qml")
    }
    width: parent ? parent.width : 0
    spacing: Style.space(8)
    Flow {
        width: parent.width
        spacing: Style.space(6)
        SettingsButton {
            width: Math.min(implicitWidth, parent.width)
            height: Math.max(44, implicitHeight)
            text: root.configuration ? Locale.Strings.t("nativeFeatures.nativeSettings") : Locale.Strings.t("nativeFeatures.nativeKdeConnectSettings")
            Accessible.name: Locale.Strings.t("nativeFeatures.nativeKdeConnectSettings")
            Accessible.description: Locale.Strings.t("nativeFeatures.openTheSelectedDeviceInNative")
            focusable: true
            foreground: Commons.Color.popups.text
            enabled: !!root.service && !root.service.nativeAppOpening
            onClicked: if (root.service) root.service.openKdeConnectApp()
        }
        SettingsButton {
            visible: root.configuration
            width: Math.min(implicitWidth, parent.width)
            height: Math.max(44, implicitHeight)
            text: Locale.Strings.t("nativeFeatures.info")
            Accessible.name: Locale.Strings.t(root.informationExpanded ? "nativeFeatures.hideInformation" : "nativeFeatures.showInformation")
            tooltipText: Locale.Strings.t("nativeFeatures.deviceIdentityBatteryAndConnectionInformation")
            focusable: true
            foreground: Commons.Color.popups.text
            selected: root.informationExpanded
            onClicked: root.informationExpanded = !root.informationExpanded
        }
        SettingsButton {
            visible: root.configuration
            width: Math.min(implicitWidth, parent.width)
            height: Math.max(44, implicitHeight)
            text: Locale.Strings.t("nativeFeatures.actions")
            Accessible.name: Locale.Strings.t(root.actionsExpanded ? "nativeFeatures.hideActions" : "nativeFeatures.showActions")
            tooltipText: Locale.Strings.t("nativeFeatures.virtualMonitorAndCommandSetupOn")
            focusable: true
            foreground: Commons.Color.popups.text
            selected: root.actionsExpanded
            onClicked: root.actionsExpanded = !root.actionsExpanded
        }
    }
    Text {
        objectName: "native-launch-status"
        width: parent.width
        visible: text !== ""
        text: root.service ? root.service.nativeAppMessage : ""
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }
    DeviceInformationSection {
        width: parent.width
        visible: root.configuration && root.informationExpanded
        service: root.service
    }
    Column {
        width: parent.width
        visible: root.configuration && root.actionsExpanded
        spacing: Style.space(6)
        VirtualMonitorSection { width: parent.width; service: root.service; configuration: true }
        SettingsButton {
            objectName: "request-remote-command-editor"
            width: parent.width
            height: Math.max(44, implicitHeight)
            text: Locale.Strings.t("nativeFeatures.requestCommandEditorOnSelectedDevice")
            Accessible.name: text
            Accessible.description: Locale.Strings.t("nativeFeatures.askTheSelectedDeviceToOpen")
            focusable: true
            foreground: Commons.Color.popups.text
            enabled: !!root.device && root.device.paired && root.device.reachable
                && root.pluginIds.indexOf("kdeconnect_remotecommands") !== -1 && root.service.actionState !== "running"
            onClicked: if (enabled) root.service.editRemoteCommands(root.device.id)
        }
        Text {
            width: parent.width
            text: Locale.Strings.t("nativeFeatures.forCommandsThatRunOnThe")
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
        }
        Text {
            width: parent.width
            visible: !!root.service && !!(root.service.actionError || root.service.actionMessage)
            text: root.service ? Locale.Strings.format("nativeFeatures.latestAction", [root.service.actionError || root.service.actionMessage]) : ""
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
        }
    }
    NativeModuleSettings {
        id: moduleSettings
        width: parent.width
        visible: root.configuration
        service: root.service
        modules: root.installedModules
        active: root.configuration && root.settingsActive
        onConfigureRequested: function(pluginId) { if (root.service) root.service.openKdeConnectApp(pluginId) }
    }
    Text {
        width: parent.width
        visible: root.configuration && !!nativeMetadata.item && nativeMetadata.item.truncated
        text: Locale.Strings.t("nativeFeatures.someInstalledModulesAreOmittedOpen")
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    Column {
        width: parent.width
        visible: root.configuration && root.unknownPluginIds.length > 0
        spacing: Style.space(4)
        Text {
            width: parent.width
            text: Locale.Strings.t("nativeFeatures.additionalDeviceReportedFeatures")
            textFormat: Text.PlainText
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
        }
        Repeater {
            model: root.unknownPluginIds
            delegate: Text {
                required property string modelData
                width: parent.width
                text: Locale.Strings.format("nativeFeatures.missingModule", [modelData])
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }
        }
    }
    VirtualMonitorSection { width: parent.width; visible: !root.configuration; service: root.service }
    SettingsButton {
        visible: root.configuration
        width: Math.min(implicitWidth, parent.width)
        text: Locale.Strings.t("nativeFeatures.kdeConnectUserGuide")
        Accessible.name: Locale.Strings.t("nativeFeatures.openTheOfficialKdeConnectUser")
        focusable: true
        foreground: Commons.Color.popups.text
        onClicked: Qt.openUrlExternally("https://kdeconnect.kde.org/users.html")
    }
}
