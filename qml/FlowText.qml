import QtQuick

Text {
    id: root
    width: parent.width * .75
    height: parent.height * .75
    anchors.centerIn: parent
    text: text
    fontSizeMode: Text.Fit
    wrapMode: Text.WordWrap
    minimumPixelSize: 1
    font.pixelSize: 100 / Screen.devicePixelRatio
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    transformOrigin: Item.Center
}

