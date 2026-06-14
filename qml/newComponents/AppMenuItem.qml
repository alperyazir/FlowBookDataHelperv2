import QtQuick
import QtQuick.Controls

// A themed menu row. Set `danger: true` for destructive actions (Clear...).
MenuItem {
    id: mi
    property bool danger: false
    implicitHeight: 34
    padding: 8

    // Small checkbox shown for checkable items (e.g. Settings toggles).
    indicator: Rectangle {
        visible: mi.checkable
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        radius: 4
        color: mi.checked ? "#009ca6" : "transparent"
        border.color: "#3a5560"
        border.width: 1
        Text {
            anchors.centerIn: parent
            text: "✓"
            color: "white"
            font.pixelSize: 11
            visible: mi.checked
        }
    }

    contentItem: Text {
        text: mi.text
        color: !mi.enabled ? "#6b7a80"
               : mi.highlighted ? "white"
               : (mi.danger ? "#e8908d" : "#e6f2f3")
        font.pixelSize: 13
        leftPadding: mi.checkable ? 34 : 6
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: 5
        color: mi.highlighted ? (mi.danger ? "#a94442" : "#009ca6") : "transparent"
    }
}
