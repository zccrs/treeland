// Copyright (C) 2023 JiDe Zhang <zccrs@live.com>.
// SPDX-License-Identifier: Apache-2.0 OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Waylib.Server
import Treeland
import Blur

Item {
    id :root

    property bool glassMode: true
    property real effectRadius: 36
    property real refractionHeight: 24
    property real refractionAmount: 10
    property real highlightStrength: 0.45

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
                        source: "file:///usr/share/wallpapers/deepin/desktop.jpg"
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        anchors.fill: parent
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
                            text: root.glassMode ? "Glass" : "Blur"
                            onClicked: root.glassMode = !root.glassMode
                        }

                        Label {
                            text: "radius " + Math.round(root.effectRadius)
                            color: "white"
                        }

                        Slider {
                            from: 0
                            to: 80
                            value: root.effectRadius
                            onMoved: root.effectRadius = value
                        }

                        Label {
                            text: "height " + Math.round(root.refractionHeight)
                            color: "white"
                        }

                        Slider {
                            from: 1
                            to: 80
                            value: root.refractionHeight
                            onMoved: root.refractionHeight = value
                        }

                        Label {
                            text: "amount " + Math.round(root.refractionAmount)
                            color: "white"
                        }

                        Slider {
                            from: -40
                            to: 40
                            value: root.refractionAmount
                            onMoved: root.refractionAmount = value
                        }

                        Label {
                            text: "highlight " + root.highlightStrength.toFixed(2)
                            color: "white"
                        }

                        Slider {
                            from: 0
                            to: 1
                            value: root.highlightStrength
                            onMoved: root.highlightStrength = value
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

                    Item {
                        id: effectPanel
                        width: 220
                        height: 220
                        anchors.centerIn: parent

                        Rectangle {
                            anchors.fill: parent
                            radius: root.effectRadius
                            color: Qt.rgba(1, 1, 1, 0.08)
                            border.color: Qt.rgba(1, 1, 1, 0.35)
                            border.width: 1
                        }

                        Loader {
                            anchors.fill: parent
                            sourceComponent: root.glassMode ? glassComponent : blurComponent
                        }

                        Component {
                            id: glassComponent
                            Glass {
                                radius: root.effectRadius
                                refractionHeight: root.refractionHeight
                                refractionAmount: root.refractionAmount
                                highlightStrength: root.highlightStrength
                            }
                        }

                        Component {
                            id: blurComponent
                            RenderBufferBlitter {
                                anchors.fill: parent
                                MultiEffect {
                                    anchors.fill: parent
                                    source: parent.content
                                    autoPaddingEnabled: false
                                    blurEnabled: true
                                    blur: 1.0
                                    blurMax: 64
                                    saturation: 0.2
                                }
                            }
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
            id: globalEffectPanel
            width: 300
            height: 300
            anchors.centerIn: parent

            Loader {
                anchors.fill: parent
                sourceComponent: root.glassMode ? globalGlassComponent : globalBlurComponent
            }

            Component {
                id: globalGlassComponent
                Glass {
                    radius: root.effectRadius
                    refractionHeight: root.refractionHeight
                    refractionAmount: root.refractionAmount
                    highlightStrength: root.highlightStrength
                }
            }

            Component {
                id: globalBlurComponent
                RenderBufferBlitter {
                    anchors.fill: parent
                    MultiEffect {
                        anchors.fill: parent
                        source: parent.content
                        autoPaddingEnabled: false
                        blurEnabled: true
                        blur: 1.0
                        blurMax: 64
                        saturation: 0.2
                    }
                }
            }
        }
    }
}
