import QtQuick
import QtQuick.Controls

// Reusable rubber-band selector for the activity editors. When `active`,
// dragging a box over the image selects the answer zones underneath and
// emits selected(hits). Place it inside the image (filling it), as a sibling
// of the answers Repeater, with `flick` and `image` set so it can map mouse
// coords to original-image coords (matching the answer delegates).
Item {
    id: band

    property var flick
    property var image
    property var answers: []
    property bool active: false
    signal selected(var hits)

    z: 60

    function _toOrig(mx, my) {
        var sx = image.paintedWidth / image.sourceSize.width;
        var sy = image.paintedHeight / image.sourceSize.height;
        return {
            x: (mx - (flick.contentWidth / 2 - image.paintedWidth / 2)) / sx,
            y: (my - (flick.contentHeight / 2 - image.paintedHeight / 2)) / sy
        };
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: band.active
        preventStealing: true
        // Only show the crosshair while the select tool is active.
        cursorShape: band.active ? Qt.CrossCursor : Qt.ArrowCursor

        property bool dragging: false
        property real x0: 0
        property real y0: 0
        property real x1: 0
        property real y1: 0

        onPressed: mouse => {
            ma.dragging = true;
            ma.x0 = mouse.x; ma.y0 = mouse.y;
            ma.x1 = mouse.x; ma.y1 = mouse.y;
        }
        onPositionChanged: mouse => {
            if (ma.dragging) { ma.x1 = mouse.x; ma.y1 = mouse.y; }
        }
        onReleased: mouse => {
            if (!ma.dragging)
                return;
            ma.dragging = false;
            var p0 = band._toOrig(Math.min(ma.x0, ma.x1), Math.min(ma.y0, ma.y1));
            var p1 = band._toOrig(Math.max(ma.x0, ma.x1), Math.max(ma.y0, ma.y1));
            var rx = p0.x, ry = p0.y, rw = p1.x - p0.x, rh = p1.y - p0.y;
            var hits = [];
            for (var i = 0; i < band.answers.length; i++) {
                var c = band.answers[i].coords;
                if (rx < c.x + c.width && rx + rw > c.x
                    && ry < c.y + c.height && ry + rh > c.y)
                    hits.push(band.answers[i]);
            }
            band.selected(hits);
        }
    }

    // Band rectangle (image space).
    Rectangle {
        visible: ma.dragging
        x: Math.min(ma.x0, ma.x1)
        y: Math.min(ma.y0, ma.y1)
        width: Math.abs(ma.x1 - ma.x0)
        height: Math.abs(ma.y1 - ma.y0)
        color: "#2200e6e6"
        border.color: "#00e6e6"
        border.width: 1
    }

    // Banner pinned to the viewport top while the tool is active.
    Rectangle {
        visible: band.active && band.flick
        x: band.flick ? band.flick.contentX + (band.flick.width - width) / 2 : 0
        y: band.flick ? band.flick.contentY + 8 : 0
        width: brow.implicitWidth + 22
        height: 30
        radius: 15
        color: "#cc009ca6"
        border.color: "#00e6e6"
        border.width: 1
        Row {
            id: brow
            anchors.centerIn: parent
            spacing: 6
            Text {
                text: "▭ Select"
                color: "white"
                font.bold: true
                font.pixelSize: 13
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "drag · Esc"
                color: "#d5f2f4"
                font.pixelSize: 11
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
