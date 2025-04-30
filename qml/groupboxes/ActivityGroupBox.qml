import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform
import QtMultimedia


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
                    audioTextField.text = newPath
                    root.sectionModelData.audioExtra.path = newPath
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
    property var sectionModelData: undefined
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
            width: parent.width * .9
            spacing: 10
            height: 40
            FlowText {
                text: "Audio Extra Path: "
                color: "white"
                anchors.centerIn: undefined
                width: parent.width * .25
                font.pixelSize: 15
                verticalAlignment: Text.AlignBottom
            }

            // TextEdit bileşeni
            TextField {
                id: audioTextField
                width: parent.width*.65
                height: parent.height
                placeholderText: "audio extra.mp3"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.sectionModelData.audioExtra.path
            }

            Rectangle {
                height: 40
                width: parent.width * 0.1
                anchors.verticalCenter: parent.verticalCenter
                color: "white"
                FlowText {
                    text: "..."
                    color: "black"
                    anchors.centerIn: undefined
                    width: parent.width
                    height: 35
                    font.pixelSize: 15
                    verticalAlignment: Text.AlignBottom
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        fileDialog.folder = "file:" + appPath + root.audioModelData.path
                        fileDialog.open()
                    }
                }
            }
        }




        Row {
            property bool isPlaying: playRecordAudio.playbackState === MediaPlayer.PlayingState
            id: audioContrller
            width: parent.width
            height: 40
            spacing: 5

            Button {
                id: playPauseButton
                width: 60
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (!audioContrller.isPlaying) {
                            playRecordAudio.source = "file:" + appPath + audioTextField.text
                            playRecordAudio.play()
                        } else {
                            playRecordAudio.pause()
                        }
                    }
                }
            }

            Slider {
                id: audioSlider
                enabled: true
                to: playRecordAudio.duration
                value: playRecordAudio.position
                width: parent.width - playPauseButton.width - audioContrller.spacing - stopButton.width
                anchors.verticalCenter: parent.verticalCenter
                onMoved: {
                    if (playRecordAudio.seekable) {
                        playRecordAudio.setPosition(value)
                    } else {
                        console.log("Media is not seekable!")
                    }
                }
            }

            Button {
                id: stopButton
                width: 60
                anchors.verticalCenter: parent.verticalCenter
                text: "Stop"
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        playRecordAudio.stop()
                    }
                }
            }
        }

        states: [
            State {
                name: "playing"
                when: playRecordAudio.playbackState === MediaPlayer.PlayingState

                PropertyChanges {
                    playPauseButton.text: "Pause"
                }

            },
            State {
                name: "paused"
                when: playRecordAudio.playbackState === MediaPlayer.PausedState || playRecordAudio.playbackState === MediaPlayer.StoppedState

                PropertyChanges {
                    playPauseButton.text: "Play"
                }
            }
        ]

        MediaPlayer {
            id: playRecordAudio
            audioOutput: AudioOutput {
                //volume: volumeSlider.value / 100.0
            }
            onSourceChanged: {
                play()
            }
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

