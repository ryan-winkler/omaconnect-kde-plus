pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit
import "../i18n" as Locale

// A normal managed window stays open when the file manager receives focus.
// All draft/transfer state belongs to the existing service, not this window.
Window {
    id: root
    LayoutMirroring.enabled: Commons.I18n.rightToLeft
    LayoutMirroring.childrenInherit: true
    required property var service
    property var device: null
    property var chooserOptions: ({useDesktopFileChooser: false, reviewFilesBeforeSend: false})
    property string fileChoiceHint: Locale.Strings.t("files.immediateHint")
    readonly property var target: service ? service.draftTarget : null
    readonly property bool canChoose: !!(service && device && device.paired && device.reachable
        && device.capabilities && device.capabilities.file && !service.operationBusy && !service.selectionCancelling
        && service.selectionState !== "choosing" && service.selectionState !== "draft" && service.selectionState !== "preview"
        && (!service.selection || service.selection.length === 0))
    signal returnToPanelRequested()
    signal chooserStarted()
    title: Locale.Strings.t("sendWindow.omaconnectKdePlusSendFiles")
    transientParent: null
    flags: Qt.Window
    width: 620
    height: 560
    minimumWidth: 480
    minimumHeight: 360
    color: Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1)
    visible: false
    property var noticeSurfaceService: null
    function syncTaskNoticeSurface() {
        if (noticeSurfaceService && noticeSurfaceService !== service && typeof noticeSurfaceService.setTaskNoticeSurfaceVisible === "function")
            noticeSurfaceService.setTaskNoticeSurfaceVisible(root, "send", false)
        noticeSurfaceService = service
        if (service && typeof service.setTaskNoticeSurfaceVisible === "function")
            service.setTaskNoticeSurfaceVisible(root, "send", visible)
    }
    onServiceChanged: syncTaskNoticeSurface()
    onVisibleChanged: syncTaskNoticeSurface()
    Component.onDestruction: if (noticeSurfaceService && typeof noticeSurfaceService.setTaskNoticeSurfaceVisible === "function")
        noticeSurfaceService.setTaskNoticeSurfaceVisible(root, "send", false)

    function openSend() { show(); raise(); requestActivate() }
    function chooseFiles() {
        if (!canChoose || !service.chooseFiles(device.id, chooserOptions)) return false
        chooserStarted()
        return true
    }
    function returnToDevices() { hide(); returnToPanelRequested() }
    Shortcut { sequence: "Escape"; context: Qt.WindowShortcut; onActivated: root.close() }
    Shortcut { sequence: "Ctrl+W"; context: Qt.WindowShortcut; onActivated: root.close() }

    Column {
        id: layout
        anchors.fill: parent
        anchors.margins: Style.spacing.panelPadding
        spacing: Style.space(12)
        Text {
            width: parent.width
            text: Locale.Strings.t("files.send")
            textFormat: Text.PlainText
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
        }
        Text {
            objectName: "send-window-recipient"
            width: parent.width
            text: root.target ? Locale.Strings.format("files.reviewedRecipient", [root.target.peerName, root.target.peerId])
                : root.device ? Locale.Strings.format("files.selectedRecipient", [
                    root.service && typeof root.service.displayName === "function" ? root.service.displayName(root.device) : root.device.name, root.device.id])
                : Locale.Strings.t("sendWindow.selectADeviceInDevicesFirst")
            Accessible.role: Accessible.StaticText
            Accessible.name: text
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
        }
        Flow {
            id: actions
            width: parent.width
            spacing: Style.space(8)
            SettingsButton {
                objectName: "send-window-back-to-devices"
                text: Locale.Strings.t("settings.back")
                Accessible.name: text
                focusable: true
                foreground: Commons.Color.popups.text
                onClicked: root.returnToDevices()
            }
            SettingsButton {
                objectName: "send-window-choose-files"
                text: Locale.Strings.t("files.choose")
                Accessible.name: text
                focusable: true
                foreground: Commons.Color.popups.text
                enabled: root.canChoose
                onClicked: root.chooseFiles()
            }
        }
        Text {
            width: parent.width
            text: root.fileChoiceHint
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
        }
        Controls.ScrollView {
            width: parent.width
            height: Math.max(1, root.height - layout.anchors.margins * 2 - y)
            contentWidth: availableWidth
            clip: true
            Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
            Column {
                width: parent.width
                spacing: Style.space(12)
                FileDropZone {
                    objectName: "send-window-drop-zone"
                    width: parent.width
                    service: root.service
                    device: root.device
                }
                SendSection {
                    width: parent.width
                    service: root.service
                    device: root.device
                    foreground: Commons.Color.popups.text
                    fontFamily: Style.font.family
                }
                Text {
                    width: parent.width
                    text: Locale.Strings.t("sendWindow.thisWindowStaysOpenWhileYou")
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: Commons.Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.bodySmall
                }
            }
        }
    }
}
