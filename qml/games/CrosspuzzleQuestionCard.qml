import QtQuick 2.15
import QtQuick.Controls 2.15
import ".."

Rectangle {
    id: root

    property var crosspuzzleQuestion: ({
            "question": "",
            "answers": []
        })

    // Add question ID property
    property int questionId: 0

    // Signals for external communication
    signal questionDeleted

    Component.onCompleted: {
        console.log("Crosspuzzle question loaded. Single answer structure.");
    }

    width: parent.width
    height: parent.height
    radius: 8
    color: "#1A2327"
    border.color: "#009ca6"
    border.width: 1

    Column {
        id: totalColumn
        width: parent.width
        height: parent.height
        spacing: 8

        // Header Row
        Row {
            id: headerRow
            width: parent.width
            height: parent.height * 0.15  // Increased from 0.1 to 0.15

            Text {
                text: "Crosspuzzle Question #" + questionId
                width: parent.width / 4
                height: parent.height
                color: "#009ca6"
                font.pixelSize: root.height * 0.08  // Increased from 0.06 to 0.08
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
                        print("deleting Crosspuzzle Question");
                        questionDeleted();
                    }
                }
            }
        }

        // Question Text Section
        Rectangle {
            id: questionTextSection
            width: parent.width
            height: parent.height * 0.35  // Increased from 0.2 to 0.35
            color: "#232f34"
            border.color: "#009ca6"
            border.width: 1
            radius: 6

            Row {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                Text {
                    text: "Question:"
                    width: 80
                    height: parent.height
                    color: "#009ca6"
                    font.pixelSize: root.height * 0.07  // Increased from 0.04 to 0.05
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }

                TextField {
                    id: questionTextField
                    width: parent.width - 80 - 10
                    height: parent.height
                    text: crosspuzzleQuestion && crosspuzzleQuestion.question ? crosspuzzleQuestion.question : ""
                    color: "#FFFFFF"
                    font.pixelSize: parent.height * 0.3  // Increased from 0.03 to 0.04
                    placeholderText: "Enter crosspuzzle question text..."
                    placeholderTextColor: "#666666"
                    background: Rectangle {
                        color: "#1A2327"
                        border.color: questionTextField.focus ? "#009ca6" : "#445055"
                        border.width: 1
                        radius: 3
                    }
                    onTextChanged: {
                        if (crosspuzzleQuestion) {
                            crosspuzzleQuestion.question = text;
                        }
                    }
                }
            }
        }

        // Single Answer Section
        Rectangle {
            id: answerSection
            width: parent.width
            height: parent.height * 0.4  // Reduced from 0.6 to 0.4
            color: "#232f34"
            border.color: "#009ca6"
            border.width: 1
            radius: 6

            Row {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                Text {
                    text: "Answer:"
                    width: 80
                    height: parent.height
                    color: "#009ca6"
                    font.pixelSize: root.height * 0.07  // Increased from 0.04 to 0.05
                    font.bold: true
                    verticalAlignment: Text.AlignVCenter
                }

                TextField {
                    id: answerTextField
                    width: parent.width - 80 - 10
                    height: parent.height
                    text: {
                        if (crosspuzzleQuestion && crosspuzzleQuestion.answers && crosspuzzleQuestion.answers.length > 0) {
                            return crosspuzzleQuestion.answers[0].text || "";
                        }
                        return "";
                    }
                    color: "#FFFFFF"
                    font.pixelSize: parent.height * 0.3  // Increased from 0.03 to 0.04
                    placeholderText: "Enter the answer..."
                    placeholderTextColor: "#666666"
                    background: Rectangle {
                        color: "#1A2327"
                        border.color: answerTextField.focus ? "#009ca6" : "#445055"
                        border.width: 1
                        radius: 3
                    }
                    onTextChanged: {
                        if (crosspuzzleQuestion && crosspuzzleQuestion.answers && crosspuzzleQuestion.answers.length > 0) {
                            crosspuzzleQuestion.answers[0].text = text;
                        }
                    }
                }
            }
        }
    }
}
