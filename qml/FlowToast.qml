import QtQuick
import QtQuick.Controls

Popup {
    id: root

    // Error toasts are red, wrap longer messages, and linger longer so the
    // user can actually read what failed.
    property bool isError: false

    width: Math.min((parent ? parent.width : 600) * 0.6, 540)
    height: toastText.implicitHeight + 28
    y: parent ? parent.height - height - 20 : 0 // Bottom margin
    x: parent ? parent.width - width - 25 : 0
    background: Rectangle {
        color: root.isError ? "#c0392b" : "#00FFFF"
        radius: 10
        opacity: 0.92
    }

    contentItem: Text {
        id: toastText
        text: ""
        color: root.isError ? "white" : "darkblue"
        font.pixelSize: 16
        width: root.width - 28
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    // show(message)            -> normal cyan toast (2.5s)
    // show(message, true)      -> red error toast (6s)
    function show(message, error) {
        root.isError = error === true;
        toastText.text = message;
        root.open();
        toastTimer.interval = root.isError ? 6000 : 2500;
        toastTimer.restart();
    }

    Timer {
        id: toastTimer
        interval: 2500
        running: false
        repeat: false
        onTriggered: root.close()
    }
}
