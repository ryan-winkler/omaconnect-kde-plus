import QtQuick
import QtTest
import Quickshell
import "plugin/components" as Components

ShellRoot {
    id: test
    property int page: 0
    property int step: 0
    property int direction: 1
    property int cycles: 0
    property bool scrolled: false
    property bool activated: false
    property int settling: 0
    property var previousFocus: null
    property var device: ({id:"fixture", name:"Fixture phone", type:"phone", paired:true, reachable:true, pluginIds:[], loadedKnown:true, loadedPluginIds:[], capabilities:{}})
    QtObject {
        id: service
        property var devices: [test.device]
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
            var activationLabels=["Start Syncthing notes expanded","Show Other WireGuard profiles","Use default actions","Show remote commands"]
            if(!test.activated && focus && focus.Accessible.name===activationLabels[test.page]) {
                test.activated=true
                settings.contentItem.grabToImage(function(result) {result.saveToFile(Qt.resolvedUrl("focus-"+test.page+".png").toString().replace("file://",""))})
                events.keyClick(Qt.Key_Space,Qt.NoModifier,1)
                test.previousFocus=null;test.settling=3;return
            }
            // One full cycle includes the persistent Device selector, page
            // navigation, all page controls and the return/close buttons.
            if(focus && focus.Accessible.name==="Close Plus settings") test.cycles++
            if(test.cycles===2) {
                if(!test.scrolled || !test.activated) {test.fail(settings.currentPage+" did not exercise clipped activation");return}
                if(test.direction===1) {test.direction=-1;test.cycles=0;test.scrolled=false}
                else {
                    console.log("FOCUS_PASS "+settings.currentPage+" Tab and Shift+Tab")
                    test.page++;test.step=0;test.direction=1;test.cycles=0;test.scrolled=false;test.activated=false;test.previousFocus=null
                    if(test.page===settings.pages.length) {console.log("NATIVE_PASS settings focus");Qt.quit()}
                    return
                }
            }
            if(++test.step>240) {test.fail("focus cycle deadline");return}
            events.keyClick(Qt.Key_Tab,test.direction===1?Qt.NoModifier:Qt.ShiftModifier,1)
            test.previousFocus=settings.activeFocusItem
        }
    }
}
