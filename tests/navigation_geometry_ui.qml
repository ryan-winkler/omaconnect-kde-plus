import QtQuick
import QtQuick.Window
import QtTest
import qs.Commons
import Quickshell
import "plugin" as Plugin

ShellRoot {
    id: test
    property int tick: 0
    property int step: 0
    property int wait: 0
    property bool capturing: false
    property bool dispatching: false
    property var samples: []
    function find(item, name, seen) {
        if (!item || seen.indexOf(item)>=0)return null
        seen.push(item)
        if(item.objectName===name)return item
        var lists=[item.children || [],item.data || []]
        for(var l=0;l<lists.length;l++)for(var i=0;i<lists[l].length;i++){
            var found=find(lists[l][i],name,seen);if(found)return found
        }
        if(item.contentItem){var content=find(item.contentItem,name,seen);if(content)return content}
        return null
    }
    function fail(message){console.error("NATIVE_FAIL navigation geometry: "+message);Qt.quit()}
    Plugin.Service{id:service}
    QtObject{id:facade;function serviceFor(id){return service}}
    QtObject{
        id:bar
        property var shell:facade
        property color barForeground:"white"
        property color foreground:"white"
        property string fontFamily:"sans-serif"
    }
    Window{
        id:preview
        visible:true;width:400;height:740
        Item{id:anchor;width:26;height:26}
        Item { TestEvent { id:events } }
        Plugin.Panel{id:panel;bar:bar;anchorItem:anchor;settings:({showSavedAddresses:false,showNativeFeatures:false})}
    }
    Timer{
        interval:40;running:true;repeat:true
        onTriggered:{
            if(test.dispatching)return
            test.dispatching=true
            try {
            if(++test.tick>160){test.fail("deadline");return}
            if(service.devices.length!==2 || test.capturing)return
            var nav=test.find(panel,"daily-navigation",[])
            var scroll=test.find(panel,"daily-content-scroll",[])
            var popup=test.find(panel,"daily-view-popup",[])
            if(!nav || !scroll || !popup)return
            if(test.wait===0){
                if(test.step>=6){console.log("GEOMETRY_PASS "+JSON.stringify(test.samples));console.log("NATIVE_PASS fitted navigation geometry");Qt.quit();return}
                if(test.step===0){
                    var controls=test.find(nav,"daily-navigation-controls",[])
                    if(nav.shortcutsWrapped || controls.height>nav.focusItem.height+1){test.fail("default must stay one quiet row");return}
                }
                panel.settings={navigationAtTop:test.step>=3,showSendShortcut:true,showActivityShortcut:true,showSavedAddresses:false,showNativeFeatures:false}
                panel.currentView=panel.viewNames[test.step%3]
                panel.open();test.wait=1;return
            }
            if(test.wait===1){nav.focusItem.clicked();test.wait=2;return}
            if(!nav.menuOpen)return
            if(test.wait===2){nav.focusMenu(3);test.wait=3;return}
            var top=panel.navigationAtTop
            var inside=nav.y>=-1 && nav.y+nav.height<=nav.parent.height+1
            var separate=top ? scroll.y>=nav.y+nav.height : nav.y>=scroll.y+scroll.height
            var menuInside=popup.y+nav.y>=-1 && popup.y+nav.y+popup.height<=nav.parent.height+1
            var rowFits=nav.focusItem.width>70 && nav.width<=nav.parent.width
            var last=test.find(nav,"daily-route-3",[])
            var lastY=last.mapToItem(popup.contentItem,0,0).y
            var lastVisible=lastY>=-1 && lastY+last.height<=popup.contentItem.height+1
            var send=test.find(nav,"daily-send-shortcut",[]),activity=test.find(nav,"daily-activity-shortcut",[]),settings=test.find(nav,"daily-plus-settings",[])
            var label=(function findText(item){
                if("truncated" in item && item.text===nav.focusItem.text)return item
                var children=item.children || []
                for(var i=0;i<children.length;i++){var hit=findText(children[i]);if(hit)return hit}
                return null
            })(nav.focusItem)
            var wrappedBounds=!nav.shortcutsWrapped || settings.y===nav.focusItem.y && send.y>=nav.focusItem.y+nav.focusItem.height && activity.y===send.y && activity.x>=send.x+send.width && activity.x+activity.width<=nav.width+1
            if(Style.font.baseSize===18 && (!nav.shortcutsWrapped || !wrappedBounds || !label || label.truncated)){test.fail("large text must retain the full view label and wrap shortcuts");return}
            nav.closeMenu()
            nav.focusItem.forceActiveFocus()
            events.keyClick(Qt.Key_Tab,Qt.NoModifier,1)
            var settingsFocused=settings.activeFocus
            events.keyClick(Qt.Key_Tab,Qt.NoModifier,1)
            var sendFocused=send.activeFocus
            events.keyClick(Qt.Key_Tab,Qt.NoModifier,1)
            var activityFocused=activity.activeFocus
            var tabOrder=settingsFocused && sendFocused && activityFocused
            if(!tabOrder){test.fail("Tab order must match View, Settings, Send, Activity");return}
            test.samples.push({baseFont:Style.font.baseSize,spacingScale:Style.spacing.scale,wrapped:nav.shortcutsWrapped,viewTruncated:label.truncated,viewNominalFont:label.font.pixelSize,viewPaintedWidth:label.paintedWidth,wrappedBounds:wrappedBounds,tabOrder:tabOrder,view:panel.currentView,position:top?"Top":"Bottom",height:nav.parent.height,navigationY:nav.y,navigationHeight:nav.height,scrollY:scroll.y,scrollHeight:scroll.height,menuY:popup.y+nav.y,menuHeight:popup.height,triggerWidth:nav.focusItem.width,lastRouteVisible:lastVisible})
            if(!inside || !separate || !menuInside || !rowFits || !lastVisible){test.fail(JSON.stringify(test.samples));return}
            nav.closeMenu()
            test.step++;test.wait=0
            } finally {test.dispatching=false}
        }
    }
}
