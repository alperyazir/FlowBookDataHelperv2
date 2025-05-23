import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform

import "../../../qml"

Column {
    property var words: wordsRepeater
    width: parent.width

    FileDialog {
        id: fileDialog
        title: "Select a File"
        //folder: StandardPaths.home // Varsayılan başlangıç yolu, değiştirilecektir

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
        width: parent.width * .9
        spacing: 10
        height: 40
        FlowText {
            id: textType
            text: "Type: "
            color: "white"
            anchors.centerIn: undefined
            width: parent.width * .15
            font.pixelSize: 15
            verticalAlignment: Text.AlignBottom
        }

        FlowText {
            text: activityModelData.type
            color: "white"
            anchors.centerIn: undefined
            font.pixelSize: 15
            verticalAlignment: Text.AlignBottom
        }
    }

    Row {
        width: parent.width * .9
        spacing: 10
        height: 40
        FlowText {
            text: "Header: "
            color: "white"
            anchors.centerIn: undefined
            width: parent.width * .15
            font.pixelSize: 15
            verticalAlignment: Text.AlignBottom
        }

        // TextEdit bileşeni
        TextField {
            width: parent.width * .75
            height: parent.height
            placeholderText: "Mark the right answer."
            placeholderTextColor: "gray"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.activityModelData.headerText
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
    }

    Row {
        width: parent.width * .9
        spacing: 10
        height: 40
        FlowText {
            text: "Path: "
            color: "white"
            anchors.centerIn: undefined
            width: parent.width * .15
            font.pixelSize: 15
            verticalAlignment: Text.AlignBottom
        }

        // TextEdit bileşeni
        TextField {
            id: audioTextField
            width: parent.width * .75
            height: parent.height
            placeholderText: "Enter Image Path"
            placeholderTextColor: "gray"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            color: "white"
            text: root.activityModelData.sectionPath
            background: Rectangle {
                color: "#1A2327"
                border.color: parent.focus ? "#009ca6" : "#445055"
                border.width: 1
                radius: 4
            }
        }


        Button {
            width: 36
            height: 36
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

    Row {
        width: parent.width * .9
        spacing: 10
        height: 40
        FlowText {
            text: "Mark count: "
            color: "white"
            anchors.centerIn: undefined
            width: parent.width * .15
            font.pixelSize: 15
            verticalAlignment: Text.AlignBottom
        }

        SpinBox {
            id: cbCircleCount
            width: height * 2
            height: parent.height
            font.pixelSize: 15
            value: 2
            editable: true

            onValueChanged: {
                root.activityModelData.markCount = value;
                config.bookSets[0].saveToJson();
                print("mark count changed to:", value);
            }
        }
    }
}
