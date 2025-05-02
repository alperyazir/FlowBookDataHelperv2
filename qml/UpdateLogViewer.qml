import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: updateLogViewer

    property alias logMessages: listView.model

    color: "#232f34"
    border.color: "#3498db"
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Güncelleme Kayıtları"
                color: "white"
                font.pixelSize: 16
                font.bold: true
                Layout.fillWidth: true
            }

            Button {
                text: "Temizle"
                onClicked: updateManager.clearLogs()
            }

            Button {
                text: "Kapat"
                onClicked: updateLogViewer.visible = false
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#1a2327"
            border.color: "#3498db"
            border.width: 1

            ListView {
                id: listView
                anchors.fill: parent
                anchors.margins: 5
                clip: true

                delegate: Rectangle {
                    width: ListView.view.width
                    height: messageText.contentHeight + 10
                    color: index % 2 === 0 ? "#1a2327" : "#232f34"

                    Text {
                        id: messageText
                        text: modelData
                        color: {
                            if (modelData.indexOf("Hata:") !== -1)
                                return "#e74c3c";
                                // kırmızı
                            else if (modelData.indexOf("Güncelleme başarıyla") !== -1)
                                return "#2ecc71";
                                // yeşil
                            else if (modelData.indexOf("Çıktı:") !== -1)
                                return "#f1c40f";
                                // sarı
                            else
                                return "white";    // beyaz
                        }
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            margins: 5
                        }
                    }
                }

                // ListView sonuna otomatik kaydır
                onCountChanged: {
                    if (count > 0) {
                        positionViewAtIndex(count - 1, ListView.End);
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    active: true
                }
            }
        }
    }

    // Yeni log mesajı geldiğinde otomatik olarak göster
    Connections {
        target: updateManager
        function onNewLogMessage(message) {
            // Mesajı göster ve sonuna kaydır
            listView.positionViewAtEnd();
        }
    }
}
