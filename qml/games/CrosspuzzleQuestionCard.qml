import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window
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

    // Everything scales with the window height (1080 baseline) instead of
    // fixed pixels, so the card stays proportional on any screen — while the
    // card's *total* height still follows its content (no cramping).
    readonly property real ui: Window.height > 0 ? Window.height / 1080 : 1.0
    readonly property int labelW: Math.round(80 * ui)
    readonly property int rowH: Math.round(38 * ui)
    readonly property int pad: Math.round(12 * ui)
    readonly property int gap: Math.round(10 * ui)
    readonly property int fsTitle: Math.round(16 * ui)
    readonly property int fs: Math.round(14 * ui)

    Component.onCompleted: {
        console.log("Crosspuzzle question loaded. Single answer structure.");
    }

    width: parent ? parent.width : 600
    // Height follows the content so a card never leaves a big empty gap.
    implicitHeight: contentColumn.implicitHeight + 2 * pad
    height: implicitHeight
    radius: 8
    color: "#1A2327"
    border.color: "#009ca6"
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
                text: "Crosspuzzle Question #" + questionId
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
                        print("deleting Crosspuzzle Question");
                        questionDeleted();
                    }
                }
            }
        }

        // Question Text Section
        Row {
            width: parent.width
            height: root.rowH
            spacing: root.gap

            Text {
                width: root.labelW
                height: parent.height
                text: "Question:"
                color: "#FFFFFF"
                font.pixelSize: root.fs
                verticalAlignment: Text.AlignVCenter
            }

            TextField {
                id: questionTextField
                width: parent.width - root.labelW - root.gap
                height: parent.height
                text: crosspuzzleQuestion && crosspuzzleQuestion.question ? crosspuzzleQuestion.question : ""
                color: "#FFFFFF"
                font.pixelSize: root.fs
                placeholderText: "Enter crosspuzzle question text..."
                placeholderTextColor: "#666666"
                background: Rectangle {
                    color: "#232f34"
                    border.color: questionTextField.focus ? "#009ca6" : "#445055"
                    border.width: 1
                    radius: 6
                }
                onTextChanged: {
                    if (crosspuzzleQuestion) {
                        crosspuzzleQuestion.question = text;
                    }
                }
            }
        }

        // Single Answer Section
        Row {
            width: parent.width
            height: root.rowH
            spacing: root.gap

            Text {
                width: root.labelW
                height: parent.height
                text: "Answer:"
                color: "#FFFFFF"
                font.pixelSize: root.fs
                verticalAlignment: Text.AlignVCenter
            }

            TextField {
                id: answerTextField
                width: parent.width - root.labelW - root.gap
                height: parent.height
                text: {
                    if (crosspuzzleQuestion && crosspuzzleQuestion.answers && crosspuzzleQuestion.answers.length > 0) {
                        return crosspuzzleQuestion.answers[0].text || "";
                    }
                    return "";
                }
                color: "#FFFFFF"
                font.pixelSize: root.fs
                placeholderText: "Enter the answer..."
                placeholderTextColor: "#666666"
                background: Rectangle {
                    color: "#232f34"
                    border.color: answerTextField.focus ? "#009ca6" : "#445055"
                    border.width: 1
                    radius: 6
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
