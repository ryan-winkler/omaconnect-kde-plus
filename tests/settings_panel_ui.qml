import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "plugin" as Plugin
import "plugin/components" as Components

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property var checks: []
    property bool capturing: false
    property int nativeOpens: 0
    property int returned: 0
    property string nativeTarget: ""
    property string nativePluginTarget: ""
    property int deviceSelections: 0
    property int monitorRequests: 0
    property string commandEditorTarget: ""
    property int metadataWait: 0
    readonly property var catalogueForPanel: sectionCatalogModel
    Plugin.PanelSectionCatalog { id: sectionCatalogModel; storedOrder: panel.getSetting("sectionOrder", "") }
    property var initialDevices: [
        {id:"fixture_phone",name:"Fixture phone",type:"phone",paired:true,reachable:true,reachableAddresses:["192.0.2.10:1716"],activeProviderNames:["LAN"],virtualMonitor:{known:true,active:false,available:true},pluginIds:["kdeconnect_share","kdeconnect_sftp","thirdparty.custom-addon","kdeconnect_remotecommands","kdeconnect_virtualmonitor"],loadedKnown:true,loadedPluginIds:["kdeconnect_share","kdeconnect_virtualmonitor"]},
        {id:"fixture_offline",name:"Fixture phone",type:"laptop",paired:true,reachable:false,pluginIds:["kdeconnect_battery"],loadedKnown:true,loadedPluginIds:["kdeconnect_battery"]},
        {id:"fixture_new",name:"<b>Living room tablet with a very long device name that must stay plain and fit the settings window</b>",type:"tablet",paired:false,reachable:true,pluginIds:[],loadedKnown:false}
    ]
    property var captures: [
        {page:"Appearance", width:720, name:"settings-720-appearance.png"},
        {page:"Connections", width:720, name:"settings-720-connections.png"},
        {page:"Quick actions", width:720, name:"settings-720-actions.png"},
        {page:"Device features", width:720, name:"settings-720-features.png"},
        {page:"Connections", width:520, name:"settings-520-connections.png"},
        {page:"Device features", width:520, name:"settings-520-features.png"},
        {page:"Device features", width:520, popup:true, name:"settings-520-dropdown.png"},
        {page:"Appearance", width:520, device:"fixture_new", name:"settings-520-long-name.png"},
        {page:"Device features", width:520, height:440, name:"settings-520-minimum-height.png"},
        {page:"Device features", width:720, scroll:500, name:"settings-720-command-setup.png"},
        {page:"Device features", width:520, scroll:850, name:"settings-520-native-configuration.png"},
        {page:"Device features", width:720, scroll:99999, name:"settings-720-feature-inventory.png"}
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
    function preference(key) { return find(settings.contentItem,function(o) { return o.objectName === "preference-" + key },[]) }
    function checkSectionPreference(key, name, label) {
        var item = preference(key)
        return check(item && item.visible && item.label === label && item.Accessible.role === Accessible.CheckBox
            && item.Accessible.name === name, key + " has compact visible copy and the full semantic AT name in its domain")
    }
    QtObject {
        id: service
        property var appearance: null
        property var devices: test.initialDevices
        property string selectedDeviceId: "fixture_phone"
        readonly property var selectedDevice: devices.find(function(entry) { return entry.id === service.selectedDeviceId }) || null
        property bool scanning: false
        property bool daemonAvailable: true
        property string discoveryState: "ready"
        property string discoveryMessage: ""
        property bool nativeAppOpening: false
        property string nativeAppMessage: ""
        property bool nativeAppFailed: false
        property string actionMessage: ""
        property string actionError: ""
        property string actionState: "idle"
        function displayName(device) { return device.name }
        function openKdeConnectApp(pluginId) { test.nativeOpens++;test.nativeTarget=selectedDeviceId;test.nativePluginTarget=pluginId || "" }
        function toggleVirtualMonitor(id) { if(id===selectedDeviceId)test.monitorRequests++;return true }
        function editRemoteCommands(id) { test.commandEditorTarget=id;return true }
    }
    QtObject {
        id: panel
        property var service: service
        property var device: service.selectedDevice
        property var settings: ({networkBthEnabled:true})
        readonly property var sectionCatalog: test.catalogueForPanel
        function getSetting(key,fallback) { return key in panel.settings ? panel.settings[key] : fallback }
        function selectDevice(id) { test.deviceSelections++;service.selectedDeviceId=id }
    }
    Components.SettingsPanel { id: settings; panel: panel; onReturnToPanelRequested: test.returned++ }
    TestCase { id: events; when:false }
    Timer {
        interval:100; running:true; repeat:true
        onTriggered: {
            if (++test.ticks>100) { test.check(false,"scenario completed before deadline");return }
            if (test.phase===0 && sectionCatalogModel.ready) { settings.openSettings("Appearance");test.phase=1 }
            else if(test.phase===1) {
                if(!test.check(settings.visible && settings.width===720 && settings.height===640,"dedicated native settings window opens"))return
                if(!test.check(settings.transientParent===null,"settings remains independent of the bar popup"))return
                if(!test.check(test.named("Settings: Appearance").activeFocus,"opening settings focuses domain navigation"))return
                if(!test.check(test.named("Change selected device icon and alias").Accessible.role===Accessible.Button,"settings actions expose a native button role"))return
                if(!test.check(sectionCatalogModel.entries.length===10 && test.named("Use default section order").visible,"Appearance exposes order controls from the real ten-section catalogue"))return
                test.named("Settings: Connections").clicked();test.phase=2
            } else if(test.phase===2) {
                if(!test.check(settings.currentPage==="Connections" && test.named("Show MikroTik Back to Home")!==null,"domain navigation exposes connection preferences"))return
                if(!test.check(panel.getSetting("networkBthEnabled",false) === true && test.named("Show MikroTik Back to Home").checked,"saved BTH preference reaches the real native toggle"))return
                if(!test.checkSectionPreference("showSyncthingLinks", "Show Syncthing identity note", "Show in Devices"))return
                if(!test.checkSectionPreference("showSavedAddresses", "Show Saved addresses", "Show in Devices"))return
                if(!test.checkSectionPreference("networkStartExpanded", "Start Connection controls expanded", "Start expanded"))return
                var scroll=test.find(settings.contentItem,function(o){return o.objectName === "settings-page-scroll"},[])
                if(!test.check(scroll && scroll.contentHeight > scroll.availableHeight,"long domain content uses a bounded scrolling region"))return
                events.mouseWheel(scroll,scroll.width/2,scroll.height/2,0,-2400,Qt.NoButton,Qt.NoModifier,1)
                test.phase=290
            } else if(test.phase===290) {
                var scrolled=test.find(settings.contentItem,function(o){return o.objectName === "settings-page-scroll"},[])
                if(!test.check(scrolled.contentItem.contentY > 0,"mouse wheel reaches lower connection settings"))return
                test.named("Settings: Quick actions").clicked();test.phase=3
            } else if(test.phase===3) {
                if(!test.check(test.named("Settings: Quick actions")!==null,"quick actions have an explicit domain"))return
                if(!test.checkSectionPreference("showQuickActions", "Show Quick actions", "Show in Devices"))return
                if(!test.checkSectionPreference("showInlineSend", "Show File sharing", "Show in Devices"))return
                test.named("Settings: Device features").clicked();test.phase=4
            } else if(test.phase===4) {
                if(!test.checkSectionPreference("mediaStartExpanded", "Start Media controls expanded", "Start expanded"))return
                if(!test.checkSectionPreference("showRemoteCommands", "Show Remote commands", "Show in Devices"))return
                var features=test.find(settings.contentItem,function(o){return "filteredPluginIds" in o && o.configuration===true},[])
                if(!test.check(features && features.pluginIds.length===5,"complete reported inventory is present in settings"))return
                if (features.installedModules.length === 0) {
                    if (++test.metadataWait > 30) test.check(false, "installed native metadata loaded before deadline")
                    return
                }
                if(!test.check(features.nativeConfigurations.some(function(entry) { return entry.id === "kdeconnect_runcommand" }),"native local command configuration is discovered without requiring remote feature support"))return
                var configure=test.find(settings.contentItem,function(o){return o.objectName === "native-module-configure-kdeconnect_runcommand"},[])
                if(!test.check(configure && configure.enabled,"paired device has a native command configuration control"))return
                if(!test.check(configure.Accessible.role===Accessible.Button,"native configuration exposes its button role"))return
                configure.Accessible.pressAction()
                if(!test.check(test.nativeTarget==="fixture_phone" && test.nativePluginTarget==="kdeconnect_runcommand","Configure passes the selected device and exact native module"))return
                test.named("Show device information").Accessible.pressAction()
                test.named("Show device actions").Accessible.pressAction()
                var editor=test.find(settings.contentItem,function(o){return o.objectName === "request-remote-command-editor"},[])
                if(!test.check(editor && editor.visible && editor.enabled,"connected command-capable peer has a visible explicit editor request"))return
                editor.Accessible.pressAction()
                if(!test.check(test.commandEditorTarget==="fixture_phone","remote editor request uses the selected peer, separate from local configuration"))return
                var addressInfo=test.find(settings.contentItem,function(o){return o.objectName==="device-information-Addresses"},[])
                if(!test.check(addressInfo && addressInfo.text.indexOf("192.0.2.10:1716")!==-1,"Information shows reported native addresses"))return
                var monitor=test.named("Use device as an external monitor")
                if(!test.check(monitor && monitor.visible && monitor.enabled,"known native monitor state enables the visible explicit action"))return
                monitor.clicked()
                if(!test.check(test.monitorRequests===1,"monitor control dispatches to the selected native device"))return
                features.informationExpanded=false;features.actionsExpanded=false
                features.searchText="browse";test.phase=5
            } else if(test.phase===5) {
                var featureList=test.find(settings.contentItem,function(o){return "filteredPluginIds" in o && o.configuration===true},[])
                if(!test.check(featureList.filteredPluginIds.length===1 && featureList.filteredPluginIds[0]==="kdeconnect_sftp","task search finds native file browsing"))return
                featureList.searchText="thirdparty.custom";test.phase=6
            } else if(test.phase===6) {
                var featureList2=test.find(settings.contentItem,function(o){return "filteredPluginIds" in o && o.configuration===true},[])
                if(!test.check(featureList2.filteredPluginIds.length===1 && featureList2.filteredPluginIds[0]==="thirdparty.custom-addon","search retains unknown third-party IDs"))return
                test.named("Native KDE Connect settings").Accessible.pressAction()
                if(!test.check(test.nativeOpens===2 && settings.visible,"native settings handoff keeps Plus settings available"))return
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
                settings.openSettings("Device features");test.phase=30
            } else if(test.phase===30) {
                var selector=test.find(settings.contentItem,function(o){return o.objectName==="settings-device-selector"},[])
                if(!test.check(selector && selector.count===3 && selector.currentValue==="fixture_phone","settings has a native dropdown bound to all known devices"))return
                if(!test.check(selector.textAt(0).indexOf("[fixture_phone]")!==-1 && selector.textAt(1).indexOf("[fixture_offline]")!==-1,"duplicate device names include stable IDs"))return
                if(!test.check(selector.textAt(1).indexOf("Offline")!==-1 && selector.textAt(2).indexOf("Not paired")!==-1,"offline and unpaired devices have text states"))return
                selector.activated(1);test.phase=31
            } else if(test.phase===31) {
                if(!test.check(service.selectedDeviceId==="fixture_offline" && test.deviceSelections===1 && settings.currentPage==="Device features","switching uses the shared panel selector and keeps the domain"))return
                var switched=test.find(settings.contentItem,function(o){return "filteredPluginIds" in o && o.configuration===true},[])
                if(!test.check(switched.pluginIds.length===1 && switched.pluginIds[0]==="kdeconnect_battery","feature inventory follows the selected device"))return
                test.named("Native KDE Connect settings").clicked()
                if(!test.check(test.nativeTarget==="fixture_offline","native handoff follows the new selected ID"))return
                service.nativeAppOpening=true;service.nativeAppMessage="Opening KDE Connect";test.phase=32
            } else if(test.phase===32) {
                var status=test.find(settings.contentItem,function(o){return o.objectName==="native-launch-status"},[])
                if(!test.check(!test.named("Native KDE Connect settings").enabled && status.text==="Opening KDE Connect","native launch has visible busy feedback and prevents repeat requests"))return
                var opens=test.nativeOpens
                test.named("Native KDE Connect settings").Accessible.pressAction()
                if(!test.check(test.nativeOpens===opens,"assistive-technology press cannot activate a disabled native launch"))return
                service.nativeAppOpening=false;service.nativeAppFailed=true;service.nativeAppMessage="KDE Connect app unavailable";test.phase=33
            } else if(test.phase===33) {
                var failed=test.find(settings.contentItem,function(o){return o.objectName==="native-launch-status"},[])
                if(!test.check(failed.visible && failed.text==="KDE Connect app unavailable" && test.named("Native KDE Connect settings").enabled,"native launch failure is visible and retry is available"))return
                service.nativeAppMessage="";service.nativeAppFailed=false;service.actionError="Unrelated action failed";test.phase=331
            } else if(test.phase===331) {
                var scoped=test.find(settings.contentItem,function(o){return o.objectName==="native-launch-status"},[])
                if(!test.check(!scoped.visible,"unrelated action feedback is not shown as native launch status"))return
                service.actionError="";service.selectedDeviceId="fixture_phone";test.phase=34
            } else if(test.phase===34) {
                var keys=test.find(settings.contentItem,function(o){return o.objectName==="settings-device-selector"},[])
                keys.forceActiveFocus();events.keyClick(Qt.Key_Space,Qt.NoModifier,1);test.phase=35
            } else if(test.phase===35) {
                var opened=test.find(settings.contentItem,function(o){return o.objectName==="settings-device-selector"},[])
                if(!test.check(opened.popup.visible,"Space opens the device dropdown"))return
                service.devices=JSON.parse(JSON.stringify(service.devices));test.phase=350
            } else if(test.phase===350) {
                var unchanged=test.find(settings.contentItem,function(o){return o.objectName==="settings-device-selector"},[])
                if(!test.check(unchanged.popup.visible,"identical discovery refresh keeps the device dropdown open"))return
                var changed=JSON.parse(JSON.stringify(service.devices))
                changed[0].name="Refreshed fixture phone";service.devices=changed;test.phase=3501
            } else if(test.phase===3501) {
                var refreshed=test.find(settings.contentItem,function(o){return o.objectName==="settings-device-selector"},[])
                if(!test.check(!refreshed.popup.visible,"changed device labels close stale dropdown rows"))return
                refreshed.forceActiveFocus();events.keyClick(Qt.Key_Space,Qt.NoModifier,1);test.phase=3502
            } else if(test.phase===3502) {
                events.keyClick(Qt.Key_Down,Qt.NoModifier,1);test.phase=351
            } else if(test.phase===351) {
                events.keyClick(Qt.Key_Return,Qt.NoModifier,1);test.phase=36
            } else if(test.phase===36) {
                var selected=test.find(settings.contentItem,function(o){return o.objectName==="settings-device-selector"},[])
                if(!test.check(service.selectedDeviceId==="fixture_offline" && !selected.popup.visible,"arrows and Enter select the device by keyboard: " + service.selectedDeviceId + " / " + selected.currentIndex + " / " + selected.popup.visible))return
                selected.forceActiveFocus();events.keyClick(Qt.Key_Space,Qt.NoModifier,1);test.phase=37
            } else if(test.phase===37) {
                events.keyClick(Qt.Key_Escape,Qt.NoModifier,1);test.phase=38
            } else if(test.phase===38) {
                var dismissed=test.find(settings.contentItem,function(o){return o.objectName==="settings-device-selector"},[])
                if(!test.check(settings.visible && !dismissed.popup.visible && dismissed.activeFocus,"first Escape closes the dropdown and restores focus"))return
                events.keyClick(Qt.Key_Escape,Qt.NoModifier,1);test.phase=39
            } else if(test.phase===39) {
                if(!test.check(!settings.visible,"second Escape closes Settings"))return
                settings.openSettings("Appearance");service.devices=[test.initialDevices[2],test.initialDevices[1],test.initialDevices[0]];test.phase=40
            } else if(test.phase===40) {
                var reordered=test.find(settings.contentItem,function(o){return o.objectName==="settings-device-selector"},[])
                if(!test.check(reordered.currentValue==="fixture_offline","device list reorder preserves selected identity"))return
                if(!test.check(reordered.displayText.indexOf("[fixture_offline]")!==-1 && reordered.displayText.indexOf("Offline")!==-1,"displayed device label follows the stable ID after reorder"))return
                reordered.activated(0);test.phase=41
            } else if(test.phase===41) {
                if(!test.check(service.selectedDeviceId==="fixture_new" && settings.selectedName.indexOf("<b>")===0,"long markup-shaped names remain selectable as plain data"))return
                service.devices=[];service.scanning=true;service.selectedDeviceId="";test.phase=42
            } else if(test.phase===42) {
                var empty=test.find(settings.contentItem,function(o){return o.objectName==="settings-device-selector"},[])
                if(!test.check(!empty.enabled && settings.deviceStatus.indexOf("Checking")===0 && settings.device===null,"removed selection and loading state do not keep a stale device"))return
                if(!test.check(empty.displayText==="Choose a device","removed device does not leave an invalid label index"))return
                settings.selectSettingsDevice("fixture_phone")
                if(!test.check(service.selectedDeviceId==="","removed ID cannot be selected from a stale option"))return
                service.scanning=false;test.phase=43
            } else if(test.phase===43) {
                if(!test.check(settings.deviceStatus.indexOf("No devices found")===0,"empty state explains pairing in KDE Connect"))return
                service.daemonAvailable=false;service.discoveryMessage="KDE Connect service is unavailable";test.phase=44
            } else if(test.phase===44) {
                if(!test.check(settings.deviceStatus==="KDE Connect service is unavailable","provider failure stays distinct from an empty device list"))return
                service.daemonAvailable=true;service.devices=test.initialDevices;service.selectedDeviceId="fixture_phone";test.phase=2000
            } else if(test.phase>=2000 && test.phase<2000+test.captures.length && !test.capturing) {
                var capture=test.captures[test.phase-2000]
                settings.width=capture.width;settings.height=capture.height || 640
                service.selectedDeviceId=capture.device || "fixture_phone"
                settings.openSettings(capture.page)
                if(capture.scroll) test.find(settings.contentItem,function(o){return o.objectName==="settings-page-scroll"},[]).contentItem.contentY=capture.scroll
                if(capture.popup) test.find(settings.contentItem,function(o){return o.objectName==="settings-device-selector"},[]).popup.open()
                test.capturing=true;test.phase+=1000
            } else if(test.phase>=3000 && test.phase<3000+test.captures.length) {
                var shot=test.captures[test.phase-3000]
                test.phase+=1000
                settings.contentItem.grabToImage(function(result) {
                    if(!test.check(result.saveToFile(Qt.resolvedUrl(shot.name).toString().replace("file://","")),"filled screenshot saved: "+shot.name))return
                    test.capturing=false;test.phase-=1999
                })
            } else if(test.phase===2000+test.captures.length) {
                console.log("SETTINGS_PASS "+JSON.stringify(test.checks));console.log("NATIVE_PASS settings");Qt.quit()
            }
        }
    }
}
