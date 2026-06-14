import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform

import "../../qml"
import "../newComponents"

GroupBox {
    id: root
    title: ""
    width: parent.width * .98
    padding: 14
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter

    property var circleList: []
    property int circleIndex
    property var page
    property int sectionIndex
    signal removeSection(int secIndex)
    signal removeAnswer(int answerIndex)

    background: Rectangle {
        color: "#232f34"
        border.color: "#009ca6"
        border.width: 1
        radius: 8
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        PanelHeader {
            Layout.fillWidth: true
            title: "Circle"
            onCloseClicked: sideBar.circleVisible = false
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#2a3f48" }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            color: "#16242b"
            border.color: "#2a3f48"
            border.width: 1

            ScrollView {
                anchors.fill: parent
                anchors.margins: 8
                clip: true

                ListView {
                    id: rectRepeater
                    spacing: 6
                    model: root.circleList
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        width: ListView.view ? ListView.view.width : 0
                        height: 44
                        radius: 6
                        color: "#1A2327"
                        border.color: "#2f4751"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            spacing: 8

                            AppCheckBox {
                                text: "Is Correct"
                                checked: modelData.isCorrect || false
                                Layout.fillWidth: true
                                onCheckedChanged: modelData.isCorrect = checked
                            }

                            AppButton {
                                text: "✕"
                                variant: "danger"
                                Layout.preferredWidth: 30
                                Layout.preferredHeight: 30
                                leftPadding: 0; rightPadding: 0
                                onClicked: confirmBox.ask("answer", index)
                            }
                        }
                    }
                }
            }
        }

        AppButton {
            text: "Delete"
            variant: "danger"
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            onClicked: confirmBox.ask("section", -1)
        }
    }

    ConfirmDelete {
        id: confirmBox
        onConfirmed: function(kind, idx) {
            if (kind === "section") {
                root.removeSection(root.sectionIndex);
                sideBar.circleVisible = false;
            } else if (kind === "answer") {
                root.removeAnswer(idx);
            }
        }
    }
}
