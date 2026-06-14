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

    property var fillList: []
    property int fillIndex
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
            title: "Fill With Color"
            onCloseClicked: sideBar.fillwColorVisible = false
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
                    model: root.fillList
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        width: ListView.view ? ListView.view.width : 0
                        height: 46
                        radius: 6
                        color: "#1A2327"
                        border.color: "#2f4751"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            AppTextField {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                horizontalAlignment: Text.AlignHCenter
                                placeholderText: "Ex: #00ff55"
                                text: modelData.color
                                onTextEdited: modelData.color = text
                            }
                            AppTextField {
                                Layout.preferredWidth: 56
                                Layout.preferredHeight: 30
                                horizontalAlignment: Text.AlignHCenter
                                placeholderText: "0–1"
                                text: modelData.opacity
                                validator: DoubleValidator { bottom: 0.0; top: 1.0 }
                                onTextEdited: modelData.opacity = Number(text)
                            }
                            AppCheckBox {
                                text: "Round"
                                checked: modelData.isRound
                                onCheckedChanged: modelData.isRound = checked
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
                sideBar.fillwColorVisible = false;
            } else if (kind === "answer") {
                root.removeAnswer(idx);
            }
        }
    }
}
