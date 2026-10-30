import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import "plugin/components" as Components

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property bool dispatching: false
    property var checks: []
    function check(ok, message) {
        if (!ok) { console.error("NATIVE_FAIL navigation: " + message + " phase=" + phase + " checks=" + JSON.stringify(checks)); Qt.quit(); return false }
        checks = checks.concat([message]); return true
    }
    function find(item, name) {
        if (item.Accessible && item.Accessible.name === name) return item
        var children = item.children || []
        for (var i=0;i<children.length;i++) { var result=find(children[i],name);if(result)return result }
        return null
    }
    function controlsBusy() {
        for(var i=0;i<preferences.children.length;i++) {
            var child=preferences.children[i]
            if ("preferences" in child && "busy" in child) return child.busy
        }
        return true
    }
    function key(code) { events.keyClick(code, Qt.NoModifier, 1) }
    QtObject {
        id: service
        property var operations: []
        property string selectionState: ""
        property var draftTarget: null
    }
    QtObject {
        id: panel
        property var service: service
        property var settings: ({})
        property string currentView: "Devices"
        property bool opened: true
        property int settingsOpens: 0
        readonly property Item focusTarget: navigation.focusItem
        function getSetting(key, fallback) { return key in settings ? settings[key] : fallback }
        function openSettings() { settingsOpens++ }
        function close() { opened=false }
    }
    FileView {
        path: Quickshell.env("NATIVE_COMMAND_LOG").replace("commands.jsonl", "preferences.json")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: panel.settings = JSON.parse(text())
    }
    Window {
        id: preview
        visible: true
        width: 400
        height: 640
        Components.CompactNavigation { id: navigation; width: parent.width; panel: panel }
        Components.NavigationSettings { id: preferences; y: 260; width: parent.width; panel: panel }
        Item { TestEvent { id: events } }
    }
    Timer {
        interval: 30;running: true;repeat: true
        onTriggered: {
            if(test.dispatching)return
            test.dispatching=true
            try {
                if(++test.ticks>180){test.check(false,"bounded scenario finishes");return}
                if(test.phase===0){
                    preview.requestActivate()
                    if(!test.check(navigation.entries.join(",")==="Devices,Send,Activity,Plus settings","all routes remain in fixed menu order"))return
                    if(!test.check(navigation.focusItem.text==="View: Devices" && navigation.focusItem.Accessible.role===Accessible.Button && navigation.focusItem.Accessible.name==="Current view: Devices. Choose a view","trigger exposes visible view and accurate accessible semantics"))return
                    navigation.focusItem.forceActiveFocus();test.key(Qt.Key_Space);test.phase=1
                }else if(test.phase===1){
                    if(!test.check(navigation.menuOpen,"Space opens view menu"))return
                    test.key(Qt.Key_Tab);test.phase=2
                }else if(test.phase===2){
                    if(!test.check(preview.activeFocusItem.Accessible.name==="Send","Tab reaches next menu item"))return
                    test.key(Qt.Key_Return);test.phase=3
                }else if(test.phase===3){
                    if(!test.check(panel.currentView==="Send" && !navigation.menuOpen && navigation.focusItem.activeFocus,"Enter changes view and restores trigger focus"))return
                    test.key(Qt.Key_Return);test.phase=4
                }else if(test.phase===4){
                    test.key(Qt.Key_Down);test.key(Qt.Key_Space);test.phase=5
                }else if(test.phase===5){
                    if(!test.check(panel.currentView==="Activity","arrows and Space select Activity"))return
                    navigation.focusItem.Accessible.pressAction();test.phase=6
                }else if(test.phase===6){
                    if(!test.check(navigation.menuOpen,"accessible press opens menu"))return
                    test.key(Qt.Key_Escape);test.phase=7
                }else if(test.phase===7){
                    if(!test.check(!navigation.menuOpen && navigation.focusItem.activeFocus && panel.currentView==="Activity" && panel.opened,"Escape restores focus without closing panel or changing view"))return
                    navigation.choose("unreviewed-command")
                    if(!test.check(panel.currentView==="Activity","unknown menu route is rejected"))return
                    service.selectionState="draft";service.draftTarget={peerName:"Fixture phone <b>plain</b>"}
                    service.operations=[{state:"submission_unknown"}]
                    panel.currentView="Devices"
                    if(!test.check(navigation.draftSummary.indexOf("Fixture phone <b>plain</b>")>=0 && navigation.activitySummary==="Needs review","pending draft and uncertain activity retain independent cues"))return
                    var place=test.find(preferences,"Place navigation at Top")
                    if(!test.check(place && !place.checked,"Bottom is the saved default"))return
                    place.clicked()
                    if(!test.check(!place.checked,"save request does not fabricate configuration readback"))return
                    test.phase=8
                }else if(test.phase===8 && panel.getSetting("navigationAtTop",false)===true && !test.controlsBusy()){
                    if(!test.check(test.find(preferences,"Place navigation at Top").checked,"saved host readback updates placement"))return
                    test.find(preferences,"Show a direct Send shortcut").clicked();test.phase=9
                }else if(test.phase===9 && panel.getSetting("showSendShortcut",false)===true && !test.controlsBusy()){
                    test.find(preferences,"Show a direct Activity shortcut").clicked();test.phase=10
                }else if(test.phase===10 && panel.getSetting("showActivityShortcut",false)===true && !test.controlsBusy()){
                    if(!test.check(test.find(navigation,"Open Send").visible && test.find(navigation,"Open Activity").visible,"saved shortcuts are composable without hiding menu routes"))return
                    var saved=panel.settings
                    panel.settings=({showSendShortcut:"true",showActivityShortcut:1})
                    if(!test.check(!test.find(navigation,"Open Send").visible && !test.find(navigation,"Open Activity").visible,"wrong typed values do not reveal shortcuts"))return
                    panel.settings=saved
                    test.find(navigation,"Open Plus settings").Accessible.pressAction()
                    if(!test.check(panel.settingsOpens===1,"quiet settings control supports accessible activation"))return
                    console.log("COMPACT_NAVIGATION_PASS "+JSON.stringify(test.checks))
                    console.log("NATIVE_PASS compact navigation")
                    Qt.quit()
                }
            } finally {test.dispatching=false}
        }
    }
}
