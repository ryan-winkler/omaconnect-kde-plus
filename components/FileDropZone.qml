pragma ComponentBehavior: Bound
import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit

Kit.BorderSurface {
    id: root
    required property var service
    property var device: null
    signal filesStaged()
    readonly property bool ready: dropArea.ready
    readonly property string instructions: dropArea.instructions
    width: parent ? parent.width : 0
    implicitHeight: copy.implicitHeight + Style.space(24)
    color: dropArea.containsDrag ? Style.hoverFillFor(Commons.Color.popups.text, Commons.Color.accent) : "transparent"
    radius: Style.cornerRadius
    borderSpec: Commons.Border.controlSpec(dropArea.containsDrag ? "focus" : "normal", Commons.Color.popups.text, Commons.Color.accent)
    Accessible.role: Accessible.StaticText
    Accessible.name: "Drop files for review"
    Accessible.description: instructions

    function acceptFiles(event) { return dropArea.acceptFiles(event) }
    Text {
        id: copy
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: Style.space(12)
        text: dropArea.containsDrag && root.ready ? "Release to review these files. Nothing sends until you select Send." : root.instructions
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
    FileDropArea {
        id: dropArea
        anchors.fill: parent
        service: root.service
        device: root.device
        onFilesStaged: root.filesStaged()
    }
}
