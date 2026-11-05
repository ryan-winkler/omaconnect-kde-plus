pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons as Commons
import "../ActionCatalog.js" as Actions

Column {
    id: root
    required property var service
    readonly property var device: service ? service.selectedDevice : null
    readonly property bool supported: Actions.compatible("browse-files", device)
    width: parent ? parent.width : 0
    spacing: Commons.Style.space(6)
    visible: supported || (!!service && service.phoneFilesMessage !== "")
    Flow {
        width: parent.width
        spacing: Commons.Style.space(6)
        SettingsButton {
            objectName: "browse-phone-files"
            text: "Browse phone files"
            width: Math.min(implicitWidth, parent.width)
            height: Math.max(44, implicitHeight)
            foreground: Commons.Color.popups.text
            focusable: true
            enabled: !!root.service && Actions.ready("browse-files", root.device, root.service)
            Accessible.description: "Open shared phone folders in the default file manager. The phone's KDE Connect Filesystem expose permission is required."
            onClicked: root.service.browsePhoneFiles(root.device.id)
        }
        SettingsButton {
            objectName: "cancel-phone-files"
            text: "Cancel browse"
            width: Math.min(implicitWidth, parent.width)
            height: Math.max(44, implicitHeight)
            foreground: Commons.Color.popups.text
            focusable: true
            visible: !!root.service && (root.service.phoneFilesBusy || root.service.phoneFilesState === "choosing")
            onClicked: root.service.cancelPhoneFiles(false)
        }
    }
    Text {
        width: parent.width
        text: "KDE Connect mounts the phone's shared folders. Files open in your default file manager."
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.caption
    }
    Text {
        objectName: "phone-files-status"
        width: parent.width
        visible: text !== ""
        text: root.service ? root.service.phoneFilesMessage : ""
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.bodySmall
        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }
    Repeater {
        model: root.service && root.service.phoneFilesState === "choosing" && root.service.phoneFileLocations.length > 1
            ? root.service.phoneFileLocations : []
        delegate: SettingsButton {
            required property var modelData
            required property int index
            objectName: "phone-files-choice-" + index
            width: root.width
            height: Math.max(44, implicitHeight)
            text: modelData.name
            foreground: Commons.Color.popups.text
            focusable: true
            enabled: !!root.service && !root.service.phoneFilesBusy
            Accessible.name: "Open shared folder " + modelData.name
            Accessible.description: "Open this advertised shared folder in the default file manager."
            onClicked: root.service.openPhoneFileLocation(index)
        }
    }
    SettingsButton {
        objectName: "phone-files-native-settings"
        text: "Phone file settings in KDE ↗"
        width: Math.min(implicitWidth, parent.width)
        height: Math.max(44, implicitHeight)
        foreground: Commons.Color.popups.text
        focusable: true
        enabled: !!root.service && !root.service.nativeAppOpening
        Accessible.description: "Open native KDE Connect to check the Filesystem expose module and permissions."
        onClicked: root.service.openKdeConnectApp("kdeconnect_sftp")
    }
}
