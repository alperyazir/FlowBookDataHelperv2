import QtQuick

import "../../qml"

Item {
    property string text: ""
    property int rotation: 0
    property Image imageSrc
    property Item prevRoot
    id: root
    // Rectangle {
    //     id: rectGeneric
    //     color: "#7bd5bd"
    //     border.color: "black"
    //     border.width: 1
    //     radius: 5
    //     opacity: .5
    //     anchors.fill: parent
    // }

    Rectangle {
        id: mainRect
        color: "#7bd5bd"
        border.color: "black"
        border.width: 1
        radius: 5
        opacity: .5
        width: parent.width
        height: parent.height
        Drag.active: mouseArea.drag.active

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            drag.target: mainRect
        }
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
            onPositionChanged: {
                var adjustedX = (mouseX  - (prevRoot.width / 2 - imageSrc.paintedWidth / 2))
                var adjustedY = (mouseY  - (prevRoot.height / 2 - imageSrc.paintedHeight / 2))
                var originalX = adjustedX * (imageSrc.sourceSize.width / imageSrc.paintedWidth)
                var originalY = adjustedY * (imageSrc.sourceSize.height / imageSrc.paintedHeight)

                // Mouse hareketini zoom seviyesine göre ölçekle
                mainRect.width = mainRect.width + (originalX);
                mainRect.height = mainRect.height + (originalY);

                // Minimum boyutları belirle
                if (mainRect.width < 20) mainRect.width = 20;
                if (mainRect.height < 10) mainRect.height = 10;
            }
        }
    }


    FlowText {
        text: root.text
        color: "black"
        anchors.centerIn: undefined
        rotation: root.rotation
        height: mainRect.height
        width: mainRect.width
        x: mainRect.x
        y: mainRect.y
    }

    MouseArea {
        anchors.fill: parent
        drag.target: parent
    }
}
