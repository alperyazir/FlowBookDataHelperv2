import QtQuick

Item {
    property real biggestWidth: 0
    property real biggestHeight: 0
    property var dragMap: []
    property var shuffledWords: []
    property string standColor: "black" // myColors.standColor
    id: root
    anchors.fill: parent
    Rectangle {
        id: wordsCover
        anchors.fill: parent
        radius: 10
        color:"transparent"
        //border.color: myColors.standColor
        z: 2

        Flow  {
            id: wordsRow
            spacing: 10
            width: root.biggestWidth*root.shuffledWords.length + (root.shuffledWords.length - 1)*10  <  parent.width ? root.biggestWidth*root.shuffledWords.length + (root.shuffledWords.length - 1)*10 : parent.width
            height: parent.height
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                id: wordsRepeater
                model: root.shuffledWords
                Item {
                    property bool isCorrect : false
                    id: rootDragItem
                    width: root.biggestWidth / 1.1
                    height: root.biggestHeight / 1.1
                    MouseArea {
                        property string text: modelData

                        id: mouseArea
                        anchors.fill: parent;
                        drag.target: tile

                        onReleased: {
                            tile.border.color = root.standColor
                            tile.resultStatus = false
                            tile.correctTile = false
                            root.dragMap[index].isCorrect = false
                            if (tile.Drag.target !== null && !tile.Drag.target.isOccupied) {
                                parent = tile.Drag.target
                                parent.isOccupied = true

                                if(parent.type === "dragdroppicturegroup") {
                                    root.dragMap[index].isCorrect = (parent.correctAnswerGroup.indexOf(tile.text) === -1 ? false: true)
                                }
                                else
                                {
                                    root.dragMap[index].isCorrect = (parent.correctAnswerText === tile.text)
                                }


                            } else {
                                parent = rootDragItem

                            }
                        }
                        Rectangle {
                            property string text: modelData
                            property bool resultStatus : false
                            property bool correctTile: false
                            id: tile
                            width: parent.width
                            height: parent.height
                            Drag.keys: [ "thissouldbeasecret" ]
                            Drag.active: mouseArea.drag.active
                            Drag.hotSpot.x: rootDragItem.width/2
                            Drag.hotSpot.y: rootDragItem.height/2
                            color: "transparent"// myColors.standColor
                            border.color: "black" //myColors.standColor
                            border.width: 1
                            radius: 5
                            Text {
                                id: tileText
                                text: tile.text
                                color: myColors.standColor
                                width: parent.width * .9
                                height: parent.height * .9
                                //font.family: fontRalewayRegular.name
                                font.bold: true
                                minimumPixelSize: 1
                                font.pixelSize: 25
                                fontSizeMode: Text.Fit
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.horizontalCenter: parent.horizontalCenter
                            }


                            Image {
                                id: statusImg
                                source: parent.correctTile ? "qrc:/icons/correct.svg" : "qrc:/icons/incorrect.svg"
                                fillMode: Image.PreserveAspectFit
                                height: mainwindow.height * 30 / 1080
                                x: parent.width - width/2
                                y: -height/2
                                visible : parent.resultStatus
                                antialiasing: true
                            }
                            states: State {
                                when: mouseArea.drag.active
                                ParentChange { target: tile; parent: rootDragItem }
                                AnchorChanges { target: tile; anchors.verticalCenter: undefined; anchors.horizontalCenter: undefined }
                            }
                        }

                        Component.onCompleted: {
                            root.dragMap.push({dragItem: mouseArea, dragItemParent: mouseArea.parent, dragItemText: tile, isCorrect: false})
                        }
                    }
                }
            }
        }
    }
}
