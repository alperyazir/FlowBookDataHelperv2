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
    // When true each row gets a reading-order badge (click to renumber). Only
    // meaningful where the row order IS the answer (the ordering activity);
    // the plain drag-drop/fill/puzzle word pools leave it off.
    property bool reorderable: false

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
                    model: wl.activityModelData ? wl.activityModelData.words : []
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: RowLayout {
                        width: ListView.view ? ListView.view.width : 0
                        property string wText: tf.text
                        spacing: 6

                        // Reading-order badge (ordering activity only): click to
                        // type a new position. Invisible items are dropped from
                        // the RowLayout, so the pool rows keep their old look.
                        OrderBadge {
                            visible: wl.reorderable
                            diameter: 26
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            number: index + 1
                            total: wordsRepeater.count
                            pillColor: "#E65100"
                            onReorderRequested: (oneBased) => {
                                wl.updateData();
                                wl.activityModelData.moveWord(index, oneBased - 1);
                                config.bookSets[0].saveToJson();
                            }
                        }

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
