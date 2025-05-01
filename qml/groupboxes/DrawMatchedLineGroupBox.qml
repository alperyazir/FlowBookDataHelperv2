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
    padding: 15

    background: Rectangle {
        color: "#232f34"
        border.color: "#009ca6"
        border.width: 1
        radius: 6
    }

    property var drawMatchedLineList: []
    property int fillIndex
    property var page
    property int sectionIndex
    signal removeSection(int secIndex)
    signal removeAnswer(int answerIndex)

    Column {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 15

        // Header with title and close button
        Row {
            width: parent.width
            height: 40
            spacing: 10

            Text {
                text: "Draw Matched Lines"
                color: "white"
                font.pixelSize: 24
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }

            Item {
                width: parent.width - closeButton.width - 80
                height: 1
            }

            Button {
                id: closeButton
                text: "X"
                width: 32
                height: 32
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
                        sideBar.drawMatchedVisible = false;
                    }
                }
            }
        }

        ScrollView {
            width: parent.width
            height: 500
            ScrollBar.vertical.interactive: true
            clip: true

            Column {
                width: parent.width
                spacing: 10

                ListView {
                    id: rectRepeater
                    width: parent.width
                    height: 500
                    orientation: ListView.Vertical
                    model: root.drawMatchedLineList
                    clip: true

                    delegate: ItemDelegate {
                        width: parent.width
                        height: 50
                        background: Rectangle {
                            color: "#1A2327"
                            border.color: "#445055"
                            border.width: 1
                            radius: 4
                        }

                        Row {
                            width: parent.width - 40
                            height: parent.height
                            spacing: 10
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10

                            Text {
                                text: "Color:"
                                color: "white"
                                font.pixelSize: 14
                                width: 45
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            TextField {
                                id: rectTextField
                                width: parent.width * 0.25
                                height: 36
                                text: modelData.color
                                color: "white"
                                placeholderText: "Ex: #00ff55"
                                horizontalAlignment: Text.AlignHCenter

                                background: Rectangle {
                                    color: "#1A2327"
                                    border.color: parent.focus ? "#009ca6" : "#445055"
                                    border.width: 1
                                    radius: 4
                                }

                                onTextChanged: {
                                    modelData.color = text;
                                }
                            }

                            Text {
                                text: "Opacity:"
                                color: "white"
                                font.pixelSize: 14
                                width: 60
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            TextField {
                                id: rectTextOpacity
                                width: parent.width * 0.15
                                height: 36
                                text: modelData.opacity
                                color: "white"
                                placeholderText: "0.5"
                                horizontalAlignment: Text.AlignHCenter

                                background: Rectangle {
                                    color: "#1A2327"
                                    border.color: parent.focus ? "#009ca6" : "#445055"
                                    border.width: 1
                                    radius: 4
                                }

                                onTextChanged: {
                                    modelData.opacity = Number(text);
                                    config.bookSets[0].saveToJson();
                                }
                            }

                            CheckBox {
                                id: isRoubdCb
                                text: "Round"
                                height: parent.height
                                width: parent.width * 0.2
                                checked: modelData.isRound

                                contentItem: Text {
                                    text: isRoubdCb.text
                                    color: "white"
                                    font.pixelSize: 14
                                    verticalAlignment: Text.AlignVCenter
                                    leftPadding: isRoubdCb.indicator.width + 8
                                }

                                indicator: Rectangle {
                                    implicitWidth: 20
                                    implicitHeight: 20
                                    x: isRoubdCb.leftPadding
                                    y: parent.height / 2 - height / 2
                                    radius: 4
                                    color: "#1A2327"
                                    border.color: isRoubdCb.checked ? "#009ca6" : "#445055"
                                    border.width: 1

                                    Rectangle {
                                        width: 12
                                        height: 12
                                        anchors.centerIn: parent
                                        radius: 2
                                        color: "#009ca6"
                                        visible: isRoubdCb.checked
                                    }
                                }

                                onCheckedChanged: {
                                    modelData.isRound = isRoubdCb.checked;
                                }
                            }

                            Button {
                                width: 32
                                height: 32
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
            height: 36

            Button {
                text: "Save"
                width: 80
                height: parent.height

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
                width: 80
                height: parent.height

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
            width: parent.width * 0.8
            height: 120
            color: "#1A2327"
            border.color: "#a63030"
            border.width: 1
            radius: 6
            visible: false
            anchors.horizontalCenter: parent.horizontalCenter

            Column {
                anchors.centerIn: parent
                spacing: 15

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
                                sideBar.drawMatchedVisible = false;
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
