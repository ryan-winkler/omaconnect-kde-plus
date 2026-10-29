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
            delegate: Button {
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

                text: actionName
                iconText: actionIcon
                tooltipText: actionTooltip
                Accessible.role: Accessible.Button
                Accessible.name: actionName
                Accessible.description: actionTooltip
                Accessible.onPressAction: if (enabled) clicked()
                focusable: true
                fontFamily: root.fontFamily
                fontSize: Style.font.bodySmall
                iconSize: Style.font.caption
                hasCursor: panel.cursorActive && panel.focusSection === "actions" && panel.actionSelectedIndex === index
                selected: (modelData === "ping" && panel.activeComposer === "ping") || (modelData === "text" && panel.activeComposer === "text") || (modelData === "file" && !!(root.service && root.service.fileBusy))
                foreground: root.foreground
                enabled: !root.service || (modelData === "file" ? true : (root.service.actionState !== "running"))
                onHovered: function(isHovered) {
                    if (isHovered) {
                        panel.cursorActive = true
                        panel.focusSection = "actions"
                        panel.actionSelectedIndex = index
                    }
                }
                onClicked: if (enabled) panel.triggerAction(modelData)
            }
        }
    }
}
