import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import Qt.labs.platform
import ".."

Rectangle {
    id: root

    property var raceQuestion: ({
            "question": "",
            "image": "",
            "audio": "",
            "answers": []
        })

    // Add question ID property
    property int questionId: 0

    // Signals for external communication
    signal questionDeleted
    signal optionAdded
    signal optionDeleted(int index)

    // Function to find books folder
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
        console.log("Race question loaded:", raceQuestion.question);
        console.log("Number of answers:", raceQuestion.answers ? raceQuestion.answers.length : 0);
    }

    width: parent.width
    height: parent.height
    radius: 8
    color: "#1A2327"
    border.color: "#009ca6"
    border.width: 1

    // FileDialog for question image
    FileDialog {
        id: imageFileDialog
        title: "Select Question Image"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.gif *.bmp)"]
        onAccepted: {
            var selectedFilePath = imageFileDialog.file + "";
            if (selectedFilePath) {
                var newPath = findBooksFolder(selectedFilePath, "books");
                if (newPath) {
                    imageTextField.text = newPath;
                    if (raceQuestion) {
                        raceQuestion.image = newPath;
                    }
                } else {
                    imageTextField.text = selectedFilePath;
                    if (raceQuestion) {
                        raceQuestion.image = selectedFilePath;
                    }
                }
            }
        }
    }

    // FileDialog for question audio
    FileDialog {
        id: audioFileDialog
        title: "Select Question Audio"
        nameFilters: ["Audio files (*.mp3 *.wav *.ogg)"]
        onAccepted: {
            var selectedFilePath = audioFileDialog.file + "";
            if (selectedFilePath) {
                var newPath = findBooksFolder(selectedFilePath, "books");
                if (newPath) {
                    audioTextField.text = newPath;
                    if (raceQuestion) {
                        raceQuestion.audio = newPath;
                    }
                } else {
                    audioTextField.text = selectedFilePath;
                    if (raceQuestion) {
                        raceQuestion.audio = selectedFilePath;
                    }
                }
            }
        }
    }

    Column {
        id: totalColumn
        width: parent.width
        height: parent.height
        spacing: 6

        // Header Row
        Row {
            id: headerRow
            width: parent.width
            height: parent.height * 0.1

            Text {
                text: "Race Question #" + questionId
                width: parent.width / 4
                height: parent.height
                color: "#009ca6"
                font.pixelSize: root.height * 0.08
                font.bold: true
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignLeft
            }

            Item {
                width: parent.width / 4 * 3
                height: parent.height
            }

            Rectangle {
                id: deleteQuestionBtn
                width: 28
                height: 28
                radius: 14
                color: "#d2232b"
                anchors.verticalCenter: parent.verticalCenter

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
                        print("deleting Race Question");
                        questionDeleted();
                    }
                }
            }
        }

        // Question Input Section
        Rectangle {
            id: questionInputSection
            width: parent.width
            height: parent.height * 0.15
            color: "#232f34"
            border.color: "#009ca6"
            border.width: 1
            radius: 6

            Row {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                Text {
                    text: "Question:"
                    width: 80
                    height: parent.height
                    color: "#009ca6"
                    font.pixelSize: root.height * 0.05
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }

                TextField {
                    id: questionTextField
                    width: parent.width - 80 - 10
                    height: parent.height
                    text: raceQuestion && raceQuestion.question ? raceQuestion.question : ""
                    color: "#FFFFFF"
                    font.pixelSize: root.height * 0.04
                    placeholderText: "Enter race question text..."
                    placeholderTextColor: "#666666"
                    background: Rectangle {
                        color: "#1A2327"
                        border.color: questionTextField.focus ? "#009ca6" : "#445055"
                        border.width: 1
                        radius: 3
                    }
                    onTextChanged: {
                        if (raceQuestion) {
                            raceQuestion.question = text;
                        }
                    }
                }
            }
        }

        // Image Row
        Row {
            width: parent.width
            height: parent.height * 0.08
            spacing: 5

            Text {
                text: "Image:"
                width: 60
                height: parent.height
                color: "#FFFFFF"
                font.pixelSize: root.height * 0.04
                verticalAlignment: Text.AlignVCenter
            }

            TextField {
                id: imageTextField
                width: parent.width - 60 - 30 - 10
                height: parent.height
                text: raceQuestion && raceQuestion.image ? raceQuestion.image : ""
                color: "#FFFFFF"
                font.pixelSize: root.height * 0.03
                placeholderText: "Select image..."
                placeholderTextColor: "#666666"
                background: Rectangle {
                    color: "#1A2327"
                    border.color: imageTextField.focus ? "#009ca6" : "#445055"
                    border.width: 1
                    radius: 3
                }
                onTextChanged: {
                    if (raceQuestion) {
                        raceQuestion.image = text;
                    }
                }
            }

            Rectangle {
                width: 30
                height: parent.height
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
                    onClicked: imageFileDialog.open()
                }
            }
        }

        // Audio Row
        Row {
            width: parent.width
            height: parent.height * 0.08
            spacing: 5

            Text {
                text: "Audio:"
                width: 60
                height: parent.height
                color: "#FFFFFF"
                font.pixelSize: root.height * 0.04
                verticalAlignment: Text.AlignVCenter
            }

            TextField {
                id: audioTextField
                width: parent.width - 60 - 30 - 10
                height: parent.height
                text: raceQuestion && raceQuestion.audio ? raceQuestion.audio : ""
                color: "#FFFFFF"
                font.pixelSize: root.height * 0.03
                placeholderText: "Select audio..."
                placeholderTextColor: "#666666"
                background: Rectangle {
                    color: "#1A2327"
                    border.color: audioTextField.focus ? "#009ca6" : "#445055"
                    border.width: 1
                    radius: 3
                }
                onTextChanged: {
                    if (raceQuestion) {
                        raceQuestion.audio = text;
                    }
                }
            }

            Rectangle {
                width: 30
                height: parent.height
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
                    onClicked: audioFileDialog.open()
                }
            }
        }

        // Fixed Options Area (4 options only)
        Column {
            id: optionsColumn
            width: parent.width
            height: parent.height * 0.53
            spacing: 6

            // Options Header
            Row {
                width: parent.width
                height: 30

                Text {
                    text: "Answer Options (4)"
                    color: "#009ca6"
                    font.pixelSize: root.height * 0.04
                    font.bold: true
                    width: parent.width
                }
            }

            // Fixed 4 Options
            Repeater {
                id: optionRepeater
                model: 4  // Fixed 4 options

                Row {
                    id: optionRow
                    width: optionsColumn.width
                    height: root.height * 0.08
                    spacing: 10

                    Text {
                        text: "Option " + (index + 1)
                        width: parent.width / 7
                        height: parent.height
                        color: "#FFFFFF"
                        font.pixelSize: root.height * 0.04
                        verticalAlignment: Text.AlignVCenter
                    }

                    // Correct checkbox
                    Rectangle {
                        width: 22
                        height: 22
                        radius: 4
                        color: "white"
                        border.color: "#009ca6"
                        border.width: 2
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (raceQuestion.answers && raceQuestion.answers[index]) {
                                    raceQuestion.answers[index].isCorrect = !raceQuestion.answers[index].isCorrect;
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (!raceQuestion.answers || !raceQuestion.answers[index])
                                    return "";
                                return raceQuestion.answers[index].isCorrect ? "✓" : "";
                            }
                            color: "#009ca6"
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }

                    TextField {
                        width: parent.width / 7 * 3
                        height: parent.height
                        text: {
                            if (!raceQuestion.answers || !raceQuestion.answers[index])
                                return "";
                            return raceQuestion.answers[index].text || "";
                        }
                        color: "#FFFFFF"
                        font.pixelSize: root.height * 0.04
                        placeholderText: "Option " + (index + 1) + " text"
                        placeholderTextColor: "#666666"
                        background: Rectangle {
                            color: "#232f34"
                            border.color: parent.focus ? "#009ca6" : "#445055"
                            border.width: 1
                            radius: 3
                        }
                        onTextChanged: {
                            if (raceQuestion.answers && raceQuestion.answers[index]) {
                                raceQuestion.answers[index].text = text;
                            }
                        }
                    }

                    // Image field for option
                    TextField {
                        width: parent.width / 7 * 2
                        height: parent.height
                        text: {
                            if (!raceQuestion.answers || !raceQuestion.answers[index])
                                return "";
                            return raceQuestion.answers[index].image || "";
                        }
                        color: "#FFFFFF"
                        font.pixelSize: root.height * 0.04
                        placeholderText: "Option image"
                        placeholderTextColor: "#666666"
                        background: Rectangle {
                            color: "#232f34"
                            border.color: parent.focus ? "#009ca6" : "#445055"
                            border.width: 1
                            radius: 3
                        }
                        onTextChanged: {
                            if (raceQuestion.answers && raceQuestion.answers[index]) {
                                raceQuestion.answers[index].image = text;
                            }
                        }
                    }

                    // File dialog button for option image
                    Rectangle {
                        width: 30
                        height: parent.height
                        color: "#009ca6"
                        radius: 3
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "..."
                            color: "white"
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                // Create dynamic FileDialog for this option
                                var optionImageDialog = Qt.createQmlObject('import QtQuick.Dialogs; import Qt.labs.platform; FileDialog { title: "Select Option ' + (index + 1) + ' Image"; nameFilters: ["Image files (*.png *.jpg *.jpeg *.gif *.bmp)"] }', parent);

                                optionImageDialog.accepted.connect(function () {
                                    var selectedFilePath = optionImageDialog.file + "";
                                    if (selectedFilePath) {
                                        var newPath = findBooksFolder(selectedFilePath, "books");
                                        if (newPath) {
                                            // Update the text field
                                            parent.parent.children[3].text = newPath;
                                            // Update the data
                                            if (raceQuestion.answers && raceQuestion.answers[index]) {
                                                raceQuestion.answers[index].image = newPath;
                                            }
                                        } else {
                                            parent.parent.children[3].text = selectedFilePath;
                                            if (raceQuestion.answers && raceQuestion.answers[index]) {
                                                raceQuestion.answers[index].image = selectedFilePath;
                                            }
                                        }
                                    }
                                });

                                optionImageDialog.open();
                            }
                        }
                    }
                }
            }
        }
    }
}
