
import QtQuick
import QtQuick.Controls
import QtQuick.Shapes

import "../"

Rectangle {
    property var sentences: []
    property var shuffledWords: []
    property string headerText
    property string dash: "  ........................  "
    signal closed()
    property var dragMap: []
    property var dropMap: []
    property var pathMap: [{"sx": 0, "sy": 0, "ex": 0, "ey": 0, "color": "gray"}]
    property string correctColor: myColors.correctColor
    property string wrongColor: myColors.wrongColor
    property string audio_path
    property real spacing: Screen.width * 20 /mainwindow.width
    property bool isTextOnLeft: false
    property real textFontSize: 33
    z: 10

    id: root
    //clip: true
    width: parent.width
    height: parent.height
    anchors.centerIn: parent
    color: "#232f34"

    property int startX: 0
    property int startY: 0
    property int endX: 0
    property int endY: 0

    // ActivityHeader {
    //     id: header
    //     headerText: root.headerText
    //     defaultText: qsTr("Match the words.")
    // }

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

    Canvas {
        id: canvas
        anchors {
            fill: parent
            margins: 8
        }

        onPaint: {
            var ctx = getContext('2d')
            ctx.clearRect(0, 0, width, height);


            for (var i = 0; i < root.pathMap.length; i++) {
                ctx.beginPath();
                ctx.moveTo(root.pathMap[i].sx, root.pathMap[i].sy);
                ctx.lineTo(root.pathMap[i].ex, root.pathMap[i].ey);
                ctx.lineWidth = 3
                ctx.strokeStyle = pathMap[i].color

                ctx.stroke();
            }
        }
    }

    Item {
        id: activityCoverRect
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        property real itemspacing:  5//Screen.height * 5 / 1080
        property real tileHeight: (((height - (shuffledWords.length-1) * itemspacing ))  / shuffledWords.length) > 140 ?  140 : (((height - (shuffledWords.length-1) * itemspacing ))  / shuffledWords.length)


        Row {
            anchors.fill: parent
            Item {
                id: wordsRect
                width: parent.width / 5 * 2
                height: parent.height

                Column {
                    width: parent.width
                    //height: parent.height
                    spacing: activityCoverRect.itemspacing
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        id: wordsRepeater
                        model: shuffledWords

                        Row {
                            width: parent.width
                            height: activityCoverRect.tileHeight

                            Item {
                                width: parent.width - (matchImage.visible ? matchImage.width : 0) - rootDragItem.width - space1.width - space2.width
                                height: parent.height
                                anchors.verticalCenter: parent.verticalCenter
                                FlowText {
                                    width: parent.width
                                    height: parent.height / 2
                                    text: modelData.word
                                    anchors.centerIn: parent
                                    horizontalAlignment:  Text.AlignRight
                                    font.pixelSize: root.textFontSize / Screen.devicePixelRatio
                                    fontSizeMode: Text.FixedSize
                                    color: "#009ca6"
                                    //font.pixelSize: 25
                                }

                                TapHandler {
                                    target: parent
                                    onTapped: {
                                        print(modelData.imagePath,"-", modelData.imagePath.length, "-",fImg.source, "-",matchImage.visible)
                                    }
                                }
                            }
                            Item {
                                id: space1
                                width: root.spacing
                                height: parent.height
                            }

                            Item {
                                width: height
                                height: parent.height
                                id: matchImage
                                visible: modelData.imagePath.length !== 0
                                Image {
                                    id: fImg
                                    source: modelData.imagePath.length === 0 ? "" : "file:" + appPath + modelData.imagePath
                                    width: parent.width
                                    height: parent.height
                                    fillMode: Image.PreserveAspectFit
                                    visible: parent.visible
                                }
                            }
                            Item {
                                id: space2
                                width: matchImage.visible ? root.spacing : 0
                                height: parent.height
                            }

                            Item {
                                id: rootDragItem
                                width: height
                                height: parent.height / 2
                                anchors.verticalCenter: parent.verticalCenter


                                Rectangle {
                                    property bool resultStatus: false
                                    property bool correctTile: false
                                    id: dragItemCover
                                    width: height
                                    height: rootDragItem.height
                                    color: "gray"
                                    radius: height/2
                                    anchors.centerIn: rootDragItem
                                }

                                MouseArea {
                                    property string text: modelData.word
                                    id: mouseArea
                                    width: tile.paintedWidth
                                    height: tile.paintedHeight
                                    drag.target: tile
                                    anchors.centerIn: dragItemCover


                                    onReleased: {

                                        if (tile.Drag.target !== null && !tile.Drag.target.isOccupied) {
                                            parent = tile.Drag.target
                                            parent.isOccupied = true
                                            root.dragMap[index].isCorrect = (parent.correctAnswerText === tile.tileText)
                                        } else {
                                            parent = rootDragItem
                                            root.dragMap[index].isCorrect = false
                                        }

                                        var mapped = mapToItem(canvas, mouseArea.x + mouseArea.width/2, mouseArea.y + mouseArea.height/2)
                                        root.pathMap[index].ex = mapped.x
                                        root.pathMap[index].ey = mapped.y
                                        canvas.requestPaint()
                                    }

                                    onPressed: {
                                        root.pathMap[index].color = "gray"
                                        if(parent === rootDragItem) {
                                            var mapped = tile.mapToItem(canvas, tile.x + tile.paintedWidth/2, tile.y + tile.paintedHeight/2)
                                            root.pathMap[index].sx = mapped.x
                                            root.pathMap[index].sy = mapped.y
                                        }
                                    }

                                    onPositionChanged: {
                                        var mapped = tile.parent.mapToItem(canvas, tile.x + tile.width/2, tile.y + tile.height/2)
                                        root.pathMap[index].ex = mapped.x
                                        root.pathMap[index].ey = mapped.y
                                        canvas.requestPaint()
                                    }

                                    Image {
                                        property string tileText: modelData.word
                                        id: tile
                                        source: "qrc:/icons/playArrow.png"
                                        width: height
                                        height: rootDragItem.height
                                        fillMode: Image.PreserveAspectFit

                                        Drag.keys: [ "thissouldbeasecret" ]
                                        Drag.active: mouseArea.drag.active
                                        Drag.source: mouseArea
                                        Drag.hotSpot.x: tile.width/2
                                        Drag.hotSpot.y: tile.height/2

                                        Image {
                                            id: statusImg
                                            source: dragItemCover.correctTile ? "qrc:/icons/correct.svg" : "qrc:/icons/incorrect.svg"
                                            fillMode: Image.PreserveAspectFit
                                            height: mainwindow.height * 30 / 1080
                                            x: parent.width - width/2
                                            y: -height/2
                                            visible : dragItemCover.resultStatus
                                            antialiasing: true

                                        }

                                        states: State {
                                            when: mouseArea.drag.active
                                            ParentChange { target: tile; parent: rootDragItem }
                                            AnchorChanges { target: tile; anchors.verticalCenter: undefined; anchors.horizontalCenter: undefined }
                                        }
                                    }
                                    Component.onCompleted: {
                                        root.pathMap.push({sx: 0, sy: 0, ex:0, ey:0, color: "gray"})
                                        root.dragMap.push({dragItem: mouseArea, dragItemParent: mouseArea.parent, isCorrect: false, dragItemCover: dragItemCover})
                                    }
                                }
                            }
                        }
                    }
                }

            }

            Item {
                width: parent.width / 5 * 1
                height: parent.height

            }

            Item {
                id: secRect
                width: parent.width / 5 * 2
                height: parent.height
                Column {
                    width: parent.width
                    //height: parent.height
                    spacing: activityCoverRect.itemspacing
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        id: sentencesRepeater
                        model: sentences

                        Row {
                            width: parent.width
                            height: activityCoverRect.tileHeight
                            Item {
                                id: dropRect
                                width: height
                                height: parent.height/2
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    id: dropRect1
                                    height: parent.height
                                    width: height
                                    color: "#028fb2"
                                    radius: height/2
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                DropArea {
                                    property var correctAnswerText : modelData.word
                                    property bool isOccupied : false
                                    id: dragTarget
                                    anchors.fill: dropRect

                                    keys: [ "thissouldbeasecret" ]
                                    states: [
                                        State {
                                            when: dragTarget.containsDrag && !dragTarget.isOccupied
                                            PropertyChanges {
                                                target: dropRect1
                                                color: myColors.highlightColor
                                                opacity: 0.3
                                            }
                                        }
                                    ]
                                    onChildrenChanged: {
                                        if (children.length === 0) {
                                            isOccupied = false
                                        }
                                    }
                                }
                                Component.onCompleted: {
                                    root.dropMap.push({dropItem: dragTarget})
                                }
                            }
                            Item {
                                width: root.spacing
                                height: parent.height
                            }

                            Item {
                                width: matchImage2.width
                                height: parent.height
                                anchors.verticalCenter: parent.verticalCenter
                                visible: root.isTextOnLeft

                                FlowText {
                                    width: parent.width
                                    height: parent.height/2
                                    text: qsTr(modelData.sentence)
                                    anchors.centerIn: parent
                                    horizontalAlignment: Text.AlignLeft
                                    font.pixelSize: root.textFontSize / Screen.devicePixelRatio
                                    fontSizeMode: Text.FixedSize
                                    color: "#009ca6"
                                }
                            }

                            Item {
                                width: visible ? height : 0
                                height: parent.height
                                visible: modelData.imagePath.length !== 0
                                id: matchImage2
                                Image {
                                    source: modelData.imagePath.length === 0 ? "" : "file:" + appPath + modelData.imagePath
                                    width: parent.width
                                    height: parent.height
                                    fillMode: Image.PreserveAspectFit
                                }
                            }
                            Item {
                                id: spacer
                                width: root.spacing
                                height: parent.height
                                visible: matchImage2.visible
                            }
                            Item {
                                width: parent.width - (matchImage2.visible ? matchImage2.width : 0) - dropRect.width
                                height: parent.height
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !root.isTextOnLeft

                                FlowText {
                                    width: parent.width
                                    height: parent.height/2
                                    text: qsTr(modelData.sentence)
                                    anchors.centerIn: parent
                                    horizontalAlignment: Text.AlignLeft
                                    font.pixelSize: root.textFontSize / Screen.devicePixelRatio
                                    fontSizeMode: Text.FixedSize
                                    color: "#009ca6"
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function showAnswer() {
        // for (var i = 0; i < root.dragMap.length; i++) {
        //     root.dragMap[i].dragItem.parent = root.dragMap[i].dragItemParent
        //     root.dragMap[i].isCorrect = false
        //     root.dragMap[i].dragItemCover.resultStatus = false

        //     root.dragMap[i].dragItemCover.color = "gray"
        //     //root.dropMap[i].dropItem.parent.color = "gray"

        //     root.pathMap[i].sx = 0
        //     root.pathMap[i].sy = 0
        //     root.pathMap[i].ex = 0
        //     root.pathMap[i].ey = 0
        //     root.pathMap[i].color = "gray"
        //     canvas.requestPaint()
        // }

        // root.dragMap = []
        // root.dropMap = []

        // root.shuffledWords = []
        // root.sentences = []

        for (var i = 0; i < root.dragMap.length; i++) {
            root.dragMap[i].dragItemCover.resultStatus = true
            //if(root.dragMap[i].dragItem.parent === root.dragMap[i].dragItemParent){
            var mapped = root.dragMap[i].dragItem.mapToItem(canvas, root.dragMap[i].dragItem.x + root.dragMap[i].dragItem.width/2,
                                                            root.dragMap[i].dragItem.y + root.dragMap[i].dragItem.height/2)
            root.pathMap[i].sx = mapped.x
            root.pathMap[i].sy = mapped.y
            //}


            for (var j = 0; j < root.dropMap.length; j++) {
                if (root.dragMap[i].dragItem.text === root.dropMap[j].dropItem.correctAnswerText){
                    root.dragMap[i].dragItem.parent = root.dropMap[j].dropItem

                    root.dragMap[i].isCorrect = true
                    mapped = root.dragMap[i].dragItem.parent.mapToItem(canvas, root.dragMap[i].dragItem.parent.x + root.dragMap[i].dragItem.parent.width/2,
                                                                       root.dragMap[i].dragItem.parent.y + root.dragMap[i].dragItem.parent.height/2)
                    root.pathMap[i].ex = mapped.x
                    root.pathMap[i].ey = mapped.y
                    break;
                }
            }
            root.pathMap[i].color = root.correctColor
            root.dragMap[i].dragItemCover.color = root.correctColor
            root.dragMap[i].dragItemCover.correctTile = true
        }
        canvas.requestPaint()
    }

    function reset() {
        for (var i = 0; i < root.dragMap.length; i++) {
            root.dragMap[i].dragItem.parent = root.dragMap[i].dragItemParent
            root.dragMap[i].isCorrect = false
            root.dragMap[i].dragItemCover.resultStatus = false

            root.dragMap[i].dragItemCover.color = "gray"
            //root.dropMap[i].dropItem.parent.color = "gray"

            root.pathMap[i].sx = 0
            root.pathMap[i].sy = 0
            root.pathMap[i].ex = 0
            root.pathMap[i].ey = 0
            root.pathMap[i].color = "gray"
            canvas.requestPaint()
        }

        // root.dragMap = []
        // root.dropMap = []

        // root.shuffledWords = []
        // root.sentences = []
    }



    Button {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        width: 50
        height: 40
        text: "Show"
        background: Rectangle {
            color: parent.hovered ? "#2A3337" : "#1A2327"
            border.color: "#009ca6"
            border.width: 1
            radius: 2
        }
        contentItem: Text {
            text: parent.text
            color: "white"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        MouseArea {
            anchors.fill: parent
            onClicked: showAnswer()
        }
    }
}
