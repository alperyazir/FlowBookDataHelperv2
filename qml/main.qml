import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtMultimedia
import QtQuick.Controls.Basic

ApplicationWindow {
    id: mainwindow
    visibility: Window.Maximized
    width: 1920// Screen.width
    height: 1080 //Screen.height
    visible: true
    color: "#232f34"

    function save() {
        console.log("Ctrl+S shortcut activated!");

        sideBar.saveRemains();

        // CRASH-SAFE: Güvenli kaydetme
        try {
            if (config && config.bookSets && config.bookSets.length > 0) {
                config.bookSets[0].saveToJson();
                toast.show("Changes saved successfully!");
            } else {
                console.warn("No data to save!");
                toast.show("No data to save!");
            }
        } catch (error) {
            console.error("Save error:", error);
            toast.show("Save failed! Check console for details.");
        }
    }

    Shortcut {
        sequence: "Ctrl+S"
        onActivated: {
            save()
        }
    }

    // --- Quick-add shortcuts at current mouse position ---
    // `a` acts both as "audio" and as the prefix for activity shortcuts (a+d, a+g, ...).
    // We wait a short window after `a` to see if the next key completes an activity combo.
    property bool awaitingActivityKey: false

    Timer {
        id: activityPrefixTimer
        interval: 450
        onTriggered: commitPendingAudio()
    }

    function commitPendingAudio() {
        if (awaitingActivityKey) {
            awaitingActivityKey = false;
            activityPrefixTimer.stop();
            content.pageDetails.addAudioAtMouse();
        }
    }

    function triggerActivityCombo(type) {
        awaitingActivityKey = false;
        activityPrefixTimer.stop();
        content.pageDetails.addActivityAtMouse(type);
    }

    Shortcut {
        sequence: "a"
        onActivated: {
            // Double-a: first 'a' becomes audio, second starts fresh
            if (awaitingActivityKey) commitPendingAudio();
            awaitingActivityKey = true;
            activityPrefixTimer.restart();
        }
    }

    Shortcut {
        sequence: "v"
        onActivated: {
            commitPendingAudio();
            content.pageDetails.addVideoAtMouse();
        }
    }

    Shortcut {
        sequence: "f"
        onActivated: {
            if (awaitingActivityKey) triggerActivityCombo("fillpicture");
            else content.pageDetails.addFillAtMouse();
        }
    }

    // Activity sub-keys: only meaningful while waiting for activity combo
    Shortcut {
        sequence: "d"
        enabled: awaitingActivityKey
        onActivated: triggerActivityCombo("dragdroppicture")
    }
    Shortcut {
        sequence: "g"
        enabled: awaitingActivityKey
        onActivated: triggerActivityCombo("dragdroppicturegroup")
    }
    Shortcut {
        sequence: "c"
        enabled: awaitingActivityKey
        onActivated: triggerActivityCombo("circle")
    }
    Shortcut {
        sequence: "m"
        enabled: awaitingActivityKey
        onActivated: triggerActivityCombo("matchTheWords")
    }
    Shortcut {
        sequence: "p"
        enabled: awaitingActivityKey
        onActivated: triggerActivityCombo("puzzleFindWords")
    }
    Shortcut {
        sequence: "x"
        enabled: awaitingActivityKey
        onActivated: triggerActivityCombo("markwithx")
    }

    Shortcut {
        sequences: ["Delete", "Backspace"]
        onActivated: content.pageDetails.removeSelectedSection()
    }

    Colors {
        id: myColors
    }

    FlowToolBar {
        id: toolBar
        onOutlineEnabled: {
            content.outlineEnabled = enabled;
        }
    }

    Content {
        id: content
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: parent.width / 5.5
        anchors.top: toolBar.bottom
        width: parent.width / 2
    }

    FlowSideBar {
        id: sideBar
        width: parent.width / 3.5
        anchors.right: parent.right
        anchors.top: toolBar.bottom
        anchors.bottom: parent.bottom
    }

    Dialog {
        id: confirmDialog
        title: "Confirm Exit"
        width: parent.width / 4
        height: parent.height / 6
        anchors.centerIn: parent
        standardButtons: Dialog.Ok | Dialog.Cancel

        FlowText {
            text: "Are you sure to exit? \n Changes will be saved!"
            wrapMode: Text.NoWrap
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: parent.height
            color: myColors.textColor
            font.pixelSize: 30
        }
        onAccepted: {
            save()
            Qt.quit();
        }
        onRejected: {}
    }

    FlowToast {
        id: toast
        width: parent.width / 6
        height: 50
    }

    ActivityDialog {
        id: activityDialog
    }

    NewProjectDialog {
        id: newProjectDialog
        width: parent.width / 2
        height: parent.height / 6 * 5
        onAccepted: {
            // Show progress dialog when starting processing
            flowProgress.reset();
            flowProgress.statusText = "Processing your project...";
            flowProgress.addLogMessage("Starting project creation...");
            flowProgress.open();
        }
    }

    FlowProgress {
        id: flowProgress
    }

    OpenProject {
        id: openProject
    }

    TestDialog {
        id: testDialog
    }

    PackageDialog {
        id: packageDialog
    }

    GamesDialog {
        id: gamesDialog
    }

    ModuleEditorDialog {
        id: moduleEditorDialog
    }

    Connections {
        target: config
        function onBookSetsChanged() {
            print("Book is changed");
            content.currentPageIndex++;
            content.currentPageIndex--;
        }
    }

    // VideoOutput {
    //     id: videoOutput
    //     width: 1000
    //     height: 1000
    //     anchors.centerIn: parent
    // }

    Rectangle {
        id: versionRect
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 20
        width: versionText.width + 20
        height: 40
        color: "#1A2327"
        border.color: versionPulse.running ? "#00e6e6" : "#009ca6"
        border.width: versionPulse.running ? 2 : 1
        radius: 2
        scale: 1.0

        SequentialAnimation {
            id: versionPulse
            NumberAnimation { target: versionRect; property: "scale"; to: 1.2; duration: 180; easing.type: Easing.OutBack }
            NumberAnimation { target: versionRect; property: "scale"; to: 1.0; duration: 320; easing.type: Easing.OutBounce }
        }

        Text {
            id: versionText
            text: "v2.3.0"
            color: "#009ca6"
            anchors.centerIn: parent
            font.pixelSize: 14
        }

        MouseArea {
            id: versionClicker
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            property int clickCount: 0

            Timer {
                id: clickResetTimer
                interval: 900
                onTriggered: versionClicker.clickCount = 0
            }

            onClicked: {
                versionClicker.clickCount++;
                clickResetTimer.restart();
                if (versionClicker.clickCount >= 3) {
                    versionClicker.clickCount = 0;
                    clickResetTimer.stop();
                    easterEgg.playVideoOnly();
                } else {
                    easterEgg.burstOnly();
                }
            }
        }
    }

    // Easter-egg layer: confetti burst + greeting card
    Item {
        id: easterEgg
        anchors.fill: parent
        z: 1000

        property var palette: ["#ff3b6b", "#ff6b9d", "#ff91b5", "#ff4d8f", "#e91e63", "#ffd24a", "#f472b6", "#a78bfa"]

        function burstOnly() {
            versionPulse.restart();
            greeting.show();
            var originX = versionRect.x + versionRect.width / 2;
            var originY = versionRect.y + versionRect.height / 2;
            for (var i = 0; i < 32; i++) {
                var angle = (Math.PI * 2) * (i / 32) + (Math.random() - 0.5) * 0.25;
                var speed = 140 + Math.random() * 160;
                confettiComponent.createObject(easterEgg, {
                    x: originX - 4,
                    y: originY - 4,
                    vx: Math.cos(angle) * speed,
                    vy: Math.sin(angle) * speed - 80,
                    tint: palette[Math.floor(Math.random() * palette.length)],
                    lifespan: 1100 + Math.random() * 700,
                    rotEnd: (Math.random() - 0.5) * 1440
                });
            }
        }

        function playVideoOnly() {
            versionPulse.restart();
            greeting.showPersistent();
            videoPopup.play();
        }

        Component {
            id: confettiComponent
            Text {
                id: particle
                property real vx: 0
                property real vy: 0
                property int lifespan: 1500
                property real rotEnd: 0
                property color tint: "#ff6b9d"
                text: "♥"
                color: particle.tint
                font.pixelSize: 16 + Math.floor(Math.random() * 14)
                font.bold: true
                style: Text.Raised
                styleColor: Qt.darker(particle.tint, 1.4)
                antialiasing: true
                opacity: 1.0
                transformOrigin: Item.Center

                ParallelAnimation {
                    running: true
                    NumberAnimation { target: particle; property: "x"; to: particle.x + particle.vx; duration: particle.lifespan; easing.type: Easing.OutQuad }
                    SequentialAnimation {
                        NumberAnimation { target: particle; property: "y"; to: particle.y + particle.vy; duration: particle.lifespan * 0.35; easing.type: Easing.OutQuad }
                        NumberAnimation { target: particle; property: "y"; to: particle.y + particle.vy + 260; duration: particle.lifespan * 0.65; easing.type: Easing.InQuad }
                    }
                    NumberAnimation { target: particle; property: "rotation"; to: particle.rotEnd; duration: particle.lifespan }
                    SequentialAnimation {
                        NumberAnimation { target: particle; property: "scale"; from: 0.4; to: 1.0; duration: 200; easing.type: Easing.OutBack }
                        PauseAnimation { duration: particle.lifespan * 0.35 }
                        NumberAnimation { target: particle; property: "scale"; to: 0.6; duration: particle.lifespan * 0.45; easing.type: Easing.InQuad }
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: particle.lifespan * 0.55 }
                        NumberAnimation { target: particle; property: "opacity"; to: 0; duration: particle.lifespan * 0.45; easing.type: Easing.InQuad }
                    }
                    onFinished: particle.destroy()
                }
            }
        }

        // Greeting card — shows next to version badge for the short burst,
        // or locked at bottom-right while the full-screen video is playing.
        Rectangle {
            id: greeting
            property bool persistentMode: false
            width: greetingRow.implicitWidth + 24
            height: 40
            radius: 20
            x: persistentMode
               ? (easterEgg.width - width - 20)
               : (versionRect.x + versionRect.width + 10)
            y: persistentMode
               ? (easterEgg.height - height - 20)
               : (versionRect.y + (versionRect.height - height) / 2)
            opacity: 0
            scale: 0.6
            visible: opacity > 0.01
            z: 20
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#009ca6" }
                GradientStop { position: 0.5; color: "#0d7a8c" }
                GradientStop { position: 1.0; color: "#7c3aed" }
            }
            border.color: "#00e6e6"
            border.width: 1

            Row {
                id: greetingRow
                anchors.centerIn: parent
                spacing: 6
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Made by Alper"
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                }
            }

            function show() {
                persistentMode = false;
                showAnim.restart();
                hideDelay.restart();
            }

            function showPersistent() {
                persistentMode = true;
                hideDelay.stop();
                showAnim.restart();
            }

            function hide() {
                hideDelay.stop();
                hideAnim.restart();
            }

            ParallelAnimation {
                id: showAnim
                NumberAnimation { target: greeting; property: "opacity"; to: 1.0; duration: 260; easing.type: Easing.OutQuad }
                NumberAnimation { target: greeting; property: "scale"; to: 1.0; duration: 320; easing.type: Easing.OutBack }
            }

            ParallelAnimation {
                id: hideAnim
                NumberAnimation { target: greeting; property: "opacity"; to: 0; duration: 400; easing.type: Easing.InQuad }
                NumberAnimation { target: greeting; property: "scale"; to: 0.6; duration: 400; easing.type: Easing.InQuad }
            }

            Timer {
                id: hideDelay
                interval: 2400
                onTriggered: hideAnim.restart()
            }
        }

        // Full-screen video overlay (triggered on 3× version click)
        Rectangle {
            id: videoPopup
            anchors.fill: parent
            color: "#ee000000"  // near-opaque black backdrop
            opacity: 0
            visible: opacity > 0.01
            z: 10

            property url videoSource: "qrc:/fun/minion.mp4"

            function play() {
                videoPlayer.source = "";
                videoPlayer.source = videoPopup.videoSource;
                videoPlayer.play();
                videoShowAnim.restart();
            }

            function stop() {
                videoPlayer.stop();
                videoHideAnim.restart();
                greeting.hide();
            }

            // Modal backdrop: swallows clicks so dialogs behind don't receive them,
            // but does NOT close the popup on click — only the × button or Escape.
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onClicked: (mouse) => mouse.accepted = true
                onPressed: (mouse) => mouse.accepted = true
            }

            MediaPlayer {
                id: videoPlayer
                videoOutput: videoOut
                audioOutput: AudioOutput { volume: 0.9 }
                onMediaStatusChanged: {
                    if (mediaStatus === MediaPlayer.EndOfMedia
                            && videoPopup.opacity > 0.5) {
                        videoPopup.stop();
                    }
                }
                onErrorOccurred: function(error, errorString) {
                    console.log("Easter video error:", errorString);
                    videoPopup.stop();
                }
            }

            // Centered video frame with subtle glow
            Rectangle {
                id: videoFrame
                anchors.centerIn: parent
                width: parent.width * 0.85
                height: parent.height * 0.85
                color: "#0b1012"
                radius: 8
                border.color: "#00e6e6"
                border.width: 2
                scale: 0.6

                VideoOutput {
                    id: videoOut
                    anchors.fill: parent
                    anchors.margins: 4
                }

                // Absorb clicks on the video so they don't close via backdrop
                MouseArea { anchors.fill: parent }
            }

            // Close button
            Rectangle {
                width: 42; height: 42
                radius: 21
                color: closeMouse.containsMouse ? "#ff3b6b" : "#1A2327"
                border.color: "#00e6e6"
                border.width: 2
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 24
                z: 2

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: "white"
                    font.pixelSize: 26
                    font.bold: true
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: videoPopup.stop()
                }
            }

            Shortcut {
                sequence: "Escape"
                enabled: videoPopup.opacity > 0.5
                onActivated: videoPopup.stop()
            }

            ParallelAnimation {
                id: videoShowAnim
                NumberAnimation { target: videoPopup; property: "opacity"; to: 1.0; duration: 280; easing.type: Easing.OutQuad }
                NumberAnimation { target: videoFrame; property: "scale"; to: 1.0; duration: 420; easing.type: Easing.OutBack }
            }

            ParallelAnimation {
                id: videoHideAnim
                NumberAnimation { target: videoPopup; property: "opacity"; to: 0; duration: 300; easing.type: Easing.InQuad }
                NumberAnimation { target: videoFrame; property: "scale"; to: 0.6; duration: 300; easing.type: Easing.InQuad }
            }
        }
    }

    Timer {
        id: heartbeatTimer
        interval: 5000 // 5 saniyede bir
        repeat: true
        running: true
        onTriggered: {
            var xhr = new XMLHttpRequest();
            //var url = "http://localhost:3000/api/clients";
            //var url = "https://flowtrack.dreamedtech.com/helper.php";
            //var url = config.url
            var url = "https://flowbook.uk/api/helpers"
            var jsonData = {
                "type": "helper",
                "hostname": config.hostname,
                "active_book": openProject.currentProject,
                "active": activityTracker.active
            };

            xhr.open("POST", url);
            xhr.setRequestHeader("Content-Type", "application/json");
            xhr.send(JSON.stringify(jsonData));
        }
    }

    Timer {
        id: saveTimer
        interval: 60000 // 5 saniyede bir
        repeat: true
        running: true
        onTriggered: {
            save()
        }
    }
}
