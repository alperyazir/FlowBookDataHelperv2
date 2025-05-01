import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform

import "../../../qml"

Column {
    property var words: wordsRepeater
    width: parent.width

    Row {
        width: parent.width * .9
        spacing: 10
        height: 40
        FlowText {
            id: textType
            text: "Type: "
            color: "white"
            anchors.centerIn: undefined
            width: parent.width * .15
            font.pixelSize: 15
            verticalAlignment: Text.AlignBottom
        }

        FlowText {
            text: activityModelData.type
            color: "white"
            anchors.centerIn: undefined
            font.pixelSize: 15
            verticalAlignment: Text.AlignBottom
        }
    }

    Row {
        width: parent.width * .9
        spacing: 10
        height: 40
        FlowText {
            text: "Header: "
            color: "white"
            anchors.centerIn: undefined
            width: parent.width * .15
            font.pixelSize: 15
            verticalAlignment: Text.AlignBottom
        }

        // TextEdit bileşeni
        TextField {
            width: parent.width * .75
            height: parent.height
            placeholderText: "Complete the sentences."
            placeholderTextColor: "gray"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.activityModelData.headerText
            onTextChanged: {
                root.activityModelData.headerText = text;
            }
            background: Rectangle {
                color: "#1A2327"
                border.color: parent.focus ? "#009ca6" : "#445055"
                border.width: 1
                radius: 4
            }
        }
    }

    GroupBox {
        id: wordsGB
        title: "Words"
        width: parent.width * .9
        anchors.horizontalCenter: parent.horizontalCenter
        Column {
            width: parent.width * .9
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2
            Repeater {
                id: wordsRepeater
                model: root.activityModelData.words
                Row {
                    property string wText: tf.text
                    width: parent.width * .75
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 30
                    TextField {
                        id: tf
                        width: parent.width * .75
                        height: 30
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: modelData
                        onAccepted: acceptEnter()
                        background: Rectangle {
                            color: "#1A2327"
                            border.color: parent.focus ? "#009ca6" : "#445055"
                            border.width: 1
                            radius: 4
                        }
                    }

                    Button {
                        width: 30
                        height: 30
                        anchors.verticalCenter: parent.verticalCenter
                        text: "X"

                        background: Rectangle {
                            color: parent.hovered ? "#bf4040" : "#a63030"
                            radius: 4
                        }

                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.activityModelData.removeWord(index);
                            }
                        }
                    }
                }
            }

            Button {
                text: "Add New"
                anchors.horizontalCenter: parent.horizontalCenter
                onClicked: acceptEnter()
            }
        }
    }

    function acceptEnter() {
        saveChanges();
        root.activityModelData.addNewWord("Dummy");
    }
}
