pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit

// The service owns the captured recipient and policy. Browsing emits no send.
Window {
    id: root
    required property var service
    property bool activeForOwner: true
    readonly property bool previewActive: activeForOwner && !!(service && service.selectionState === "preview")
    readonly property var candidates: service && Array.isArray(service.previewCandidates) ? service.previewCandidates : []
    readonly property var target: service ? service.draftTarget : null
    readonly property bool sendsImmediately: !!(service && service.previewSubmits === true)
    readonly property var matches: {
        var query = search.text.trim().toLowerCase()
        return candidates.filter(function(path) {
            return typeof path === "string" && path.charAt(0) === "/"
                && (!query || path.toLowerCase().indexOf(query) !== -1)
        })
    }
    property int selectedIndex: 0
    readonly property string selectedPath: previewActive && matches.length ? matches[Math.min(selectedIndex, matches.length - 1)] : ""
    readonly property string selectedName: selectedPath.split("/").pop() || ""
    readonly property bool canConfirm: previewActive && selectedPath !== "" && image.status === Image.Ready
        && String(image.source) === String(Qt.resolvedUrl(Util.fileUrl(selectedPath)))
    signal backRequested()
    signal cancelRequested()
    signal confirmRequested(string path)

    title: "Omaconnect KDE Plus — Choose an image"
    objectName: "image-preview-window"
    transientParent: null
    flags: Qt.Window
    width: 760
    height: 720
    minimumWidth: 520
    minimumHeight: 560
    color: Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1)
    visible: previewActive

    onMatchesChanged: selectedIndex = 0
    onPreviewActiveChanged: if (previewActive) Qt.callLater(function() {
        if (!root.previewActive) return
        search.text = ""
        root.selectedIndex = 0
        root.raise()
        root.requestActivate()
        search.forceActiveFocus()
    })
    // Keep the service-driven visibility binding, including after WM Close.
    onClosing: function(event) {
        event.accepted = false
        if (root.previewActive) root.cancelRequested()
    }
    function move(delta) {
        if (!matches.length) return
        selectedIndex = Math.max(0, Math.min(matches.length - 1, selectedIndex + delta))
    }
    function confirm() {
        if (canConfirm && candidates.indexOf(selectedPath) !== -1) confirmRequested(selectedPath)
    }
    Shortcut {
        objectName: "image-preview-escape"
        sequence: "Escape"
        context: Qt.WindowShortcut
        enabled: root.previewActive
        onActivated: root.cancelRequested()
    }
    Shortcut {
        sequence: "Alt+Left"
        context: Qt.WindowShortcut
        enabled: root.previewActive
        onActivated: root.backRequested()
    }

    Column {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Style.spacing.panelPadding
        spacing: Style.space(10)
        Text {
            width: parent.width
            text: "Choose an image"
            textFormat: Text.PlainText
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
        }
        Text {
            objectName: "image-preview-recipient"
            width: parent.width
            text: "To: \u2068" + (root.target ? root.target.peerName : "No recipient selected") + "\u2069"
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 2
            elide: Text.ElideRight
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.body
        }
        Text {
            objectName: "image-preview-instruction"
            width: parent.width
            text: root.sendsImmediately ? "Choose the image, then select Send image."
                : "Choose an image to review before sending."
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
        }
        Kit.TextField {
            id: search
            objectName: "image-preview-search"
            width: parent.width
            placeholderText: "Search images"
            Accessible.name: "Search images"
            foreground: Commons.Color.popups.text
            maximumLength: 256
        }
        Row {
            width: parent.width
            spacing: Style.space(8)
            SettingsButton {
                id: previous
                objectName: "image-preview-previous"
                text: "Previous"
                focusable: true
                foreground: Commons.Color.popups.text
                enabled: root.selectedIndex > 0 && root.matches.length > 0
                onClicked: root.move(-1)
            }
            Text {
                width: Math.max(1, parent.width - previous.width - next.width - parent.spacing * 2)
                height: previous.height
                text: root.matches.length ? (root.selectedIndex + 1) + " of " + root.matches.length : "No matching images"
                textFormat: Text.PlainText
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                color: Commons.Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.font.bodySmall
            }
            SettingsButton {
                id: next
                objectName: "image-preview-next"
                text: "Next"
                focusable: true
                foreground: Commons.Color.popups.text
                enabled: root.selectedIndex < root.matches.length - 1
                onClicked: root.move(1)
            }
        }
        Text {
            width: parent.width
            text: root.selectedName || "Try another name or use Back to files."
            textFormat: Text.PlainText
            elide: Text.ElideMiddle
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.body
        }
        Text {
            width: parent.width
            text: root.selectedPath
            textFormat: Text.PlainText
            elide: Text.ElideMiddle
            color: Commons.Color.popups.text
            opacity: 0.7
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
        }
    }
    Rectangle {
        id: preview
        anchors.top: header.bottom
        anchors.bottom: footer.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Style.spacing.panelPadding
        color: Commons.Color.background
        border.color: Commons.Color.popups.border
        activeFocusOnTab: true
        Accessible.role: Accessible.Pane
        Accessible.name: "Image preview"
        Accessible.description: "Use Left and Right to choose a different image."
        Keys.onLeftPressed: root.move(-1)
        Keys.onRightPressed: root.move(1)
        Image {
            id: image
            objectName: "image-preview-image"
            anchors.fill: parent
            anchors.margins: Style.space(8)
            source: root.visible && root.selectedPath ? Util.fileUrl(root.selectedPath) : ""
            sourceSize.width: Math.min(1600, Math.max(1, Math.round(width * Screen.devicePixelRatio)))
            sourceSize.height: Math.min(1200, Math.max(1, Math.round(height * Screen.devicePixelRatio)))
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
            Accessible.role: Accessible.Graphic
            Accessible.name: root.selectedName
        }
        Text {
            objectName: "image-preview-status"
            anchors.fill: parent
            anchors.margins: Style.space(16)
            visible: image.status !== Image.Ready
            text: !root.selectedPath ? "No matching images. Try another name or use Back to files."
                : image.status === Image.Error ? "This image cannot be previewed. Use Back to files to choose another file."
                : "Loading preview…"
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.body
        }
    }
    Column {
        id: footer
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Style.spacing.panelPadding
        spacing: Style.space(10)
        Text {
            objectName: "image-preview-error"
            width: parent.width
            visible: text !== ""
            text: root.service ? root.service.selectionError : ""
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: Commons.Color.urgent
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
        }
        Flow {
            width: parent.width
            spacing: Style.space(8)
            SettingsButton {
                objectName: "image-preview-back"
                text: "Back to files"
                focusable: true
                foreground: Commons.Color.popups.text
                enabled: root.previewActive
                onClicked: if (root.previewActive) root.backRequested()
            }
            SettingsButton {
                objectName: "image-preview-cancel"
                text: "Cancel"
                focusable: true
                foreground: Commons.Color.popups.text
                enabled: root.previewActive
                onClicked: if (root.previewActive) root.cancelRequested()
            }
            SettingsButton {
                objectName: "image-preview-confirm"
                text: root.sendsImmediately ? "Send image" : "Review image"
                focusable: true
                foreground: Commons.Color.popups.text
                enabled: root.canConfirm
                selected: root.canConfirm
                onClicked: root.confirm()
            }
        }
    }
}
