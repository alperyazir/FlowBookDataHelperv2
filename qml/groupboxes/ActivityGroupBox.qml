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
    title: qsTr("")
    width: parent.width * .98
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    onActivityModelDataChanged: {
    }

    background: Rectangle {
        color: "#232f34"
        border.color: "#009ca6"
        border.width: 1
        radius: 6
    }

    // Custom title style
    Column {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 15
        Row {
            width: parent.width
            height: 40
            spacing: 10

            Text {
                text: "Activity"
                color: "white"
                font.pixelSize: 24
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                width: parent.width - closeButton.width - 90
                height: 1
            }

            Button {
                id: closeButton
                text: "X"
                width: 32
                height: 32
                anchors.verticalCenter: parent.verticalCenter

                background: Rectangle {
                    color: parent.hovered ? "#2A3337" : "#1A2327"
                    border.color: "#009ca6"
                    border.width: 1
                    radius: 4
                }

                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 14
                }
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

            Text {
                text: " Path:"
                color: "white"
                font.pixelSize: 14
                width: 60
                anchors.verticalCenter: parent.verticalCenter
            }


            TextField {
                id: audioTextField
                width: parent.width - 100
                height: 36
                text: root.sectionModelData.audioExtra.path
                placeholderText: "audio extra path "
                color: "white"

                background: Rectangle {
                    color: "#1A2327"
                    border.color: parent.focus ? "#009ca6" : "#445055"
                    border.width: 1
                    radius: 4
                }
            }

            Button {
                width: 36
                height: 36
                anchors.verticalCenter: parent.verticalCenter

                background: Rectangle {
                    color: parent.hovered ? "#2A3337" : "#1A2327"
                    border.color: "#009ca6"
                    border.width: 1
                    radius: 4
                }

                contentItem: Text {
                    text: "..."
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        fileDialog.folder = "file:" + appPath + root.sectionModelData.audioExtra.path;
                        fileDialog.open();
                    }
                }
            }
        }

        Row {
            id: audioContrller
            property bool isPlaying: playRecordAudio.playbackState === MediaPlayer.PlayingState
            width: parent.width
            height: 40
            spacing: 10

            Button {
                id: playPauseButton
                width: 80
                height: 36
                anchors.verticalCenter: parent.verticalCenter

                background: Rectangle {
                    color: parent.hovered ? "#00b3be" : "#009ca6"
                    radius: 4
                }

                contentItem: Text {
                    text: audioContrller.isPlaying ? "Pause" : "Play"
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (!audioContrller.isPlaying) {
                            playRecordAudio.source = "file:" + appPath + audioTextField.text;
                            playRecordAudio.play();
                        } else {
                            playRecordAudio.pause();
                        }
                    }
                }
            }

            Slider {
                id: audioSlider
                enabled: true
                to: playRecordAudio.duration
                value: playRecordAudio.position
                width: parent.width - playPauseButton.width - stopButton.width - 20
                height: 36
                anchors.verticalCenter: parent.verticalCenter

                background: Rectangle {
                    x: audioSlider.leftPadding
                    y: audioSlider.topPadding + audioSlider.availableHeight / 2 - height / 2
                    width: audioSlider.availableWidth
                    height: 4
                    radius: 2
                    color: "#1A2327"

                    Rectangle {
                        width: audioSlider.visualPosition * parent.width
                        height: parent.height
                        color: "#009ca6"
                        radius: 2
                    }
                }

                handle: Rectangle {
                    x: audioSlider.leftPadding + audioSlider.visualPosition * (audioSlider.availableWidth - width)
                    y: audioSlider.topPadding + audioSlider.availableHeight / 2 - height / 2
                    color: "#009ca6"
                    border.color: "white"
                    border.width: 1
                    radius: 6
                    width: 16
                    height: 16
                }

                onMoved: {
                    if (playRecordAudio.seekable) {
                        playRecordAudio.setPosition(value);
                    }
                }
            }

            Button {
                id: stopButton
                width: 80
                height: 36
                anchors.verticalCenter: parent.verticalCenter
                text: "Stop"

                background: Rectangle {
                    color: parent.hovered ? "#2A3337" : "#1A2327"
                    border.color: "#009ca6"
                    border.width: 1
                    radius: 4
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
                        playRecordAudio.stop();
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
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            height: 36
            Button {
                text: "Activity"
                width: 80
                height: parent.height
                background: Rectangle {
                    color: "#1A2327"
                    border.color: "#445055"
                    border.width: 1
                    radius: 4
                }

                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
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
                width: 80
                height: parent.height

                background: Rectangle {
                    color: parent.hovered ? "#00b3be" : "#009ca6"
                    radius: 4
                }

                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    saveChanges()
                }
            }

            Button {
                text: "Delete"
                width: 80
                height: parent.height

                background: Rectangle {
                    color: parent.hovered ? "#bf4040" : "#a63030"
                    radius: 4
                }

                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

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

