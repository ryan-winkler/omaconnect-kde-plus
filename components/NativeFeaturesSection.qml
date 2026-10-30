pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit

Column {
    id: root
    required property var service
    readonly property var device: service ? service.selectedDevice : null
    property bool configuration: false
    property alias searchText: featureSearch.text
    readonly property var filteredPluginIds: {
        var query = featureSearch.text.trim().toLowerCase()
        return pluginIds.filter(function(id) { return !query || id.toLowerCase().indexOf(query) !== -1 || root.taskName(id).toLowerCase().indexOf(query) !== -1 })
    }
    readonly property var pluginIds: device && device.pluginIds ? device.pluginIds : []
    readonly property var nativeConfigurations: nativeMetadata.item ? nativeMetadata.item.configurations : []
    readonly property var filteredConfigurations: {
        var query = featureSearch.text.trim().toLowerCase()
        return nativeConfigurations.filter(function(entry) { return !query || (entry.id + " " + entry.name + " " + entry.description).toLowerCase().indexOf(query) !== -1 })
    }
    // IDs remain visible even when this version has no friendly task label.
    function taskName(id) {
        var name = nativeMetadata.item ? nativeMetadata.item.displayName(id) : ""
        return name || id
    }
    Loader {
        id: nativeMetadata
        active: root.configuration
        visible: false
        source: Qt.resolvedUrl("NativePluginMetadata.qml")
    }
    width: parent ? parent.width : 0
    spacing: Style.space(6)
    Kit.Button {
        width: parent.width
        text: "Native KDE Connect settings"
        Accessible.name: text
        Accessible.description: (root.device ? "Open the selected device in KDE Connect." : "Open KDE Connect's device list.") + " Use Plugin settings to choose native features and permissions. Older settings frontends may open the device list."
        focusable: true
        enabled: !!root.service && !root.service.nativeAppOpening
        onClicked: if (root.service) root.service.openKdeConnectApp()
    }
    Text {
        objectName: "native-launch-status"
        width: parent.width
        visible: text !== ""
        text: root.service ? root.service.nativeAppMessage : ""
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: root.service && root.service.nativeAppFailed ? Commons.Color.urgent : Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }
    Text {
        width: parent.width
        visible: !root.configuration
        text: "Opens the device in KDE Connect, where you turn its features on or off."
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    VirtualMonitorSection { width: parent.width; service: root.service; configuration: root.configuration }
    DeviceInformationSection { width: parent.width; visible: root.configuration; service: root.service }
    Text {
        width: parent.width
        visible: root.configuration && (!root.device || !root.device.paired || !root.device.reachable)
        text: !root.device ? "Choose a device above. KDE Connect can still open its device list."
            : !root.device.paired ? "Not paired. Open KDE Connect to pair this device and choose its native features."
            : "Offline. Live tasks need a connection. Local icon, name and native configuration are still available."
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    Column {
        width: parent.width
        visible: root.configuration
        spacing: Style.space(8)
        Text {
            width: parent.width
            text: "Features this device reports"
            textFormat: Text.PlainText
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
        }
        Text {
            width: parent.width
            text: "Turn features on in KDE Connect Plugin settings. They are not Omarchy bar plugins."
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
        }
        Text {
            width: parent.width
            text: "Search device features"
            textFormat: Text.PlainText
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
        }
        Kit.TextField {
            id: featureSearch
            objectName: "native-feature-search"
            width: parent.width
            placeholderText: "Task name or plugin ID"
            foreground: Commons.Color.popups.text
            Accessible.name: "Search device features"
            selectByMouse: true
            maximumLength: 128
        }
        Text {
            width: parent.width
            text: root.pluginIds.length === 0 ? "No device feature list was reported. Installed configuration pages may still be available below."
                : root.filteredPluginIds.length === 0 ? "No matching reported device features. Check the configuration pages below or clear the search."
                : "Showing " + root.filteredPluginIds.length + " of " + root.pluginIds.length + " reported device features"
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
        }
        Text {
            width: parent.width
            text: "Supported: the device can use it. Loaded: KDE Connect runs it now. This does not confirm settings or phone permissions."
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
        }
        Column {
            width: parent.width
            spacing: Style.space(6)
            Text {
                width: parent.width
                text: "Commands on the selected device"
                textFormat: Text.PlainText
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
            }
            Kit.Button {
                objectName: "request-remote-command-editor"
                width: parent.width
                height: Math.max(44, implicitHeight)
                text: "Request command editor on selected device"
                Accessible.name: text
                Accessible.description: "Ask the selected device to open its command setup. No command runs."
                focusable: true
                enabled: !!root.device && root.device.paired && root.device.reachable
                    && root.pluginIds.indexOf("kdeconnect_remotecommands") !== -1
                    && root.service.actionState !== "running"
                foreground: Commons.Color.popups.text
                onClicked: if (enabled) root.service.editRemoteCommands(root.device.id)
            }
            Text {
                width: parent.width
                text: "For commands that run there. The device must be connected and accept remote setup requests. Check that device for the editor; if unavailable, open its KDE Connect Run commands settings. No command runs."
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }
            Text {
                width: parent.width
                visible: !!root.service && !!(root.service.actionError || root.service.actionMessage)
                text: root.service ? "Latest device action: " + (root.service.actionError || root.service.actionMessage) : ""
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }
            Text {
                width: parent.width
                text: "Configure this computer for the selected device"
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.body
                font.bold: true
            }
            Text {
                width: parent.width
                text: "Open installed KDE Connect configuration pages. Run commands defines commands on this computer that the selected device can run. Edit commands on the other device there. Module switches and permissions stay in native Plugin Settings."
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }
            Repeater {
                model: root.filteredConfigurations
                delegate: Column {
                    required property var modelData
                    width: parent.width
                    spacing: Style.space(2)
                    Kit.Button {
                        objectName: "native-configure-" + modelData.id
                        width: parent.width
                        height: Math.max(44, implicitHeight)
                        text: modelData.id === "kdeconnect_runcommand" ? "Configure commands on this computer ↗" : "Configure " + modelData.name + " ↗"
                        Accessible.name: modelData.id === "kdeconnect_runcommand" ? "Configure commands on this computer in native KDE Connect" : "Configure " + modelData.name + " in native KDE Connect"
                        Accessible.description: modelData.description + ". On this computer, for the selected device."
                        enabled: !!root.device && root.device.paired && !root.service.nativeAppOpening
                        focusable: true
                        foreground: Commons.Color.popups.text
                        onClicked: root.service.openKdeConnectApp(modelData.id)
                    }
                    Text {
                        width: parent.width
                        text: modelData.description
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        color: Commons.Color.popups.text
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }
                }
            }
            Text {
                width: parent.width
                visible: !root.device || !root.device.paired || root.filteredConfigurations.length === 0
                text: !root.device ? "Choose a device to configure its native features."
                    : !root.device.paired ? "Pair this device in KDE Connect before configuring native features."
                    : root.nativeConfigurations.length === 0 ? "Native configuration metadata is unavailable. Open Native KDE Connect settings, then Plugin Settings."
                    : "No matching configuration pages. Clear the search to see all installed pages."
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }
        }
        Text {
            width: parent.width
            text: "Reported device features"
            textFormat: Text.PlainText
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
        }
        Repeater {
            model: root.filteredPluginIds
            delegate: Text {
                required property string modelData
                width: parent.width
                text: root.taskName(modelData) + "\n" + modelData + " · Supported · "
                    + (!root.device || !root.device.paired || !root.device.reachable || !root.device.loadedKnown ? "Loading status unknown" : (root.device.loadedPluginIds || []).indexOf(modelData) !== -1 ? "Loaded" : "Not loaded")
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
            }
        }
        Kit.Button {
            width: parent.width
            text: "KDE Connect user guide ↗"
            Accessible.name: "Open the official KDE Connect user guide"
            focusable: true
            foreground: Commons.Color.popups.text
            onClicked: Qt.openUrlExternally("https://kdeconnect.kde.org/users.html")
        }
    }
}
