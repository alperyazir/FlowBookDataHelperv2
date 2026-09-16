import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "newComponents"

// Project ▸ Videos: every video in the open book against what the Windows
// reader can play (scripts/video_compat.py), and Optimize to convert the ones
// that won't — in the book's own folder, replacing the originals, so Test and
// every package after it get the playable files. The conversion belongs to the
// window (videoOptimizer in main.qml): it runs in the background and closing
// this dialog leaves it running.
Dialog {
    id: videosDialog
    title: "Videos"
    modal: true
    closePolicy: Popup.NoAutoClose
    width: 640
    height: 640
    anchors.centerIn: parent

    // The book this dialog shows; set from the open project when it opens.
    property string book: ""
    // The last check ({toplam, sorunlu, okunamayan, ffmpeg_yok, videolar} or
    // {hata}); {} until the first one comes back. Not "result": Dialog has one.
    property var report: ({})
    property bool checking: false
    // What the last optimize of this book could not do (until the next starts).
    property string runError: ""

    readonly property int problemCount: (report.sorunlu || 0)
    // The background optimize, when it is this book's.
    readonly property bool running: videoOptimizer.running && videoOptimizer.book === book
    readonly property var progress: running ? videoOptimizer.progress : ({})

    onOpened: {
        var open = openProject.currentProject || "";
        if (open !== book)
            runError = "";
        book = open;
        report = ({});
        recheck();
    }

    function recheck() {
        if (!book)
            return;
        checking = true;
        pdfProcess.checkVideos(book);
    }

    function optimize() {
        if (!book)
            return;
        runError = "";
        if (!videoOptimizer.start(book))
            runError = "Videos are already being optimized for " + videoOptimizer.book
                       + " — wait for that to finish.";
    }

    Connections {
        target: pdfProcess
        function onVideosChecked(book, json) {
            if (book !== videosDialog.book || !videosDialog.checking)
                return;
            videosDialog.checking = false;
            try {
                videosDialog.report = JSON.parse(json);
            } catch (e) {
                videosDialog.report = { hata: "" + e };
            }
        }
    }

    // A run ended: what it left undone, and the book as it is now.
    Connections {
        target: videoOptimizer
        function onFinished(book, r) {
            if (book !== videosDialog.book)
                return;
            var msgs = [];
            if (r.hata)
                msgs.push(r.hata);
            var failed = r.basarisiz || [];
            for (var i = 0; i < failed.length; i++)
                msgs.push(failed[i].dosya + ": " + failed[i].hata);
            videosDialog.runError = msgs.join("\n");
            if (videosDialog.visible)
                videosDialog.recheck();
        }
    }

    header: Rectangle {
        color: "#1A2327"; height: 44
        border.color: "#009ca6"; border.width: 1
        Label {
            text: "Videos" + (videosDialog.book ? "  ·  " + videosDialog.book : "")
            color: "white"; font.pixelSize: 16; font.bold: true
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left; anchors.leftMargin: 12
            anchors.right: parent.right; anchors.rightMargin: 12
        }
    }

    footer: Rectangle {
        color: "#1A2327"; height: 56
        border.color: "#009ca6"; border.width: 1
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10

            AppButton {
                text: "Check again"
                variant: "secondary"
                enabled: !!videosDialog.book && !videosDialog.checking && !videosDialog.running
                Layout.preferredHeight: 34
                onClicked: videosDialog.recheck()
            }
            Item { Layout.fillWidth: true }
            AppButton {
                visible: !videosDialog.running
                text: "Optimize " + videosDialog.problemCount + " video(s)"
                variant: "primary"
                enabled: videosDialog.problemCount > 0 && !videosDialog.checking
                         && !videoOptimizer.running
                Layout.preferredHeight: 34
                onClicked: videosDialog.optimize()
            }
            AppButton {
                visible: videosDialog.running
                text: videoOptimizer.stopping ? "Stopping…" : "Stop"
                variant: "danger"
                enabled: !videoOptimizer.stopping
                Layout.preferredWidth: 100
                Layout.preferredHeight: 34
                onClicked: videoOptimizer.stop()
            }
            AppButton {
                text: "Close"
                variant: "secondary"
                Layout.preferredWidth: 90
                Layout.preferredHeight: 34
                onClicked: videosDialog.close()
            }
        }
    }

    background: Rectangle {
        color: "#232f34"; border.color: "#009ca6"; border.width: 1; radius: 4
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 10

        Text {
            Layout.fillWidth: true
            text: "FlowBook on Windows plays H.264 video (8-bit, up to 1080p) with AAC or MP3 "
                  + "audio, in .mp4, .m4v or .mov. Optimize converts the other videos in the "
                  + "book's own folder and replaces the originals, so Test and every package "
                  + "get videos that play. It runs in the background: you can close this "
                  + "window and keep working."
            color: "#8aa0a8"; font.pixelSize: 12; wrapMode: Text.WordWrap
        }

        // One line on the state of the book.
        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: 13
            font.bold: true
            readonly property var r: videosDialog.report
            text: {
                if (!videosDialog.book)
                    return "Open a book first.";
                if (videosDialog.checking)
                    return "Checking the videos…";
                if (r.hata)
                    return "✖  " + r.hata;
                if (r.toplam === undefined)
                    return "";
                if (r.toplam === 0)
                    return "This book has no videos.";
                if (r.ffmpeg_yok)
                    return "✖  " + r.toplam + " video(s), but ffmpeg isn't installed, so they can't be "
                           + "checked or converted — install it from Help ▸ Dependencies.";
                var bad = (r.sorunlu || 0) + (r.okunamayan || 0);
                if (bad === 0)
                    return "✓  All " + r.toplam + " video(s) play on Windows.";
                var parts = [];
                if (r.sorunlu)
                    parts.push(r.sorunlu + " won't play on Windows");
                if (r.okunamayan)
                    parts.push(r.okunamayan + " can't be read (replace them)");
                return r.toplam + " video(s): " + parts.join(", ") + ".";
            }
            color: {
                if (videosDialog.checking || r.toplam === undefined || r.toplam === 0)
                    return "#e0a32e";
                if (r.hata || r.ffmpeg_yok || (r.sorunlu || 0) + (r.okunamayan || 0) > 0)
                    return "#e06c75";
                return "#4fd2dc";
            }
        }

        // The background optimize: this book's progress, or a note that
        // another book's is running.
        ColumnLayout {
            Layout.fillWidth: true
            visible: videoOptimizer.running
            spacing: 4
            Text {
                Layout.fillWidth: true
                font.pixelSize: 12
                color: "#e0a32e"
                elide: Text.ElideMiddle
                text: !videosDialog.running
                      ? "Optimizing the videos of " + videoOptimizer.book + " in the background…"
                      : videosDialog.progress.n > 0
                        ? "Converting " + (videosDialog.progress.i + 1) + " of " + videosDialog.progress.n
                          + " · " + Math.round(videoOptimizer.overall * 100) + "%  ·  "
                          + (videosDialog.progress.dosya || "")
                        : "Getting ready…"
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 4
                radius: 2
                color: "#1A2327"
                Rectangle {
                    width: parent.width * videoOptimizer.overall
                    height: parent.height
                    radius: 2
                    color: "#009ca6"
                }
            }
        }

        TextEdit {
            Layout.fillWidth: true
            visible: !videosDialog.running && videosDialog.runError !== ""
            readOnly: true
            selectByMouse: true
            selectionColor: "#00707a"
            selectedTextColor: "white"
            textFormat: TextEdit.PlainText
            wrapMode: TextEdit.Wrap
            font.pixelSize: 12
            color: "#e06c75"
            text: "✖  " + videosDialog.runError
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            border.width: 1; border.color: "#009ca6"; radius: 4

            ListView {
                id: videoList
                anchors.fill: parent
                anchors.margins: 6
                clip: true
                spacing: 4
                model: videosDialog.report.videolar || []
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    id: row
                    required property var modelData
                    readonly property string durum: modelData.durum
                    // The file being converted right now.
                    readonly property bool converting: videosDialog.running
                                                       && videosDialog.progress.dosya === modelData.dosya
                    width: ListView.view ? ListView.view.width - 8 : 0
                    height: rowCol.implicitHeight + 16
                    radius: 6
                    color: "#1A2327"
                    border.width: 1
                    border.color: row.converting ? "#e0a32e"
                                : row.durum === "uygun" ? "#2f4751" : "#6b3a3f"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 10
                        spacing: 10

                        ColumnLayout {
                            id: rowCol
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.dosya
                                color: "white"; font.pixelSize: 13
                                elide: Text.ElideMiddle
                            }
                            Text {
                                Layout.fillWidth: true
                                text: (row.modelData.ozet ? row.modelData.ozet + "  ·  " : "")
                                      + row.modelData.mb + " MB"
                                color: "#8aa0a8"; font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: !!(row.modelData.sorun || row.modelData.hata)
                                text: row.modelData.sorun || row.modelData.hata || ""
                                color: "#e06c75"; font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }
                        }

                        Text {
                            Layout.preferredWidth: 110
                            horizontalAlignment: Text.AlignRight
                            font.pixelSize: 12
                            font.bold: true
                            text: row.converting ? (videosDialog.progress.pct || 0) + "%"
                                : row.durum === "uygun" ? "✓ Plays"
                                : row.durum === "sorunlu" ? "✖ Won't play"
                                : row.durum === "okunamayan" ? "✖ Can't read"
                                : "? Not checked"
                            color: row.converting ? "#e0a32e"
                                 : row.durum === "uygun" ? "#4fd2dc"
                                 : row.durum === "bilinmiyor" ? "#8aa0a8" : "#e06c75"
                        }
                    }
                }
            }
        }
    }
}
