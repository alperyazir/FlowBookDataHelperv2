import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../../newComponents"

// Puzzle-find-words editor: shared chrome (no section image, so no
// Path/Crop) + an editable word pool.
ColumnLayout {
    spacing: 12

    function updateData() {
        wordList.updateData();
    }

    ActivityFields {
        Layout.fillWidth: true
        activityModelData: root.activityModelData
        showPath: false
        showCrop: false
        headerPlaceholder: "Find the words."
    }

    WordList {
        id: wordList
        Layout.fillWidth: true
        Layout.fillHeight: true
        activityModelData: root.activityModelData
        title: "Words"
    }
}
