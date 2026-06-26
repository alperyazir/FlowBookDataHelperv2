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

    // Karaoke (passage word-timing) status, driven by pdfProcess signals.
    property bool karaokeBusy: false
    property string karaokeStatus: ""

    function _baseName(p) { return p ? String(p).substring(String(p).lastIndexOf("/") + 1) : ""; }
    function _isThisAudio(p) { return _baseName(p) === _baseName(root.audioModelData && root.audioModelData.audioPath); }

    // <book>/audio/audio.json sits next to the audio file.
    function _audioJsonPath() {
        var p = (root.audioModelData && root.audioModelData.audioPath) ? String(root.audioModelData.audioPath) : "";
        var i = p.lastIndexOf("/");
        return i >= 0 ? p.substring(0, i + 1) + "audio.json" : "";
    }

    // Load this audio's word timings into the page overlay (for in-editor preview).
    function loadKaraoke() {
        content.pageDetails.karaokeTime = -1;
        content.pageDetails.karaokeWords = [];
        if (!root.audioModelData || !root.audioModelData.karaoke)
            return;
        var rel = _audioJsonPath();
        if (rel === "")
            return;
        var id = _baseName(root.audioModelData.audioPath);
        // rel is "./books/.../audio/audio.json"; drop the "./" and join the app
        // root. Read in C++ (QFile) so it works the same on Windows.
        var path = appPath + (rel.indexOf("./") === 0 ? rel.substring(2) : rel);
        content.pageDetails.karaokeWords = pdfProcess.loadKaraokeWords(path, id);
    }

    onAudioModelDataChanged: loadKaraoke()
    Component.onCompleted: loadKaraoke()

    Connections {
        target: pdfProcess
        function onPassageCropStarted(audioPath) {
            if (root._isThisAudio(audioPath)) {
                root.karaokeBusy = true;
                root.karaokeStatus = "Aligning…";
            }
        }
        function onPassageCropCompleted(success, audioPath, summaryJson) {
            if (!root._isThisAudio(audioPath))
                return;
            root.karaokeBusy = false;
            if (!success) {
                root.karaokeStatus = "Failed — try again";
                return;
            }
            var info = {};
            try { info = JSON.parse(summaryJson); } catch (e) {}
            var msg = (info.words || 0) + " words";
            if (info.mean_score !== undefined)
                msg += " · score " + info.mean_score;
            if (info.needs_review)
                msg += " · ⚠ review";
            root.karaokeStatus = msg;
            if (root.audioModelData)
                root.audioModelData.karaoke = true;   // order-independent of PageDetails handler
            root.loadKaraoke();   // pull the fresh timings into the page overlay
        }
    }

    // Stop playback when this panel is deselected (another section clicked).
    onVisibleChanged: {
        if (!visible) {
            playRecordAudio.stop();
            content.pageDetails.karaokeTime = -1;   // hide the page overlay
        } else {
            loadKaraoke();
        }
    }

    // Play / pause / resume — used by the Play button and the Space shortcut.
    function togglePlay() {
        if (playRecordAudio.playbackState === MediaPlayer.PlayingState)
            playRecordAudio.pause();
        else if (playRecordAudio.playbackState === MediaPlayer.PausedState)
            playRecordAudio.play();
        else {
            playRecordAudio.source = "file:" + appPath + audioTextField.text;
            playRecordAudio.play();
        }
    }

    // Seek (and play) to a karaoke word's start time. Used when the author
    // clicks a word in the list below to jump there and verify its alignment.
    // If playback hasn't started, load the source first and defer the seek
    // until the player is seekable.
    property int _pendingSeekMs: -1
    function seekToWord(startSec) {
        var ms = Math.max(0, Math.round(startSec * 1000));
        if (playRecordAudio.playbackState === MediaPlayer.StoppedState) {
            playRecordAudio.source = "file:" + appPath + audioTextField.text;
            playRecordAudio.play();
        }
        if (playRecordAudio.seekable)
            playRecordAudio.setPosition(ms);
        else
            root._pendingSeekMs = ms;
    }

    background: Rectangle {
        color: "#232f34"
        border.color: "#009ca6"
        border.width: 1
        radius: 8
    }

    // Browse the filesystem for an arbitrary audio file ("…" button).
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

    // In-app list of the book's audio files ("Pick" button).
    MediaPicker {
        id: audioPicker
        kind: "audio"
        onPicked: function(rel) { root.audioModelData.audioPath = rel; }
    }

    MediaPlayer {
        id: playRecordAudio
        audioOutput: AudioOutput {}
        onSourceChanged: play()
        // Push the position onto the slider while the user isn't dragging.
        onPositionChanged: function(position) {
            if (!audioSlider.pressed)
                audioSlider.value = position;
            // Drive the page karaoke highlight (position is ms).
            if (root.audioModelData && root.audioModelData.karaoke)
                content.pageDetails.karaokeTime = position / 1000.0;
        }
        // Clear the highlight when playback stops/ends.
        onPlaybackStateChanged: if (playbackState === MediaPlayer.StoppedState)
                                    content.pageDetails.karaokeTime = -1
        // Apply a click-to-seek that arrived before the player was seekable.
        onSeekableChanged: function(seekable) {
            if (seekable && root._pendingSeekMs >= 0) {
                setPosition(root._pendingSeekMs);
                root._pendingSeekMs = -1;
            }
        }
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

            AppButton {
                text: "Pick"
                variant: "primary"
                Layout.preferredWidth: 58
                Layout.preferredHeight: 34
                onClicked: {
                    audioPicker.currentPath = root.audioModelData.audioPath || "";
                    audioPicker.open();
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
                onClicked: root.togglePlay()
            }

            Slider {
                id: audioSlider
                Layout.fillWidth: true
                // The custom handle/background are plain Rectangles with no
                // implicit size, so without an explicit height the Slider
                // collapsed to 0px tall — visible but impossible to grab/drag.
                Layout.preferredHeight: 28
                from: 0
                to: playRecordAudio.duration > 0 ? playRecordAudio.duration : 1
                // No `value:` binding on purpose — it would re-assert the playback
                // position every frame and fight the drag, so the handle snapped
                // back and seeking did nothing. The value is pushed imperatively
                // from onPositionChanged while not being dragged (see MediaPlayer).
                // Seek as the user drags. If the player isn't seekable yet (the
                // ffmpeg backend reports that until it has buffered), queue the
                // target and apply it from onSeekableChanged — never drop it.
                onMoved: {
                    var ms = Math.max(0, Math.round(value));
                    if (playRecordAudio.seekable)
                        playRecordAudio.setPosition(ms);
                    else
                        root._pendingSeekMs = ms;
                }

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

        Rectangle { Layout.fillWidth: true; height: 1; color: "#2a3f48" }

        // Karaoke: word-level highlight timing for a read-aloud passage.
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                text: "Karaoke"
                color: "#8aa0a8"
                font.pixelSize: 13
                Layout.preferredWidth: 64
            }

            Text {
                Layout.fillWidth: true
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                color: root.karaokeBusy ? "#e0a000"
                       : ((root.audioModelData && root.audioModelData.karaoke) ? "#3ecf8e" : "#8aa0a8")
                text: root.karaokeBusy ? root.karaokeStatus
                      : ((root.audioModelData && root.audioModelData.karaoke)
                         ? ("✓ " + (root.karaokeStatus !== "" ? root.karaokeStatus : "set"))
                         : "Not set")
            }

            BusyIndicator {
                running: root.karaokeBusy
                visible: root.karaokeBusy
                implicitWidth: 22
                implicitHeight: 22
            }
        }

        // Start passage selection (same as pressing "c" with this audio open).
        AppButton {
            text: "Select karaoke (C)"
            variant: "secondary"
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            enabled: !root.karaokeBusy
            onClicked: content.pageDetails.startPassageCropMode(root.audioModelData)
        }

        // ----- Karaoke words: the aligned passage, in sync with playback -----
        // Shows every word from audio.json. The word currently playing is
        // highlighted (same as the page overlay) so the author can verify the
        // alignment; clicking a word jumps playback to it.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
            visible: root.audioModelData && root.audioModelData.karaoke

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Words"
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: (content.pageDetails.karaokeWords
                           ? content.pageDetails.karaokeWords.length : 0) + " words"
                    color: "#8aa0a8"
                    font.pixelSize: 12
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#1A2327"
                border.color: "#2a3f48"
                border.width: 1
                radius: 6
                clip: true

                Flickable {
                    id: wordsFlick
                    anchors.fill: parent
                    anchors.margins: 10
                    contentWidth: width
                    contentHeight: wordsFlow.height
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                    // Keep the currently-playing word in view as audio advances.
                    function scrollToActive() {
                        var i = content.pageDetails.karaokeActiveIndex;
                        if (i < 0)
                            return;
                        var it = wordsRep.itemAt(i);
                        if (!it)
                            return;
                        if (it.y < contentY)
                            contentY = it.y;
                        else if (it.y + it.height > contentY + height)
                            contentY = it.y + it.height - height;
                    }

                    Flow {
                        id: wordsFlow
                        width: wordsFlick.width
                        spacing: 6

                        Repeater {
                            id: wordsRep
                            model: content.pageDetails.karaokeWords

                            delegate: Rectangle {
                                id: chip
                                readonly property bool isActive:
                                    index === content.pageDetails.karaokeActiveIndex
                                width: chipText.implicitWidth + 16
                                height: chipText.implicitHeight + 10
                                radius: 4
                                color: isActive ? "#ffd200"
                                       : (chipMouse.containsMouse ? "#26343c" : "transparent")
                                border.color: isActive ? "#ffd200" : "#2f4650"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 80 } }

                                Text {
                                    id: chipText
                                    anchors.centerIn: parent
                                    text: (modelData && modelData.text) ? modelData.text : ""
                                    color: chip.isActive ? "#10242b" : "#cfe8ea"
                                    font.pixelSize: 14
                                    font.bold: chip.isActive
                                }

                                MouseArea {
                                    id: chipMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (modelData && modelData.start !== undefined)
                                            root.seekToWord(modelData.start);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Hint shown when this audio has no karaoke timings yet.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !(root.audioModelData && root.audioModelData.karaoke)
            Text {
                anchors.centerIn: parent
                width: parent.width - 24
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: "#6b7a80"
                font.pixelSize: 13
                text: "Select a passage on the page (Select karaoke / C) to "
                      + "align the spoken words. They will appear here and "
                      + "highlight as the audio plays."
            }
        }

        // Keep the word list scrolled to the active word during playback.
        Connections {
            target: content.pageDetails
            function onKaraokeActiveIndexChanged() { wordsFlick.scrollToActive(); }
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
                sideBar.audioVisible = false;
            }
        }
    }
}
