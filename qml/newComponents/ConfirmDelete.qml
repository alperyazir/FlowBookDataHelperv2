import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Shared delete-confirmation overlay. Place it as a direct child of the
// panel (a sibling of the content layout) so it floats centered on top.
// Call ask(kind, index); on "Yes" it emits confirmed(kind, index).
Rectangle {
    id: cd

    property string message: "Are you sure you want to delete?"
    property string pendingKind
    property int pendingIndex
    signal confirmed(string kind, int idx)

    function ask(kind, index) {
        cd.pendingKind = kind;
        cd.pendingIndex = index;
        cd.visible = true;
    }

    anchors.centerIn: parent
    width: parent ? parent.width * 0.8 : 240
    height: col.implicitHeight + 28
    radius: 8
    color: "#1A2327"
    border.color: "#a63030"
    border.width: 1
    visible: false
    z: 100

    ColumnLayout {
        id: col
        anchors.centerIn: parent
        spacing: 12

        Text {
            text: cd.message
            color: "white"
            font.pixelSize: 15
            Layout.alignment: Qt.AlignHCenter
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16

            AppButton {
                text: "Yes"
                variant: "danger"
                Layout.preferredWidth: 90
                onClicked: {
                    cd.visible = false;
                    cd.confirmed(cd.pendingKind, cd.pendingIndex);
                }
            }
            AppButton {
                text: "No"
                variant: "secondary"
                Layout.preferredWidth: 90
                onClicked: cd.visible = false
            }
        }
    }
}
