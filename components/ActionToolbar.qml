pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "../ActionCatalog.js" as Actions

Column {
    id: root

    required property var panel

    width: parent ? parent.width : 0
    spacing: Style.space(8)
    visible: !!(panel && panel.device && panel.device.paired && panel.device.reachable)

    readonly property var bar: panel ? panel.bar : null
    readonly property var service: panel ? panel.service : null
    readonly property var device: panel ? panel.device : null
    readonly property color foreground: bar ? bar.foreground : "#ffffff"
    readonly property string fontFamily: bar ? bar.fontFamily : "sans-serif"

    PanelSeparator { foreground: root.foreground }

    PanelSectionHeader {
        text: (root.device && root.device.type && root.device.type !== "unknown") ? (root.device.type.toUpperCase() + " ACTIONS") : "ACTIONS"
        foreground: root.foreground
        fontFamily: root.fontFamily
    }

    Flow {
        width: parent.width
        spacing: Style.space(6)
        Repeater {
            model: panel ? panel.availableActions : []
            delegate: CursorSurface {
                id: actionSurface
                required property string modelData
                required property int index
                readonly property var catalogEntry: Actions.entry(modelData)
                readonly property string actionName: modelData === "file" && root.service && root.service.fileBusy
                    ? "Stop submitting" : catalogEntry ? catalogEntry.label : modelData
                readonly property string actionTooltip: modelData === "file" && root.service && root.service.fileBusy
                    ? "Cancel the current file submission" : catalogEntry ? catalogEntry.description : modelData
                readonly property string actionIcon: modelData === "file" && root.service && root.service.fileBusy
                    ? "󰅖" : catalogEntry ? catalogEntry.icon : ""

                PanelToolTip {
                    visible: actionMouseArea.containsMouse
                    text: actionSurface.actionTooltip
                    fontFamily: root.fontFamily
                }

                implicitWidth: actionRowContent.implicitWidth + Style.space(16)
                implicitHeight: actionRowContent.implicitHeight + Style.space(8)
                radius: Style.cornerRadius
                hasCursor: panel.cursorActive && panel.focusSection === "actions" && panel.actionSelectedIndex === index
                current: (modelData === "ping" && panel.activeComposer === "ping") || (modelData === "text" && panel.activeComposer === "text") || (modelData === "file" && !!(root.service && root.service.fileBusy))
                foreground: root.foreground
                fill: Style.hoverFillFor(root.foreground, Commons.Color.accent)
                currentFill: Style.selectedFillFor(root.foreground, Commons.Color.accent)
                enabled: !root.service || (modelData === "file" ? true : (root.service.actionState !== "running"))

                MouseArea {
                    id: actionMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onEntered: {
                        panel.cursorActive = true
                        panel.focusSection = "actions"
                        panel.actionSelectedIndex = index
                    }
                    onClicked: panel.triggerAction(modelData)
                }

                Row {
                    id: actionRowContent
                    anchors.centerIn: parent
                    spacing: Style.space(6)

                    Text {
                        textFormat: Text.PlainText
                        visible: actionSurface.actionIcon !== ""
                        text: actionSurface.actionIcon
                        color: actionSurface.current ? Commons.Color.accent : root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        textFormat: Text.PlainText
                        id: actionBtnText
                        text: actionSurface.actionName
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: actionSurface.current
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
