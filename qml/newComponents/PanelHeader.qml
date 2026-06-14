import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Shared side-panel header: bold title on the left, a rounded close button
// on the right. The host reacts to closeClicked().
RowLayout {
    id: hdr

    property string title: ""
    signal closeClicked()

    spacing: 10

    Text {
        text: hdr.title
        color: "white"
        font.pixelSize: 22
        font.bold: true
        Layout.fillWidth: true
        elide: Text.ElideRight
    }

    Rectangle {
        width: 30
        height: 30
        radius: 6
        color: closeMouse.containsMouse ? "#2A3337" : "#1A2327"
        border.color: "#3a5560"
        border.width: 1
        Text {
            anchors.centerIn: parent
            text: "✕"
            color: "#cfe8ea"
            font.pixelSize: 13
        }
        MouseArea {
            id: closeMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: hdr.closeClicked()
        }
    }
}
