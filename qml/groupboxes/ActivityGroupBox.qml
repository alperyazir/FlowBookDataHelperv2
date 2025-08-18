import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform
import QtMultimedia

import "../../qml"
import "activities"

GroupBox {
    id: root

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
                    if (root.sectionModelData.audioExtra === null) {
                        print("audio extra is null creating new one");
                        root.sectionModelData.createAudioExtra(newPath);
                    } else {
                        root.sectionModelData.audioExtra.path = newPath;
                    }
                } else {
                    console.log("Books klasörü bulunamadı.");
                }
            } else {
                console.log("Dosya yolu geçersiz.");
            }
        }

        onRejected: {
            console.log("File selection was canceled");
        }
    }

    function saveRemains() {
        //if (matchthewords.visible) {
        matchthewords.updateData()
        ddpicture.updateData()
        ddppicturegroup.updateData()
        fillpicture.updateData()
        findPuzzle.updateData()
        //}
    }

    property var activityModelData: undefined
    property var sectionModelData: undefined
    signal removeSection
    title: qsTr("")
    width: parent.width * .98
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    onActivityModelDataChanged: {}

    background: Rectangle {
        color: "#232f34"
        border.color: "#009ca6"
        border.width: 1
        radius: 6
    }

    // Custom title style
    Column {
        anchors.fill: parent
        anchors.leftMargin: 5
        anchors.rightMargin: 5
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        // Header with title and close button
        Row {
            width: parent.width
            height: parent.height * 0.1
            spacing: 10

            Text {
                text: "Activity"
                color: "white"
                font.pixelSize: 24
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                width: parent.width - closeButton.width - parent.width * .5
                height: 1
            }

            Button {
                id: closeButton
                text: "X"
                width: height
                height: parent.height / 2
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
                        root.saveRemains()
                        sideBar.activityVisible = false;

                    }
                }
            }
        }

        DragDropPicture {
            id: ddpicture
            visible: root.activityModelData.type === "dragdroppicture"
            enabled: visible
            width: parent.width
            height: parent.height * 0.6
        }

        MatchTheWords {
            id: matchthewords
            visible: root.activityModelData.type === "matchTheWords"
            enabled: visible
            width: parent.width
            height: parent.height * 0.7
        }

        DragDropPictureGroup {
            id: ddppicturegroup
            visible: root.activityModelData.type === "dragdroppicturegroup"
            enabled: visible
            width: parent.width
            height: parent.height * 0.5
        }

        FillPicture {
            id: fillpicture
            visible: root.activityModelData.type === "fillpicture"
            enabled: visible
            width: parent.width
            height: parent.height * 0.5
        }

        PuzzleFindWords {
            id: findPuzzle
            visible: root.activityModelData.type === "puzzleFindWords"
            enabled: visible
            width: parent.width
            height: parent.height * 0.5
        }

        Circle {
            id: activityCircle
            visible: root.activityModelData.type === "circle"
            enabled: visible
            width: parent.width
            height: parent.height * 0.5
        }

        MarkWithX {
            id: activityMarkWithX
            visible: root.activityModelData.type === "markwithx"
            enabled: visible
            width: parent.width
            height: parent.height * 0.5
        }

        Row {
            width: parent.width * .9
            spacing: 10
            height: parent.height * 0.05

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
                height: parent.height
                text: root.sectionModelData.audioExtra !== null ? root.sectionModelData.audioExtra.path : ""
                placeholderText: "audio extra path "
                placeholderTextColor: "gray"
                color: "white"

                background: Rectangle {
                    color: "#1A2327"
                    border.color: parent.focus ? "#009ca6" : "#445055"
                    border.width: 1
                    radius: 4
                }
                onAccepted: {
                    //Audio Extra
                    if (root.sectionModelData.audioExtra === null) {
                        print("audio extra is null creating new one");
                        root.sectionModelData.createAudioExtra(audioTextField.text);
                    } else {
                        root.sectionModelData.audioExtra.path = audioTextField.text;
                    }

                    // config.bookSets[0].saveToJson();
                }
            }

            Button {
                width: parent.height
                height: parent.height
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
                        fileDialog.folder = "file:" + appPath;
                        fileDialog.open();
                    }
                }
            }
        }

        Row {
            id: audioContrller
            property bool isPlaying: playRecordAudio.playbackState === MediaPlayer.PlayingState
            width: parent.width
            height: parent.height * 0.05
            spacing: 10

            Button {
                id: playPauseButton
                width: parent.width / 4
                height: parent.height
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
                height: parent.height
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
                width: parent.width / 4
                height: parent.height
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
            audioOutput:
                //volume: volumeSlider.value / 100.0
                AudioOutput {}
            onSourceChanged: {
                play();
            }
        }

        Row {
            spacing: 10
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: parent.height * 0.05
            Button {
                text: "Activity"
                width: parent.width / 4
                height: parent.height * .8
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
                onClicked: {
                    activityDialog.wordLists = root.activityModelData.words;
                    activityDialog.imageSource = root.activityModelData.sectionPath;
                    activityDialog.headerText = root.activityModelData.headerText;
                    activityDialog.answers = root.activityModelData.answers;
                    activityDialog.activityModelData = root.activityModelData;

                    if (root.activityModelData.type === "matchTheWords")
                        activityDialog.createActivityMatchTheWord();
                    else if (root.activityModelData.type === "dragdroppicture")
                        activityDialog.createActivityDragDropPicture();
                    else if (root.activityModelData.type === "dragdroppicturegroup")
                        activityDialog.createActivityDragDropPictureGroup();
                    else if (root.activityModelData.type === "fillpicture")
                        activityDialog.createActivityFillPicture();
                    else if (root.activityModelData.type === "puzzleFindWords")
                        activityDialog.createActivityFindPuzzle();
                    else if (root.activityModelData.type === "circle")
                        activityDialog.createActivityCircle();
                    else if (root.activityModelData.type === "markwithx")
                        activityDialog.createActivityMarkWithX();

                    activityDialog.open();
                }
            }

            Button {
                text: "Delete"
                width: parent.width / 4
                height: parent.height * .8

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
                    confirmBox.visible = true;
                }
            }
        }

        Rectangle {
            id: confirmBox
            property string type
            property int index
            color: "#1A2327"
            border.color: "#a63030"
            border.width: 1
            radius: 6
            visible: false
            anchors.horizontalCenter: parent.horizontalCenter
            height: parent.height * 0.05
            width: parent.width * 0.8

            Column {
                anchors.centerIn: parent
                spacing: 5

                Text {
                    text: "Are you sure you want to delete?"
                    font.pixelSize: 16
                    color: "white"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Row {
                    spacing: 20
                    anchors.horizontalCenter: parent.horizontalCenter

                    Button {
                        text: "Yes"
                        width: 80
                        height: 20

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
                            removeSection();
                            confirmBox.visible = false;
                            sideBar.activityVisible = false;
                        }
                    }

                    Button {
                        text: "No"
                        width: 80
                        height: 20

                        background: Rectangle {
                            color: parent.hovered ? "#2A3337" : "#1A2327"
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
                            confirmBox.visible = false;
                        }
                    }
                }
            }
        }
    }

}
