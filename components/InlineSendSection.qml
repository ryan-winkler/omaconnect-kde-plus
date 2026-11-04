pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import qs.Commons as Commons

// Daily Devices content; transfer review and submission keep their existing owner.
Column {
    id: root
    required property var panel
    readonly property var service: panel ? panel.service : null
    readonly property var device: panel ? panel.device : null
    signal filesStaged()
    width: parent ? parent.width : 0
    spacing: Style.space(8)

    FileDropZone {
        id: dropZone
        objectName: "inline-send-drop-zone"
        width: parent.width
        service: root.service
        device: root.device
        onFilesStaged: root.filesStaged()
    }
    Flow {
        width: parent.width
        spacing: Style.space(8)
        SettingsButton {
            objectName: "inline-send-choose-files"
            text: "Choose files"
            foreground: Commons.Color.popups.text
            focusable: true
            enabled: dropZone.ready
            onClicked: if (enabled) root.panel.chooseFiles()
        }
        SettingsButton {
            objectName: "inline-send-open-window"
            text: "Keep Send window open"
            tooltipText: "Switching to your file manager can close this popup. This window stays open as a drop target while you review."
            foreground: Commons.Color.popups.text
            focusable: true
            enabled: !!root.panel && typeof root.panel.openSendWindow === "function"
            onClicked: if (enabled) root.panel.openSendWindow()
        }
    }
    Text {
        width: parent.width
        text: root.panel.fileChoiceHint
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    SendSection {
        objectName: "inline-send-review"
        width: parent.width
        service: root.service
        device: root.device
        foreground: Commons.Color.popups.text
        fontFamily: Style.font.family
        showHeading: false
    }
}
