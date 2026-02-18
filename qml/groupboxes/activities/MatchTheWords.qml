import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform

import "../../../qml"

Column {
    // property var words: wordsRepeater
    // property var sentences: sentencesRepeater
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

    GroupBox {
        id: wordsGB
        title: "Left"
        width: parent.width
        height: parent.height * .40
        anchors.horizontalCenter: parent.horizontalCenter
        Column {
            width: parent.width
            height: parent.height
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2

            ScrollView {
                id: scrol1
                width: parent.width
                height: parent.height * 0.9
                ScrollBar.vertical.interactive: true
                clip: true
                ListView {
                    id: wordsRepeater
                    property var data: ({})
                    width: parent.width
                    height: parent.height
                    model: root.activityModelData.matchWord
                    delegate: Row {
                        property string wordText: tf.text
                        property string imagePathText: pictureEdit.text
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: scrol1.width
                        height: scrol1.height / 5
                        FlowText {
                            text: index
                            width: parent.width * 0.05
                            height: parent.height
                            color: "white"

                            anchors.centerIn: undefined
                        }
                        TextField {
                            id: tf
                            width: parent.width * 0.40
                            height: parent.height
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: modelData.word
                            placeholderText: "add..."
                            placeholderTextColor: "gray"
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
                        TextField {
                            id: pictureEdit
                            width: parent.width * 0.40
                            height: parent.height
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: modelData.imagePath
                            placeholderText: "add path..."
                            placeholderTextColor: "gray"
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
                            width: parent.width * 0.075
                            height: parent.height
                            anchors.verticalCenter: parent.verticalCenter

                            background: Rectangle {
                                color: parent.hovered ? "#2A3337" : "#1A2327"
                                border.color: "#009ca6"
                                border.width: 1
                                radius: 4
                            }

                            contentItem: FlowText {
                                text: "..."
                                color: "white"
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
                            width: parent.width * 0.075
                            height: parent.height
                            anchors.verticalCenter: parent.verticalCenter

                            background: Rectangle {
                                color: parent.hovered ? "#00b3be" : "#009ca6"
                                border.color: "#007a82"
                                border.width: 1
                                radius: 4
                            }

                            contentItem: FlowText {
                                text: "Crop"
                                color: "white"
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    content.startCropMode(modelData, "imagePath");
                                }
                            }
                        }
                        Button {
                            width: parent.width * 0.075
                            height: parent.height
                            anchors.verticalCenter: parent.verticalCenter
                            text: "X"

                            background: Rectangle {
                                color: parent.hovered ? "#bf4040" : "#a63030"
                                radius: 4
                            }

                            contentItem: FlowText {
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
            }

            Button {
                text: "Add New"
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: {
                    updateData();
                    root.activityModelData.createMatchWord("", "");
                }
            }
        }
    }

    GroupBox {
        id: rightGB
        title: "Right"
        width: parent.width
        height: parent.height * .40
        anchors.horizontalCenter: parent.horizontalCenter
        Column {
            width: parent.width
            height: parent.height
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2

            ScrollView {
                id: scrol2
                width: parent.width
                height: parent.height * 0.9
                ScrollBar.vertical.interactive: true
                clip: true

                ListView {
                    id: sentencesRepeater
                    width: parent.width
                    height: parent.height
                    model: root.activityModelData.sentences
                    delegate: Row {
                        property string wordText: matchedLeft.text
                        property string imagePathText: pictureEditRight.text
                        property string sentenceText: sentenceTxt.text

                        width: scrol2.width
                        height: scrol2.height / 5
                        anchors.horizontalCenter: parent.horizontalCenter
                        TextField {
                            id: matchedLeft
                            width: parent.width * 0.07
                            height: parent.height
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: getMathcedIndex(modelData.word)
                            placeholderText: "."
                            placeholderTextColor: "gray"
                            color: "white"
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
                            height: parent.height
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: modelData.sentence
                            placeholderText: "add..."
                            placeholderTextColor: "gray"
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
                        TextField {
                            id: pictureEditRight
                            width: parent.width * 0.39
                            height: parent.height
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: modelData.imagePath
                            placeholderText: "add path..."
                            placeholderTextColor: "gray"
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
                            width: parent.width * 0.075
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
                                    activeImage = modelData;
                                    fileDialog.folder = "file:" + appPath + root.activityModelData.sectionPath;
                                    fileDialog.open();
                                }
                            }
                        }
                        Button {
                            width: parent.width * 0.075
                            height: parent.height
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
                                font.pixelSize: 10
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    content.startCropMode(modelData, "imagePath");
                                }
                            }
                        }
                        Button {
                            width: parent.width * 0.075
                            height: parent.height
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
                                    root.activityModelData.removeSentences(index);
                                }
                            }
                        }
                    }
                }
            }

            Button {
                text: "Add New"
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: {
                    updateData()
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

    function updateData() {


        for (var i = 0; i < wordsRepeater.count; i++) {
            var item = wordsRepeater.itemAtIndex(i);
            if (item !== null) {
                root.activityModelData.matchWord[i].word = item.wordText;
                root.activityModelData.matchWord[i].imagePath = item.imagePathText;
            }
        }
        // Match sentence
        for (var i = 0; i < sentencesRepeater.count; i++) {
            var item = sentencesRepeater.itemAtIndex(i);
            if (item !== null) {
                root.activityModelData.sentences[i].imagePath = item.imagePathText;
                root.activityModelData.sentences[i].sentence = item.sentenceText;
                var witem = wordsRepeater.itemAtIndex(parseInt(item.wordText));
                if (witem !== null) {
                    root.activityModelData.sentences[i].word = witem.wordText;
                }
            }
        }
    }
}
