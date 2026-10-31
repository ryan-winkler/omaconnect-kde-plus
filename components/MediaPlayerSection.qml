pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Column {
    id: root

    required property var panel

    width: parent ? parent.width : 0
    spacing: Style.space(6)
    visible: !!(panel && panel.mediaPlayerVisible)

    readonly property var bar: panel ? panel.bar : null
    readonly property var service: panel ? panel.service : null
    readonly property var device: panel ? panel.device : null
    readonly property color foreground: bar ? bar.foreground : "#ffffff"
    readonly property string fontFamily: bar ? bar.fontFamily : "sans-serif"

    readonly property var media: (service && service.mediaState) ? service.mediaState : null
    readonly property bool hasMedia: !!(media && (media.title || media.artist || media.album || media.player))
    readonly property bool isPlaying: !!(media && media.isPlaying)
    readonly property string trackTitle: (media && media.title) ? media.title : "Nothing playing"
    readonly property string trackArtist: (media && media.artist) ? media.artist : ""
    readonly property string trackAlbum: (media && media.album) ? media.album : ""
    readonly property string trackPlayer: (media && media.player) ? media.player : ""
    readonly property var playerList: (media && Array.isArray(media.playerList)) ? media.playerList : []

    PanelSeparator {
        foreground: root.foreground
    }

    CursorSurface {
        id: collapsedBar
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: "Expand media controls"
        Accessible.description: "Control music and video playing on the selected device. If it reports more than one player, choose one."
        Accessible.onPressAction: panel.toggleMediaExpanded()
        Keys.onReturnPressed: panel.toggleMediaExpanded()
        Keys.onEnterPressed: panel.toggleMediaExpanded()
        Keys.onSpacePressed: panel.toggleMediaExpanded()
        visible: !panel.mediaExpanded
        width: parent.width
        implicitHeight: Math.max(32, Style.space(32))
        hasCursor: panel.cursorActive && panel.focusSection === "media" && !panel.mediaExpanded
        radius: Style.cornerRadius
        foreground: root.foreground
        fill: Style.hoverFillFor(root.foreground, Commons.Color.accent)
        currentFill: Style.selectedFillFor(root.foreground, Commons.Color.accent)

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: {
                panel.cursorActive = true
                panel.focusSection = "media"
            }
            onClicked: panel.toggleMediaExpanded()
        }

        Text {
            textFormat: Text.PlainText
            id: musicIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.isPlaying ? "󰝚" : "󰎈"
            color: root.isPlaying ? Commons.Color.accent : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
        }

        Text {
            textFormat: Text.PlainText
            id: chevronIcon
            anchors.right: parent.right
            anchors.rightMargin: Style.space(2)
            anchors.verticalCenter: parent.verticalCenter
            text: "󰅀"
            color: Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
        }

        Text {
            textFormat: Text.PlainText
            id: titleText
            anchors.left: musicIcon.right
            anchors.leftMargin: Style.space(6)
            anchors.right: chevronIcon.left
            anchors.rightMargin: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter
            text: root.trackTitle + (root.trackArtist ? "  •  " + root.trackArtist : "")
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            elide: Text.ElideRight
        }
    }

    Rectangle {
        id: mediaCard
        visible: panel.mediaExpanded
        width: parent.width
        implicitHeight: cardContent.implicitHeight + Style.space(20)
        radius: Style.cornerRadius
        color: Style.hoverFillFor(root.foreground, Commons.Color.accent)
        border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
        border.width: 1
        clip: true

        PanelActionButton {
            id: minimizeBtn
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Style.space(8)
            iconText: "󰅃"
            tooltipText: "Collapse media controls"
            focusable: true
            Accessible.role: Accessible.Button
            Accessible.name: "Collapse media controls"
            Accessible.onPressAction: panel.toggleMediaExpanded()
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: panel.toggleMediaExpanded()
            z: 2
        }

        Column {
            id: cardContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Style.space(10)
            spacing: Style.space(10)

            Row {
                width: parent.width
                spacing: Style.space(10)

                Rectangle {
                    id: coverFrame
                    width: Style.space(72)
                    height: width
                    radius: Style.cornerRadius
                    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
                    border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
                    border.width: 1
                    clip: true

                    Text {
                        textFormat: Text.PlainText
                        anchors.centerIn: parent
                        text: "󰎈"
                        color: root.hasMedia ? Commons.Color.accent : Qt.darker(root.foreground, 1.5)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.display
                    }
                }

                Column {
                    width: Math.max(1, parent.width - coverFrame.width - Style.space(10) - minimizeBtn.implicitWidth)
                    spacing: Style.space(4)
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        textFormat: Text.PlainText
                        width: parent.width
                        text: root.trackTitle
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        textFormat: Text.PlainText
                        width: parent.width
                        visible: root.trackArtist !== "" || root.trackAlbum !== ""
                        text: {
                            if (root.trackArtist && root.trackAlbum) return root.trackArtist + "  •  " + root.trackAlbum
                            return root.trackArtist || root.trackAlbum
                        }
                        color: Qt.darker(root.foreground, 1.3)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                    }

                    Text {
                        textFormat: Text.PlainText
                        width: parent.width
                        visible: !root.hasMedia
                        text: root.device && root.device.name ? "Open media on " + root.device.name : "No active player"
                        color: Qt.darker(root.foreground, 1.45)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                    }

                    Flow {
                        id: playerControlsRow
                        visible: root.playerList.length > 0 || root.trackPlayer !== ""
                        width: parent.width
                        spacing: Style.space(6)

                        Repeater {
                            model: root.playerList.length > 0 ? root.playerList : (root.trackPlayer !== "" ? [root.trackPlayer] : [])
                            delegate: Button {
                                id: playerChip
                                required property string modelData
                                required property int index
                                readonly property bool isCurrent: modelData === root.trackPlayer
                                objectName: "media-player-" + index
                                width: Math.min(playerControlsRow.width, implicitWidth)
                                text: isCurrent ? "Current: " + modelData : modelData
                                iconText: "󰐌"
                                tooltipText: isCurrent ? "Current player" : "Choose this player"
                                selected: isCurrent
                                focusable: true
                                enabled: !isCurrent && root.playerList.length > 1 && !!root.service && !!root.device
                                implicitHeight: Math.max(44, Style.space(32))
                                foreground: root.foreground
                                fontFamily: root.fontFamily
                                fontSize: Style.font.bodySmall
                                Accessible.role: Accessible.Button
                                Accessible.name: (isCurrent ? "Current player " : "Choose player ") + modelData
                                Accessible.description: isCurrent ? "Current player" : "Select this reported player on the selected device."
                                Accessible.onPressAction: if (enabled) clicked()
                                onClicked: if (enabled) root.service.mediaSelectPlayer(root.device.id, modelData)
                            }
                        }
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Style.space(12)

                PanelActionButton {
                    id: prevBtn
                    objectName: "media-transport-0"
                    iconText: "󰒮"
                    tooltipText: "Previous track"
                    size: Math.max(44, Style.space(44))
                    fontSize: Style.font.title
                    focusable: true
                    enabled: root.hasMedia && !!root.service && !!root.device
                    opacity: enabled ? 1 : 0.4
                    hasCursor: panel.cursorActive && panel.focusSection === "media" && panel.mediaExpanded && panel.mediaControlIndex === 0
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    Accessible.role: Accessible.Button
                    Accessible.name: tooltipText
                    Accessible.description: "Control the selected device's active player."
                    Accessible.onPressAction: if (enabled) clicked()
                    onHovered: function(inside) {
                        if (inside) { panel.cursorActive = true; panel.focusSection = "media"; panel.mediaControlIndex = 0 }
                    }
                    onClicked: if (enabled) root.service.mediaPrevious(root.device.id)
                }

                PanelActionButton {
                    id: playPauseBtn
                    objectName: "media-transport-1"
                    iconText: root.isPlaying ? "󰏤" : "󰐊"
                    tooltipText: root.isPlaying ? "Pause playback" : "Resume playback"
                    size: Math.max(44, Style.space(48))
                    fontSize: Style.font.title
                    focusable: true
                    enabled: root.hasMedia && !!root.service && !!root.device
                    opacity: enabled ? 1 : 0.4
                    hasCursor: panel.cursorActive && panel.focusSection === "media" && panel.mediaExpanded && panel.mediaControlIndex === 1
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    Accessible.role: Accessible.Button
                    Accessible.name: tooltipText
                    Accessible.description: "Control the selected device's active player."
                    Accessible.onPressAction: if (enabled) clicked()
                    onHovered: function(inside) {
                        if (inside) { panel.cursorActive = true; panel.focusSection = "media"; panel.mediaControlIndex = 1 }
                    }
                    onClicked: if (enabled) root.service.mediaPlayPause(root.device.id)
                }

                PanelActionButton {
                    id: nextBtn
                    objectName: "media-transport-2"
                    iconText: "󰒭"
                    tooltipText: "Next track"
                    size: Math.max(44, Style.space(44))
                    fontSize: Style.font.title
                    focusable: true
                    enabled: root.hasMedia && !!root.service && !!root.device
                    opacity: enabled ? 1 : 0.4
                    hasCursor: panel.cursorActive && panel.focusSection === "media" && panel.mediaExpanded && panel.mediaControlIndex === 2
                    foreground: root.foreground
                    fontFamily: root.fontFamily
                    Accessible.role: Accessible.Button
                    Accessible.name: tooltipText
                    Accessible.description: "Control the selected device's active player."
                    Accessible.onPressAction: if (enabled) clicked()
                    onHovered: function(inside) {
                        if (inside) { panel.cursorActive = true; panel.focusSection = "media"; panel.mediaControlIndex = 2 }
                    }
                    onClicked: if (enabled) root.service.mediaNext(root.device.id)
                }
            }
        }
    }
}
