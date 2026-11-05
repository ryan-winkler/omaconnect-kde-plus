pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "Appearance.js" as Appearance
import "i18n" as Locale

// Own-service presentation store. All writes go through a short-lived helper.
// Commands use fixed argv and bounded JSON stdin. No polling or service actions.
Item {
    id: root
    property bool autoLoad: true
    property string helperPath: Qt.resolvedUrl("scripts/appearance.py").toString().replace(/^file:\/\//, "")
    property var snapshot: ({schema_version:1,bar_icon:Appearance.phone(),devices:{}})
    property var themeIcons: []
    property bool libraryTruncated: false
    property var invalidAssets: []
    property string assetBaseUrl: ""
    property string errorKey: ""
    property string errorFallback: ""
    readonly property string error: errorKey ? Locale.Strings.t(errorKey, errorFallback) : errorFallback
    readonly property var warnings: invalidAssets.length ? [Locale.Strings.t("appearance.assetFallback")] : []
    property bool ready: false
    readonly property bool busy: worker.running
    signal saved()
    signal imageImported(var icon)
    signal operationFailed(string message)
    property bool libraryPending: false
    property bool outputRejected: false
    property string currentAction: ""
    property string payload: "{}"

    function safeIcon(value) {
        return value.mode === "image" && invalidAssets.indexOf(value.value) >= 0 ? Appearance.phone() : value;
    }
    function barIcon(id,type) { return safeIcon(Appearance.barIcon(snapshot,id,type)); }
    function deviceIcon(id,type) { return safeIcon(Appearance.deviceIcon(snapshot,id,type)); }
    function displayName(id,advertised) { return Appearance.displayName(snapshot,id,advertised); }
    function deviceAppearance(id) { return Appearance.record(snapshot,id); }
    function start(action,request) {
        if (worker.running) return false;
        currentAction = action;
        outputRejected = false;
        errorKey = "";
        errorFallback = "";
        payload = JSON.stringify(request || {}) + "\n";
        worker.stdinEnabled = true;
        worker.command = ["python3", decodeURIComponent(helperPath), action];
        worker.running = true;
        deadline.restart();
        return true;
    }
    function refresh() { return start("read",{}); }
    function loadLibrary() {
        if (worker.running) { libraryPending = true; return false; }
        libraryPending = false;
        return start("library",{});
    }
    function setBarIcon(icon) { return start("update",{action:"bar",icon:icon}); }
    function setDeviceAppearance(id,alias,icon) { return start("update",{action:"device",device_id:String(id),alias:alias,icon:icon}); }
    function linkSyncthing(id,syncthingId) { return start("update",{action:"link",device_id:String(id),syncthing_device_id:syncthingId || null}); }
    function forgetAppearance(id) { return start("update",{action:"forget",device_id:String(id)}); }
    function importImage(localUrl) { return start("import",{path:String(localUrl)}); }
    function fail(key, fallback) {
        ready = true
        errorKey = key
        errorFallback = fallback || ""
        operationFailed(error)
    }

    Process {
        id: worker
        stdinEnabled: true
        onStarted: { worker.write(root.payload); worker.stdinEnabled = false; }
        stdout: StdioCollector {
            waitForEnd: false
            onDataChanged: {
                if (text.length > 400000) {
                    root.outputRejected = true;
                    worker.running = false;
                    root.fail("appearance.responseTooLarge");
                }
            }
            onStreamFinished: {
                deadline.stop();
                if (root.outputRejected) return;
                if (text.length > 400000) { root.fail("appearance.responseTooLarge"); return; }
                var result;
                try { result = JSON.parse(text); }
                catch (exception) { root.fail("appearance.helperUnavailable"); return; }
                if (!result.ok) {
                    root.ready = true;
                    var knownCode = typeof result.error_code === "string" && /^[a-z0-9-]{1,128}$/.test(result.error_code)
                    var fallback = typeof result.error === "string" && result.error.length < 512 ? result.error : ""
                    root.fail(knownCode ? "appearance.error." + result.error_code : fallback ? "" : "appearance.error.read-save-failed", fallback);
                    return;
                }
                if (root.currentAction === "library") {
                    root.themeIcons = (result.theme_icons || []).filter(function(name) { return Quickshell.iconPath(name,true) !== ""; });
                    root.libraryTruncated = result.library_truncated === true;
                }
                else {
                    root.snapshot = result.snapshot;
                    root.invalidAssets = result.invalid_assets || [];
                    root.assetBaseUrl = "file://" + result.asset_dir.split("/").map(encodeURIComponent).join("/") + "/";
                    root.ready = true;
                    if (root.currentAction === "update") root.saved();
                    if (root.currentAction === "import") root.imageImported(result.icon);
                }
            }
        }
        onExited: function(code) {
            deadline.stop();
            if (code !== 0 && !root.error) root.fail("appearance.helperUnavailable");
            if (root.libraryPending) Qt.callLater(function() { if (!worker.running) root.loadLibrary(); });
        }
    }
    Timer {
        id: deadline
        interval: 5000
        onTriggered: { worker.running = false; root.fail("appearance.helperTimeout"); }
    }
    Component.onCompleted: if (autoLoad) refresh()
}
