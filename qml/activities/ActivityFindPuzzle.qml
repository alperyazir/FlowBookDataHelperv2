import QtQuick
import QtQuick.Controls


import "ActivityPuzzleFindWords.js" as PuzzleLogic
import "../"

Rectangle {
    property string headerText
    property var secretWords: []
    signal closed()
    id: root
    width: parent.width
    height: parent.height
    color: "#232f34"

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

    Rectangle {
        id: actColumn
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 20
        color: "#232f34"

        Column {
            anchors.left: parent.left
            anchors.right: sentencesRect.left
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Repeater {

                id: wordsRepeater
                model: root.secretWords
                Rectangle {
                    property bool isDiscovered: false
                    property string word: modelData
                    width: parent.width
                    height: puzzleListView.height / 25
                    radius: 5

                    FlowText {
                        text: modelData
                        font.strikeout: parent.isDiscovered
                        font.italic: parent.isDiscovered
                        font.bold: true
                    }
                }
            }
        }

        Rectangle {
            id: sentencesRect
            anchors.margins: 2
            width: height
            height: parent.height
            radius: 5
            color: "#232f34"
            z: 1
            border.color: "black"
            anchors.horizontalCenter: parent.horizontalCenter

            ListView {
                interactive: false
                id: puzzleListView
                anchors.fill: parent
                model: puzzleModel
                orientation: Qt.Vertical
                spacing: 0
                delegate: Row {
                    spacing: 0
                    Repeater {
                        model: rowModel
                        Rectangle {
                            id: coverRect
                            width: puzzleListView.width / 15
                            height: puzzleListView.height / 15
                            color: "lightblue"
                            Rectangle {
                                width: parent.width * .93
                                height: parent.height * .93
                                radius: 5
                                color: model.discovered ? model.color : model.selected ? "lightblue" : "white"
                                anchors.centerIn: parent
                                Text {
                                    text: model.letter
                                    font.bold: true
                                    font.pixelSize: 30
                                    anchors.fill: parent
                                    fontSizeMode: Text.Fit
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                }

                MouseArea {
                    property bool started: false
                    property int direction:-1 // 0 dikey, 1 yatay, 2 çapraz
                    property int startX: -1
                    property int startY: -1
                    property var hist: []
                    anchors.fill: parent
                    onPressed: {
                        started: false
                        if (mouseX % ((puzzleListView.width / 15) + puzzleListView.spacing) >  puzzleListView.width / 15) {
                            return
                        }

                        if (mouseY % ((puzzleListView.height / 15) + puzzleListView.spacing) >  puzzleListView.height / 15) {
                            return
                        }
                        started = true

                        direction = -1
                        startY = parseInt(mouseX / (puzzleListView.width / 15 + puzzleListView.spacing))
                        startX = parseInt(mouseY / (puzzleListView.height / 15 + puzzleListView.spacing))
                        puzzleModel.get(startX).rowModel.get(startY).selected = true
                        hist = []
                        hist.push([startX, startY])
                    }

                    onPositionChanged: {
                        if (!started) {
                            return
                        }

                        if (mouseX % ((puzzleListView.width / 15) + puzzleListView.spacing) >  puzzleListView.width / 15) {
                            return
                        }

                        if (mouseY % ((puzzleListView.height / 15) + puzzleListView.spacing) >  puzzleListView.height / 15) {
                            return
                        }

                        var secondY = parseInt((mouseX) / (puzzleListView.width / 15 +puzzleListView.spacing ))
                        var secondX = parseInt((mouseY) / (puzzleListView.height / 15 +puzzleListView.spacing ))

                        if (!puzzleModel.get(secondX).rowModel.get(secondY).selected) {
                            if ((direction === -1 || direction === 0) && (Math.abs(secondX - hist[hist.length-1][0]) > 0 && Math.abs(secondY - hist[hist.length-1][1]) === 0)) {
                                direction = 0
                                puzzleModel.get(secondX).rowModel.get(secondY).selected = true
                                hist.push([secondX, secondY])
                            } else if((direction === -1 || direction === 1) && (Math.abs(secondX - hist[hist.length-1][0]) === 0 && Math.abs(secondY - hist[hist.length-1][1]) > 0)) {
                                direction = 1
                                puzzleModel.get(secondX).rowModel.get(secondY).selected = true
                                hist.push([secondX, secondY])
                            } /*else if((direction === -1 || direction === 2) && (Math.abs(secondX - hist[hist.length-1].x) > 0 && Math.abs(secondY - hist[hist.length-1].y) > 0)) {
                                direction = 2
                                puzzleModel.get(secondX).rowModel.get(secondY).selected = true
                                hist.push({"x": secondX, "y": secondY})
                            }*/

                        } else if (puzzleModel.get(secondX).rowModel.get(secondY).selected){
                            if (hist.length > 2) {

                                if (hist[hist.length-2][0] === secondX && hist[hist.length-2][1] === secondY) {
                                    puzzleModel.get(hist[hist.length-1][0]).rowModel.get(hist[hist.length-1][1]).selected = false
                                    hist.pop()
                                }
                            } else if(hist.length === 2) {
                                if (hist[0][0] === secondX && hist[0][1] === secondY) {
                                    puzzleModel.get(hist[1][0]).rowModel.get(hist[1][1]).selected = false
                                    direction = -1
                                    hist.pop()
                                }
                            }
                        }
                    }

                    onReleased: {
                        var correctWord = PuzzleLogic.isCoordinateMatch(hist, PuzzleLogic.allWordsCoordinates)
                        if (correctWord) {
                            // change color
                            var nColor = PuzzleLogic.getRandomColor()
                            var selectedWord = ""
                            for (var l = 0; l < hist.length; l++) {
                                puzzleModel.get(hist[l][0]).rowModel.get(hist[l][1]).color = nColor
                                puzzleModel.get(hist[l][0]).rowModel.get(hist[l][1]).discovered = true
                                selectedWord += puzzleModel.get(hist[l][0]).rowModel.get(hist[l][1]).letter
                            }

                            for (var i = 0; i < wordsRepeater.count; i++ ) {
                                if (selectedWord === wordsRepeater.itemAt(i).word) {
                                    wordsRepeater.itemAt(i).isDiscovered = true
                                }
                            }
                        } else {
                            // unselect selection
                            for (var m = 0; m < hist.length; m++) {
                                puzzleModel.get(hist[m][0]).rowModel.get(hist[m][1]).selected = false
                            }
                        }
                    }
                }
            }


            ListModel {
                id: puzzleModel
            }
        }
    }

    Button {
        property bool show: false
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        width: 50
        height: 40
        text: !show ? "Show" : "Hide"
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
            onClicked: {
                parent.show  = !parent.show
                showAnswer(parent.show)
            }
        }
    }


    function showAnswer(eyeState) {
        for (var i = 0; i < PuzzleLogic.allWordsCoordinates.length; i++) {
            var nColor = PuzzleLogic.getRandomColor()
            for (var j = 0; j < PuzzleLogic.allWordsCoordinates[i].length; j++) {
                puzzleModel.get(PuzzleLogic.allWordsCoordinates[i][j][0]).rowModel.get(PuzzleLogic.allWordsCoordinates[i][j][1]).discovered = eyeState
                puzzleModel.get(PuzzleLogic.allWordsCoordinates[i][j][0]).rowModel.get(PuzzleLogic.allWordsCoordinates[i][j][1]).color = eyeState ? nColor : "white"
                if (!eyeState) {
                    puzzleModel.get(PuzzleLogic.allWordsCoordinates[i][j][0]).rowModel.get(PuzzleLogic.allWordsCoordinates[i][j][1]).selected = false
                }
            }
        }

        for (var i = 0; i < wordsRepeater.count; i++ ) {
            wordsRepeater.itemAt(i).isDiscovered = eyeState
        }
    }



    function reset() {
        showAnswersButton.eyeState = false
        PuzzleLogic.recreatePuzzle()

        for (var i = 0; i < wordsRepeater.count; i++ ) {
            wordsRepeater.itemAt(i).isDiscovered = false
        }
    }

    function setWords(words) {
        PuzzleLogic.words = words
        PuzzleLogic.recreatePuzzle()
    }
}
