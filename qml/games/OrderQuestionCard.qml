import QtQuick 2.15
import QtQuick.Controls 2.15
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

    width: parent.width
    height: parent.height
    radius: 8
    color: "#1A2327" // Ana tema rengi
    border.color: "#009ca6" // Turquoise border
    border.width: 1

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
                text: "Order Question #" + questionId
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
                        print("deleting Order Question");
                        questionDeleted();
                    }
                }
            }
        }

        // Main content area
        Column {
            id: mainContentColumn
            width: parent.width
            height: parent.height * 0.75
            spacing: 15

            // Sentence Input Row
            Row {
                id: sentenceInputRow
                width: parent.width
                height: parent.height * 0.25

                Text {
                    text: "Sentence:"
                    width: parent.width / 7
                    height: parent.height
                    color: "#FFFFFF" // White text
                    font.pixelSize: root.height * 0.06
                    verticalAlignment: Text.AlignVCenter
                }

                TextField {
                    id: sentenceTextField
                    width: parent.width / 7 * 6
                    height: parent.height
                    color: "#FFFFFF" // White text
                    font.pixelSize: root.height * 0.06
                    placeholderText: "Enter a sentence to be split into words for ordering..."
                    placeholderTextColor: "#666666"

                    background: Rectangle {
                        color: "#232f34" // Darker background
                        border.color: sentenceTextField.focus ? "#009ca6" : "#445055"
                        border.width: 1
                        radius: 4
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
                height: parent.height * 0.7  // Increased from 0.6 to 0.7 since we removed info text
                color: "#232f34"
                border.color: "#009ca6"
                border.width: 1
                radius: 8
                anchors.leftMargin: 10
                anchors.rightMargin: 10

                Column {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 10

                    Text {
                        text: "Words Preview (" + (orderQuestion.words ? orderQuestion.words.length : 0) + " words)"
                        color: "#009ca6"
                        font.pixelSize: root.height * 0.05
                        font.bold: true
                        width: parent.width
                    }

                    ScrollView {
                        width: parent.width
                        height: parent.height - 40
                        clip: true

                        Flow {
                            id: wordsFlow
                            width: parent.width
                            spacing: 8

                            Repeater {
                                model: orderQuestion && orderQuestion.words ? orderQuestion.words : []

                                Rectangle {
                                    width: wordText.contentWidth + 16
                                    height: 30
                                    radius: 15
                                    color: "#009ca6"
                                    border.color: "#FFFFFF"
                                    border.width: 1

                                    Text {
                                        id: wordText
                                        text: (index + 1) + ". " + modelData
                                        anchors.centerIn: parent
                                        color: "#FFFFFF"
                                        font.pixelSize: root.height * 0.04
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
                            font.pixelSize: root.height * 0.04
                            horizontalAlignment: Text.AlignHCenter
                            visible: !orderQuestion.words || orderQuestion.words.length === 0
                        }
                    }
                }
            }
        }
    }
}
