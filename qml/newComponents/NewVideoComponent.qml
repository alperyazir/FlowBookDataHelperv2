import QtQuick 2.15

Rectangle {
    property real imageHeights: mainwindow.height * 30 / 1080
    property string path
    id: sectionRect
    color:  "transparent"
    width: imageHeights
    height: imageHeights
    Image {
        id: audioImage
        source: "qrc:/icons/video.svg"
        height: root.imageHeights
        width: height
        smooth: true
        antialiasing: true
        anchors.centerIn: parent
    }

    MouseArea {
        anchors.fill: parent
        drag.target: parent
        onClicked: {

        }
    }
}
