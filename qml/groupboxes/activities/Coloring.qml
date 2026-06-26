import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "../../newComponents"

// Coloring editor — the simplest activity: a child colours the cropped outline
// drawing in the reader. Free mode, so there are no answers/words/targets to
// author; the author only crops the outline image (Crop sets sectionPath +
// image_coords) and optionally types a header.
ColumnLayout {
    spacing: 12

    // Called by ActivityGroupBox.saveRemains(); nothing to flush here.
    function updateData() {}

    ActivityFields {
        Layout.fillWidth: true
        activityModelData: root.activityModelData
        showPath: true
        showCrop: true
        headerPlaceholder: "Colour the picture."
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 4
        wrapMode: Text.WordWrap
        color: "#8aa0a8"
        font.pixelSize: 12
        text: qsTr("Crop a clean line-art region: closed, dark outlines over a "
                   + "white/transparent interior. Open lines let the bucket leak "
                   + "between regions.")
    }

    // Coloring has no word/answer list to fill the panel (unlike fillpicture's
    // WordList), so this spacer absorbs the slack — keeping the fields anchored
    // right under the header, consistent with the other activity panels.
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
    }
}
