import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtQuick.Window
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

    // Everything scales with the window height (1080 baseline) instead of
    // fixed pixels, so the card stays proportional on any screen — while the
    // card's *total* height still follows its content (no cramping).
    readonly property real ui: Window.height > 0 ? Window.height / 1080 : 1.0
    readonly property int labelW: Math.round(70 * ui)
    readonly property int rowH: Math.round(38 * ui)
    readonly property int optRowH: Math.round(34 * ui)
    readonly property int pad: Math.round(12 * ui)
    readonly property int gap: Math.round(10 * ui)
    readonly property int cbSize: Math.round(22 * ui)
    readonly property int delSize: Math.round(24 * ui)
    readonly property int browseW: Math.round(70 * ui)
    readonly property int fsTitle: Math.round(16 * ui)
    readonly property int fs: Math.round(14 * ui)
    readonly property int fsSmall: Math.round(13 * ui)

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

    width: parent ? parent.width : 600
    // Height follows the content so a card never leaves a big empty gap.
    implicitHeight: contentColumn.implicitHeight + 2 * pad
    height: implicitHeight
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
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.pad
        spacing: Math.round(8 * root.ui)

        // Header: title + delete button (anchored, never overflows the card)
        Item {
            width: parent.width
            height: Math.round(28 * root.ui)

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Question #" + questionId
                color: "#009ca6"
                font.pixelSize: root.fsTitle
                font.bold: true
            }

            Rectangle {
                id: deleteQuestionBtn
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.round(26 * root.ui)
                height: Math.round(26 * root.ui)
                radius: width / 2
                color: delQArea.containsMouse ? "#e23b42" : "#d2232b"

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: "white"
                    font.pixelSize: root.fsTitle
                    font.bold: true
                }

                MouseArea {
                    id: delQArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        print("deleting Question");
                        questionDeleted();
                    }
                }
            }
        }

        // Question text
        Row {
            width: parent.width
            height: root.rowH
            spacing: root.gap

            Text {
                width: root.labelW
                height: parent.height
                text: "Text:"
                color: "#FFFFFF"
                font.pixelSize: root.fs
                verticalAlignment: Text.AlignVCenter
            }

            TextField {
                id: questionTextField
                width: parent.width - root.labelW - root.gap
                height: parent.height
                text: quizQuestion && quizQuestion.question ? quizQuestion.question : ""
                color: "#FFFFFF"
                font.pixelSize: root.fs
                placeholderText: "Enter your question here..."
                placeholderTextColor: "#666666"

                background: Rectangle {
                    color: "#232f34"
                    border.color: questionTextField.focus ? "#009ca6" : "#445055"
                    border.width: 1
                    radius: 6
                }

                onTextChanged: {
                    if (quizQuestion) {
                        quizQuestion.question = text;
                    }
                }
            }
        }

        // Image path + browse
        Row {
            width: parent.width
            height: root.rowH
            spacing: root.gap

            Text {
                width: root.labelW
                height: parent.height
                text: "Image:"
                color: "#FFFFFF"
                font.pixelSize: root.fs
                verticalAlignment: Text.AlignVCenter
            }

            TextField {
                id: imageTextField
                width: parent.width - root.labelW - root.browseW - 2 * root.gap
                height: parent.height
                text: quizQuestion && quizQuestion.image ? quizQuestion.image : ""
                color: "#FFFFFF"
                font.pixelSize: root.fs
                placeholderText: "Select image file or enter path..."
                placeholderTextColor: "#666666"

                background: Rectangle {
                    color: "#232f34"
                    border.color: imageTextField.focus ? "#009ca6" : "#445055"
                    border.width: 1
                    radius: 6
                }

                onTextChanged: {
                    if (quizQuestion) {
                        quizQuestion.image = text;
                    }
                }
            }

            Rectangle {
                width: root.browseW
                height: parent.height
                radius: 6
                color: browseArea.containsMouse ? "#00b3be" : "#009ca6"

                Text {
                    anchors.centerIn: parent
                    text: "..."
                    color: "white"
                    font.pixelSize: root.fsTitle
                    font.bold: true
                }

                MouseArea {
                    id: browseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        console.log("File dialog button clicked");
                        imageFileDialog.open();
                    }
                }
            }
        }

        // Options
        Repeater {
            id: optionRepeater
            model: quizQuestion && quizQuestion.answers ? quizQuestion.answers : []

            Row {
                width: contentColumn.width
                height: root.optRowH
                spacing: root.gap

                Text {
                    width: root.labelW
                    height: parent.height
                    text: "Option " + (index + 1)
                    color: "#FFFFFF"
                    font.pixelSize: root.fsSmall
                    verticalAlignment: Text.AlignVCenter
                }

                // Correct-answer checkbox
                Rectangle {
                    width: root.cbSize
                    height: root.cbSize
                    radius: 4
                    color: "white"
                    border.color: "#009ca6"
                    border.width: 2
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        anchors.centerIn: parent
                        text: modelData && modelData.isCorrect ? "✓" : ""
                        color: "#009ca6"
                        font.pixelSize: root.fs
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (modelData) {
                                modelData.isCorrect = !modelData.isCorrect;
                            }
                        }
                    }
                }

                TextField {
                    id: answerTextField
                    width: parent.width - root.labelW - root.cbSize - root.delSize - 3 * root.gap
                    height: parent.height
                    text: modelData && modelData.text ? modelData.text : ""
                    color: "#FFFFFF"
                    font.pixelSize: root.fsSmall
                    placeholderText: "Enter option " + (index + 1)
                    placeholderTextColor: "#666666"

                    background: Rectangle {
                        color: "#232f34"
                        border.color: answerTextField.focus ? "#009ca6" : "#445055"
                        border.width: 1
                        radius: 6
                    }

                    onTextChanged: {
                        if (modelData) {
                            modelData.text = text;
                        }
                    }
                }

                // Delete option
                Rectangle {
                    id: deleteOptionBtn
                    width: root.delSize
                    height: root.delSize
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    property bool canDelete: !(quizQuestion && quizQuestion.answers && quizQuestion.answers.length <= 3)
                    color: !canDelete ? "#555f64" : (delOptArea.containsMouse ? "#e23b42" : "#d2232b")
                    opacity: canDelete ? 1.0 : 0.5

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: "white"
                        font.pixelSize: root.fsSmall
                        font.bold: true
                    }

                    MouseArea {
                        id: delOptArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: deleteOptionBtn.canDelete ? Qt.PointingHandCursor : Qt.ArrowCursor
                        enabled: deleteOptionBtn.canDelete
                        onClicked: {
                            print("deleting Option");
                            optionDeleted(index);
                        }
                    }
                }
            }
        }

        // Add new option
        Rectangle {
            id: addNewOptionBtn
            width: parent.width * 0.4
            height: root.optRowH
            radius: 6
            anchors.horizontalCenter: parent.horizontalCenter
            property bool canAdd: !(quizQuestion && quizQuestion.answers && quizQuestion.answers.length >= 5)
            color: !canAdd ? "#555f64" : (addOptArea.containsMouse ? "#00b3be" : "#009ca6")
            opacity: canAdd ? 1.0 : 0.5

            Text {
                text: "Add New Option"
                anchors.centerIn: parent
                color: "white"
                font.pixelSize: root.fsSmall
                font.bold: true
            }

            MouseArea {
                id: addOptArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: addNewOptionBtn.canAdd ? Qt.PointingHandCursor : Qt.ArrowCursor
                enabled: addNewOptionBtn.canAdd
                onClicked: {
                    print("Add New Option");
                    optionAdded();
                }
            }
        }
    }
}
