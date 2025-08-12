import QtQuick
import ".."
Item {
    property var modelData

    id: root

    Rectangle {

        color: "#7bd5bd"
        border.color: "black"
        border.width: 2
        radius: 5
        anchors.fill: parent
        opacity: 0.4
    }

    FlowText {
        id: answer
        text: modelData.text
        color: myColors.answerColor
        rotation: modelData.rotation
        height: parent.height
        width: parent.width
    }

    MouseArea {
        anchors.fill: parent
        drag.target: parent
        onReleased: answerRect.setStatus()

    }

    Rectangle {
        color: "black"
        radius: 15
        width: radius
        height: radius

        id: zoomPoint

        anchors.right: parent.right
        anchors.rightMargin: -width/2
        anchors.bottomMargin: -height/2
        anchors.bottom: parent.bottom

        MouseArea {
            anchors.fill: parent
            drag{ target: parent; axis: Drag.XAndYAxis }
            onReleased: answerRect.setStatus()

        }
    }
    function setStatus() {

        var originalWidth = activityImage.sourceSize.width;
        var originalHeight = activityImage.sourceSize.height;

        var displayedWidth = activityImage.width;
        var displayedHeight = activityImage.height;

        var x = mouse.x;
        var y = mouse.y;
        var horizontalEmptySpace = (activityImage.width - displayedWidth) / 2;
        var verticalEmptySpace = (activityImage.height - displayedHeight) / 2;

        // Orijinal image üzerindeki noktaya dönüştür
        var xInOriginalImage = (x - horizontalEmptySpace) * (originalWidth / displayedWidth);
        var yInOriginalImage = (y - verticalEmptySpace) * (originalHeight / displayedHeight);

        root.modelData.updatePosition(xInOriginalImage, yInOriginalImage, 100, 50)
        // config.bookSets[0].saveToJson();
        print("Changes Are Saved Page Detail set status")
    }
}
