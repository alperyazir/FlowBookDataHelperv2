import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import Qt.labs.platform
import ".."

Rectangle {
    id: root

    property var selectorQuestion: ({
            "question": "",
            "image": "",
            "audio": "",
            "video": "",
            "answers": []
        })

    // Add question ID property
    property int questionId: 0

    // Signals for external communication
    signal questionDeleted
    signal optionAdded
    signal optionDeleted(int index)

    // Function to find books folder - copied from other cards
    function findBooksFolder(filePath, targetFolder) {
        var pathParts = filePath.split("/");
        var booksIndex = -1;
        for (var i = pathParts.length - 1; i >= 0; i--) {
            if (pathParts[i] === targetFolder) {
                booksIndex = i;
                break;
            }
        }
        if (booksIndex !== -1) {
            var newPath = "./";
            for (booksIndex; booksIndex < pathParts.length; booksIndex++) {
                newPath += pathParts[booksIndex] + "/";
            }
            if (newPath.length > 0) {
                newPath = newPath.substring(0, newPath.length - 1);
            }
            return newPath;
        }
        return null;
    }

    Component.onCompleted: {
        console.log("Selector question loaded. Options count:", selectorQuestion.answers ? selectorQuestion.answers.length : 0);
    }

    width: parent.width
    height: parent.height
    radius: 8
    color: "#1A2327"
    border.color: "#009ca6"
    border.width: 1

    // FileDialog for question image
    FileDialog {
        id: questionImageDialog
        title: "Select Question Image"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.gif *.bmp)"]
        onAccepted: {
            var selectedFilePath = questionImageDialog.file + "";
            if (selectedFilePath) {
                var newPath = findBooksFolder(selectedFilePath, "books");
                if (newPath) {
                    questionImageField.text = newPath;
                    if (selectorQuestion) {
                        selectorQuestion.image = newPath;
                    }
                } else {
                    questionImageField.text = selectedFilePath;
                    if (selectorQuestion) {
                        selectorQuestion.image = selectedFilePath;
                    }
                }
            }
        }
    }

    // FileDialog for question audio
    FileDialog {
        id: questionAudioDialog
        title: "Select Question Audio"
        nameFilters: ["Audio files (*.mp3 *.wav *.ogg)"]
        onAccepted: {
            var selectedFilePath = questionAudioDialog.file + "";
            if (selectedFilePath) {
                var newPath = findBooksFolder(selectedFilePath, "books");
                if (newPath) {
                    questionAudioField.text = newPath;
                    if (selectorQuestion) {
                        selectorQuestion.audio = newPath;
                    }
                } else {
                    questionAudioField.text = selectedFilePath;
                    if (selectorQuestion) {
                        selectorQuestion.audio = selectedFilePath;
                    }
                }
            }
        }
    }

    // FileDialog for question video
    FileDialog {
        id: questionVideoDialog
        title: "Select Question Video"
        nameFilters: ["Video files (*.mp4 *.avi *.mov *.mkv)"]
        onAccepted: {
            var selectedFilePath = questionVideoDialog.file + "";
            if (selectedFilePath) {
                var newPath = findBooksFolder(selectedFilePath, "books");
                if (newPath) {
                    questionVideoField.text = newPath;
                    if (selectorQuestion) {
                        selectorQuestion.video = newPath;
                    }
                } else {
                    questionVideoField.text = selectedFilePath;
                    if (selectorQuestion) {
                        selectorQuestion.video = selectedFilePath;
                    }
                }
            }
        }
    }

    // FileDialog for option image
    FileDialog {
        id: optionImageDialog
        title: "Select Option Image"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.gif *.bmp)"]
        property int currentOptionIndex: -1
        onAccepted: {
            var selectedFilePath = optionImageDialog.file + "";
            if (selectedFilePath && currentOptionIndex >= 0 && selectorQuestion.answers && currentOptionIndex < selectorQuestion.answers.length) {
                var newPath = findBooksFolder(selectedFilePath, "books");
                var finalPath = newPath || selectedFilePath;
                selectorQuestion.answers[currentOptionIndex].image = finalPath;
                console.log("Option", currentOptionIndex + 1, "image set to:", finalPath);
            }
        }
    }

    ColumnLayout {
        id: totalColumn
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // Header Row
        RowLayout {
            id: headerRow
            Layout.fillWidth: true
            Layout.preferredHeight: 30

            Text {
                text: "Selector Question #" + questionId
                color: "#009ca6"
                font.pixelSize: 18
                font.bold: true
                Layout.fillWidth: true
            }

            Rectangle {
                id: deleteQuestionBtn
                width: 28
                height: 28
                radius: 14
                color: "#d2232b"

                Text {
                    text: "×"
                    anchors.centerIn: parent
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        print("deleting Selector Question");
                        questionDeleted();
                    }
                }
            }
        }

        // Question Media Section
        Rectangle {
            id: questionMediaSection
            Layout.fillWidth: true
            Layout.preferredHeight: mediaColumn.implicitHeight + 20
            color: "#232f34"
            border.color: "#009ca6"
            border.width: 1
            radius: 6

            ColumnLayout {
                id: mediaColumn
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                Text {
                    text: "Question Media"
                    color: "#009ca6"
                    font.pixelSize: 14
                    font.bold: true
                }

                // Text Question Row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    spacing: 8

                    Text {
                        text: "Text:"
                        Layout.preferredWidth: 50
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        verticalAlignment: Text.AlignVCenter
                    }

                    TextField {
                        id: questionTextField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        text: selectorQuestion && selectorQuestion.question ? selectorQuestion.question : ""
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        placeholderText: "Enter question text..."
                        placeholderTextColor: "#666666"
                        background: Rectangle {
                            color: "#1A2327"
                            border.color: questionTextField.focus ? "#009ca6" : "#445055"
                            border.width: 1
                            radius: 3
                        }
                        onTextChanged: {
                            if (selectorQuestion) {
                                selectorQuestion.question = text;
                            }
                        }
                    }
                }

                // Image Row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    spacing: 8

                    Text {
                        text: "Image:"
                        Layout.preferredWidth: 50
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        verticalAlignment: Text.AlignVCenter
                    }

                    TextField {
                        id: questionImageField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        text: selectorQuestion && selectorQuestion.image ? selectorQuestion.image : ""
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        placeholderText: "Select image..."
                        placeholderTextColor: "#666666"
                        background: Rectangle {
                            color: "#1A2327"
                            border.color: questionImageField.focus ? "#009ca6" : "#445055"
                            border.width: 1
                            radius: 3
                        }
                        onTextChanged: {
                            if (selectorQuestion) {
                                selectorQuestion.image = text;
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 35
                        Layout.preferredHeight: 28
                        color: "#009ca6"
                        radius: 3
                        Text {
                            anchors.centerIn: parent
                            text: "..."
                            color: "white"
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: questionImageDialog.open()
                        }
                    }
                }

                // Audio Row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    spacing: 8

                    Text {
                        text: "Audio:"
                        Layout.preferredWidth: 50
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        verticalAlignment: Text.AlignVCenter
                    }

                    TextField {
                        id: questionAudioField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        text: selectorQuestion && selectorQuestion.audio ? selectorQuestion.audio : ""
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        placeholderText: "Select audio..."
                        placeholderTextColor: "#666666"
                        background: Rectangle {
                            color: "#1A2327"
                            border.color: questionAudioField.focus ? "#009ca6" : "#445055"
                            border.width: 1
                            radius: 3
                        }
                        onTextChanged: {
                            if (selectorQuestion) {
                                selectorQuestion.audio = text;
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 35
                        Layout.preferredHeight: 28
                        color: "#009ca6"
                        radius: 3
                        Text {
                            anchors.centerIn: parent
                            text: "..."
                            color: "white"
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: questionAudioDialog.open()
                        }
                    }
                }

                // Video Row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    spacing: 8

                    Text {
                        text: "Video:"
                        Layout.preferredWidth: 50
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        verticalAlignment: Text.AlignVCenter
                    }

                    TextField {
                        id: questionVideoField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 28
                        text: selectorQuestion && selectorQuestion.video ? selectorQuestion.video : ""
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        placeholderText: "Select video..."
                        placeholderTextColor: "#666666"
                        background: Rectangle {
                            color: "#1A2327"
                            border.color: questionVideoField.focus ? "#009ca6" : "#445055"
                            border.width: 1
                            radius: 3
                        }
                        onTextChanged: {
                            if (selectorQuestion) {
                                selectorQuestion.video = text;
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 35
                        Layout.preferredHeight: 28
                        color: "#009ca6"
                        radius: 3
                        Text {
                            anchors.centerIn: parent
                            text: "..."
                            color: "white"
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: questionVideoDialog.open()
                        }
                    }
                }
            }
        }

        // Options Section
        Rectangle {
            id: optionsSection
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#232f34"
            border.color: "#009ca6"
            border.width: 1
            radius: 6

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 25

                    Text {
                        text: "Answer Options (" + (selectorQuestion.answers ? selectorQuestion.answers.length : 0) + ")"
                        color: "#009ca6"
                        font.pixelSize: 14
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 25
                        color: {
                            let optionCount = selectorQuestion && selectorQuestion.answers ? selectorQuestion.answers.length : 0;
                            return optionCount >= 5 ? "#666666" : "#009ca6";
                        }
                        opacity: {
                            let optionCount = selectorQuestion && selectorQuestion.answers ? selectorQuestion.answers.length : 0;
                            return optionCount >= 5 ? 0.5 : 1.0;
                        }
                        radius: 4
                        Text {
                            anchors.centerIn: parent
                            text: "Add Option"
                            color: "white"
                            font.pixelSize: 12
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                let optionCount = selectorQuestion && selectorQuestion.answers ? selectorQuestion.answers.length : 0;
                                if (optionCount < 5) {
                                    optionAdded();
                                } else {
                                    console.log("Maximum 5 options allowed");
                                }
                            }
                        }
                    }
                }

                // Options list
                ListView {
                    id: optionsListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 4
                    model: selectorQuestion && selectorQuestion.answers ? selectorQuestion.answers : []

                    delegate: Rectangle {
                        width: optionsListView.width
                        height: 35
                        color: "#1A2327"
                        border.color: "#445055"
                        border.width: 1
                        radius: 4

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 6

                            // Option number
                            Text {
                                text: index + 1
                                Layout.preferredWidth: 20
                                color: "#009ca6"
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            // Correct checkbox
                            Rectangle {
                                Layout.preferredWidth: 22
                                Layout.preferredHeight: 22
                                radius: 4
                                color: "white"
                                border.color: "#009ca6"
                                border.width: 2

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        if (modelData) {
                                            modelData.isCorrect = !modelData.isCorrect;
                                        }
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData && modelData.isCorrect ? "✓" : ""
                                    color: "#009ca6"
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                            }

                            // Text field
                            TextField {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 26
                                text: modelData && modelData.text ? modelData.text : ""
                                color: "#FFFFFF"
                                font.pixelSize: 11
                                placeholderText: "Option text..."
                                placeholderTextColor: "#666666"
                                background: Rectangle {
                                    color: "#232f34"
                                    border.color: parent.focus ? "#009ca6" : "#445055"
                                    border.width: 1
                                    radius: 3
                                }
                                onTextChanged: {
                                    if (modelData) {
                                        modelData.text = text;
                                    }
                                }
                            }

                            // Image field
                            TextField {
                                Layout.preferredWidth: parent.width * 0.25
                                Layout.preferredHeight: 26
                                text: modelData && modelData.image ? modelData.image : ""
                                color: "#FFFFFF"
                                font.pixelSize: 11
                                placeholderText: "Image..."
                                placeholderTextColor: "#666666"
                                readOnly: true
                                background: Rectangle {
                                    color: "#232f34"
                                    border.color: parent.focus ? "#009ca6" : "#445055"
                                    border.width: 1
                                    radius: 3
                                }
                            }

                            // Image select button
                            Rectangle {
                                Layout.preferredWidth: 25
                                Layout.preferredHeight: 25
                                color: "#009ca6"
                                radius: 3
                                Text {
                                    anchors.centerIn: parent
                                    text: "..."
                                    color: "white"
                                    font.bold: true
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        optionImageDialog.currentOptionIndex = index;
                                        optionImageDialog.open();
                                    }
                                }
                            }

                            // Delete button
                            Rectangle {
                                Layout.preferredWidth: 25
                                Layout.preferredHeight: 25
                                radius: 12
                                color: {
                                    let optionCount = selectorQuestion && selectorQuestion.answers ? selectorQuestion.answers.length : 0;
                                    return optionCount <= 2 ? "#666666" : "#d2232b";
                                }
                                opacity: {
                                    let optionCount = selectorQuestion && selectorQuestion.answers ? selectorQuestion.answers.length : 0;
                                    return optionCount <= 2 ? 0.5 : 1.0;
                                }

                                Text {
                                    text: "×"
                                    anchors.centerIn: parent
                                    color: "white"
                                    font.pixelSize: 14
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        let optionCount = selectorQuestion && selectorQuestion.answers ? selectorQuestion.answers.length : 0;
                                        if (optionCount > 2) {
                                            optionDeleted(index);
                                        } else {
                                            console.log("Minimum 2 options required");
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
