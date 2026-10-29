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
    // IDs remain visible even when this version has no friendly task label.
    function taskName(id) {
        var tasks = {
            kdeconnect_battery: "Check battery", kdeconnect_ping: "Send a ping",
            kdeconnect_share: "Share files, text and links", kdeconnect_clipboard: "Share clipboard",
            kdeconnect_findmyphone: "Ring the other device", kdeconnect_findthisdevice: "Let the other device ring this computer",
            kdeconnect_notifications: "View notifications from the other device", kdeconnect_sendnotifications: "Send this computer's notifications",
            kdeconnect_replynotifications: "Reply to notifications", kdeconnect_sftp: "Browse the other device's files",
            kdeconnect_mprisremote: "Control the other device's media", kdeconnect_mpriscontrol: "Let the other device control this computer's media",
            kdeconnect_remotecommands: "Run commands on the other device", kdeconnect_runcommand: "Choose commands the other device can run here",
            kdeconnect_mousepad: "Let the other device control this computer's input", kdeconnect_remotekeyboard: "Type on the other device",
            kdeconnect_presenter: "Use presentation controls", kdeconnect_sms: "Send and read SMS",
            kdeconnect_contacts: "Use shared contacts", kdeconnect_lockdevice: "Device locking",
            kdeconnect_connectivity_report: "Check cellular connection", kdeconnect_telephony: "Handle call events",
            kdeconnect_pausemusic: "Pause media during calls", kdeconnect_systemvolume: "System volume",
            kdeconnect_remotesystemvolume: "Volume controls", kdeconnect_shareinputdevices: "Share input devices"
        }
        return tasks[id] || id
    }
    width: parent ? parent.width : 0
    spacing: Style.space(6)
    Kit.Button {
        width: parent.width
        text: "All KDE Connect features"
        Accessible.name: text
        Accessible.description: "Open the selected device in KDE Connect. Use Plugin settings to choose its native features and permissions."
        focusable: true
        enabled: !!root.service
        onClicked: if (root.service) root.service.openKdeConnectApp()
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
    Text {
        width: parent.width
        visible: root.configuration && (!root.device || !root.device.paired || !root.device.reachable)
        text: !root.device ? "Choose a device in Devices first. KDE Connect can still open its device list."
            : "KDE Connect shows Plugin settings when this device is paired and online. Connect it, then open KDE Connect."
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
            text: root.pluginIds.length === 0 ? "This device sent no feature list. Open KDE Connect to check it."
                : root.filteredPluginIds.length === 0 ? "No matching features. Clear the search or open native Plugin settings."
                : "Showing " + root.filteredPluginIds.length + " of " + root.pluginIds.length + " features"
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
        }
        Text {
            width: parent.width
            text: "Supported: the device can use it. Loaded: KDE Connect runs it now."
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
        }
        Repeater {
            model: root.filteredPluginIds
            delegate: Text {
                required property string modelData
                width: parent.width
                text: root.taskName(modelData) + "\n" + modelData + " · Supported · "
                    + (!root.device || !root.device.loadedKnown ? "Loading status unknown" : (root.device.loadedPluginIds || []).indexOf(modelData) !== -1 ? "Loaded" : "Not loaded")
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
