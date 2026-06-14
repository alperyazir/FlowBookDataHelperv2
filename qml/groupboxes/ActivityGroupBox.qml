import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform
import QtMultimedia

import "../../qml"
import "activities"
import "../newComponents"

GroupBox {
    id: root

    property var activityModelData: ({})
    property var sectionModelData: ({})
    signal removeSection

    title: qsTr("")
    width: parent.width * .98
    padding: 14
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter

    // Stop the extra-audio preview when this panel is deselected.
    onVisibleChanged: if (!visible) playRecordAudio.stop()

    // Extra audio is optional: collapsed to an "Add" button until the user
    // asks for it, or auto-expanded when the section already carries one.
    property bool audioRequested: false
    readonly property bool hasAudioExtra: !!(sectionModelData && sectionModelData.audioExtra && sectionModelData.audioExtra.path)
    readonly property bool audioExpanded: audioRequested || hasAudioExtra
    onSectionModelDataChanged: audioRequested = false

    background: Rectangle {
        color: "#232f34"
        border.color: "#009ca6"
        border.width: 1
        radius: 8
    }

    function saveRemains() {
        matchthewords.updateData();
        ddpicture.updateData();
        ddppicturegroup.updateData();
        fillpicture.updateData();
        findPuzzle.updateData();
    }

    // Browse for an extra audio file attached to the section.
    FileDialog {
        id: fileDialog
        title: "Select a File"
        onAccepted: {
            var selectedFilePath = fileDialog.file + "";
            if (selectedFilePath) {
                var newPath = findBooksFolder(selectedFilePath, "books");
                if (newPath) {
                    if (root.sectionModelData.audioExtra === null) {
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
        onRejected: console.log("File selection was canceled")
    }

    MediaPlayer {
        id: playRecordAudio
        audioOutput: AudioOutput {}
        onSourceChanged: play()
        // Keep the slider in sync after a drag breaks the value binding.
        onPositionChanged: if (!extraAudioSlider.pressed) extraAudioSlider.value = position
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        // ----- Header -----
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "Activity"
                color: "white"
                font.pixelSize: 22
                font.bold: true
            }

            Rectangle {
                radius: 11
                height: 22
                visible: headerBadge.text.length > 0
                Layout.preferredWidth: headerBadge.implicitWidth + 22
                color: "#11343a"
                border.color: "#1c5a63"
                border.width: 1
                Text {
                    id: headerBadge
                    anchors.centerIn: parent
                    text: (root.activityModelData && root.activityModelData.type) || ""
                    color: "#4fd2dc"
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                id: closeButton
                width: 30
                height: 30
                radius: 6
                color: closeMouse.containsMouse ? "#2A3337" : "#1A2327"
                border.color: "#3a5560"
                border.width: 1
                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: "#cfe8ea"
                    font.pixelSize: 13
                }
                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.saveRemains();
                        sideBar.activityVisible = false;
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#2a3f48" }

        // ----- Activity-specific editor (only the matching one is shown) -----
        DragDropPicture {
            id: ddpicture
            visible: root.activityModelData.type === "dragdroppicture"
            enabled: visible
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
        MatchTheWords {
            id: matchthewords
            visible: root.activityModelData.type === "matchTheWords"
            enabled: visible
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
        DragDropPictureGroup {
            id: ddppicturegroup
            visible: root.activityModelData.type === "dragdroppicturegroup"
            enabled: visible
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
        FillPicture {
            id: fillpicture
            visible: root.activityModelData.type === "fillpicture"
            enabled: visible
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
        PuzzleFindWords {
            id: findPuzzle
            visible: root.activityModelData.type === "puzzleFindWords"
            enabled: visible
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
        Circle {
            id: activityCircle
            visible: root.activityModelData.type === "circle"
            enabled: visible
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
        MarkWithX {
            id: activityMarkWithX
            visible: root.activityModelData.type === "markwithx"
            enabled: visible
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        // ----- Extra audio (optional) -----
        AppButton {
            visible: !root.audioExpanded
            text: "+  Add extra audio"
            variant: "secondary"
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            onClicked: root.audioRequested = true
        }

        Rectangle {
            visible: root.audioExpanded
            Layout.fillWidth: true
            Layout.preferredHeight: audioCol.implicitHeight + 20
            radius: 8
            color: "#16242b"
            border.color: "#2a3f48"
            border.width: 1

            ColumnLayout {
                id: audioCol
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Extra audio"
                        color: "#cfe8ea"
                        font.pixelSize: 13
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 6
                        color: rmAudioMouse.containsMouse ? "#2A3337" : "transparent"
                        border.color: "#3a5560"
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: "#8aa0a8"
                            font.pixelSize: 11
                        }
                        MouseArea {
                            id: rmAudioMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                playRecordAudio.stop();
                                audioTextField.text = "";
                                if (root.sectionModelData && root.sectionModelData.audioExtra)
                                    root.sectionModelData.audioExtra.path = "";
                                root.audioRequested = false;
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    AppTextField {
                        id: audioTextField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        placeholderText: "audio extra path"
                        text: (root.sectionModelData && root.sectionModelData.audioExtra) ? root.sectionModelData.audioExtra.path : ""
                        onAccepted: {
                            if (root.sectionModelData.audioExtra === null) {
                                root.sectionModelData.createAudioExtra(audioTextField.text);
                            } else {
                                root.sectionModelData.audioExtra.path = audioTextField.text;
                            }
                        }
                    }

                    AppButton {
                        text: "…"
                        variant: "secondary"
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 32
                        leftPadding: 0; rightPadding: 0
                        onClicked: {
                            fileDialog.folder = "file:" + appPath;
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
                        id: extraAudioSlider
                        Layout.fillWidth: true
                        from: 0
                        to: playRecordAudio.duration > 0 ? playRecordAudio.duration : 1
                        value: playRecordAudio.position
                        onMoved: if (playRecordAudio.seekable) playRecordAudio.setPosition(value)

                        background: Rectangle {
                            x: extraAudioSlider.leftPadding
                            y: extraAudioSlider.topPadding + extraAudioSlider.availableHeight / 2 - height / 2
                            width: extraAudioSlider.availableWidth
                            height: 4
                            radius: 2
                            color: "#1A2327"
                            Rectangle {
                                width: extraAudioSlider.visualPosition * parent.width
                                height: parent.height
                                color: "#009ca6"
                                radius: 2
                            }
                        }
                        handle: Rectangle {
                            x: extraAudioSlider.leftPadding + extraAudioSlider.visualPosition * (extraAudioSlider.availableWidth - width)
                            y: extraAudioSlider.topPadding + extraAudioSlider.availableHeight / 2 - height / 2
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
            }
        }

        // ----- Actions -----
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            AppButton {
                text: "Activity"
                variant: "secondary"
                Layout.fillWidth: true
                Layout.preferredHeight: 36
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

            AppButton {
                text: "Delete"
                variant: "danger"
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                onClicked: confirmBox.visible = true
            }
        }
    }

    // ----- Delete confirmation overlay -----
    Rectangle {
        id: confirmBox
        anchors.centerIn: parent
        width: parent.width * 0.8
        height: confirmCol.implicitHeight + 28
        radius: 8
        color: "#1A2327"
        border.color: "#a63030"
        border.width: 1
        visible: false
        z: 100

        ColumnLayout {
            id: confirmCol
            anchors.centerIn: parent
            spacing: 12

            Text {
                text: "Are you sure you want to delete?"
                font.pixelSize: 15
                color: "white"
                Layout.alignment: Qt.AlignHCenter
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 16

                AppButton {
                    text: "Yes"
                    variant: "danger"
                    Layout.preferredWidth: 90
                    onClicked: {
                        removeSection();
                        confirmBox.visible = false;
                        sideBar.activityVisible = false;
                    }
                }
                AppButton {
                    text: "No"
                    variant: "secondary"
                    Layout.preferredWidth: 90
                    onClicked: confirmBox.visible = false
                }
            }
        }
    }
}
