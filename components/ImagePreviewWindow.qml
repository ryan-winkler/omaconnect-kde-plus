pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import qs.Commons
import qs.Commons as Commons
import qs.Ui as Kit
import "../i18n" as Locale

// The service owns the captured recipient and policy. Browsing emits no send.
Window {
    id: root
    LayoutMirroring.enabled: Commons.I18n.rightToLeft
    LayoutMirroring.childrenInherit: true
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

    title: Locale.Strings.t("imagePreviewWindow.omaconnectKdePlusChooseAnImage")
    objectName: "image-preview-window"
    transientParent: null
    flags: Qt.Window
    width: 760
    height: 720
    minimumWidth: 520
    minimumHeight: 560
    color: Qt.rgba(Commons.Color.popups.background.r, Commons.Color.popups.background.g, Commons.Color.popups.background.b, 1)
    visible: previewActive
    property var noticeSurfaceService: null
    function syncTaskNoticeSurface() {
        if (noticeSurfaceService && noticeSurfaceService !== service && typeof noticeSurfaceService.setTaskNoticeSurfaceVisible === "function")
            noticeSurfaceService.setTaskNoticeSurfaceVisible(root, "preview", false)
        noticeSurfaceService = service
        if (service && typeof service.setTaskNoticeSurfaceVisible === "function")
            service.setTaskNoticeSurfaceVisible(root, "preview", visible)
    }
    onServiceChanged: syncTaskNoticeSurface()
    onVisibleChanged: syncTaskNoticeSurface()
    Component.onDestruction: if (noticeSurfaceService && typeof noticeSurfaceService.setTaskNoticeSurfaceVisible === "function")
        noticeSurfaceService.setTaskNoticeSurfaceVisible(root, "preview", false)

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
        sequence: Commons.I18n.rightToLeft ? "Alt+Right" : "Alt+Left"
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
            text: Locale.Strings.t("imagePreviewWindow.chooseAnImage")
            textFormat: Text.PlainText
            color: Commons.Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.title
            font.bold: true
        }
        Text {
            objectName: "image-preview-recipient"
            width: parent.width
            text: Locale.Strings.format("files.previewRecipient", [root.target ? root.target.peerName : Locale.Strings.t("imagePreviewWindow.noRecipientSelected")])
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
            text: root.sendsImmediately ? Locale.Strings.t("imagePreviewWindow.chooseTheImageThenSelectSend")
                : Locale.Strings.t("imagePreviewWindow.chooseAnImageToReviewBefore")
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
            placeholderText: Locale.Strings.t("imagePreviewWindow.searchImages")
            Accessible.name: Locale.Strings.t("imagePreviewWindow.searchImages")
            foreground: Commons.Color.popups.text
            maximumLength: 256
        }
        Row {
            width: parent.width
            spacing: Style.space(8)
            SettingsButton {
                id: previous
                objectName: "image-preview-previous"
                text: Locale.Strings.t("imagePreviewWindow.previous")
                focusable: true
                foreground: Commons.Color.popups.text
                enabled: root.selectedIndex > 0 && root.matches.length > 0
                onClicked: root.move(-1)
            }
            Text {
                width: Math.max(1, parent.width - previous.width - next.width - parent.spacing * 2)
                height: previous.height
                text: root.matches.length ? Locale.Strings.format("files.imagePosition", [Commons.I18n.formatNumber(root.selectedIndex + 1), Commons.I18n.formatNumber(root.matches.length)]) : Locale.Strings.t("imagePreviewWindow.noMatchingImages")
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
                text: Locale.Strings.t("imagePreviewWindow.next")
                focusable: true
                foreground: Commons.Color.popups.text
                enabled: root.selectedIndex < root.matches.length - 1
                onClicked: root.move(1)
            }
        }
        Text {
            width: parent.width
            text: root.selectedName || Locale.Strings.t("imagePreviewWindow.tryAnotherNameOrUseBack")
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
        Accessible.name: Locale.Strings.t("imagePreviewWindow.imagePreview")
        Accessible.description: Locale.Strings.t("imagePreviewWindow.useLeftAndRightToChoose")
        Keys.onPressed: function(event) {
            if (event.modifiers !== Qt.NoModifier) return
            var key = Util.readingKey(event)
            if (key !== Qt.Key_Left && key !== Qt.Key_Right) return
            root.move(key === Qt.Key_Left ? -1 : 1)
            event.accepted = true
        }
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
            text: !root.selectedPath ? Locale.Strings.t("imagePreviewWindow.noMatchingImagesTryAnotherName")
                : image.status === Image.Error ? Locale.Strings.t("imagePreviewWindow.thisImageCannotBePreviewedUse")
                : Locale.Strings.t("imagePreviewWindow.loadingPreview")
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
                text: Locale.Strings.t("imagePreviewWindow.backToFiles")
                focusable: true
                foreground: Commons.Color.popups.text
                enabled: root.previewActive
                onClicked: if (root.previewActive) root.backRequested()
            }
            SettingsButton {
                objectName: "image-preview-cancel"
                text: Locale.Strings.t("common.cancel")
                focusable: true
                foreground: Commons.Color.popups.text
                enabled: root.previewActive
                onClicked: if (root.previewActive) root.cancelRequested()
            }
            SettingsButton {
                objectName: "image-preview-confirm"
                text: root.sendsImmediately ? Locale.Strings.t("imagePreviewWindow.sendImage") : Locale.Strings.t("imagePreviewWindow.reviewImage")
                focusable: true
                foreground: Commons.Color.popups.text
                enabled: root.canConfirm
                selected: root.canConfirm
                onClicked: root.confirm()
            }
        }
    }
}
