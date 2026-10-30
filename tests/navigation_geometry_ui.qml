import QtQuick
import QtQuick.Window
import Quickshell
import "plugin" as Plugin

ShellRoot {
    id: test
    property int tick: 0
    property int step: 0
    property int wait: 0
    property bool capturing: false
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
        Plugin.Panel{id:panel;bar:bar;anchorItem:anchor;settings:({showSavedAddresses:false,showNativeFeatures:false})}
    }
    Timer{
        interval:40;running:true;repeat:true
        onTriggered:{
            if(++test.tick>160){test.fail("deadline");return}
            if(service.devices.length!==2 || test.capturing)return
            var nav=test.find(panel,"daily-navigation",[])
            var scroll=test.find(panel,"daily-content-scroll",[])
            var popup=test.find(panel,"daily-view-popup",[])
            if(!nav || !scroll || !popup)return
            if(test.wait===0){
                if(test.step>=6){console.log("GEOMETRY_PASS "+JSON.stringify(test.samples));console.log("NATIVE_PASS fitted navigation geometry");Qt.quit();return}
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
            test.samples.push({view:panel.currentView,position:top?"Top":"Bottom",height:nav.parent.height,navigationY:nav.y,navigationHeight:nav.height,scrollY:scroll.y,scrollHeight:scroll.height,menuY:popup.y+nav.y,menuHeight:popup.height,triggerWidth:nav.focusItem.width,lastRouteVisible:lastVisible})
            if(!inside || !separate || !menuInside || !rowFits || !lastVisible){test.fail(JSON.stringify(test.samples));return}
            nav.closeMenu()
            test.step++;test.wait=0
        }
    }
}
