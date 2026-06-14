import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The simple editable word pool shared by dragdrop / fill / puzzle
// activities. Each row is one word; the host calls updateData() before
// saving to flush edits back into the model's `words` array.
ColumnLayout {
    id: wl

    property var activityModelData: ({})
    property string title: "Words"

    spacing: 8

    function updateData() {
        for (var i = 0; i < wordsRepeater.count; i++) {
            var item = wordsRepeater.itemAtIndex(i);
            if (item !== null)
                wl.activityModelData.words[i] = item.wText;
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: wl.title
            color: "#cfe8ea"
            font.pixelSize: 14
            font.bold: true
            Layout.fillWidth: true
        }
        Text {
            text: wordsRepeater.count + (wordsRepeater.count === 1 ? " word" : " words")
            color: "#5e7178"
            font.pixelSize: 12
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 8
        color: "#16242b"
        border.color: "#2a3f48"
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ListView {
                    id: wordsRepeater
                    spacing: 5
                    model: wl.activityModelData.words
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: RowLayout {
                        width: ListView.view ? ListView.view.width : 0
                        property string wText: tf.text
                        spacing: 6

                        AppTextField {
                            id: tf
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            onAccepted: {
                                wl.updateData();
                                focus = false;
                            }
                        }

                        AppButton {
                            text: "✕"
                            variant: "danger"
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            leftPadding: 0
                            rightPadding: 0
                            onClicked: wl.activityModelData.removeWord(index)
                        }
                    }
                }
            }

            AppButton {
                text: "+  Add word"
                variant: "secondary"
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                onClicked: {
                    wl.updateData();
                    wl.activityModelData.addNewWord("");
                }
            }
        }
    }
}
