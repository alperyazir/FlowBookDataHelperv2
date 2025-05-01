import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform

import "../../../qml"

Column {
    property var words: wordsRepeater
    property var sentences: sentencesRepeater
    property var activeImage
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
                    activeImage.imagePath = newPath;
                    print("activeImage", activeImage);
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
            placeholderText: "Match the words."
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.activityModelData.headerText
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

    GroupBox {
        id: wordsGB
        title: "Left"
        width: parent.width * .95
        anchors.horizontalCenter: parent.horizontalCenter
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            spacing: 1
            Repeater {
                id: wordsRepeater
                model: root.activityModelData.matchWord
                Row {
                    property string wordText: tf.text
                    property string imagePathText: pictureEdit.text
                    width: parent.width
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 30

                    Text {
                        text: index + "-"
                        width: parent.width * 0.03
                        height: parent.height
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    TextField {
                        id: tf
                        width: parent.width * 0.40
                        height: 30
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.word
                        placeholderText: "add..."
                        placeholderTextColor: "gray"
                        background: Rectangle {
                            color: "#1A2327"
                            border.color: parent.focus ? "#009ca6" : "#445055"
                            border.width: 1
                            radius: 4
                        }
                    }

                    TextField {
                        id: pictureEdit
                        width: parent.width * 0.40
                        height: 30
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.imagePath
                        placeholderText: "add path..."
                        placeholderTextColor: "gray"
                        background: Rectangle {
                            color: "#1A2327"
                            border.color: parent.focus ? "#009ca6" : "#445055"
                            border.width: 1
                            radius: 4
                        }
                    }


                    Button {
                        width: 30
                        height: 30
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
                                activeImage = modelData;
                                fileDialog.folder = "file:" + appPath + root.activityModelData.sectionPath;
                                fileDialog.open();
                            }
                        }
                    }

                    Button {
                        width: 30
                        height: 30
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
                                root.activityModelData.removeMatchWord(index);
                            }
                        }
                    }
                }
            }

            Button {
                text: "Add New"
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: {
                    saveChanges();

                    root.activityModelData.createMatchWord("", "");
                }
            }
        }
    }

    GroupBox {
        id: rightGB
        title: "Right"
        width: parent.width * .95
        anchors.horizontalCenter: parent.horizontalCenter
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            spacing: 1
            Repeater {
                id: sentencesRepeater
                model: root.activityModelData.sentences
                Row {
                    property string wordText: matchedLeft.text
                    property string imagePathText: pictureEditRight.text
                    property string sentenceText: sentenceTxt.text

                    width: parent.width
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 30
                    TextField {
                        id: matchedLeft
                        width: parent.width * 0.05
                        height: 30
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: getMathcedIndex(modelData.word)
                        placeholderText: "."
                        placeholderTextColor: "gray"
                        background: Rectangle {
                            color: "#1A2327"
                            border.color: parent.focus ? "#009ca6" : "#445055"
                            border.width: 1
                            radius: 4
                        }
                    }

                    TextField {
                        id: sentenceTxt
                        width: parent.width * 0.39
                        height: 30
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.sentence
                        placeholderText: "add..."
                        placeholderTextColor: "gray"
                        background: Rectangle {
                            color: "#1A2327"
                            border.color: parent.focus ? "#009ca6" : "#445055"
                            border.width: 1
                            radius: 4
                        }
                    }

                    TextField {
                        id: pictureEditRight
                        width: parent.width * 0.39
                        height: 30
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.imagePath
                        placeholderText: "add path..."
                        placeholderTextColor: "gray"
                        background: Rectangle {
                            color: "#1A2327"
                            border.color: parent.focus ? "#009ca6" : "#445055"
                            border.width: 1
                            radius: 4
                        }
                    }



                    Button {
                        width: 30
                        height: 30
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
                                activeImage = modelData;
                                fileDialog.folder = "file:" + appPath + root.activityModelData.sectionPath;
                                fileDialog.open();
                            }
                        }
                    }


                    Button {
                        width: 30
                        height: 30
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
                                root.activityModelData.removeSentences(index);                                                }
                        }
                    }
                }
            }

            Button {
                text: "Add New"
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: {
                    saveChanges();

                    root.activityModelData.createSentences("", "", "");
                }
            }
        }
    }

    function getMathcedIndex(sentence) {
        for (var i = 0; i < root.activityModelData.matchWord.length; i++) {
            if (root.activityModelData.matchWord[i].word === sentence)
                return i;
        }
        return "";
    }
}
