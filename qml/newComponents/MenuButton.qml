import QtQuick
import QtQuick.Controls

// A top menu-bar trigger ("File", "Project", "Page"). Declare the menu
// as a child and open it from onClicked, e.g.
//   MenuButton { text: "File"; onClicked: fileMenu.open()
//                AppMenu { id: fileMenu; y: parent.height + 2; ... } }
Button {
    id: ctrl
    height: 30
    leftPadding: 12
    rightPadding: 12
    hoverEnabled: true

    background: Rectangle {
        radius: 6
        color: ctrl.down ? "#26343c"
               : ctrl.hovered ? "#202d34" : "transparent"
        Behavior on color { ColorAnimation { duration: 80 } }
    }
    contentItem: Text {
        text: ctrl.text
        color: "#d5e7ea"
        font.pixelSize: 14
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
