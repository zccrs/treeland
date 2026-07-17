// Copyright (C) 2026 UnionTech Software Technology Co., Ltd.
// SPDX-License-Identifier: Apache-2.0 OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Waylib.Server
import GlassExample
import Treeland

Item {
    id :root

    readonly property url wallpaperSource: Helper.wallpaperSource

    property bool glassMode: true
    property bool glassBlurEnabled: true
    property int glassBlurMax: 36
    property real glassPowerFactor: 3.0
    property real glassFPower: 1.0
    property real glassA: 0.7
    property real glassB: 2.3
    property real glassC: 5.2
    property real glassD: 6.9
    property real glassNoise: 0.06
    property real glassGlowWeight: 0.25
    property real glassGlowBias: 0.0
    property real glassGlowEdge0: 0.5
    property real glassGlowEdge1: -0.5
    property real glassBrightness: 0.05
    property real glassContrast: -0.12
    property real glassSaturation: 0.4
    property real glassColorization: 0.12
    property bool advancedExpanded: false

    Shortcut {
        sequences: [StandardKey.Quit]
        context: Qt.ApplicationShortcut
        onActivated: {
            Qt.quit()
        }
    }

    OutputRenderWindow {
        id: renderWindow

        width: outputsContainer.implicitWidth
        height: outputsContainer.implicitHeight
        color: "black"

        Row {
            id: outputsContainer

            anchors.fill: parent

            DynamicCreatorComponent {
                id: outputDelegateCreator
                creator: Helper.outputCreator

                OutputItem {
                    id: rootOutputItem
                    required property WaylandOutput waylandOutput
                    readonly property OutputViewport onscreenViewport: outputViewport

                    output: waylandOutput
                    devicePixelRatio: waylandOutput.scale

                    cursorDelegate: Cursor {
                        id: cursorItem

                        required property QtObject outputCursor
                        readonly property point position: parent.mapFromGlobal(cursor.position.x, cursor.position.y)

                        cursor: outputCursor.cursor
                        output: outputCursor.output.output
                        x: position.x - hotSpot.x
                        y: position.y - hotSpot.y
                        visible: valid && outputCursor.visible
                        OutputLayer.enabled: true
                        OutputLayer.keepLayer: true
                        OutputLayer.flags: OutputLayer.Cursor
                        OutputLayer.cursorHotSpot: hotSpot
                        OutputLayer.outputs: [outputViewport]
                    }

                    OutputViewport {
                        id: outputViewport

                        output: waylandOutput
                        devicePixelRatio: parent.devicePixelRatio
                        anchors.centerIn: parent

                        RotationAnimation {
                            id: rotationAnimator

                            target: outputViewport
                            duration: 200
                            alwaysRunToEnd: true
                        }

                        Timer {
                            id: setTransform

                            property var scheduleTransform
                            onTriggered: onscreenViewport.rotateOutput(scheduleTransform)
                            interval: rotationAnimator.duration / 2
                        }

                        function rotationOutput(orientation) {
                            setTransform.scheduleTransform = orientation
                            setTransform.start()

                            switch(orientation) {
                            case WaylandOutput.R90:
                                rotationAnimator.to = 90
                                break
                            case WaylandOutput.R180:
                                rotationAnimator.to = 180
                                break
                            case WaylandOutput.R270:
                                rotationAnimator.to = -90
                                break
                            default:
                                rotationAnimator.to = 0
                                break
                            }

                            rotationAnimator.from = rotation
                            rotationAnimator.start()
                        }
                    }

                    Image {
                        id: background
                        source: root.wallpaperSource
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        anchors.fill: parent
                        smooth: true
                    }

                    Column {
                        id: controlColumn
                        anchors {
                            bottom: parent.bottom
                            left: parent.left
                            margins: 10
                        }

                        spacing: 10

                        // ── Action buttons ──────────────────────────
                        Row {
                            spacing: 10
                            Button {
                                text: root.glassMode ? "Switch to Blur" : "Switch to Glass"
                                onClicked: root.glassMode = !root.glassMode
                            }
                            Button {
                                text: "Grab Glass"
                                onClicked: {
                                    effectPanel.grabToImage(function(result) {
                                        const path = "/tmp/treeland-liquid-glass-grab.png"
                                        if (result.saveToFile(path)) {
                                            console.log("Liquid Glass grab saved", path, result.image.size)
                                        } else {
                                            console.warn("Liquid Glass grab failed", path)
                                        }
                                    })
                                }
                            }
                            Button {
                                text: root.glassBlurEnabled ? "Blur: on" : "Blur: off"
                                onClicked: root.glassBlurEnabled = !root.glassBlurEnabled
                            }
                        }

                        // ── Common sliders (always visible, single row) ──
                        Row {
                            spacing: 20

                            Column {
                                spacing: 2
                                Label { text: "power " + root.glassPowerFactor.toFixed(2); color: "white" }
                                Slider { from: 1.001; to: 6.0; value: root.glassPowerFactor; onMoved: root.glassPowerFactor = value }
                            }
                            Column {
                                spacing: 2
                                Label { text: "blur max " + root.glassBlurMax; color: "white" }
                                Slider { from: 0; to: 96; stepSize: 1; value: root.glassBlurMax; onMoved: root.glassBlurMax = value }
                            }
                        }

                        Button {
                            text: root.advancedExpanded ? "▼ Advanced" : "▶ Advanced"
                            onClicked: root.advancedExpanded = !root.advancedExpanded
                        }

                        // ── Advanced sliders (collapsible, multi-column) ──
                        Row {
                            spacing: 20
                            visible: root.advancedExpanded

                            // Column A: refraction curve
                            Column {
                                spacing: 2
                                Label { text: "fPower " + root.glassFPower.toFixed(2); color: "white" }
                                Slider { from: -1.5; to: 6.0; value: root.glassFPower; onMoved: root.glassFPower = value }
                                Label { text: "a " + root.glassA.toFixed(2); color: "white" }
                                Slider { from: 0; to: 5; value: root.glassA; onMoved: root.glassA = value }
                                Label { text: "b " + root.glassB.toFixed(2); color: "white" }
                                Slider { from: 0; to: 6; value: root.glassB; onMoved: root.glassB = value }
                                Label { text: "c " + root.glassC.toFixed(2); color: "white" }
                                Slider { from: 0; to: 6; value: root.glassC; onMoved: root.glassC = value }
                                Label { text: "d " + root.glassD.toFixed(2); color: "white" }
                                Slider { from: 0; to: 10; value: root.glassD; onMoved: root.glassD = value }
                            }

                            // Column B: glow & noise
                            Column {
                                spacing: 2
                                Label { text: "noise " + root.glassNoise.toFixed(3); color: "white" }
                                Slider { from: 0; to: 0.3; value: root.glassNoise; onMoved: root.glassNoise = value }
                                Label { text: "glow wt " + root.glassGlowWeight.toFixed(2); color: "white" }
                                Slider { from: -1; to: 1; value: root.glassGlowWeight; onMoved: root.glassGlowWeight = value }
                                Label { text: "glow bias " + root.glassGlowBias.toFixed(2); color: "white" }
                                Slider { from: -1; to: 1; value: root.glassGlowBias; onMoved: root.glassGlowBias = value }
                                Label { text: "glow e0 " + root.glassGlowEdge0.toFixed(2); color: "white" }
                                Slider { from: -1; to: 1; value: root.glassGlowEdge0; onMoved: root.glassGlowEdge0 = value }
                                Label { text: "glow e1 " + root.glassGlowEdge1.toFixed(2); color: "white" }
                                Slider { from: -1; to: 1; value: root.glassGlowEdge1; onMoved: root.glassGlowEdge1 = value }
                            }

                            // Column C: colour grading (MultiEffect)
                            Column {
                                spacing: 2
                                Label { text: "brightness " + root.glassBrightness.toFixed(2); color: "white" }
                                Slider { from: -1; to: 1; value: root.glassBrightness; onMoved: root.glassBrightness = value }
                                Label { text: "contrast " + root.glassContrast.toFixed(2); color: "white" }
                                Slider { from: -1; to: 1; value: root.glassContrast; onMoved: root.glassContrast = value }
                                Label { text: "saturation " + root.glassSaturation.toFixed(2); color: "white" }
                                Slider { from: -1; to: 1; value: root.glassSaturation; onMoved: root.glassSaturation = value }
                                Label { text: "colorization " + root.glassColorization.toFixed(2); color: "white" }
                                Slider { from: 0; to: 1; value: root.glassColorization; onMoved: root.glassColorization = value }
                            }
                        }
                    }

                    Column {
                        anchors {
                            bottom: parent.bottom
                            right: parent.right
                            margins: 10
                        }

                        spacing: 10

                        Button {
                            text: "1X"
                            onClicked: {
                                onscreenViewport.setOutputScale(1)
                            }
                        }

                        Button {
                            text: "1.5X"
                            onClicked: {
                                onscreenViewport.setOutputScale(1.5)
                            }
                        }

                        Button {
                            text: "Normal"
                            onClicked: {
                                outputViewport.rotationOutput(WaylandOutput.Normal)
                            }
                        }

                        Button {
                            text: "R90"
                            onClicked: {
                                outputViewport.rotationOutput(WaylandOutput.R90)
                            }
                        }

                        Button {
                            text: "R270"
                            onClicked: {
                                outputViewport.rotationOutput(WaylandOutput.R270)
                            }
                        }

                        Button {
                            text: "Quit"
                            onClicked: {
                                Qt.quit()
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "'Ctrl+Q' quit"
                        font.pointSize: 40
                        color: "white"

                        SequentialAnimation on rotation {
                            id: ani
                            running: true
                            PauseAnimation { duration: 1500 }
                            NumberAnimation { from: 0; to: 360; duration: 5000; easing.type: Easing.InOutCubic }
                            loops: Animation.Infinite
                        }
                    }


                    function setTransform(transform) {
                        onscreenViewport.rotationOutput(transform)
                    }

                    function setScale(scale) {
                        onscreenViewport.setOutputScale(scale)
                    }

                    function invalidate() {
                        onscreenViewport.invalidate()
                    }
                }
            }
        }

        Item {
            id: effectPanel
            width: 250
            height: 250
            x: (parent.width - width) / 2
            y: (parent.height - height) / 2

            MouseArea {
                anchors.fill: parent
                drag.target: effectPanel
                drag.axis: Drag.XAndYAxis
                drag.minimumX: 0
                drag.maximumX: parent.parent.width - effectPanel.width
                drag.minimumY: 0
                drag.maximumY: parent.parent.height - effectPanel.height
            }

            Loader {
                anchors.fill: parent
                sourceComponent: root.glassMode ? globalGlassComponent : globalBlurComponent
            }

            Component {
                id: globalGlassComponent
                RenderBufferBlitter {
                    id: blitter
                    anchors.fill: parent
                    smooth: true
                    GlassEffect {
                        anchors.fill: parent
                        source: blitter.content
                        blurEnabled: root.glassBlurEnabled
                        blurMax: root.glassBlurMax
                        brightness: root.glassBrightness
                        contrast: root.glassContrast
                        saturation: root.glassSaturation
                        colorization: root.glassColorization
                        powerFactor: root.glassPowerFactor
                        fPower: root.glassFPower
                        a: root.glassA
                        b: root.glassB
                        c: root.glassC
                        d: root.glassD
                        noise: root.glassNoise
                        glowWeight: root.glassGlowWeight
                        glowBias: root.glassGlowBias
                        glowEdge0: root.glassGlowEdge0
                        glowEdge1: root.glassGlowEdge1
                        smooth: true
                    }
                }
            }

            Component {
                id: globalBlurComponent
                RenderBufferBlitter {
                    id: blitter
                    anchors.fill: parent
                    MultiEffect {
                        anchors.fill: parent
                        source: blitter.content
                        autoPaddingEnabled: false
                        blurEnabled: true
                        blur: 1.0
                        blurMax: 64
                        saturation: 0.2
                    }
                }
            }
        }

        // ── Draggable RoundBlur demo ────────────────────────────────────
        // Uses the real RoundBlur component (Blur subclass) from the
        // GlassExample QML module, which reads glass parameters from
        // Helper.config. Drag to reposition.
        Item {
            id: roundBlurPanel
            width: 30
            height: 30
            x: (parent.width - width) / 2 + 260
            y: (parent.height - height) / 2 - 180

            MouseArea {
                anchors.fill: parent
                drag.target: roundBlurPanel
                drag.axis: Drag.XAndYAxis
                drag.minimumX: 0
                drag.maximumX: parent.parent.width - roundBlurPanel.width
                drag.minimumY: 0
                drag.maximumY: parent.parent.height - roundBlurPanel.height
            }

            RoundBlur {
                anchors.fill: parent
                radius: root.effectRadius
            }

            Text {
                anchors.left: parent.right
                text: "RoundBlur\n(drag me)"
                color: "white"
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
