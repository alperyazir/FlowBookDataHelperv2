import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import Qt.labs.platform
import ".."

Rectangle {
    id: root

    property var builderQuestion: ({
            "question": "",
            "image": "",
            "audio": "",
            "video": "",
            "words": []
        })

    // Add question ID property
    property int questionId: 0

    // Signals for external communication
    signal questionDeleted

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

    // Function to split sentence into words
    function splitSentenceIntoWords(sentence) {
        if (!sentence || sentence.trim() === "") {
            return [];
        }
        return sentence.trim().split(/\s+/);
    }

    Component.onCompleted: {
        console.log("Builder question loaded. Words count:", builderQuestion.words ? builderQuestion.words.length : 0);
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
                    if (builderQuestion) {
                        builderQuestion.image = newPath;
                    }
                } else {
                    questionImageField.text = selectedFilePath;
                    if (builderQuestion) {
                        builderQuestion.image = selectedFilePath;
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
                    if (builderQuestion) {
                        builderQuestion.audio = newPath;
                    }
                } else {
                    questionAudioField.text = selectedFilePath;
                    if (builderQuestion) {
                        builderQuestion.audio = selectedFilePath;
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
                    if (builderQuestion) {
                        builderQuestion.video = newPath;
                    }
                } else {
                    questionVideoField.text = selectedFilePath;
                    if (builderQuestion) {
                        builderQuestion.video = selectedFilePath;
                    }
                }
            }
        }
    }

    Column {
        id: totalColumn
        width: parent.width
        height: parent.height
        spacing: 8

        // Header Row
        Row {
            id: headerRow
            width: parent.width
            height: parent.height * 0.08

            Text {
                text: "Builder Question #" + questionId
                width: parent.width / 4
                height: parent.height
                color: "#009ca6"
                font.pixelSize: root.height * 0.06
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
                        print("deleting Builder Question");
                        questionDeleted();
                    }
                }
            }
        }

        // Question Text Section
        Rectangle {
            id: questionTextSection
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
                    font.pixelSize: root.height * 0.035
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }

                TextField {
                    id: questionTextField
                    width: parent.width - 80 - 10
                    height: parent.height
                    text: builderQuestion && builderQuestion.question ? builderQuestion.question : ""
                    color: "#FFFFFF"
                    font.pixelSize: root.height * 0.025
                    placeholderText: "Enter question text..."
                    placeholderTextColor: "#666666"
                    background: Rectangle {
                        color: "#1A2327"
                        border.color: questionTextField.focus ? "#009ca6" : "#445055"
                        border.width: 1
                        radius: 3
                    }
                    onTextChanged: {
                        if (builderQuestion) {
                            builderQuestion.question = text;
                        }
                    }
                }
            }
        }

        // Question Media Section
        Rectangle {
            id: questionMediaSection
            width: parent.width
            height: parent.height * 0.27  // Increased from 0.2 to 0.25
            color: "#232f34"
            border.color: "#009ca6"
            border.width: 1
            radius: 6

            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 3 // Increased from 4 to 6

                Text {
                    text: "Question Media"
                    color: "#009ca6"
                    font.pixelSize: root.height * 0.035
                    font.bold: true
                }

                // Image Row
                Row {
                    width: parent.width
                    height: parent.height * 0.25  // Increased from 0.22 to 0.25
                    spacing: 5

                    Text {
                        text: "Image:"
                        width: 60
                        height: parent.height
                        color: "#FFFFFF"
                        font.pixelSize: root.height * 0.025
                        verticalAlignment: Text.AlignVCenter
                    }

                    TextField {
                        id: questionImageField
                        width: parent.width - 60 - 30 - 10
                        height: parent.height
                        text: builderQuestion && builderQuestion.image ? builderQuestion.image : ""
                        color: "#FFFFFF"
                        font.pixelSize: root.height * 0.025
                        placeholderText: "Select image..."
                        placeholderTextColor: "#666666"
                        background: Rectangle {
                            color: "#1A2327"
                            border.color: questionImageField.focus ? "#009ca6" : "#445055"
                            border.width: 1
                            radius: 3
                        }
                        onTextChanged: {
                            if (builderQuestion) {
                                builderQuestion.image = text;
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
                            onClicked: questionImageDialog.open()
                        }
                    }
                }

                // Audio Row
                Row {
                    width: parent.width
                    height: parent.height * 0.25  // Increased from 0.22 to 0.25
                    spacing: 5

                    Text {
                        text: "Audio:"
                        width: 60
                        height: parent.height
                        color: "#FFFFFF"
                        font.pixelSize: root.height * 0.025
                        verticalAlignment: Text.AlignVCenter
                    }

                    TextField {
                        id: questionAudioField
                        width: parent.width - 60 - 30 - 10
                        height: parent.height
                        text: builderQuestion && builderQuestion.audio ? builderQuestion.audio : ""
                        color: "#FFFFFF"
                        font.pixelSize: root.height * 0.025
                        placeholderText: "Select audio..."
                        placeholderTextColor: "#666666"
                        background: Rectangle {
                            color: "#1A2327"
                            border.color: questionAudioField.focus ? "#009ca6" : "#445055"
                            border.width: 1
                            radius: 3
                        }
                        onTextChanged: {
                            if (builderQuestion) {
                                builderQuestion.audio = text;
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
                            onClicked: questionAudioDialog.open()
                        }
                    }
                }

                // Video Row
                Row {
                    width: parent.width
                    height: parent.height * 0.25  // Increased from 0.22 to 0.25
                    spacing: 5

                    Text {
                        text: "Video:"
                        width: 60
                        height: parent.height
                        color: "#FFFFFF"
                        font.pixelSize: root.height * 0.025
                        verticalAlignment: Text.AlignVCenter
                    }

                    TextField {
                        id: questionVideoField
                        width: parent.width - 60 - 30 - 10
                        height: parent.height
                        text: builderQuestion && builderQuestion.video ? builderQuestion.video : ""
                        color: "#FFFFFF"
                        font.pixelSize: root.height * 0.025
                        placeholderText: "Select video..."
                        placeholderTextColor: "#666666"
                        background: Rectangle {
                            color: "#1A2327"
                            border.color: questionVideoField.focus ? "#009ca6" : "#445055"
                            border.width: 1
                            radius: 3
                        }
                        onTextChanged: {
                            if (builderQuestion) {
                                builderQuestion.video = text;
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
                            onClicked: questionVideoDialog.open()
                        }
                    }
                }
            }
        }

        // Words Input Section
        Rectangle {
            id: wordsInputSection
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
                    text: "Words:"
                    width: 80
                    height: parent.height
                    color: "#009ca6"
                    font.pixelSize: root.height * 0.035
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }

                TextField {
                    id: wordsTextField
                    width: parent.width - 80 - 10
                    height: parent.height
                    color: "#FFFFFF"
                    font.pixelSize: root.height * 0.025
                    placeholderText: "Enter words separated by spaces for building sentence..."
                    placeholderTextColor: "#666666"
                    background: Rectangle {
                        color: "#1A2327"
                        border.color: wordsTextField.focus ? "#009ca6" : "#445055"
                        border.width: 1
                        radius: 3
                    }

                    // Only update on focus lost or Enter key
                    onEditingFinished: {
                        if (builderQuestion) {
                            let words = splitSentenceIntoWords(text);
                            builderQuestion.words = words;
                            console.log("Words finalized. Words:", words);
                        }
                    }

                    // Initialize text from builderQuestion
                    Component.onCompleted: {
                        if (builderQuestion && builderQuestion.words) {
                            text = builderQuestion.words.join(" ");
                        }
                    }
                }
            }
        }

        // Words Preview Section
        Rectangle {
            id: wordsPreviewSection
            width: parent.width
            height: parent.height * 0.27  // Reduced from 0.32 to 0.27
            color: "#232f34"
            border.color: "#009ca6"
            border.width: 1
            radius: 6

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4

                Text {
                    text: "Words Preview (" + (builderQuestion.words ? builderQuestion.words.length : 0) + " words)"
                    color: "#009ca6"
                    font.pixelSize: root.height * 0.035
                    font.bold: true
                }

                Rectangle {
                    id: wordsPreviewArea
                    width: parent.width
                    height: parent.height - 35
                    color: "#1A2327"
                    border.color: "#445055"
                    border.width: 1
                    radius: 4

                    Flow {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Repeater {
                            model: builderQuestion && builderQuestion.words ? builderQuestion.words : []

                            Rectangle {
                                width: wordText.width + 20
                                height: 30
                                color: "#009ca6"
                                radius: 4
                                border.color: "#007a80"
                                border.width: 1

                                Text {
                                    id: wordText
                                    text: (index + 1) + ". " + modelData
                                    anchors.centerIn: parent
                                    color: "white"
                                    font.pixelSize: root.height * 0.025
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
