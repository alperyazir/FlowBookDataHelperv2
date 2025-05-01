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
                                  windows: false      // Windows 10+ selected by default
                                  ,
                                  windows78: false   // Windows 7-8 not selected by default
                                  ,
                                  linux: false        // Linux selected by default
                                  ,
                                  macos: false       // macOS not selected by default
                              })

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        // Title
        Label {
            text: "Select Platforms  🙈"
            font.pixelSize: 16
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        // Checkbox group container
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 160
            color: "transparent"
            border.width: 1
            border.color: "#CCCCCC"
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

                }

                CheckBox {
                    id: windows78Check
                    text: "Windows 7-8"
                    checked: selectedOS.windows78
                    onCheckedChanged: selectedOS.windows78 = checked
                    Layout.leftMargin: 20  // Indent to show it's related to Windows
                }

                CheckBox {
                    id: linuxCheck
                    text: "Linux"
                    checked: selectedOS.linux
                    onCheckedChanged: selectedOS.linux = checked
                }

                CheckBox {
                    id: macosCheck
                    text: "MacOs"
                    checked: selectedOS.macos
                    onCheckedChanged: selectedOS.macos = checked
                 }
            }
        }

        // Buttons container
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignBottom
            spacing: 10

            Item {
                Layout.fillWidth: true
            }  // Spacer

            Button {
                text: "Package"
                Layout.preferredWidth: 100
                onClicked: {
                    // Convert selectedOS object to platform list
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

            Button {
                text: "Exit"
                Layout.preferredWidth: 100
                onClicked: packageDialog.close()
            }
        }
    }
}
