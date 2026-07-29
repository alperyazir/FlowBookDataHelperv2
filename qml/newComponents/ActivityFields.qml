import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform

// Shared "chrome" for every activity side panel: the Type badge, the
// Header field (+ Pick), the image Path field (+ browse) and the Crop
// action. Activities that don't have a single section image hide the
// Path/Crop rows via showPath / showCrop.
//
// `content`, `appPath` and findBooksFolder() resolve through the
// surrounding sidebar context, exactly like the old per-activity copies did.
ColumnLayout {
    id: fields

    property var activityModelData: ({})
    property bool showPath: true
    property bool showCrop: true
    property string headerPlaceholder: "Complete the sentences."
    // Answer text size, in the reader. Only fillpicture and matchthewords read
    // it, so only their panels turn this on; every other activity ignores the
    // field entirely and offering it there would promise something that never
    // happens. `defaultFontSize` is what the reader falls back to when unset —
    // shown as the placeholder so the author can see what empty means.
    property bool showFontSize: false
    property int defaultFontSize: 0

    readonly property int labelW: 60

    function fontSizeText() {
        return (fields.activityModelData && fields.activityModelData.textFontSize > 0)
               ? String(fields.activityModelData.textFontSize) : "";
    }

    spacing: 8

    FileDialog {
        id: fileDialog
        title: "Select a File"
        onAccepted: {
            var selectedFilePath = fileDialog.file + "";
            if (selectedFilePath) {
                var newPath = findBooksFolder(selectedFilePath, "books");
                if (newPath)
                    fields.activityModelData.sectionPath = newPath;
                else
                    console.log("Books klasörü bulunamadı.");
            } else {
                console.log("Dosya yolu geçersiz.");
            }
        }
        onRejected: console.log("File selection was canceled")
    }

    // --- Type ---
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Text {
            text: "Type"
            color: "#8aa0a8"
            font.pixelSize: 13
            Layout.preferredWidth: fields.labelW
            horizontalAlignment: Text.AlignLeft
        }

        Rectangle {
            radius: 11
            height: 22
            Layout.preferredWidth: typeBadge.implicitWidth + 22
            color: "#11343a"
            border.color: "#1c5a63"
            border.width: 1
            Text {
                id: typeBadge
                anchors.centerIn: parent
                text: (fields.activityModelData && fields.activityModelData.type) || ""
                color: "#4fd2dc"
                font.pixelSize: 12
                font.bold: true
            }
        }

        Item { Layout.fillWidth: true }
    }

    // --- Header (+ Pick) ---
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Text {
            text: "Header"
            color: "#8aa0a8"
            font.pixelSize: 13
            Layout.preferredWidth: fields.labelW
            horizontalAlignment: Text.AlignLeft
        }

        AppTextField {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            placeholderText: fields.headerPlaceholder
            text: (fields.activityModelData && fields.activityModelData.headerText) || ""
            onTextEdited: if (fields.activityModelData) fields.activityModelData.headerText = text
        }

        // Draw a rect on the page; the instruction text inside it becomes
        // the headerText (read from the original PDF).
        AppButton {
            text: "Pick"
            variant: "primary"
            Layout.preferredWidth: 58
            Layout.preferredHeight: 34
            onClicked: content.startHeaderPickMode(fields.activityModelData)
        }
    }

    // --- Font size ---
    RowLayout {
        visible: fields.showFontSize
        Layout.fillWidth: true
        spacing: 10

        Text {
            text: "Font"
            color: "#8aa0a8"
            font.pixelSize: 13
            Layout.preferredWidth: fields.labelW
            horizontalAlignment: Text.AlignLeft
        }

        AppTextField {
            id: fontSizeField
            Layout.preferredWidth: 90
            Layout.preferredHeight: 34
            placeholderText: fields.defaultFontSize + " (default)"
            // 0 in the data means "use the default", so it shows as empty
            // rather than as a literal 0 the author might take for a real size.
            text: fields.fontSizeText()
            // Typing breaks that binding, which is what keeps the field showing
            // what was typed. Restore it on focus loss so this field follows
            // the copy in the activity dialog header.
            onActiveFocusChanged: if (!activeFocus)
                                      text = Qt.binding(fields.fontSizeText)
            inputMethodHints: Qt.ImhDigitsOnly
            validator: IntValidator { bottom: 0; top: 200 }
            // On every keystroke, not on commit: the activity preview binds to
            // this value, so typing a size shows it growing straight away.
            onTextEdited: {
                if (!fields.activityModelData)
                    return;
                var v = parseInt(text, 10);
                fields.activityModelData.textFontSize = (isNaN(v) || v <= 0) ? 0 : v;
            }
        }

        Text {
            text: "px — clear for default"
            color: "#5e7178"
            font.pixelSize: 12
            Layout.fillWidth: true
        }
    }

    // --- Path (+ browse + Crop) ---
    RowLayout {
        visible: fields.showPath
        Layout.fillWidth: true
        spacing: 10

        Text {
            text: "Path"
            color: "#8aa0a8"
            font.pixelSize: 13
            Layout.preferredWidth: fields.labelW
            horizontalAlignment: Text.AlignLeft
        }

        AppTextField {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            placeholderText: "Enter image path"
            text: (fields.activityModelData && fields.activityModelData.sectionPath) || ""
            onEditingFinished: if (fields.activityModelData) fields.activityModelData.sectionPath = text
        }

        AppButton {
            text: "…"
            variant: "secondary"
            Layout.preferredWidth: 40
            Layout.preferredHeight: 34
            leftPadding: 0
            rightPadding: 0
            onClicked: {
                fileDialog.folder = "file:" + appPath + fields.activityModelData.sectionPath;
                fileDialog.open();
            }
        }

        AppButton {
            visible: fields.showCrop
            text: "Crop"
            variant: "primary"
            Layout.preferredWidth: 88
            Layout.preferredHeight: 34
            onClicked: content.startCropMode(fields.activityModelData)
        }
    }

    // --- Crop (standalone, for activities without a section image path) ---
    AppButton {
        visible: fields.showCrop && !fields.showPath
        text: "Crop"
        variant: "primary"
        Layout.fillWidth: true
        Layout.leftMargin: fields.labelW + 10
        Layout.preferredHeight: 34
        onClicked: content.startCropMode(fields.activityModelData)
    }
}
