import QtQuick
import QtQuick.Controls

import "../"
import "../newComponents"

Rectangle {
    id: root
    property string imageSource
    property var shuffledWords: []
    property var answers
    property string audio_path
    property real circleCount
    signal closed
    property var dragMap: []
    property var dropMap: []
    property string correctColor: myColors.correctColor
    property string wrongColor: myColors.wrongColor
    property string standColor: myColors.standColor
    property string headerText
    property var activityModelData
    property real lastHeight: 100
    property real lastWidth: 100


    width: parent.width
    height: parent.height
    color: "#232f34"
    z: 10
    Rectangle {
        id: header
        width: parent.width
        height: 40
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        color: "#232f34"
        border.color: "#009ca6"
        border.width: 1

        FlowText {
            width: parent.width
            height: parent.height
            text: root.headerText
            font.pixelSize: 25
            font.bold: true
            color: "#009ca6"

        }
    }

    Column {
        id: actColumn
        property real biggestWidth: 50
        property real biggestHeight: 20
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 10
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 5

        Rectangle {
            id: draggableWords
            color: "transparent"
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: 20//actColumn.biggestHeight*2 + 10
            z: 2

            Flow {
                id: flowWords
                anchors.topMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 5
                Repeater {
                    model: root.shuffledWords
                    Rectangle {
                        width: 100
                        height: 30
                        color: "transparent"
                        border.color: "blue"
                        border.width: 1
                        FlowText {
                            width: parent.width
                            height: parent.height
                            text: modelData
                        }
                    }
                }
            }
        }

        Rectangle {
            id: sentencesRect
            width: parent.width
            height: parent.height - draggableWords.height
            radius: 10
            color: "transparent"
            z: 1
            anchors.horizontalCenter: parent.horizontalCenter

            Image {
                id: activityImage
                source: imageSource
                antialiasing: true
                smooth: true
                fillMode: Image.PreserveAspectFit
                height: parent.height
                width: parent.width
                MouseArea {
                    anchors.fill: parent
                    onPressAndHold: {
                        var adjustedX = mouseX - (sentencesRect.width - activityImage.paintedWidth) / 2;
                        var adjustedY = mouseY - (sentencesRect.height - activityImage.paintedHeight) / 2;

                        // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                        var originalX = adjustedX * (activityImage.sourceSize.width / activityImage.paintedWidth);
                        var originalY = adjustedY * (activityImage.sourceSize.height / activityImage.paintedHeight);

                        root.activityModelData.createNewAnswer(originalX, originalY, root.lastWidth, root.lastHeight);
                        config.bookSets[0].saveToJson();
                    }
                }

                Repeater {
                    id: answersDropRepeater
                    model: activityModelData.answers
                    Item {
                        id: answerRect
                        property real xScale: activityImage.paintedWidth / activityImage.sourceSize.width
                        property real yScale: activityImage.paintedHeight / activityImage.sourceSize.height
                        x: (sentencesRect.width / 2 - activityImage.paintedWidth / 2) + modelData.coords.x * xScale
                        y: (sentencesRect.height / 2 - activityImage.paintedHeight / 2) + modelData.coords.y * yScale
                        width: modelData.coords.width * xScale
                        height: modelData.coords.height * yScale
                        Rectangle {

                            color: "#7bd5bd"
                            border.color: "black"
                            border.width: 2
                            radius: 5
                            anchors.fill: parent
                            opacity: 0.4
                        }

                        FlowText {
                            id: answer
                            text: textEdit.text
                            color: myColors.answerColor
                            rotation: modelData.rotation
                            height: parent.height
                            width: parent.width
                        }

                        MouseArea {
                            anchors.fill: parent
                            drag.target: parent
                            onReleased: answerRect.setStatus()
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onDoubleClicked: {
                                if (mouse.button === Qt.LeftButton) {
                                    textEdit.focus = true;
                                    answer.visible = false;
                                    textEdit.text = textEdit.text;
                                    textEdit.visible = true;
                                }
                            }
                            onClicked: {
                                if (mouse.button === Qt.MiddleButton) {
                                    activityModelData.removeAnswer(index);
                                    print("answer silindi");
                                    config.bookSets[0].saveToJson();
                                }
                            }
                        }

                        TextField {
                            id: textEdit
                            visible: false
                            height: parent.height
                            width: parent.width
                            color: myColors.answerColor
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: modelData.isCorrect  ? "x" : ""
                            onAccepted: {
                                visible = false;
                                if (text !== "") {
                                    modelData.isCorrect = true;
                                } else
                                    modelData.isCorrect = false;

                                answer.visible = true;
                                config.bookSets[0].saveToJson();
                            }
                            onEditingFinished: {
                                visible = false;
                                if (text !== "") {
                                    modelData.isCorrect = true;
                                } else
                                    modelData.isCorrect = false;

                                answer.visible = true;
                                config.bookSets[0].saveToJson();
                            }
                        }

                        Rectangle {
                            id: zoomPoint
                            color: "black"
                            radius: 15
                            width: radius
                            height: radius

                            anchors.right: parent.right
                            anchors.rightMargin: -width / 2
                            anchors.bottomMargin: -height / 2
                            anchors.bottom: parent.bottom

                            MouseArea {
                                anchors.fill: parent
                                drag {
                                    target: parent
                                    axis: Drag.XAndYAxis
                                }

                                onPositionChanged: {
                                    //if(drag.active){

                                    var adjustedX = mouseX;
                                    var adjustedY = mouseY;
                                    var originalX = adjustedX * (activityImage.paintedWidth / activityImage.sourceSize.width);
                                    var originalY = adjustedY * (activityImage.paintedHeight / activityImage.sourceSize.height);

                                    // Mouse hareketini zoom seviyesine göre ölçekle
                                    answerRect.width = answerRect.width + (originalX);
                                    answerRect.height = answerRect.height + (originalY);

                                    // Minimum boyutları belirle
                                    if (answerRect.width < 10)
                                        answerRect.width = 10;
                                    if (answerRect.height < 10)
                                        answerRect.height = 10;
                                    //}
                                }
                                onReleased: answerRect.setStatus()
                            }
                        }
                        function setStatus() {
                            var adjustedX = (answerRect.x - (sentencesRect.width / 2 - activityImage.paintedWidth / 2));
                            var adjustedY = (answerRect.y - (sentencesRect.height / 2 - activityImage.paintedHeight / 2));
                            var originalX = adjustedX * (activityImage.sourceSize.width / activityImage.paintedWidth);
                            var originalY = adjustedY * (activityImage.sourceSize.height / activityImage.paintedHeight);

                            var adjustedW = answerRect.width * (activityImage.sourceSize.width / activityImage.paintedWidth);
                            var adjustedH = answerRect.height * (activityImage.sourceSize.height / activityImage.paintedHeight);

                            root.lastHeight = adjustedH;
                            root.lastWidth = adjustedW;
                            modelData.coords = Qt.rect(originalX, originalY, adjustedW, adjustedH);
                            config.bookSets[0].saveToJson();
                            print("Changes Are Saved Page Detail set status");
                        }
                    }
                }
            }
        }
    }
}
