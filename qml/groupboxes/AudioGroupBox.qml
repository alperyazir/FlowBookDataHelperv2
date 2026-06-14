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

    property var audioModelData: ({})
    property int sectionIndex
    signal removeSection(int secIndex)

    // Stop playback when this panel is deselected (another section clicked).
    onVisibleChanged: if (!visible) playRecordAudio.stop()

    background: Rectangle {
        color: "#232f34"
        border.color: "#009ca6"
        border.width: 1
        radius: 8
    }

    FileDialog {
        id: fileDialog
        title: "Select a File"
        onAccepted: {
            var selectedFilePath = fileDialog.file + "";
            if (selectedFilePath) {
                var newPath = findBooksFolder(selectedFilePath, "books");
                if (newPath)
                    root.audioModelData.audioPath = newPath;
                else
                    console.log("Books klasörü bulunamadı.");
            }
        }
    }

    MediaPlayer {
        id: playRecordAudio
        audioOutput: AudioOutput {}
        onSourceChanged: play()
        // Keep the slider in sync after a drag breaks the value binding.
        onPositionChanged: if (!audioSlider.pressed) audioSlider.value = position
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        PanelHeader {
            Layout.fillWidth: true
            title: "Audio"
            onCloseClicked: {
                playRecordAudio.stop();
                audioTextField.focus = false;
                sideBar.audioVisible = false;
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
                id: audioTextField
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                placeholderText: "Enter the audio path"
                text: (root.audioModelData && root.audioModelData.audioPath) || ""
                onTextEdited: root.audioModelData.audioPath = text
            }

            AppButton {
                text: "…"
                variant: "secondary"
                Layout.preferredWidth: 40
                Layout.preferredHeight: 34
                leftPadding: 0; rightPadding: 0
                onClicked: {
                    fileDialog.folder = "file:" + appPath + (root.audioModelData.audioPath || "");
                    fileDialog.open();
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            AppButton {
                text: playRecordAudio.playbackState === MediaPlayer.PlayingState ? "Pause" : "Play"
                variant: "primary"
                Layout.preferredWidth: 80
                Layout.preferredHeight: 32
                onClicked: {
                    if (playRecordAudio.playbackState === MediaPlayer.PlayingState)
                        playRecordAudio.pause();
                    else if (playRecordAudio.playbackState === MediaPlayer.PausedState)
                        playRecordAudio.play();
                    else {
                        playRecordAudio.source = "file:" + appPath + audioTextField.text;
                        playRecordAudio.play();
                    }
                }
            }

            Slider {
                id: audioSlider
                Layout.fillWidth: true
                from: 0
                to: playRecordAudio.duration > 0 ? playRecordAudio.duration : 1
                value: playRecordAudio.position
                onMoved: if (playRecordAudio.seekable) playRecordAudio.setPosition(value)

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
                onClicked: playRecordAudio.stop()
            }
        }

        Item { Layout.fillHeight: true }

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
                sideBar.audioVisible = false;
            }
        }
    }
}
