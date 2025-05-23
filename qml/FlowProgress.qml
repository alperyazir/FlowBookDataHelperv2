import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Dialog {
    id: flowProgress
    title: "Processing"
    width: 600
    height: detailsExpanded ? 500 : 250
    modal: true
    closePolicy: Popup.NoAutoClose
    anchors.centerIn: parent
    standardButtons: Dialog.Cancel

    // Properties
    property int progress: 0
    property string statusText: "Processing..."
    property bool detailsExpanded: false
    property var logMessages: ["Alper", "Test"]

    Behavior on height {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutQuad
        }
    }

    header: Rectangle {
        color: "#1A2327"
        height: 40
        border.color: "#009ca6"
        border.width: 1
        Label {
            text: "Processing"
            color: "white"
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            font.pixelSize: 16
            font.bold: true
        }
    }

    footer: Rectangle {
        color: "#1A2327"
        height: 60
        border.color: "#009ca6"
        border.width: 1
        RowLayout {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 10
            spacing: 10
            Button {
                text: "Cancel"
                Layout.preferredWidth: 80
                Layout.preferredHeight: 32
                background: Rectangle {
                    color: parent.hovered ? "#2A3337" : "#1A2327"
                    border.color: "#009ca6"
                    border.width: 1
                    radius: 2
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: flowProgress.reject()
            }
        }
    }

    background: Rectangle {
        color: "#232f34"
        border.color: "#009ca6"
        border.width: 1
    }

    // Content
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        // Status text
        Label {
            id: statusLabel
            text: "You can take a coffee ☕️ or a smoke 🚬"
            color: "white"
            font.pixelSize: 16
            Layout.fillWidth: true
        }

        // Progress bar
        ProgressBar {
            id: progressBar
            value: progress / 100
            Layout.fillWidth: true
            height: 24

            background: Rectangle {
                implicitWidth: 200
                implicitHeight: 24
                color: "#1A2327"
                border.color: "#009ca6"
                radius: 2
            }

            contentItem: Item {
                implicitWidth: 200
                implicitHeight: 24

                Rectangle {
                    width: progressBar.visualPosition * parent.width
                    height: parent.height
                    radius: 2
                    color: "#009ca6"  // Green color
                }

                Text {
                    anchors.centerIn: parent
                    text: progress + "%"
                    color: "white"
                    font.bold: true
                }
            }
        }

        // Details button
        Button {
            id: detailsButton
            text: detailsExpanded ? "Hide Details" : "Show Details"
            Layout.alignment: Qt.AlignHCenter
            width: 120  // Sabit bir genişlik değeri
            height: 40  // Sabit bir yükseklik değeri
            onClicked: {
                detailsExpanded = !detailsExpanded;
            }

            background: Rectangle {
                color: parent.hovered ? "#2A3337" : "#1A2327"
                border.color: "#009ca6"
                border.width: 1
                radius: 2
            }

            contentItem: Text {
                text: detailsButton.text
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 14  // Yazı boyutunu da belirleyin
            }
        }

        // Log messages (only visible when details expanded)
        Rectangle {
            visible: detailsExpanded
            color: "#0f0f0f"
            border.color: "#505050"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ScrollView {
                id: scrollView
                anchors.fill: parent
                anchors.margins: 5
                ScrollBar.vertical.policy: ScrollBar.AlwaysOn

                TextArea {
                    id: logTextArea
                    visible: detailsExpanded
                    readOnly: true
                    color: "#CCCCCC"
                    font.family: "Courier New, monospace"
                    font.pixelSize: 12
                    background: Rectangle {
                        color: "#0f0f0f"
                        border.color: "#505050"
                    }
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                }
            }
        }
    }

    // Function to update progress
    function updateProgress(value, message) {
        progress = value;
        if (message && message !== "") {
            statusText = message;
            addLogMessage(message);
        }
    }

    // Function to add a log message
    function addLogMessage(message) {
        logTextArea.text += message + "\n";
        // Otomatik kaydırma
        logTextArea.cursorPosition = logTextArea.text.length;
    }
    // Function to clear logs
    function clearLogs() {
        logTextArea.text = "";
    }

    // Function to reset dialog
    function reset() {
        progress = 0;
        statusText = "Processing...";
        clearLogs();
    }

    // Cancel button handler
    onRejected: {
        // You would typically add code here to cancel the ongoing process
        console.log("Process canceled by user");
    }

    Connections {
        target: pdfProcess

        function onProgressChanged() {
            progress = pdfProcess.progress;
        }

        function onLogMessagesChanged() {
            addLogMessage(pdfProcess.logMessages);
        }
    }
}
