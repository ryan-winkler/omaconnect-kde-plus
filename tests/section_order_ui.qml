import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import "plugin" as Plugin
import "plugin/components" as Components
import "plugin/SectionOrder.js" as SectionOrder

ShellRoot {
    id: test
    property int phase: 0
    property int ticks: 0
    property var heldPosition: null
    readonly property var catalogueForPanel: catalog
    Plugin.PanelSectionCatalog { id: catalog; storedOrder: fakePanel.getSetting("sectionOrder", "") }
    FileView { id: gate; path: Qt.resolvedUrl("save-gate").toString().replace(/^file:\/\//, ""); preload: true; blockWrites: true }
    FileView { id: requestState; path: Qt.resolvedUrl("request-started").toString().replace(/^file:\/\//, ""); preload: true; watchChanges: true; onFileChanged: reload() }
    QtObject {
        id: fakePanel
        property var settings: ({sectionOrder: "", networkBthEnabled: true, showSyncthingLinks: false})
        property var sectionCatalog: test.catalogueForPanel
        property bool editingLayout: true
        property bool layoutSaveBusy: false
        property string layoutMessage: ""
        property string layoutFeedbackSectionId: ""
        property string activeComposer: "none"
        function getSetting(key, fallback) { return key in settings ? settings[key] : fallback }
        function sectionExpanded(id) { return false }
        function sectionPolicy(id) { var entry=catalog.entry(id);return SectionOrder.policy(entry,{},entry ? getSetting(entry.visibilityKey,entry.defaultVisible) : true) }
        function sectionAvailability(id) { return "available" }
        function sectionAvailabilityText(id) { return "Available: private fixture" }
        function sectionVisible(id) { return true }
        function moveSectionTo(id, position) { var next=SectionOrder.moveTo(catalog.order,id,position);if(next)saver.save({key:"sectionOrder",value:next.join(",")}) }
        function saveSectionPolicy(id, policy) { return false }
    }
    Window {
        id: window
        visible: true
        width: 520
        height: 780
        Column {
            width: parent.width
            Components.LayoutSection { id: actionFrame; sectionId:"actions"; panel:fakePanel }
            Components.LayoutSection { id: syncFrame; sectionId:"syncthing"; panel:fakePanel }
            Components.SettingsButton {
                text:"Use default section order";Accessible.name:text;focusable:true
                onClicked:saver.save({key:"sectionOrder",value:""})
            }
            Components.PreferenceControls { id:saver;panel:fakePanel;width:parent.width }
            Components.PreferenceControls { id:booleanSaver;panel:fakePanel;width:parent.width;preferences:[{key:"showRemoteCommands",label:"Fixture command visibility",defaultValue:true}] }
        }
    }
    TestCase { id: events; when: false }
    function find(item, name) {
        if (item.objectName === name || item.Accessible.name === name) return item
        for (var i = 0; i < item.children.length; ++i) { var found=find(item.children[i],name);if(found)return found }
        return null
    }
    function check(value, message) {
        if (!value) { console.error("NATIVE_FAIL section order: " + message); Qt.quit(); return false }
        console.log("SECTION_ORDER_PASS " + message);return true
    }
    function luminance(color) {
        return [color.r,color.g,color.b].reduce(function(total,value,index) {
            var linear=value<=0.04045 ? value/12.92 : Math.pow((value+0.055)/1.055,2.4)
            return total+linear*[0.2126,0.7152,0.0722][index]
        },0)
    }
    function contrast(first,second) {
        var a=luminance(first),b=luminance(second)
        return (Math.max(a,b)+0.05)/(Math.min(a,b)+0.05)
    }
    Timer {
        interval:30;running:true;repeat:true
        onTriggered: {
            if (++test.ticks > 160) { test.check(false,"bounded scenario");return }
            if(test.phase===0 && catalog.ready){
                Commons.Color.loadColors('foreground = "#c2c2b0"\nbackground = "#222222"\naccent = "#78824b"\n')
                if(!test.check(catalog.entries.length===9 && catalog.preferencesFor("Connections").length===3,"one catalogue supplies order and expansion defaults"))return
                heldPosition=find(actionFrame,"section-position-actions")
                window.requestActivate();heldPosition.forceActiveFocus();test.phase=10
            }else if(test.phase===10){
                if(!test.check(window.activeFocusItem===heldPosition,"native position menu receives keyboard focus"))return
                var visibility=find(actionFrame,"section-visibility-actions")
                var selectedContrast=Math.min(contrast(visibility.palette.highlight,visibility.palette.highlightedText),
                    contrast(heldPosition.palette.highlight,heldPosition.palette.highlightedText))
                if(!test.check(selectedContrast>=4.5,"native layout choices retain readable selected text with a muted accent: "+selectedContrast.toFixed(2)+":1"))return
                events.keyClick(Qt.Key_Space,Qt.NoModifier,1);events.keyClick(Qt.Key_Up,Qt.NoModifier,1);events.keyClick(Qt.Key_Return,Qt.NoModifier,1);test.phase=11
            }else if(test.phase===11 && requestState.text()==="sectionOrder"){
                if(!test.check(saver.busy && heldPosition.currentIndex===1,"pending save keeps saved order selected"))return
                heldPosition.activated(2)
                if(!test.check(saver.message.indexOf("not submitted")>=0,"busy repeated move is rejected without a queue"))return
                find(window.contentItem,"Use default section order").Accessible.pressAction()
                gate.setText("release");test.phase=1
            }else if(test.phase===1 && !saver.busy && saver.message==="Setting saved."){
                if(!test.check(heldPosition.currentIndex===1 && catalog.order[0]==="devices","ACK alone does not fabricate readback"))return
                fakePanel.settings=({sectionOrder:"actions,devices,drop,native,media,commands,connections,addresses,syncthing",networkBthEnabled:true,showSyncthingLinks:false});test.phase=2
            }else if(test.phase===2 && catalog.order[0]==="actions"){
                if(!test.check(find(actionFrame,"section-position-actions")===heldPosition && heldPosition.currentIndex===0 && heldPosition.activeFocus,"readback updates the same native menu without stealing focus"))return
                find(syncFrame,"section-position-syncthing").activated(7);test.phase=3
            }else if(test.phase===3 && !saver.busy && saver.message.indexOf("not confirmed")>=0){
                if(!test.check(catalog.order[8]==="syncthing" && find(syncFrame,"section-position-syncthing").currentIndex===8,"failed save preserves saved position"))return
                find(window.contentItem,"Use default section order").Accessible.pressAction();test.phase=4
            }else if(test.phase===4 && !saver.busy && saver.message==="Setting saved."){
                fakePanel.settings=({sectionOrder:"",networkBthEnabled:true,showSyncthingLinks:false});test.phase=5
            }else if(test.phase===5 && catalog.order[0]==="devices"){
                if(!test.check(fakePanel.settings.networkBthEnabled && !fakePanel.settings.showSyncthingLinks,"reset changes order only"))return
                gate.setText("hold")
                find(booleanSaver,"preference-showRemoteCommands").forceActiveFocus();test.phase=6
            }else if(test.phase===6){
                events.keyClick(Qt.Key_Space,Qt.NoModifier,1);test.phase=7
            }else if(test.phase===7 && requestState.text()==="showRemoteCommands"){
                var toggle=find(booleanSaver,"preference-showRemoteCommands")
                if(!test.check(booleanSaver.busy && toggle.checked && toggle.activeFocus,"pending boolean save keeps focus and saved checked state"))return
                events.keyClick(Qt.Key_Space,Qt.NoModifier,1)
                if(!test.check(booleanSaver.message.indexOf("not submitted")>=0,"busy boolean repeat is rejected"))return
                gate.setText("release");test.phase=8
            }else if(test.phase===8 && !booleanSaver.busy && booleanSaver.message==="Setting saved."){
                fakePanel.settings=({sectionOrder:"",networkBthEnabled:true,showSyncthingLinks:false,showRemoteCommands:false});test.phase=9
            }else if(test.phase===9){
                var saved=find(booleanSaver,"preference-showRemoteCommands")
                if(!test.check(!saved.checked && saved.activeFocus,"boolean readback changes value without stealing focus"))return
                console.log("NATIVE_PASS section order");Qt.quit()
            }
        }
    }
}
