// Copyright (C) 2026 UnionTech Software Technology Co., Ltd.
// SPDX-License-Identifier: Apache-2.0 OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import QtQuick.Effects

Item {
    id: effect

    required property variant source

    // Blur (upstream MultiEffect stage) — kept architecture, not part of the
    // OverShifted glass shader itself.
    property bool blurEnabled: false
    property int blurMax: 32
    property real blurAmount: 1.0
    property real blurMultiplier: 0.0

    // ── OverShifted LiquidGlass parameters ─────────────────────────────
    // Shape: superellipse SDF fills the item; powerFactor controls corner
    // curvature (→∞ squares the shape, →2 makes it a circle).
    property real powerFactor: 3.0      // (1.001..6)

    // Refraction curve f(x) = 1 - b·(c·e)^(-d·x - a); fPower exponent on it.
    property real fPower: 1.0          // (-1.5..6)
    property real a: 0.7               // (0..5)
    property real b: 2.3               // (0..6)
    property real c: 5.2               // (0..6)
    property real d: 6.9               // (0..10)

    // Film grain noise added to the refracted backdrop.
    property real noise: 0.06          // (0..0.3)

    // Angular rim glow.
    property real glowWeight: 0.25     // (-1..1)
    property real glowBias: 0.0        // (-1..1)
    property real glowEdge0: 0.5        // (-1..1) smoothstep inner
    property real glowEdge1: -0.5       // (-1..1) smoothstep outer

    // Colour grading applied to the backdrop BEFORE refraction, via MultiEffect.
    property real brightness: 0.0       // [-1, 1], 0 = no change
    property real contrast: 0.0        // [-1, 1], 0 = no change
    property real saturation: 0.0      // [-1, 1], 0 = no change
    property real colorization: 0.0    // [0, 1], 0 = no tint
    property color colorizationColor: Qt.rgba(1, 1, 1, 1)

    // True when MultiEffect is needed for blur or colour grading of the backdrop
    readonly property bool multiEffectEnabled:
        (blurEnabled && blurAmount > 0 && blurMax > 0)
        || brightness != 0 || contrast != 0 || saturation != 0 || colorization > 0

    anchors.fill: parent

    // ── Stage 1: blur + colour-grade the raw backdrop ──────────────────
    MultiEffect {
        id: blurredSource
        anchors.fill: parent
        visible: effect.multiEffectEnabled
        layer.enabled: effect.multiEffectEnabled
        smooth: true
        opacity: 0   // not drawn to screen; sampled as a texture
        source: effect.source
        autoPaddingEnabled: false
        blurEnabled: effect.blurEnabled && effect.blurAmount > 0
        blur: blurEnabled ? effect.blurAmount : 0.0
        blurMax: effect.blurMax
        blurMultiplier: effect.blurMultiplier
        brightness: effect.brightness
        contrast: effect.contrast
        saturation: effect.saturation
        colorization: effect.colorization
        colorizationColor: effect.colorizationColor
    }

    // ── Stage 2: OverShifted glass shader refracts the (blurred) backdrop
    // and applies the angular rim glow.  The superellipse SDF defines the
    // shape; pixels outside are discarded (fully transparent).
    ShaderEffect {
        id: glassShader
        objectName: "glassShader"
        anchors.fill: parent
        smooth: true
        property variant source: effect.multiEffectEnabled ? blurredSource : effect.source
        readonly property real powerFactor: effect.powerFactor
        readonly property real fPower: effect.fPower
        readonly property real a: effect.a
        readonly property real b: effect.b
        readonly property real c: effect.c
        readonly property real d: effect.d
        readonly property real grainAmount: effect.noise
        readonly property real glowWeight: effect.glowWeight
        readonly property real glowBias: effect.glowBias
        readonly property real glowEdge0: effect.glowEdge0
        readonly property real glowEdge1: effect.glowEdge1
        vertexShader: "qrc:/shaders/liquidglass.vert.qsb"
        fragmentShader: "qrc:/shaders/liquidglass.frag.qsb"
    }
}
