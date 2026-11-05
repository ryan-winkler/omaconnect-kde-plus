pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "../ActionCatalog.js" as Actions
import "../i18n" as Locale

Column {
    id: root

    property bool showSectionHeader: true
    required property var panel

    width: parent ? parent.width : 0
    spacing: Style.space(8)
    visible: !!(panel && panel.availableActions && panel.availableActions.length > 0)

    readonly property var bar: panel ? panel.bar : null
    readonly property var service: panel ? panel.service : null
    readonly property var device: panel ? panel.device : null
    readonly property color foreground: bar ? bar.foreground : "#ffffff"
    readonly property string fontFamily: bar ? bar.fontFamily : "sans-serif"
    readonly property var blockedActions: panel && panel.availableActions ? panel.availableActions.filter(function(id) { return !root.actionReady(id); }) : []

    function actionReady(id) {
        return (id === "file" && service && service.fileBusy)
            || (id === "browse-files" && Actions.browsePending(service))
            || Actions.ready(id,device,service)
    }

    PanelSeparator { visible: root.showSectionHeader; foreground: root.foreground }

    PanelSectionHeader {
        visible: root.showSectionHeader
        text: {
            var type = root.device ? root.device.type : ""
            return Locale.Strings.t("actions.heading." + type, Locale.Strings.t("actions.heading"))
        }
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
                readonly property bool stopSubmitting: modelData === "file" && !!root.service && root.service.fileBusy
                readonly property bool cancelBrowse: modelData === "browse-files" && Actions.browsePending(root.service)
                readonly property string actionName: stopSubmitting ? Locale.Strings.t("actions.stopSubmitting")
                    : cancelBrowse ? Locale.Strings.t("phoneFiles.cancelBrowse")
                    : Locale.Strings.t(Actions.actionLabelKey(modelData, root.device))
                readonly property string actionTooltip: stopSubmitting ? Locale.Strings.t("actions.cancelSubmission")
                    : cancelBrowse ? root.service.phoneFilesMessage
                    : catalogEntry ? Locale.Strings.t(catalogEntry.descriptionKey)
                        + (root.actionReady(modelData) ? "" : "\n" + Locale.Strings.t(Actions.availabilityKey(modelData, root.device, root.service))) : modelData
                readonly property string actionIcon: stopSubmitting || cancelBrowse ? "󰅖" : catalogEntry ? catalogEntry.icon : ""

                objectName: "quick-action-" + modelData
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
                selected: (modelData === "ping" && panel.activeComposer === "ping") || (modelData === "text" && panel.activeComposer === "text") || stopSubmitting || cancelBrowse
                foreground: root.foreground
                enabled: root.actionReady(modelData)
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
    Text {
        objectName: "quick-share-launch-status"
        width: parent.width
        text: root.service ? (root.service.quickShareMessage || "") : ""
        visible: text !== ""
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }
    Text {
        width: parent.width
        visible: root.blockedActions.length > 0
        text: root.blockedActions.length > 0 ? Locale.Strings.t(Actions.availabilityKey(root.blockedActions[0],root.device,root.service))
            + (root.blockedActions.length > 1 ? " " + Locale.Strings.format("actions.otherUnavailable", [
                root.blockedActions.slice(1).map(function(id) { return Locale.Strings.t(Actions.entry(id).labelKey) }).join(", ")
            ]) : "") : ""
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
    }
    Text {
        objectName: "native-toolbar-launch-status"
        width: parent.width
        visible: text !== "" && !root.panel.getSetting("showNativeFeatures", true)
        text: root.service ? root.service.nativeAppMessage || "" : ""
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        Accessible.role: Accessible.StaticText
        Accessible.name: text
    }
}
