import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: updateNotification

    property bool updateAvailable: false
    property string updateMessage: ""
    property bool updateInProgress: false
    property var components: []

    signal applyUpdatesClicked
    signal restartClicked
    signal checkForUpdatesClicked

    // Main button to show the panel (bottom left)
    Button {
        id: updateButton
        width: 50
        height: 50
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 20
        hoverEnabled: false
        z: 10

        background: Rectangle {
            color: "#3498db"
            radius: width / 2

            // Update notification indicator
            Rectangle {
                visible: updateAvailable
                width: 16
                height: 16
                radius: width / 2
                color: "#e74c3c"
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: -5
                anchors.topMargin: -5

                Text {
                    anchors.centerIn: parent
                    text: ""
                    color: "white"
                    font.pixelSize: 10
                    font.bold: true
                }
            }
        }

        contentItem: Text {
            text: "Update"
            color: "white"
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        onClicked: {
            updatePanel.visible = !updatePanel.visible;
        }

        ToolTip.visible: hovered
        ToolTip.text: updateAvailable ? "Updates Available!" : "Update Center"
        ToolTip.delay: 500
    }

    // Update panel
    Rectangle {
        id: updatePanel
        width: 400
        height: 500
        anchors.left: parent.left
        anchors.bottom: updateButton.top
        anchors.leftMargin: 20
        anchors.bottomMargin: 10
        color: "#232f34"
        border.color: "#3498db"
        border.width: 1
        visible: false
        z: 10

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            // Header
            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Update Center"
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                    Layout.fillWidth: true
                }

                Button {
                    text: "X"
                    flat: true
                    implicitWidth: 32
                    implicitHeight: 32

                    contentItem: Text {
                        text: "X"
                        color: "white"
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: "transparent"
                    }

                    onClicked: {
                        updatePanel.visible = false;
                    }
                }
            }

            // Status message
            Rectangle {
                Layout.fillWidth: true
                height: statusText.contentHeight + 20
                color: updateAvailable ? "#2ecc71" : "#3498db"
                visible: updateMessage !== ""

                Text {
                    id: statusText
                    text: updateMessage
                    color: "white"
                    font.pixelSize: 14
                    font.bold: updateAvailable
                    anchors.fill: parent
                    anchors.margins: 10
                    wrapMode: Text.Wrap
                }
            }

            // Check and Update buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Button {
                    id: checkButton
                    text: "Check for Updates"
                    Layout.fillWidth: true
                    enabled: !updateInProgress

                    background: Rectangle {
                        color: checkButton.enabled ? (checkButton.hovered ? "#2980b9" : "#3498db") : "#7f8c8d"
                        radius: 5
                        border.width: 1
                        border.color: checkButton.enabled ? (checkButton.hovered ? "#1a5276" : "#2980b9") : "#7f8c8d"
                    }

                    contentItem: Text {
                        text: checkButton.text
                        color: "white"
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        updateNotification.checkForUpdatesClicked();
                    }
                }

                Button {
                    id: updateBtn
                    text: "Update"
                    Layout.fillWidth: true
                    enabled: updateAvailable && !updateInProgress

                    background: Rectangle {
                        color: updateBtn.enabled ? (updateBtn.hovered ? "#27ae60" : "#2ecc71") : "#7f8c8d"
                        radius: 5
                        border.width: 1
                        border.color: updateBtn.enabled ? (updateBtn.hovered ? "#186a3b" : "#27ae60") : "#7f8c8d"
                    }

                    contentItem: Text {
                        text: updateBtn.text
                        color: "white"
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        updateNotification.applyUpdatesClicked();
                        if (updateMessage.indexOf("restart") !== -1) {
                            // Automatically restart if needed
                            updateNotification.restartClicked();
                        }
                    }
                }
            }

            // Progress indicator
            BusyIndicator {
                running: updateInProgress
                Layout.alignment: Qt.AlignHCenter
                visible: updateInProgress
            }

            // Components List Header
            Text {
                text: "Components"
                color: "white"
                font.pixelSize: 16
                font.bold: true
                Layout.topMargin: 10
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#3498db"
            }

            // Components List
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ListView {
                    id: componentList
                    anchors.fill: parent
                    model: {
                        // Filter to show only component items (exclude application)
                        var filteredComponents = [];
                        for (var i = 0; i < updateNotification.components.length; i++) {
                            var comp = updateNotification.components[i];
                            if (comp && comp.name && comp.name !== "FlowBookEnvironment") {
                                filteredComponents.push(comp);
                            }
                        }
                        return filteredComponents;
                    }
                    spacing: 5

                    delegate: Rectangle {
                        width: ListView.view.width
                        height: 80
                        color: "#1a2327"
                        radius: 5

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 5

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    text: modelData.name || ""
                                    color: "white"
                                    font.pixelSize: 14
                                    font.bold: true
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    width: 70
                                    height: 24
                                    radius: 12
                                    color: modelData.hasUpdate ? "#e74c3c" : "#2ecc71"
                                    visible: modelData.version !== undefined

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.hasUpdate ? "New!" : "Current"
                                        color: "white"
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Text {
                                    text: "Version: " + (modelData.version || "")
                                    color: "#bdc3c7"
                                    font.pixelSize: 12
                                }

                                Text {
                                    text: "→"
                                    color: "#f1c40f"
                                    font.pixelSize: 14
                                    font.bold: true
                                    visible: modelData.hasUpdate
                                }

                                Text {
                                    text: "New Version: " + (modelData.newVersion || "")
                                    color: "#f1c40f"
                                    font.pixelSize: 12
                                    visible: modelData.hasUpdate
                                }
                            }

                            Text {
                                text: modelData.releaseNotes || ""
                                color: "#bdc3c7"
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                visible: modelData.releaseNotes && modelData.releaseNotes.length > 0
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "No components found"
                        color: "#bdc3c7"
                        font.pixelSize: 14
                        visible: componentList.count === 0
                    }
                }
            }
        }
    }
}
