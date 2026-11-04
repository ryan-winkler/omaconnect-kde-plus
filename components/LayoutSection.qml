pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons

Column {
    id: root
    required property var panel
    required property string sectionId
    readonly property var entry: panel.sectionCatalog.entry(sectionId)
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
        palette.highlight: Commons.Color.accent
        palette.highlightedText: surfaceColor
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
            text: root.entry ? root.entry.label : root.sectionId
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
            text: "Status: " + root.panel.layoutMessage
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
            model: ["Show", "Hide", "When available", "When unavailable"]
            readonly property var policies: ["show", "hide", "available", "unavailable"]
            currentIndex: policies.indexOf(root.policy)
            displayText: "Visibility: " + currentText
            Accessible.name: "Visibility for " + (root.entry ? root.entry.label : root.sectionId)
            Accessible.description: locked ? root.panel.layoutMessage : "Saved display policy. Checking data matches neither availability condition."
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
            model: root.panel.sectionCatalog.order.map(function(id, index) { return "Position " + (index + 1) })
            currentIndex: root.panel.sectionCatalog.order.indexOf(root.sectionId)
            displayText: "Move to: " + currentText
            Accessible.name: "Position for " + (root.entry ? root.entry.label : root.sectionId)
            Accessible.description: locked ? root.panel.layoutMessage : "Move this section to a saved position. Hidden sections keep their positions."
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
        text: (root.entry ? root.entry.label + ": " : "") + root.panel.sectionAvailabilityText(root.sectionId)
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
    }
}
