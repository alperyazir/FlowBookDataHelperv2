import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../../newComponents"

// Fill-picture editor: shared chrome + an editable word pool.
ColumnLayout {
    spacing: 12

    function updateData() {
        wordList.updateData();
    }

    ActivityFields {
        Layout.fillWidth: true
        activityModelData: root.activityModelData
        showPath: true
        showCrop: true
        headerPlaceholder: "Complete the sentences."
    }

    WordList {
        id: wordList
        Layout.fillWidth: true
        Layout.fillHeight: true
        activityModelData: root.activityModelData
        title: "Words"
    }
}
