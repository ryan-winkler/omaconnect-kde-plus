pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "Appearance.js" as Appearance

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
    property string error: ""
    property var warnings: []
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
        error = "";
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
    function fail(message) { ready = true; error = message; operationFailed(message); }

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
                    root.fail("Appearance response exceeded its limit.");
                }
            }
            onStreamFinished: {
                deadline.stop();
                if (root.outputRejected) return;
                if (text.length > 400000) { root.fail("Appearance response exceeded its limit."); return; }
                var result;
                try { result = JSON.parse(text); }
                catch (exception) { root.fail("Appearance helper is unavailable."); return; }
                if (!result.ok) {
                    root.ready = true;
                    root.fail(result.error || "Appearance could not be saved. Existing metadata was preserved.");
                    return;
                }
                if (root.currentAction === "library") {
                    root.themeIcons = (result.theme_icons || []).filter(function(name) { return Quickshell.iconPath(name,true) !== ""; });
                    root.libraryTruncated = result.library_truncated === true;
                }
                else {
                    root.snapshot = result.snapshot;
                    root.warnings = result.warnings || [];
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
            if (code !== 0 && !root.error) root.fail("Appearance helper is unavailable.");
            if (root.libraryPending) Qt.callLater(function() { if (!worker.running) root.loadLibrary(); });
        }
    }
    Timer {
        id: deadline
        interval: 5000
        onTriggered: { worker.running = false; root.fail("Appearance helper did not respond in time."); }
    }
    Component.onCompleted: if (autoLoad) refresh()
}
