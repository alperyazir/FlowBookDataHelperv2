import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia

// In-app audio/video picker. Lists the files in the book's audio/ (or
// video/) folder (via config.listBookMedia, which resolves paths in C++ for
// cross-platform correctness), lets the user search, audition audio inline,
// see which files are already assigned (and on which page), and pick one.
//
//   kind         "audio" | "video"
//   currentPath  the section's current relative path (highlighted)
//   picked(rel)  emitted with "./books/<book>/<kind>/<file>"
Popup {
    id: picker

    property string kind: "audio"
    property string currentPath: ""

    property string searchText: ""
    property var files: []            // absolute paths from C++
    property var usedMap: ({})        // fileName -> page label
    property var items: []            // filtered [{name,rel,url,used,usedPage}]
    property string playingUrl: ""    // audio audition

    signal picked(string rel)

    readonly property string currentBase: currentPath.substring(currentPath.lastIndexOf("/") + 1)

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: 580
    height: 640
    modal: true
    dim: true
    padding: 0
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    background: Rectangle {
        color: "#232f34"
        border.color: "#009ca6"
        border.width: 1
        radius: 10
    }

    onOpened: {
        picker.files = config.listBookMedia(picker.kind);
        picker.usedMap = scanUsed();
        rebuild();
    }
    onClosed: {
        preview.stop();
        picker.playingUrl = "";
    }

    // ---- helpers ----
    function basename(p) {
        return p ? p.substring(p.lastIndexOf("/") + 1) : "";
    }

    // Absolute path -> "./books/<book>/<kind>/<file>" (mirrors the sidebar's
    // findBooksFolder so the stored path matches config.json exactly).
    function toBookRel(p) {
        var parts = p.split("/");
        var idx = -1;
        for (var i = parts.length - 1; i >= 0; i--) {
            if (parts[i] === "books") { idx = i; break; }
        }
        if (idx === -1)
            return p;
        var rel = "./";
        for (var j = idx; j < parts.length; j++)
            rel += parts[j] + "/";
        return rel.slice(0, -1);
    }

    // Walk every page in the book collecting which files are already used,
    // remembering the first page that references each.
    function scanUsed() {
        var map = ({});
        try {
            var books = config.bookSets[0].books;
            for (var b = 0; b < books.length; b++) {
                var pages = books[b].pages;
                for (var p = 0; p < pages.length; p++) {
                    var label = pages[p].page_number !== undefined ? pages[p].page_number : (p + 1);
                    var secs = pages[p].sections;
                    for (var s = 0; s < secs.length; s++) {
                        var sec = secs[s];
                        var paths = [];
                        if (picker.kind === "audio") {
                            if (sec.type === "audio" && sec.audioPath)
                                paths.push(sec.audioPath);
                            if (sec.audioExtra && sec.audioExtra.path)
                                paths.push(sec.audioExtra.path);
                        } else if (picker.kind === "video") {
                            if (sec.type === "video" && sec.video && sec.video.path)
                                paths.push(sec.video.path);
                        }
                        for (var k = 0; k < paths.length; k++) {
                            var base = picker.basename(paths[k]);
                            if (base && map[base] === undefined)
                                map[base] = "" + label;
                        }
                    }
                }
            }
        } catch (e) {
            console.log("MediaPicker.scanUsed:", e);
        }
        return map;
    }

    function rebuild() {
        var out = [];
        var q = picker.searchText.toLowerCase();
        for (var i = 0; i < picker.files.length; i++) {
            var abs = picker.files[i];
            var name = picker.basename(abs);
            if (q.length && name.toLowerCase().indexOf(q) === -1)
                continue;
            var rel = picker.toBookRel(abs);
            out.push({
                name: name,
                rel: rel,
                url: "file:" + appPath + rel,
                used: picker.usedMap[name] !== undefined,
                usedPage: picker.usedMap[name]
            });
        }
        picker.items = out;
    }

    function togglePlay(url) {
        if (picker.playingUrl === url) {
            preview.stop();
            picker.playingUrl = "";
        } else {
            preview.source = url;
            preview.play();
            picker.playingUrl = url;
        }
    }

    MediaPlayer {
        id: preview
        audioOutput: AudioOutput {}
        onPlaybackStateChanged: if (playbackState === MediaPlayer.StoppedState) picker.playingUrl = ""
    }

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // Header
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: picker.kind === "audio" ? "Select audio" : "Select video"
                color: "white"
                font.pixelSize: 18
                font.bold: true
                Layout.fillWidth: true
            }
            Rectangle {
                width: 30; height: 30; radius: 6
                color: closeMouse.containsMouse ? "#2A3337" : "#1A2327"
                border.color: "#3a5560"; border.width: 1
                Text { anchors.centerIn: parent; text: "✕"; color: "#cfe8ea"; font.pixelSize: 13 }
                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: picker.close()
                }
            }
        }

        AppTextField {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            placeholderText: "Search…"
            text: picker.searchText
            onTextEdited: { picker.searchText = text; picker.rebuild(); }
        }

        Text {
            text: picker.items.length + " of " + picker.files.length + " files"
            color: "#5e7178"
            font.pixelSize: 12
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            color: "#16242b"
            border.color: "#2a3f48"
            border.width: 1

            Text {
                anchors.centerIn: parent
                width: parent.width - 24
                visible: picker.files.length === 0
                text: "No " + picker.kind + " files found in this book's " + picker.kind + " folder."
                color: "#5e7178"
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            ListView {
                id: list
                anchors.fill: parent
                anchors.margins: 6
                clip: true
                spacing: 4
                model: picker.items
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    required property var modelData
                    readonly property bool isCurrent: modelData.name === picker.currentBase
                    width: list.width
                    height: 46
                    radius: 6
                    color: isCurrent ? "#15323a"
                           : (rowMouse.containsMouse ? "#1c2a31" : "#1A2327")
                    border.color: isCurrent ? "#00e6e6" : "#2a3f48"
                    border.width: 1

                    // Background click = pick (declared first so controls win).
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            picker.picked(modelData.rel);
                            picker.close();
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        AppButton {
                            visible: picker.kind === "audio"
                            text: picker.playingUrl === modelData.url ? "⏸" : "▶"
                            variant: "secondary"
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 30
                            leftPadding: 0; rightPadding: 0
                            onClicked: picker.togglePlay(modelData.url)
                        }

                        Text {
                            text: modelData.name
                            color: "white"
                            font.pixelSize: 13
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            visible: modelData.used
                            radius: 10
                            height: 20
                            Layout.preferredWidth: usedLabel.implicitWidth + 16
                            color: "#3a2f12"
                            border.color: "#7a5e1c"
                            border.width: 1
                            Text {
                                id: usedLabel
                                anchors.centerIn: parent
                                text: "used · p." + modelData.usedPage
                                color: "#e8c45a"
                                font.pixelSize: 11
                            }
                        }

                        Text {
                            visible: isCurrent
                            text: "✓"
                            color: "#00e6e6"
                            font.pixelSize: 14
                            font.bold: true
                        }
                    }
                }
            }
        }
    }
}
