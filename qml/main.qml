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
        anchors.top: toolBar.bottom
        anchors.bottom: parent.bottom
        width: parent.width /2
        anchors.left: parent.left
        anchors.leftMargin: parent.width / 5.5
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
        background: Rectangle {
            color: myColors.surfaceColor
            border.color: myColors.borderColor
            border.width: 1
        }
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
            config.bookSets[0].saveToJson();
            toast.show("Changes are saved to File!");
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
        width: parent.width/2
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

    Connections {
        target: config
        function onBookSetsChanged() {
            print("Book is changed");
            content.currentPageIndex++; content.currentPageIndex--;
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
            text: "v2.0.0"  // versiyon numaranızı buraya yazın
            color: "#009ca6"
            anchors.centerIn: parent
            font.pixelSize: 14
        }

        MouseArea {
            anchors.fill: parent
            onDoubleClicked: {
                emojiAnimation.restart()
                emoji.visible = true
                hideTimer.restart()
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
                emoji.visible = false
                emoji.scale = 0
            }
        }
    }
}
