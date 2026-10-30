import QtQuick
import QtTest
import Quickshell
import "plugin" as Plugin
import "plugin/components" as Components

ShellRoot {
    id: test
    property int page: 0
    property bool dispatching: false
    property int step: 0
    property int direction: 1
    property int cycles: 0
    property bool scrolled: false
    property bool activated: false
    property int settling: 0
    property var previousFocus: null
    property int metadataWait: 0
    readonly property var catalogueForPanel: sectionCatalogModel
    Plugin.PanelSectionCatalog { id: sectionCatalogModel; storedOrder: panel.getSetting("sectionOrder", "") }
    property var device: ({id:"fixture", name:"Fixture phone", type:"phone", paired:true, reachable:true, pluginIds:[], loadedKnown:true, loadedPluginIds:[], capabilities:{}})
    QtObject {
        id: service
        property var devices: [test.device]
        property bool daemonAvailable: true
        property var selectedDevice: test.device
        property bool nativeAppOpening: false
        property string nativeAppMessage: ""
        property bool nativeAppFailed: false
        property string actionState: "idle"
        property string actionMessage: ""
        property string actionError: ""
        property var appearance: null
        function displayName(device) { return device.name }
    }
    QtObject {
        id: panel
        property var service: service
        property var device: test.device
        property var settings: ({quickActionsOrder:"file,text,clipboard,ring"})
        readonly property var sectionCatalog: test.catalogueForPanel
        function getSetting(key, fallback) { return key in panel.settings ? panel.settings[key] : fallback }
    }
    Components.SettingsPanel { id: settings; panel: panel; width:520; height:440 }
    TestCase { id: events; when:false }
    function findScroll(item) {
        if (item.objectName === "settings-page-scroll") return item
        var children = item.children || []
        for (var i=0;i<children.length;i++) { var found=findScroll(children[i]); if(found)return found }
        return null
    }
    function fail(message) { console.error("NATIVE_FAIL focus: " + message); Qt.quit() }
    Timer {
        interval:40; running:true; repeat:true
        onTriggered: {
            if(test.dispatching)return
            test.dispatching=true
            try {
            if (!sectionCatalogModel.ready) {
                if (++test.metadataWait > 50) test.fail("real section metadata did not load: " + sectionCatalogModel.error)
                return
            }
            if(test.step===0) { settings.openSettings(settings.pages[test.page]); test.step++; return }
            if(test.settling>0) {test.settling--;return}
            var focus=settings.activeFocusItem
            var scroll=test.findScroll(settings.contentItem)
            var ancestor=focus
            while(ancestor && ancestor!==scroll.contentItem) ancestor=ancestor.parent
            if(ancestor) {
                var position=focus.mapToItem(scroll,0,0)
                if(position.y < -1 || position.y+focus.height > scroll.height+1) {
                    test.fail(settings.currentPage+" clipped keyboard focus: "+focus.Accessible.name+" y="+position.y+" height="+focus.height+" viewport="+scroll.height); return
                }
                if(scroll.contentItem.contentY>0) test.scrolled=true
            }
            if(test.previousFocus && focus!==test.previousFocus) {
                test.fail("scrolling changed keyboard focus");return
            }
            var activationTargets=[
                {key:"showBarBattery", name:"Show battery beside the bar icon"},
                {name:"Show Other WireGuard profiles"},
                {name:"Use default actions"},
                {key:"showRemoteCommands", name:"Show Remote commands"}
            ]
            var target=activationTargets[test.page]
            var matches=focus && (target.key ? focus.objectName==="preference-"+target.key : focus.Accessible.name===target.name)
            if(!test.activated && matches) {
                if(focus.Accessible.name!==target.name) {test.fail("full semantic AT name missing for "+target.key);return}
                if(target.key==="showRemoteCommands" && focus.label!=="Show in Devices") {test.fail("compact section checkbox lost its visible label");return}
                test.activated=true
                settings.contentItem.grabToImage(function(result) {result.saveToFile(Qt.resolvedUrl("focus-"+test.page+".png").toString().replace("file://",""))})
                events.keyClick(Qt.Key_Space,Qt.NoModifier,1)
                test.previousFocus=null;test.settling=3;return
            }
            // Keep both full cycles in each direction. Explicitly assert the
            // persistent selector wrap boundary as well as scroll coverage.
            if(focus && focus.Accessible.name==="Close Plus settings") test.cycles++
            if(test.cycles===2) {
                if(!test.scrolled || !test.activated) {test.fail(settings.currentPage+" did not exercise clipped activation");return}
                if(test.direction===1) {
                    events.keyClick(Qt.Key_Tab,Qt.NoModifier,1)
                    var wrapped=settings.activeFocusItem
                    if(!wrapped || wrapped.Accessible.name!=="Device") {test.fail(settings.currentPage+" forward wrap did not reach Device");return}
                    events.keyClick(Qt.Key_Tab,Qt.ShiftModifier,1)
                    if(settings.activeFocusItem!==focus) {test.fail(settings.currentPage+" reverse wrap did not return to Close");return}
                    console.log("FOCUS_WRAP_PASS "+settings.currentPage+" Close to Device and back")
                    test.direction=-1;test.cycles=0;test.scrolled=false;test.step=1
                }
                else {
                    console.log("FOCUS_PASS "+settings.currentPage+" Tab and Shift+Tab")
                    console.log("NATIVE_PASS settings focus");Qt.quit()
                    return
                }
            }
            if(++test.step>240) {test.fail("focus direction deadline");return}
            events.keyClick(Qt.Key_Tab,test.direction===1?Qt.NoModifier:Qt.ShiftModifier,1)
            test.previousFocus=settings.activeFocusItem
            } finally { test.dispatching=false }
        }
    }
}
