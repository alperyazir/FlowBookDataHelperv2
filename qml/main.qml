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

    // Update notification (now located at bottom left)
    UpdateNotification {
        id: updateNotification
        anchors.fill: parent
        z: 10 // Make sure it's above other elements

        // Bind properties to the updateManager
        updateAvailable: updateManager.updateAvailable
        updateMessage: updateManager.updateMessage
        updateInProgress: updateManager.updateInProgress
        components: updateManager.components

        // Connect signals
        onApplyUpdatesClicked: {
            updateManager.applyUpdates();
        }
        onRestartClicked: {
            updateManager.restartApplication();
        }
        onCheckForUpdatesClicked: {
            updateManager.checkForUpdates();
        }
    }

    // Button to show update logs
    Button {
        id: updateLogButton
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 80
        anchors.bottomMargin: 20
        hoverEnabled: false
        z: 10
        width: 40
        height: 40

        icon.source: "qrc:/icons/log.png"
        icon.color: "white"

        background: Rectangle {
            color: "#3498db"
            radius: width / 2
        }

        onClicked: {
            updateLogViewer.visible = !updateLogViewer.visible;
        }

        // ToolTip.visible: hovered
        // ToolTip.text: "Güncelleme Kayıtlarını Göster"
        // ToolTip.delay: 500
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

    // Güncelleme loglarını görüntülemek için log penceresi
    UpdateLogViewer {
        id: updateLogViewer
        anchors.left: parent.left
        anchors.bottom: updateLogButton.top
        anchors.leftMargin: 20
        anchors.bottomMargin: 10
        width: parent.width / 3
        height: parent.height / 2
        visible: false
        z: 10
        logMessages: updateManager.logMessages
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

    // Update manager connections
    Connections {
        target: updateManager
        function onUpdateCompleted(success, message) {
            if (success) {
                toast.show("Güncelleme başarılı: " + message);
            } else {
                toast.show("Güncelleme hatası: " + message);
            }
        }

        function onRestartRequired() {
            var restartDialog = Qt.createComponent("Dialog");
            if (restartDialog.status === Component.Ready) {
                var dialog = restartDialog.createObject(mainwindow, {
                    "title": "Yeniden Başlatma Gerekli",
                    "standardButtons": Dialog.Yes | Dialog.No,
                    "width": mainwindow.width / 4,
                    "height": mainwindow.height / 6
                });

                var textComponent = Qt.createComponent("FlowText");
                var text = textComponent.createObject(dialog, {
                    "text": "Güncelleme tamamlandı. Değişikliklerin etkinleşmesi için uygulamayı yeniden başlatmak gerekiyor. Şimdi yeniden başlatmak istiyor musunuz?",
                    "wrapMode": Text.WordWrap,
                    "width": dialog.width - 40,
                    "anchors.centerIn": dialog.contentItem,
                    "color": myColors.textColor,
                    "font.pixelSize": 16
                });

                dialog.accepted.connect(function () {
                    updateManager.restartApplication();
                });

                dialog.open();
            }
        }
    }

    // VideoOutput {
    //     id: videoOutput
    //     width: 1000
    //     height: 1000
    //     anchors.centerIn: parent
    // }

    // Uygulama ilk başlatıldığında otomatik güncelleme kontrolü yap
    Component.onCompleted: {
        // Kısa bir gecikme ile güncelleme kontrolünü başlat
        updateCheckTimer.start();
    }

    // Güncellemeleri kontrol etmek için bir zamanlayıcı
    Timer {
        id: updateCheckTimer
        interval: 2000 // 2 seconds after startup
        repeat: false
        running: true

        onTriggered: {
            updateManager.loadConfiguration(); // Load initial configuration
            updateManager.checkForUpdates();  // Then check for updates
        }
    }
}
