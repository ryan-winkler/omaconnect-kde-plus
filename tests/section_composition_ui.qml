import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import "plugin" as Plugin

ShellRoot {
    id:test
    property int phase:0
    property int ticks:0
    property int hoverFrames:0
    property int focusSteps:0
    property var focusCounts:({forward:0,backward:0})
    property var focusHeaders:({forward:[],backward:[]})
    property string focusState:""
    property bool dispatching:false
    property var checks:[]
    property var savedSettings:({})
    property var panel:null
    property var groups:null
    property var widgets:({})
    property var address:null
    property var addressSection:null
    property var textInput:null
    property string fileDraft:""
    property var defaults:[]
    property var beforeAllHidden:({})
    readonly property string linkedId:Array(8).fill("AAAAAAA").join("-")
    function check(ok,label){
        if(!ok){console.error("NATIVE_FAIL composition: "+label+" phase="+phase+" checks="+JSON.stringify(checks));Qt.quit();return false}
        checks=checks.concat([label]);return true
    }
    function find(item,predicate,seen){
        if(!item || seen.indexOf(item)>=0)return null
        seen.push(item)
        if(predicate(item))return item
        var lists=[item.children || [],item.data || []]
        for(var n=0;n<lists.length;n++)for(var i=0;i<lists[n].length;i++){
            var hit=find(lists[n][i],predicate,seen);if(hit)return hit
        }
        var nested=["contentItem","item","footer"]
        for(var k=0;k<nested.length;k++)if(item[nested[k]]){var child=find(item[nested[k]],predicate,seen);if(child)return child}
        return null
    }
    function named(item,name){return find(item,function(o){return o.objectName===name},[])}
    function accessible(item,label){return find(item,function(o){return typeof o.clicked==="function" && o.Accessible && o.Accessible.name===label},[])}
    function sectionItems(){return Array.from(groups.children).filter(function(item){return "sectionId" in item})}
    function order(){return sectionItems().map(function(item){return item.sectionId}).join(",")}
    function sameWidgets(){return sectionItems().every(function(item){return widgets[item.sectionId]===item})}
    function patchSettings(patch){savedSettings=Object.assign({},savedSettings,patch)}
    function editor(){return find(panel.settingsWindow,function(item){return typeof item.moveSection==="function" && "order" in item && "busy" in item},[])}
    function preserve(){
        return sameWidgets() && address.text==="10.9.8.7" && addressSection.removalReview==="A:10.9.8.7"
            && panel.activeComposer==="text" && panel.draftText==="Composition draft"
            && textInput.text==="Composition draft" && service.selectionState==="draft"
            && fileDraft===JSON.stringify(service.draftTarget)+JSON.stringify(service.selection)
    }
    function tabHeaderOrder(){
        var list=[]
        named(panel,"daily-device-selector").forceActiveFocus()
        for(var i=0;i<80;i++){
            events.keyClick(Qt.Key_Tab,Qt.NoModifier,1)
            var focused=preview.activeFocusItem
            if(focused && ["section-toggle-actions","section-toggle-drop"].indexOf(focused.objectName)>=0 && list.indexOf(focused.objectName)<0)list.push(focused.objectName)
            if(list.length===2)break
        }
        return list.join(",")
    }
    function drag(actions){return {hasUrls:true,urls:[Qt.resolvedUrl("one")],supportedActions:actions,accepted:false,action:Qt.IgnoreAction,accept:function(action){this.accepted=true;this.action=action}}}
    function currentDraftState(){return JSON.stringify([panel.draftText,address.text,addressSection.removalReview,service.selectionState,service.selectedDeviceId])}
    Plugin.Service{id:service}
    QtObject{id:facade;function serviceFor(id){return service}}
    QtObject{
        id:bar
        property var shell:facade
        property var activePopout:null
        property bool vertical:false
        property bool foregroundAnimationEnabled:false
        property int barSize:26
        property string position:"top"
        property string fontFamily:"sans-serif"
        property color barForeground:"white"
        property color foreground:"white"
        property color urgent:"red"
        function hideTooltip(owner){}
        function showTooltip(owner,text,options){}
        function registerClickTarget(owner){}
        function unregisterClickTarget(owner){}
        function requestPopout(owner){activePopout=owner}
        function releasePopout(owner){if(activePopout===owner)activePopout=null}
        function switchPanelFrom(owner,direction){return false}
    }
    FileView{
        path:Quickshell.env("NATIVE_COMMAND_LOG").replace("commands.jsonl","composition-settings.json")
        watchChanges:true
        printErrors:false
        onFileChanged:reload()
        onLoaded:test.savedSettings=JSON.parse(text())
    }
    Window{
        id:preview;visible:true;width:560;height:900
        Plugin.BarWidget{id:widget;bar:bar;settings:test.savedSettings}
        Item{TestEvent{id:events}}
    }
    Timer{
        interval:30;running:true;repeat:true
        onTriggered:{
            if(test.dispatching)return
            test.dispatching=true
            try{
                if(++test.ticks>420){test.check(false,"bounded acceptance completes");return}
                if(test.phase===0 && service.appearance.ready && service.devices.length===2){
                    test.panel=test.find(widget,function(item){return typeof item.openDropTarget==="function" && "sectionCatalog" in item},[])
                    if(!panel)return
                    if(!savedSettings.fixtureCatalogFailure && !panel.sectionCatalog.ready)return
                    var loader=test.find(widget,function(item){return "item" in item && "source" in item && item.item===panel},[])
                    if(loader)loader.visible=true // Offscreen host is an Item; actual native host is a separate window.
                    service.selectDevice("A");panel.open();preview.requestActivate()
                    if(savedSettings.fixtureCatalogFailure){test.phase=1001;return}
                    test.groups=test.named(panel,"device-sections")
                    if(!test.check(groups!==null,"real daily Column exposes composed sections"))return
                    defaults=panel.sectionCatalog.entries.map(function(entry){return entry.id})
                    if(!test.check(defaults.length===10 && order()===defaults.join(","),"ten real section widgets follow metadata order"))return
                    var refs={};sectionItems().forEach(function(item){refs[item.sectionId]=item});widgets=refs
                    var correct=panel.sectionCatalog.entries.every(function(entry){return panel.sectionExpanded(entry.id)===panel.getSetting(entry.expandedKey,entry.defaultExpanded)})
                    if(!test.check(correct,"opening restores typed saved choices and metadata expansion defaults"))return
                    var picker=test.named(panel,"daily-device-selector")
                    if(!test.check(picker && picker.count===2 && picker.currentValue==="A","one shared current-device picker replaces the duplicate roster"))return
                    test.address=test.find(panel,function(item){return "placeholderText" in item && item.placeholderText==="Private or Tailscale IP address"},[])
                    test.addressSection=test.find(panel,function(item){return "removalReview" in item && "peerId" in item},[])
                    address.text="10.9.8.7";addressSection.removalReview="A:10.9.8.7"
                    panel.openComposer("text");panel.draftText="Composition draft"
                    textInput=test.find(panel,function(item){return "placeholderText" in item && item.placeholderText==="Text or link"},[])
                    if(!test.check(service.stageDroppedFiles("A",[String(Qt.resolvedUrl("one"))]),"private file review starts for A without submission"))return
                    test.phase=1
                }else if(test.phase===1001){
                    var coldSync=find(panel,function(item){return "linkedId" in item && "draftPeerId" in item},[])
                    var coldTimer=find(coldSync,function(item){return "interval" in item && item.interval===15000 && "running" in item},[])
                    if(!test.check(panel.sectionCatalog.entry("syncthing")===null && !panel.sectionVisible("syncthing") && !coldSync.panelOpened && !coldTimer.running && service.syncthingDeviceId==="","failed or missing catalogue entry cannot poll a stored-hidden expanded provider"))return
                    if(!test.check(coldSync.linkedId===linkedId && panel.syncthingExpanded,"cold provider guard is tested with a real valid saved identity and expanded preference"))return
                    if(!test.check(typeof panel.sectionCatalog.error==="string" && panel.sectionCatalog.error.length>0 && panel.sectionCatalog.error.length<=512 && named(panel,"daily-section-error").visible,"catalogue failure has bounded visible recovery text"))return
                    var coldPicker=named(panel,"daily-device-selector")
                    if(!test.check(panel.sectionVisible("devices") && coldPicker.visible && coldPicker.count===2 && coldPicker.currentValue==="A","required device picker remains usable without optional catalogue data"))return
                    named(panel,"daily-view-menu").forceActiveFocus();events.keyClick(Qt.Key_Space,Qt.NoModifier,1);test.phase=1002
                }else if(test.phase===1002){
                    var coldNav=named(panel,"daily-navigation")
                    if(!test.check(coldNav.menuOpen,"view navigation still opens after catalogue failure"))return
                    events.keyClick(Qt.Key_Down,Qt.NoModifier,1);events.keyClick(Qt.Key_Down,Qt.NoModifier,1);events.keyClick(Qt.Key_Return,Qt.NoModifier,1);test.phase=1003
                }else if(test.phase===1003){
                    if(!test.check(panel.currentView==="Activity","keyboard navigation still reaches Activity after catalogue failure"))return
                    named(panel,"daily-navigation").choose("Devices")
                    named(panel,"daily-device-selector").selectDevice("B");test.phase=1004
                }else if(test.phase===1004){
                    if(!test.check(panel.currentView==="Devices" && named(panel,"daily-device-selector").currentValue==="B" && service.selectedDeviceId==="B" && service.syncthingDeviceId==="","device switching survives catalogue failure without activating the hidden provider"))return
                    console.log("COLD_CATALOG_PASS "+savedSettings.fixtureCatalogFailure+" "+JSON.stringify(checks));console.log("NATIVE_PASS cold catalogue guard");Qt.quit()
                }else if(test.phase===1 && service.selectionState==="draft"){
                    fileDraft=JSON.stringify(service.draftTarget)+JSON.stringify(service.selection)
                    if(!test.check(tabHeaderOrder()==="section-toggle-actions,section-toggle-drop","initial real Tab order follows visible section order"))return
                    if(!test.check(preserve(),"local address, composer and file review exist before moving"))return
                    panel.setSectionExpanded("actions",false)
                    if(!test.check(widgets.actions.expanded && panel.sectionBodyVisible("actions") && named(panel,"section-toggle-actions").Accessible.name==="Collapse Quick actions","forced composer visibility shares the effective expanded state"))return
                    var composerHeader=named(panel,"section-toggle-actions")
                    composerHeader.forceActiveFocus()
                    composerHeader.Accessible.pressAction()
                    if(!test.check(panel.activeComposer==="none" && !panel.actionsExpanded && !widgets.actions.expanded && !panel.sectionBodyVisible("actions"),"Collapse closes a forced composer section in one action"))return
                    if(!test.check(preview.activeFocusItem===composerHeader,"collapsing a composer keeps keyboard focus on its disclosure"))return
                    if(!test.check(panel.draftText==="Composition draft","collapsing a composer keeps its unsent text"))return
                    panel.setSectionExpanded("actions",true);panel.openComposer("text");panel.draftText="Composition draft"
                    panel.openSettings("Appearance");test.phase=2
                }else if(test.phase===2 && panel.settingsWindow.visible && editor()){
                    var rows=panel.sectionCatalog.order.every(function(id){return test.named(editor(),"section-order-row-"+id)!==null})
                    if(!test.check(rows,"actual Settings editor keeps all ten rows including hidden sections"))return
                    accessible(editor(),"Move Quick actions down").Accessible.pressAction()
                    test.phase=3
                }else if(test.phase===3 && !editor().busy && panel.sectionCatalog.order[1]==="drop" && order()===panel.sectionCatalog.order.join(",")){
                    if(!test.check(preserve(),"host-saved reorder moves the same widgets and preserves all drafts"))return
                    panel.settingsWindow.closeSettings();panel.open();preview.requestActivate();test.phase=4
                }else if(test.phase===4){
                    if(!test.check(widgets.drop.y<widgets.actions.y && tabHeaderOrder()==="section-toggle-drop,section-toggle-actions","actual visual and Tab order change together after live move"))return
                    panel.openSettings("Appearance");test.phase=5
                }else if(test.phase===5 && panel.settingsWindow.visible && !editor().busy){
                    accessible(editor(),"Move Quick actions up").Accessible.pressAction();test.phase=6
                }else if(test.phase===6 && !editor().busy && order()===defaults.join(",")){
                    if(!test.check(preserve(),"moving back does not recreate or reset a section"))return
                    accessible(editor(),"Move Syncthing identity note up").Accessible.pressAction();test.phase=7
                }else if(test.phase===7 && !editor().busy && panel.sectionCatalog.order[8]==="syncthing" && order()===panel.sectionCatalog.order.join(",")){
                    if(!test.check(!panel.sectionVisible("syncthing") && preserve(),"hidden row still moves in Settings without losing daily state"))return
                    beforeAllHidden=savedSettings
                    var hidden={};panel.sectionCatalog.entries.forEach(function(entry){if(entry.visibilityKey)hidden[entry.visibilityKey]=false})
                    patchSettings(hidden);test.phase=71
                }else if(test.phase===71){
                    var allRows=panel.sectionCatalog.order.every(function(id,index){
                        var row=named(editor(),"section-order-row-"+id)
                        var entry=panel.sectionCatalog.entry(id)
                        var move=accessible(row,"Move "+entry.label+(index>0?" up":" down"))
                        return row && move && move.enabled && (!entry.visibilityKey || !row.shown)
                    })
                    if(!test.check(allRows && preserve(),"all ten Settings rows remain movable when every optional section is stored hidden"))return
                    savedSettings=beforeAllHidden
                    panel.settingsWindow.closeSettings();panel.open();preview.requestActivate();test.phase=8
                }else if(test.phase===8){
                    named(panel,"section-toggle-addresses").Accessible.pressAction();test.phase=9
                }else if(test.phase===9){
                    if(!test.check(!panel.addressesExpanded && preserve(),"collapse preserves the same unsaved address and removal review"))return
                    named(panel,"section-toggle-addresses").Accessible.pressAction()
                    patchSettings({showSavedAddresses:false});test.phase=10
                }else if(test.phase===10){
                    if(!test.check(!panel.sectionVisible("addresses") && preserve(),"hiding keeps the same address widget and drafts"))return
                    patchSettings({showSavedAddresses:true});named(panel,"section-toggle-native").Accessible.pressAction();test.phase=11
                }else if(test.phase===11){
                    if(!test.check(panel.nativeFeaturesExpanded && preserve(),"native feature header expands without resetting other sections"))return
                    named(panel,"section-toggle-native").Accessible.pressAction()
                    var bth=test.find(panel,function(item){return "helperPathValid" in item && "wantedMode" in item},[])
                    var sync=test.find(panel,function(item){return "linkedId" in item && "draftPeerId" in item},[])
                    var bthTimer=test.find(bth,function(item){return "interval" in item && item.interval===5000 && "running" in item},[])
                    var syncTimer=test.find(sync,function(item){return "interval" in item && item.interval===15000 && "running" in item},[])
                    if(!test.check(!bth.panelOpened && !bthTimer.running && sync.linkedId===linkedId && !sync.panelOpened && !syncTimer.running && service.syncthingDeviceId==="","collapsed/hidden provider guard "+JSON.stringify({bth:bth.panelOpened,bthTimer:bthTimer.running,linked:sync.linkedId,sync:sync.panelOpened,syncTimer:syncTimer.running,selected:service.selectedDeviceId,readId:service.syncthingDeviceId,appearanceError:service.appearance.error})))return
                    patchSettings({showSyncthingLinks:true});test.phase=111
                }else if(test.phase===111){
                    var syncCollapsed=find(panel,function(item){return "linkedId" in item && "draftPeerId" in item},[])
                    if(!test.check(panel.sectionVisible("syncthing") && !panel.sectionExpanded("syncthing") && !syncCollapsed.panelOpened && service.syncthingDeviceId==="","shown but collapsed Syncthing does not read its linked provider"))return
                    patchSettings({showNetworkControls:false,showSyncthingLinks:false})
                    panel.setSectionExpanded("connections",true);panel.setSectionExpanded("syncthing",true);test.phase=112
                }else if(test.phase===112){
                    var hiddenBth=find(panel,function(item){return "helperPathValid" in item && "wantedMode" in item},[])
                    var hiddenSync=find(panel,function(item){return "linkedId" in item && "draftPeerId" in item},[])
                    if(!test.check(!panel.sectionVisible("connections") && !panel.sectionVisible("syncthing") && !hiddenBth.panelOpened && !hiddenSync.panelOpened && service.syncthingDeviceId==="","stored-hidden providers stay stopped even with expanded session state"))return
                    patchSettings({sectionOrder:"unknown,devices"});test.phase=12
                }else if(test.phase===12 && order()===defaults.join(",")){
                    if(!test.check(panel.sectionCatalog.error!=="" && preserve(),"invalid stored order falls back to metadata without losing widget state"))return
                    patchSettings({sectionOrder:"addresses"});test.phase=13
                }else if(test.phase===13 && order()===["addresses"].concat(defaults.filter(function(id){return id!=="addresses"})).join(",")){
                    if(!test.check(sameWidgets() && panel.sectionCatalog.order.length===10 && preserve(),"partial known order appends omitted metadata sections without recreating them"))return
                    named(panel,"daily-device-selector").selectDevice("B");test.phase=14
                }else if(test.phase===14){
                    if(!test.check(address.text==="" && addressSection.removalReview==="" && fileDraft===JSON.stringify(service.draftTarget)+JSON.stringify(service.selection),"peer switch clears unsafe address drafts but keeps the captured file recipient"))return
                    service.cancelDraft();panel.selectDevice("A")
                    patchSettings({showInlineSend:false,inlineSendStartExpanded:false,showSavedAddresses:true,addressesStartExpanded:true,nativeFeaturesStartExpanded:true,sectionOrder:defaults.filter(function(id){return id!=="drop"}).concat(["drop"]).join(",")})
                    panel.setSectionExpanded("drop",false);panel.currentView="Activity";panel.close();test.phase=15
                }else if(test.phase===15 && service.selectionState!=="draft"){
                    var icon=named(widget,"bar-file-drop-area")
                    if(!test.check(!icon.acceptDrag(drag(Qt.MoveAction)) && !panel.opened,"Move-only hover cannot open a review target"))return
                    if(!test.check(icon.acceptDrag(drag(Qt.CopyAction|Qt.MoveAction)),"actual bar Copy hover accepts the file and opens its real Panel"))return
                    test.phase=16
                }else if(test.phase===16 && panel.opened && panel.currentView==="Devices"){
                    if(!test.check(panel.sectionVisible("drop") && panel.sectionExpanded("drop") && savedSettings.showInlineSend===false && savedSettings.inlineSendStartExpanded===false,"hover reveals and expands stored-hidden inline sharing without changing preferences"))return
                    var scroll=named(panel,"daily-content-scroll")
                    var top=widgets.drop.mapToItem(scroll,0,0).y
                    var scrolled=top>=-1 && top<scroll.availableHeight && scroll.contentItem.contentY>0
                    if(!scrolled && ++hoverFrames<4)return
                    if(!test.check(scrolled,"hover scroll geometry "+JSON.stringify({top:top,contentY:scroll.contentItem.contentY,contentHeight:scroll.contentHeight,available:scroll.availableHeight,dropY:widgets.drop.y,dropHeight:widgets.drop.height,order:order()})))return
                    focusState=currentDraftState()
                    named(panel,"daily-device-selector").forceActiveFocus()
                    test.phase=160
                }else if(test.phase===160){
                    var focused=preview.activeFocusItem,viewport=named(panel,"daily-content-scroll"),ancestor=focused,inside=false
                    while(ancestor){if(ancestor===groups){inside=true;break}ancestor=ancestor.parent}
                    var direction=focusSteps<=65?"forward":"backward"
                    if(focused && inside){
                        var point=focused.mapToItem(viewport,0,0)
                        var bounds={direction:direction,step:focusSteps,name:focused.objectName,label:focused.Accessible?focused.Accessible.name:"",top:point.y,bottom:point.y+focused.height,viewport:viewport.availableHeight,contentY:viewport.contentItem.contentY}
                        if(point.y< -1 || point.y+focused.height>viewport.availableHeight+1){test.check(false,"Tab focus stays inside daily viewport "+JSON.stringify(bounds));return}
                        focusCounts[direction]++
                        if(focused.objectName.indexOf("section-toggle-")===0 && focusHeaders[direction].indexOf(focused.objectName)<0)focusHeaders[direction].push(focused.objectName)
                    }
                    if(focusSteps>=130){
                        var traversed=["forward","backward"].every(function(dir){return focusCounts[dir]>10 && focusHeaders[dir].indexOf("section-toggle-actions")>=0 && focusHeaders[dir].indexOf("section-toggle-drop")>=0})
                        if(!test.check(traversed,"actual Tab and Shift+Tab reveal daily controls across reordered sections "+JSON.stringify(focusCounts)))return
                        if(!test.check(sameWidgets() && currentDraftState()===focusState && service.operations.length===0 && !service.operationBusy,"focus traversal preserves section objects and drafts without activation"))return
                        test.phase=161;return
                    }
                    focusSteps++
                    events.keyClick(Qt.Key_Tab,focusSteps<=65?Qt.NoModifier:Qt.ShiftModifier,1)
                }else if(test.phase===161){
                    var drop=drag(Qt.CopyAction|Qt.MoveAction)
                    if(!test.check(named(panel,"inline-send-drop-zone").acceptFiles(drop) && drop.action===Qt.CopyAction,"actual inline zone stages Copy review only"))return
                    test.phase=17
                }else if(test.phase===17 && service.selectionState==="draft"){
                    var review=named(panel,"inline-send-review")
                    if(!test.check(review.visible && review.target.peerId==="A" && review.files.length===1 && service.operations.length===0 && !service.operationBusy,"review stays inline for A with no automatic submission"))return
                    named(panel,"daily-device-selector").selectDevice("B")
                    if(!test.check(service.draftTarget.peerId==="A" && service.selection.length===1 && !named(panel,"inline-send-drop-zone").ready,"switching B cannot retarget or replace the captured A review"))return
                    panel.setSectionExpanded("actions",false);panel.setSectionExpanded("native",false)
                    test.phase=170
                }else if(test.phase===170 && service.quickShareAvailable){
                    if(!test.check(service.openKdeConnectApp() && service.openQuickShare(),"private native and Quick Share launch doubles start explicitly"))return
                    test.phase=18
                }else if(test.phase===18){
                    var quick=named(panel,"collapsed-launch-status-quick-share"),native=named(panel,"collapsed-launch-status-native")
                    if(!test.check(service.quickShareOpening && service.nativeAppOpening && quick.visible && quick.text==="Opening RQuickShare…" && native.visible && native.text==="Opening KDE Connect","actual pending provider feedback remains visible outside collapsed owner sections"))return
                    test.phase=19
                }else if(test.phase===19 && !service.quickShareOpening && !service.nativeAppOpening){
                    service.cancelDraft()
                    console.log("SECTION_COMPOSITION_PASS "+JSON.stringify(checks));console.log("NATIVE_PASS actual section composition");Qt.quit()
                }
            }finally{test.dispatching=false}
        }
    }
}
