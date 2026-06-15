import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window
import ".."

Rectangle {
    id: root

    property var orderQuestion: ({
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

    // Function to split sentence into words
    function splitSentenceIntoWords(sentence) {
        if (!sentence || sentence.trim() === "") {
            return [];
        }
        // Split by spaces and filter out empty strings
        return sentence.trim().split(/\s+/).filter(function (word) {
            return word.length > 0;
        });
    }

    // Component.onCompleted
    Component.onCompleted: {
        console.log("Order question loaded. Words count:", orderQuestion.words ? orderQuestion.words.length : 0);
    }

    width: parent ? parent.width : 600
    // Height follows the content so a card never leaves a big empty gap.
    implicitHeight: contentColumn.implicitHeight + 2 * pad
    height: implicitHeight
    radius: 8
    color: "#1A2327" // Ana tema rengi
    border.color: "#009ca6" // Turquoise border
    border.width: 1

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
                text: "Order Question #" + questionId
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
                        print("deleting Order Question");
                        questionDeleted();
                    }
                }
            }
        }

        // Sentence Input Row
        Row {
            id: sentenceInputRow
            width: parent.width
            height: root.rowH
            spacing: root.gap

            Text {
                text: "Sentence:"
                width: root.labelW
                height: parent.height
                color: "#FFFFFF" // White text
                font.pixelSize: root.fs
                verticalAlignment: Text.AlignVCenter
            }

            TextField {
                id: sentenceTextField
                width: parent.width - root.labelW - root.gap
                height: parent.height
                color: "#FFFFFF" // White text
                font.pixelSize: root.fs
                placeholderText: "Enter a sentence to be split into words for ordering..."
                placeholderTextColor: "#666666"

                background: Rectangle {
                    color: "#232f34" // Darker background
                    border.color: sentenceTextField.focus ? "#009ca6" : "#445055"
                    border.width: 1
                    radius: 6
                }

                // Only update on focus lost or Enter key
                onEditingFinished: {
                    if (orderQuestion) {
                        let words = splitSentenceIntoWords(text);
                        orderQuestion.words = words;
                        console.log("Sentence finalized. Words:", words);
                    }
                }

                // Initialize text from orderQuestion
                Component.onCompleted: {
                    if (orderQuestion && orderQuestion.words) {
                        text = orderQuestion.words.join(" ");
                    }
                }
            }
        }

        // Words Preview Section
        Rectangle {
            id: wordsPreviewArea
            width: parent.width
            height: Math.round(180 * root.ui)
            color: "#232f34"
            border.color: "#009ca6"
            border.width: 1
            radius: 8

            Column {
                anchors.fill: parent
                anchors.margins: root.pad
                spacing: root.gap

                Text {
                    text: "Words Preview (" + (orderQuestion.words ? orderQuestion.words.length : 0) + " words)"
                    color: "#009ca6"
                    font.pixelSize: root.fs
                    font.bold: true
                    width: parent.width
                }

                ScrollView {
                    width: parent.width
                    height: parent.height - Math.round(40 * root.ui)
                    clip: true

                    Flow {
                        id: wordsFlow
                        width: parent.width
                        spacing: Math.round(8 * root.ui)

                        Repeater {
                            model: orderQuestion && orderQuestion.words ? orderQuestion.words : []

                            Rectangle {
                                width: wordText.contentWidth + Math.round(16 * root.ui)
                                height: root.optRowH
                                radius: height / 2
                                color: "#009ca6"
                                border.color: "#FFFFFF"
                                border.width: 1

                                Text {
                                    id: wordText
                                    text: (index + 1) + ". " + modelData
                                    anchors.centerIn: parent
                                    color: "#FFFFFF"
                                    font.pixelSize: root.fsSmall
                                    font.bold: true
                                }
                            }
                        }
                    }

                    // Empty state
                    Text {
                        anchors.centerIn: parent
                        text: "No words yet.\nEnter a sentence above to see words."
                        color: "#666666"
                        font.pixelSize: root.fsSmall
                        horizontalAlignment: Text.AlignHCenter
                        visible: !orderQuestion.words || orderQuestion.words.length === 0
                    }
                }
            }
        }
    }
}
