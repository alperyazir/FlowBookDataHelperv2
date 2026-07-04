import QtQuick
import QtQuick.Controls

// A small numbered badge pinned to an activity icon or a fill blank. It shows
// the item's reading-order position and, on click, lets you type a new one;
// `reorderRequested(int)` fires with the 1-based target so the host can call
// the matching move (page.moveSection for activities, page.moveAnswer for
// fill blanks). `diameter` is driven by the caller from the page zoom so the
// badge grows and shrinks with the artwork.
Item {
    id: badge

    property int number: 0        // 1-based position to display
    property int total: 0         // count of siblings (input cap)
    property real diameter: 18    // scales with zoom; caller feeds imageHeights
    property color pillColor: "#1565C0"   // stream color (activities vs fills)
    property bool editable: true          // false = show the number only

    signal reorderRequested(int oneBased)

    implicitWidth: diameter
    implicitHeight: diameter
    width: diameter
    height: diameter
    z: 100                        // float above the section/answer rectangles

    function commit() {
        input.visible = false;
        var n = parseInt(input.text);
        if (!isNaN(n) && n >= 1 && n <= badge.total && n !== badge.number)
            badge.reorderRequested(n);
    }

    // Read-only pill.
    Rectangle {
        id: pill
        anchors.fill: parent
        radius: height / 2
        color: badge.pillColor
        border.color: "white"
        border.width: Math.max(1, badge.diameter * 0.06)
        visible: !input.visible

        Text {
            anchors.centerIn: parent
            text: badge.number
            color: "white"
            font.pixelSize: Math.max(8, badge.diameter * 0.6)
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            enabled: badge.editable
            cursorShape: badge.editable ? Qt.PointingHandCursor : Qt.ArrowCursor
            // A plain click still registers inside a Flickable; do NOT
            // preventStealing — holding the grab here can strand the canvas's
            // mouse handling after an activity drag.
            onClicked: {
                input.text = badge.number;
                input.visible = true;
                input.forceActiveFocus();
                input.selectAll();
            }
        }
    }

    // Inline order editor (shown on click).
    TextField {
        id: input
        visible: false
        anchors.centerIn: parent
        width: badge.diameter * 2.6
        height: badge.diameter * 1.4
        z: 20
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        inputMethodHints: Qt.ImhDigitsOnly
        validator: IntValidator { bottom: 1; top: Math.max(1, badge.total) }
        font.pixelSize: Math.max(9, badge.diameter * 0.7)
        onAccepted: badge.commit()
        // Clicking away (losing focus) without Enter just cancels.
        onActiveFocusChanged: if (!activeFocus && visible) input.visible = false
    }
}
