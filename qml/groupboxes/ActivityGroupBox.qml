import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform


import "../../qml"
import "activities"

GroupBox {

    // FileDialog bileşeni
    FileDialog {
        id: fileDialog
        title: "Select a File"
        //folder: StandardPaths.home // Varsayılan başlangıç yolu, değiştirilecektir

        onAccepted: {
            var selectedFilePath = fileDialog.file + ""; // Seçilen dosyanın tam dosya yolu
            if (selectedFilePath) {
                var newPath = findBooksFolder(selectedFilePath, "books");
                if (newPath) {
                    // audioTextField.text = newPath
                } else {
                    console.log("Books klasörü bulunamadı.");
                }
            } else {
                console.log("Dosya yolu geçersiz.");
            }
        }

        onRejected: {
            console.log("File selection was canceled")
        }
    }

    property var activityModelData: undefined
    signal removeSection()
    id: root
    title: qsTr("Activity")
    width: parent.width * .98
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    onActivityModelDataChanged: {
    }

    // Custom title style
    Column {
        anchors.fill: parent
        spacing: 10

        Row {
            height: 40
            anchors.right: parent.right

            Button {
                id: closeButton
                text: "X"
                height: 40
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        sideBar.activityVisible = false
                    }
                }
            }
        }

        DragDropPicture {
            id: ddpicture
            visible: root.activityModelData.type === "dragdroppicture"
            enabled: visible
            width: parent.width

        }

        MatchTheWords {
            id: matchthewords
            visible: root.activityModelData.type === "matchTheWords"
            enabled: visible
            width: parent.width
        }

        DragDropPicture {
            id: ddppicturegroup
            visible: root.activityModelData.type === "dragdroppicturegroup"
            enabled: visible
            width: parent.width

        }

        FillPicture {
            id: fillpicture
            visible: root.activityModelData.type === "fillpicture"
            enabled: visible
            width: parent.width

        }

        PuzzleFindWords {
            id: findPuzzle
            visible: root.activityModelData.type === "puzzleFindWords"
            enabled: visible
            width: parent.width

        }

        Circle {
            id: activityCircle
            visible: root.activityModelData.type === "circle"
            enabled: visible
            width: parent.width
        }

        MarkWithX {
            id: activityMarkWithX
            visible: root.activityModelData.type === "markwithx"
            enabled: visible
            width: parent.width
        }

        Row {
            height: 40
            anchors.horizontalCenter: parent.horizontalCenter
            Button {
                text: "Activity"
                onClicked: {
                    activityDialog.visible = true
                    activityDialog.wordLists = root.activityModelData.words
                    activityDialog.imageSource = root.activityModelData.sectionPath
                    activityDialog.headerText = root.activityModelData.headerText
                    activityDialog.answers = root.activityModelData.answers
                    activityDialog.activityModelData = root.activityModelData

                    if (root.activityModelData.type === "matchTheWords")
                        activityDialog.createActivityMatchTheWord()

                    else if (root.activityModelData.type === "dragdroppicture")
                        activityDialog.createActivityDragDropPicture()

                    else if (root.activityModelData.type === "dragdroppicturegroup")
                        activityDialog.createActivityDragDropPictureGroup()

                    else if (root.activityModelData.type === "fillpicture")
                        activityDialog.createActivityFillPicture()

                    else if (root.activityModelData.type === "puzzleFindWords")
                        activityDialog.createActivityFindPuzzle()

                    else if (root.activityModelData.type === "circle")
                        activityDialog.createActivityCircle()

                    else if (root.activityModelData.type === "markwithx")
                        activityDialog.createActivityMarkWithX()



                }
            }

            Button {
                text: "Save"
                onClicked: saveChanges()
            }

            Button {
                text: "Delete"
                onClicked: {

                    confirmBox.visible = true
                }
            }
        }

        Rectangle {
            id: confirmBox
            width: parent.width /2
            height: 100
            color: "transparent"
            border.color: "red"
            radius: 10
            visible: false // Başlangıçta visible true, bir işlemi başlatırken görünür olacak
            anchors.horizontalCenter: parent.horizontalCenter

            Column {
                anchors.centerIn: parent
                spacing: 10

                Text {
                    text: "Are you sure?"
                    font.pixelSize: 15
                    color: "white"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Row {
                    spacing: 20
                    anchors.horizontalCenter: parent.horizontalCenter

                    Button {
                        text: "Yes"
                        onClicked: {
                            removeSection()
                            confirmBox.visible = false
                            sideBar.activityVisible = false
                        }
                    }

                    Button {
                        text: "No"
                        onClicked: {

                            confirmBox.visible = false
                        }
                    }
                }
            }
        }
    }

    function saveChanges() {

        // drag drop picture
        for ( var i = 0; i < ddpicture.words.count; i++) {
            root.activityModelData.words[i] =  ddpicture.words.itemAt(i).wText
        }
        // drag drop picture group
        for ( var i = 0; i < ddppicturegroup.words.count; i++) {
            root.activityModelData.words[i] =  ddppicturegroup.words.itemAt(i).wText
        }
        // fill picture
        for ( var i = 0; i < fillpicture.words.count; i++) {
            root.activityModelData.words[i] =  fillpicture.words.itemAt(i).wText
        }

        // Match Word
        for ( var i = 0; i < matchthewords.words.count; i++) {
            root.activityModelData.matchWord[i].word =  matchthewords.words.itemAt(i).wordText
            root.activityModelData.matchWord[i].imagePath =  matchthewords.words.itemAt(i).imagePathText
        }
        // Match sentence
        for ( var i = 0; i < matchthewords.sentences.count; i++) {
            root.activityModelData.sentences[i].word =  matchthewords.words.itemAt(parseInt(matchthewords.sentences.itemAt(i).wordText)).wordText
            root.activityModelData.sentences[i].imagePath =  matchthewords.sentences.itemAt(i).imagePathText
            root.activityModelData.sentences[i].sentence =  matchthewords.sentences.itemAt(i).sentenceText
        }

        // find puzzle
        for ( var i = 0; i < findPuzzle.words.count; i++) {
            root.activityModelData.words[i] =  findPuzzle.words.itemAt(i).wText
        }

        config.bookSets[0].saveToJson();
        toast.show("Changes are saved to File!")
    }

}

