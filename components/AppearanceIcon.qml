pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Qt5Compat.GraphicalEffects
import "../Appearance.js" as Appearance

Item {
    id: root
    property var icon: Appearance.phone()
    property color foreground: "white"
    property string fontFamily: "sans-serif"
    property string assetBaseUrl: ""
    property int iconSize: 20
    readonly property var normalized: Appearance.normalizeIcon(icon,false)
    readonly property bool fontMissing: normalized.mode === "glyph" && !!normalized.font && Qt.fontFamilies().indexOf(normalized.font) < 0
    readonly property string themedSource: normalized.mode === "theme" || normalized.mode === "preset" ? Quickshell.iconPath(Appearance.themeFor(normalized),true) : ""
    readonly property string sourceUrl: normalized.mode === "image" && /^file:\/\//.test(assetBaseUrl) ? assetBaseUrl + normalized.value : themedSource
    readonly property bool useGlyph: normalized.mode === "glyph" && !fontMissing
    readonly property bool imageReady: image.status === Image.Ready
    readonly property bool fallback: !useGlyph && (!sourceUrl || image.status === Image.Error || image.status === Image.Null)
    readonly property string warning: fontMissing ? qsTr("Font unavailable. Phone is shown.") : normalized.mode === "image" && fallback ? qsTr("Imported image is unavailable. Phone is shown.") : normalized.mode === "theme" && fallback ? qsTr("Theme icon is unavailable. Phone is shown.") : ""
    implicitWidth: iconSize
    implicitHeight: iconSize
    Accessible.role: Accessible.StaticText
    Accessible.name: normalized.mode === "preset" ? normalized.value : qsTr("Custom device icon")

    Image {
        id: image
        anchors.fill: parent
        source: root.useGlyph ? "" : root.sourceUrl
        sourceSize.width: Math.max(1,root.width * 2)
        sourceSize.height: Math.max(1,root.height * 2)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        visible: root.imageReady && root.normalized.render === "color"
    }
    ColorOverlay {
        anchors.fill: image
        source: image
        color: root.foreground
        visible: root.imageReady && root.normalized.render !== "color"
    }
    Text {
        textFormat: Text.PlainText
        anchors.fill: parent
        visible: root.useGlyph
        text: root.useGlyph ? root.normalized.value : ""

        color: root.foreground
        font.family: root.normalized.font || root.fontFamily
        font.pixelSize: Math.max(1,root.height)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        fontSizeMode: Text.Fit
    }
    // A built-in phone outline also works after a missing font/theme change.
    Rectangle {
        visible: root.fallback
        width: root.width * 0.57
        height: root.height * 0.9
        anchors.centerIn: parent
        radius: Math.max(1,root.height * 0.09)
        color: "transparent"
        border.color: root.foreground
        border.width: Math.max(1,root.height * 0.075)
        Rectangle {
            width: parent.width * 0.28
            height: Math.max(1,root.height * 0.06)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.height * 0.12
            color: root.foreground
        }
    }
}
