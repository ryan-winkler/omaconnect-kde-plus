pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import QtQuick.Effects
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
    readonly property bool imageUnavailable: usePresetGlyph || !sourceUrl || image.status === Image.Error || image.status === Image.Null
    // Presets draw as font glyphs, as in the original OmaConnect: vector text stays
    // sharp at every scale and the bar host centres its ink exactly.
    readonly property bool usePresetGlyph: normalized.mode === "preset" && presetFont !== ""
    readonly property bool useGlyph: (normalized.mode === "glyph" && !fontMissing) || usePresetGlyph
    readonly property string renderedGlyph: usePresetGlyph ? Appearance.glyphFor(normalized) : useGlyph ? normalized.value : ""
    readonly property bool imageReady: image.status === Image.Ready
    // Full-colour application artwork has opaque internal backgrounds. Tinting
    // its alpha mask erases that detail; symbolic theme icons remain tintable.
    readonly property bool sourceColours: normalized.render === "color"
        || (normalized.mode === "theme" && normalized.tint !== true && !Appearance.symbolicThemeName(normalized.value))
    readonly property bool softwareScene: GraphicsInfo.api === GraphicsInfo.Software
    readonly property bool tintOnGpu: !softwareScene && !sourceColours && !useGlyph
    readonly property bool fallback: !useGlyph && imageUnavailable
    readonly property string warning: fontMissing ? qsTr("Font unavailable. Phone is shown.") : normalized.mode === "image" && fallback ? qsTr("Imported image is unavailable. Phone is shown.") : normalized.mode === "theme" && fallback ? qsTr("Theme icon is unavailable. Phone is shown.") : normalized.mode === "preset" && fallback ? qsTr("Icon fonts are unavailable. Phone is shown.") : ""
    implicitWidth: iconSize
    implicitHeight: iconSize
    Accessible.role: Accessible.StaticText
    Accessible.name: normalized.mode === "preset" ? normalized.value : qsTr("Custom device icon")

    Image {
        id: image
        anchors.fill: parent
        source: root.normalized.mode === "glyph" || root.usePresetGlyph ? "" : root.sourceUrl
        sourceSize.width: Math.max(1,Math.ceil(root.width * Screen.devicePixelRatio))
        sourceSize.height: Math.max(1,Math.ceil(root.height * Screen.devicePixelRatio))
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        onStatusChanged: symbolic.requestPaint()
        onSourceSizeChanged: if (symbolic) symbolic.reload()
        // The tint below uses the icon's alpha as its mask.
        layer.enabled: root.tintOnGpu
        visible: root.imageReady && root.sourceColours
    }
    Rectangle {
        id: tintFill
        anchors.fill: image
        color: root.foreground
        visible: false
    }
    MultiEffect {
        anchors.fill: image
        source: tintFill
        maskEnabled: true
        maskSource: image
        // Follow the icon's alpha so antialiased edges stay smooth.
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        visible: root.imageReady && root.tintOnGpu
    }
    // The bar host measures Text, Image and Rectangle items but not MultiEffect,
    // so this transparent box reports the tinted icon's painted area.
    Rectangle {
        anchors.centerIn: image
        width: image.paintedWidth
        height: image.paintedHeight
        color: "transparent"
        visible: root.imageReady && root.tintOnGpu
    }
    // The software scene graph draws no shader effect, so it tints with a Canvas.
    // Canvas is not used on the GPU: at scale 2 it paints a quarter-size icon.
    Canvas {
        id: symbolic
        anchors.fill: image
        property url iconSource: !root.softwareScene || root.normalized.mode === "glyph" || root.usePresetGlyph || root.sourceColours ? "" : root.sourceUrl
        property url loadedSource: ""
        function reload() {
            if (loadedSource.toString() !== "") unloadImage(loadedSource)
            loadedSource = iconSource
            if (loadedSource.toString() !== "") loadImage(loadedSource, image.sourceSize)
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
        visible: root.imageReady && !root.sourceColours && root.softwareScene
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
