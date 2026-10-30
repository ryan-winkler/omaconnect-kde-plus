import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "plugin/components" as Components

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property var checks: []
    property bool capturing: false
    property int nativeOpens: 0
    property int returned: 0
    property var captures: [
        {page:"Appearance", width:720, name:"settings-720-appearance.png"},
        {page:"Connections", width:720, name:"settings-720-connections.png"},
        {page:"Quick actions", width:720, name:"settings-720-actions.png"},
        {page:"Device features", width:720, name:"settings-720-features.png"},
        {page:"Connections", width:520, name:"settings-520-connections.png"},
        {page:"Device features", width:520, name:"settings-520-features.png"}
    ]
    function check(value, message) {
        if (!value) { console.error("NATIVE_FAIL settings: " + message); Qt.quit(); return false }
        checks = checks.concat([message]); return true
    }
    function find(object, predicate, seen) {
        if (!object || seen.indexOf(object) !== -1) return null
        seen.push(object)
        if (predicate(object)) return object
        var lists=["children","data"]
        for (var i=0;i<lists.length;i++) {
            var children=object[lists[i]] || []
            for (var j=0;j<children.length;j++) { var found=find(children[j],predicate,seen);if(found)return found }
        }
        if (object.contentItem) { var content=find(object.contentItem,predicate,seen);if(content)return content }
        return null
    }
    function named(label) { return find(settings.contentItem,function(o) { return typeof o.clicked==="function" && o.Accessible && o.Accessible.name===label },[]) }
    QtObject {
        id: service
        property var appearance: null
        property var selectedDevice: ({id:"fixture-phone",name:"Fixture phone",type:"phone",pluginIds:["kdeconnect_share","kdeconnect_sftp","thirdparty.custom-addon","kdeconnect_remotecommands"],loadedKnown:true,loadedPluginIds:["kdeconnect_share"]})
        function displayName(device) { return device.name }
        function openKdeConnectApp() { test.nativeOpens++ }
    }
    QtObject {
        id: panel
        property var service: service
        property var device: service.selectedDevice
        property var settings: ({networkBthEnabled:true})
        function getSetting(key,fallback) { return key in panel.settings ? panel.settings[key] : fallback }
    }
    Components.SettingsPanel { id: settings; panel: panel; onReturnToPanelRequested: test.returned++ }
    TestCase { id: events; when:false }
    Timer {
        interval:100; running:true; repeat:true
        onTriggered: {
            if (++test.ticks>100) { test.check(false,"scenario completed before deadline");return }
            if (test.phase===0) { settings.openSettings("Appearance");test.phase=1 }
            else if(test.phase===1) {
                if(!test.check(settings.visible && settings.width===720 && settings.height===640,"dedicated native settings window opens"))return
                if(!test.check(settings.transientParent===null,"settings remains independent of the bar popup"))return
                if(!test.check(test.named("Settings: Appearance").activeFocus,"opening settings focuses domain navigation"))return
                if(!test.check(test.named("Show Syncthing identity notes")!==null && test.named("Show saved addresses")!==null,"optional sections have explicit saved visibility controls"))return
                if(!test.check(test.named("Start media expanded")!==null && test.named("Start network controls expanded")!==null,"collapse defaults are configurable"))return
                test.named("Settings: Connections").clicked();test.phase=2
            } else if(test.phase===2) {
                if(!test.check(settings.currentPage==="Connections" && test.named("Show MikroTik Back to Home")!==null,"domain navigation exposes connection preferences"))return
                if(!test.check(panel.getSetting("networkBthEnabled",false) === true && test.named("Show MikroTik Back to Home").checked,"saved BTH preference reaches the real native toggle"))return
                var scroll=test.find(settings.contentItem,function(o){return o.objectName === "settings-page-scroll"},[])
                if(!test.check(scroll && scroll.contentHeight > scroll.availableHeight,"long domain content uses a bounded scrolling region"))return
                events.mouseWheel(scroll,scroll.width/2,scroll.height/2,0,-2400,Qt.NoButton,Qt.NoModifier,1)
                test.phase=29
            } else if(test.phase===29) {
                var scrolled=test.find(settings.contentItem,function(o){return o.objectName === "settings-page-scroll"},[])
                if(!test.check(scrolled.contentItem.contentY > 0,"mouse wheel reaches lower connection settings"))return
                test.named("Settings: Quick actions").clicked();test.phase=3
            } else if(test.phase===3) {
                if(!test.check(test.named("Settings: Quick actions")!==null,"quick actions have an explicit domain"))return
                test.named("Settings: Device features").clicked();test.phase=4
            } else if(test.phase===4) {
                var features=test.find(settings.contentItem,function(o){return "filteredPluginIds" in o && o.configuration===true},[])
                if(!test.check(features && features.pluginIds.length===4,"complete reported inventory is present in settings"))return
                features.searchText="browse";test.phase=5
            } else if(test.phase===5) {
                var featureList=test.find(settings.contentItem,function(o){return "filteredPluginIds" in o && o.configuration===true},[])
                if(!test.check(featureList.filteredPluginIds.length===1 && featureList.filteredPluginIds[0]==="kdeconnect_sftp","task search finds native file browsing"))return
                featureList.searchText="thirdparty.custom";test.phase=6
            } else if(test.phase===6) {
                var featureList2=test.find(settings.contentItem,function(o){return "filteredPluginIds" in o && o.configuration===true},[])
                if(!test.check(featureList2.filteredPluginIds.length===1 && featureList2.filteredPluginIds[0]==="thirdparty.custom-addon","search retains unknown third-party IDs"))return
                test.named("All KDE Connect features").clicked()
                if(!test.check(test.nativeOpens===1 && settings.visible,"native settings handoff keeps Plus settings available"))return
                featureList2.searchText="";test.phase=7
            } else if(test.phase===7) {
                test.named("Back to devices").clicked();test.phase=8
            } else if(test.phase===8) {
                if(!test.check(!settings.visible && test.returned===1,"Back to devices closes settings and requests the daily panel"))return
                settings.openSettings("Connections");test.phase=9
            } else if(test.phase===9) {
                settings.requestActivate()
                events.keyClick(Qt.Key_Escape,Qt.NoModifier,1)
                test.phase=10
            } else if(test.phase===10) {
                if(!test.check(!settings.visible,"Escape closes the independent settings window"))return
                test.phase=20
            } else if(test.phase>=20 && test.phase<26 && !test.capturing) {
                var capture=test.captures[test.phase-20]
                settings.width=capture.width;settings.openSettings(capture.page)
                test.capturing=true;test.phase+=100
            } else if(test.phase>=120 && test.phase<126) {
                var shot=test.captures[test.phase-120]
                test.phase+=100
                settings.contentItem.grabToImage(function(result) {
                    if(!test.check(result.saveToFile(Qt.resolvedUrl(shot.name).toString().replace("file://","")),"filled screenshot saved: "+shot.name))return
                    test.capturing=false;test.phase-=199
                })
            } else if(test.phase===26) {
                console.log("SETTINGS_PASS "+JSON.stringify(test.checks));console.log("NATIVE_PASS settings");Qt.quit()
            }
        }
    }
}
