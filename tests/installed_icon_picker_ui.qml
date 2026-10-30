import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import "plugin/components" as Components

Window {
    id: test
    width:520;height:440;visible:true
    property int phase:0
    property bool dispatching:false
    property int changes:0
    property int captures:0
    property string draft:""
    readonly property string persisted:"original"
    Rectangle {anchors.fill:parent;color:"#141414"}
    Components.InstalledIconPicker {
        id: picker
        x:20;y:330;width:480
        foreground:"#eeeeee";background:"#141414"
        options:Array.from({length:1300},function(_,i){return "icon-"+String(i).padStart(4,"0")})
        value:test.draft
        onChanged:function(value){test.draft=value;test.changes++}
    }
    TestCase {id:events;when:false}
    Item { TestEvent {id:pointerEvents} }
    function all(item, predicate, seen) {
        var found=[]
        seen=seen || []
        if(!item || seen.indexOf(item)!==-1)return found
        seen.push(item)
        if(predicate(item))found.push(item)
        for(var property of ["children","data"]) {
            var children=item[property] || []
            for(var i=0;i<children.length;i++)found=found.concat(all(children[i],predicate,seen))
        }
        if(item.contentItem)found=found.concat(all(item.contentItem,predicate,seen))
        return found
    }
    function named(name) {
        var found=all(test.contentItem,function(item){return item.objectName===name})
        return found.length?found[0]:null
    }
    function check(value,message) {
        if(value)return true
        console.error("NATIVE_FAIL picker: "+message);Qt.quit();return false
    }
    Timer {
        interval:100;running:true;repeat:true
        onTriggered: {
            if(test.dispatching)return
            test.dispatching=true
            try {
            var trigger=test.named("installed-icon-trigger")
            var popup=test.named("installed-icon-popup")
            var search=test.named("installed-icon-search")
            var results=test.named("installed-icon-results")
            if(test.phase===0){
                picker.y=25
                if(!test.check(pointerEvents.mouseClick(trigger,trigger.width/2,trigger.height/2,Qt.LeftButton,Qt.NoModifier,1),"first real trigger click is delivered"))return
                test.phase=-1;return
            }
            if(test.phase===-1){
                if(!test.check(picker.popupOpen,"first real trigger click opens picker"))return
                pointerEvents.mouseClick(trigger,trigger.width/2,trigger.height/2,Qt.LeftButton,Qt.NoModifier,1)
                test.phase=-2;return
            }
            if(test.phase===-2){
                if(!test.check(!picker.popupOpen && test.changes===0,"second real trigger click closes without selecting or reopening"))return
                picker.open();test.phase=-3;return
            }
            if(test.phase===-3){
                pointerEvents.mouseClick(test.contentItem,4,4,Qt.LeftButton,Qt.NoModifier,1)
                test.phase=-4;return
            }
            if(test.phase===-4){
                if(!test.check(!picker.popupOpen && test.changes===0,"click outside popup and trigger closes without choosing"))return
                picker.y=330;trigger.forceActiveFocus();events.keyClick(Qt.Key_Space);test.phase=1;return
            }
            if(test.phase===1){
                if(!test.check(picker.popupOpen && search.activeFocus,"Space opens a focused search"))return
                if(!test.check(popup.parent.mapToItem(picker.overlayItem,popup.x,popup.y).x>=0 && popup.parent.mapToItem(picker.overlayItem,popup.x,popup.y).y>=0 && popup.parent.mapToItem(picker.overlayItem,popup.x,popup.y).x+popup.width<=test.width && popup.parent.mapToItem(picker.overlayItem,popup.x,popup.y).y+popup.height<=test.height,"popup fits the minimum-height window"))return
                if(!test.check(results.count===1024,"inventory is bounded"))return
                var thumbs=test.all(results,function(item){return item.objectName==="installed-icon-thumbnail"})
                if(!test.check(thumbs.length>=2 && thumbs.length<=12,"only visible rows allocate thumbnails: "+thumbs.length))return
                for(var i=0;i<2;i++) {
                    if(!test.check(thumbs[i].imageReady && !thumbs[i].fallback,"fake installed source loads for each row"))return
                    (function(item,index){item.grabToImage(function(result){result.saveToFile(Qt.resolvedUrl("picker-icon-"+index+".png").toString().replace("file://",""));test.captures++})})(thumbs[i],i)
                }
                test.contentItem.grabToImage(function(result){result.saveToFile(Qt.resolvedUrl("picker-open.png").toString().replace("file://",""));test.captures++})
                test.phase++;return
            }
            if(test.phase===2){
                if(test.captures!==3)return
                search.text="ICON-001";test.phase=20;return
            }
            if(test.phase===20){
                if(!test.check(results.count===10,"search matches case-insensitively"))return
                events.keyClick(Qt.Key_Down);test.phase=3;return
            }
            if(test.phase===3){events.keyClick(Qt.Key_Down);events.keyClick(Qt.Key_Return);test.phase++;return}
            if(test.phase===4){
                if(!test.check(test.draft==="icon-0011" && test.changes===1 && test.persisted==="original" && !picker.popupOpen,"Enter changes only the draft"))return
                if(!test.check(trigger.activeFocus,"selection restores trigger focus"))return
                events.keyClick(Qt.Key_Return);test.phase++;return
            }
            if(test.phase===5){
                if(!test.check(picker.popupOpen,"Enter opens picker"))return
                search.text="no-match";test.phase++;return
            }
            if(test.phase===6){events.keyClick(Qt.Key_Return);test.phase++;return}
            if(test.phase===7){
                if(!test.check(results.count===0 && test.changes===1 && picker.popupOpen,"empty search cannot choose a stale row"))return
                events.keyClick(Qt.Key_Escape);test.phase++;return
            }
            if(test.phase===8){
                if(!test.check(!picker.popupOpen && trigger.activeFocus && search.text==="","Escape clears search and restores focus"))return
                events.keyClick(Qt.Key_Down);test.phase++;return
            }
            if(test.phase===9){
                if(!test.check(picker.popupOpen,"Down opens picker"))return
                picker.close();trigger.Accessible.pressAction();test.phase++;return
            }
            if(test.phase===10){
                if(!test.check(picker.popupOpen,"named trigger AT action opens picker"))return
                results.positionViewAtIndex(1000,ListView.Beginning);test.phase=21;return
            }
            if(test.phase===21){
                var visibleThumbs=test.all(results,function(item){return item.objectName==="installed-icon-thumbnail"})
                if(!test.check(visibleThumbs.length<=20,"scrolling keeps thumbnail allocation bounded: "+visibleThumbs.length))return
                var option=test.named("installed-icon-option-1000")
                if(!test.check(option && option.Accessible.name==="icon-1000","scrolled option has its full name"))return
                option.Accessible.pressAction();test.phase++;return
            }
            if(test.phase===22 && test.captures===3){
                if(!test.check(test.draft==="icon-1000" && test.changes===2 && !picker.popupOpen,"named option AT action chooses draft"))return
                picker.open();picker.options=picker.options.slice();test.phase=220;return
            }
            if(test.phase===220){
                if(!test.check(picker.popupOpen,"identical icon inventory keeps the picker open"))return
                picker.options=["icon-0100"];test.phase=23;return
            }
            if(test.phase===23){
                if(!test.check(!picker.popupOpen && test.changes===2 && test.draft==="icon-1000","changed inventory closes stale choices without selecting"))return
                picker.open();test.phase=24;return
            }
            if(test.phase===24){
                if(!test.check(picker.popupOpen,"single-result popup opens before moving trigger"))return
                picker.close();picker.y=25;picker.x=35;test.phase=25;return
            }
            if(test.phase===25){picker.open();test.phase=26;return}
            if(test.phase===26){
                var position=picker.mapToItem(picker.overlayItem,0,picker.height)
                var actual=popup.parent.mapToItem(picker.overlayItem,popup.x,popup.y)
                var expectedY=Math.max(popup.margin,Math.min(position.y,picker.overlayItem.height-popup.height-popup.margin))
                var expectedX=Math.max(popup.margin,Math.min(position.x,picker.overlayItem.width-popup.width-popup.margin))
                if(!test.check(Math.abs(actual.y-expectedY)<1 && Math.abs(actual.x-expectedX)<1,"reopened popup follows moved trigger"))return
                test.width=400;test.height=300;test.phase=27;return
            }
            if(test.phase===27){
                var actual=popup.parent.mapToItem(picker.overlayItem,popup.x,popup.y)
                if(!test.check(actual.x>=popup.margin && actual.y>=popup.margin && actual.x+popup.width<=picker.overlayItem.width-popup.margin+1 && actual.y+popup.height<=picker.overlayItem.height-popup.margin+1,"open popup stays within resized overlay"))return
                var option=test.named("installed-icon-option-0")
                if(!test.check(option && pointerEvents.mouseClick(option,option.width/2,option.height/2,Qt.LeftButton,Qt.NoModifier,1),"real pointer click reaches a popup option"))return
                test.phase=28;return
            }
            if(test.phase===28){
                if(!test.check(!picker.popupOpen && test.draft==="icon-0100" && test.changes===3 && test.persisted==="original","real pointer selection changes only the draft and closes the popup"))return
                console.log("NATIVE_PASS installed icon picker");Qt.quit()
            }
            } finally { test.dispatching=false }
        }
    }
    Timer {interval:5000;running:true;onTriggered:{test.check(false,"scenario deadline");Qt.quit()}}
}
