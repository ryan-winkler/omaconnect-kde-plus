import QtQuick
import QtQuick.Window
import Quickshell
import "components" as Components

ShellRoot {
    QtObject {
        id: fixtureBar
        property color foreground: "white"
        property string fontFamily: "sans-serif"
    }
    QtObject {
        id: fixtureService
        property var mediaState: ({
            title: Quickshell.env("SECURITY_FIXTURE_TITLE"),
            artist: "Owned artist", album: "Owned album", player: "Owned player",
            playerList: ["Owned player"], isPlaying: true,
            albumArt: Quickshell.env("SECURITY_FIXTURE_ART")
        })
    }
    QtObject {
        id: fixturePanel
        property var bar: fixtureBar
        property var service: fixtureService
        property var device: ({id:"owned-peer",name:"Owned peer",paired:true,reachable:true})
        property bool mediaPlayerVisible: true
        property bool mediaExpanded: Quickshell.env("SECURITY_FIXTURE_EXPANDED") === "1"
        property bool cursorActive: false
        property string focusSection: ""
        property int mediaControlIndex: 0
        function toggleMediaExpanded() {}
    }
    Window {
        width: 520
        height: 650
        visible: true
        Components.MediaPlayerSection { id: section; panel: fixturePanel; width: 500 }
    }
    Timer {
        interval: 800
        running: true
        onTriggered: {
            if (section.trackTitle !== fixtureService.mediaState.title
                || section.trackArtist !== "Owned artist"
                || section.trackPlayer !== "Owned player"
                || !section.isPlaying) {
                console.error("SECURITY_MEDIA_FAIL valid text/control state changed")
            } else {
                console.log("SECURITY_MEDIA_PASS")
            }
            Qt.quit()
        }
    }
}
