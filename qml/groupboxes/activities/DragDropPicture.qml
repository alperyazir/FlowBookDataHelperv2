import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform

import "../../../qml"

Column {

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
        height: parent.height * .1
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
        height: parent.height * .1
        FlowText {
            text: "Header: "
            color: "white"
            anchors.centerIn: undefined
            width: parent.width * .15
            verticalAlignment: Text.AlignBottom
        }

        // TextEdit bileşeni
        TextField {
            width: parent.width * .75
            height: parent.height
            placeholderText: "Complete the sentences."
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
        height: parent.height * 0.1
        FlowText {
            text: "Path: "
            color: "white"
            anchors.centerIn: undefined
            width: parent.width * .15
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
            text: root.activityModelData.sectionPath
            color: "white"
            background: Rectangle {
                color: "#1A2327"
                border.color: parent.focus ? "#009ca6" : "#445055"
                border.width: 1
                radius: 4
            }
        }

        Button {
            width: height
            height: parent.height
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

        Button {
            width: 50
            height: 36
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
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    content.startCropMode(root.activityModelData);
                }
            }
        }
    }

    GroupBox {
        id: wordsGB
        title: "Words"
        width: parent.width * .9
        height: parent.height * .7
        anchors.horizontalCenter: parent.horizontalCenter
        Column {
            width: parent.width * .9
            height: parent.height
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2

            ScrollView {
                id: scrol
                width: parent.width
                height: parent.height * 0.9
                ScrollBar.vertical.interactive: true
                clip: true
                ListView {
                    id: wordsRepeater
                    width: parent.width
                    height: parent.height
                    model: root.activityModelData.words
                    delegate: Row {
                        property string wText: tf.text
                        anchors.horizontalCenter: parent.horizontalCenter
                        height: 20
                        width: scrol.width
                        TextField {
                            id: tf
                            width: parent.width * .75
                            height: 20
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: modelData
                            color: "white"
                            background: Rectangle {
                                color: "#1A2327"
                                border.color: parent.focus ? "#009ca6" : "#445055"
                                border.width: 1
                                radius: 4
                            }

                            onAccepted: {
                                updateData()
                                focus = false
                            }
                        }

                        Button {
                            width: 20
                            height: 20
                            anchors.verticalCenter: parent.verticalCenter
                            text: "X"

                            background: Rectangle {
                                color: parent.hovered ? "#bf4040" : "#a63030"
                                radius: 4
                            }

                            contentItem: Text {
                                text: parent.text
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.activityModelData.removeWord(index);
                                }
                            }
                        }
                    }
                }
            }
            Button {
                text: "Add"
                height: parent.height * .1
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: {

                    updateData()
                    root.activityModelData.addNewWord("");

                }
            }


        }
    }

    function updateData() {
        for (var i = 0; i < wordsRepeater.count; i++) {
            var item = wordsRepeater.itemAtIndex(i);
            if (item !== null) {
                print(item.wText);
                root.activityModelData.words[i] = item.wText;
            }
        }
    }
}
