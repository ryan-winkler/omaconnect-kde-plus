import QtQuick
import QtTest
import Quickshell
import qs.Commons
import "plugin" as Plugin
import "plugin/components" as Components

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property int routeIndex: 0
    property int direction: 1
    property var measurements: []
    readonly property var catalogue: sectionCatalog
    Plugin.PanelSectionCatalog { id: sectionCatalog; storedOrder: "" }
    property var device: ({id:"fixture",name:"Fixture phone",type:"phone",paired:true,reachable:true,pluginIds:[],loadedKnown:true,loadedPluginIds:[],capabilities:{}})
    QtObject {
        id: service
        property var devices: [test.device]
        property var selectedDevice: test.device
        property bool daemonAvailable: false
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
        readonly property var sectionCatalog: test.catalogue
        function getSetting(key,fallback) { return fallback }
    }
    readonly property var settings: settingsLoader.item
    Loader {
        id: settingsLoader
        // The real host already has its theme when settings is opened. Wait
        // for this isolated host's asynchronous theme load before construction.
        active: sectionCatalog.ready && Style.font.baseSize===18 && Math.abs(Style.effectiveSpacingScale-1.5)<.01
        sourceComponent: Component { Components.SettingsPanel { panel: panel; width:520; height:440 } }
    }
    TestCase { id: events; when:false }

    // Follow visual children only. Metadata QtObjects have no Item geometry or
    // attached accessibility surface and are not navigation targets.
    function find(item,predicate) {
        if(!item)return null
        if(predicate(item))return item
        var children=item.children || []
        for(var i=0;i<children.length;i++) {var hit=find(children[i],predicate);if(hit)return hit}
        return null
    }
    function route(name) {
        return find(settings.contentItem,function(item){return typeof item.clicked==="function" && item.Accessible.name==="Settings: "+name})
    }
    function fail(message) {console.error("NATIVE_FAIL settings navigation: "+message);Qt.quit()}
    Timer {
        interval:60;running:true;repeat:true
        onTriggered: {
            if(++test.ticks>100){test.fail("bounded navigation scenario finishes");return}
            if(test.phase===0) {
                if(!sectionCatalog.ready || !settings)return
                if(Style.font.baseSize!==18 || Math.abs(Style.effectiveSpacingScale-1.5)>.01){test.fail("fixture must use native base18 and spacing1.5");return}
                settings.openSettings("Appearance");test.phase=1;return
            }
            var name=settings.pages[test.routeIndex],button=test.route(name)
            if(!button || settings.activeFocusItem!==button){test.fail("ordinary Tab did not focus "+name);return}
            var label=test.find(button,function(item){return "truncated" in item && item.text===button.text})
            if(!label || label.truncated || label.font.pixelSize!==18 || label.font.family!==Style.font.family){test.fail("native18 navigation label must stay complete: "+name+" "+JSON.stringify({buttonWidth:button.width,labelWidth:label?label.width:null,natural:label?label.implicitWidth:null,font:label?label.font.pixelSize:null,family:label?label.font.family:null,truncated:label?label.truncated:null}));return}
            if(button.height<44 || button.Accessible.role!==Accessible.RadioButton){test.fail("navigation target must retain native role and minimum44 height: "+name);return}
            var sidebar=test.find(settings.contentItem,function(item){return item.objectName==="settings-navigation-scroll"})
            var back=test.find(settings.contentItem,function(item){return typeof item.clicked==="function" && item.Accessible.name==="Back to devices"})
            if(!sidebar || !back || !sidebar.clip){test.fail("bounded sidebar and permanent Back route exist");return}
            var relative=button.mapToItem(sidebar,0,0)
            var sidePosition=sidebar.mapToItem(settings.contentItem,0,0)
            var backPosition=back.mapToItem(settings.contentItem,0,0)
            if(relative.x< -1 || relative.x+button.width>sidebar.availableWidth+1 || relative.y< -1 || relative.y+button.height>sidebar.availableHeight+1){test.fail("focused navigation is clipped by sidebar viewport: "+name);return}
            if(sidePosition.y+sidebar.height>backPosition.y+1){test.fail("sidebar overlaps Back to devices");return}
            events.keyClick(Qt.Key_Space,Qt.NoModifier,1)
            if(settings.currentPage!==name || settings.activeFocusItem!==button || !button.Accessible.checked){test.fail("Space activates exact domain without losing focus: "+name);return}
            test.measurements.push({route:name,direction:test.direction,height:button.height,font:label.font.pixelSize,truncated:label.truncated,y:relative.y,viewport:sidebar.availableHeight,sidebarBottom:sidePosition.y+sidebar.height,backTop:backPosition.y})
            if(test.direction===1 && test.routeIndex===3){test.direction=-1;return}
            if(test.direction===-1 && test.routeIndex===0){
                console.log("SETTINGS_NAVIGATION_LAYOUT_PASS "+JSON.stringify(test.measurements))
                console.log("NATIVE_PASS settings navigation layout");Qt.quit();return
            }
            test.routeIndex+=test.direction
            events.keyClick(Qt.Key_Tab,test.direction===1?Qt.NoModifier:Qt.ShiftModifier,1)
        }
    }
}
