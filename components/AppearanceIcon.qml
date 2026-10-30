pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.Commons as Commons
import qs.Ui as Kit
import "../Appearance.js" as Appearance

Item {
    id: root
    property var icon: Appearance.phone()
    property color foreground: Commons.Color.foreground
    property string fontFamily: Commons.Style.font.family
    property string assetBaseUrl: ""
    property int iconSize: 20
    readonly property var normalized: Appearance.normalizeIcon(icon,false)
    readonly property bool fontMissing: normalized.mode === "glyph" && !!normalized.font && Qt.fontFamilies().indexOf(normalized.font) < 0
    property string themedSource: normalized.mode === "theme" || normalized.mode === "preset" ? Quickshell.iconPath(Appearance.themeFor(normalized),true) : ""
    readonly property string sourceUrl: normalized.mode === "image" && /^file:\/\//.test(assetBaseUrl) ? assetBaseUrl + normalized.value : themedSource
    readonly property string presetFont: Appearance.symbolFont(Qt.fontFamilies(),fontFamily)
    readonly property bool imageUnavailable: !sourceUrl || image.status === Image.Error || image.status === Image.Null
    readonly property bool usePresetGlyph: normalized.mode === "preset" && imageUnavailable && presetFont !== ""
    readonly property bool useGlyph: (normalized.mode === "glyph" && !fontMissing) || usePresetGlyph
    readonly property string renderedGlyph: usePresetGlyph ? Appearance.glyphFor(normalized) : useGlyph ? normalized.value : ""
    readonly property bool imageReady: image.status === Image.Ready
    readonly property bool fallback: !useGlyph && imageUnavailable
    readonly property string warning: fontMissing ? qsTr("Font unavailable. Phone is shown.") : normalized.mode === "image" && fallback ? qsTr("Imported image is unavailable. Phone is shown.") : normalized.mode === "theme" && fallback ? qsTr("Theme icon is unavailable. Phone is shown.") : normalized.mode === "preset" && fallback ? qsTr("Icon fonts are unavailable. Phone is shown.") : ""
    implicitWidth: iconSize
    implicitHeight: iconSize
    Accessible.role: Accessible.StaticText
    Accessible.name: normalized.mode === "preset" ? normalized.value : qsTr("Custom device icon")

    Image {
        id: image
        anchors.fill: parent
        source: root.normalized.mode === "glyph" ? "" : root.sourceUrl
        sourceSize.width: Math.max(1,root.width * 2)
        sourceSize.height: Math.max(1,root.height * 2)
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        onStatusChanged: symbolic.requestPaint()
        visible: root.imageReady && root.normalized.render === "color"
    }
    // Raster composition also works with Qt's software scene graph. A shader
    // effect can report a loaded image while drawing no symbolic icon there.
    Canvas {
        id: symbolic
        anchors.fill: image
        property url iconSource: root.normalized.mode === "glyph" || root.normalized.render === "color" ? "" : root.sourceUrl
        property url loadedSource: ""
        function reload() {
            if (loadedSource.toString() !== "") unloadImage(loadedSource)
            loadedSource = iconSource
            if (loadedSource.toString() !== "") loadImage(loadedSource, Qt.size(Math.max(1,width * 2), Math.max(1,height * 2)))
            requestPaint()
        }
        onIconSourceChanged: reload()
        onWidthChanged: reload()
        onHeightChanged: reload()
        onImageLoaded: requestPaint()
        onAvailableChanged: if (available) reload()
        Connections {
            target: root
            function onForegroundChanged() { symbolic.requestPaint() }
        }
        onPaint: {
            var context = getContext("2d")
            context.reset()
            context.clearRect(0, 0, width, height)
            if (loadedSource.toString() === "" || !isImageLoaded(loadedSource)) return
            var w = image.paintedWidth, h = image.paintedHeight
            context.drawImage(loadedSource, (width - w) / 2, (height - h) / 2, w, h)
            context.globalCompositeOperation = "source-in"
            context.fillStyle = root.foreground
            context.fillRect(0, 0, width, height)
        }
        visible: root.imageReady && root.normalized.render !== "color"
    }
    Kit.OpticalGlyph {
        objectName: "appearance-glyph"
        anchors.fill: parent
        visible: root.useGlyph
        text: root.renderedGlyph
        color: root.foreground
        fontFamily: root.usePresetGlyph ? root.presetFont : root.normalized.font || root.fontFamily
        fontSize: Math.max(1,root.height)
        paintedSize: Math.max(1,Math.min(root.width,root.height))
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
