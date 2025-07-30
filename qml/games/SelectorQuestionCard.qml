import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import Qt.labs.platform
import ".."

Rectangle {
    id: root

    property var selectorQuestion: ({
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
                text: "Selector Question #" + questionId
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
                        print("deleting Selector Question");
                        questionDeleted();
                    }
                }
            }
        }

        // Question Media Section
        Rectangle {
            id: questionMediaSection
            width: parent.width
            height: parent.height * 0.25  // Increased from 0.2 to 0.25
            color: "#232f34"
            border.color: "#009ca6"
            border.width: 1
            radius: 6

            Column {
                anchors.fill: parent
                anchors.margins: 8  // Reduced from 10 to 8
                spacing: 4  // Reduced from 8 to 4

                Text {
                    text: "Question Media"
                    color: "#009ca6"
                    font.pixelSize: root.height * 0.035  // Reduced from 0.04
                    font.bold: true
                }

                // Image Row
                Row {
                    width: parent.width
                    height: parent.height * 0.22  // Reduced from 0.25 to 0.22
                    spacing: 5

                    Text {
                        text: "Image:"
                        width: 60
                        height: parent.height
                        color: "#FFFFFF"
                        font.pixelSize: root.height * 0.025  // Reduced from 0.03
                        verticalAlignment: Text.AlignVCenter
                    }

                    TextField {
                        id: questionImageField
                        width: parent.width - 60 - 30 - 10
                        height: parent.height
                        text: selectorQuestion && selectorQuestion.image ? selectorQuestion.image : ""
                        color: "#FFFFFF"
                        font.pixelSize: root.height * 0.025  // Reduced from 0.03
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
                    height: parent.height * 0.22  // Reduced from 0.25 to 0.22
                    spacing: 5

                    Text {
                        text: "Audio:"
                        width: 60
                        height: parent.height
                        color: "#FFFFFF"
                        font.pixelSize: root.height * 0.025  // Reduced from 0.03
                        verticalAlignment: Text.AlignVCenter
                    }

                    TextField {
                        id: questionAudioField
                        width: parent.width - 60 - 30 - 10
                        height: parent.height
                        text: selectorQuestion && selectorQuestion.audio ? selectorQuestion.audio : ""
                        color: "#FFFFFF"
                        font.pixelSize: root.height * 0.025  // Reduced from 0.03
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
                    height: parent.height * 0.22  // Reduced from 0.25 to 0.22
                    spacing: 5

                    Text {
                        text: "Video:"
                        width: 60
                        height: parent.height
                        color: "#FFFFFF"
                        font.pixelSize: root.height * 0.025  // Reduced from 0.03
                        verticalAlignment: Text.AlignVCenter
                    }

                    TextField {
                        id: questionVideoField
                        width: parent.width - 60 - 30 - 10
                        height: parent.height
                        text: selectorQuestion && selectorQuestion.video ? selectorQuestion.video : ""
                        color: "#FFFFFF"
                        font.pixelSize: root.height * 0.025  // Reduced from 0.03
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

        // Options Section
        Rectangle {
            id: optionsSection
            width: parent.width
            height: parent.height * 0.65  // Reduced from 0.7 to 0.65
            color: "#232f34"
            border.color: "#009ca6"
            border.width: 1
            radius: 6

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Row {
                    width: parent.width
                    height: 25

                    Text {
                        text: "Answer Options (" + (selectorQuestion.answers ? selectorQuestion.answers.length : 0) + ")"
                        color: "#009ca6"
                        font.pixelSize: root.height * 0.04
                        font.bold: true
                        width: parent.width - 100
                    }

                    Rectangle {
                        width: 80
                        height: 25
                        color: {
                            let optionCount = selectorQuestion && selectorQuestion.answers ? selectorQuestion.answers.length : 0;
                            return optionCount >= 5 ? "#666666" : "#009ca6";  // Gray if max reached
                        }
                        opacity: {
                            let optionCount = selectorQuestion && selectorQuestion.answers ? selectorQuestion.answers.length : 0;
                            return optionCount >= 5 ? 0.5 : 1.0;  // Dim if max reached
                        }
                        radius: 4
                        Text {
                            anchors.centerIn: parent
                            text: "Add Option"
                            color: "white"
                            font.pixelSize: root.height * 0.03
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                let optionCount = selectorQuestion && selectorQuestion.answers ? selectorQuestion.answers.length : 0;
                                if (optionCount < 5) {
                                    // Maximum 5 options
                                    optionAdded();
                                } else {
                                    console.log("Maximum 5 options allowed");
                                }
                            }
                        }
                    }
                }

                // Add a spacer item instead of anchors.top
                Item {
                    width: parent.width
                    height: 3  // Space for header
                }

                Column {
                    id: column
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: selectorQuestion && selectorQuestion.answers ? selectorQuestion.answers : []

                        Rectangle {
                            width: parent.width
                            height: 35  // Reduced from 45 to 40
                            color: "#1A2327"
                            border.color: "#445055"
                            border.width: 1
                            radius: 4

                            Row {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                // Option number
                                Text {
                                    text: index + 1
                                    width: 20
                                    height: parent.height
                                    color: "#009ca6"
                                    font.bold: true
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
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
                                    width: parent.width * 0.4
                                    height: parent.height
                                    text: modelData && modelData.text ? modelData.text : ""
                                    color: "#FFFFFF"
                                    font.pixelSize: root.height * 0.03
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
                                    width: parent.width * 0.35
                                    height: parent.height
                                    text: modelData && modelData.image ? modelData.image : ""
                                    color: "#FFFFFF"
                                    font.pixelSize: root.height * 0.03
                                    placeholderText: "Image path..."
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
                                    width: 25
                                    height: 25
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
                                            optionImageDialog.currentOptionIndex = index;
                                            optionImageDialog.open();
                                        }
                                    }
                                }

                                // Delete button
                                Rectangle {
                                    width: 25
                                    height: 25
                                    radius: 12
                                    color: {
                                        let optionCount = selectorQuestion && selectorQuestion.answers ? selectorQuestion.answers.length : 0;
                                        return optionCount <= 2 ? "#666666" : "#d2232b";  // Gray if min reached
                                    }
                                    opacity: {
                                        let optionCount = selectorQuestion && selectorQuestion.answers ? selectorQuestion.answers.length : 0;
                                        return optionCount <= 2 ? 0.5 : 1.0;  // Dim if min reached
                                    }
                                    anchors.verticalCenter: parent.verticalCenter

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
                                                // Minimum 2 options
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
}
