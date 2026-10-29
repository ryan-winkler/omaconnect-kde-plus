pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../Appearance.js" as Appearance

// openForBar() or openForDevice(id,advertisedName,type). Editing is a draft;
// only Apply writes metadata. Import copies an asset but does not change icons.
Controls.Dialog {
    id: root
    required property var store
    property string deviceId: ""
    property string barDeviceId: ""
    property string barDeviceType: "phone"
    property string advertisedName: ""
    property string deviceType: "phone"
    property string fontFamily: "sans-serif"
    property color foreground: palette.windowText
    property var draft: Appearance.phone()
    property bool pendingApply: false
    property bool pendingImport: false
    readonly property bool deviceMode: deviceId !== ""
    readonly property var modeChoices: deviceMode ? [qsTr("Automatic"),qsTr("Preset"),qsTr("Icon library"),qsTr("Custom symbol"),qsTr("Local image")] : [qsTr("Follow selected device"),qsTr("Preset"),qsTr("Icon library"),qsTr("Custom symbol"),qsTr("Local image")]
    readonly property var entries: Appearance.library(search.text,store ? store.themeIcons : [])
    readonly property var resolvedDraft: {
        var resolved = draft.mode === "inherit" ? Appearance.typeIcon(deviceType)
            : draft.mode === "automatic" ? Appearance.deviceIcon(store ? store.snapshot : null,deviceMode ? deviceId : barDeviceId,deviceMode ? deviceType : barDeviceType) : draft;
        return store ? store.safeIcon(resolved) : resolved;
    }
    signal cancelled()

    title: deviceMode ? qsTr("Device appearance") : qsTr("Bar appearance")
    modal: true
    width: Math.max(260,Math.min(480, parent ? parent.width - 24 : 480))
    closePolicy: pendingApply ? Controls.Popup.NoAutoClose : Controls.Popup.CloseOnEscape
    anchors.centerIn: parent

    function prepare() {
        pendingApply = false;
        pendingImport = false;
        var saved = deviceMode ? (store ? store.deviceAppearance(deviceId) : {}) : {};
        draft = Appearance.normalizeIcon(deviceMode ? saved.icon || {mode:"inherit"} : store ? store.snapshot.bar_icon : null,deviceMode);
        aliasField.text = saved.alias || "";
        symbolField.text = draft.mode === "glyph" ? draft.value : "";
        fontField.text = draft.font || "";
        search.text = "";
        mode.currentIndex = [deviceMode ? "inherit" : "automatic","preset","theme","glyph","image"].indexOf(draft.mode);
        if (mode.currentIndex < 0) mode.currentIndex = 0;
    }
    function openForBar(selectedId,selectedType) { barDeviceId = String(selectedId || ""); barDeviceType = String(selectedType || "phone"); deviceId = ""; prepare(); open(); }
    function openForDevice(id,name,type) { deviceId = String(id); advertisedName = String(name || ""); deviceType = String(type || "phone"); prepare(); open(); }
    function choose(entry) { draft = Appearance.normalizeIcon(entry,deviceMode); mode.currentIndex = [deviceMode ? "inherit" : "automatic","preset","theme","glyph","image"].indexOf(draft.mode); }
    function applyDraft() {
        if (!store || store.busy) return;
        pendingApply = deviceMode ? store.setDeviceAppearance(deviceId,aliasField.text,draft) : store.setBarIcon(draft);
    }
    onOpened: {
        if (store && store.themeIcons.length === 0) store.loadLibrary();
        mode.forceActiveFocus();
    }
    onRejected: { pendingApply = false; pendingImport = false; cancelled(); }

    contentItem: Controls.ScrollView {
        clip: true
        implicitHeight: Math.min(body.implicitHeight,root.parent ? root.parent.height - 140 : 560)
        contentWidth: availableWidth
        ColumnLayout {
            id: body
            width: parent.width
            spacing: 10

            Controls.Label {
                visible: root.deviceMode
                text: qsTr("Advertised name: ") + "\u2068" + root.advertisedName + "\u2069"

                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            Controls.Label { visible: root.deviceMode; text: qsTr("Local alias"); textFormat: Text.PlainText }
            Controls.TextField {
                id: aliasField
                visible: root.deviceMode
                Layout.fillWidth: true
                maximumLength: 160
                placeholderText: qsTr("Use advertised name")
                Accessible.name: qsTr("Local alias, up to 80 characters")
                selectByMouse: true
            }
            Controls.Label {
                visible: root.deviceMode && Array.from(aliasField.text).length > 80
                text: qsTr("Use at most 80 characters.")

            }
            Controls.Label { text: qsTr("Icon source"); textFormat: Text.PlainText }
            Controls.ComboBox {
                id: mode
                Layout.fillWidth: true
                model: root.modeChoices
                Accessible.name: qsTr("Icon source")
                onActivated: function(index) {
                    if (index === 0) root.draft = {mode:root.deviceMode ? "inherit" : "automatic",render:"symbolic"};
                    else if (index === 1) root.draft = Appearance.phone();
                    else if (index === 2) {
                        root.draft = {mode:"theme",value:"smartphone-symbolic",render:"symbolic"};
                        if (root.store && root.store.themeIcons.length === 0) root.store.loadLibrary();
                    }
                    else if (index === 3) root.draft = {mode:"glyph",value:symbolField.text || "★",font:fontField.text,render:"symbolic"};
                    else if (index === 4) imageDialog.open();
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Repeater {
                    model: ["#ffffff","#171717"]
                    Rectangle {
                        required property string modelData
                        Layout.fillWidth: true
                        implicitHeight: 64
                        color: modelData
                        border.color: "#888888"
                        radius: 4
                        AppearanceIcon {
                            id: preview
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 8
                            width: 20
                            height: 20
                            icon: root.resolvedDraft
                            foreground: parent.modelData === "#ffffff" ? "#171717" : "#ffffff"
                            fontFamily: root.fontFamily
                            assetBaseUrl: root.store ? root.store.assetBaseUrl : ""
                        }
                        Text {
                            textFormat: Text.PlainText
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                            text: parent.modelData === "#ffffff" ? qsTr("Light · 20 px") : qsTr("Dark · 20 px")

                            color: parent.modelData === "#ffffff" ? "#171717" : "#ffffff"
                            font.pixelSize: 12
                        }
                    }
                }
            }
            Controls.TextField {
                id: search
                visible: mode.currentIndex === 1 || mode.currentIndex === 2
                Layout.fillWidth: true
                placeholderText: qsTr("Search presets and installed symbols")
                Accessible.name: qsTr("Search icon library")
                maximumLength: 128
                selectByMouse: true
            }
            ListView {
                id: library
                visible: mode.currentIndex === 1 || mode.currentIndex === 2
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 160 : 0
                clip: true
                model: root.entries
                keyNavigationEnabled: true
                activeFocusOnTab: true
                currentIndex: 0
                Keys.onReturnPressed: if (currentIndex >= 0 && currentIndex < root.entries.length) root.choose(root.entries[currentIndex])
                Keys.onSpacePressed: if (currentIndex >= 0 && currentIndex < root.entries.length) root.choose(root.entries[currentIndex])
                delegate: Controls.ItemDelegate {
                    id: optionRow
                    required property var modelData
                    required property int index
                    width: library.width
                    height: 36
                    highlighted: library.currentIndex === index
                    Accessible.name: modelData.label
                    onClicked: { library.currentIndex = index; root.choose(modelData); }
                    contentItem: RowLayout {
                        AppearanceIcon {
                            icon: optionRow.modelData
                            foreground: root.foreground
                            fontFamily: root.fontFamily
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                        }
                        Controls.Label {
                            text: optionRow.modelData.label

                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                }
                Controls.ScrollBar.vertical: Controls.ScrollBar {}
            }
            Controls.TextField {
                id: symbolField
                visible: mode.currentIndex === 3
                Layout.fillWidth: true
                maximumLength: 16
                placeholderText: qsTr("Type or paste a symbol")
                Accessible.name: qsTr("Custom symbol, up to 8 characters")
                selectByMouse: true
                onTextEdited: root.draft = {mode:"glyph",value:text,font:fontField.text,render:"symbolic"}
            }
            Controls.TextField {
                id: fontField
                visible: mode.currentIndex === 3
                Layout.fillWidth: true
                maximumLength: 128
                placeholderText: qsTr("Font family (optional)")
                Accessible.name: qsTr("Installed font family")
                selectByMouse: true
                onTextEdited: root.draft = {mode:"glyph",value:symbolField.text,font:text,render:"symbolic"}
            }
            Controls.Label {
                visible: mode.currentIndex === 3
                Layout.fillWidth: true
                text: fontField.text && Qt.fontFamilies().indexOf(fontField.text) < 0 ? qsTr("This font is unavailable. Phone is shown until you choose an installed font.") : qsTr("Check the preview. Font fallback can change a symbol's appearance.")

                wrapMode: Text.Wrap
            }
            Controls.Button {
                visible: mode.currentIndex === 4
                text: qsTr("Choose local SVG or PNG…")
                enabled: root.store && !root.store.busy
                implicitHeight: 36
                onClicked: imageDialog.open()
            }
            Controls.Label {
                visible: mode.currentIndex === 4
                Layout.fillWidth: true
                text: qsTr("Up to 1 MiB and 512 × 512 pixels. Static SVG or non-interlaced PNG. The original file is kept.")

                wrapMode: Text.Wrap
            }
            Controls.CheckBox {
                visible: mode.currentIndex === 4
                text: qsTr("Keep image colours")
                checked: root.draft.render === "color"
                onToggled: { var next = Object.assign({},root.draft); next.render = checked ? "color" : "symbolic"; root.draft = next; }
            }
            AppearanceIcon {
                id: validationPreview
                visible: false
                icon: root.resolvedDraft
                assetBaseUrl: root.store ? root.store.assetBaseUrl : ""
            }
            Controls.Label {
                visible: !!validationPreview.warning
                Layout.fillWidth: true
                text: validationPreview.warning

                wrapMode: Text.Wrap
            }
            Controls.Label {
                visible: !!(root.store && (root.store.error || root.store.warnings.length))
                Layout.fillWidth: true
                text: root.store ? root.store.error || root.store.warnings.join("\n") : ""

                wrapMode: Text.Wrap
                Accessible.role: Accessible.AlertMessage
            }
            Controls.Button {
                text: root.deviceMode ? qsTr("Reset to Automatic") : qsTr("Use Phone")
                implicitHeight: 36
                enabled: !root.pendingApply
                onClicked: root.choose(root.deviceMode ? {mode:"inherit"} : Appearance.phone())
            }
        }
    }
    footer: Controls.DialogButtonBox {
        Controls.Button {
            text: qsTr("Cancel")
            implicitHeight: 36
            enabled: !root.pendingApply
            Controls.DialogButtonBox.buttonRole: Controls.DialogButtonBox.RejectRole
        }
        Controls.Button {
            text: root.pendingApply ? qsTr("Saving…") : qsTr("Apply")
            implicitHeight: 36
            enabled: !!root.store && root.store.ready && !root.store.busy && Array.from(aliasField.text).length <= 80
            Controls.DialogButtonBox.buttonRole: Controls.DialogButtonBox.ActionRole
            onClicked: root.applyDraft()
        }
        onRejected: root.reject()
    }
    FileDialog {
        id: imageDialog
        title: qsTr("Choose a local icon")
        fileMode: FileDialog.OpenFile
        nameFilters: [qsTr("SVG or PNG images (*.svg *.png)"),qsTr("All files (*)")]
        onAccepted: if (root.store && !root.store.busy) root.pendingImport = root.store.importImage(selectedFile)
        onRejected: mode.currentIndex = [root.deviceMode ? "inherit" : "automatic","preset","theme","glyph","image"].indexOf(root.draft.mode)
    }
    Connections {
        target: root.store
        function onSaved() { if (root.pendingApply) { root.pendingApply = false; root.applied(); root.close(); } }
        function onImageImported(icon) { if (root.pendingImport) { root.pendingImport = false; root.choose(icon); } }
        function onOperationFailed(message) { root.pendingApply = false; root.pendingImport = false; }
    }
}
