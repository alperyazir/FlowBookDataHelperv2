import QtQuick
import QtQuick.Controls

import "../"
import "../newComponents"

Rectangle {
    id: root
    property string imageSource
    property var shuffledWords: []
    property var answers
    property string audio_path
    signal closed
    property var dragMap: []
    property var dropMap: []
    property string correctColor: myColors.correctColor
    property string wrongColor: myColors.wrongColor
    property string standColor: myColors.standColor
    property string headerText
    property var activityModelData
    property real lastHeight: 60
    property real lastWidth: 60
    width: parent.width
    height: parent.height
    color: "#232f34"

    // --- Ctrl+click multi-selection of answer zones + group resize ---
    property var selectedAnswers: []
    function isAnsSelected(a) { return root.selectedAnswers.indexOf(a) !== -1; }
    function setSingleAnsSelection(a) { root.selectedAnswers = a ? [a] : []; }
    function toggleAnsSelection(a) {
        var arr = root.selectedAnswers.slice();
        var p = arr.indexOf(a);
        if (p === -1) arr.push(a); else arr.splice(p, 1);
        root.selectedAnswers = arr;
    }
    function clearAnsSelection() { root.selectedAnswers = []; }
    function syncSizeLive(src, w, h) {
        var sel = root.selectedAnswers;
        if (sel.length < 2 || sel.indexOf(src) === -1) return;
        for (var i = 0; i < sel.length; i++) {
            var a = sel[i];
            if (a === src) continue;
            var c = a.coords;
            if (c.width === w && c.height === h) continue;
            a.coords = Qt.rect(c.x, c.y, w, h);
        }
    }
    function syncSizeToSelection(src) {
        if (root.selectedAnswers.indexOf(src) === -1) return;
        syncSizeLive(src, src.coords.width, src.coords.height);
    }
    // --- Group move: absolute (snapshot + total delta) to avoid drift. ---
    property var moveSnap: []
    property real moveStartOX: 0
    property real moveStartOY: 0
    function snapshotAnsSelection() {
        var sel = root.selectedAnswers;
        var snap = [];
        for (var i = 0; i < sel.length; i++)
            snap.push({ a: sel[i], x: sel[i].coords.x, y: sel[i].coords.y });
        return snap;
    }
    function applyAnsMove(snap, src, dX, dY) {
        if (root.selectedAnswers.length < 2) return;
        for (var i = 0; i < snap.length; i++) {
            if (snap[i].a === src) continue;
            var c = snap[i].a.coords;
            snap[i].a.coords = Qt.rect(Math.round(snap[i].x + dX), Math.round(snap[i].y + dY), c.width, c.height);
        }
    }
    // Align every selected zone to the leftmost one ('l').
    function alignSelectedLeft() {
        var sel = root.selectedAnswers;
        if (sel.length < 2) return;
        var minX = sel[0].coords.x;
        for (var i = 1; i < sel.length; i++)
            if (sel[i].coords.x < minX) minX = sel[i].coords.x;
        for (var j = 0; j < sel.length; j++) {
            var c = sel[j].coords;
            sel[j].coords = Qt.rect(minX, c.y, c.width, c.height);
        }
    }
    // Align every selected zone to the bottom-most one ('b').
    function alignSelectedBottom() {
        var sel = root.selectedAnswers;
        if (sel.length < 2) return;
        var maxB = sel[0].coords.y + sel[0].coords.height;
        for (var i = 1; i < sel.length; i++) {
            var b = sel[i].coords.y + sel[i].coords.height;
            if (b > maxB) maxB = b;
        }
        for (var j = 0; j < sel.length; j++) {
            var c = sel[j].coords;
            sel[j].coords = Qt.rect(c.x, maxB - c.height, c.width, c.height);
        }
    }
    // Align every selected zone's right edge to the rightmost one.
    function alignSelectedRight() {
        var sel = root.selectedAnswers;
        if (sel.length < 2) return;
        var maxR = sel[0].coords.x + sel[0].coords.width;
        for (var i = 1; i < sel.length; i++) {
            var r = sel[i].coords.x + sel[i].coords.width;
            if (r > maxR) maxR = r;
        }
        for (var j = 0; j < sel.length; j++) {
            var c = sel[j].coords;
            sel[j].coords = Qt.rect(maxR - c.width, c.y, c.width, c.height);
        }
    }
    // Align every selected zone to the top-most one.
    function alignSelectedTop() {
        var sel = root.selectedAnswers;
        if (sel.length < 2) return;
        var minY = sel[0].coords.y;
        for (var i = 1; i < sel.length; i++)
            if (sel[i].coords.y < minY) minY = sel[i].coords.y;
        for (var j = 0; j < sel.length; j++) {
            var c = sel[j].coords;
            sel[j].coords = Qt.rect(c.x, minY, c.width, c.height);
        }
    }
    property real hoverX: 0
    property real hoverY: 0
    // Add an answer zone at the cursor ('f' shortcut), like the long-press.
    function addAnswerAtCursor() {
        if (!root.activityModelData || !root.activityModelData.createNewAnswer)
            return;
        var adjustedX = root.hoverX - (flick.contentWidth / 2 - activityImage.paintedWidth / 2);
        var adjustedY = root.hoverY - (flick.contentHeight / 2 - activityImage.paintedHeight / 2);
        var originalX = adjustedX * (activityImage.sourceSize.width / activityImage.paintedWidth);
        var originalY = adjustedY * (activityImage.sourceSize.height / activityImage.paintedHeight);
        root.activityModelData.createNewAnswer(originalX, originalY, root.lastWidth, root.lastHeight);
    }

    Rectangle {
        id: header
        width: parent.width
        height: 54
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        color: "#1A2327"
        border.color: "#009ca6"
        border.width: 1

        Text {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            text: root.headerText
            font.pixelSize: 16
            font.bold: true
            color: "#cfe8ea"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            maximumLineCount: 2
        }
    }

    Column {
        id: actColumn
        property real biggestWidth: 50
        property real biggestHeight: 20
        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 10
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 5

        Rectangle {
            id: draggableWords
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            // A single horizontal strip of word chips, centered; scrolls
            // sideways when there are too many to fit. Collapses when empty.
            height: (root.shuffledWords && root.shuffledWords.length > 0) ? 44 : 0
            color: "#16242b"
            radius: 6
            border.color: (root.shuffledWords && root.shuffledWords.length > 0) ? "#2a3f48" : "transparent"
            border.width: 1
            z: 2

            Flickable {
                id: wordsFlick
                anchors.fill: parent
                anchors.margins: 6
                contentWidth: wordsRow.width
                contentHeight: height
                flickableDirection: Flickable.HorizontalFlick
                clip: true
                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

                Row {
                    id: wordsRow
                    spacing: 6
                    // Centered horizontally & vertically; chips stay in one row.
                    x: Math.max(0, (wordsFlick.width - width) / 2)
                    y: Math.max(0, (wordsFlick.height - height) / 2)

                    Repeater {
                        model: root.shuffledWords
                        Rectangle {
                            width: chipText.implicitWidth + 20
                            height: 28
                            radius: 14
                            color: chipMouse.containsMouse ? "#22323a" : "#2A3337"
                            border.color: "#009ca6"
                            border.width: 1
                            Text {
                                id: chipText
                                anchors.centerIn: parent
                                text: modelData
                                color: "#cfe8ea"
                                font.pixelSize: 13
                            }
                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: clipboardHelper.copyText(modelData)
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: sentencesRect
            width: parent.width
            height: parent.height - draggableWords.height
            radius: 10
            color: "transparent"
            z: 1
            anchors.horizontalCenter: parent.horizontalCenter

            // Zoom ve pan için mouse area
            MouseArea {
                id: mainMouseArea
                anchors.fill: parent
                acceptedButtons: Qt.MiddleButton | Qt.RightButton
                scrollGestureEnabled: true
                hoverEnabled: true

                property bool dragging: false
                property real lastX: 0
                property real lastY: 0

                onPressed: mouse => {
                    if (mouse.button === Qt.MiddleButton) {
                        dragging = true;
                        lastX = mouse.x;
                        lastY = mouse.y;
                    }
                }

                onReleased: mouse => {
                    if (mouse.button === Qt.MiddleButton) {
                        dragging = false;
                    }
                }

                onPositionChanged: mouse => {
                    if (dragging) {
                        var dx = mouse.x - lastX;
                        var dy = mouse.y - lastY;
                        flick.contentX -= dx;
                        flick.contentY -= dy;
                        lastX = mouse.x;
                        lastY = mouse.y;
                    }
                }

                onWheel: event => {
                    if (event.angleDelta.y > 0) {
                        flick.zoomIn();
                    } else {
                        flick.zoomOut();
                    }
                    event.accepted = true;
                }
            }

            Flickable {
                id: flick
                anchors.fill: parent
                contentHeight: parent.height
                contentWidth: parent.width
                interactive: true
                clip: true
                boundsMovement: Flickable.StopAtBounds

                property real minZoom: 1.0
                property real maxZoom: 4.0
                property real zoomLevel: 1
                property real zoomStep: 0.1

                function zoomIn() {
                    if (contentWidth < width * maxZoom) {
                        resizeContent(contentWidth * (1 + zoomStep), contentHeight * (1 + zoomStep), Qt.point(contentX + width / 2, contentY + height / 2));
                        returnToBounds();
                    }
                }

                function zoomOut() {
                    if (contentWidth > width * minZoom) {
                        resizeContent(contentWidth * (1 - zoomStep), contentHeight * (1 - zoomStep), Qt.point(contentX + width / 2, contentY + height / 2));
                        returnToBounds();
                    }
                }

                function setDefaultZoom() {
                    resizeContent(width, height, Qt.point(width / 2, height / 2));
                    returnToBounds();
                    contentX = 0;
                    contentY = 0;
                }

                PinchArea {
                    id: pinch
                    width: Math.max(flick.contentWidth, flick.width)
                    height: Math.max(flick.contentHeight, flick.height)

                    property real initialWidth
                    property real initialHeight

                    onPinchStarted: {
                        initialWidth = flick.contentWidth;
                        initialHeight = flick.contentHeight;
                    }

                    onPinchUpdated: {
                        var newWidth = initialWidth * pinch.scale;
                        var newHeight = initialHeight * pinch.scale;

                        if (newWidth < flick.width || newHeight < flick.height) {
                            flick.resizeContent(flick.width, flick.height, Qt.point(flick.width / 2, flick.height / 2));
                        } else {
                            flick.contentX += pinch.previousCenter.x - pinch.center.x;
                            flick.contentY += pinch.previousCenter.y - pinch.center.y;
                            flick.resizeContent(initialWidth * pinch.scale, initialHeight * pinch.scale, pinch.center);
                        }
                    }

                    onPinchFinished: {
                        flick.returnToBounds();
                    }

                    Image {
                        id: activityImage
                        source: imageSource
                        antialiasing: true
                        smooth: true
                        fillMode: Image.PreserveAspectFit
                        width: Math.max(flick.contentWidth, flick.width)
                        height: Math.max(flick.contentHeight, flick.height)

                        MouseArea {
                            anchors.fill: parent
                            propagateComposedEvents: true
                            hoverEnabled: true
                            onPositionChanged: { root.hoverX = mouseX; root.hoverY = mouseY; }
                            onPressAndHold: {
                                var adjustedX = mouseX - (flick.contentWidth / 2 - activityImage.paintedWidth / 2);
                                var adjustedY = mouseY - (flick.contentHeight / 2 - activityImage.paintedHeight / 2);

                                // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                                var originalX = adjustedX * (activityImage.sourceSize.width / activityImage.paintedWidth);
                                var originalY = adjustedY * (activityImage.sourceSize.height / activityImage.paintedHeight);

                                root.activityModelData.createNewAnswer(originalX, originalY, root.lastWidth, root.lastHeight);
                                // config.bookSets[0].saveToJson();
                            }

                            onWheel: function (wheel) {
                                if (wheel.angleDelta.y / 120 * flick.contentWidth * 0.1 + flick.contentWidth > flick.width && wheel.angleDelta.y / 120 * flick.contentHeight * 0.1 + flick.contentHeight > flick.height) {
                                    flick.resizeContent(wheel.angleDelta.y / 120 * flick.contentWidth * 0.1 + flick.contentWidth, wheel.angleDelta.y / 120 * flick.contentHeight * 0.1 + flick.contentHeight, Qt.point(wheel.x, wheel.y));
                                    flick.returnToBounds();
                                } else {
                                    flick.resizeContent(flick.width, flick.height, Qt.point(flick.width / 2, flick.height / 2));
                                    flick.returnToBounds();
                                }
                            }
                        }

                        RubberBandSelector {
                            anchors.fill: parent
                            flick: flick
                            image: activityImage
                            answers: activityModelData.answers
                            active: activityDialog.selectMode
                            onSelected: hits => {
                                root.selectedAnswers = hits;
                                activityDialog.selectMode = false;
                            }
                        }

                        Repeater {
                            id: answersDropRepeater
                            model: activityModelData.answers
                            Item {
                                id: answerRect
                                property real xScale: activityImage.paintedWidth / activityImage.sourceSize.width
                                property real yScale: activityImage.paintedHeight / activityImage.sourceSize.height
                                property real originalWidth: modelData.coords.width
                                property real originalHeight: modelData.coords.height
                                x: (flick.contentWidth / 2 - activityImage.paintedWidth / 2) + modelData.coords.x * xScale
                                y: (flick.contentHeight / 2 - activityImage.paintedHeight / 2) + modelData.coords.y * yScale
                                width: originalWidth * activityImage.paintedWidth / activityImage.sourceSize.width
                                height: originalHeight * activityImage.paintedHeight / activityImage.sourceSize.height

                                                                 Connections {
                                     target: activityImage
                                     function onPaintedWidthChanged() {
                                         answerRect.width = originalWidth * activityImage.paintedWidth / activityImage.sourceSize.width
                                     }
                                     function onPaintedHeightChanged() {
                                         answerRect.height = originalHeight * activityImage.paintedHeight / activityImage.sourceSize.height
                                     }
                                 }
                                Connections {
                                    target: modelData
                                    function onCoordsChanged() {
                                        answerRect.width = modelData.coords.width * answerRect.xScale;
                                        answerRect.height = modelData.coords.height * answerRect.yScale;
                                        answerRect.x = (flick.contentWidth / 2 - activityImage.paintedWidth / 2) + modelData.coords.x * answerRect.xScale;
                                        answerRect.y = (flick.contentHeight / 2 - activityImage.paintedHeight / 2) + modelData.coords.y * answerRect.yScale;
                                    }
                                }

                                // Dragging breaks the x/y binding; re-derive position
                                // from coords on zoom so moved zones stay put.
                                Connections {
                                    target: activityImage
                                    function onPaintedWidthChanged() {
                                        answerRect.x = (flick.contentWidth / 2 - activityImage.paintedWidth / 2) + modelData.coords.x * answerRect.xScale;
                                    }
                                    function onPaintedHeightChanged() {
                                        answerRect.y = (flick.contentHeight / 2 - activityImage.paintedHeight / 2) + modelData.coords.y * answerRect.yScale;
                                    }
                                }

                                Rectangle {
                                    color: "#7bd5bd"
                                    border.color: root.isAnsSelected(modelData) ? "#00e6e6" : "black"
                                    border.width: root.isAnsSelected(modelData) ? 4 : 2
                                    radius: 5
                                    anchors.fill: parent
                                    opacity: root.isAnsSelected(modelData) ? 0.65 : 0.4
                                }

                                FlowText {
                                    id: answer
                                    text: modelData.group.join(",")
                                    color: myColors.answerColor
                                    rotation: modelData.rotation
                                    height: parent.height
                                    width: parent.width
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    drag.target: parent
                                    onPressed: {
                                        if (mouse.button === Qt.LeftButton) {
                                            if (mouse.modifiers & Qt.ControlModifier)
                                                root.toggleAnsSelection(modelData);
                                            else if (!root.isAnsSelected(modelData))
                                                root.setSingleAnsSelection(modelData);
                                        }
                                        root.moveStartOX = modelData.coords.x;
                                        root.moveStartOY = modelData.coords.y;
                                        root.moveSnap = root.snapshotAnsSelection();
                                    }
                                    onPositionChanged: {
                                        if (drag.active) {
                                            var curOX = (answerRect.x - (flick.contentWidth / 2 - activityImage.paintedWidth / 2)) / answerRect.xScale;
                                            var curOY = (answerRect.y - (flick.contentHeight / 2 - activityImage.paintedHeight / 2)) / answerRect.yScale;
                                            root.applyAnsMove(root.moveSnap, modelData,
                                                              curOX - root.moveStartOX, curOY - root.moveStartOY);
                                        }
                                    }
                                    onReleased: answerRect.setStatus()
                                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                    onDoubleClicked: {
                                        if (mouse.button === Qt.LeftButton) {
                                            answer.visible = false;
                                            textEdit.text = answer.text;
                                            textEdit.visible = true;
                                            textEdit.focus = true;
                                        }
                                    }
                                    onClicked: {
                                        if (mouse.button === Qt.MiddleButton) {
                                            activityModelData.removeAnswer(index);
                                            print("answer silindi");
                                            // config.bookSets[0].saveToJson();
                                        }
                                    }
                                }

                                TextField {
                                    id: textEdit
                                    visible: false
                                    height: parent.height
                                    width: parent.width
                                    color: myColors.answerColor
                                    wrapMode: Text.WordWrap
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    onAccepted: {
                                        visible = false;
                                        var group = textEdit.text.split(",").map(function (item) {
                                            return item.trim();
                                        });
                                        modelData.group = group;
                                        answer.visible = true;
                                        // config.bookSets[0].saveToJson();
                                    }

                                    onEditingFinished: {
                                        visible = false;
                                        var group = textEdit.text.split(",").map(function (item) {
                                            return item.trim();
                                        });
                                        modelData.group = group;
                                        answer.visible = true;
                                        // config.bookSets[0].saveToJson();
                                    }
                                }

                                Rectangle {
                                    id: zoomPoint
                                    color: "black"
                                    radius: 15
                                    width: radius
                                    height: radius

                                    anchors.right: parent.right
                                    anchors.rightMargin: -width / 2
                                    anchors.bottomMargin: -height / 2
                                    anchors.bottom: parent.bottom

                                    MouseArea {
                                        anchors.fill: parent
                                        drag {
                                            target: parent
                                            axis: Drag.XAndYAxis
                                        }

                                        onPressed: {
                                            print("w:", answerRect.width, "h:", answerRect.height);
                                        }

                                        onPositionChanged: {
                                            if (drag.active) {
                                                answerRect.width += mouseX / (activityImage.paintedWidth / activityImage.sourceSize.width);
                                                answerRect.height += mouseY / (activityImage.paintedHeight / activityImage.sourceSize.height);

                                                // Minimum boyutları kontrol et
                                                if (answerRect.width < 18 / (activityImage.paintedWidth / activityImage.sourceSize.width))
                                                    answerRect.width = 18 / (activityImage.paintedWidth / activityImage.sourceSize.width);
                                                if (answerRect.height < 18 / (activityImage.paintedHeight / activityImage.sourceSize.height))
                                                    answerRect.height = 18 / (activityImage.paintedHeight / activityImage.sourceSize.height);

                                                root.syncSizeLive(modelData,
                                                                  answerRect.width / answerRect.xScale,
                                                                  answerRect.height / answerRect.yScale);
                                            }
                                        }
                                        onReleased: {
                                            answerRect.setStatus();
                                            root.syncSizeToSelection(modelData);
                                        }
                                    }
                                }
                                function setStatus() {
                                    var adjustedX = (answerRect.x - (flick.contentWidth / 2 - activityImage.paintedWidth / 2));
                                    var adjustedY = (answerRect.y - (flick.contentHeight / 2 - activityImage.paintedHeight / 2));
                                    var originalX = adjustedX * (activityImage.sourceSize.width / activityImage.paintedWidth);
                                    var originalY = adjustedY * (activityImage.sourceSize.height / activityImage.paintedHeight);

                                    var adjustedW = answerRect.width * (activityImage.sourceSize.width / activityImage.paintedWidth);
                                    var adjustedH = answerRect.height * (activityImage.sourceSize.height / activityImage.paintedHeight);
                                    root.lastHeight = adjustedH;
                                    root.lastWidth = adjustedW;

                                    modelData.coords = Qt.rect(originalX, originalY, adjustedW, adjustedH);
                                    // config.bookSets[0].saveToJson();
                                    print("Changes Are Saved Page Detail set status");
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
