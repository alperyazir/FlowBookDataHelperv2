import QtQuick
import QtQuick.Effects

// An image clipped to a rounded rectangle. Plain `clip: true` only clips to
// the bounding box, so a pill/circle shape would still show the image in its
// corners; MultiEffect masking (ships with Qt6 QtQuick.Effects) clips to the
// actual rounded outline. Set `cornerRadius` to the shape's radius (height/2
// for a pill/circle, a small value for a rounded rectangle).
Item {
    property alias source: img.source
    property int fillMode: Image.PreserveAspectFit
    property real cornerRadius: 0

    // Layered so the effect samples the fillMode-scaled result (an Image fed
    // straight into MultiEffect.source would ignore fillMode and stretch).
    Image {
        id: img
        anchors.fill: parent
        fillMode: parent.fillMode
        visible: false
        mipmap: true
        asynchronous: true
        layer.enabled: true
    }

    // Rounded rectangle mask, rendered off-screen.
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: cornerRadius
        visible: false
        layer.enabled: true
        layer.smooth: true
    }

    MultiEffect {
        anchors.fill: img
        source: img
        maskEnabled: true
        maskSource: mask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        // No blur/shadow here, so keep the effect strictly within bounds.
        autoPaddingEnabled: false
    }
}
