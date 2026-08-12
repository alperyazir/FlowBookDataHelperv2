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
    // True between the user pressing Stop and the cancel landing, so the
    // completion handler shows "Canceled" rather than "Failed".
    property bool karaokeCanceled: false

    // Word-list editing. In edit mode a click selects a word (instead of
    // seeking) so it can be renamed / reordered / deleted; selectedWordIndex is
    // the word being edited (-1 = none). Edits persist to audio.json immediately.
    property bool wordsEditMode: false
    property int selectedWordIndex: -1

    // Alignment quality for the loaded passage, re-read from audio.json on every
    // load: {mean_score, needs_review, review: [reason, …]}. karaokeStatus only
    // ever held the verdict of an align done in this session, so a passage that
    // came out desynced looked identical to a good one as soon as the panel was
    // reopened — and the author had no reason to play it back.
    property var karaokeMeta: ({})
    property bool karaokeNeedsReview: !!(karaokeMeta && karaokeMeta.needs_review)

    // Playback speed, held here rather than read back off the player. Setting
    // MediaPlayer.source resets playbackRate to 1.0 behind QML's back, and a
    // binding is pushed rather than polled — so buttons bound to the player's
    // own property stopped showing the chosen speed the moment a clip reloaded.
    // This is the authority; the player is re-told on every source change and
    // whenever playback starts.
    property real playSpeed: 1.0
    onPlaySpeedChanged: playRecordAudio.playbackRate = playSpeed

    // Anchor for the karaoke clock (see karaokeTicker): the last position the
    // player actually reported, and the wall-clock instant it reported it.
    property real _tickLastPos: -1
    property real _tickBaseMs: 0
    property real _tickBaseWall: 0

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
        root.karaokeMeta = ({});
        if (!root.audioModelData || !root.audioModelData.karaoke)
            return;
        var rel = _audioJsonPath();
        if (rel === "")
            return;
        var id = _baseName(root.audioModelData.audioPath);
        // rel is "./books/.../audio/audio.json"; drop the "./" and join the app
        // root. Read in C++ (QFile) so it works the same on Windows.
        var path = appPath + (rel.indexOf("./") === 0 ? rel.substring(2) : rel);
        var words = pdfProcess.loadKaraokeWords(path, id);
        root.karaokeMeta = pdfProcess.loadKaraokeMeta(path, id) || {};
        // Point each cloze blank at the fill box it opens. Done on load (not
        // only right after aligning) so the link heals when the author moves,
        // adds or deletes a fill afterwards; linkKaraokeBlanks returns null
        // when nothing changed, so this doesn't rewrite audio.json every time.
        // Only relink while this audio's own page is the one on screen —
        // matching against another page's fills would wipe good links.
        if (root._audioIsOnShownPage()) {
            var linked = content.pageDetails.linkKaraokeBlanks(words);
            if (linked) {
                words = linked;
                pdfProcess.saveKaraokeWords(path, id, words);
            }
        }
        content.pageDetails.karaokeWords = words;
    }

    // audioModelData is a section object taken from a page's sections list, so
    // identity against the shown page's sections is an exact check.
    function _audioIsOnShownPage() {
        var pg = content.pageDetails ? content.pageDetails.page : null;
        if (!pg || !root.audioModelData)
            return false;
        var secs = pg.sections || [];
        for (var i = 0; i < secs.length; i++)
            if (secs[i] === root.audioModelData)
                return true;
        return false;
    }

    // Blanks that found no fill box: nothing for the reader to open there, so
    // the panel warns and the author fixes it by drawing the missing fill.
    function unlinkedBlankCount() {
        var words = content.pageDetails.karaokeWords || [];
        var n = 0;
        for (var i = 0; i < words.length; i++)
            if (words[i] && words[i].blank && !words[i].fill)
                n++;
        return n;
    }

    onAudioModelDataChanged: {
        root.wordsEditMode = false;      // reset editing when the audio changes
        root.selectedWordIndex = -1;
        loadKaraoke();
    }
    Component.onCompleted: loadKaraoke()

    Connections {
        target: pdfProcess
        function onPassageCropStarted(audioPath) {
            if (root._isThisAudio(audioPath)) {
                root.karaokeBusy = true;
                root.karaokeCanceled = false;
                root.karaokeStatus = "Starting…";
                // The aligner may rewrite this very file, converting a
                // variable-bitrate clip to a constant one so it can be seeked.
                // Windows will not let a file be replaced while another process
                // holds it open, and this panel's player holds it from the
                // moment the clip is auditioned — which is exactly what an
                // author does before running karaoke. Let go for the run.
                playRecordAudio.stop();
                playRecordAudio.source = "";
                content.pageDetails.karaokeTime = -1;
            }
        }
        // Live stage messages from align_audio.py ("PROGRESS:" lines).
        function onPassageCropProgress(audioPath, message) {
            if (root._isThisAudio(audioPath) && root.karaokeBusy)
                root.karaokeStatus = message;
        }
        function onPassageCropCanceled(audioPath) {
            if (!root._isThisAudio(audioPath))
                return;
            root.karaokeBusy = false;
            root.karaokeCanceled = false;
            root.karaokeStatus = "Canceled";
        }
        function onPassageCropCompleted(success, audioPath, summaryJson) {
            if (!root._isThisAudio(audioPath))
                return;
            root.karaokeBusy = false;
            if (!success) {
                root.karaokeStatus = root.karaokeCanceled ? "Canceled" : "Failed — try again";
                root.karaokeCanceled = false;
                return;
            }
            var info = {};
            try { info = JSON.parse(summaryJson); } catch (e) {}
            var msg = (info.words || 0) + " words";
            if (info.mean_score !== undefined)
                msg += " · score " + info.mean_score;
            // The aligner rewrites a variable-bitrate clip to a constant one
            // before timing it, because a VBR mp3 cannot be seeked accurately
            // and the highlight drifts after a slider drag. That changes the
            // author's file, so say so rather than let them find a different
            // mp3 than the one they dropped in.
            if (info.audio_cbr && info.audio_cbr.kbps)
                msg += " · audio → CBR " + info.audio_cbr.kbps + "k";
            else if (info.audio_cbr && info.audio_cbr.failed)
                msg += " · ⚠ audio is VBR (seeking will drift)";
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

    // ----- Word-list editing helpers -----------------------------------------
    // karaokeWords is a plain JS array (a QVariantList snapshot of audio.json).
    // Each helper mutates a copy, reassigns it (so the list + page overlay
    // rebind), then persists the whole array back to audio.json in C++.
    function _persistWords(words) {
        content.pageDetails.karaokeWords = words;
        if (!root.audioModelData || !root.audioModelData.karaoke)
            return;
        var rel = _audioJsonPath();
        if (rel === "")
            return;
        var id = _baseName(root.audioModelData.audioPath);
        var path = appPath + (rel.indexOf("./") === 0 ? rel.substring(2) : rel);
        pdfProcess.saveKaraokeWords(path, id, words);
    }

    function renameWord(index, newText) {
        var words = (content.pageDetails.karaokeWords || []).slice();
        if (index < 0 || index >= words.length)
            return;
        var t = String(newText).trim();
        if (t === "" || t === words[index].text)
            return;
        // Copy the map so the reassignment is seen as a change.
        var w = {};
        for (var k in words[index]) w[k] = words[index][k];
        w.text = t;
        words[index] = w;
        root._persistWords(words);
    }

    function deleteWord(index) {
        var words = (content.pageDetails.karaokeWords || []).slice();
        if (index < 0 || index >= words.length)
            return;
        words.splice(index, 1);
        // Keep the selection sensible after removing a chip.
        if (root.selectedWordIndex === index)
            root.selectedWordIndex = -1;
        else if (root.selectedWordIndex > index)
            root.selectedWordIndex -= 1;
        content.pageDetails.karaokeActiveIndex = -1;
        root._persistWords(words);
    }

    // Move a word one step left/right (delta = -1 / +1) to fix its order.
    function moveWord(index, delta) {
        var words = (content.pageDetails.karaokeWords || []).slice();
        var to = index + delta;
        if (index < 0 || index >= words.length || to < 0 || to >= words.length)
            return;
        var tmp = words[index];
        words[index] = words[to];
        words[to] = tmp;
        root.selectedWordIndex = to;   // selection follows the moved word
        root._persistWords(words);
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
        playbackRate: root.playSpeed
        // Clearing the source is how the panel releases the file (see
        // onPassageCropStarted); don't try to play nothing.
        onSourceChanged: {
            if (String(source) === "")
                return;
            playbackRate = root.playSpeed;
            play();
        }
        // Push the position onto the slider while the user isn't dragging.
        onPositionChanged: function(position) {
            if (!audioSlider.pressed)
                audioSlider.value = position;
            // While playing, the highlight is driven by karaokeTicker instead —
            // this signal is too coarse for short words. Still update it when
            // paused or seeking, so scrubbing moves the highlight.
            if (root.audioModelData && root.audioModelData.karaoke
                    && playbackState !== MediaPlayer.PlayingState)
                content.pageDetails.karaokeTime = position / 1000.0;
        }
        // Clear the highlight when playback stops/ends. Starting playback is
        // also where a backend-side reset of the rate shows up, so re-assert it,
        // and drop the karaoke clock's anchor so it re-seeds from the new
        // position instead of extrapolating from a stale one.
        onPlaybackStateChanged: {
            if (playbackState === MediaPlayer.StoppedState)
                content.pageDetails.karaokeTime = -1;
            else if (Math.abs(playbackRate - root.playSpeed) > 0.001)
                playbackRate = root.playSpeed;
            root._tickLastPos = -1;
        }
        // Apply a click-to-seek that arrived before the player was seekable.
        onSeekableChanged: function(seekable) {
            if (seekable && root._pendingSeekMs >= 0) {
                setPosition(root._pendingSeekMs);
                root._pendingSeekMs = -1;
            }
        }
    }

    // The karaoke clock, deliberately not the player's position signal.
    //
    // A word is the active one from its own start until the next word's start,
    // and the highlight can only land on it if a clock reading falls inside that
    // window. positionChanged arrives roughly every 100ms, and across the books
    // 16% of word windows are shorter than 150ms and 2.7% shorter than 100ms —
    // so a real, correctly-timed word could fall between two readings and never
    // be drawn at all. That is the "it finds the word but never highlights it"
    // report, and no amount of re-aligning fixes it: the timings are right, the
    // clock is too coarse.
    //
    // Polling alone would not help if the backend only refreshes position on the
    // same slow beat, so this anchors on each fresh reading and extrapolates
    // from wall-clock in between. The extrapolation is capped, so if reports
    // stall (buffering, a stopped clip) the clock waits rather than running off.
    Timer {
        id: karaokeTicker
        interval: 30
        repeat: true
        running: playRecordAudio.playbackState === MediaPlayer.PlayingState
                 && !!(root.audioModelData && root.audioModelData.karaoke)
        onTriggered: {
            var p = playRecordAudio.position;
            if (p !== root._tickLastPos) {      // a genuinely new reading
                root._tickLastPos = p;
                root._tickBaseMs = p;
                root._tickBaseWall = Date.now();
            }
            var ahead = (Date.now() - root._tickBaseWall) * playRecordAudio.playbackRate;
            if (ahead > 250)
                ahead = 250;
            content.pageDetails.karaokeTime = (root._tickBaseMs + ahead) / 1000.0;
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

        // Playback speed. The narration runs fast enough that checking a
        // highlight word by word is hard at 1×; slowing the clip only changes
        // how fast it is played, never the stored timings, so what you hear
        // still lines up with what you see.
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                text: "Speed"
                color: "#8aa0a8"
                font.pixelSize: 11
                Layout.preferredWidth: 38
            }
            Repeater {
                model: [0.25, 0.5, 0.75, 1.0, 1.25, 1.5]
                AppButton {
                    readonly property bool current:
                        Math.abs(root.playSpeed - modelData) < 0.001
                    text: modelData + "×"
                    variant: current ? "primary" : "secondary"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    // Six buttons share a sidebar column — trim the shared
                    // padding so the labels fit instead of eliding.
                    leftPadding: 3
                    rightPadding: 3
                    onClicked: root.playSpeed = modelData
                }
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

        // A passage can align "successfully" and still be badly out of sync, and
        // nothing on screen said so — the author had to play the whole clip to
        // find out. The aligner now records why it distrusts a result, and this
        // stays visible for as long as the problem does, so a bad passage is
        // caught in the editor rather than by a reader.
        Rectangle {
            Layout.fillWidth: true
            visible: root.karaokeNeedsReview && !root.karaokeBusy
            Layout.preferredHeight: reviewCol.implicitHeight + 16
            color: "#3a2a1a"
            border.color: "#e0a000"
            border.width: 1
            radius: 4

            ColumnLayout {
                id: reviewCol
                anchors.fill: parent
                anchors.margins: 8
                spacing: 3

                Text {
                    Layout.fillWidth: true
                    text: "⚠ This alignment looks wrong"
                          + (root.karaokeMeta && root.karaokeMeta.mean_score >= 0
                             ? "  ·  score " + Number(root.karaokeMeta.mean_score).toFixed(2)
                             : "")
                    color: "#e0a000"
                    font.pixelSize: 13
                    font.bold: true
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: (root.karaokeMeta && root.karaokeMeta.review) ? root.karaokeMeta.review : []
                    Text {
                        Layout.fillWidth: true
                        text: "• " + modelData
                        color: "#d8c9a8"
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Play it back to check. If the passage is read in "
                          + "separate chunks, select each chunk on its own."
                    color: "#8aa0a8"
                    font.pixelSize: 11
                    wrapMode: Text.WordWrap
                }
            }
        }

        // Start passage selection / stop a running align / delete existing.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Same as pressing "c" with this audio open.
            AppButton {
                text: root.karaokeBusy ? "Analyzing…" : "Select karaoke (C)"
                variant: "secondary"
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                enabled: !root.karaokeBusy
                onClicked: content.pageDetails.startPassageCropMode(root.audioModelData)
            }

            // Cancel the in-flight alignment.
            AppButton {
                text: "Stop"
                variant: "danger"
                visible: root.karaokeBusy
                Layout.preferredWidth: 72
                Layout.preferredHeight: 32
                onClicked: {
                    root.karaokeCanceled = true;
                    root.karaokeStatus = "Canceling…";
                    pdfProcess.cancelPassageAudio();
                }
            }

            // Remove the saved karaoke timings for this audio.
            AppButton {
                text: "Delete"
                variant: "danger"
                visible: !root.karaokeBusy && root.audioModelData && root.audioModelData.karaoke
                Layout.preferredWidth: 72
                Layout.preferredHeight: 32
                onClicked: {
                    var rel = root._audioJsonPath();
                    if (rel !== "") {
                        var path = appPath + (rel.indexOf("./") === 0 ? rel.substring(2) : rel);
                        pdfProcess.deleteKaraoke(path, root._baseName(root.audioModelData.audioPath));
                    }
                    if (root.audioModelData)
                        root.audioModelData.karaoke = false;
                    content.pageDetails.karaokeWords = [];
                    content.pageDetails.karaokeTime = -1;
                    root.karaokeStatus = "";
                }
            }
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
                spacing: 8
                Text {
                    text: "Words"
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                // A blank with no fill under it opens nothing in the reader —
                // surface the count so the author can draw the missing fill.
                Text {
                    property int unlinked: content.pageDetails.karaokeWords
                                           ? root.unlinkedBlankCount() : 0
                    visible: unlinked > 0
                    text: "⚠ " + unlinked + " blank" + (unlinked === 1 ? "" : "s")
                          + " with no fill"
                    color: "#e57373"
                    font.pixelSize: 12
                }
                Text {
                    text: (content.pageDetails.karaokeWords
                           ? content.pageDetails.karaokeWords.length : 0) + " words"
                    color: "#8aa0a8"
                    font.pixelSize: 12
                }
                // Toggle between playback (click a word to seek) and editing
                // (click a word to rename / reorder / delete it).
                AppButton {
                    text: root.wordsEditMode ? "Done" : "Edit"
                    variant: root.wordsEditMode ? "primary" : "secondary"
                    height: 30
                    leftPadding: 12
                    rightPadding: 12
                    enabled: content.pageDetails.karaokeWords
                             && content.pageDetails.karaokeWords.length > 0
                    onClicked: {
                        root.wordsEditMode = !root.wordsEditMode;
                        root.selectedWordIndex = -1;
                        renameField.text = "";
                    }
                }
            }

            // Edit toolbar: acts on the selected word (highlighted in the list).
            RowLayout {
                Layout.fillWidth: true
                visible: root.wordsEditMode
                spacing: 6

                TextField {
                    id: renameField
                    Layout.fillWidth: true
                    enabled: root.selectedWordIndex >= 0
                    placeholderText: root.selectedWordIndex >= 0
                                     ? "Rename word…" : "Select a word to edit"
                    placeholderTextColor: "#6b7a80"
                    color: "white"
                    font.pixelSize: 13
                    selectByMouse: true
                    background: Rectangle {
                        radius: 6
                        color: "#1A2327"
                        border.color: renameField.activeFocus ? "#00b3be" : "#2f4650"
                        border.width: 1
                    }
                    onAccepted: {
                        root.renameWord(root.selectedWordIndex, text);
                        focus = false;
                    }
                }
                AppButton {
                    text: "◀"          // ◀ move earlier
                    variant: "secondary"
                    height: 32
                    leftPadding: 10
                    rightPadding: 10
                    enabled: root.selectedWordIndex > 0
                    onClicked: root.moveWord(root.selectedWordIndex, -1)
                }
                AppButton {
                    text: "▶"          // ▶ move later
                    variant: "secondary"
                    height: 32
                    leftPadding: 10
                    rightPadding: 10
                    enabled: root.selectedWordIndex >= 0
                             && content.pageDetails.karaokeWords
                             && root.selectedWordIndex
                                < content.pageDetails.karaokeWords.length - 1
                    onClicked: root.moveWord(root.selectedWordIndex, 1)
                }
                AppButton {
                    text: "Delete"
                    variant: "danger"
                    height: 32
                    enabled: root.selectedWordIndex >= 0
                    onClicked: root.deleteWord(root.selectedWordIndex)
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
                                readonly property bool isSelected:
                                    root.wordsEditMode
                                    && index === root.selectedWordIndex
                                // Cloze blank: the chip shows the answer it will
                                // reveal, not the underscores, so the author can
                                // check the pairing at a glance.
                                readonly property bool isBlank:
                                    modelData && modelData.blank === true
                                readonly property bool isLinked:
                                    isBlank && modelData.fill
                                // Reserve room for the × delete button in edit mode.
                                width: chipText.implicitWidth
                                       + (root.wordsEditMode ? 42 : 16)
                                height: chipText.implicitHeight + 10
                                radius: 4
                                color: isSelected ? "#0d3b44"
                                       : isActive ? "#ffd200"
                                       : (chipMouse.containsMouse ? "#26343c" : "transparent")
                                border.color: isSelected ? "#00b3be"
                                              : isActive ? "#ffd200"
                                              : isBlank ? (isLinked ? "#00c853" : "#e53935")
                                              : "#2f4650"
                                border.width: isSelected ? 2 : 1
                                Behavior on color { ColorAnimation { duration: 80 } }

                                Text {
                                    id: chipText
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (chip.isLinked && modelData.answer)
                                          ? "__ " + modelData.answer
                                          : ((modelData && modelData.text) ? modelData.text : "")
                                    color: (chip.isActive && !chip.isSelected)
                                           ? "#10242b" : "#cfe8ea"
                                    font.pixelSize: 14
                                    font.italic: chip.isBlank
                                    font.bold: chip.isActive || chip.isSelected
                                }

                                MouseArea {
                                    id: chipMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.wordsEditMode) {
                                            root.selectedWordIndex = index;
                                            renameField.text = (modelData && modelData.text)
                                                               ? modelData.text : "";
                                        } else if (modelData
                                                   && modelData.start !== undefined) {
                                            root.seekToWord(modelData.start);
                                        }
                                    }
                                }

                                // Per-chip quick delete. Declared after chipMouse so
                                // it sits on top and handles its own clicks.
                                Rectangle {
                                    id: chipDel
                                    visible: root.wordsEditMode
                                    width: 18
                                    height: 18
                                    radius: 9
                                    anchors.right: parent.right
                                    anchors.rightMargin: 5
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: delMouse.containsMouse ? "#c9504d" : "#33474f"
                                    Text {
                                        anchors.centerIn: parent
                                        text: "×"
                                        color: "white"
                                        font.pixelSize: 13
                                        font.bold: true
                                    }
                                    MouseArea {
                                        id: delMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.deleteWord(index)
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
