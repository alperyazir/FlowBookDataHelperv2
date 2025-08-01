import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform
import QtMultimedia
// import QtQuick.Controls.Material

import "../../qml"

GroupBox {
    id: root
    title: ""
    width: parent.width * .98
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.margins: 10
    padding: 10

    background: Rectangle {
        color: "#232f34"
        border.color: "#009ca6"
        border.width: 1
        radius: 6
    }

    property var fillList: []
    property int fillIndex
    property var page
    property int sectionIndex
    signal removeSection(int secIndex)
    signal removeAnswer(int answerIndex)

    Column {
        anchors.fill: parent
        anchors.leftMargin: 5
        anchors.rightMargin: 5
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        // Header with title and close button
        Row {
            width: parent.width
            height: parent.height * 0.1
            spacing: 10

            Text {
                text: "Fill"
                color: "white"
                font.pixelSize: 24
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                width: parent.width - closeButton.width - parent.width*.2
                height: 1
            }

            Button {
                id: closeButton
                text: "X"
                width: height
                height: parent.height / 2
                anchors.verticalCenter: parent.verticalCenter

                background: Rectangle {
                    color: parent.hovered ? "#2A3337" : "#1A2327"
                    border.color: "#009ca6"
                    border.width: 1
                    radius: 4
                }

                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 14
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        sideBar.fillVisible = false;
                    }
                }
            }
        }

        ScrollView {
            id: scrollView
            width: parent.width
            height: parent.height * 0.6 - parent.spacing * 4
            clip: true

            Column {
                width: parent.width
                spacing: 5

                ListView {
                    id: rectRepeater
                    width: parent.width
                    height: scrollView.height * 0.9
                    orientation: ListView.Vertical
                    model: root.fillList
                    clip: true

                    delegate: ItemDelegate {
                        width: parent.width
                        height: scrollView.height / 9
                        background: Rectangle {
                            color: "#1A2327"
                            border.color: "#445055"
                            border.width: 1
                            radius: 4
                        }

                        Row {
                            width: parent.width
                            height: parent.height
                            spacing: 5
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 3
                            anchors.rightMargin: 3
                            anchors.topMargin: 3

                            TextField {
                                id: rectTextField
                                width: parent.width * 0.40
                                height: parent.height
                                text: modelData.text
                                color: "white"

                                background: Rectangle {
                                    color: "#1A2327"
                                    border.color: parent.focus ? "#009ca6" : "#445055"
                                    border.width: 1
                                    radius: 4
                                }

                                onTextChanged: {
                                    modelData.text = text;
                                }
                            }

                            FlowText {
                                text: "Rot:"
                                color: "white"
                                width: parent.width * 0.15
                                height: parent.height
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.centerIn: undefined
                            }

                            SpinBox {
                                id: rectRotationField
                                width: parent.width * 0.25
                                height: parent.height
                                value: modelData.rotation
                                editable: true
                                from: -180
                                to: 180

                                background: Rectangle {
                                    color: "#1A2327"
                                    border.color: parent.focus ? "#009ca6" : "#445055"
                                    border.width: 1
                                    radius: 4
                                }

                                contentItem: TextInput {
                                    text: rectRotationField.textFromValue(rectRotationField.value, rectRotationField.locale)
                                    color: "white"
                                    horizontalAlignment: Qt.AlignHCenter
                                    verticalAlignment: Qt.AlignVCenter
                                }

                                onValueChanged: {
                                    modelData.rotation = value;
                                }
                            }

                            Button {
                                width: parent.width * 0.10
                                height: parent.height * 0.8
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
                                        confirmBox.visible = true;
                                        confirmBox.type = "answer";
                                        confirmBox.index = index;
                                        config.bookSets[0].saveToJson();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Save/Delete buttons
        Row {
            spacing: 10
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: parent.height * 0.1

            Button {
                text: "Save"
                width: parent.width / 3
                height: parent.height * .8

                background: Rectangle {
                    color: parent.hovered ? "#00b3be" : "#009ca6"
                    radius: 4
                }

                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    config.bookSets[0].saveToJson();
                    toast.show("Changes are saved to File!");
                }
            }

            Button {
                text: "Delete"
                width: parent.width / 3
                height: parent.height * .8

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

                onClicked: {
                    confirmBox.visible = true;
                    confirmBox.type = "section";
                }
            }
        }

        // Confirmation dialog
        Rectangle {
            id: confirmBox
            property string type
            property int index
            color: "#1A2327"
            border.color: "#a63030"
            border.width: 1
            radius: 6
            visible: false
            anchors.horizontalCenter: parent.horizontalCenter
            height: parent.height * 0.2
            width: parent.width * 0.8

            Column {
                anchors.centerIn: parent
                spacing: 5

                Text {
                    text: "Are you sure you want to delete?"
                    font.pixelSize: 16
                    color: "white"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Row {
                    spacing: 20
                    anchors.horizontalCenter: parent.horizontalCenter

                    Button {
                        text: "Yes"
                        width: 80
                        height: 36

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

                        onClicked: {
                            if (confirmBox.type === "section") {
                                root.removeSection(root.sectionIndex);
                                sideBar.fillVisible = false;
                            } else if (confirmBox.type === "answer") {
                                root.removeAnswer(confirmBox.index);
                            }
                            confirmBox.visible = false;
                        }
                    }

                    Button {
                        text: "No"
                        width: 80
                        height: 36

                        background: Rectangle {
                            color: parent.hovered ? "#2A3337" : "#1A2327"
                            border.color: "#445055"
                            border.width: 1
                            radius: 4
                        }

                        contentItem: Text {
                            text: parent.text
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            confirmBox.visible = false;
                        }
                    }
                }
            }
        }

    }
}
