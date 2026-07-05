import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Bottom-right toast for remote updates. Reader builds sync silently in the
// background; this surfaces (a) download/install progress and (b) the prompt to
// apply a newer editor (which quits + relaunches via the updater helper).
//
// Drives entirely off the `updater` context property. Non-blocking: it never
// covers the whole UI, so the user can keep working while readers download and
// choose when to apply an editor update.
Item {
    id: root
    anchors.fill: parent
    z: 90000  // above the app, below the LockScreen (100000)

    // The user dismissed the editor-update prompt this session ("Later").
    property bool dismissed: false
    // Transient error text from the updater (shown briefly).
    property string errorText: ""

    // Show while working, while an un-dismissed editor update is offered, or
    // while an error is being surfaced.
    readonly property bool shouldShow:
        updater.busy || (updater.editorUpdateAvailable && !dismissed) || errorText !== ""

    Connections {
        target: updater
        function onError(message) {
            root.errorText = message
            errorClear.restart()
        }
        // A fresh editor update showing up re-arms the prompt.
        function onEditorUpdateAvailableChanged() {
            if (updater.editorUpdateAvailable)
                root.dismissed = false
        }
    }

    Timer {
        id: errorClear
        interval: 8000
        onTriggered: root.errorText = ""
    }

    Rectangle {
        id: card
        width: Math.min(440, parent.width - 40)
        implicitHeight: content.implicitHeight + 32
        height: implicitHeight
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 20
        radius: 12
        color: "#2b3a41"
        border.color: root.errorText !== "" ? "#bc262c" : "#3d5059"
        border.width: 1

        // Slide/fade in from below.
        opacity: root.shouldShow ? 1 : 0
        transform: Translate { y: root.shouldShow ? 0 : 30 }
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: 180 } }

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: 16
            spacing: 10

            // Title row
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: root.errorText !== "" ? "⚠️"
                          : updater.busy ? "⬇️" : "✨"
                    font.pixelSize: 20
                }
                Text {
                    Layout.fillWidth: true
                    color: "white"
                    font.pixelSize: 15
                    font.bold: true
                    wrapMode: Text.WordWrap
                    text: root.errorText !== "" ? "Güncelleme hatası"
                          : updater.busy ? "Güncelleniyor…"
                          : ("Yeni sürüm hazır: " + updater.editorUpdateVersion)
                }
            }

            // Detail / status line
            Text {
                Layout.fillWidth: true
                color: "#b8c6cd"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                visible: text !== ""
                text: root.errorText !== "" ? root.errorText
                      : updater.busy ? updater.statusMessage
                      : "Uygulama kapanıp yeni sürümle yeniden başlayacak."
            }

            // Progress bar while downloading/installing.
            ProgressBar {
                Layout.fillWidth: true
                visible: updater.busy && updater.progress > 0
                from: 0; to: 100
                value: updater.progress
            }

            // Action row (only for the editor-update prompt, not while busy).
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: !updater.busy && updater.editorUpdateAvailable && root.errorText === ""

                Item { Layout.fillWidth: true }

                Button {
                    text: "Daha sonra"
                    flat: true
                    onClicked: root.dismissed = true
                }
                Button {
                    text: "Güncelle ve yeniden başlat"
                    highlighted: true
                    onClicked: updater.applyEditorUpdate()
                }
            }
        }
    }
}
