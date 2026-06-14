import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../../newComponents"

// Mark-with-X editor: shared chrome + how many boxes to mark.
ColumnLayout {
    spacing: 12

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

    // Push the (short) content to the top of the panel.
    Item { Layout.fillHeight: true }
}
