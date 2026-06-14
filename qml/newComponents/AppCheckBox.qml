import QtQuick
import QtQuick.Controls

// Themed checkbox matching the dark teal app theme.
CheckBox {
    id: cb

    indicator: Rectangle {
        implicitWidth: 20
        implicitHeight: 20
        x: cb.leftPadding
        y: cb.height / 2 - height / 2
        radius: 4
        color: "#1A2327"
        border.color: cb.checked ? "#009ca6" : "#445055"
        border.width: 1
        Rectangle {
            width: 12
            height: 12
            anchors.centerIn: parent
            radius: 2
            color: "#009ca6"
            visible: cb.checked
        }
    }

    contentItem: Text {
        text: cb.text
        color: "white"
        font.pixelSize: 13
        verticalAlignment: Text.AlignVCenter
        leftPadding: cb.indicator.width + 8
    }
}
