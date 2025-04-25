import QtQuick
import QtQuick.Controls

import "../"
import "../newComponents"


Rectangle {
    property string imageSource
    property var shuffledWords: []
    property var answers
    property string audio_path
    signal closed()
    property var dragMap: []
    property var dropMap: []
    property string correctColor: myColors.correctColor
    property string wrongColor: myColors.wrongColor
    property string standColor: myColors.standColor
    property string headerText
    property var activityModelData
    property real lastHeight: 100
    property real lastWidth: 100

    id: root
    width: parent.width -10
    height: parent.height
    color: "gray"
    z: 10
     Rectangle {
        id: header
        width: parent.width
        height: 40
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        FlowText {
            width: parent.width
            height: parent.height
            text: root.headerText
            anchors.centerIn: parent
            font.pixelSize: 25
            font.bold: true
        }
    }

    Column {
        property real biggestWidth: 50
        property real biggestHeight: 20
        id: actColumn
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 10
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing : 5

        Rectangle{
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
                        FlowText{
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
            color:"transparent"
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
                        var adjustedX = mouseX - (sentencesRect.width - activityImage.paintedWidth)/2
                        var adjustedY = mouseY - (sentencesRect.height - activityImage.paintedHeight)/2

                        // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                        var originalX = adjustedX * (activityImage.sourceSize.width / activityImage.paintedWidth)
                        var originalY = adjustedY * (activityImage.sourceSize.height / activityImage.paintedHeight)

                        var lastWidth = 100
                        var lastHeight = 50

                        root.activityModelData.createNewAnswer(originalX, originalY, root.lastWidth, root.lastHeight);
                        config.bookSets[0].saveToJson();
                    }
                }

                Repeater {
                    id: answersDropRepeater
                    model: activityModelData.answers
                    Item {
                        property real xScale : activityImage.paintedWidth / activityImage.sourceSize.width
                        property real yScale : activityImage.paintedHeight / activityImage.sourceSize.height
                        id: answerRect
                        x: (sentencesRect.width/2 - activityImage.paintedWidth/2) + modelData.coords.x * xScale
                        y: (sentencesRect.height/2 - activityImage.paintedHeight/2)+ modelData.coords.y * yScale
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
                            text: modelData.group.join(",")
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
                                    answer.visible = false
                                    textEdit.text = answer.text
                                    textEdit.visible = true
                                    textEdit.focus = true
                                }
                            }
                            onClicked: {
                                if (mouse.button === Qt.MiddleButton) {
                                    activityModelData.removeAnswer(index)
                                    print("answer silindi")
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
                            onAccepted: {
                                visible = false
                                var group = textEdit.text.split(",").map(function(item) {
                                    return item.trim();
                                });
                                modelData.group = group
                                answer.visible = true
                                config.bookSets[0].saveToJson();
                            }

                            onEditingFinished: {
                                visible = false
                                var group = textEdit.text.split(",").map(function(item) {
                                    return item.trim();
                                });
                                modelData.group = group
                                answer.visible = true
                                config.bookSets[0].saveToJson();
                            }
                        }


                        Rectangle {
                            color: "black"
                            radius: 15
                            width: radius
                            height: radius

                            id: zoomPoint

                            anchors.right: parent.right
                            anchors.rightMargin: -width/2
                            anchors.bottomMargin: -height/2
                            anchors.bottom: parent.bottom

                            MouseArea {
                                anchors.fill: parent
                                drag{ target: parent; axis: Drag.XAndYAxis }

                                onPressed: {
                                    print("w:", answerRect.width, "h:", answerRect.height)
                                }

                                onPositionChanged: {
                                    //if(drag.active){

                                    var adjustedX = mouseX
                                    var adjustedY = mouseY
                                    var originalX = adjustedX * (activityImage.paintedWidth / activityImage.sourceSize.width)
                                    var originalY = adjustedY * (activityImage.paintedHeight / activityImage.sourceSize.height)

                                    // Mouse hareketini zoom seviyesine göre ölçekle
                                    answerRect.width = answerRect.width + (originalX);
                                    answerRect.height = answerRect.height + (originalY);

                                    // Minimum boyutları belirle
                                    if (answerRect.width < 20) answerRect.width = 20;
                                    if (answerRect.height < 10) answerRect.height = 10;
                                    //}
                                }
                                onReleased: answerRect.setStatus()

                            }
                        }
                        function setStatus() {

                            var adjustedX = (answerRect.x  - (sentencesRect.width / 2 - activityImage.paintedWidth / 2))
                            var adjustedY = (answerRect.y  - (sentencesRect.height / 2 - activityImage.paintedHeight / 2))
                            var originalX = adjustedX * (activityImage.sourceSize.width / activityImage.paintedWidth)
                            var originalY = adjustedY * (activityImage.sourceSize.height / activityImage.paintedHeight)

                            var adjustedW = answerRect.width * (activityImage.sourceSize.width /activityImage.paintedWidth)
                            var adjustedH = answerRect.height * (activityImage.sourceSize.height / activityImage.paintedHeight )
                            root.lastHeight = adjustedH
                            root.lastWidth = adjustedW

                            modelData.coords = Qt.rect(originalX, originalY, adjustedW, adjustedH)
                            config.bookSets[0].saveToJson();
                            print("Changes Are Saved Page Detail set status")
                        }
                    }

                }



            }
        }
    }


    Rectangle {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        width: 40
        height: 40
        color: "red"
        FlowText {
            text: qsTr("X")
            color: "white"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                activityDialog.visible = false
            }
        }
    }
}
