import QtQuick
import QtQuick.Controls

// Full-window blocking overlay shown when the server has locked this install.
// It swallows all input and cannot be dismissed from the client — only a
// heartbeat returning locked:false clears it (no manual backdoor, by design).
Rectangle {
    id: lockRoot
    color: "#141b1f"

    // Eat every mouse / wheel event so nothing behind the overlay is reachable.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        acceptedButtons: Qt.AllButtons
        onWheel: (wheel) => wheel.accepted = true
    }

    Column {
        anchors.centerIn: parent
        spacing: 22
        width: Math.min(parent.width * 0.7, 480)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "🔒"   // 🔒
            font.pixelSize: 96
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: "white"
            font.pixelSize: 24
            font.bold: true
            text: "This application has been locked."
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: "#8fa6ad"
            font.pixelSize: 15
            text: "Please contact the publisher for assistance."
        }
    }
}
