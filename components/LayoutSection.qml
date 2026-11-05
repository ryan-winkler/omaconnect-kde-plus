pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import "../i18n" as Locale

Column {
    id: root
    required property var panel
    required property string sectionId
    readonly property var entry: panel.sectionCatalog.entry(sectionId)
    readonly property string sectionTitle: panel.sectionCatalog.title(sectionId)
    readonly property bool expanded: panel.sectionExpanded(sectionId) || (sectionId === "actions" && panel.activeComposer !== "none")
    readonly property string policy: panel.sectionPolicy(sectionId)
    readonly property string availability: panel.sectionAvailability(sectionId)
    default property alias contentData: body.data
    objectName: "layout-section-" + sectionId
    width: parent ? parent.width : 0
    spacing: Style.space(6)
    visible: panel.editingLayout || panel.sectionVisible(sectionId)

    component LayoutChoice: Controls.ComboBox {
        id: choice
        property var optionLabel
        readonly property bool locked: root.panel.layoutSaveBusy
        // Keep the focused control in the Tab chain while its saved value is pending.
        enabled: !locked || activeFocus
        opacity: locked ? 0.65 : 1
        Keys.onPressed: function(event) {
            if (locked && [Qt.Key_Space, Qt.Key_Return, Qt.Key_Enter, Qt.Key_Up, Qt.Key_Down,
                Qt.Key_Left, Qt.Key_Right, Qt.Key_Home, Qt.Key_End, Qt.Key_PageUp, Qt.Key_PageDown].indexOf(event.key) >= 0) event.accepted = true
        }
        MouseArea { anchors.fill: parent; enabled: choice.locked; cursorShape: Qt.WaitCursor }
        Connections {
            target: choice.popup
            function onVisibleChanged() { if (choice.locked && choice.popup.visible) choice.popup.close() }
        }
        readonly property color surfaceColor: Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1)
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        palette.text: Commons.Color.popups.text
        palette.buttonText: Commons.Color.popups.text
        palette.base: surfaceColor
        palette.button: surfaceColor
        palette.window: surfaceColor
        palette.windowText: Commons.Color.popups.text
        palette.highlight: Commons.Color.popups.text
        palette.highlightedText: surfaceColor
        delegate: Controls.ItemDelegate {
            required property int index
            width: choice.width
            text: choice.optionLabel(index)
            font: choice.font
            palette: choice.palette
            highlighted: choice.highlightedIndex === index
        }
        Accessible.role: Accessible.ComboBox
        Accessible.onPressAction: {
            if (!enabled || locked) return
            forceActiveFocus()
            popup.visible ? popup.close() : popup.open()
        }
    }
    Column {
        width: parent.width
        visible: root.panel.editingLayout
        spacing: Style.space(4)
        Text {
            width: parent.width
            text: root.sectionTitle
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.body
            font.bold: true
        }
        Text {
            width: parent.width
            text: root.panel.sectionAvailabilityText(root.sectionId)
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
        }
        Text {
            objectName: "section-layout-status-" + root.sectionId
            width: parent.width
            visible: root.panel.layoutMessage !== "" &&
                (root.panel.layoutFeedbackSectionId === root.sectionId ||
                 (root.panel.layoutSaveBusy && (visibilityControl.activeFocus || positionControl.activeFocus)))
            text: Locale.Strings.t("layout.status").arg(root.panel.layoutMessage)
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }
        LayoutChoice {
            id: visibilityControl
            objectName: "section-visibility-" + root.sectionId
            width: parent.width
            height: Math.max(44, implicitHeight)
            visible: !!root.entry && !!root.entry.visibilityKey
            readonly property var policies: ["show", "hide", "available", "unavailable"]
            model: policies
            optionLabel: function(index) {
                return index >= 0 ? Locale.Strings.t("layout.policy." + policies[index]) : ""
            }
            currentIndex: policies.indexOf(root.policy)
            displayText: Locale.Strings.t("layout.visibility").arg(optionLabel(currentIndex))
            Accessible.name: Locale.Strings.t("layout.visibilityFor").arg(root.sectionTitle)
            Accessible.description: locked ? root.panel.layoutMessage : Locale.Strings.t("layout.visibilityHelp")
            onActivated: function(index) {
                root.panel.saveSectionPolicy(root.sectionId, policies[index])
                currentIndex = Qt.binding(function() { return visibilityControl.policies.indexOf(root.policy) })
            }
        }
        LayoutChoice {
            id: positionControl
            objectName: "section-position-" + root.sectionId
            width: parent.width
            height: Math.max(44, implicitHeight)
            model: root.panel.sectionCatalog.order.length
            optionLabel: function(index) {
                return index >= 0 ? Locale.Strings.t("layout.position").arg(Commons.I18n.formatNumber(index + 1)) : ""
            }
            currentIndex: root.panel.sectionCatalog.order.indexOf(root.sectionId)
            displayText: Locale.Strings.t("layout.moveTo").arg(optionLabel(currentIndex))
            Accessible.name: Locale.Strings.t("layout.positionFor").arg(root.sectionTitle)
            Accessible.description: locked ? root.panel.layoutMessage : Locale.Strings.t("layout.positionHelp")
            onActivated: function(index) {
                root.panel.moveSectionTo(root.sectionId, index)
                currentIndex = Qt.binding(function() { return root.panel.sectionCatalog.order.indexOf(root.sectionId) })
            }
        }
    }
    Column {
        id: body
        width: parent.width
        visible: root.sectionId === "devices" || (!root.panel.editingLayout && root.availability === "available")
    }
    Text {
        width: parent.width
        visible: !root.panel.editingLayout && root.sectionId !== "devices" && root.availability !== "available"
        text: root.entry ? Locale.Strings.t("layout.sectionStatus").arg(root.sectionTitle).arg(root.panel.sectionAvailabilityText(root.sectionId))
            : root.panel.sectionAvailabilityText(root.sectionId)
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
}
