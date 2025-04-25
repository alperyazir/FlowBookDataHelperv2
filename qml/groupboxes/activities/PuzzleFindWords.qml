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
            width: parent.width*.75
            height: parent.height
            placeholderText: "Complete the sentences."
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.activityModelData.headerText
            onTextChanged: {
                root.activityModelData.headerText = text
            }

        }
    }

    GroupBox {
        id: wordsGB
        title: "Words"
        width: parent.width* .9
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
                    width: parent.width*.75
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 30
                    TextField {
                        id: tf
                        width: parent.width*.75
                        height: 30
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: modelData
                        onAccepted: acceptEnter()
                    }

                    Button {
                        text: "X"
                        onClicked: {
                            root.activityModelData.removeWord(index)
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
        saveChanges()
        root.activityModelData.addNewWord("Dummy")
    }

}
