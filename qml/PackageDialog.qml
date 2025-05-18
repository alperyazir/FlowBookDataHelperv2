import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Dialog {
    id: packageDialog
    property string currentProject
    title: "Let's Package"
    modal: true
    closePolicy: Popup.NoAutoClose
    width: 400
    height: 500

    anchors.centerIn: parent

    // Properties to track selected operating systems
    property var selectedOS: ({
                                  windows: false,
                                  windows78: false,
                                  linux: false,
                                  macos: false
                              })

    // Custom header
    header: Rectangle {
        color: "#1A2327"
        height: 40
        border.color: "#009ca6"
        border.width: 1
        Label {
            text: "Let's Package"
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
                onClicked: packageDialog.reject()
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
                    var platforms = [];
                    if (selectedOS.windows)
                        platforms.push("windows");
                    if (selectedOS.windows78)
                        platforms.push("windows78");
                    if (selectedOS.linux)
                        platforms.push("linux");
                    if (selectedOS.macos)
                        platforms.push("macos");
                    if (platforms.length > 0) {
                        var success = pdfProcess.packageForPlatforms(platforms, currentProject);
                        flowProgress.reset();
                        flowProgress.statusText = "Packaging is Processing...";
                        flowProgress.addLogMessage("Starting ...");
                        flowProgress.open();
                        packageDialog.close();
                        if (success) {
                            console.log("Successfully packaged for platforms:", platforms);
                            packageDialog.close();
                        } else {
                            console.error("Failed to package for platforms:", platforms);
                        }
                    } else {
                        console.error("No platforms selected");
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

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        Label {
            text: "Select Platforms  🙈"
            font.pixelSize: 16
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
            color: "white"
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 250
            color: "transparent"
            border.width: 1
            border.color: "#009ca6"
            radius: 4

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 15

                CheckBox {
                    id: windowsCheck
                    text: "Windows"
                    checked: selectedOS.windows
                    onCheckedChanged: selectedOS.windows = checked
                    width: 400
                    height: 50

                    indicator: Rectangle {
                        width: 18
                        height: 18
                        radius: 4
                        color: windowsCheck.checked ? "#00e6e6" : "#232f34"
                        border.color: "#009ca6"
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 5
                    }

                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.indicator.right
                        anchors.leftMargin: 10
                    }
                }

                CheckBox {
                    id: windows78Check
                    text: "Windows 7-8"
                    checked: selectedOS.windows78
                    width: 150
                    onCheckedChanged: selectedOS.windows78 = checked
                    Layout.leftMargin: 20
                    indicator: Rectangle {
                        width: 18
                        height: 18
                        radius: 4
                        color: windows78Check.checked ? "#00e6e6" : "#232f34"
                        border.color: "#009ca6"
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.indicator.right
                        anchors.leftMargin: 10
                    }
                }

                CheckBox {
                    id: linuxCheck
                    text: "Linux"
                    checked: selectedOS.linux
                    width: 150
                    onCheckedChanged: selectedOS.linux = checked
                    indicator: Rectangle {
                        width: 18
                        height: 18
                        radius: 4
                        color: linuxCheck.checked ? "#00e6e6" : "#232f34"
                        border.color: "#009ca6"
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.indicator.right
                        anchors.leftMargin: 10
                    }
                }

                CheckBox {
                    id: macosCheck
                    text: "MacOS"
                    checked: selectedOS.macos
                    onCheckedChanged: selectedOS.macos = checked
                    indicator: Rectangle {
                        width: 18
                        height: 18
                        radius: 4
                        color: macosCheck.checked ? "#00e6e6" : "#232f34"
                        border.color: "#009ca6"
                        border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.indicator.right
                        anchors.leftMargin: 10
                    }
                }
            }
        }
    }
}
