import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtQuick.Window
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
                text: "Race Question #" + questionId
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
                        print("deleting Race Question");
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
                text: raceQuestion && raceQuestion.question ? raceQuestion.question : ""
                color: "#FFFFFF"
                font.pixelSize: root.fs
                placeholderText: "Enter race question text..."
                placeholderTextColor: "#666666"
                background: Rectangle {
                    color: "#232f34"
                    border.color: questionTextField.focus ? "#009ca6" : "#445055"
                    border.width: 1
                    radius: 6
                }
                onTextChanged: {
                    if (raceQuestion) {
                        raceQuestion.question = text;
                    }
                }
            }
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
                id: imageTextField
                width: parent.width - root.labelW - root.browseW - 2 * root.gap
                height: parent.height
                text: raceQuestion && raceQuestion.image ? raceQuestion.image : ""
                color: "#FFFFFF"
                font.pixelSize: root.fs
                placeholderText: "Select image..."
                placeholderTextColor: "#666666"
                background: Rectangle {
                    color: "#232f34"
                    border.color: imageTextField.focus ? "#009ca6" : "#445055"
                    border.width: 1
                    radius: 6
                }
                onTextChanged: {
                    if (raceQuestion) {
                        raceQuestion.image = text;
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
                    onClicked: imageFileDialog.open()
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
                id: audioTextField
                width: parent.width - root.labelW - root.browseW - 2 * root.gap
                height: parent.height
                text: raceQuestion && raceQuestion.audio ? raceQuestion.audio : ""
                color: "#FFFFFF"
                font.pixelSize: root.fs
                placeholderText: "Select audio..."
                placeholderTextColor: "#666666"
                background: Rectangle {
                    color: "#232f34"
                    border.color: audioTextField.focus ? "#009ca6" : "#445055"
                    border.width: 1
                    radius: 6
                }
                onTextChanged: {
                    if (raceQuestion) {
                        raceQuestion.audio = text;
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
                    onClicked: audioFileDialog.open()
                }
            }
        }

        // Fixed Options Area (4 options only)
        Column {
            id: optionsColumn
            width: parent.width
            spacing: Math.round(8 * root.ui)

            // Options Header
            Text {
                text: "Answer Options (4)"
                color: "#009ca6"
                font.pixelSize: root.fs
                font.bold: true
                width: parent.width
            }

            // Fixed 4 Options
            Repeater {
                id: optionRepeater
                model: 4  // Fixed 4 options

                Row {
                    id: optionRow
                    width: optionsColumn.width
                    height: root.optRowH
                    spacing: root.gap

                    Text {
                        text: "Option " + (index + 1)
                        width: root.labelW
                        height: parent.height
                        color: "#FFFFFF"
                        font.pixelSize: root.fsSmall
                        verticalAlignment: Text.AlignVCenter
                    }

                    // Correct checkbox
                    Rectangle {
                        width: root.cbSize
                        height: root.cbSize
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
                            font.pixelSize: root.fs
                            font.bold: true
                        }
                    }

                    TextField {
                        width: (parent.width - root.labelW - root.cbSize - root.browseW - 4 * root.gap) * 0.55
                        height: parent.height
                        text: {
                            if (!raceQuestion.answers || !raceQuestion.answers[index])
                                return "";
                            return raceQuestion.answers[index].text || "";
                        }
                        color: "#FFFFFF"
                        font.pixelSize: root.fsSmall
                        placeholderText: "Option " + (index + 1) + " text"
                        placeholderTextColor: "#666666"
                        background: Rectangle {
                            color: "#232f34"
                            border.color: parent.focus ? "#009ca6" : "#445055"
                            border.width: 1
                            radius: 6
                        }
                        onTextChanged: {
                            if (raceQuestion.answers && raceQuestion.answers[index]) {
                                raceQuestion.answers[index].text = text;
                            }
                        }
                    }

                    // Image field for option
                    TextField {
                        width: (parent.width - root.labelW - root.cbSize - root.browseW - 4 * root.gap) * 0.45
                        height: parent.height
                        text: {
                            if (!raceQuestion.answers || !raceQuestion.answers[index])
                                return "";
                            return raceQuestion.answers[index].image || "";
                        }
                        color: "#FFFFFF"
                        font.pixelSize: root.fsSmall
                        placeholderText: "Option image"
                        placeholderTextColor: "#666666"
                        background: Rectangle {
                            color: "#232f34"
                            border.color: parent.focus ? "#009ca6" : "#445055"
                            border.width: 1
                            radius: 6
                        }
                        onTextChanged: {
                            if (raceQuestion.answers && raceQuestion.answers[index]) {
                                raceQuestion.answers[index].image = text;
                            }
                        }
                    }

                    // File dialog button for option image
                    Rectangle {
                        width: root.browseW
                        height: parent.height
                        radius: 6
                        anchors.verticalCenter: parent.verticalCenter
                        color: optImageBrowseArea.containsMouse ? "#00b3be" : "#009ca6"

                        Text {
                            anchors.centerIn: parent
                            text: "..."
                            color: "white"
                            font.pixelSize: root.fsTitle
                            font.bold: true
                        }

                        MouseArea {
                            id: optImageBrowseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
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
