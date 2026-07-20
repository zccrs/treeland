// Copyright (C) 2026 UnionTech Software Technology Co., Ltd.
// SPDX-License-Identifier: Apache-2.0 OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import QtQuick.Effects

Item {
    id: effect

    required property variant source

    // WebGL reference material controls from zccrs/liquid-glass/webgl.html.
    // Blur and shadow stay delegated to Qt Quick MultiEffect / callers.
    property real radius: 60
    property real thickness: 50
    property real bezelWidth: 60
    property real ior: 3.0
    property real specular: 0.55
    property real tint: 0.08
    // Chromatic edge dispersion: per-channel pixel spread along the refraction
    // gradient, confined to a thin rim band so the chromatic split lives only
    // at the outermost pixels. dispersionPx=0 disables it; dispersionWidth
    // sets the absolute width of the rim band in pixels (15 matches iOS).
    // When dispersionWidth is 0, dispersion is completely disabled.
    // dispersionBlend mixes the split into the rim.
    property real dispersionPx: 40
    property real dispersionWidth: 15.0
    property real dispersionBlend: 1.0

    // Compatibility inputs kept for existing Blur.qml users. MultiEffect owns
    // backdrop blur and colour adjustment before the WebGL refraction shader.
    property bool blurEnabled: true
    property int blurMax: 12
    property real blurAmount: 1.0
    property real blurMultiplier: 0.0
    property real displacementFactor: 1.0
    property real brightness: 0.0
    property real contrast: 0.0
    property real saturation: 0.0
    property real colorization: 0.0
    property color colorizationColor: Qt.rgba(1, 1, 1, 1)
    property color highlightColor: Qt.rgba(1, 1, 1, 0.35)
    property real strokeWidth: 1.5
    property real strokeStrength: 1.0
    property real specularOpacity: specular
    property bool highlightEnabled: true
    property real lightPower: 1.5
    readonly property vector2d lightDirection: Qt.vector2d(0.5, -0.7)
    readonly property bool multiEffectEnabled:
        (blurEnabled && blurAmount > 0 && blurMax > 0)
        || brightness != 0 || contrast != 0 || saturation != 0 || colorization > 0

    readonly property real effectiveSpecular: highlightEnabled
        ? Math.max(0, Math.min(1, specular))
        : 0

    MultiEffect {
        id: processedSource
        anchors.fill: parent
        visible: effect.multiEffectEnabled
        source: effect.source
        autoPaddingEnabled: false
        blurEnabled: effect.blurEnabled
        blur: effect.blurAmount
        blurMax: effect.blurMax
        blurMultiplier: effect.blurMultiplier
        brightness: effect.brightness
        contrast: effect.contrast
        saturation: effect.saturation
        colorization: effect.colorization
        colorizationColor: effect.colorizationColor
    }
    ShaderEffectSource {
        id: processedTexture
        anchors.fill: parent
        sourceItem: processedSource
        hideSource: true
        live: true
        visible: false
    }

    ShaderEffect {
        id: glassShader
        objectName: "glassShader"
        anchors.fill: parent
        smooth: true
        property variant source: effect.multiEffectEnabled ? processedTexture : effect.source
        readonly property vector2d itemSize: Qt.vector2d(Math.max(width, 1), Math.max(height, 1))
        readonly property real radius: effect.radius
        readonly property real bezelWidth: effect.bezelWidth
        readonly property real tint: Math.max(0, Math.min(1, effect.tint))
        readonly property real dispersion: effect.dispersionPx
        readonly property real dispersionBlend: Math.max(0, Math.min(1, effect.dispersionBlend))
        readonly property real dispersionWidth: Math.max(0, effect.dispersionWidth)
        readonly property real thickness: effect.thickness
        readonly property real ior: effect.ior
        readonly property real specular: effect.effectiveSpecular

        // Compatibility material controls stay forwarded for existing Blur.qml
        // users; the shader consumes only the WebGL reference controls.
        readonly property real displacementFactor: effect.displacementFactor
        readonly property color highlightColor: effect.highlightColor
        readonly property real strokeWidth: effect.strokeWidth
        readonly property real strokeStrength: effect.highlightEnabled ? effect.strokeStrength : 0.0
        readonly property vector2d lightDirection: effect.lightDirection
        readonly property real lightPower: effect.lightPower

        vertexShader: "qrc:/shaders/liquidglass.vert.qsb"
        fragmentShader: "qrc:/shaders/liquidglass.frag.qsb"
    }
}
