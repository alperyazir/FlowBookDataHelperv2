import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs
import QtQuick.Window
import Qt.labs.platform
import ".."

Rectangle {
    id: root

    property var selectorQuestion: ({
            "question": "",
            "header": "",
            "image": "",
            "audio": "",
            "video": "",
            "answers": []
        })

    property int questionId: 0

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

    width: parent ? parent.width : 600
    // Height follows the content so a card never leaves a big empty gap.
    implicitHeight: contentColumn.implicitHeight + 2 * pad
    height: implicitHeight
    radius: 8
    color: "#1A2327"
    border.color: "#009ca6"
    border.width: 1

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
                anchors.right: deleteQuestionBtn.left
                anchors.rightMargin: root.gap
                anchors.verticalCenter: parent.verticalCenter
                text: "Selector Question #" + questionId
                color: "#009ca6"
                font.pixelSize: root.fsTitle
                font.bold: true
                elide: Text.ElideRight
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
                    onClicked: questionDeleted()
                }
            }
        }

        // Question Media Section
        Rectangle {
            width: parent.width
            implicitHeight: questionMediaLayout.implicitHeight + 2 * Math.round(6 * root.ui)
            height: implicitHeight
            color: "#232f34"
            border.color: "#009ca6"
            border.width: 1
            radius: 6
            clip: true

            ColumnLayout {
                id: questionMediaLayout
                anchors.fill: parent
                anchors.margins: Math.round(6 * root.ui)
                spacing: Math.round(6 * root.ui)

                // Header
                Text {
                    text: "Question Media"
                    color: "#009ca6"
                    font.pixelSize: root.fs
                    font.bold: true
                    Layout.preferredHeight: Math.round(18 * root.ui)
                }

                // Header and Text field row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.rowH
                    spacing: root.gap

                    // Header field group
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Math.round(4 * root.ui)

                        Text {
                            text: "Header:"
                            Layout.preferredWidth: Math.round(50 * root.ui)
                            color: "#FFFFFF"
                            font.pixelSize: root.fs
                            verticalAlignment: Text.AlignVCenter
                        }

                        TextField {
                            id: questionHeaderField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: selectorQuestion && selectorQuestion.header ? selectorQuestion.header : ""
                            color: "#FFFFFF"
                            font.pixelSize: root.fs
                            placeholderText: "Header text..."
                            placeholderTextColor: "#666666"
                            background: Rectangle {
                                color: "#1A2327"
                                border.color: questionHeaderField.focus ? "#009ca6" : "#445055"
                                border.width: 1
                                radius: 6
                            }
                            onTextChanged: {
                                if (selectorQuestion) selectorQuestion.header = text;
                            }
                        }
                    }

                    // Text field group
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Math.round(4 * root.ui)

                        Text {
                            text: "Text:"
                            Layout.preferredWidth: Math.round(35 * root.ui)
                            color: "#FFFFFF"
                            font.pixelSize: root.fs
                            verticalAlignment: Text.AlignVCenter
                        }

                        TextField {
                            id: questionTextField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: selectorQuestion && selectorQuestion.question ? selectorQuestion.question : ""
                            color: "#FFFFFF"
                            font.pixelSize: root.fs
                            placeholderText: "Question text..."
                            placeholderTextColor: "#666666"
                            background: Rectangle {
                                color: "#1A2327"
                                border.color: questionTextField.focus ? "#009ca6" : "#445055"
                                border.width: 1
                                radius: 6
                            }
                            onTextChanged: {
                                if (selectorQuestion) selectorQuestion.question = text;
                            }
                        }
                    }
                }

                // Image and Audio in same row (2 columns)
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.rowH
                    spacing: root.gap

                    // Image field group
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Math.round(4 * root.ui)

                        Text {
                            text: "Image:"
                            Layout.preferredWidth: Math.round(45 * root.ui)
                            color: "#FFFFFF"
                            font.pixelSize: root.fs
                            verticalAlignment: Text.AlignVCenter
                        }

                        TextField {
                            id: questionImageField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: selectorQuestion && selectorQuestion.image ? selectorQuestion.image : ""
                            color: "#FFFFFF"
                            font.pixelSize: root.fs
                            placeholderText: "Select..."
                            placeholderTextColor: "#666666"
                            background: Rectangle {
                                color: "#1A2327"
                                border.color: questionImageField.focus ? "#009ca6" : "#445055"
                                border.width: 1
                                radius: 6
                            }
                            onTextChanged: {
                                if (selectorQuestion) selectorQuestion.image = text;
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: root.delSize
                            Layout.fillHeight: true
                            Layout.maximumHeight: root.rowH
                            color: qImgBrowseArea.containsMouse ? "#00b3be" : "#009ca6"
                            radius: 6
                            Text {
                                anchors.centerIn: parent
                                text: "..."
                                color: "white"
                                font.bold: true
                                font.pixelSize: root.fsTitle
                            }
                            MouseArea {
                                id: qImgBrowseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: questionImageDialog.open()
                            }
                        }
                    }

                    // Audio field group
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: Math.round(4 * root.ui)

                        Text {
                            text: "Audio:"
                            Layout.preferredWidth: Math.round(45 * root.ui)
                            color: "#FFFFFF"
                            font.pixelSize: root.fs
                            verticalAlignment: Text.AlignVCenter
                        }

                        TextField {
                            id: questionAudioField
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: selectorQuestion && selectorQuestion.audio ? selectorQuestion.audio : ""
                            color: "#FFFFFF"
                            font.pixelSize: root.fs
                            placeholderText: "Select..."
                            placeholderTextColor: "#666666"
                            background: Rectangle {
                                color: "#1A2327"
                                border.color: questionAudioField.focus ? "#009ca6" : "#445055"
                                border.width: 1
                                radius: 6
                            }
                            onTextChanged: {
                                if (selectorQuestion) selectorQuestion.audio = text;
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: root.delSize
                            Layout.fillHeight: true
                            Layout.maximumHeight: root.rowH
                            color: qAudioBrowseArea.containsMouse ? "#00b3be" : "#009ca6"
                            radius: 6
                            Text {
                                anchors.centerIn: parent
                                text: "..."
                                color: "white"
                                font.bold: true
                                font.pixelSize: root.fsTitle
                            }
                            MouseArea {
                                id: qAudioBrowseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: questionAudioDialog.open()
                            }
                        }
                    }
                }

                // Video field row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.rowH
                    spacing: Math.round(4 * root.ui)

                    Text {
                        text: "Video:"
                        Layout.preferredWidth: Math.round(45 * root.ui)
                        color: "#FFFFFF"
                        font.pixelSize: root.fs
                        verticalAlignment: Text.AlignVCenter
                    }

                    TextField {
                        id: questionVideoField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        text: selectorQuestion && selectorQuestion.video ? selectorQuestion.video : ""
                        color: "#FFFFFF"
                        font.pixelSize: root.fs
                        placeholderText: "Select..."
                        placeholderTextColor: "#666666"
                        background: Rectangle {
                            color: "#1A2327"
                            border.color: questionVideoField.focus ? "#009ca6" : "#445055"
                            border.width: 1
                            radius: 6
                        }
                        onTextChanged: {
                            if (selectorQuestion) selectorQuestion.video = text;
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: root.delSize
                        Layout.fillHeight: true
                        Layout.maximumHeight: root.rowH
                        color: qVideoBrowseArea.containsMouse ? "#00b3be" : "#009ca6"
                        radius: 6
                        Text {
                            anchors.centerIn: parent
                            text: "..."
                            color: "white"
                            font.bold: true
                            font.pixelSize: root.fsTitle
                        }
                        MouseArea {
                            id: qVideoBrowseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
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
            implicitHeight: optionsLayout.implicitHeight + 2 * Math.round(6 * root.ui)
            height: implicitHeight
            color: "#232f34"
            border.color: "#009ca6"
            border.width: 1
            radius: 6
            clip: true

            ColumnLayout {
                id: optionsLayout
                anchors.fill: parent
                anchors.margins: Math.round(6 * root.ui)
                spacing: root.gap

                // Header row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(24 * root.ui)

                    Text {
                        text: "Answer Options (" + (selectorQuestion.answers ? selectorQuestion.answers.length : 0) + ")"
                        color: "#009ca6"
                        font.pixelSize: root.fs
                        font.bold: true
                        Layout.fillWidth: true
                        verticalAlignment: Text.AlignVCenter
                    }

                    Rectangle {
                        id: addOptionBtn
                        property bool canAdd: {
                            let count = selectorQuestion && selectorQuestion.answers ? selectorQuestion.answers.length : 0;
                            return count < 5;
                        }
                        Layout.preferredWidth: Math.round(90 * root.ui)
                        Layout.preferredHeight: Math.round(24 * root.ui)
                        color: !canAdd ? "#555f64" : (addOptArea.containsMouse ? "#00b3be" : "#009ca6")
                        opacity: canAdd ? 1.0 : 0.5
                        radius: 4
                        Text {
                            anchors.centerIn: parent
                            text: "Add Option"
                            color: "white"
                            font.pixelSize: root.fsSmall
                            font.bold: true
                        }
                        MouseArea {
                            id: addOptArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: addOptionBtn.canAdd ? Qt.PointingHandCursor : Qt.ArrowCursor
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
                    rowSpacing: root.gap
                    columnSpacing: root.gap

                    Repeater {
                        model: selectorQuestion && selectorQuestion.answers ? selectorQuestion.answers : []

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.optRowH
                            Layout.minimumHeight: root.optRowH
                            color: "#1A2327"
                            border.color: "#445055"
                            border.width: 1
                            radius: 4

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: Math.round(4 * root.ui)
                                spacing: Math.round(4 * root.ui)

                                // Option number
                                Text {
                                    text: index + 1
                                    Layout.preferredWidth: Math.round(16 * root.ui)
                                    color: "#009ca6"
                                    font.bold: true
                                    font.pixelSize: root.fsSmall
                                    verticalAlignment: Text.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                // Correct checkbox
                                Rectangle {
                                    Layout.preferredWidth: root.cbSize
                                    Layout.preferredHeight: root.cbSize
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: 4
                                    color: "white"
                                    border.color: "#009ca6"
                                    border.width: 2

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (modelData) modelData.isCorrect = !modelData.isCorrect;
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData && modelData.isCorrect ? "✓" : ""
                                        color: "#009ca6"
                                        font.pixelSize: root.fs
                                        font.bold: true
                                    }
                                }

                                // Text field
                                TextField {
                                    id: optionTextField
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: Math.round(100 * root.ui)
                                    text: modelData && modelData.text ? modelData.text : ""
                                    color: "#FFFFFF"
                                    font.pixelSize: root.fsSmall
                                    placeholderText: "Text..."
                                    placeholderTextColor: "#666666"
                                    background: Rectangle {
                                        color: "#232f34"
                                        border.color: optionTextField.focus ? "#009ca6" : "#445055"
                                        border.width: 1
                                        radius: 6
                                    }
                                    onTextChanged: {
                                        if (modelData) modelData.text = text;
                                    }
                                }

                                // Image field
                                TextField {
                                    id: optionImageField
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.preferredWidth: Math.round(100 * root.ui)
                                    text: modelData && modelData.image ? modelData.image : ""
                                    color: "#FFFFFF"
                                    font.pixelSize: root.fsSmall
                                    placeholderText: "Image..."
                                    placeholderTextColor: "#666666"
                                    readOnly: true
                                    background: Rectangle {
                                        color: "#232f34"
                                        border.color: optionImageField.focus ? "#009ca6" : "#445055"
                                        border.width: 1
                                        radius: 6
                                    }
                                }

                                // Image select button
                                Rectangle {
                                    Layout.preferredWidth: root.cbSize
                                    Layout.preferredHeight: root.cbSize
                                    Layout.alignment: Qt.AlignVCenter
                                    color: optImgBrowseArea.containsMouse ? "#00b3be" : "#009ca6"
                                    radius: 4
                                    Text {
                                        anchors.centerIn: parent
                                        text: "..."
                                        color: "white"
                                        font.bold: true
                                        font.pixelSize: root.fsSmall
                                    }
                                    MouseArea {
                                        id: optImgBrowseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            optionImageDialog.currentOptionIndex = index;
                                            optionImageDialog.open();
                                        }
                                    }
                                }

                                // Delete button
                                Rectangle {
                                    id: deleteOptionBtn
                                    property bool canDelete: {
                                        let count = selectorQuestion && selectorQuestion.answers ? selectorQuestion.answers.length : 0;
                                        return count > 2;
                                    }
                                    Layout.preferredWidth: root.cbSize
                                    Layout.preferredHeight: root.cbSize
                                    Layout.alignment: Qt.AlignVCenter
                                    radius: width / 2
                                    color: !canDelete ? "#555f64" : (delOptArea.containsMouse ? "#e23b42" : "#d2232b")
                                    opacity: canDelete ? 1.0 : 0.5

                                    Text {
                                        text: "×"
                                        anchors.centerIn: parent
                                        color: "white"
                                        font.pixelSize: root.fsSmall
                                        font.bold: true
                                    }

                                    MouseArea {
                                        id: delOptArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: deleteOptionBtn.canDelete ? Qt.PointingHandCursor : Qt.ArrowCursor
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
