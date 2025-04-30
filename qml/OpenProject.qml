import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Dialog {
    id: openProjectDialog
    title: "Open Project"
    width: 600
    height: 500
    modal: true
    anchors.centerIn: parent
    closePolicy: Popup.NoAutoClose // Prevents dialog from closing when clicking outside
    standardButtons: Dialog.Ok | Dialog.Cancel

    // Signal to emit when a project is selected
    signal projectSelected(string projectPath)
    property string currentProject

    // Property to hold the selected project path
    property string selectedProjectPath: ""

    background: Rectangle {
        color: "#2c2a2a"
        border.color: "gray"
        border.width: 1
    }

    // File dialog for browsing files
    FileDialog {
        id: projectFileDialog
        title: "Select Project File"
        nameFilters: ["JSON files (*.json)"]
        onAccepted: {
            pathTextField.text = selectedFile.toString().replace("file://", "");
            selectedProjectPath = pathTextField.text;
        }
    }

    // Function to check if a string is empty or whitespace only
    function isNullOrWhitespace(str) {
        return str === null || str.trim() === "";
    }

    // Function to get recent projects from output directory
    function loadRecentProjects() {
        recentProjectsModel.clear();

        // In a real implementation, this would scan the output directory
        // For now we'll use a placeholder function that should be implemented in C++
        var projects  = []

        try {
            // This would be connected to a C++ method that returns the directory list
            projects = config.recentProject
            print("Here ", config.recentProject)
        } catch (e) {
            console.error("Error loading projects: " + e);
            // Add some example projects for demonstration
        }

        for (var i = 0; i < projects.length; i++) {
            recentProjectsModel.append({
                name: projects[i]
            });
        }
    }

    // Main content area
    ColumnLayout {
        anchors.fill: parent
        spacing: 20

        // Project path selection
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 20
            spacing: 10

            Label {
                text: "Path:"
                font.pixelSize: 20
                font.bold: true
                color: "white"
            }

            TextField {
                id: pathTextField
                Layout.fillWidth: true
                placeholderText: "path"
                color: "white"
                background: Rectangle {
                    color: "#3a3a3a"
                    border.color: "gray"
                }
            }

            Button {
                text: "..."
                width: 40
                height: 40
                onClicked: projectFileDialog.open()
                background: Rectangle {
                    color: "#505050"
                    border.color: "gray"
                }
                contentItem: Text {
                    text: "..."
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // Recent projects section
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 20
            color: "#2c2a2a"
            border.color: "gray"
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                Label {
                    text: "Recents"
                    font.pixelSize: 24
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    Layout.alignment: Qt.AlignHCenter
                    color: "white"
                }

                ListView {
                    id: recentProjectsListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: ListModel {
                        id: recentProjectsModel
                    }
                    delegate: Rectangle {
                        width: recentProjectsListView.width
                        height: 40
                        color: "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: model.name
                            font.pixelSize: 16
                            color: "white"
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: parent.color = "#3a3a3a"
                            onExited: parent.color = "transparent"
                            onClicked: {
                                // Set the selected project path
                                var projectDir = appPath + "books/" +model.name
                                currentProject = model.name

                                selectedProjectPath = projectDir;
                                pathTextField.text = projectDir;

                            }
                        }
                    }

                    ScrollBar.vertical: ScrollBar {
                        active: true
                        policy: ScrollBar.AsNeeded
                    }
                }
            }
        }
    }

    // Load recent projects when the dialog opens
    Component.onCompleted: {
        loadRecentProjects();
    }

    // Handle dialog result
    onAccepted: {
        if (!isNullOrWhitespace(selectedProjectPath)) {
            config.initialize(true, selectedProjectPath)
            print("Project is loading", selectedProjectPath)
        }
    }
}
