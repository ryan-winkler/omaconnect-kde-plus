pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit
import "../i18n" as Locale

// Daily routes only. Provider actions remain in their owning domain.
Column {
    id: root
    required property var panel
    readonly property Item focusItem: viewButton
    readonly property Item layoutShortcut: editLayoutShortcut
    readonly property bool menuOpen: viewMenu.opened
    property real menuHeightLimit: 240
    readonly property real utilityWidth: settingsButton.width + navigationControls.spacing
        + (editLayoutShortcut.visible ? editLayoutShortcut.width + navigationControls.spacing : 0)
    readonly property bool shortcutsWrapped: viewButton.implicitWidth + utilityWidth
        + (sendShortcut.visible ? sendShortcut.width + navigationControls.spacing : 0)
        + (activityShortcut.visible ? activityShortcut.width + navigationControls.spacing : 0) > width
    readonly property var entries: ["Devices", "Send", "Activity", "Plus settings"]
    readonly property var viewKeys: ({
        "Devices": "navigation.devices",
        "Send": "navigation.send",
        "Activity": "navigation.activity",
        "Plus settings": "navigation.settings"
    })
    readonly property string draftSummary: panel.service && panel.service.selectionState === "draft" && panel.service.draftTarget
        ? Locale.Strings.t("navigation.draft").arg(panel.service.draftTarget.peerName) : ""
    readonly property string activitySummary: {
        var operations = panel.service ? panel.service.operations : []
        var pending = false
        var hasAccepted = false
        for (var i = 0; i < operations.length; i++) {
            var state = operations[i].state
            if (operations[i].accepted > 0) hasAccepted = true
            if (["submission_failed", "submission_unknown", "cancellation_unconfirmed"].indexOf(state) >= 0) return Locale.Strings.t("navigation.needsReview")
            if (["queued", "preparing", "submitting"].indexOf(state) >= 0) pending = true
        }
        return pending ? Locale.Strings.t("navigation.pending")
            : hasAccepted ? Locale.Strings.t("navigation.submissionRecorded") : ""
    }
    spacing: Style.space(4)
    objectName: "daily-navigation"

    Kit.Button {
        objectName: "cancel-pending-files"
        width: parent.width
        implicitHeight: Math.max(44, Style.space(44))
        visible: !!root.panel.service && (root.panel.service.operationBusy || root.panel.service.selectionState === "choosing" || root.panel.service.selectionState === "preview" || root.panel.service.selectionCancelling === true)
        text: root.panel.service && (root.panel.service.selectionCancelling === true || (root.panel.service.operationBusy && root.panel.service.cancellationRequested === true))
            ? Locale.Strings.t("navigation.cancelling") : Locale.Strings.t("navigation.cancel")
        enabled: !!root.panel.service && root.panel.service.selectionCancelling !== true && (!root.panel.service.operationBusy || root.panel.service.cancellationRequested !== true)
        foreground: Commons.Color.popups.text
        focusable: true
        Accessible.role: Accessible.Button
        Accessible.onPressAction: if (enabled) clicked()
        Accessible.name: text
        Accessible.description: Locale.Strings.t("navigation.cancelHelp")
        onClicked: {
            if (root.panel.service.operationBusy) root.panel.service.cancelOperation()
            else root.panel.service.cancelDraft()
        }
    }

    function focusMenu(index) {
        var item = menuEntries.itemAt((index + entries.length) % entries.length)
        if (item) {
            item.forceActiveFocus()
            revealMenuItem(item)
        }
    }
    function revealMenuItem(item) {
        var flickable = menuScroll.contentItem
        if (!flickable || !("contentY" in flickable)) return
        var top = item.y, bottom = top + item.height
        if (top < flickable.contentY) flickable.contentY = top
        else if (bottom > flickable.contentY + menuScroll.availableHeight) flickable.contentY = bottom - menuScroll.availableHeight
    }
    function choose(value) {
        if (entries.indexOf(value) < 0) return
        viewMenu.close()
        if (value === "Plus settings") panel.openSettings()
        else {
            panel.currentView = value
            if (value === "Devices") Qt.callLater(function() { root.panel.focusTarget.forceActiveFocus() })
        }
    }
    function closeMenu() { viewMenu.close() }

    Flow {
        id: navigationControls
        objectName: "daily-navigation-controls"
        width: parent.width
        spacing: Style.space(4)
        Kit.Button {
            id: viewButton
            objectName: "daily-view-menu"
            width: Math.max(0, parent.width - root.utilityWidth
                - (!root.shortcutsWrapped && sendShortcut.visible ? sendShortcut.width + parent.spacing : 0)
                - (!root.shortcutsWrapped && activityShortcut.visible ? activityShortcut.width + parent.spacing : 0))
            implicitHeight: Math.max(44, Style.spacing.controlHeight)
            text: Locale.Strings.t("navigation.currentView").arg(Locale.Strings.t(root.viewKeys[root.panel.currentView]))
            iconText: "󰅀"
            leftAlign: true
            fontSize: Style.font.bodySmall
            foreground: Commons.Color.popups.text
            focusable: true
            tooltipText: Locale.Strings.t("navigation.choose")
            Accessible.role: Accessible.Button
            Accessible.name: Locale.Strings.t("navigation.currentViewAccessible").arg(Locale.Strings.t(root.viewKeys[root.panel.currentView]))
            Accessible.description: Locale.Strings.t("navigation.keyboardHelp")
            Accessible.onPressAction: clicked()
            onClicked: viewMenu.opened ? viewMenu.close() : viewMenu.open()
            Keys.onDownPressed: viewMenu.open()
            Keys.onEscapePressed: root.panel.close()
        }
        Kit.PanelActionButton {
            id: settingsButton
            objectName: "daily-plus-settings"
            size: viewButton.implicitHeight
            iconText: "󰒓"
            foreground: Commons.Color.popups.text
            focusable: true
            tooltipText: Locale.Strings.t("navigation.settingsHelp")
            Accessible.role: Accessible.Button
            Accessible.name: Locale.Strings.t("navigation.openSettings")
            Accessible.onPressAction: clicked()
            onClicked: root.panel.openSettings()
        }
        SettingsButton {
            id: editLayoutShortcut
            objectName: "daily-edit-layout"
            width: viewButton.implicitHeight
            height: viewButton.implicitHeight
            visible: root.panel.currentView === "Devices" && !root.panel.editingLayout
                && root.panel.getSetting("showEditLayoutShortcut", true) === true
            enabled: root.panel.sectionCatalog.ready
            bordered: false
            iconText: "󰏫"
            foreground: Commons.Color.popups.text
            focusable: true
            tooltipText: Locale.Strings.t("layout.edit")
            Accessible.name: Locale.Strings.t("layout.editDevices")
            onClicked: root.panel.setLayoutEditing(true)
        }
        Kit.Button {
            id: sendShortcut
            objectName: "daily-send-shortcut"
            visible: root.panel.getSetting("showSendShortcut", false) === true
            text: Locale.Strings.t("navigation.send")
            implicitHeight: viewButton.implicitHeight
            fontSize: Style.font.bodySmall
            foreground: Commons.Color.popups.text
            focusable: true
            tooltipText: Locale.Strings.t("navigation.sendHelp")
            Accessible.role: Accessible.Button
            Accessible.name: Locale.Strings.t("navigation.openSend")
            Accessible.onPressAction: clicked()
            onClicked: root.choose("Send")
        }
        Kit.Button {
            id: activityShortcut
            objectName: "daily-activity-shortcut"
            visible: root.panel.getSetting("showActivityShortcut", false) === true
            text: Locale.Strings.t("navigation.activity")
            implicitHeight: viewButton.implicitHeight
            fontSize: Style.font.bodySmall
            foreground: Commons.Color.popups.text
            focusable: true
            tooltipText: Locale.Strings.t("navigation.activityHelp")
            Accessible.role: Accessible.Button
            Accessible.name: Locale.Strings.t("navigation.openActivity")
            Accessible.onPressAction: clicked()
            onClicked: root.choose("Activity")
        }

    }
    Text {
        width: parent.width
        visible: root.draftSummary !== "" && root.panel.currentView !== "Send"
        text: root.draftSummary
        textFormat: Text.PlainText
        wrapMode: Text.WrapAnywhere
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        Accessible.name: text
    }
    Text {
        width: parent.width
        visible: root.activitySummary !== "" && root.panel.currentView !== "Activity"
        text: Locale.Strings.t("navigation.activitySummary").arg(root.activitySummary)
        textFormat: Text.PlainText
        wrapMode: Text.Wrap
        color: Commons.Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        Accessible.name: text
    }
    Controls.Popup {
        id: viewMenu
        objectName: "daily-view-popup"
        x: 0
        y: root.panel.getSetting("navigationAtTop", false) === true
            ? viewButton.height + Style.space(4) : -height - Style.space(4)
        width: Math.min(root.width, Style.space(280))
        padding: Style.space(4)
        height: Math.min(menuColumn.implicitHeight + topPadding + bottomPadding, Math.max(44, root.menuHeightLimit))
        focus: true
        closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutsideParent
        background: Kit.BorderSurface {
            color: Commons.Color.popups.background
            borderSpec: Border.surfaceSpec("popups", "border", Commons.Color.popups.border, Style.normalBorderWidth)
            radius: Style.cornerRadius
        }
        onOpened: root.focusMenu(root.entries.indexOf(root.panel.currentView))
        onClosed: if (root.panel.opened) viewButton.forceActiveFocus()
        contentItem: Controls.ScrollView {
            id: menuScroll
            clip: true
            contentWidth: availableWidth
            Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
            Controls.ScrollBar.vertical.policy: contentHeight > availableHeight ? Controls.ScrollBar.AlwaysOn : Controls.ScrollBar.AlwaysOff
            Column {
                id: menuColumn
                width: menuScroll.availableWidth
                spacing: Style.space(2)
                Repeater {
                    id: menuEntries
                    model: root.entries
                    delegate: Kit.Button {
                        required property string modelData
                        required property int index
                        objectName: "daily-route-" + index
                        width: parent.width
                        implicitHeight: Math.max(44, Style.spacing.controlHeight)
                        text: Locale.Strings.t(root.viewKeys[modelData])
                        leftAlign: true
                        selected: root.panel.currentView === modelData
                        foreground: Commons.Color.popups.text
                        focusable: true
                        Accessible.role: Accessible.MenuItem
                        Accessible.name: selected ? Locale.Strings.t("navigation.selectedRoute").arg(text) : text
                        Accessible.checkable: modelData !== "Plus settings"
                        Accessible.checked: selected
                        Accessible.onPressAction: clicked()
                        onClicked: root.choose(modelData)
                        onActiveFocusChanged: if (activeFocus) root.revealMenuItem(this)
                        Keys.onUpPressed: root.focusMenu(index - 1)
                        Keys.onDownPressed: root.focusMenu(index + 1)
                        Keys.onEscapePressed: viewMenu.close()
                    }
                }
            }
        }
    }
}
