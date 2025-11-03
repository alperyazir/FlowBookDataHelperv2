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
        border.color: "#009ca6"
        border.width: 1
        radius: 2

        Text {
            id: versionText
            text: "v2.2.0"  // versiyon numaranızı buraya yazın
            color: "#009ca6"
            anchors.centerIn: parent
            font.pixelSize: 14
        }

        MouseArea {
            anchors.fill: parent
            onDoubleClicked: {
                emojiAnimation.restart();
                emoji.visible = true;
                hideTimer.restart();
            }
        }
    }

    // Emoji için Text component'i
    Text {
        id: emoji
        text: "🤗"  // kucaklayan emoji
        font.pixelSize: 48
        visible: false
        anchors.left: versionRect.right
        anchors.leftMargin: 5
        anchors.verticalCenter: versionRect.verticalCenter

        NumberAnimation {
            id: emojiAnimation
            target: emoji
            property: "scale"
            from: 0
            to: 1
            duration: 200
            easing.type: Easing.OutBack
        }

        Timer {
            id: hideTimer
            interval: 2000
            onTriggered: {
                emoji.visible = false;
                emoji.scale = 0;
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
                "active_book": openProject.currentProject
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
