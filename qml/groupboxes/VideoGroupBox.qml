import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform
import QtMultimedia
import "../../qml"

GroupBox {
    id: root
    title: ""
    width: parent.width * .98
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    padding: 15

    background: Rectangle {
        color: "#232f34"
        border.color: "#009ca6"
        border.width: 1
        radius: 6
    }

    // FileDialog component
    FileDialog {
        id: fileDialog
        title: "Select a File"
        onAccepted: {
            var selectedFilePath = fileDialog.file + "";
            if (selectedFilePath) {
                var newPath = findBooksFolder(selectedFilePath, "books");
                if (newPath) {
                    videoTextField.text = newPath;
                } else {
                    console.log("Books klasörü bulunamadı.");
                }
            }
        }
    }

    property var videoModelData
    property int sectionIndex
    signal removeSection(int secIndex)

    Column {
        anchors.fill: parent
        anchors.leftMargin: 5
        anchors.rightMargin: 5
        spacing: 10

        // Header with title and close button
        Row {
            width: parent.width
            height: parent.height / 9
            spacing: 3

            Text {
                text: "Video"
                color: "white"
                font.pixelSize: 24
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                width: parent.width - closeButton.width - parent.width * .2
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
                        videoTextField.focus = false;
                        sideBar.videoVisible = false;
                        playRecord.stop();
                    }
                }
            }
        }

        // Path input row
        Row {
            width: parent.width
            spacing: 3
            height: parent.height / 9

            Text {
                text: "Path:"
                color: "white"
                font.pixelSize: 14
                width: 40
                anchors.verticalCenter: parent.verticalCenter
            }

            TextField {
                id: videoTextField
                width: parent.width * 0.75
                height: parent.height
                text: root.videoModelData.video.path
                placeholderText: "Enter the video path"
                placeholderTextColor: "gray"
                color: "white"

                background: Rectangle {
                    color: "#1A2327"
                    border.color: parent.focus ? "#009ca6" : "#445055"
                    border.width: 1
                    radius: 4
                }
            }

            Button {
                width: parent.width * 0.1
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
                        fileDialog.folder = "file:" + appPath + root.videoModelData.path;
                        fileDialog.open();
                    }
                }
            }
        }

        // Video controls
        Row {
            id: videoContrller
            property bool isPlaying: playRecord.playbackState === MediaPlayer.PlayingState
            width: parent.width
            height: parent.height / 9
            spacing: 3

            Button {
                id: playPauseButton
                width: parent.width * 0.15
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter

                background: Rectangle {
                    color: parent.hovered ? "#00b3be" : "#009ca6"
                    radius: parent.width / 2
                }

                contentItem: Text {
                    text: videoContrller.isPlaying ? "Pause" : "Play"
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (!videoContrller.isPlaying) {
                            playRecord.source = "file:" + appPath + videoTextField.text;
                            playRecord.play();
                        } else {
                            playRecord.pause();
                        }
                    }
                }
            }

            Slider {
                id: audioSlider
                enabled: true
                to: playRecord.duration
                value: playRecord.position
                width: parent.width * 0.65
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
                    if (playRecord.seekable) {
                        playRecord.setPosition(value);
                    }
                }
            }

            Button {
                id: stopButton
                width: parent.width * 0.15
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter
                text: "Stop"

                background: Rectangle {
                    color: parent.hovered ? "#2A3337" : "#1A2327"
                    border.color: "#009ca6"
                    border.width: 1
                    radius: parent.width / 2
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
                        playRecord.stop();
                    }
                }
            }
        }

        // Video output
        VideoOutput {
            id: videoOutput
            height: width * 0.5625  // 16:9 aspect ratio
            width: parent.width
        }

        // Save/Delete buttons
        Row {
            spacing: 10
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: parent.height * 0.1

            Button {
                text: "Save"
                width: parent.width / 3
                height: parent.height * .8

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
                    root.videoModelData.video.path = videoTextField.text;
                    videoTextField.focus = false;
                    config.bookSets[0].saveToJson();
                    toast.show("Changes are saved to File!");
                }
            }

            Button {
                text: "Delete"
                width: parent.width / 3
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

        // Confirmation dialog
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
            height: parent.height * 0.2
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
                        height: 36

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
                            removeSection(root.sectionIndex);
                            confirmBox.visible = false;
                            sideBar.videoVisible = false;
                        }
                    }

                    Button {
                        text: "No"
                        width: 80
                        height: 36

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

    MediaPlayer {
        id: playRecord
        videoOutput: videoOutput
        audioOutput: AudioOutput {}
        onPositionChanged: {
            audioSlider.value = position;
        }
    }
}
