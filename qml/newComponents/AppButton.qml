import QtQuick
import QtQuick.Controls

// Shared button with three visual variants so the UI has a consistent
// hierarchy:
//   primary   — the main action (solid brand teal, bold)
//   secondary — supporting actions (ghost: outline + subtle hover)
//   danger    — destructive actions (solid red, bold)
Button {
    id: ctrl

    property string variant: "secondary"   // primary | secondary | danger

    height: 34
    leftPadding: 14
    rightPadding: 14
    hoverEnabled: true

    background: Rectangle {
        radius: 6
        color: {
            if (!ctrl.enabled)
                return "#2a3338";
            if (ctrl.variant === "primary")
                return ctrl.down ? "#00808a" : (ctrl.hovered ? "#00b3be" : "#009ca6");
            if (ctrl.variant === "danger")
                return ctrl.down ? "#8f3936" : (ctrl.hovered ? "#c9504d" : "#a94442");
            // secondary (ghost)
            return ctrl.down ? "#2c3e47" : (ctrl.hovered ? "#22323a" : "transparent");
        }
        border.width: ctrl.variant === "secondary" ? 1 : 0
        border.color: ctrl.enabled ? "#3a5560" : "#3a4248"
        Behavior on color { ColorAnimation { duration: 90 } }
    }

    contentItem: Text {
        text: ctrl.text
        color: !ctrl.enabled ? "#6b7a80"
               : (ctrl.variant === "secondary" ? "#cfe8ea" : "white")
        font.bold: ctrl.variant !== "secondary"
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
