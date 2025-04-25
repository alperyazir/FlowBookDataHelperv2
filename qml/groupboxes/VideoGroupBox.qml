import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform
import QtMultimedia
import "../../qml"

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
                    videoTextField.text = newPath
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


    property var videoModelData
    property int sectionIndex
    signal removeSection(int secIndex)
    title: qsTr("Video")
    width: parent.width * .98
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
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
                        videoTextField.focus = false
                        sideBar.videoVisible = false
                        playRecord.stop()
                    }
                }
            }
        }
        Row {
            width: parent.width * .9
            spacing: 10
            height: 40
            FlowText {
                text: "Path: "
                color: "white"
                anchors.centerIn: undefined
                width: parent.width * .15
                font.pixelSize: 15
                verticalAlignment: Text.AlignBottom
            }

            // TextEdit bileşeni
            TextField {
                id: videoTextField
                width: parent.width*.75
                height: parent.height
                placeholderText: "video.mp4"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.videoModelData.video.path

                onAccepted: {

                }
            }

            Rectangle {
                height: width
                width: parent.width * 0.1
                anchors.verticalCenter: parent.verticalCenter
                color: "white"
                FlowText {
                    text: "..."
                    color: "black"
                    anchors.centerIn: undefined
                    width: parent.width
                    height: width
                    font.pixelSize: 15
                    verticalAlignment: Text.AlignBottom
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        fileDialog.folder = "file:" + appPath + root.videoModelData.path
                        fileDialog.open()
                    }
                }
            }
        }

        Row {
            height: 40
            anchors.horizontalCenter: parent.horizontalCenter
            Button {
                text: "Save"
                onClicked: {
                    root.videoModelData.video.path = videoTextField.text
                    videoTextField.focus = false
                    config.bookSets[0].saveToJson();
                    toast.show("Changes are saved to File!")
                }
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
                            removeSection(root.sectionIndex)
                            confirmBox.visible = false
                            sideBar.videoVisible = false
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


        Row {
            property bool isPlaying: playRecord.playbackState === MediaPlayer.PlayingState
            id: videoContrller
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
                        if (!videoContrller.isPlaying) {
                            playRecord.source = "file:" + appPath + videoTextField.text
                            playRecord.play()
                        } else {
                            playRecord.pause()
                        }
                    }
                }
            }

            Slider {
                id: audioSlider
                enabled: true
                to: playRecord.duration
                value: playRecord.position
                width: parent.width - playPauseButton.width - videoContrller.spacing - stopButton.width
                anchors.verticalCenter: parent.verticalCenter
                onMoved: {
                    if (playRecord.seekable) {
                        playRecord.setPosition(value)
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
                        playRecord.stop()
                    }
                }
            }
        }

        VideoOutput {
            height: width
            width: parent.width
            id: videoOutput
        }

        Rectangle {
            property string subText
            id: subRect
            // width: subTxt.width * 1.05
            // height: subTxt.height * 1.2
            color: "black"
            width: parent.width
            height: 40
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                id: subTxt
                fontSizeMode: Text.Fit
                text: parent.subText
                width: parent.width
                height: parent.height
                color: "white"
                font.pointSize: 15
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    Timer {
        interval: 500
        repeat: true
        running: playRecord.playbackState === MediaPlayer.PlayingState
        onTriggered: {
            for (var i = 0; i < root.videoModelData.video.subtitles.length; i++) {
                if (playRecord.position >= root.videoModelData.video.subtitles[i].startTime && playRecord.position <= root.videoModelData.video.subtitles[i].endTime) {
                    if (!subTxt.visible) {
                        subTxt.visible = true;
                    }

                    subRect.subText = root.videoModelData.video.subtitles[i].subtitle;
                    return;
                } else {
                    subTxt.visible = false
                }
            }
        }
    }

    states: [
        State {
            name: "playing"
            when: playRecord.playbackState === MediaPlayer.PlayingState

            PropertyChanges {
                playPauseButton.text: "Pause"
            }

        },
        State {
            name: "paused"
            when: playRecord.playbackState === MediaPlayer.PausedState || playRecord.playbackState === MediaPlayer.StoppedState

            PropertyChanges {
                playPauseButton.text: "Play"
            }
        }
    ]


    MediaPlayer {
        id: playRecord
        videoOutput: videoOutput
        audioOutput: AudioOutput {
        }
        onSourceChanged: {
            play()
        }
    }
}

