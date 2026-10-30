pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit

// Daily routes only. Provider actions remain in their owning domain.
Column {
    id: root
    required property var panel
    readonly property Item focusItem: viewButton
    readonly property bool menuOpen: viewMenu.opened
    property real menuHeightLimit: 240
    readonly property var entries: ["Devices", "Send", "Activity", "Plus settings"]
    readonly property string draftSummary: panel.service && panel.service.selectionState === "draft" && panel.service.draftTarget
        ? "Draft for " + panel.service.draftTarget.peerName + " · Open Send to review." : ""
    readonly property string activitySummary: {
        var operations = panel.service ? panel.service.operations : []
        var pending = false
        for (var i = 0; i < operations.length; i++) {
            var state = operations[i].state
            if (["submission_failed", "submission_unknown", "cancellation_unconfirmed"].indexOf(state) >= 0) return "Needs review"
            if (["queued", "preparing", "submitting"].indexOf(state) >= 0) pending = true
        }
        return pending ? "In progress" : operations.length ? "Submission recorded · delivery unknown" : ""
    }
    spacing: Style.space(4)
    objectName: "daily-navigation"

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

    Row {
        width: parent.width
        spacing: Style.space(4)
        Kit.Button {
            id: viewButton
            objectName: "daily-view-menu"
            width: Math.max(0, parent.width - settingsButton.width - parent.spacing
                - (sendShortcut.visible ? sendShortcut.width + parent.spacing : 0)
                - (activityShortcut.visible ? activityShortcut.width + parent.spacing : 0))
            implicitHeight: Math.max(44, Style.spacing.controlHeight)
            text: "View: " + root.panel.currentView
            iconText: "󰅀"
            leftAlign: true
            fontSize: Style.font.bodySmall
            foreground: Commons.Color.popups.text
            focusable: true
            tooltipText: "Choose Devices, Send, Activity or Plus settings."
            Accessible.role: Accessible.Button
            Accessible.name: "Current view: " + root.panel.currentView + ". Choose a view"
            Accessible.description: "Opens the daily view menu. Use arrows to choose, Enter to open, or Escape to return."
            Accessible.onPressAction: clicked()
            onClicked: viewMenu.opened ? viewMenu.close() : viewMenu.open()
            Keys.onDownPressed: viewMenu.open()
            Keys.onEscapePressed: root.panel.close()
        }
        Kit.Button {
            id: sendShortcut
            objectName: "daily-send-shortcut"
            visible: root.panel.getSetting("showSendShortcut", false) === true
            text: "Send"
            implicitHeight: viewButton.implicitHeight
            fontSize: Style.font.bodySmall
            foreground: Commons.Color.popups.text
            focusable: true
            tooltipText: "Review files or text for the selected device."
            Accessible.role: Accessible.Button
            Accessible.name: "Open Send"
            Accessible.onPressAction: clicked()
            onClicked: root.choose("Send")
        }
        Kit.Button {
            id: activityShortcut
            objectName: "daily-activity-shortcut"
            visible: root.panel.getSetting("showActivityShortcut", false) === true
            text: "Activity"
            implicitHeight: viewButton.implicitHeight
            fontSize: Style.font.bodySmall
            foreground: Commons.Color.popups.text
            focusable: true
            tooltipText: "Review KDE submission results. Delivery remains unknown."
            Accessible.role: Accessible.Button
            Accessible.name: "Open Activity"
            Accessible.onPressAction: clicked()
            onClicked: root.choose("Activity")
        }
        Kit.PanelActionButton {
            id: settingsButton
            objectName: "daily-plus-settings"
            size: viewButton.implicitHeight
            iconText: "󰒓"
            foreground: Commons.Color.popups.text
            focusable: true
            tooltipText: "Plus settings: appearance, connections and device features."
            Accessible.role: Accessible.Button
            Accessible.name: "Open Plus settings"
            Accessible.onPressAction: clicked()
            onClicked: root.panel.openSettings()
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
        text: "Activity: " + root.activitySummary
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
        closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutside
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
                        text: modelData
                        leftAlign: true
                        selected: root.panel.currentView === modelData
                        foreground: Commons.Color.popups.text
                        focusable: true
                        Accessible.role: Accessible.MenuItem
                        Accessible.name: text + (selected ? ", current view" : "")
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
