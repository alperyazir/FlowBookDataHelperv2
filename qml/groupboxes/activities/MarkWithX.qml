import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../../newComponents"

// Mark-with-X editor: shared chrome + how many boxes to mark.
ColumnLayout {
    id: markPanel
    spacing: 12

    // The activity's mark colour without "#", for image://markicon.
    readonly property string markColorHex: (root.activityModelData && root.activityModelData.markColor)
                                           ? String(root.activityModelData.markColor).substring(1) : "d2232b"

    ActivityFields {
        Layout.fillWidth: true
        activityModelData: root.activityModelData
        showPath: true
        showCrop: true
        headerPlaceholder: "Mark the right answer."
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Text {
            text: "Mark count"
            color: "#8aa0a8"
            font.pixelSize: 13
            Layout.preferredWidth: 96
        }

        AppTextField {
            id: cbMarkCount
            Layout.preferredWidth: 80
            Layout.preferredHeight: 34
            horizontalAlignment: Text.AlignHCenter
            text: (root.activityModelData && root.activityModelData.markCount) ? root.activityModelData.markCount : 2

            property var allowedValues: [-1, 2, 3, 4, 5, 6, 7, 8, 9]
            validator: RegularExpressionValidator {
                regularExpression: /^(-1|[2-9])$/
            }

            onTextChanged: {
                var numValue = parseInt(text);
                if (allowedValues.includes(numValue))
                    root.activityModelData.markCount = numValue;
            }
            onFocusChanged: {
                if (!focus) {
                    var numValue = parseInt(text);
                    if (!allowedValues.includes(numValue))
                        text = root.activityModelData.markCount.toString();
                }
            }
        }

        Item { Layout.fillWidth: true }
    }

    // What a mark looks like in FlowBook: the default dot, an X or a tick.
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Text {
            text: "Mark type"
            color: "#8aa0a8"
            font.pixelSize: 13
            Layout.preferredWidth: 96
        }

        Repeater {
            model: [
                { value: "dot",  label: "Dot"  },
                { value: "x",    label: "X"    },
                { value: "tick", label: "Tick" }
            ]
            delegate: Rectangle {
                readonly property bool selected: root.activityModelData
                                                 && root.activityModelData.markType === modelData.value
                Layout.preferredWidth: 64
                Layout.preferredHeight: 34
                radius: 2
                color: selected ? "#00e6e6" : (typeArea.containsMouse ? "#2c3b41" : "#232f34")
                border.color: selected ? "#00e6e6" : "#009ca6"
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    // A white chip shows the mark as it sits on a page.
                    Rectangle {
                        width: 20; height: 20; radius: 3
                        color: "white"
                        anchors.verticalCenter: parent.verticalCenter
                        Image {
                            anchors.fill: parent
                            anchors.margins: 2
                            // Same provider FlowBook draws with, in this activity's colour.
                            source: "image://markicon/" + modelData.value + "/" + markPanel.markColorHex
                            sourceSize: Qt.size(32, 32)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                    }
                    Text {
                        text: modelData.label
                        color: selected ? "#10181b" : "white"
                        font.pixelSize: 12
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: typeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.activityModelData) root.activityModelData.markType = modelData.value
                }
            }
        }

        Item { Layout.fillWidth: true }
    }

    // The mark's colour. Empty = FlowBook's answer red (#d2232b), which is
    // also what books without the key get.
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Text {
            text: "Mark color"
            color: "#8aa0a8"
            font.pixelSize: 13
            Layout.preferredWidth: 96
        }

        AppTextField {
            id: markColorField
            Layout.preferredWidth: 90
            Layout.preferredHeight: 34
            horizontalAlignment: Text.AlignHCenter
            placeholderText: "#d2232b"
            text: root.activityModelData ? root.activityModelData.markColor : ""
            // Show the stored value again. Re-bound, not assigned: assigning
            // would cut the binding and the field would keep this activity's
            // colour after the panel switches to another one.
            function showStored() {
                text = Qt.binding(function() { return root.activityModelData ? root.activityModelData.markColor : ""; });
            }
            // Applied once it's a full colour, so typing doesn't flash through
            // invalid values; an emptied field means the default.
            onTextEdited: {
                var t = text.trim();
                if (t === "" || /^#?[0-9a-fA-F]{6}$/.test(t))
                    root.activityModelData.markColor = t === "" ? "" : (t[0] === "#" ? t : "#" + t);
            }
            onEditingFinished: showStored()
        }

        Repeater {
            model: ["#d2232b", "#000000", "#1565c0", "#2e7d32", "#ef6c00", "#6a1b9a"]
            delegate: Rectangle {
                readonly property bool selected: markPanel.markColorHex === modelData.substring(1)
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                radius: 11
                color: modelData
                border.color: selected ? "#00e6e6" : "#445055"
                border.width: selected ? 3 : 1
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.activityModelData)
                            return;
                        root.activityModelData.markColor = modelData;
                        markColorField.showStored();
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }
    }

    // Push the (short) content to the top of the panel.
    Item { Layout.fillHeight: true }
}
