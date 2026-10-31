pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Column {
    id: root

    required property var panel

    width: parent ? parent.width : 0
    spacing: Style.space(6)
    visible: !!(panel && panel.remoteCommandsVisible)

    readonly property var bar: panel ? panel.bar : null
    readonly property var service: panel ? panel.service : null
    readonly property var device: panel ? panel.device : null
    readonly property color foreground: bar ? bar.foreground : "#ffffff"
    readonly property string fontFamily: bar ? bar.fontFamily : "sans-serif"
    readonly property bool hasMediaAbove: !!(panel && panel.mediaPlayerVisible)

    PanelSeparator {
        visible: !root.hasMediaAbove || (panel && panel.mediaExpanded)
        foreground: root.foreground
    }

    Row {
        width: parent.width
        spacing: Style.space(6)

        CursorSurface {
            activeFocusOnTab: true
            Accessible.role: Accessible.Button
            Accessible.name: panel.commandsExpanded ? "Collapse remote commands" : "Expand remote commands"
            Accessible.description: "Run commands configured on the selected device. Add or edit them in that device’s KDE Connect Run commands settings."
            Accessible.onPressAction: panel.toggleCommandsExpanded()
            Keys.onReturnPressed: panel.toggleCommandsExpanded()
            Keys.onEnterPressed: panel.toggleCommandsExpanded()
            Keys.onSpacePressed: panel.toggleCommandsExpanded()
            width: Math.max(1, parent.width - (panel.commandsExpanded ? refreshCmdBtn.implicitWidth + Style.space(6) : 0))
            implicitHeight: Math.max(32, headerRow.implicitHeight + Style.space(6))
            hasCursor: panel.cursorActive && panel.focusSection === "commands" && !panel.commandsExpanded
            radius: Style.cornerRadius
            foreground: root.foreground
            fill: Style.hoverFillFor(root.foreground, Commons.Color.accent)
            currentFill: Style.selectedFillFor(root.foreground, Commons.Color.accent)

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onEntered: {
                    panel.cursorActive = true
                    panel.focusSection = "commands"
                }
                onClicked: panel.toggleCommandsExpanded()
            }

            Row {
                id: headerRow
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(6)

                Text {
                    textFormat: Text.PlainText
                    text: panel.commandsExpanded ? "󰅀" : "󰅂"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                }

                PanelSectionHeader {
                    text: "REMOTE COMMANDS"
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        PanelActionButton {
            id: refreshCmdBtn
            visible: panel.commandsExpanded
            iconText: "󰑐"
            tooltipText: "Refresh commands"
            foreground: root.foreground
            fontFamily: root.fontFamily
            enabled: !!(root.service && !root.service.commandsLoading)
            onClicked: if (root.service && root.device) root.service.fetchRemoteCommands(root.device.id)
        }
    }

    Column {
        visible: panel.commandsExpanded
        width: parent.width
        spacing: Style.space(6)

        Text {
            textFormat: Text.PlainText
            visible: !!root.service && root.service.commandsLoading
            text: "Loading commands..."
            color: Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
        }

        Text {
            textFormat: Text.PlainText
            visible: !!root.service && !root.service.commandsLoading && (!root.service.remoteCommands || root.service.remoteCommands.length === 0)
            width: parent.width
            text: "No remote commands. Add them in the device’s KDE Connect Run commands settings."
            wrapMode: Text.Wrap
            color: Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
        }

        Repeater {
            model: root.service ? root.service.remoteCommands : []
            delegate: CursorSurface {
                id: cmdSurface
                required property var modelData
                required property int index

                width: parent.width
                implicitHeight: cmdRow.implicitHeight + Style.space(8)
                hasCursor: panel.cursorActive && panel.focusSection === "commands" && panel.commandsExpanded && panel.commandSelectedIndex === index
                foreground: root.foreground
                fill: Style.hoverFillFor(root.foreground, Commons.Color.accent)
                currentFill: Style.selectedFillFor(root.foreground, Commons.Color.accent)
                function run() { if (root.service && root.device && modelData) root.service.executeRemoteCommand(root.device.id, modelData.key) }
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: "Run remote command " + (modelData ? modelData.name : "")
                Accessible.onPressAction: run()
                Keys.onReturnPressed: run()
                Keys.onSpacePressed: run()

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                        panel.cursorActive = true
                        panel.focusSection = "commands"
                        panel.commandSelectedIndex = cmdSurface.index
                    }
                    onClicked: cmdSurface.run()
                }

                Row {
                    id: cmdRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Style.space(8)
                    anchors.rightMargin: Style.space(8)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)

                    Text {
                        textFormat: Text.PlainText
                        text: "󰘳"
                        color: Qt.darker(root.foreground, 1.4)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        textFormat: Text.PlainText
                        id: cmdBtnText
                        text: cmdSurface.modelData ? cmdSurface.modelData.name : ""
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        elide: Text.ElideRight
                        width: Math.max(1, parent.width - Style.space(20))
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
