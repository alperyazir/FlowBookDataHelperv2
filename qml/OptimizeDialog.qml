import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "newComponents"

// Project ▸ Optimize: shows every book's original.pdf size and lets the user
// shrink it (image downsample, vector text untouched). The compressed copy is
// a cache used at package time — the editor keeps the full-res original.
Dialog {
    id: optimizeDialog
    title: "Optimize PDFs"
    modal: true
    closePolicy: Popup.NoAutoClose
    width: 560
    height: 600
    anchors.centerIn: parent

    // Bumped on a timer so each row re-queries pdfProcess.originalPdfInfo()
    // and reflects a background compression finishing.
    property int tick: 0

    onOpened: optimizeDialog.tick++

    Timer {
        running: optimizeDialog.visible
        interval: 1500
        repeat: true
        onTriggered: optimizeDialog.tick++
    }

    function mb(bytes) {
        return (bytes / 1048576).toFixed(1) + " MB";
    }

    header: Rectangle {
        color: "#1A2327"; height: 44
        border.color: "#009ca6"; border.width: 1
        Label {
            text: "Optimize PDFs"
            color: "white"; font.pixelSize: 16; font.bold: true
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left; anchors.leftMargin: 12
        }
    }

    footer: Rectangle {
        color: "#1A2327"; height: 56
        border.color: "#009ca6"; border.width: 1
        AppButton {
            text: "Close"
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 100; height: 34
            onClicked: optimizeDialog.close()
        }
    }

    background: Rectangle {
        color: "#232f34"; border.color: "#009ca6"; border.width: 1; radius: 4
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        Text {
            Layout.fillWidth: true
            text: "Shrink each book's original PDF. The compressed copy is used "
                  + "when packaging; the editor keeps the full-resolution original."
            color: "#8aa0a8"; font.pixelSize: 12; wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            border.width: 1; border.color: "#009ca6"; radius: 4

            ListView {
                anchors.fill: parent
                anchors.margins: 6
                clip: true
                spacing: 4
                model: config ? config.recentProject : []
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    // { status, original, compressed } — tick forces refresh.
                    readonly property var info: {
                        optimizeDialog.tick;
                        return pdfProcess.originalPdfInfo(row.modelData);
                    }
                    width: ListView.view ? ListView.view.width : 0
                    height: 48
                    radius: 6
                    color: "#1A2327"
                    border.color: "#2f4751"; border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: row.modelData
                                color: "white"; font.pixelSize: 14
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                // Sizes / status line.
                                text: {
                                    var i = row.info;
                                    if (i.status === "none")
                                        return "no original PDF";
                                    if (i.status === "inprogress")
                                        return "optimizing…";
                                    if (i.status === "ready")
                                        return optimizeDialog.mb(i.original)
                                               + "  →  " + optimizeDialog.mb(i.compressed)
                                               + "   (-" + Math.round(100 * (i.original - i.compressed) / i.original) + "%)";
                                    return optimizeDialog.mb(i.original) + "  · not optimized";
                                }
                                color: row.info.status === "ready" ? "#4fd2dc"
                                     : row.info.status === "inprogress" ? "#e0a32e"
                                     : row.info.status === "none" ? "#5e7178" : "#8aa0a8"
                                font.pixelSize: 12
                            }
                        }

                        AppButton {
                            text: row.info.status === "ready" ? "Re-optimize" : "Optimize"
                            variant: "secondary"
                            Layout.preferredWidth: 110
                            Layout.preferredHeight: 30
                            visible: row.info.status === "stale" || row.info.status === "ready"
                            onClicked: {
                                // Re-optimize forces a rebuild by clearing the cache stamp first.
                                pdfProcess.optimizeOriginalPdf(row.modelData,
                                                               row.info.status === "ready");
                                optimizeDialog.tick++;
                            }
                        }
                        Text {
                            text: "optimizing…"
                            color: "#e0a32e"; font.pixelSize: 12
                            visible: row.info.status === "inprogress"
                            Layout.preferredWidth: 110
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}
