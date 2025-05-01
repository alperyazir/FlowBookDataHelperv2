import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Dialog {
    id: testDialog
    title: "Test with FlowBook"
    modal: true
    closePolicy: Popup.NoAutoClose // Prevents dialog from closing when clicking outside

    // Add property to track selected version
    property int selectedVersionIndex: 0
    property string selectedVersion: versionList.model.count > 0 ? versionList.model.get(selectedVersionIndex).version : ""
    property string currentProject

    width: 400
    height: 500

    // Add dark background to the dialog
    background: Rectangle {
        color: "#2B2B2B"  // Dark background
    }

    anchors.centerIn: parent

    // Load test versions when dialog opens
    onVisibleChanged: {
        if (visible) {
            var versions = pdfProcess.getTestVersions();
            versionList.model.clear();
            for (var i = 0; i < versions.length; i++) {
                versionList.model.append({
                    "version": versions[i]
                });
            }
            if (versions.length > 0) {
                selectedVersionIndex = 0;
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 20

        // Title at the top
        Label {
            text: "Test is very important 🧪"
            font.pixelSize: 18
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
            color: "#FFFFFF"  // White text for dark background
        }

        // Version selection area
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 300
            border.width: 1
            border.color: "#404040"  // Darker border
            color: "#333333"  // Dark gray background

            ListView {
                id: versionList
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10
                model: ListModel {}

                delegate: Rectangle {
                    width: parent.width
                    height: 40
                    border.width: 1
                    border.color: "#404040"
                    color: index === testDialog.selectedVersionIndex ? "#1A1A1A" : "#2B2B2B"

                    Label {
                        anchors.centerIn: parent
                        text: version
                        color: "#FFFFFF"  // White text
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            testDialog.selectedVersionIndex = index;
                            // Clear all backgrounds
                            for (let i = 0; i < versionList.count; i++) {
                                versionList.itemAtIndex(i).color = "#2B2B2B";
                            }
                            // Set selected background
                            parent.color = "#1A1A1A";  // Very dark gray for selection
                        }
                    }
                }
            }
        }

        // Buttons at the bottom
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignBottom
            spacing: 10

            Item {
                Layout.fillWidth: true
            } // Spacer

            Button {
                text: "Start"
                Layout.preferredWidth: 100
                onClicked: {
                    if (versionList.model.count > 0) {
                        // Show progress dialog
                        flowProgress.reset();
                        flowProgress.statusText = "Copying book files...";
                        flowProgress.open();

                        // Start copying process
                        pdfProcess.copyBookToTestVersion(selectedVersion, currentProject);
                    }
                }

                background: Rectangle {
                    color: parent.pressed ? myColors.buttonPressedColor : parent.hovered ? myColors.buttonHoverColor : myColors.buttonBackgroundColor
                    border.color: myColors.borderColor
                    border.width: 1
                    radius: 4
                }

                contentItem: Text {
                    text: parent.text
                    color: myColors.textColor
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Button {
                text: "Close"
                Layout.preferredWidth: 100
                onClicked: testDialog.close()

                background: Rectangle {
                    color: parent.pressed ? "#1A1A1A" : "#333333"
                    border.color: "#404040"
                    border.width: 1
                    radius: 4
                }

                contentItem: Text {
                    text: parent.text
                    color: "#FFFFFF"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    // Add Connections for handling copy completion
    Connections {
        target: pdfProcess
        function onCopyCompleted(success) {
            if (success) {
                flowProgress.addLogMessage("Successfully copied book files");
                flowProgress.statusText = "Launching FlowBook...";

                // Launch FlowBook after successful copy
                if (pdfProcess.launchTestFlowBook(selectedVersion)) {
                    flowProgress.addLogMessage("FlowBook launched successfully");
                    flowProgress.close();
                    testDialog.close();
                } else {
                    flowProgress.addLogMessage("Failed to launch FlowBook");
                }
            } else {
                flowProgress.addLogMessage("Failed to copy book files");
            }
        }
    }
}
