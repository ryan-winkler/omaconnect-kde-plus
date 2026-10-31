pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit
import "../Appearance.js" as Appearance

Item {
    id: root
    property var options: []
    property string value: ""
    property string label: qsTr("Installed icons")
    property string triggerLabel: qsTr("Search installed icons…")
    property string placeholderText: qsTr("Search installed icons")
    property string emptyText: qsTr("No matching icons")
    property bool showLabel: true
    property color foreground: Commons.Color.popups.text
    property color background: Commons.Color.popups.background
    property color accent: Commons.Color.accent
    property string fontFamily: Style.font.family
    property int rowHeight: Math.max(44, Style.spacing.controlHeight)
    property int popupRowHeight: Math.max(44, Style.spacing.popupRowHeight)
    readonly property Item overlayItem: Controls.Overlay.overlay
    readonly property bool popupOpen: popup.opened
    readonly property var validOptions: (Array.isArray(options) ? options.slice(0, 1024) : []).filter(function(name) {
        return typeof name === "string" && /^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$/.test(name)
    })
    // Symbolic icons stay sharp at bar size and follow the theme, so list them first.
    readonly property string optionsKey: JSON.stringify(validOptions.filter(Appearance.symbolicThemeName)
        .concat(validOptions.filter(function(name) { return !Appearance.symbolicThemeName(name) })))
    readonly property var matchingOptions: {
        var query = search.text.trim().toLowerCase()
        return JSON.parse(optionsKey).filter(function(name) { return !query || name.toLowerCase().indexOf(query) !== -1 })
    }
    signal changed(string value)
    implicitWidth: Style.spacing.searchableDropdownWidth
    implicitHeight: trigger.y + trigger.height

    function open() { if (enabled) popup.open() }
    function close() { if (popup) popup.close() }
    function toggle() { popup.opened ? close() : open() }
    function choose(index) {
        if (!enabled || !popup.opened || index < 0 || index >= matchingOptions.length) return
        changed(matchingOptions[index])
        close()
    }
    onMatchingOptionsChanged: if (results) results.currentIndex = matchingOptions.length ? 0 : -1
    onOptionsKeyChanged: if (popup) popup.close()
    onEnabledChanged: if (!enabled) close()
    onVisibleChanged: if (!visible) close()

    Text {
        id: caption
        width: parent.width
        visible: root.showLabel && root.label !== ""
        text: root.label
        textFormat: Text.PlainText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.Wrap
    }
    Controls.Button {
        id: trigger
        objectName: "installed-icon-trigger"
        y: caption.visible ? caption.height + Style.spacing.labelGap : 0
        width: parent.width
        height: root.rowHeight
        padding: Style.spacing.controlPaddingX
        focusPolicy: Qt.StrongFocus
        Accessible.name: root.label || qsTr("Installed icons")
        Accessible.description: root.value ? qsTr("Selected icon: ") + root.value : root.triggerLabel
        Accessible.onPressAction: if (enabled) root.toggle()
        onClicked: root.toggle()
        Keys.onDownPressed: root.open()
        Keys.onReturnPressed: root.toggle()
        Keys.onEnterPressed: root.toggle()
        background: Kit.BorderSurface {
            color: Style.controlFill(trigger.activeFocus, trigger.hovered, root.foreground, root.accent)
            radius: Style.cornerRadius
            borderSpec: Commons.Border.controlSpec(trigger.activeFocus ? "focus" : trigger.hovered ? "hover-cursor" : "normal", root.foreground, root.accent)
        }
        contentItem: Row {
            spacing: Style.spacing.controlGap
            AppearanceIcon {
                visible: root.value !== ""
                width: visible ? 20 : 0; height: 20
                anchors.verticalCenter: parent.verticalCenter
                icon: ({mode:"theme", value:root.value, render:"symbolic"})
                foreground: root.foreground
                Accessible.ignored: true
            }
            Text {
                width: parent.width - x - arrow.width - parent.spacing
                height: parent.height
                text: root.value || root.triggerLabel
                textFormat: Text.PlainText
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            Item {
                id: arrow
                width: 12; height: 8
                anchors.verticalCenter: parent.verticalCenter
                Accessible.ignored: true
                Rectangle {x:1;y:2;width:7;height:2;rotation:45;color:root.foreground}
                Rectangle {x:5;y:2;width:7;height:2;rotation:-45;color:root.foreground}
            }
        }
    }
    Controls.Popup {
        id: popup
        objectName: "installed-icon-popup"
        parent: root
        readonly property int margin: Style.space(8)
        width: Math.max(0, Math.min(root.width, root.overlayItem ? root.overlayItem.width - margin * 2 : root.width))
        height: Math.min(search.implicitHeight + padding * 2 + Style.space(8)
            + Math.max(1, Math.min(6, root.matchingOptions.length)) * root.popupRowHeight,
            root.overlayItem ? Math.max(0, root.overlayItem.height - margin * 2) : 340)
        function place() {
            if (!root.overlayItem) return
            var below = root.mapToItem(root.overlayItem, 0, root.height)
            var above = root.mapToItem(root.overlayItem, 0, 0)
            var preferredY = below.y
            if (below.y + height > root.overlayItem.height - margin && above.y - height >= margin)
                preferredY = above.y - height
            var overlayX = Math.max(margin, Math.min(below.x, root.overlayItem.width - width - margin))
            var overlayY = Math.max(margin, Math.min(preferredY, root.overlayItem.height - height - margin))
            var position = root.overlayItem.mapToItem(root, overlayX, overlayY)
            x = position.x
            y = position.y
        }
        onAboutToShow: place()
        onWidthChanged: if (opened) place()
        onHeightChanged: if (opened) place()
        Connections {
            target: root.overlayItem
            function onWidthChanged() { if (popup.opened) popup.place() }
            function onHeightChanged() { if (popup.opened) popup.place() }
        }
        padding: Style.space(8)
        focus: true
        closePolicy: Controls.Popup.CloseOnEscape | Controls.Popup.CloseOnPressOutsideParent
        onOpened: {
            place()
            search.text = ""
            results.currentIndex = Math.max(0, root.matchingOptions.indexOf(root.value))
            Qt.callLater(function() { search.forceActiveFocus() })
        }
        onClosed: {
            search.text = ""
            if (root.visible && root.enabled) trigger.forceActiveFocus()
        }
        background: Kit.BorderSurface {
            color: root.background
            radius: Style.cornerRadius
            borderSpec: Commons.Border.surfaceSpec("popups", "border", Commons.Color.popups.border, Style.normalBorderWidth)
        }
        contentItem: Column {
            spacing: Style.space(8)
            Kit.TextField {
                id: search
                objectName: "installed-icon-search"
                width: parent.width
                maximumLength: 128
                placeholderText: root.placeholderText
                foreground: root.foreground
                accent: root.accent
                font.family: root.fontFamily
                Accessible.name: qsTr("Search installed icons")
                Keys.onDownPressed: if (results.count) { results.currentIndex = 0; results.forceActiveFocus() }
                Keys.onReturnPressed: root.choose(results.currentIndex)
                Keys.onEnterPressed: root.choose(results.currentIndex)
                Keys.onEscapePressed: root.close()
            }
            Item {
                width: parent.width
                height: Math.max(0, popup.availableHeight - search.height - parent.spacing)
                Text {
                    anchors.fill: parent
                    visible: !results.count
                    text: root.emptyText
                    textFormat: Text.PlainText
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    wrapMode: Text.Wrap
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }
                ListView {
                    id: results
                    objectName: "installed-icon-results"
                    anchors.fill: parent
                    model: root.matchingOptions
                    clip: true
                    reuseItems: true
                    cacheBuffer: 0
                    boundsBehavior: Flickable.StopAtBounds
                    keyNavigationEnabled: true
                    Accessible.role: Accessible.List
                    Accessible.name: qsTr("Matching installed icons")
                    Keys.onReturnPressed: root.choose(currentIndex)
                    Keys.onEnterPressed: root.choose(currentIndex)
                    Keys.onSpacePressed: root.choose(currentIndex)
                    Keys.onEscapePressed: root.close()
                    Keys.onUpPressed: function(event) {
                        if (currentIndex <= 0) search.forceActiveFocus()
                        else event.accepted = false
                    }
                    delegate: Controls.ItemDelegate {
                        id: option
                        required property string modelData
                        required property int index
                        objectName: "installed-icon-option-" + index
                        width: results.width
                        height: root.popupRowHeight
                        padding: Style.spacing.controlPaddingX
                        highlighted: results.currentIndex === index
                        Accessible.name: modelData
                        Accessible.description: qsTr("Choose this installed icon. Apply saves the choice.")
                        Accessible.selected: root.value === modelData
                        Accessible.onPressAction: if (enabled) root.choose(index)
                        onClicked: root.choose(index)
                        contentItem: Row {
                            spacing: Style.spacing.controlGap
                            AppearanceIcon {
                                objectName: "installed-icon-thumbnail"
                                width:24;height:24
                                anchors.verticalCenter: parent.verticalCenter
                                icon: ({mode:"theme",value:option.modelData,render:"symbolic"})
                                foreground: root.foreground
                                Accessible.ignored: true
                            }
                            Text {
                                width: parent.width - x
                                height: parent.height
                                text: option.modelData
                                textFormat: Text.PlainText
                                color: root.foreground
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.body
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                        }
                        background: Rectangle {
                            color: option.highlighted || option.hovered ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"
                        }
                    }
                }
            }
        }
    }
}
