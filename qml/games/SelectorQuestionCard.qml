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

    property int questionId: 0

    signal questionDeleted
    signal optionAdded
    signal optionDeleted(int index)

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

    width: parent.width
    height: parent.height
    radius: 8
    color: "#1A2327"
    border.color: "#009ca6"
    border.width: 1

    // Row height calculated based on available space
    property real rowHeight: Math.max(24, root.height * 0.055)
    property real fontSize: Math.max(10, root.height * 0.028)

    // FileDialogs
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
                    if (selectorQuestion) selectorQuestion.image = newPath;
                } else {
                    questionImageField.text = selectedFilePath;
                    if (selectorQuestion) selectorQuestion.image = selectedFilePath;
                }
            }
        }
    }

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
                    if (selectorQuestion) selectorQuestion.audio = newPath;
                } else {
                    questionAudioField.text = selectedFilePath;
                    if (selectorQuestion) selectorQuestion.audio = selectedFilePath;
                }
            }
        }
    }

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
                    if (selectorQuestion) selectorQuestion.video = newPath;
                } else {
                    questionVideoField.text = selectedFilePath;
                    if (selectorQuestion) selectorQuestion.video = selectedFilePath;
                }
            }
        }
    }

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
            }
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        // Header Row - 8%
        Row {
            width: parent.width
            height: root.height * 0.07

            Text {
                text: "Selector Question #" + questionId
                width: parent.width - 35
                height: parent.height
                color: "#009ca6"
                font.pixelSize: Math.max(14, root.height * 0.04)
                font.bold: true
                verticalAlignment: Text.AlignVCenter
            }

            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: "#d2232b"
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: "×"
                    anchors.centerIn: parent
                    color: "white"
                    font.pixelSize: 16
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: questionDeleted()
                }
            }
        }

        // Question Media Section
        Rectangle {
            width: parent.width
            height: root.height * 0.30
            color: "#232f34"
            border.color: "#009ca6"
            border.width: 1
            radius: 6
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 2

                // Header
                Text {
                    text: "Question Media"
                    color: "#009ca6"
                    font.pixelSize: fontSize
                    font.bold: true
                    Layout.preferredHeight: 16
                }

                // Text field row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    Text {
                        text: "Text:"
                        Layout.preferredWidth: 40
                        color: "#FFFFFF"
                        font.pixelSize: fontSize
                        verticalAlignment: Text.AlignVCenter
                    }

                    TextField {
                        id: questionTextField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: selectorQuestion && selectorQuestion.question ? selectorQuestion.question : ""
                        color: "#FFFFFF"
                        font.pixelSize: fontSize
                        placeholderText: "Enter question text..."
                        placeholderTextColor: "#666666"
                        background: Rectangle {
                            color: "#1A2327"
                            border.color: questionTextField.focus ? "#009ca6" : "#445055"
                            border.width: 1
                            radius: 3
                        }
                        onTextChanged: {
                            if (selectorQuestion) selectorQuestion.question = text;
                        }
                    }
                }

                // Image and Audio in same row (2 columns)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8

                    // Image field group
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 4

                        Text {
                            text: "Image:"
                            Layout.preferredWidth: 40
                            color: "#FFFFFF"
                            font.pixelSize: fontSize
                            verticalAlignment: Text.AlignVCenter
                        }

                        TextField {
                            id: questionImageField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: selectorQuestion && selectorQuestion.image ? selectorQuestion.image : ""
                            color: "#FFFFFF"
                            font.pixelSize: fontSize
                            placeholderText: "Select..."
                            placeholderTextColor: "#666666"
                            background: Rectangle {
                                color: "#1A2327"
                                border.color: questionImageField.focus ? "#009ca6" : "#445055"
                                border.width: 1
                                radius: 3
                            }
                            onTextChanged: {
                                if (selectorQuestion) selectorQuestion.image = text;
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.fillHeight: true
                            Layout.maximumHeight: 28
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

                    // Audio field group
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 4

                        Text {
                            text: "Audio:"
                            Layout.preferredWidth: 40
                            color: "#FFFFFF"
                            font.pixelSize: fontSize
                            verticalAlignment: Text.AlignVCenter
                        }

                        TextField {
                            id: questionAudioField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: selectorQuestion && selectorQuestion.audio ? selectorQuestion.audio : ""
                            color: "#FFFFFF"
                            font.pixelSize: fontSize
                            placeholderText: "Select..."
                            placeholderTextColor: "#666666"
                            background: Rectangle {
                                color: "#1A2327"
                                border.color: questionAudioField.focus ? "#009ca6" : "#445055"
                                border.width: 1
                                radius: 3
                            }
                            onTextChanged: {
                                if (selectorQuestion) selectorQuestion.audio = text;
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.fillHeight: true
                            Layout.maximumHeight: 28
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
                }

                // Video field row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 4

                    Text {
                        text: "Video:"
                        Layout.preferredWidth: 40
                        color: "#FFFFFF"
                        font.pixelSize: fontSize
                        verticalAlignment: Text.AlignVCenter
                    }

                    TextField {
                        id: questionVideoField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: selectorQuestion && selectorQuestion.video ? selectorQuestion.video : ""
                        color: "#FFFFFF"
                        font.pixelSize: fontSize
                        placeholderText: "Select..."
                        placeholderTextColor: "#666666"
                        background: Rectangle {
                            color: "#1A2327"
                            border.color: questionVideoField.focus ? "#009ca6" : "#445055"
                            border.width: 1
                            radius: 3
                        }
                        onTextChanged: {
                            if (selectorQuestion) selectorQuestion.video = text;
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.fillHeight: true
                        Layout.maximumHeight: 28
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

        // Options Section - 56%
        Rectangle {
            id: optionsSection
            width: parent.width
            height: root.height * 0.56
            color: "#232f34"
            border.color: "#009ca6"
            border.width: 1
            radius: 6
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 4

                // Header row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 22

                    Text {
                        text: "Answer Options (" + (selectorQuestion.answers ? selectorQuestion.answers.length : 0) + ")"
                        color: "#009ca6"
                        font.pixelSize: fontSize
                        font.bold: true
                        Layout.fillWidth: true
                        verticalAlignment: Text.AlignVCenter
                    }

                    Rectangle {
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 20
                        color: {
                            let count = selectorQuestion && selectorQuestion.answers ? selectorQuestion.answers.length : 0;
                            return count >= 5 ? "#666666" : "#009ca6";
                        }
                        opacity: {
                            let count = selectorQuestion && selectorQuestion.answers ? selectorQuestion.answers.length : 0;
                            return count >= 5 ? 0.5 : 1.0;
                        }
                        radius: 4
                        Text {
                            anchors.centerIn: parent
                            text: "Add Option"
                            color: "white"
                            font.pixelSize: fontSize * 0.9
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                let count = selectorQuestion && selectorQuestion.answers ? selectorQuestion.answers.length : 0;
                                if (count < 5) optionAdded();
                            }
                        }
                    }
                }

                // Options grid
                GridLayout {
                    id: optionsGrid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 2
                    rowSpacing: 3
                    columnSpacing: 4

                    Repeater {
                        model: selectorQuestion && selectorQuestion.answers ? selectorQuestion.answers : []

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.minimumHeight: 26
                            color: "#1A2327"
                            border.color: "#445055"
                            border.width: 1
                            radius: 4

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 3
                                spacing: 3

                                // Option number
                                Text {
                                    text: index + 1
                                    Layout.preferredWidth: 14
                                    color: "#009ca6"
                                    font.bold: true
                                    font.pixelSize: fontSize * 0.9
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                // Correct checkbox
                                Rectangle {
                                    Layout.preferredWidth: 18
                                    Layout.preferredHeight: 18
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 3
                                    color: "white"
                                    border.color: "#009ca6"
                                    border.width: 2

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (modelData) modelData.isCorrect = !modelData.isCorrect;
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData && modelData.isCorrect ? "✓" : ""
                                        color: "#009ca6"
                                        font.pixelSize: parent.height * 0.7
                                        font.bold: true
                                    }
                                }

                                // Text field
                                TextField {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 100
                                    text: modelData && modelData.text ? modelData.text : ""
                                    color: "#FFFFFF"
                                    font.pixelSize: fontSize * 0.85
                                    placeholderText: "Text..."
                                    placeholderTextColor: "#666666"
                                    background: Rectangle {
                                        color: "#232f34"
                                        border.color: parent.focus ? "#009ca6" : "#445055"
                                        border.width: 1
                                        radius: 3
                                    }
                                    onTextChanged: {
                                        if (modelData) modelData.text = text;
                                    }
                                }

                                // Image field
                                TextField {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: 100
                                    text: modelData && modelData.image ? modelData.image : ""
                                    color: "#FFFFFF"
                                    font.pixelSize: fontSize * 0.85
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
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 22
                                    Layout.alignment: Qt.AlignVCenter
                                    color: "#009ca6"
                                    radius: 3
                                    Text {
                                        anchors.centerIn: parent
                                        text: "..."
                                        color: "white"
                                        font.bold: true
                                        font.pixelSize: 10
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
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 22
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 11
                                    color: {
                                        let count = selectorQuestion && selectorQuestion.answers ? selectorQuestion.answers.length : 0;
                                        return count <= 2 ? "#666666" : "#d2232b";
                                    }
                                    opacity: {
                                        let count = selectorQuestion && selectorQuestion.answers ? selectorQuestion.answers.length : 0;
                                        return count <= 2 ? 0.5 : 1.0;
                                    }

                                    Text {
                                        text: "×"
                                        anchors.centerIn: parent
                                        color: "white"
                                        font.pixelSize: parent.height * 0.6
                                        font.bold: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            let count = selectorQuestion && selectorQuestion.answers ? selectorQuestion.answers.length : 0;
                                            if (count > 2) optionDeleted(index);
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
