import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform

import "../../../qml"

Column {
    width: parent.width
    spacing: 8

    // Fixed label column so every row lines up.
    readonly property int labelW: 92
    readonly property int rowH: 36

    FileDialog {
        id: fileDialog
        title: "Select a File"

        onAccepted: {
            var selectedFilePath = fileDialog.file + ""; // Seçilen dosyanın tam dosya yolu
            if (selectedFilePath) {
                var newPath = findBooksFolder(selectedFilePath, "books");
                if (newPath) {
                    root.activityModelData.sectionPath = newPath;
                } else {
                    console.log("Books klasörü bulunamadı.");
                }
            } else {
                console.log("Dosya yolu geçersiz.");
            }
        }

        onRejected: {
            console.log("File selection was canceled");
        }
    }

    Row {
        width: parent.width * .94
        spacing: 10
        height: rowH

        FlowText {
            text: "Type:"
            color: "white"
            anchors.centerIn: undefined
            width: labelW
            height: parent.height
            font.pixelSize: 15
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
        }

        FlowText {
            text: (activityModelData && activityModelData.type) || ""
            color: "white"
            anchors.centerIn: undefined
            height: parent.height
            font.pixelSize: 15
            verticalAlignment: Text.AlignVCenter
        }
    }

    Row {
        width: parent.width * .94
        spacing: 10
        height: rowH

        FlowText {
            text: "Header:"
            color: "white"
            anchors.centerIn: undefined
            width: labelW
            height: parent.height
            font.pixelSize: 15
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
        }

        TextField {
            width: parent.width - labelW - 2 * parent.spacing - 50
            height: parent.height
            placeholderText: "Circle the right answer."
            placeholderTextColor: "gray"
            verticalAlignment: Text.AlignVCenter
            leftPadding: 10
            text: (root.activityModelData && root.activityModelData.headerText) || ""
            color: "white"
            onTextChanged: {
                root.activityModelData.headerText = text;
            }
            background: Rectangle {
                color: "#1A2327"
                border.color: parent.focus ? "#009ca6" : "#445055"
                border.width: 1
                radius: 4
            }
        }

        // Draw a rect on the page; the instruction text inside it
        // becomes the headerText (read from the original PDF).
        Button {
            width: 50
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter

            background: Rectangle {
                color: parent.hovered ? "#00b3be" : "#009ca6"
                border.color: "#007a82"
                border.width: 1
                radius: 4
            }

            contentItem: Text {
                text: "Pick"
                color: "white"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    content.startHeaderPickMode(root.activityModelData);
                }
            }
        }
    }

    Row {
        width: parent.width * .94
        spacing: 10
        height: rowH

        FlowText {
            text: "Path:"
            color: "white"
            anchors.centerIn: undefined
            width: labelW
            height: parent.height
            font.pixelSize: 15
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
        }

        TextField {
            id: audioTextField
            width: parent.width - labelW - rowH - 2 * parent.spacing
            height: parent.height
            placeholderText: "Enter Image Path"
            placeholderTextColor: "gray"
            verticalAlignment: Text.AlignVCenter
            leftPadding: 10
            text: (root.activityModelData && root.activityModelData.sectionPath) || ""
            color: "white"
            background: Rectangle {
                color: "#1A2327"
                border.color: parent.focus ? "#009ca6" : "#445055"
                border.width: 1
                radius: 4
            }
        }

        Button {
            width: rowH
            height: rowH
            anchors.verticalCenter: parent.verticalCenter

            background: Rectangle {
                color: parent.hovered ? "#2A3337" : "#1A2327"
                border.color: "#009ca6"
                border.width: 1
                radius: 4
            }

            contentItem: Text {
                text: "..."
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    fileDialog.folder = "file:" + appPath + root.activityModelData.sectionPath;
                    fileDialog.open();
                }
            }
        }
    }

    // Crop re-runs option detection inside the drawn rect too.
    Row {
        width: parent.width * .94
        spacing: 10
        height: rowH

        Item { width: labelW; height: 1 }

        Button {
            width: (parent.width - labelW - 2 * parent.spacing) / 2
            height: rowH
            anchors.verticalCenter: parent.verticalCenter

            background: Rectangle {
                color: parent.hovered ? "#00b3be" : "#009ca6"
                border.color: "#007a82"
                border.width: 1
                radius: 4
            }

            contentItem: Text {
                text: "Crop"
                color: "white"
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    // executeCrop auto-upgrades circle crops to re-detect
                    content.startCropMode(root.activityModelData);
                }
            }
        }
    }

    Row {
        width: parent.width * .94
        spacing: 10
        height: rowH

        FlowText {
            text: "Circle count:"
            color: "white"
            anchors.centerIn: undefined
            width: labelW
            height: parent.height
            font.pixelSize: 15
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
        }

        TextField {
            id: cbCircleCount
            width: 72
            height: parent.height
            font.pixelSize: 15
            text: (root.activityModelData && root.activityModelData.circleCount) ? root.activityModelData.circleCount : 2
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: "white"

            property var allowedValues: [-1, 2, 3, 4, 5, 6, 7, 8, 9]

            validator: RegularExpressionValidator {
                regularExpression: /^(-1|[2-9])$/
            }

            background: Rectangle {
                color: "#1A2327"
                border.color: parent.focus ? "#009ca6" : "#445055"
                border.width: 1
                radius: 4
            }

            onTextChanged: {
                var numValue = parseInt(text);
                if (allowedValues.includes(numValue)) {
                    root.activityModelData.circleCount = numValue;
                }
            }

            onFocusChanged: {
                if (!focus) {
                    var numValue = parseInt(text);
                    if (!allowedValues.includes(numValue)) {
                        text = root.activityModelData.circleCount.toString();
                    }
                }
            }
        }
    }
}
