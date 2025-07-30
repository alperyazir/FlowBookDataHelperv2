import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import Qt.labs.platform
import ".."

Rectangle {
    id: root

    property var quizQuestion: ({
            "question": "",
            "image": "",
            "answers": []
        })

    // Add question ID property
    property int questionId: 0

    // Signal for option addition
    signal optionAdded
    signal optionDeleted(int index)
    signal questionDeleted

    // Simple function to process file path
    function processImagePath(filePath) {
        console.log("processImagePath called with:", filePath);
        console.log("filePath type:", typeof filePath);

        if (!filePath) {
            console.log("No file path provided");
            return "";
        }

        // Remove file:// prefix if present
        var cleanPath = filePath.toString();
        console.log("After toString():", cleanPath);

        if (cleanPath.startsWith("file://")) {
            cleanPath = cleanPath.substring(7);
            console.log("After removing file:// prefix:", cleanPath);
        }

        console.log("Final clean path:", cleanPath);
        return cleanPath;
    }

    // Function to find books folder - copied from working examples
    function findBooksFolder(filePath, targetFolder) {
        // Yol parçalarını ayır
        var pathParts = filePath.split("/");
        console.log("Path parts:", pathParts);

        // "books" klasörünü bulana kadar yukarı doğru çık
        var booksIndex = -1;
        for (var i = pathParts.length - 1; i >= 0; i--) {
            if (pathParts[i] === targetFolder) {
                booksIndex = i;
                break;
            }
        }

        // Eğer "books" klasörü bulunursa, yeni yolu oluştur
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

        // "books" klasörü bulunamazsa null döndür
        console.log("Books klasörü bulunamadı.");
        return null;
    }

    // Component.onCompleted ile dummy veri ekleme
    Component.onCompleted: {
        console.log("Quiz question loaded:", quizQuestion.question);
        console.log("Number of answers:", quizQuestion.answers.length);
    }

    width: parent.width
    height: parent.height
    radius: 8
    color: "#1A2327" // Ana tema rengi
    border.color: "#009ca6" // Turquoise border
    border.width: 1

    // FileDialog for image selection
    FileDialog {
        id: imageFileDialog
        title: "Select Image"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.gif *.bmp)"]

        onAccepted: {
            console.log("FileDialog accepted!");
            var selectedFilePath = imageFileDialog.file + ""; // Seçilen dosyanın tam dosya yolu
            console.log("Selected file path:", selectedFilePath);

            if (selectedFilePath) {
                var newPath = findBooksFolder(selectedFilePath, "books");
                if (newPath) {
                    imageTextField.text = newPath;
                    if (quizQuestion) {
                        quizQuestion.image = newPath;
                    }
                    console.log("Image path set to:", newPath);
                } else {
                    console.log("Books klasörü bulunamadı, using full path");
                    // If books folder not found, use the full path
                    imageTextField.text = selectedFilePath;
                    if (quizQuestion) {
                        quizQuestion.image = selectedFilePath;
                    }
                }
            } else {
                console.log("Dosya yolu geçersiz.");
            }
        }

        onRejected: {
            console.log("File selection was canceled");
        }
    }

    Column {
        id: totalColumn
        width: parent.width
        height: parent.height
        spacing: 10

        // Header Row
        Row {
            id: headerRow
            width: parent.width
            height: parent.height * 0.12

            Text {
                text: "Question #" + questionId
                width: parent.width / 4
                height: parent.height
                color: "#009ca6" // Turquoise text
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
                color: "#d2232b" // Red color for delete
                anchors.verticalCenter: parent.verticalCenter
                // Note: We could add opacity/color changes here but would need access to total question count

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
                        print("deleting Question");
                        questionDeleted();
                    }
                }
            }
        }

        // Question Text Row
        Row {
            id: questionTextRow
            width: parent.width
            height: parent.height * 0.12

            Text {
                text: "Text:"
                width: parent.width / 7
                height: parent.height
                color: "#FFFFFF" // White text
                font.pixelSize: root.height * 0.06
                verticalAlignment: Text.AlignVCenter
            }

            TextField {
                id: questionTextField
                width: parent.width / 7 * 6
                height: parent.height
                text: quizQuestion && quizQuestion.question ? quizQuestion.question : ""
                color: "#FFFFFF" // White text
                font.pixelSize: root.height * 0.06
                placeholderText: "Enter your question here..."
                placeholderTextColor: "#666666"

                background: Rectangle {
                    color: "#232f34" // Darker background
                    border.color: questionTextField.focus ? "#009ca6" : "#445055"
                    border.width: 1
                    radius: 4
                }

                onTextChanged: {
                    if (quizQuestion) {
                        quizQuestion.question = text;
                    }
                }
            }
        }

        // Image Row
        Row {
            id: imageRow
            width: parent.width
            height: parent.height * 0.12

            Text {
                text: "Image:"
                width: parent.width / 7
                height: parent.height
                color: "#FFFFFF" // White text
                font.pixelSize: root.height * 0.06
                verticalAlignment: Text.AlignVCenter
            }

            TextField {
                id: imageTextField
                width: parent.width / 7 * 5
                height: parent.height
                text: quizQuestion && quizQuestion.image ? quizQuestion.image : ""
                color: "#FFFFFF" // White text
                font.pixelSize: root.height * 0.06
                placeholderText: "Select image file or enter path..."
                placeholderTextColor: "#666666"

                background: Rectangle {
                    color: "#232f34" // Darker background
                    border.color: imageTextField.focus ? "#009ca6" : "#445055"
                    border.width: 1
                    radius: 4
                }

                onTextChanged: {
                    if (quizQuestion) {
                        quizQuestion.image = text;
                    }
                }
            }

            Rectangle {
                width: parent.width / 7
                height: parent.height
                color: "#009ca6"
                radius: 4

                Text {
                    anchors.centerIn: parent
                    text: "..."
                    color: "white"
                    font.pixelSize: root.height * 0.08
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        console.log("File dialog button clicked");
                        imageFileDialog.open();
                        console.log("File dialog opened");
                    }
                }
            }
        }

        // Scrollable Options Area
        ScrollView {
            id: optionsScrollView
            width: parent.width
            height: parent.height * 0.53  // Reduced from 0.65 to account for image row
            clip: true

            Column {
                id: optionsColumn
                width: parent.width
                spacing: 6

                // Options Repeater
                Repeater {
                    id: optionRepeater
                    model: quizQuestion && quizQuestion.answers ? quizQuestion.answers : []

                    Row {
                        id: optionRow
                        width: optionsColumn.width
                        height: root.height * 0.08
                        spacing: 10

                        Text {
                            text: "Option " + (index + 1)
                            width: parent.width / 7
                            height: parent.height
                            color: "#FFFFFF" // White text
                            font.pixelSize: root.height * 0.05
                            verticalAlignment: Text.AlignVCenter
                        }

                        // Correct Answer Checkbox
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

                            // Checkmark
                            Text {
                                anchors.centerIn: parent
                                text: modelData && modelData.isCorrect ? "✓" : ""
                                color: "#009ca6"
                                font.pixelSize: 14
                                font.bold: true
                            }
                        }

                        TextField {
                            id: answerTextField
                            width: parent.width / 7 * 4
                            height: parent.height
                            text: modelData && modelData.text ? modelData.text : ""
                            color: "#FFFFFF" // White text
                            font.pixelSize: root.height * 0.05
                            placeholderText: "Enter option " + (index + 1)
                            placeholderTextColor: "#666666"

                            background: Rectangle {
                                color: "#232f34" // Darker background
                                border.color: answerTextField.focus ? "#009ca6" : "#445055"
                                border.width: 1
                                radius: 4
                            }

                            onTextChanged: {
                                if (modelData) {
                                    modelData.text = text;
                                }
                            }
                        }

                        // Delete Option Button
                        Rectangle {
                            id: deleteOptionBtn
                            color: (quizQuestion && quizQuestion.answers && quizQuestion.answers.length <= 3) ? "#999999" : "#d2232b" // Gray if disabled
                            width: 22
                            height: 22
                            radius: 11
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: (quizQuestion && quizQuestion.answers && quizQuestion.answers.length <= 3) ? 0.5 : 1.0

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: "white"
                                font.pixelSize: 14
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: !(quizQuestion && quizQuestion.answers && quizQuestion.answers.length <= 3)
                                onClicked: {
                                    print("deleting Option");
                                    optionDeleted(index);
                                }
                            }
                        }
                    }
                }

                // Add New Option Button - Now inside the ScrollView
                Rectangle {
                    id: addNewOptionBtn
                    width: parent.width / 3
                    height: root.height * 0.08
                    radius: 6
                    color: (quizQuestion && quizQuestion.answers && quizQuestion.answers.length >= 5) ? "#666666" : "#009ca6" // Gray if disabled
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: (quizQuestion && quizQuestion.answers && quizQuestion.answers.length >= 5) ? 0.5 : 1.0

                    Text {
                        text: "Add New Option"
                        anchors.centerIn: parent
                        color: "white"
                        font.pixelSize: root.height * 0.05
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !(quizQuestion && quizQuestion.answers && quizQuestion.answers.length >= 5)
                        onClicked: {
                            print("Add New Option");
                            optionAdded();
                        }
                    }
                }
            }
        }
    }
}
