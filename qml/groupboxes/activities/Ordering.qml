import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../../newComponents"

// Ordering editor: shared chrome + the list of CORRECT sentences.
// Each row is one sentence in its correct word order; the reader shuffles the
// words of each sentence at display time ("Put the words in the correct
// order."). Stored in the model's `words` array (one entry per sentence) — no
// disk-shuffle applies to "ordering", so the correct order is preserved.
// No section image: Crop only reads the answer sentences from the answered PDF.
// `root` resolves to the enclosing ActivityGroupBox via the sidebar context.
ColumnLayout {
    spacing: 12

    function updateData() {
        sentenceList.updateData();
    }

    ActivityFields {
        Layout.fillWidth: true
        activityModelData: root.activityModelData
        showPath: false
        showCrop: true
        headerPlaceholder: "Put the words in the correct order."
    }

    WordList {
        id: sentenceList
        Layout.fillWidth: true
        Layout.fillHeight: true
        activityModelData: root.activityModelData
        title: "Correct sentences"
        // The row order is the correct answer, so let it be reordered.
        reorderable: true
    }
}
