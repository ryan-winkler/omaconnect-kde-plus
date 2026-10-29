pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import qs.Commons as Commons
import qs.Ui as Kit
import "../Appearance.js" as Appearance

// Browsing never changes a draft. Only a choice changes it; only Apply saves it.
Controls.Dialog {
    id: root
    required property var store
    property string deviceId: ""
    property string barDeviceId: ""
    property string barDeviceType: "phone"
    property string advertisedName: ""
    property string deviceType: "phone"
    property string fontFamily: Commons.Style.font.family
    property color foreground: Commons.Color.popups.text
    property var draft: Appearance.phone()
    property bool pendingApply: false
    property bool pendingImport: false
    property bool moreOptions: false
    readonly property bool deviceMode: deviceId !== ""
    readonly property string presetFont: Appearance.symbolFont(Qt.fontFamilies(),fontFamily)
    readonly property var resolvedDraft: {
        var resolved = draft.mode === "inherit" ? Appearance.typeIcon(deviceType)
            : draft.mode === "automatic" ? Appearance.deviceIcon(store ? store.snapshot : null,deviceMode ? deviceId : barDeviceId,deviceMode ? deviceType : barDeviceType) : draft;
        return store ? store.safeIcon(resolved) : resolved;
    }
    readonly property string choiceLabel: {
        if (draft.mode === "inherit") return qsTr("Automatic — use device type");
        if (draft.mode === "automatic") return qsTr("Follow selected device");
        if (draft.mode === "preset") return Appearance.presets.filter(function(entry) { return entry.value === root.draft.value; })[0].label;
        if (draft.mode === "theme") return qsTr("Installed icon: ") + String(draft.value || "");
        if (draft.mode === "glyph") return qsTr("Symbol: ") + String(draft.value || "");
        return qsTr("Local image");
    }
    signal cancelled()

    title: deviceMode ? qsTr("Device appearance") : qsTr("Bar appearance")
    modal: true
    width: Math.max(260,Math.min(480,parent ? parent.width - 24 : 480))
    padding: Commons.Style.spacing.panelPadding
    closePolicy: pendingApply ? Controls.Popup.NoAutoClose : Controls.Popup.CloseOnEscape
    anchors.centerIn: parent
    background: Kit.BorderSurface {
        color: Commons.Color.popups.background
        radius: Commons.Style.cornerRadius
        borderSpec: Commons.Border.surfaceSpec("popups","border",Commons.Color.popups.border,1)
    }
    header: Controls.Label {
        text: root.title
        textFormat: Text.PlainText
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Commons.Style.font.title
        font.bold: true
        padding: root.padding
    }

    function choose(entry) {
        draft = Appearance.normalizeIcon(entry,deviceMode);
        symbolField.text = draft.mode === "glyph" ? draft.value : "";
        fontField.text = draft.mode === "glyph" ? draft.font || "" : "";
        themeNameField.text = draft.mode === "theme" ? draft.value : "";
    }
    function prepare() {
        pendingApply = false;
        pendingImport = false;
        moreOptions = false;
        var saved = deviceMode ? (store ? store.deviceAppearance(deviceId) : {}) : {};
        choose(deviceMode ? saved.icon || {mode:"inherit"} : store ? store.snapshot.bar_icon : null);
        aliasField.text = saved.alias || "";
    }
    function openForBar(selectedId,selectedType) { barDeviceId = String(selectedId || ""); barDeviceType = String(selectedType || "phone"); deviceId = ""; prepare(); open(); }
    function openForDevice(id,name,type) { deviceId = String(id); advertisedName = String(name || ""); deviceType = String(type || "phone"); prepare(); open(); }
    function applyDraft() {
        if (!store || store.busy) return;
        pendingApply = deviceMode ? store.setDeviceAppearance(deviceId,aliasField.text,draft) : store.setBarIcon(draft);
    }
    onOpened: {
        if (store && store.themeIcons.length === 0) store.loadLibrary();
        automaticChoice.forceActiveFocus();
    }
    onDraftChanged: pendingImport = false
    onRejected: { pendingApply = false; pendingImport = false; cancelled(); }

    contentItem: Controls.ScrollView {
        clip: true
        implicitHeight: Math.max(160,Math.min(body.implicitHeight,root.parent ? root.parent.height - 180 : 560))
        contentWidth: availableWidth
        ColumnLayout {
            id: body
            width: parent.width
            spacing: 10
            Controls.Label {
                visible: root.deviceMode
                text: qsTr("Advertised name: ") + "\u2068" + root.advertisedName + "\u2069"
                textFormat: Text.PlainText
                color: root.foreground
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            Kit.TextField {
                id: aliasField
                visible: root.deviceMode
                Layout.fillWidth: true
                maximumLength: 160
                placeholderText: qsTr("Local alias (optional)")
                Accessible.name: qsTr("Local alias, up to 80 characters")
                selectByMouse: true
            }
            Controls.Label {
                visible: root.deviceMode && Array.from(aliasField.text).length > 80
                text: qsTr("Use at most 80 characters.")
                textFormat: Text.PlainText
                color: root.foreground
            }
            Kit.Button {
                id: automaticChoice
                Accessible.role: Accessible.Button
                Accessible.name: text
                Accessible.checkable: true
                Accessible.checked: selected
                Accessible.onPressAction: clicked()
                Layout.fillWidth: true
                text: root.deviceMode ? qsTr("Automatic — use device type") : qsTr("Follow selected device")
                selected: root.draft.mode === "inherit" || root.draft.mode === "automatic"
                foreground: root.foreground
                focusable: true
                Layout.minimumHeight: 32
                onClicked: root.choose({mode:root.deviceMode ? "inherit" : "automatic"})
            }
            Controls.Label { text: qsTr("Choose an icon"); textFormat: Text.PlainText; color: root.foreground }
            Flow {
                id: presets
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: Appearance.presets
                    Kit.Button {
                        required property var modelData
                        objectName: "preset-" + modelData.value
                        text: modelData.label
                        iconText: root.presetFont ? Appearance.glyphFor(modelData) : ""
                        fontFamily: root.presetFont || root.fontFamily
                        foreground: root.foreground
                        selected: root.draft.mode === "preset" && root.draft.value === modelData.value
                        focusable: true
                        width: Math.min(implicitWidth,presets.width)
                        height: Math.max(32,implicitHeight)
                        Accessible.role: Accessible.Button
                        Accessible.name: modelData.label + qsTr(" icon")
                        Accessible.checkable: true
                        Accessible.checked: selected
                        Accessible.onPressAction: clicked()
                        onClicked: root.choose(modelData)
                    }
                }
            }
            Controls.Label {
                objectName: "icon-choice-label"
                Layout.fillWidth: true
                text: qsTr("Choice: ") + root.choiceLabel
                textFormat: Text.PlainText
                color: root.foreground
                wrapMode: Text.Wrap
            }
            Kit.SearchableDropdown {
                id: installedIcons
                objectName: "installed-icon-picker"
                Layout.fillWidth: true
                label: qsTr("Installed icons")
                rowHeight: Math.max(32,Commons.Style.spacing.controlHeight)
                popupRowHeight: Math.max(32,Commons.Style.spacing.popupRowHeight)
                options: root.store ? root.store.themeIcons : []
                value: root.draft.mode === "theme" ? root.draft.value : ""
                triggerLabel: qsTr("Search installed icons…")
                foreground: root.foreground
                onChanged: function(value) { root.choose({mode:"theme",value:value,render:"symbolic"}); }
            }
            Controls.Label {
                visible: !root.store || root.store.themeIcons.length === 0
                Layout.fillWidth: true
                text: root.store && root.store.busy ? qsTr("Loading installed icons…") : qsTr("No installed icons found. Use a preset or open More options.")
                textFormat: Text.PlainText
                color: root.foreground
                wrapMode: Text.Wrap
            }
            Controls.Label {
                Layout.fillWidth: true
                text: qsTr("Preview — Apply saves your choice")
                textFormat: Text.PlainText
                color: root.foreground
                wrapMode: Text.Wrap
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Repeater {
                    model: ["#ffffff","#171717"]
                    Rectangle {
                        required property string modelData
                        Layout.fillWidth: true
                        implicitHeight: 60
                        color: modelData
                        border.color: "#888888"
                        radius: 4
                        AppearanceIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 8
                            width: 20; height: 20
                            icon: root.resolvedDraft
                            foreground: parent.modelData === "#ffffff" ? "#171717" : "#ffffff"
                            fontFamily: root.fontFamily
                            assetBaseUrl: root.store ? root.store.assetBaseUrl : ""
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                            text: parent.modelData === "#ffffff" ? qsTr("Light bar · 20 px") : qsTr("Dark bar · 20 px")
                            textFormat: Text.PlainText
                            color: parent.modelData === "#ffffff" ? "#171717" : "#ffffff"
                            font.pixelSize: 12
                        }
                    }
                }
            }
            AppearanceIcon { id: validationPreview; visible: false; icon: root.resolvedDraft; assetBaseUrl: root.store ? root.store.assetBaseUrl : "" }
            Controls.Label {
                visible: !!validationPreview.warning || !!(root.store && (root.store.error || root.store.warnings.length))
                Layout.fillWidth: true
                text: (root.store ? root.store.error : "") || validationPreview.warning || (root.store ? root.store.warnings.join("\n") : "")
                textFormat: Text.PlainText
                color: root.foreground
                wrapMode: Text.Wrap
                Accessible.role: Accessible.AlertMessage
            }
            Kit.Button {
                Layout.minimumHeight: 32
                text: root.moreOptions ? qsTr("Hide more options") : qsTr("More options")
                foreground: root.foreground
                focusable: true
                onClicked: root.moreOptions = !root.moreOptions
            }
            ColumnLayout {
                visible: root.moreOptions
                Layout.fillWidth: true
                spacing: 8
                Controls.Label { text: qsTr("Custom symbol"); textFormat: Text.PlainText; color: root.foreground }
                Flow {
                    id: symbols
                    Layout.fillWidth: true
                        spacing: 6
                    Repeater {
                        model: Appearance.glyphs
                        Kit.Button {
                            required property var modelData
                            text: modelData.value + " " + modelData.label
                            height: Math.max(32,implicitHeight)
                            width: Math.min(implicitWidth,symbols.width)
                            foreground: root.foreground
                            focusable: true
                            selected: root.draft.mode === "glyph" && root.draft.value === modelData.value
                            onClicked: root.choose(modelData)
                        }
                    }
                }
                Kit.TextField {
                    id: symbolField
                    objectName: "custom-symbol-input"
                    Layout.fillWidth: true
                    maximumLength: 16
                    placeholderText: qsTr("Type or paste a symbol (up to 8 characters)")
                    Accessible.name: qsTr("Custom symbol, up to 8 characters")
                    selectByMouse: true
                    onTextEdited: root.draft = {mode:"glyph",value:text,font:fontField.text,render:"symbolic"}
                }
                Kit.TextField {
                    id: fontField
                    Layout.fillWidth: true
                    maximumLength: 128
                    placeholderText: qsTr("Font family (optional)")
                    Accessible.name: qsTr("Installed font family")
                    selectByMouse: true
                    onTextEdited: root.draft = {mode:"glyph",value:symbolField.text,font:text,render:"symbolic"}
                }
                Controls.Label {
                    Layout.fillWidth: true
                    text: fontField.text && Qt.fontFamilies().indexOf(fontField.text) < 0 ? qsTr("This font is unavailable. Phone is shown until you choose an installed font.") : qsTr("Check the preview. Font fallback can change a symbol's appearance.")
                    textFormat: Text.PlainText
                    color: root.foreground
                    wrapMode: Text.Wrap
                }
                Kit.TextField {
                    id: themeNameField
                    Layout.fillWidth: true
                    maximumLength: 128
                    placeholderText: qsTr("Exact installed icon name (optional)")
                    Accessible.name: qsTr("Exact installed theme icon name")
                    selectByMouse: true
                    onTextEdited: root.draft = {mode:"theme",value:text,render:"symbolic"}
                }
                Controls.Label {
                    visible: !!root.store && root.store.libraryTruncated === true
                    Layout.fillWidth: true
                    text: qsTr("Some installed icons may be omitted. You can enter an icon name or use your own image.")
                    textFormat: Text.PlainText
                    color: root.foreground
                    wrapMode: Text.Wrap
                }
                Kit.Button {
                    Layout.minimumHeight: 32
                    text: qsTr("Choose local SVG or PNG…")
                    foreground: root.foreground
                    focusable: true
                    enabled: root.store && !root.store.busy
                    onClicked: imageDialog.open()
                }
                Controls.Label {
                    Layout.fillWidth: true
                    text: qsTr("Up to 1 MiB and 512 × 512 pixels. Static SVG or non-interlaced PNG. The original file is kept.")
                    textFormat: Text.PlainText
                    color: root.foreground
                    wrapMode: Text.Wrap
                }
                Controls.CheckBox {
                    visible: root.draft.mode === "image"
                    text: qsTr("Keep image colours")
                    checked: root.draft.render === "color"
                    onToggled: { var next = Object.assign({},root.draft); next.render = checked ? "color" : "symbolic"; root.draft = next; }
                }
                Kit.Button {
                    Layout.minimumHeight: 32
                    text: root.deviceMode ? qsTr("Reset to Automatic") : qsTr("Use Phone")
                    foreground: root.foreground
                    focusable: true
                    enabled: !root.pendingApply
                    onClicked: root.choose(root.deviceMode ? {mode:"inherit"} : Appearance.phone())
                }
            }
        }
    }
    footer: RowLayout {
        spacing: 8
        Kit.Button {
            text: qsTr("Cancel")
            objectName: "appearance-cancel"
            Accessible.role: Accessible.Button
            Accessible.name: text
            Accessible.onPressAction: clicked()
            Layout.minimumHeight: 32
            Layout.fillWidth: true
            foreground: root.foreground
            focusable: true
            enabled: !root.pendingApply
            onClicked: root.reject()
        }
        Kit.Button {
            text: root.pendingApply ? qsTr("Saving…") : qsTr("Apply")
            objectName: "appearance-apply"
            Accessible.role: Accessible.Button
            Accessible.name: text
            Accessible.onPressAction: clicked()
            Layout.minimumHeight: 32
            Layout.fillWidth: true
            foreground: root.foreground
            focusable: true
            enabled: !!root.store && root.store.ready && !root.store.busy && Array.from(aliasField.text).length <= 80
            onClicked: root.applyDraft()
        }
    }
    FileDialog {
        id: imageDialog
        title: qsTr("Choose a local icon")
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("SVG or PNG images (*.svg *.png)"),qsTr("All files (*)")]
        onAccepted: if (root.store && !root.store.busy) root.pendingImport = root.store.importImage(selectedFile)
    }
    Connections {
        target: root.store
        function onSaved() { if (root.pendingApply) { root.pendingApply = false; root.applied(); root.close(); } }
        function onImageImported(icon) { if (root.pendingImport) { root.pendingImport = false; root.choose(icon); } }
        function onOperationFailed(message) { root.pendingApply = false; root.pendingImport = false; }
    }
}
