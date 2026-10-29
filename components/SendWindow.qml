pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit

// A normal managed window stays open when the file manager receives focus.
// All draft/transfer state belongs to the existing service, not this window.
Window {
    id: root
    required property var service
    property var device: null
    readonly property var target: service ? service.draftTarget : null
    readonly property bool canChoose: !!(service && device && device.paired && device.reachable
        && device.capabilities && device.capabilities.file && !service.operationBusy
        && service.selectionState !== "choosing" && service.selectionState !== "draft"
        && (!service.selection || service.selection.length === 0))
    signal returnToPanelRequested()
    title: "OmaConnect Plus — Send files"
    transientParent: null
    flags: Qt.Window
    width: 620
    height: 560
    minimumWidth: 480
    minimumHeight: 360
    color: Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1)
    visible: false

    function openSend() { show(); raise(); requestActivate() }
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
            text: "Send files"
            textFormat: Text.PlainText
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
        }
        Text {
            objectName: "send-window-recipient"
            width: parent.width
            text: root.target ? "Reviewed recipient: \u2068" + root.target.peerName + "\u2069\nKDE ID: \u2068" + root.target.peerId + "\u2069"
                : root.device ? "Selected recipient: \u2068" + (root.service && typeof root.service.displayName === "function" ? root.service.displayName(root.device) : root.device.name) + "\u2069\nKDE ID: \u2068" + root.device.id + "\u2069"
                : "Select a device in Devices first."
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
            Kit.Button {
                text: "Back to devices"
                Accessible.name: text
                focusable: true
                foreground: Commons.Color.popups.text
                onClicked: root.returnToDevices()
            }
            Kit.Button {
                text: "Choose files"
                Accessible.name: text
                focusable: true
                foreground: Commons.Color.popups.text
                enabled: root.canChoose
                onClicked: root.service.chooseFiles(root.device.id)
            }
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
                    text: "This window stays open while you use your file manager. Closing it keeps the current selection and activity."
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: Commons.Color.popups.text
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                }
            }
        }
    }
}
