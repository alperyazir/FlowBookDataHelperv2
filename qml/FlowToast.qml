import QtQuick
import QtQuick.Controls

Popup {
    id: root
    width: parent.width * 0.8
    height: implicitHeight
    y: parent.height - height - 20 // Bottom margin
    x: parent.width - width - 25
    background: Rectangle {
        color: "#00FFFF"
        radius: 10
        opacity: 0.8
    }

    contentItem: Text {
        id: toastText
        text: ""
        color: "darkblue"
        font.pixelSize: 16
        anchors.centerIn: parent
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    function show(message) {
        toastText.text = message
        toast.open()
        toastTimer.start()
    }

    Timer {
        id: toastTimer
        interval: 2000 // 2 seconds
        running: false
        repeat: false
        onTriggered: root.close()
    }
}
