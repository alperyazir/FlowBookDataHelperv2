import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Dialog {
    id: testDialog
    title: "Test with FlowBook"
    modal: true
    closePolicy: Popup.NoAutoClose

    property int selectedVersionIndex: 0
    property string selectedVersion: versionList.model.count > 0 ? versionList.model.get(selectedVersionIndex).version : ""
    property string currentProject

    width: 400
    height: 500

    // Custom header
    header: Rectangle {
        color: "#1A2327"
        height: 40
        border.color: "#009ca6"
        border.width: 1
        Label {
            text: "Test with FlowBook"
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
                onClicked: testDialog.reject()
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
                onClicked: {
                    if (versionList.model.count > 0) {
                        // flowProgress.reset();
                        // flowProgress.statusText = "Copying book files...";
                        // flowProgress.open();
                        pdfProcess.launchTestFlowBook(selectedVersion);
                    }
                }
            }
        }
    }

    background: Rectangle {
        color: "#232f34"
        border.color: "#009ca6"
        border.width: 1
        radius: 4
    }

    anchors.centerIn: parent

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

        Label {
            text: "Test is very important 🧪"
            font.pixelSize: 18
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
            color: "white"
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 300
            border.width: 1
            border.color: "#009ca6"
            color: "#1A2327"
            radius: 4

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
                    border.color: "#009ca6"
                    color: index === testDialog.selectedVersionIndex ? "#009ca6" : "transparent"
                    radius: 2

                    Label {
                        anchors.centerIn: parent
                        text: version
                        color: index === testDialog.selectedVersionIndex ? "#232f34" : "white"
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: if (index !== testDialog.selectedVersionIndex)
                            parent.color = "#232f34"
                        onExited: if (index !== testDialog.selectedVersionIndex)
                            parent.color = "transparent"
                        onClicked: {
                            testDialog.selectedVersionIndex = index;
                            for (let i = 0; i < versionList.count; i++) {
                                let item = versionList.itemAtIndex(i);
                                if (item) {
                                    item.color = i === index ? "#009ca6" : "transparent";
                                    item.children[0].color = i === index ? "#232f34" : "white";
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: pdfProcess
        function onCopyCompleted(success) {
            if (success) {
                flowProgress.addLogMessage("Successfully copied book files");
                flowProgress.statusText = "Launching FlowBook...";

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
