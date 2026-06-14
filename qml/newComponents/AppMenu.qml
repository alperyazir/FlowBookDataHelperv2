import QtQuick
import QtQuick.Controls

// Dark, rounded dropdown menu matching the app theme. Fill with AppMenuItem.
Menu {
    id: m
    padding: 6
    implicitWidth: 210

    background: Rectangle {
        implicitWidth: 210
        color: "#202c33"
        border.color: "#33505b"
        border.width: 1
        radius: 8
    }
}
