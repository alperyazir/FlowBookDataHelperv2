import QtQuick
import QtQuick.Controls

import "activities"

Rectangle {
    property string imageSource
    property string headerText
    property var wordLists: []
    property var answers: []
    property var activityModelData
    id: root
    width: mainwindow.width*3/4
    height: mainwindow.height*3/4
    anchors.right: sideBar.left
    anchors.margins: 20
    anchors.verticalCenter: parent.verticalCenter
    visible: false
    color: "gray"
    MouseArea {
        anchors.fill: parent
        drag.target: parent
    }

    // Flow {
    //     id: flowWords
    //     anchors.top: headerRect.bottom
    //     anchors.topMargin: 10
    //     anchors.horizontalCenter: parent.horizontalCenter
    //     spacing: 5
    //     Repeater {
    //         model: root.wordLists
    //         Rectangle {
    //             width: 100
    //             height: 30
    //             color: "transparent"
    //             border.color: "blue"
    //             border.width: 1
    //             FlowText{
    //                 width: parent.width
    //                 height: parent.height
    //                 text: modelData
    //             }
    //         }
    //     }
    // }


    // Image {
    //     id: activityImage
    //     source: "file:" + appPath + root.imageSource
    //     antialiasing: true
    //     smooth: true
    //     fillMode: Image.PreserveAspectFit
    //     // anchors.top: flowWords.bottom
    //     // anchors.bottom: buttons.top
    //     anchors.left: parent.left
    //     anchors.right: parent.right
    //     anchors.margins: 10

    //     Repeater {
    //         id: answerRepeater
    //         model: root.answers
    //         Rectangle {
    //             property bool showAnswer: false
    //             property var correctAnswerText: modelData.text
    //             property real xScale : activityImage.paintedWidth / activityImage.sourceSize.width
    //             property real yScale : activityImage.paintedHeight / activityImage.sourceSize.height
    //             id: dropRectangle
    //             x: (activityImage.width/2 - activityImage.paintedWidth/2) + modelData.coords.x * xScale
    //             y: (activityImage.height/2 - activityImage.paintedHeight/2)+ modelData.coords.y * yScale
    //             width: modelData.coords.width * xScale
    //             height: modelData.coords.height * yScale
    //             color: "orange"
    //             radius: 5

    //             FlowText {
    //                 text: modelData.text
    //             }
    //         }
    //     }


    //     MouseArea {
    //         id: mouseArea
    //         anchors.fill: parent
    //         onPressAndHold: {
    //             // var adjustedX = mouseArea.mouseX * activityImage.paintedWidth / activityImage.sourceSize.width
    //             // var adjustedY = mouseArea.mouseY
    //             // print(mouseArea.mouseX ,mouseArea.mouseY)

    //             // // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
    //             // var originalX = adjustedX * (activityImage.sourceSize.width / activityImage.paintedWidth)
    //             // var originalY = adjustedY * (activityImage.sourceSize.height / activityImage.paintedHeight)

    //             var originalWidth = activityImage.sourceSize.width;
    //             var originalHeight = activityImage.sourceSize.height;

    //             var displayedWidth = activityImage.width;
    //             var displayedHeight = activityImage.height;

    //             var x = mouse.x;
    //             var y = mouse.y;
    //             var horizontalEmptySpace = (activityImage.width - displayedWidth) / 2;
    //             var verticalEmptySpace = (activityImage.height - displayedHeight) / 2;

    //             // Orijinal image üzerindeki noktaya dönüştür
    //             var xInOriginalImage = (x - horizontalEmptySpace) * (originalWidth / displayedWidth);
    //             var yInOriginalImage = (y - verticalEmptySpace) * (originalHeight / displayedHeight);

    //             root.activityModelData.createNewAnswer(xInOriginalImage,yInOriginalImage, 100, 50)
    //             config.bookSets[0].saveToJson();
    //             print("Changes Are Saved activity Dialog")
    //         }
    //     }
    // }


    // ActivityMatchTheWords {
    //     id: activityMatch
    //     visible: root.activityModelData.type === "matchTheWords"
    //     shuffledWords: root.activityModelData.matchWord
    //     sentences: root.activityModelData.sentences
    // }



    function createActivityMatchTheWord() {
        var component = Qt.createComponent("activities/ActivityMatchTheWords.qml")

        var activityMatch = component.createObject(root, {});
        activityMatch.headerText = root.activityModelData.headerText
        activityMatch.shuffledWords= root.activityModelData.matchWord
        activityMatch.sentences = root.activityModelData.sentences
        content.enableRightClick(false)

        activityMatch.onVisibleChanged.connect(function(visible) {
            if(!visible) {
                content.enableRightClick(true)
            }
        })
    }

    function createActivityDragDropPicture() {
        var component = Qt.createComponent("activities/ActivityDragDropPicture.qml")
        var activityDragDropPicture = component.createObject(root, {});
        activityDragDropPicture.headerText = root.activityModelData.headerText
        activityDragDropPicture.shuffledWords= root.activityModelData.words
        activityDragDropPicture.imageSource = "file:" + appPath + root.activityModelData.sectionPath
        activityDragDropPicture.answers = root.activityModelData.answers
        activityDragDropPicture.activityModelData = root.activityModelData
        content.enableRightClick(false)
        activityDragDropPicture.onVisibleChanged.connect(function(visible) {
            if(!visible) {
                content.enableRightClick(true)
            }
        })

    }

    function createActivityDragDropPictureGroup() {
        var component = Qt.createComponent("activities/ActivityDragDropPictureGroup.qml")

        var activityDragDropPictureGroup = component.createObject(root, {});
        activityDragDropPictureGroup.headerText = root.activityModelData.headerText
        activityDragDropPictureGroup.shuffledWords= root.activityModelData.words
        activityDragDropPictureGroup.imageSource = "file:" + appPath + root.activityModelData.sectionPath
        activityDragDropPictureGroup.answers = root.activityModelData.answers
        activityDragDropPictureGroup.activityModelData = root.activityModelData
        content.enableRightClick(false)

        activityDragDropPictureGroup.onVisibleChanged.connect(function(visible) {
            if(!visible) {
                content.enableRightClick(true)
            }
        })
    }

    function createActivityFillPicture() {
        var component = Qt.createComponent("activities/ActivityFillPicture.qml")
        var activityDragDropPicture = component.createObject(root, {});
        activityDragDropPicture.headerText = root.activityModelData.headerText
        activityDragDropPicture.shuffledWords= root.activityModelData.words
        activityDragDropPicture.imageSource = "file:" + appPath + root.activityModelData.sectionPath
        activityDragDropPicture.answers = root.activityModelData.answers
        activityDragDropPicture.activityModelData = root.activityModelData
        content.enableRightClick(false)
        activityDragDropPicture.onVisibleChanged.connect(function(visible) {
            if(!visible) {
                content.enableRightClick(true)
            }
        })

    }

    function createActivityFindPuzzle() {
        var component = Qt.createComponent("activities/ActivityFindPuzzle.qml")
        var activityPuzzleWords = component.createObject(root, {});
        activityPuzzleWords.headerText = root.activityModelData.headerText
        activityPuzzleWords.secretWords= root.activityModelData.words
        activityPuzzleWords.setWords(root.activityModelData.words)
        content.enableRightClick(false)
        activityPuzzleWords.onVisibleChanged.connect(function(visible) {
            if(!visible) {
                content.enableRightClick(true)
            }
        })

    }

    function createActivityCircle() {
        var component = Qt.createComponent("activities/ActivityCircle.qml")
        var activityCircle = component.createObject(root, {});
        activityCircle.headerText = root.activityModelData.headerText
        activityCircle.imageSource = "file:" + appPath + root.activityModelData.sectionPath
        activityCircle.answers = root.activityModelData.answers
        activityCircle.activityModelData = root.activityModelData
        content.enableRightClick(false)
        activityCircle.onVisibleChanged.connect(function(visible) {
            if(!visible) {
                content.enableRightClick(true)
            }
        })
    }

    function createActivityMarkWithX() {
        var component = Qt.createComponent("activities/ActivityMarkWithX.qml")
        var activityMarkWithX= component.createObject(root, {});
        activityMarkWithX.headerText = root.activityModelData.headerText
        activityMarkWithX.imageSource = "file:" + appPath + root.activityModelData.sectionPath
        activityMarkWithX.answers = root.activityModelData.answers
        activityMarkWithX.activityModelData = root.activityModelData
        content.enableRightClick(false)
        activityMarkWithX.onVisibleChanged.connect(function(visible) {
            if(!visible) {
                content.enableRightClick(true)
            }
        })
    }






    // Row {
    //     id: buttons
    //     anchors.right: parent.right
    //     anchors.bottom: parent.bottom
    //     Button {
    //         text: "Answers"
    //         onClicked: {
    //             activityMatch.showAnswer()
    //         }
    //     }

    //     Button {
    //         text: "Save"
    //     }

    //     Button {
    //         text: "Cancel"
    //     }
    // }

}
