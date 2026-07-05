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

    // Browse an image file for a fill block. The target answer is captured
    // when the dialog is opened; the picked path is stored relative to books/.
    property var imgTarget: null
    FileDialog {
        id: imgFileDialog
        title: "Select an Image"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.gif *.bmp *.webp)", "All files (*)"]
        onAccepted: {
            var sel = imgFileDialog.file + "";
            if (sel && root.imgTarget) {
                var rel = sideBar.findBooksFolder(sel, "books");
                if (rel)
                    root.imgTarget.imagePath = rel;
                else
                    console.log("Books klasörü bulunamadı.");
            }
            root.imgTarget = null;
        }
        onRejected: root.imgTarget = null
    }

    function baseName(p) {
        return p ? p.substring(p.lastIndexOf("/") + 1) : "";
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
                        height: 84
                        radius: 6
                        color: "#1A2327"
                        border.color: "#2f4751"
                        border.width: 1

                        readonly property bool hasImage:
                            modelData.imagePath !== undefined && modelData.imagePath !== ""

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            // Row 1: color / opacity / round / delete
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                AppTextField {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 30
                                    horizontalAlignment: Text.AlignHCenter
                                    // Dimmed while an image overrides the color.
                                    opacity: hasImage ? 0.45 : 1.0
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

                            // Row 2: image (browse a file / crop from page / clear)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                AppTextField {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 30
                                    horizontalAlignment: Text.AlignHCenter
                                    placeholderText: "No image — color fill"
                                    readOnly: true
                                    text: hasImage ? root.baseName(modelData.imagePath) : ""
                                }
                                AppButton {
                                    text: "…"
                                    variant: "secondary"
                                    Layout.preferredWidth: 34
                                    Layout.preferredHeight: 30
                                    leftPadding: 0; rightPadding: 0
                                    onClicked: {
                                        root.imgTarget = modelData;
                                        var start = hasImage
                                            ? appPath + modelData.imagePath
                                            : appPath + (page ? page.image_path : "");
                                        imgFileDialog.folder = "file:" + start;
                                        imgFileDialog.open();
                                    }
                                }
                                AppButton {
                                    text: "Crop"
                                    variant: "primary"
                                    Layout.preferredWidth: 62
                                    Layout.preferredHeight: 30
                                    leftPadding: 0; rightPadding: 0
                                    // Draw a rect on the page; that region is
                                    // cropped into this block's image (imagePath).
                                    onClicked: content.startCropMode(modelData, "imagePath")
                                }
                                AppButton {
                                    text: "⌫"
                                    variant: "danger"
                                    enabled: hasImage
                                    opacity: hasImage ? 1.0 : 0.4
                                    Layout.preferredWidth: 30
                                    Layout.preferredHeight: 30
                                    leftPadding: 0; rightPadding: 0
                                    onClicked: modelData.imagePath = ""
                                }
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
