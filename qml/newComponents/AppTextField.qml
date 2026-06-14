import QtQuick
import QtQuick.Controls

// Themed single-line input matching the dark teal app theme. Focus lights
// the border in brand teal; placeholder is muted.
TextField {
    id: ctrl

    color: "white"
    placeholderTextColor: "#5e7178"
    selectByMouse: true
    leftPadding: 10
    rightPadding: 10
    verticalAlignment: Text.AlignVCenter
    font.pixelSize: 13

    background: Rectangle {
        radius: 6
        color: "#1A2327"
        border.color: ctrl.activeFocus ? "#009ca6" : "#3a4f57"
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 90 } }
    }
}
