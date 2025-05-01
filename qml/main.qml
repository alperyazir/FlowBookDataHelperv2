import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtMultimedia

ApplicationWindow {
    id: mainwindow
    //visibility: Window.Maximized
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
        width: 850
        anchors.horizontalCenter: parent.horizontalCenter
    }

    FlowSideBar {
        id: sideBar
        width: parent.width / 4
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
        onBookSetsChanged: {
            print("Book is changed");
        }
    }

    // VideoOutput {
    //     id: videoOutput
    //     width: 1000
    //     height: 1000
    //     anchors.centerIn: parent
    // }

}
