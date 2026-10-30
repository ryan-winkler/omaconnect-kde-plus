import QtQuick
import QtQuick.Window
import Quickshell
import qs.Commons as Commons
import "plugin/components" as Components

Window {
    id: test
    width:440; height:160; visible:true
    property string iconForeground: "#f0f0f0"
    property int phase: 0
    property int pending: 0
    property bool swapped: false
    color: phase < 2 ? "#171717" : "#ffffff"
    Rectangle {anchors.fill:parent;color:test.color}
    function capture(label) {
        pending=icons.count+1
        for(var i=0;i<icons.count;i++) {
            (function(item,index) {
                item.grabToImage(function(result) {
                    result.saveToFile(Qt.resolvedUrl(label+"-"+index+".png").toString().replace("file://",""))
                    test.pending--
                })
            })(icons.itemAt(i).iconItem,i)
        }
        contentItem.grabToImage(function(result) {
            result.saveToFile(Qt.resolvedUrl(label+".png").toString().replace("file://",""))
            test.pending--
        })
    }
    Row {
        x:20;y:24;spacing:28
        Repeater {
            id: icons
            model:[
                {name:"Installed desktop",value:"computer-symbolic"},
                {name:"Installed phone",value:"phone-symbolic"},
                {name:"Custom colours",source:"",custom:true}
            ]
            Column {
                required property var modelData
                required property int index
                property alias iconItem: preview
                spacing:16
                Components.AppearanceIcon {
                    id: preview
                    width:64;height:64
                    icon:modelData.custom ? ({mode:"image",value:"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.svg",render:"color"}) : ({mode:"theme",value:test.swapped && index===0 ? "phone-symbolic" : modelData.value,render:"symbolic"})
                    // Native provider path fallback keeps this offscreen fixture independent of a desktop theme.
                    themedSource: modelData.custom ? "" : "image://icon/" + (test.swapped && index===0 ? "phone-symbolic" : modelData.value) + ".svg?path=usr/share/icons/Adwaita/symbolic/devices"
                    assetBaseUrl:Qt.resolvedUrl("assets/").toString()
                    foreground:test.iconForeground
                }
                Text {text:modelData.name;color:test.iconForeground;font.pixelSize:12}
            }
        }
    }
    Components.AppearanceIcon {
        id: nativeDefault
        visible:false
    }
    Timer {
        interval:100;running:true;repeat:true
        onTriggered: {
            if(test.phase===0) {
                for(var i=0;i<icons.count;i++) if(!icons.itemAt(i).iconItem.imageReady)return
                if(nativeDefault.foreground!==Commons.Color.foreground) {console.error("NATIVE_FAIL default foreground ignores native theme");Qt.quit();return}
                test.capture("dark");test.phase=1
            } else if(test.phase===1 && test.pending===0) {
                test.iconForeground="#202020";test.phase=2
            } else if(test.phase===2) {
                test.capture("light");test.phase=3
            } else if(test.phase===3 && test.pending===0) {
                test.swapped=true;test.phase=4
            } else if(test.phase===4) {
                test.capture("replaced");test.phase=5
            } else if(test.phase===5 && test.pending===0) {
                console.log("NATIVE_PASS appearance pixels");Qt.quit()
            }
        }
    }
    Timer {interval:4000;running:true;onTriggered:{console.error("NATIVE_FAIL render deadline");Qt.quit()}}
}
