import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform
import QtMultimedia
// import QtQuick.Controls.Material

import "../../qml"

GroupBox {

    property var fillList: []
    property int fillIndex
    property var page
    property int sectionIndex
    signal removeSection(int secIndex)
    signal removeAnswer(int answerIndex)
    id: root
    title: qsTr("Fills")
    width: parent.width * .98
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter

    // Custom title style
    Column {
        anchors.fill: parent
        spacing: 10

        Row {
            height: 40
            anchors.right: parent.right

            Button {
                id: closeButton
                text: "X"
                height: 40
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        sideBar.fillVisible = false
                    }
                }
            }
        }
        ScrollView {
            width: parent.width
            height: 500
            ScrollBar.vertical.interactive: true

            Column {
                width: parent.width
                height: 500 // Column'un height'ini içeriğe göre ayarla
                spacing: 10

                ListView {
                    width: parent.width
                    height: 500
                    id: rectRepeater
                    orientation: ListView.Vertical
                    model: root.fillList
                    clip: true

                    delegate: ItemDelegate {
                        width: parent.width
                        height: 40
                        Row {
                            width: parent.width * .9
                            spacing: 10
                            height: 40

                            FlowText {
                                text: "Fill: "
                                color: "black"
                                anchors.centerIn: undefined
                                width: parent.width * .15
                                font.pixelSize: 15
                                verticalAlignment: Text.AlignBottom
                            }

                            TextField {
                                id: rectTextField
                                width: parent.width * .45
                                height: parent.height
                                text: modelData.text
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                onTextChanged: {
                                    modelData.text = text
                                }
                            }

                            FlowText {
                                text: "Rotation: "
                                color: "black"
                                anchors.centerIn: undefined
                                width: parent.width * .10
                                font.pixelSize: 15
                                verticalAlignment: Text.AlignBottom
                            }

                            SpinBox {
                                id: rectRotationField
                                width: parent.width * .20
                                height: parent.height
                                value: modelData.rotation
                                editable: true
                                from: -180
                                to: 180
                                onValueChanged: {
                                    modelData.rotation = value
                                }
                            }

                            Button {
                                text: "X"
                                height: 40
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        confirmBox.visible = true
                                        confirmBox.type = "answer"
                                        confirmBox.index = index
                                        config.bookSets[0].saveToJson();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        Row {
            height: 40
            anchors.horizontalCenter: parent.horizontalCenter

            Button {
                text: "Save"
                onClicked: {
                    config.bookSets[0].saveToJson();
                    toast.show("Changes are saved to File!")
                }
            }

            Button {
                text: "Delete"
                onClicked: {
                    confirmBox.visible = true
                    confirmBox.type = "section"
                }
            }
        }

        Rectangle {
            property string type
            property int index
            id: confirmBox
            width: parent.width /2
            height: 100
            color: "transparent"
            border.color: "red"
            radius: 10
            visible: false // Başlangıçta visible true, bir işlemi başlatırken görünür olacak
            anchors.horizontalCenter: parent.horizontalCenter

            Column {
                anchors.centerIn: parent
                spacing: 10

                Text {
                    text: "Are you sure?"
                    font.pixelSize: 15
                    color: "white"
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Row {
                    spacing: 20
                    anchors.horizontalCenter: parent.horizontalCenter

                    Button {
                        text: "Yes"
                        onClicked: {
                            if (confirmBox.type === "section") {
                                root.removeSection(root.sectionIndex)
                                sideBar.fillVisible = false
                            } else if (confirmBox.type === "answer") {
                                root.removeAnswer(confirmBox.index)
                            }

                            confirmBox.visible = false
                        }
                    }

                    Button {
                        text: "No"
                        onClicked: {

                            confirmBox.visible = false
                        }
                    }
                }
            }
        }
    }

}

