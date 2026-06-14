import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform
import QtMultimedia

import "../../qml"
import "../newComponents"

GroupBox {
    id: root
    title: ""
    width: parent.width * .98
    padding: 14
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter

    property var videoModelData: ({})
    property int sectionIndex
    signal removeSection(int secIndex)

    // Stop playback when this panel is deselected (another section clicked).
    onVisibleChanged: if (!visible) playRecord.stop()

    // Play / pause / resume — used by the Play button and the Space shortcut.
    function togglePlay() {
        if (playRecord.playbackState === MediaPlayer.PlayingState)
            playRecord.pause();
        else if (playRecord.playbackState === MediaPlayer.PausedState)
            playRecord.play();
        else {
            playRecord.source = "file:" + appPath + videoTextField.text;
            playRecord.play();
        }
    }

    background: Rectangle {
        color: "#232f34"
        border.color: "#009ca6"
        border.width: 1
        radius: 8
    }

    // Browse the filesystem for an arbitrary video file ("…" button).
    FileDialog {
        id: fileDialog
        title: "Select a File"
        onAccepted: {
            var selectedFilePath = fileDialog.file + "";
            if (selectedFilePath) {
                var newPath = findBooksFolder(selectedFilePath, "books");
                if (newPath && root.videoModelData && root.videoModelData.video)
                    root.videoModelData.video.path = newPath;
                else if (!newPath)
                    console.log("Books klasörü bulunamadı.");
            }
        }
    }

    // In-app list of the book's video files ("Pick" button).
    MediaPicker {
        id: videoPicker
        kind: "video"
        onPicked: function(rel) {
            if (root.videoModelData && root.videoModelData.video)
                root.videoModelData.video.path = rel;
        }
    }

    MediaPlayer {
        id: playRecord
        videoOutput: videoOutput
        audioOutput: AudioOutput {}
        // Keep the slider in sync after a drag breaks the value binding.
        onPositionChanged: if (!videoSlider.pressed) videoSlider.value = position
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        PanelHeader {
            Layout.fillWidth: true
            title: "Video"
            onCloseClicked: {
                videoTextField.focus = false;
                playRecord.stop();
                sideBar.videoVisible = false;
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#2a3f48" }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "Path"
                color: "#8aa0a8"
                font.pixelSize: 13
                Layout.preferredWidth: 44
            }

            AppTextField {
                id: videoTextField
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                placeholderText: "Enter the video path"
                text: (root.videoModelData && root.videoModelData.video) ? root.videoModelData.video.path : ""
                onTextEdited: if (root.videoModelData && root.videoModelData.video) root.videoModelData.video.path = text
            }

            AppButton {
                text: "…"
                variant: "secondary"
                Layout.preferredWidth: 40
                Layout.preferredHeight: 34
                leftPadding: 0; rightPadding: 0
                onClicked: {
                    fileDialog.folder = "file:" + appPath;
                    fileDialog.open();
                }
            }

            AppButton {
                text: "Pick"
                variant: "primary"
                Layout.preferredWidth: 58
                Layout.preferredHeight: 34
                onClicked: {
                    videoPicker.currentPath = (root.videoModelData && root.videoModelData.video)
                                              ? root.videoModelData.video.path : "";
                    videoPicker.open();
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            AppButton {
                text: playRecord.playbackState === MediaPlayer.PlayingState ? "Pause" : "Play"
                variant: "primary"
                Layout.preferredWidth: 80
                Layout.preferredHeight: 32
                onClicked: root.togglePlay()
            }

            Slider {
                id: videoSlider
                Layout.fillWidth: true
                from: 0
                to: playRecord.duration > 0 ? playRecord.duration : 1
                value: playRecord.position
                onMoved: if (playRecord.seekable) playRecord.setPosition(value)

                background: Rectangle {
                    x: videoSlider.leftPadding
                    y: videoSlider.topPadding + videoSlider.availableHeight / 2 - height / 2
                    width: videoSlider.availableWidth
                    height: 4
                    radius: 2
                    color: "#1A2327"
                    Rectangle {
                        width: videoSlider.visualPosition * parent.width
                        height: parent.height
                        color: "#009ca6"
                        radius: 2
                    }
                }
                handle: Rectangle {
                    x: videoSlider.leftPadding + videoSlider.visualPosition * (videoSlider.availableWidth - width)
                    y: videoSlider.topPadding + videoSlider.availableHeight / 2 - height / 2
                    width: 16
                    height: 16
                    radius: 8
                    color: "#009ca6"
                    border.color: "white"
                    border.width: 1
                }
            }

            AppButton {
                text: "Stop"
                variant: "secondary"
                Layout.preferredWidth: 70
                Layout.preferredHeight: 32
                onClicked: playRecord.stop()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            color: "#0b1012"
            border.color: "#2a3f48"
            border.width: 1
            VideoOutput {
                id: videoOutput
                anchors.fill: parent
                anchors.margins: 4
            }
        }

        AppButton {
            text: "Delete"
            variant: "danger"
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            onClicked: confirmBox.ask("section", root.sectionIndex)
        }
    }

    ConfirmDelete {
        id: confirmBox
        onConfirmed: function(kind, idx) {
            if (kind === "section") {
                root.removeSection(root.sectionIndex);
                sideBar.videoVisible = false;
            }
        }
    }
}
