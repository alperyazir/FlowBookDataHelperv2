import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtQuick.Window
import Qt.labs.platform
import ".."

Rectangle {
    id: root

    property var memoryQuestion: ({
            "image": "",
            "audio": ""
        })

    // Add question ID property
    property int questionId: 0

    // Signals for external communication
    signal questionDeleted

    // Everything scales with the window height (1080 baseline) instead of
    // fixed pixels, so the card stays proportional on any screen — while the
    // card's *total* height still follows its content (no cramping).
    readonly property real ui: Window.height > 0 ? Window.height / 1080 : 1.0
    readonly property int labelW: Math.round(70 * ui)
    readonly property int rowH: Math.round(38 * ui)
    readonly property int pad: Math.round(12 * ui)
    readonly property int gap: Math.round(10 * ui)
    readonly property int browseW: Math.round(70 * ui)
    readonly property int previewW: Math.round(220 * ui)
    readonly property int fsTitle: Math.round(16 * ui)
    readonly property int fs: Math.round(14 * ui)
    readonly property int fsSmall: Math.round(13 * ui)

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

    // FileDialog for audio selection
    FileDialog {
        id: audioFileDialog
        title: "Select Audio"
        nameFilters: ["Audio files (*.mp3 *.wav *.ogg *.m4a *.aac)"]

        onAccepted: {
            console.log("Audio FileDialog accepted!");
            var selectedFilePath = audioFileDialog.file + ""; // Seçilen dosyanın tam dosya yolu
            console.log("Selected audio file path:", selectedFilePath);

            if (selectedFilePath) {
                var newPath = findBooksFolder(selectedFilePath, "books");
                if (newPath) {
                    audioTextField.text = newPath;
                    if (memoryQuestion) {
                        memoryQuestion.audio = newPath;
                    }
                    console.log("Memory audio path set to:", newPath);
                } else {
                    console.log("Books klasörü bulunamadı, using full path");
                    // If books folder not found, use the full path
                    audioTextField.text = selectedFilePath;
                    if (memoryQuestion) {
                        memoryQuestion.audio = selectedFilePath;
                    }
                }
            } else {
                console.log("Dosya yolu geçersiz.");
            }
        }

        onRejected: {
            console.log("Audio file selection was canceled");
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
                text: "Memory Card #" + questionId
                color: "#009ca6" // Turquoise text
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
                color: delQArea.containsMouse ? "#e23b42" : "#d2232b" // Red color for delete

                Text {
                    text: "×"
                    anchors.centerIn: parent
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
                        print("deleting Memory Question");
                        questionDeleted();
                    }
                }
            }
        }

        // Main content area with image/audio fields and preview
        Row {
            id: mainContentRow
            width: parent.width
            spacing: root.gap

            // Left side - Image/Audio path inputs + info
            Column {
                id: leftColumn
                width: parent.width - root.previewW - root.gap
                spacing: Math.round(8 * root.ui)

                // Image Row
                Row {
                    id: imageRow
                    width: parent.width
                    height: root.rowH
                    spacing: root.gap

                    Text {
                        text: "Image:"
                        width: root.labelW
                        height: parent.height
                        color: "#FFFFFF" // White text
                        font.pixelSize: root.fs
                        verticalAlignment: Text.AlignVCenter
                    }

                    TextField {
                        id: imageTextField
                        width: parent.width - root.labelW - root.browseW - 2 * root.gap
                        height: parent.height
                        text: memoryQuestion && memoryQuestion.image ? memoryQuestion.image : ""
                        color: "#FFFFFF" // White text
                        font.pixelSize: root.fs
                        placeholderText: "Select image file or enter path..."
                        placeholderTextColor: "#666666"

                        background: Rectangle {
                            color: "#232f34" // Darker background
                            border.color: imageTextField.focus ? "#009ca6" : "#445055"
                            border.width: 1
                            radius: 6
                        }

                        onTextChanged: {
                            if (memoryQuestion) {
                                memoryQuestion.image = text;
                            }
                        }
                    }

                    Rectangle {
                        width: root.browseW
                        height: parent.height
                        radius: 6
                        color: imageBrowseArea.containsMouse ? "#00b3be" : "#009ca6"

                        Text {
                            anchors.centerIn: parent
                            text: "..."
                            color: "white"
                            font.pixelSize: root.fsTitle
                            font.bold: true
                        }

                        MouseArea {
                            id: imageBrowseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                console.log("Memory image dialog button clicked");
                                imageFileDialog.open();
                            }
                        }
                    }
                }

                // Audio Row
                Row {
                    id: audioRow
                    width: parent.width
                    height: root.rowH
                    spacing: root.gap

                    Text {
                        text: "Audio:"
                        width: root.labelW
                        height: parent.height
                        color: "#FFFFFF" // White text
                        font.pixelSize: root.fs
                        verticalAlignment: Text.AlignVCenter
                    }

                    TextField {
                        id: audioTextField
                        width: parent.width - root.labelW - root.browseW - 2 * root.gap
                        height: parent.height
                        text: memoryQuestion && memoryQuestion.audio ? memoryQuestion.audio : ""
                        color: "#FFFFFF" // White text
                        font.pixelSize: root.fs
                        placeholderText: "Select audio file or enter path..."
                        placeholderTextColor: "#666666"

                        background: Rectangle {
                            color: "#232f34" // Darker background
                            border.color: audioTextField.focus ? "#009ca6" : "#445055"
                            border.width: 1
                            radius: 6
                        }

                        onTextChanged: {
                            if (memoryQuestion) {
                                memoryQuestion.audio = text;
                            }
                        }
                    }

                    Rectangle {
                        width: root.browseW
                        height: parent.height
                        radius: 6
                        color: audioBrowseArea.containsMouse ? "#00b3be" : "#009ca6"

                        Text {
                            anchors.centerIn: parent
                            text: "..."
                            color: "white"
                            font.pixelSize: root.fsTitle
                            font.bold: true
                        }

                        MouseArea {
                            id: audioBrowseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                console.log("Memory audio dialog button clicked");
                                audioFileDialog.open();
                            }
                        }
                    }
                }

                // Info text
                Text {
                    text: "Select an image and optionally an audio file for this memory card. Both will be available during the memory game."
                    width: parent.width
                    color: "#CCCCCC"
                    font.pixelSize: root.fsSmall
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignTop
                }
            }

            // Right side - Preview area
            Rectangle {
                id: previewArea
                width: root.previewW
                height: Math.round(200 * root.ui)
                color: "#232f34"
                border.color: "#009ca6"
                border.width: 1
                radius: 8

                Column {
                    anchors.fill: parent
                    anchors.margins: root.gap
                    spacing: root.gap

                    Text {
                        text: "Preview"
                        color: "#009ca6"
                        font.pixelSize: root.fs
                        font.bold: true
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    // Image Preview
                    Rectangle {
                        id: imagePreview
                        width: parent.width
                        height: (parent.height - Math.round(30 * root.ui)) * 0.6
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
                            font.pixelSize: root.fsSmall
                            horizontalAlignment: Text.AlignHCenter
                            visible: !previewImage.visible
                        }
                    }

                    // Audio Preview
                    Rectangle {
                        id: audioPreview
                        width: parent.width
                        height: (parent.height - Math.round(30 * root.ui)) * 0.35
                        color: "#1A2327"
                        border.color: "#445055"
                        border.width: 1
                        radius: 4

                        Row {
                            anchors.fill: parent
                            anchors.margins: 5
                            spacing: root.gap

                            Image {
                                id: audioIcon
                                width: parent.height
                                height: parent.height
                                source: "qrc:/icons/sound.svg"
                                fillMode: Image.PreserveAspectFit
                                visible: memoryQuestion && memoryQuestion.audio && memoryQuestion.audio !== ""
                            }

                            Column {
                                width: parent.width - parent.height - root.gap
                                height: parent.height
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    text: "Audio File"
                                    color: "#009ca6"
                                    font.pixelSize: root.fsSmall
                                    font.bold: true
                                    visible: memoryQuestion && memoryQuestion.audio && memoryQuestion.audio !== ""
                                }

                                Text {
                                    text: memoryQuestion && memoryQuestion.audio ? memoryQuestion.audio.split('/').pop() : ""
                                    color: "#CCCCCC"
                                    font.pixelSize: root.fsSmall
                                    elide: Text.ElideMiddle
                                    visible: memoryQuestion && memoryQuestion.audio && memoryQuestion.audio !== ""
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "No Audio\nSelected"
                                color: "#666666"
                                font.pixelSize: root.fsSmall
                                horizontalAlignment: Text.AlignHCenter
                                visible: !(memoryQuestion && memoryQuestion.audio && memoryQuestion.audio !== "")
                            }
                        }
                    }
                }
            }
        }
    }
}
