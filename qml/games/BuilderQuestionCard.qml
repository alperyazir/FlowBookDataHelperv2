import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtQuick.Window
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

    width: parent ? parent.width : 600
    // Height follows the content so a card never leaves a big empty gap.
    implicitHeight: contentColumn.implicitHeight + 2 * pad
    height: implicitHeight
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
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.pad
        spacing: Math.round(8 * root.ui)

        // Header: title + delete button (anchored, never overflows the card)
        Item {
            id: headerRow
            width: parent.width
            height: Math.round(28 * root.ui)

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Builder Question #" + questionId
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
                        print("deleting Builder Question");
                        questionDeleted();
                    }
                }
            }
        }

        // Question Text Section
        Row {
            id: questionTextSection
            width: parent.width
            height: root.rowH
            spacing: root.gap

            Text {
                text: "Question:"
                width: root.labelW
                height: parent.height
                color: "#FFFFFF"
                font.pixelSize: root.fs
                verticalAlignment: Text.AlignVCenter
            }

            TextField {
                id: questionTextField
                width: parent.width - root.labelW - root.gap
                height: parent.height
                text: builderQuestion && builderQuestion.question ? builderQuestion.question : ""
                color: "#FFFFFF"
                font.pixelSize: root.fs
                placeholderText: "Enter question text..."
                placeholderTextColor: "#666666"
                background: Rectangle {
                    color: "#232f34"
                    border.color: questionTextField.focus ? "#009ca6" : "#445055"
                    border.width: 1
                    radius: 6
                }
                onTextChanged: {
                    if (builderQuestion) {
                        builderQuestion.question = text;
                    }
                }
            }
        }

        // Question Media Section
        Column {
            id: questionMediaSection
            width: parent.width
            spacing: Math.round(8 * root.ui)

            Text {
                text: "Question Media"
                color: "#009ca6"
                font.pixelSize: root.fs
                font.bold: true
            }

            // Image Row
            Row {
                width: parent.width
                height: root.rowH
                spacing: root.gap

                Text {
                    text: "Image:"
                    width: root.labelW
                    height: parent.height
                    color: "#FFFFFF"
                    font.pixelSize: root.fs
                    verticalAlignment: Text.AlignVCenter
                }

                TextField {
                    id: questionImageField
                    width: parent.width - root.labelW - root.browseW - 2 * root.gap
                    height: parent.height
                    text: builderQuestion && builderQuestion.image ? builderQuestion.image : ""
                    color: "#FFFFFF"
                    font.pixelSize: root.fs
                    placeholderText: "Select image..."
                    placeholderTextColor: "#666666"
                    background: Rectangle {
                        color: "#232f34"
                        border.color: questionImageField.focus ? "#009ca6" : "#445055"
                        border.width: 1
                        radius: 6
                    }
                    onTextChanged: {
                        if (builderQuestion) {
                            builderQuestion.image = text;
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
                        onClicked: questionImageDialog.open()
                    }
                }
            }

            // Audio Row
            Row {
                width: parent.width
                height: root.rowH
                spacing: root.gap

                Text {
                    text: "Audio:"
                    width: root.labelW
                    height: parent.height
                    color: "#FFFFFF"
                    font.pixelSize: root.fs
                    verticalAlignment: Text.AlignVCenter
                }

                TextField {
                    id: questionAudioField
                    width: parent.width - root.labelW - root.browseW - 2 * root.gap
                    height: parent.height
                    text: builderQuestion && builderQuestion.audio ? builderQuestion.audio : ""
                    color: "#FFFFFF"
                    font.pixelSize: root.fs
                    placeholderText: "Select audio..."
                    placeholderTextColor: "#666666"
                    background: Rectangle {
                        color: "#232f34"
                        border.color: questionAudioField.focus ? "#009ca6" : "#445055"
                        border.width: 1
                        radius: 6
                    }
                    onTextChanged: {
                        if (builderQuestion) {
                            builderQuestion.audio = text;
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
                        onClicked: questionAudioDialog.open()
                    }
                }
            }

            // Video Row
            Row {
                width: parent.width
                height: root.rowH
                spacing: root.gap

                Text {
                    text: "Video:"
                    width: root.labelW
                    height: parent.height
                    color: "#FFFFFF"
                    font.pixelSize: root.fs
                    verticalAlignment: Text.AlignVCenter
                }

                TextField {
                    id: questionVideoField
                    width: parent.width - root.labelW - root.browseW - 2 * root.gap
                    height: parent.height
                    text: builderQuestion && builderQuestion.video ? builderQuestion.video : ""
                    color: "#FFFFFF"
                    font.pixelSize: root.fs
                    placeholderText: "Select video..."
                    placeholderTextColor: "#666666"
                    background: Rectangle {
                        color: "#232f34"
                        border.color: questionVideoField.focus ? "#009ca6" : "#445055"
                        border.width: 1
                        radius: 6
                    }
                    onTextChanged: {
                        if (builderQuestion) {
                            builderQuestion.video = text;
                        }
                    }
                }

                Rectangle {
                    width: root.browseW
                    height: parent.height
                    radius: 6
                    color: videoBrowseArea.containsMouse ? "#00b3be" : "#009ca6"
                    Text {
                        anchors.centerIn: parent
                        text: "..."
                        color: "white"
                        font.pixelSize: root.fsTitle
                        font.bold: true
                    }
                    MouseArea {
                        id: videoBrowseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: questionVideoDialog.open()
                    }
                }
            }
        }

        // Words Input Section
        Row {
            id: wordsInputSection
            width: parent.width
            height: root.rowH
            spacing: root.gap

            Text {
                text: "Words:"
                width: root.labelW
                height: parent.height
                color: "#009ca6"
                font.pixelSize: root.fs
                font.bold: true
                verticalAlignment: Text.AlignVCenter
            }

            TextField {
                id: wordsTextField
                width: parent.width - root.labelW - root.gap
                height: parent.height
                color: "#FFFFFF"
                font.pixelSize: root.fs
                placeholderText: "Enter words separated by spaces for building sentence..."
                placeholderTextColor: "#666666"
                background: Rectangle {
                    color: "#232f34"
                    border.color: wordsTextField.focus ? "#009ca6" : "#445055"
                    border.width: 1
                    radius: 6
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

        // Words Preview Section
        Column {
            id: wordsPreviewSection
            width: parent.width
            spacing: Math.round(6 * root.ui)

            Text {
                text: "Words Preview (" + (builderQuestion.words ? builderQuestion.words.length : 0) + " words)"
                color: "#009ca6"
                font.pixelSize: root.fs
                font.bold: true
            }

            Rectangle {
                id: wordsPreviewArea
                width: parent.width
                height: Math.max(Math.round(56 * root.ui), wordsFlow.implicitHeight + 2 * root.pad)
                color: "#232f34"
                border.color: "#445055"
                border.width: 1
                radius: 6

                Flow {
                    id: wordsFlow
                    anchors.fill: parent
                    anchors.margins: root.pad
                    spacing: Math.round(8 * root.ui)

                    Repeater {
                        model: builderQuestion && builderQuestion.words ? builderQuestion.words : []

                        Rectangle {
                            width: wordText.width + Math.round(20 * root.ui)
                            height: root.optRowH
                            color: "#009ca6"
                            radius: 6
                            border.color: "#007a80"
                            border.width: 1

                            Text {
                                id: wordText
                                text: (index + 1) + ". " + modelData
                                anchors.centerIn: parent
                                color: "white"
                                font.pixelSize: root.fsSmall
                                font.bold: true
                            }
                        }
                    }
                }
            }
        }
    }
}
