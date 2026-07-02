// Copyright (C) 2026 UnionTech Software Technology Co., Ltd.
// SPDX-License-Identifier: Apache-2.0 OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Waylib.Server
import Treeland

RenderBufferBlitter {
    id: blitter

    property real radius: 0
    property bool radiusEnabled: radius > 0
    property bool blurEnabled: true
    property int blurMax: 32
    property real refractionHeight: 24
    property real refractionAmount: 10
    property real exposure: 1.08
    property real saturation: 1.15
    property color tintColor: Qt.rgba(1, 1, 1, 0.10)
    property color highlightColor: Qt.rgba(1, 1, 1, 0.35)
    property real highlightStrength: 0.45
    readonly property alias shaderStatus: glassShader.status
    readonly property alias shaderLog: glassShader.log

    z: parent.z ? parent.z - 1 : -1
    anchors.fill: parent

    ShaderEffect {
        id: glassShader
        anchors.fill: parent
        property variant source: blitter.content
        layer.enabled: blitter.radiusEnabled || blitter.blurEnabled
        smooth: blitter.radiusEnabled || blitter.blurEnabled
        opacity: (blitter.radiusEnabled || blitter.blurEnabled) ? 0 : parent.opacity
        readonly property vector2d itemSize: Qt.vector2d(Math.max(width, 1), Math.max(height, 1))
        readonly property real radius: blitter.radius
        readonly property real refractionHeight: blitter.refractionHeight
        readonly property real refractionAmount: blitter.refractionAmount
        readonly property real exposure: blitter.exposure
        readonly property real saturation: blitter.saturation
        readonly property color tintColor: blitter.tintColor
        readonly property color highlightColor: blitter.highlightColor
        readonly property real highlightStrength: blitter.highlightStrength
        vertexShader: "qrc:/shaders/liquidglass.vert.qsb"
        fragmentShader: "qrc:/shaders/liquidglass.frag.qsb"
    }

    MultiEffect {
        id: softenedGlass
        anchors.fill: parent
        visible: blitter.blurEnabled
        layer.enabled: blitter.radiusEnabled
        smooth: blitter.radiusEnabled
        opacity: blitter.radiusEnabled ? 0 : parent.opacity
        source: glassShader
        autoPaddingEnabled: false
        blurEnabled: blitter.blurEnabled
        blur: blitter.blurEnabled ? 1.0 : 0.0
        blurMax: blitter.blurMax
        saturation: 1.0
    }

    Loader {
        x: glassShader.x
        y: glassShader.y
        active: blitter.radiusEnabled
        sourceComponent: Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeWidth: 0
                fillItem: blitter.blurEnabled ? softenedGlass : glassShader
                PathRectangle {
                    width: glassShader.width
                    height: glassShader.height
                    radius: blitter.radius
                }
            }
        }
    }
}
