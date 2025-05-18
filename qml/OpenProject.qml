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

    // Custom header
    header: Rectangle {
        color: "#1A2327"
        height: 40
        border.color: "#009ca6"
        border.width: 1
        Label {
            text: "Open Project"
            color: "white"
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            font.pixelSize: 16
            font.bold: true
        }
    }

    // Custom footer for buttons
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
                onClicked: openProjectDialog.reject()
            }
            Button {
                text: "OK"
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
                onClicked: openProjectDialog.accept()
            }
        }
    }

    background: Rectangle {
        color: "#232f34"
        border.color: "#009ca6"
        border.width: 1
    }

    // Signal to emit when a project is selected
    signal projectSelected(string projectPath)
    property string currentProject

    // Property to hold the selected project path
    property string selectedProjectPath: ""

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
        var projects = [];

        try {
            // This would be connected to a C++ method that returns the directory list
            projects = config.recentProject;
            print("Here ", config.recentProject);
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
                placeholderTextColor: "gray"
                color: "white"
                background: Rectangle {
                    color: "#1A2327"
                    border.color: "#009ca6"
                    border.width: 1
                    radius: 2
                }
            }

            Button {
                text: "..."
                width: 40
                height: 40
                onClicked: projectFileDialog.open()
                background: Rectangle {
                    color: "#1A2327"
                    border.color: "#009ca6"
                    border.width: 1
                    radius: 2
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
            color: "#1A2327"
            border.color: "#009ca6"
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                // Recents header with underline
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Label {
                        text: "Recents"
                        font.pixelSize: 24
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        Layout.alignment: Qt.AlignHCenter
                        color: "white"
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: "#009ca6"
                        Layout.bottomMargin: 10
                    }
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
                        color: {
                            if (model.name === currentProject)
                                return "#009ca6";
                            return hovered ? "#232f34" : "transparent";
                        }
                        property bool hovered: false

                        Text {
                            anchors.centerIn: parent
                            text: model.name
                            font.pixelSize: 16
                            color: model.name === currentProject ? "#232f34" : "white"
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: parent.hovered = true
                            onExited: parent.hovered = false
                            onClicked: {
                                var projectDir = appPath + "books/" + model.name;
                                currentProject = model.name;
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
            config.initialize(true,  selectedProjectPath);
            print("Project is loading",  selectedProjectPath);
        }
    }
}
