import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import Qt.labs.platform
import ".."

Rectangle {
    id: root

    property var memoryQuestion: ({
            "image": ""
        })

    // Add question ID property
    property int questionId: 0

    // Signals for external communication
    signal questionDeleted

    // Function to find books folder - copied from QuizQuestionCard
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

    // Component.onCompleted
    Component.onCompleted: {
        console.log("Memory question loaded:", memoryQuestion.image);
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
                    if (memoryQuestion) {
                        memoryQuestion.image = newPath;
                    }
                    console.log("Memory image path set to:", newPath);
                } else {
                    console.log("Books klasörü bulunamadı, using full path");
                    // If books folder not found, use the full path
                    imageTextField.text = selectedFilePath;
                    if (memoryQuestion) {
                        memoryQuestion.image = selectedFilePath;
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
            height: parent.height * 0.15

            Text {
                text: "Memory Card #" + questionId
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
                        print("deleting Memory Question");
                        questionDeleted();
                    }
                }
            }
        }

        // Main content area with image field and preview
        Row {
            id: mainContentRow
            width: parent.width
            height: parent.height * 0.75
            spacing: 10

            // Left side - Image path input
            Column {
                id: leftColumn
                width: parent.width * 0.6
                height: parent.height
                spacing: 10

                // Image Row
                Row {
                    id: imageRow
                    width: parent.width
                    height: parent.height * 0.2

                    Text {
                        text: "Image:"
                        width: parent.width / 5
                        height: parent.height
                        color: "#FFFFFF" // White text
                        font.pixelSize: root.height * 0.06
                        verticalAlignment: Text.AlignVCenter
                    }

                    TextField {
                        id: imageTextField
                        width: parent.width / 5 * 3
                        height: parent.height
                        text: memoryQuestion && memoryQuestion.image ? memoryQuestion.image : ""
                        color: "#FFFFFF" // White text
                        font.pixelSize: root.height * 0.05
                        placeholderText: "Select image file or enter path..."
                        placeholderTextColor: "#666666"

                        background: Rectangle {
                            color: "#232f34" // Darker background
                            border.color: imageTextField.focus ? "#009ca6" : "#445055"
                            border.width: 1
                            radius: 4
                        }

                        onTextChanged: {
                            if (memoryQuestion) {
                                memoryQuestion.image = text;
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width / 5
                        height: parent.height
                        color: "#009ca6"
                        radius: 4

                        Text {
                            anchors.centerIn: parent
                            text: "..."
                            color: "white"
                            font.pixelSize: root.height * 0.06
                            font.bold: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                console.log("Memory image dialog button clicked");
                                imageFileDialog.open();
                            }
                        }
                    }
                }

                // Info text
                Text {
                    text: "Select an image for this memory card. The image will be shown during the memory game."
                    width: parent.width
                    height: parent.height * 0.15
                    color: "#CCCCCC"
                    font.pixelSize: root.height * 0.04
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignTop
                }
            }

            // Right side - Image preview
            Rectangle {
                id: previewArea
                width: parent.width * 0.35
                height: parent.height
                color: "#232f34"
                border.color: "#009ca6"
                border.width: 1
                radius: 8

                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Text {
                        text: "Preview"
                        color: "#009ca6"
                        font.pixelSize: root.height * 0.05
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Rectangle {
                        id: imagePreview
                        width: parent.width
                        height: parent.height - 30
                        color: "#1A2327"
                        border.color: "#445055"
                        border.width: 1
                        radius: 4

                        Image {
                            id: previewImage
                            anchors.fill: parent
                            anchors.margins: 5
                            source: "file:" + appPath + memoryQuestion.image
                            fillMode: Image.PreserveAspectFit
                            visible: memoryQuestion && memoryQuestion.image && memoryQuestion.image !== ""

                            onStatusChanged: {
                                if (status === Image.Error) {
                                    console.log("Error loading image:", source);
                                } else if (status === Image.Ready) {
                                    console.log("Image loaded successfully:", source);
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "No Image\nSelected"
                            color: "#666666"
                            font.pixelSize: root.height * 0.04
                            horizontalAlignment: Text.AlignHCenter
                            visible: !previewImage.visible
                        }
                    }
                }
            }
        }
    }
}
