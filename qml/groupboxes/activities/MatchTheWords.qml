import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform

import "../../newComponents"

// Match-the-words editor: shared chrome (no single section image) + two
// editable columns. Left = the items to match (word + optional picture),
// Right = the sentences, each pointing back to a left item by its index.
ColumnLayout {
    id: match
    spacing: 12

    // The per-row model object whose imagePath the browse dialog writes to.
    property var activeImage

    FileDialog {
        id: fileDialog
        title: "Select a File"
        onAccepted: {
            var selectedFilePath = fileDialog.file + "";
            if (selectedFilePath) {
                var newPath = findBooksFolder(selectedFilePath, "books");
                if (newPath) {
                    match.activeImage.imagePath = newPath;
                } else {
                    console.log("Books klasörü bulunamadı.");
                }
            } else {
                console.log("Dosya yolu geçersiz.");
            }
        }
        onRejected: console.log("File selection was canceled")
    }

    ActivityFields {
        Layout.fillWidth: true
        activityModelData: root.activityModelData
        showPath: false
        showCrop: true
        headerPlaceholder: "Match the words."
    }

    // ----- Left column: items -----
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 8

        Text {
            text: "Left  ·  items"
            color: "#cfe8ea"
            font.pixelSize: 14
            font.bold: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            color: "#16242b"
            border.color: "#2a3f48"
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ListView {
                        id: wordsRepeater
                        spacing: 5
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.activityModelData.matchWord

                        delegate: RowLayout {
                            width: ListView.view ? ListView.view.width : 0
                            spacing: 6
                            property string wordText: tf.text
                            property string imagePathText: pictureEdit.text

                            Text {
                                text: index
                                color: "#4fd2dc"
                                font.pixelSize: 13
                                font.bold: true
                                Layout.preferredWidth: 16
                                horizontalAlignment: Text.AlignHCenter
                            }
                            AppTextField {
                                id: tf
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                text: modelData.word
                                placeholderText: "word…"
                                onAccepted: { updateData(); focus = false; }
                            }
                            AppTextField {
                                id: pictureEdit
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                text: modelData.imagePath
                                placeholderText: "image path…"
                                onAccepted: { updateData(); focus = false; }
                            }
                            AppButton {
                                text: "…"
                                variant: "secondary"
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                leftPadding: 0; rightPadding: 0
                                onClicked: {
                                    match.activeImage = modelData;
                                    fileDialog.folder = "file:" + appPath + root.activityModelData.sectionPath;
                                    fileDialog.open();
                                }
                            }
                            AppButton {
                                text: "Crop"
                                variant: "primary"
                                Layout.preferredWidth: 46
                                Layout.preferredHeight: 30
                                leftPadding: 0; rightPadding: 0
                                onClicked: content.startCropMode(modelData, "imagePath")
                            }
                            AppButton {
                                text: "✕"
                                variant: "danger"
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                leftPadding: 0; rightPadding: 0
                                onClicked: root.activityModelData.removeMatchWord(index)
                            }
                        }
                    }
                }

                AppButton {
                    text: "+  Add item"
                    variant: "secondary"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    onClicked: {
                        updateData();
                        root.activityModelData.createMatchWord("", "");
                    }
                }
            }
        }
    }

    // ----- Right column: sentences -----
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 8

        Text {
            text: "Right  ·  sentences"
            color: "#cfe8ea"
            font.pixelSize: 14
            font.bold: true
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            color: "#16242b"
            border.color: "#2a3f48"
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ListView {
                        id: sentencesRepeater
                        spacing: 5
                        boundsBehavior: Flickable.StopAtBounds
                        model: root.activityModelData.sentences

                        delegate: RowLayout {
                            width: ListView.view ? ListView.view.width : 0
                            spacing: 6
                            property string wordText: matchedLeft.text
                            property string imagePathText: pictureEditRight.text
                            property string sentenceText: sentenceTxt.text

                            AppTextField {
                                id: matchedLeft
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                horizontalAlignment: Text.AlignHCenter
                                text: getMathcedIndex(modelData.word)
                                placeholderText: "#"
                            }
                            AppTextField {
                                id: sentenceTxt
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                text: modelData.sentence
                                placeholderText: "sentence…"
                                onAccepted: { updateData(); focus = false; }
                            }
                            AppTextField {
                                id: pictureEditRight
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                text: modelData.imagePath
                                placeholderText: "image path…"
                                onAccepted: { updateData(); focus = false; }
                            }
                            AppButton {
                                text: "…"
                                variant: "secondary"
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                leftPadding: 0; rightPadding: 0
                                onClicked: {
                                    match.activeImage = modelData;
                                    fileDialog.folder = "file:" + appPath + root.activityModelData.sectionPath;
                                    fileDialog.open();
                                }
                            }
                            AppButton {
                                text: "Crop"
                                variant: "primary"
                                Layout.preferredWidth: 46
                                Layout.preferredHeight: 30
                                leftPadding: 0; rightPadding: 0
                                onClicked: content.startCropMode(modelData, "imagePath")
                            }
                            AppButton {
                                text: "✕"
                                variant: "danger"
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                leftPadding: 0; rightPadding: 0
                                onClicked: root.activityModelData.removeSentences(index)
                            }
                        }
                    }
                }

                AppButton {
                    text: "+  Add sentence"
                    variant: "secondary"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    onClicked: {
                        updateData();
                        root.activityModelData.createSentences("", "", "");
                    }
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
        for (var j = 0; j < sentencesRepeater.count; j++) {
            var sitem = sentencesRepeater.itemAtIndex(j);
            if (sitem !== null) {
                root.activityModelData.sentences[j].imagePath = sitem.imagePathText;
                root.activityModelData.sentences[j].sentence = sitem.sentenceText;
                var witem = wordsRepeater.itemAtIndex(parseInt(sitem.wordText));
                if (witem !== null) {
                    root.activityModelData.sentences[j].word = witem.wordText;
                }
            }
        }
    }
}
