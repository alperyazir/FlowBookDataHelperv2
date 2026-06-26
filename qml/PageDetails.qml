import QtQuick
import QtQuick.Controls
import QtQuick.Shapes

import "newComponents"

Item {
    id: root
    property real imageHeights: (mainwindow.height * 30 / 1080) * (flick.contentWidth / flick.width)
    property var page
    property string currentSelectionType: ""
    property size lastSize: Qt.size(60, 30)

    property bool fillingModeEnabled: false
    property var activeFillRectangle
    property var fillList: []
    property var newSection
    property var activeSession
    property real startRectX: 0
    property real startRectY: 0

    // Crop mode properties
    property bool cropMode: false
    property bool cropRedetect: false      // crop also re-detects circle options
    property var cropActivity: null        // target object during crop mode
    property string cropPathProperty: ""   // property name to update ("sectionPath" or "imagePath")
    property var cropActivityRef: null     // kept after crop mode ends for onCropCompleted
    property string cropNewSectionPath: ""
    property var cropPngRect: null         // crop rect in page-PNG px (for zone sync)
    property bool cropHeaderPick: false    // rect picks the headerText, no crop
    property bool cropFillRedetect: false  // rect re-checks fill sizes vs the answered PDF
    property var cropFillSectionRef: null  // fill section to update (survives endCropMode)
    property var cropFillBand: null        // re-check rect in page-PNG px (kept for the result)
    property string cropIconKind: ""       // rect crops an icon template ("audio"/"video")
    property bool cropPassage: false       // rect picks the passage text to karaoke-align
    property var cropPassageAudioRef: null // audio section to flag karaoke on (survives endCropMode)
    // Karaoke preview: word boxes (with start/end) for the selected audio, lit
    // in sync with in-editor playback. karaokeTime < 0 hides the overlay.
    property var karaokeWords: []
    property real karaokeTime: -1
    property int karaokeActiveIndex: -1
    onKaraokeTimeChanged: {
        if (karaokeTime < 0 || !karaokeWords || karaokeWords.length === 0) {
            karaokeActiveIndex = -1;
            return;
        }
        // Active word = the last word whose start has been reached; it stays
        // lit until the next word starts (short words don't blink).
        var idx = -1;
        for (var i = 0; i < karaokeWords.length; i++) {
            if (karaokeWords[i].start <= karaokeTime)
                idx = i;
            else
                break;
        }
        if (idx === karaokeWords.length - 1
                && karaokeTime > karaokeWords[idx].end + 0.4)
            idx = -1;   // clear after the last word + small tail
        karaokeActiveIndex = idx;
    }
    property real cropStartX: 0
    property real cropStartY: 0
    property real cropEndX: 0
    property real cropEndY: 0
    property bool cropDrawing: false

    anchors.fill: parent

    // HoverHandler lives in the pointer-handler layer so it always sees hover
    // movements even when a Flickable / other MouseArea sits on top of us.
    HoverHandler {
        id: hoverTracker
    }

    // Converts current mouse position inside the picture into page-original coords.
    function _mouseToOriginal() {
        var x = hoverTracker.hovered ? hoverTracker.point.position.x : mainMouseArea.mouseX;
        var y = hoverTracker.hovered ? hoverTracker.point.position.y : mainMouseArea.mouseY;
        // mouse is in viewport space; +contentX/Y maps it into the
        // scrolled content, then -centering offset into painted space
        // (must match the display formula or items drift when zoomed).
        var adjustedX = (x + flick.contentX) - (flick.contentWidth / 2 - picture.paintedWidth / 2);
        var adjustedY = (y + flick.contentY) - (flick.contentHeight / 2 - picture.paintedHeight / 2);
        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);
        return { x: originalX, y: originalY };
    }

    // Open the right-side Audio panel for a freshly created (last) section.
    function openAudioSidebar(sec) {
        if (!sec) return;
        sideBar.hideAllComponent();
        sideBar.audioVisible = true;
        sideBar.page = page;
        sideBar.sectionIndex = page.sections.length - 1;
        sideBar.audioModelData = sec;
        clearTextFocus();
    }

    // Open the right-side Video panel for a freshly created (last) section.
    function openVideoSidebar(sec) {
        if (!sec) return;
        sideBar.hideAllComponent();
        sideBar.videoVisible = true;
        sideBar.page = page;
        sideBar.sectionIndex = page.sections.length - 1;
        sideBar.videoModelData = sec;
        clearTextFocus();
    }

    function addAudioAtMouse() {
        if (!root.page) return;
        var p = _mouseToOriginal();
        openAudioSidebar(root.page.createNewAudioSection(p.x, p.y, root.imageHeights, root.imageHeights, ""));
        currentSelectionType = "";
    }

    function addVideoAtMouse() {
        if (!root.page) return;
        var p = _mouseToOriginal();
        openVideoSidebar(root.page.createNewVideoSection(p.x, p.y, root.imageHeights, root.imageHeights, ""));
        currentSelectionType = "";
    }

    function addFillAtMouse() {
        if (!root.page) return;
        root.fillingModeEnabled = true;
        currentSelectionType = "fill";
        var p = _mouseToOriginal();
        root.activeSession = root.page.getAvailableSection("fill");
        root.activeSession.createNewAnswer(p.x, p.y, root.lastSize.width, root.lastSize.height);
        sideBar.hideAllComponent();
        sideBar.fillVisible = true;
        sideBar.page = page;
        sideBar.section = activeSession;
        sideBar.fillList = activeSession.answers;
        sideBar.fillIndex = activeSession.answers.length - 1;
    }

    // Drop keyboard focus from whatever sidebar text field holds it, so
    // typing stops and the c/h shortcuts work. Clearing the focused
    // item's focus directly is more reliable than forceActiveFocus on a
    // MouseArea (which doesn't always steal focus across the sidebar's
    // focus scope). mainwindow is the ApplicationWindow (in scope here).
    function clearTextFocus() {
        var fi = mainwindow.activeFocusItem;
        if (fi && fi !== mainMouseArea)
            fi.focus = false;
        mainMouseArea.forceActiveFocus();
    }

    // Open the right-side activity panel for a freshly created section
    // (createNewActivity appends it, so it is the last one). Also moves
    // keyboard focus off any sidebar text field so the c/h shortcuts work.
    function openActivitySidebar(sec) {
        if (!sec || !sec.activity) return;
        sideBar.hideAllComponent();
        sideBar.activityVisible = true;
        sideBar.page = page;
        sideBar.sectionIndex = page.sections.length - 1;
        sideBar.activityModelData = sec.activity;
        sideBar.sectionModelData = sec;
        clearTextFocus();
    }

    function addActivityAtMouse(activityType) {
        if (!root.page) return;
        var p = _mouseToOriginal();
        openActivitySidebar(root.page.createNewActivity(
            p.x, p.y, root.imageHeights, root.imageHeights, activityType));
        currentSelectionType = "";
    }

    function removeSelectedSection() {
        var hasSelection = sideBar.audioVisible || sideBar.videoVisible
                        || sideBar.activityVisible || sideBar.fillVisible
                        || sideBar.circleVisible || sideBar.fillwColorVisible
                        || sideBar.drawMatchedVisible;
        if (!hasSelection) return;
        if (!sideBar.page || sideBar.sectionIndex < 0) return;

        // A multi-selection (checkbox / rubber-band) takes priority: Delete
        // removes every selected fill answer across all fill sections, not the
        // whole section.
        if (sideBar.fillVisible && sideBar.fillSelection
            && sideBar.fillSelection.length > 0) {
            deleteSelectedFills();
            return;
        }

        // If a single fill is selected, delete just that one instead of the whole section
        if (sideBar.fillVisible && sideBar.section
            && sideBar.fillIndex >= 0
            && sideBar.fillIndex < sideBar.section.answers.length) {
            sideBar.section.removeAnswer(sideBar.fillIndex);
            sideBar.fillList = sideBar.section.answers;
            return;
        }

        var pg = sideBar.page;
        var idx = sideBar.sectionIndex;
        sideBar.hideAllComponent();
        pg.removeSection(idx);
    }

    // --- On-page multi-selection of fill answers (rubber-band / Ctrl+click) ---
    // The selection lives in sideBar.fillSelection (array of answer objects)
    // so the page highlights and the Fill panel checkboxes stay in sync.
    property bool fillSelectMode: false   // 'r' toggles the rubber-band tool
    onPageChanged: { sideBar.fillSelection = []; fillSelectMode = false; }

    function isFillSelected(ans) {
        return sideBar.fillSelection.indexOf(ans) !== -1;
    }
    function setSingleFillSelection(ans) {
        sideBar.fillSelection = ans ? [ans] : [];
    }
    function toggleFillSelection(ans) {
        var arr = sideBar.fillSelection.slice();
        var p = arr.indexOf(ans);
        if (p === -1)
            arr.push(ans);
        else
            arr.splice(p, 1);
        sideBar.fillSelection = arr;
    }
    function clearFillSelection() {
        sideBar.fillSelection = [];
    }

    // Delete every fill answer in the current multi-selection. The selection
    // can span several fill sections, so remove from each one high index ->
    // low so the remaining indices stay valid.
    function deleteSelectedFills() {
        var sel = sideBar.fillSelection;
        if (!root.page || !sel || sel.length === 0)
            return;
        var secs = root.page.sections;
        for (var i = 0; i < secs.length; i++) {
            if (secs[i].type !== "fill")
                continue;
            var ans = secs[i].answers;
            var idxs = [];
            for (var j = 0; j < ans.length; j++)
                if (sel.indexOf(ans[j]) !== -1)
                    idxs.push(j);
            idxs.sort(function (a, b) { return b - a; });
            for (var k = 0; k < idxs.length; k++)
                secs[i].removeAnswer(idxs[k]);
        }
        sideBar.fillSelection = [];
        // Refresh the open Fill panel list against its (still-present) section.
        if (sideBar.fillVisible && sideBar.section)
            sideBar.fillList = sideBar.section.answers;
    }

    // Apply a fill re-check result: drop the section's fills whose center sits
    // in the drawn band, then add the freshly detected ones (page-PNG px).
    function applyFillRedetect(res) {
        var sec = root.cropFillSectionRef;
        var band = root.cropFillBand;
        root.cropFillSectionRef = null;
        root.cropFillBand = null;
        if (!sec || !band) {
            print("Fill re-check: no target section / band");
            return;
        }
        var found = res.answer ? res.answer.length : 0;
        if (found === 0) {
            // Detection came back empty — keep the existing fills rather than
            // wiping them on a miss.
            print("Fill re-check: nothing detected in rect, fills kept");
            return;
        }
        // Delete existing answers that overlap the band (high -> low). Using
        // rect intersection — not center-in-band — so an oversized/merged fill
        // (exactly what re-check targets) whose center sits outside the drawn
        // rect is still replaced instead of left behind as a duplicate.
        var ans = sec.answers;
        var del = [];
        for (var i = 0; i < ans.length; i++) {
            var c = ans[i].coords;
            if (c.x < band.x + band.w && c.x + c.width > band.x
                && c.y < band.y + band.h && c.y + c.height > band.y)
                del.push(i);
        }
        del.sort(function (a, b) { return b - a; });
        for (var k = 0; k < del.length; k++)
            sec.removeAnswer(del[k]);
        // Insert the redetected fills.
        for (var j = 0; j < found; j++) {
            var a = res.answer[j];
            var na = sec.createNewAnswer(a.coords.x, a.coords.y,
                                         a.coords.w, a.coords.h, a.text || "");
            if (na && a.isTextBold !== undefined)
                na.isTextBold = a.isTextBold;
        }
        sideBar.fillList = sec.answers;
        print("Fill re-check: removed " + del.length + ", added " + found);
    }

    // Open the Fill panel for the section of the first selected fill so the
    // selection shows up (checked) in the sidebar list.
    function openFillPanelForSelection() {
        var sel = sideBar.fillSelection;
        if (sel.length === 0)
            return;
        var first = sel[0];
        var secs = root.page ? root.page.sections : [];
        for (var i = 0; i < secs.length; i++) {
            if (secs[i].type !== "fill")
                continue;
            var ans = secs[i].answers;
            for (var j = 0; j < ans.length; j++) {
                if (ans[j] === first) {
                    sideBar.fillVisible = true;
                    sideBar.page = page;
                    sideBar.section = secs[i];
                    sideBar.fillList = ans;
                    sideBar.fillIndex = j;
                    sideBar.sectionIndex = i;
                    return;
                }
            }
        }
    }

    // Picture-space point -> original-image coords (same transform the fill
    // delegates and setTotalStatus use; no contentX since we're inside content).
    function _picToOriginal(mx, my) {
        var ax = mx - (flick.contentWidth / 2 - picture.paintedWidth / 2);
        var ay = my - (flick.contentHeight / 2 - picture.paintedHeight / 2);
        return {
            x: ax * (picture.sourceSize.width / picture.paintedWidth),
            y: ay * (picture.sourceSize.height / picture.paintedHeight)
        };
    }

    // Select every fill answer whose bounds intersect the dragged band rect
    // (band corners given in picture space).
    function selectFillsInPicRect(x0, y0, x1, y1) {
        var p0 = _picToOriginal(Math.min(x0, x1), Math.min(y0, y1));
        var p1 = _picToOriginal(Math.max(x0, x1), Math.max(y0, y1));
        var rx = p0.x, ry = p0.y, rw = p1.x - p0.x, rh = p1.y - p0.y;
        var sel = [];
        var secs = root.page ? root.page.sections : [];
        for (var i = 0; i < secs.length; i++) {
            if (secs[i].type !== "fill")
                continue;
            var ans = secs[i].answers;
            for (var j = 0; j < ans.length; j++) {
                var c = ans[j].coords;
                if (rx < c.x + c.width && rx + rw > c.x
                    && ry < c.y + c.height && ry + rh > c.y)
                    sel.push(ans[j]);
            }
        }
        sideBar.fillSelection = sel;
        openFillPanelForSelection();
    }

    // After resizing one selected fill, give every other selected fill the
    // same size (position unchanged).
    function syncSizeToSelection(src) {
        if (sideBar.fillSelection.indexOf(src) === -1)
            return;
        syncSizeLive(src, src.coords.width, src.coords.height);
    }

    // --- Group move: absolute (snapshot + total delta) to avoid integer
    // truncation drift that would otherwise break the formation. ---
    property var moveSnap: []
    property real moveStartOX: 0
    property real moveStartOY: 0

    function snapshotFillSelection() {
        var sel = sideBar.fillSelection;
        var snap = [];
        for (var i = 0; i < sel.length; i++)
            snap.push({ a: sel[i], x: sel[i].coords.x, y: sel[i].coords.y });
        return snap;
    }
    function applyFillMove(snap, src, dX, dY) {
        if (sideBar.fillSelection.length < 2)
            return;
        for (var i = 0; i < snap.length; i++) {
            if (snap[i].a === src)
                continue;
            var c = snap[i].a.coords;
            snap[i].a.coords = Qt.rect(Math.round(snap[i].x + dX), Math.round(snap[i].y + dY), c.width, c.height);
        }
    }

    // Align every selected fill to the leftmost one ('l').
    function alignSelectedLeft() {
        var sel = sideBar.fillSelection;
        if (sel.length < 2)
            return;
        var minX = sel[0].coords.x;
        for (var i = 1; i < sel.length; i++)
            if (sel[i].coords.x < minX)
                minX = sel[i].coords.x;
        for (var j = 0; j < sel.length; j++) {
            var c = sel[j].coords;
            sel[j].coords = Qt.rect(minX, c.y, c.width, c.height);
        }
    }

    // Align every selected fill to the bottom-most one ('b').
    function alignSelectedBottom() {
        var sel = sideBar.fillSelection;
        if (sel.length < 2)
            return;
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

    // Align every selected fill's right edge to the rightmost one.
    function alignSelectedRight() {
        var sel = sideBar.fillSelection;
        if (sel.length < 2)
            return;
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

    // Align every selected fill to the top-most one.
    function alignSelectedTop() {
        var sel = sideBar.fillSelection;
        if (sel.length < 2)
            return;
        var minY = sel[0].coords.y;
        for (var i = 1; i < sel.length; i++)
            if (sel[i].coords.y < minY)
                minY = sel[i].coords.y;
        for (var j = 0; j < sel.length; j++) {
            var c = sel[j].coords;
            sel[j].coords = Qt.rect(c.x, minY, c.width, c.height);
        }
    }

    // Live variant called on every drag step: w/h are given directly in
    // original coords (the dragged fill's own coords aren't written until
    // release, so we can't read them yet).
    function syncSizeLive(src, w, h) {
        var sel = sideBar.fillSelection;
        if (sel.length < 2 || sel.indexOf(src) === -1)
            return;
        for (var i = 0; i < sel.length; i++) {
            var a = sel[i];
            if (a === src)
                continue;
            var c = a.coords;
            if (c.width === w && c.height === h)
                continue;
            a.coords = Qt.rect(c.x, c.y, w, h);
        }
    }

    // Top banner shown while the fill-select (rubber-band) tool is active.
    Rectangle {
        visible: root.fillSelectMode
        z: 200
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 10
        width: bannerRow.implicitWidth + 28
        height: 34
        radius: 17
        color: "#cc009ca6"
        border.color: "#00e6e6"
        border.width: 1
        Row {
            id: bannerRow
            anchors.centerIn: parent
            spacing: 8
            Text {
                text: "▭ Select fill"
                color: "white"
                font.bold: true
                font.pixelSize: 14
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "drag to select · Esc to exit"
                color: "#d5f2f4"
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    MouseArea {
        id: mainMouseArea
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton | Qt.RightButton | Qt.LeftButton
        scrollGestureEnabled: true
        hoverEnabled: true

        property bool dragging: false
        property bool drawing: false
        property real lastX: 0
        property real lastY: 0

        onPressed: mouse => {
                       // Any click on the page takes focus off a sidebar text
                       // field (so editing stops and the c/h shortcuts work).
                       root.clearTextFocus();
                       if (mouse.button === Qt.MiddleButton) {
                           dragging = true;
                           lastX = mouse.x;
                           lastY = mouse.y;
                       } else if (mouse.button === Qt.RightButton) {
                           menu.popup(mouse.x, mouse.y);
                       } else if ((mouse.button === Qt.LeftButton) && root.fillingModeEnabled)
                       {}
                   }

        onReleased: mouse => {
                        if (mouse.button === Qt.MiddleButton) {
                            dragging = false;
                        } else if (mouse.button === Qt.LeftButton && root.fillingModeEnabled)
                        {}
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
                     // if (event.angleDelta.y > 0) {
                     //     flick.zoomIn();
                     // } else {
                     //     flick.zoomOut();
                     // }
                     event.accepted = true;
                 }

        onPressAndHold: mouse => {
                            var adjustedX = mouse.x - (flick.contentWidth / 2 - picture.paintedWidth / 2);
                            var adjustedY = mouse.y - (flick.contentHeight / 2 - picture.paintedHeight / 2);

                            print(mouse.x, mouse.y)

                            // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                            var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                            var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);
                            var answer;
                            if (currentSelectionType === "fill") {
                                root.activeSession = root.page.getAvailableSection("fill");
                                answer = root.activeSession.createNewAnswer(originalX, originalY, root.lastSize.width, root.lastSize.height);
                            } else if (currentSelectionType === "circle") {
                                root.activeSession = root.page.getAvailableSection("circle");
                                answer = root.activeSession.createNewAnswer(originalX, originalY, root.lastSize.width, root.lastSize.height);
                            } else if (currentSelectionType === "fillWithColor") {
                                root.activeSession = root.page.getAvailableSection("fillWithColor");
                                answer = root.activeSession.createNewAnswer(originalX, originalY, root.lastSize.width, root.lastSize.height);
                            } else if (currentSelectionType === "drawMatchedLine") {
                                root.activeSession = root.page.getAvailableSection("drawMatchedLine");
                                answer = root.activeSession.createNewAnswerDrawMacthedLine(originalX, originalY, root.lastSize.width, root.lastSize.height);
                            }

                            // if(root.activeSession.answers.length>1) {
                            //     lastWidth = root.activeSession.answers[root.activeSession.answers.length -2].width
                            //     lastHeight = root.activeSession.answers[root.activeSession.answers.length -2].height
                            // }

                            if (currentSelectionType === "fill") {
                                sideBar.hideAllComponent();
                                sideBar.fillVisible = true;
                                sideBar.page = page;
                                sideBar.section = activeSession;
                                sideBar.fillList = activeSession.answers;
                                sideBar.fillIndex = activeSession.answers.length - 1;
                            } else if (currentSelectionType === "circle") {
                                sideBar.hideAllComponent();
                                sideBar.circleVisible = true;
                                sideBar.page = page;
                                sideBar.section = activeSession;
                                sideBar.circleList = activeSession.answers;
                            } else if (currentSelectionType === "fillWithColor") {
                                sideBar.hideAllComponent();
                                sideBar.fillwColorVisible = true;
                                sideBar.page = page;
                                sideBar.section = activeSession;
                                sideBar.fillWColorList = activeSession.answers;
                            } else if (currentSelectionType === "drawMatchedLine") {
                                sideBar.hideAllComponent();
                                sideBar.drawMatchedVisible = true;
                                sideBar.page = page;
                                sideBar.section = activeSession;
                                sideBar.drawMatchedLineList = activeSession.answers;
                            }

                            // config.bookSets[0].saveToJson();
                            print("Changes Are Saved activity Fill on Triggered");
                        }

        Menu {
            id: menu
            implicitWidth: 260
            MenuItem {
                text: "Audio\t(A)"
                onTriggered: {
                    var adjustedX = mainMouseArea.mouseX - (flick.contentWidth / 2 - picture.paintedWidth / 2);
                    var adjustedY = mainMouseArea.mouseY - (flick.contentHeight / 2 - picture.paintedHeight / 2);

                    // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                    var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                    var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                    openAudioSidebar(root.page.createNewAudioSection(originalX, originalY, root.imageHeights, root.imageHeights, ""));
                    // config.bookSets[0].saveToJson();
                    print("Changes Are Saved activity Audio on Triggered");
                    currentSelectionType = "";
                }
            }
            MenuItem {
                text: "Video\t(V)"
                onTriggered: {
                    var adjustedX = mainMouseArea.mouseX - (flick.contentWidth / 2 - picture.paintedWidth / 2);
                    var adjustedY = mainMouseArea.mouseY - (flick.contentHeight / 2 - picture.paintedHeight / 2);

                    // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                    var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                    var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                    openVideoSidebar(root.page.createNewVideoSection(originalX, originalY, root.imageHeights, root.imageHeights, ""));
                    // config.bookSets[0].saveToJson();
                    print("Changes Are Saved activity Video on Triggered");
                    currentSelectionType = "";
                }
            }
            MenuItem {
                text: "Fill\t(F)"
                highlighted: currentSelectionType == "fill"
                onTriggered: {
                    root.fillingModeEnabled = true;
                    currentSelectionType = "fill";

                    var adjustedX = mainMouseArea.mouseX - (flick.contentWidth / 2 - picture.paintedWidth / 2);
                    var adjustedY = mainMouseArea.mouseY - (flick.contentHeight / 2 - picture.paintedHeight / 2);

                    // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                    var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                    var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                    root.activeSession = root.page.getAvailableSection("fill");

                    // if(root.activeSession.answers.length>1) {
                    //     lastWidth = root.activeSession.answers[root.activeSession.answers.length -2].width
                    //     lastHeight = root.activeSession.answers[root.activeSession.answers.length -2].height
                    // }
                    var answer = root.activeSession.createNewAnswer(originalX, originalY, root.lastSize.width, root.lastSize.height);

                    sideBar.hideAllComponent();
                    sideBar.fillVisible = true;
                    sideBar.page = page;
                    sideBar.section = activeSession;
                    sideBar.fillList = activeSession.answers;
                    sideBar.fillIndex = activeSession.answers.length - 1;

                    // config.bookSets[0].saveToJson();
                    print("Changes Are Saved activity Fill on Triggered");
                }
            }
            MenuItem {
                text: "Circle"
                highlighted: currentSelectionType === "circle"
                onTriggered: {
                    currentSelectionType = "circle";

                    var adjustedX = mainMouseArea.mouseX - (flick.contentWidth / 2 - picture.paintedWidth / 2);
                    var adjustedY = mainMouseArea.mouseY - (flick.contentHeight / 2 - picture.paintedHeight / 2);

                    // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                    var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                    var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                    root.activeSession = root.page.getAvailableSection("circle");

                    // if(root.activeSession.answers.length>1) {
                    //     lastWidth = root.activeSession.answers[root.activeSession.answers.length -2].width
                    //     lastHeight = root.activeSession.answers[root.activeSession.answers.length -2].height
                    // }
                    var answer = root.activeSession.createNewAnswer(originalX, originalY, root.lastSize.width, root.lastSize.height);

                    sideBar.hideAllComponent();
                    sideBar.circleVisible = true;
                    sideBar.page = page;
                    sideBar.section = activeSession;
                    sideBar.circleList = activeSession.answers;

                    // config.bookSets[0].saveToJson();
                    print("Changes Are Saved activity Circle on Triggered");
                }
            }
            MenuItem {
                text: "Fill with Color"
                highlighted: currentSelectionType === "fillWithColor"
                onTriggered: {
                    currentSelectionType = "fillWithColor";

                    var adjustedX = mainMouseArea.mouseX - (flick.contentWidth / 2 - picture.paintedWidth / 2);
                    var adjustedY = mainMouseArea.mouseY - (flick.contentHeight / 2 - picture.paintedHeight / 2);

                    // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                    var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                    var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                    root.activeSession = root.page.getAvailableSection("fillWithColor");

                    // if(root.activeSession.answers.length>1) {
                    //     lastWidth = root.activeSession.answers[root.activeSession.answers.length -2].width
                    //     lastHeight = root.activeSession.answers[root.activeSession.answers.length -2].height
                    // }
                    var answer = root.activeSession.createNewAnswer(originalX, originalY, root.lastSize.width, root.lastSize.height);

                    sideBar.hideAllComponent();
                    sideBar.fillwColorVisible = true;
                    sideBar.page = page;
                    sideBar.section = activeSession;
                    sideBar.fillWColorList = activeSession.answers;

                    // config.bookSets[0].saveToJson();
                    print("Changes Are Saved activity Circle on Triggered");
                }
            }
            MenuItem {
                text: "Draw Matched Line"
                highlighted: currentSelectionType === "drawMatchedLine"
                onTriggered: {
                    currentSelectionType = "drawMatchedLine";
                    var adjustedX = mainMouseArea.mouseX - (flick.contentWidth / 2 - picture.paintedWidth / 2);
                    var adjustedY = mainMouseArea.mouseY - (flick.contentHeight / 2 - picture.paintedHeight / 2);

                    // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                    var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                    var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                    root.activeSession = root.page.getAvailableSection("drawMatchedLine");
                    print(root.activeSession);

                    // if(root.activeSession.answers.length>1) {
                    //     lastWidth = root.activeSession.answers[root.activeSession.answers.length -2].width
                    //     lastHeight = root.activeSession.answers[root.activeSession.answers.length -2].height
                    // }
                    var answer = root.activeSession.createNewAnswerDrawMacthedLine(originalX, originalY, root.lastSize.width, root.lastSize.height);

                    sideBar.hideAllComponent();
                    sideBar.drawMatchedVisible = true;
                    sideBar.page = page;
                    sideBar.section = activeSession;
                    sideBar.drawMatchedLineList = activeSession.answers;

                    // config.bookSets[0].saveToJson();
                    print("Changes Are Saved activity Circle on Triggered");
                }
            }

            Menu {
                id: activityMenu
                title: "Activity"
                implicitWidth: 300
                MenuItem {
                    text: "Drag Drop Picture\t(A → D)"
                    onTriggered: {
                        var adjustedX = (mainMouseArea.mouseX + flick.contentX) - (flick.contentWidth / 2 - picture.paintedWidth / 2);
                        var adjustedY = (mainMouseArea.mouseY + flick.contentY) - (flick.contentHeight / 2 - picture.paintedHeight / 2);

                        // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                        openActivitySidebar(root.page.createNewActivity(originalX, originalY, root.imageHeights, root.imageHeights, "dragdroppicture"));
                        // config.bookSets[0].saveToJson();
                        print("Changes Are Saved activity Drag Drop on Triggered");
                        currentSelectionType = "";
                    }
                }
                MenuItem {
                    text: "Drag Drop Picture Group\t(A → G)"
                    onTriggered: {
                        var adjustedX = (mainMouseArea.mouseX + flick.contentX) - (flick.contentWidth / 2 - picture.paintedWidth / 2);
                        var adjustedY = (mainMouseArea.mouseY + flick.contentY) - (flick.contentHeight / 2 - picture.paintedHeight / 2);

                        // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                        openActivitySidebar(root.page.createNewActivity(originalX, originalY, root.imageHeights, root.imageHeights, "dragdroppicturegroup"));
                        // config.bookSets[0].saveToJson();
                        print("Changes Are Saved activity Drag Drop Picture Group on Triggered");
                        currentSelectionType = "";
                    }
                }
                MenuItem {
                    text: "Fill Picture\t(A → F)"
                    onTriggered: {
                        var adjustedX = (mainMouseArea.mouseX + flick.contentX) - (flick.contentWidth / 2 - picture.paintedWidth / 2);
                        var adjustedY = (mainMouseArea.mouseY + flick.contentY) - (flick.contentHeight / 2 - picture.paintedHeight / 2);

                        // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                        openActivitySidebar(root.page.createNewActivity(originalX, originalY, root.imageHeights, root.imageHeights, "fillpicture"));
                        // config.bookSets[0].saveToJson();
                        print("Changes Are Saved activity Fill Picture on Triggered");
                        currentSelectionType = "";
                    }
                }
                MenuItem {
                    text: "Circle\t(A → C)"
                    onTriggered: {
                        var adjustedX = (mainMouseArea.mouseX + flick.contentX) - (flick.contentWidth / 2 - picture.paintedWidth / 2);
                        var adjustedY = (mainMouseArea.mouseY + flick.contentY) - (flick.contentHeight / 2 - picture.paintedHeight / 2);

                        // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                        openActivitySidebar(root.page.createNewActivity(originalX, originalY, root.imageHeights, root.imageHeights, "circle"));
                        // config.bookSets[0].saveToJson();
                        print("Changes Are Saved Circle on Triggered");
                        currentSelectionType = "";
                    }
                }

                MenuItem {
                    text: "Match\t(A → M)"
                    onTriggered: {
                        var adjustedX = (mainMouseArea.mouseX + flick.contentX) - (flick.contentWidth / 2 - picture.paintedWidth / 2);
                        var adjustedY = (mainMouseArea.mouseY + flick.contentY) - (flick.contentHeight / 2 - picture.paintedHeight / 2);

                        // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                        openActivitySidebar(root.page.createNewActivity(originalX, originalY, root.imageHeights, root.imageHeights, "matchTheWords"));
                        // config.bookSets[0].saveToJson();
                        print("Changes Are Saved MenuItem onmatchTheWords Triggered");
                    }
                }

                MenuItem {
                    text: "Puzzle Find Words\t(A → P)"
                    onTriggered: {
                        var adjustedX = (mainMouseArea.mouseX + flick.contentX) - (flick.contentWidth / 2 - picture.paintedWidth / 2);
                        var adjustedY = (mainMouseArea.mouseY + flick.contentY) - (flick.contentHeight / 2 - picture.paintedHeight / 2);

                        // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                        openActivitySidebar(root.page.createNewActivity(originalX, originalY, root.imageHeights, root.imageHeights, "puzzleFindWords"));
                        // config.bookSets[0].saveToJson();
                        print("Changes Are Saved MenuItem Puzzle Find Words Triggered");
                        currentSelectionType = "";
                    }
                }

                MenuItem {
                    text: "Mark With X\t(A → X)"
                    onTriggered: {
                        var adjustedX = (mainMouseArea.mouseX + flick.contentX) - (flick.contentWidth / 2 - picture.paintedWidth / 2);
                        var adjustedY = (mainMouseArea.mouseY + flick.contentY) - (flick.contentHeight / 2 - picture.paintedHeight / 2);

                        // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                        openActivitySidebar(root.page.createNewActivity(originalX, originalY, root.imageHeights, root.imageHeights, "markwithx"));
                        // config.bookSets[0].saveToJson();
                        print("Changes Are Saved MenuItem Mark With X Triggered");
                        currentSelectionType = "";
                    }
                }

                MenuItem {
                    text: "Coloring\t(A → L)"
                    onTriggered: {
                        var adjustedX = (mainMouseArea.mouseX + flick.contentX) - (flick.contentWidth / 2 - picture.paintedWidth / 2);
                        var adjustedY = (mainMouseArea.mouseY + flick.contentY) - (flick.contentHeight / 2 - picture.paintedHeight / 2);

                        // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                        openActivitySidebar(root.page.createNewActivity(originalX, originalY, root.imageHeights, root.imageHeights, "coloring"));
                        print("Changes Are Saved MenuItem Coloring Triggered");
                        currentSelectionType = "";
                    }
                }
            }
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

        property real lastContentHeight
        property real lastContentWidth

        property real minZoom: 1.0
        property real maxZoom: 4.0
        property real zoomLevel: 1
        property real zoomStep: 0.1
        property real pinchCenter: 1

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
        }

        Image {
            id: picture
            source: page ? qsTr("file:" + appPath + page.image_path) : ""
            fillMode: Image.PreserveAspectFit
            width: Math.max(flick.contentWidth, flick.width)
            height: Math.max(flick.contentHeight, flick.height)

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                propagateComposedEvents: true
                pressAndHoldInterval: 500
                // Only hold onto left-drags while the rubber-band tool is active;
                // otherwise let the Flickable steal them so left-drag pans when
                // zoomed in.
                preventStealing: root.fillSelectMode

                // Rubber-band selection of fills (in picture space).
                property bool bandPressed: false
                property bool banding: false
                property real bandX0: 0
                property real bandY0: 0
                property real bandX1: 0
                property real bandY1: 0

                // A click on the page image drops focus from any sidebar
                // text field (this MouseArea, not mainMouseArea, gets the
                // left-clicks on the page).
                cursorShape: root.fillSelectMode ? Qt.CrossCursor : Qt.ArrowCursor

                onPressed: mouse => {
                    root.clearTextFocus();
                    if (mouse.button === Qt.LeftButton && root.fillSelectMode && !root.cropMode) {
                        mouseArea.bandPressed = true;
                        mouseArea.banding = false;
                        mouseArea.bandX0 = mouse.x;
                        mouseArea.bandY0 = mouse.y;
                        mouseArea.bandX1 = mouse.x;
                        mouseArea.bandY1 = mouse.y;
                    }
                }

                onPositionChanged: mouse => {
                    if (mouseArea.bandPressed) {
                        mouseArea.bandX1 = mouse.x;
                        mouseArea.bandY1 = mouse.y;
                        if (!mouseArea.banding
                            && (Math.abs(mouseArea.bandX1 - mouseArea.bandX0) > 3
                                || Math.abs(mouseArea.bandY1 - mouseArea.bandY0) > 3))
                            mouseArea.banding = true;
                    }
                }

                onReleased: mouse => {
                    if (mouseArea.bandPressed) {
                        if (mouseArea.banding) {
                            root.selectFillsInPicRect(mouseArea.bandX0, mouseArea.bandY0,
                                                      mouseArea.bandX1, mouseArea.bandY1);
                            root.fillSelectMode = false;   // one-shot: exit after selecting
                        } else {
                            root.clearFillSelection();   // plain click on empty space
                        }
                        mouseArea.bandPressed = false;
                        mouseArea.banding = false;
                    }
                }

                onWheel: function (wheel) {
                    if (wheel.angleDelta.y / 120 * flick.contentWidth * 0.1 + flick.contentWidth > flick.width && wheel.angleDelta.y / 120 * flick.contentHeight * 0.1 + flick.contentHeight > flick.height) {
                        // Zoom around the cursor: wheel.x/y are already in content
                        // coords (this MouseArea fills the content image).
                        flick.resizeContent(wheel.angleDelta.y / 120 * flick.contentWidth * 0.1 + flick.contentWidth, wheel.angleDelta.y / 120 * flick.contentHeight * 0.1 + flick.contentHeight, Qt.point(wheel.x, wheel.y));
                        flick.returnToBounds();
                    } else {
                        flick.resizeContent(flick.width, flick.height, Qt.point(flick.width / 2, flick.height / 2));
                        flick.returnToBounds();
                    }
                }
            }

            // Rubber-band selection rectangle (picture space).
            Rectangle {
                visible: mouseArea.banding
                z: 50
                x: Math.min(mouseArea.bandX0, mouseArea.bandX1)
                y: Math.min(mouseArea.bandY0, mouseArea.bandY1)
                width: Math.abs(mouseArea.bandX1 - mouseArea.bandX0)
                height: Math.abs(mouseArea.bandY1 - mouseArea.bandY0)
                color: "#2200e6e6"
                border.color: "#00e6e6"
                border.width: 1
            }

            // Karaoke highlight overlay: one box per passage word, mapped from
            // PNG px to the painted page (same transform as section rects).
            Repeater {
                id: karaokeOverlay
                model: root.karaokeWords
                Rectangle {
                    // Word bbox from fitz is line-height tall; inset vertically
                    // and keep the fill light so the text stays readable.
                    property real sx: picture.paintedWidth / picture.sourceSize.width
                    property real sy: picture.paintedHeight / picture.sourceSize.height
                    visible: root.karaokeTime >= 0 && index === root.karaokeActiveIndex
                    x: (flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.bbox.x * sx
                    y: (flick.contentHeight / 2 - picture.paintedHeight / 2) + (modelData.bbox.y + modelData.bbox.h * 0.08) * sy
                    width: modelData.bbox.w * sx
                    height: modelData.bbox.h * 0.60 * sy
                    radius: 3
                    z: 50
                    color: "#4dffd200"
                }
            }

            Repeater {
                id: sections
                model: page ? page.sections : []
                Item {
                    id: sectionItem
                    property var currentSection: modelData
                    property var sectionData: modelData
                    property var sectionType: modelData.type
                    property int sectionIndex: index
                    property var sectionAnswers: modelData.answers
                    property var circleIsCorrectArr: []
                    // audio
                    Rectangle {
                        id: sectionRect
                        color: "transparent"
                        visible: modelData.type === "audio" ? true : false
                        x: (flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.coords.x * (picture.paintedWidth / picture.sourceSize.width)
                        y: (flick.contentHeight / 2 - picture.paintedHeight / 2) + modelData.coords.y * (picture.paintedHeight / picture.sourceSize.height)
                        width: modelData.coords.width * (picture.paintedWidth / picture.sourceSize.width)
                        height: modelData.coords.height * (picture.paintedHeight / picture.sourceSize.height)
                        // Highlight when this audio is the one open in the sidebar.
                        Rectangle {
                            visible: sideBar.audioVisible && sideBar.audioModelData === modelData
                            anchors.centerIn: parent
                            width: root.imageHeights + 14
                            height: root.imageHeights + 14
                            radius: 8
                            color: "#3300e6e6"
                            border.color: "#00e6e6"
                            border.width: 2
                        }

                        Image {
                            id: audioImage
                            source: "qrc:/icons/sound.svg"
                            height: parent.height > 0 ? root.imageHeights : 0
                            width: height
                            smooth: true
                            antialiasing: true
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            // The section rect is sized from coords (much smaller
                            // than the drawn icon), so filling it left only a tiny
                            // hittable spot at the center. Grow the drag area to the
                            // visible icon (matching the selected highlight) so the
                            // whole icon can be grabbed and moved.
                            anchors.centerIn: parent
                            width: Math.max(parent.width, root.imageHeights + 14)
                            height: Math.max(parent.height, root.imageHeights + 14)
                            drag.target: parent
                            onPressed: {
                                sideBar.hideAllComponent();
                                sideBar.audioVisible = true;
                                sideBar.page = page;
                                sideBar.sectionIndex = index;
                                sideBar.audioModelData = modelData;
                            }

                            onReleased: {
                                var adjustedX = (sectionRect.x - (flick.contentWidth / 2 - picture.paintedWidth / 2));
                                var adjustedY = (sectionRect.y - (flick.contentHeight / 2 - picture.paintedHeight / 2));

                                // Zoom seviyesini ve PaintedWidth/PaintedHeight'i hesaba katarak orijinal koordinatları bul
                                var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                                var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                                modelData.coords = Qt.rect(originalX, originalY, modelData.coords.width, modelData.coords.height);
                                // config.bookSets[0].saveToJson();
                                //print("Changes Are Saved Page Detail Audio On Released Triggered");
                            }
                        }
                    }
                    //video
                    Rectangle {
                        id: videoRect
                        color: "transparent"
                        visible: modelData.type === "video" ? true : false
                        x: (flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.coords.x * (picture.paintedWidth / picture.sourceSize.width)
                        y: (flick.contentHeight / 2 - picture.paintedHeight / 2) + modelData.coords.y * (picture.paintedHeight / picture.sourceSize.height)
                        width: modelData.coords.width * (picture.paintedWidth / picture.sourceSize.width)
                        height: modelData.coords.height * (picture.paintedHeight / picture.sourceSize.height)
                        // Highlight when this video is the one open in the sidebar.
                        Rectangle {
                            visible: sideBar.videoVisible && sideBar.videoModelData === modelData
                            anchors.centerIn: parent
                            width: root.imageHeights + 14
                            height: root.imageHeights + 14
                            radius: 8
                            color: "#3300e6e6"
                            border.color: "#00e6e6"
                            border.width: 2
                        }

                        Image {
                            id: videoImg
                            source: "qrc:/icons/video.svg"
                            //fillMode: Image.PreserveAspectFit
                            height: parent.height > 0 ? root.imageHeights : 0
                            width: height
                            smooth: true
                            antialiasing: true
                            anchors.centerIn: parent
                            //mipmap: true
                        }

                        MouseArea {
                            // Same as audio: grow the drag area to the visible icon
                            // so the whole icon is grabbable, not just a tiny center.
                            anchors.centerIn: parent
                            width: Math.max(parent.width, root.imageHeights + 14)
                            height: Math.max(parent.height, root.imageHeights + 14)
                            drag.target: parent
                            onPressed: {
                                sideBar.hideAllComponent();
                                sideBar.videoVisible = true;
                                sideBar.page = page;
                                sideBar.sectionIndex = index;
                                sideBar.videoModelData = modelData;
                            }
                            onReleased: {
                                var adjustedX = (videoRect.x - (flick.contentWidth / 2 - picture.paintedWidth / 2));
                                var adjustedY = (videoRect.y - (flick.contentHeight / 2 - picture.paintedHeight / 2));

                                // Zoom seviyesini ve PaintedWidth/PaintedHeight'i hesaba katarak orijinal koordinatları bul
                                var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                                var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                                modelData.coords = Qt.rect(originalX, originalY, modelData.coords.width, modelData.coords.height);
                                // config.bookSets[0].saveToJson();
                                //print("Changes Are Saved Page Detail vide On Released Triggered");
                            }
                        }
                    }
                    // fill
                    Repeater {
                        id: answersFillRepeater
                        model: modelData.answers
                        Item {
                            id: answerRect
                            property real originalWidth: modelData.coords.width
                            property real originalHeight: modelData.coords.height
                            property bool editing: false
                            x: (flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.coords.x * (picture.paintedWidth / picture.sourceSize.width)
                            y: (flick.contentHeight / 2 - picture.paintedHeight / 2) + modelData.coords.y * (picture.paintedHeight / picture.sourceSize.height)
                            width: originalWidth * (picture.paintedWidth / picture.sourceSize.width)
                            height: originalHeight * (picture.paintedHeight / picture.sourceSize.height)
                            visible: sectionType === "fill"

                            // Re-sync the live size when the model coords change
                            // (e.g. group resize), so this fill follows along even
                            // after its own resize broke the originalWidth binding.
                            Connections {
                                target: modelData
                                function onCoordsChanged() {
                                    answerRect.originalWidth = modelData.coords.width;
                                    answerRect.originalHeight = modelData.coords.height;
                                    answerRect.x = (flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.coords.x * (picture.paintedWidth / picture.sourceSize.width);
                                    answerRect.y = (flick.contentHeight / 2 - picture.paintedHeight / 2) + modelData.coords.y * (picture.paintedHeight / picture.sourceSize.height);
                                }
                            }

                            // Dragging breaks the x/y binding (drag.target sets them
                            // imperatively); re-derive position from coords on zoom so
                            // moved fills stay put when the image is rescaled.
                            Connections {
                                target: picture
                                function onPaintedWidthChanged() {
                                    answerRect.x = (flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.coords.x * (picture.paintedWidth / picture.sourceSize.width);
                                }
                                function onPaintedHeightChanged() {
                                    answerRect.y = (flick.contentHeight / 2 - picture.paintedHeight / 2) + modelData.coords.y * (picture.paintedHeight / picture.sourceSize.height);
                                }
                            }

                            Rectangle {
                                id: fillBg
                                property bool isSelected: (sideBar.fillVisible
                                                          && sideBar.section === sectionData
                                                          && sideBar.fillIndex === index)
                                                          || root.isFillSelected(modelData)

                                color: "#7bd5bd"
                                border.color: isSelected ? "#00e6e6" : "black"
                                border.width: isSelected ? 4 : 2
                                radius: 5
                                anchors.fill: parent
                                opacity: isSelected ? 0.65 : 0.4
                            }

                            // Bright outer ring so the selected fill clearly
                            // stands out from the others on the page.
                            Rectangle {
                                visible: fillBg.isSelected
                                anchors.fill: parent
                                anchors.margins: -4
                                color: "transparent"
                                border.color: "#00e6e6"
                                border.width: 2
                                radius: 9
                            }

                            FlowText {
                                id: answer
                                text: modelData.text
                                color: modelData.textColor === "" ? myColors.answerColor : modelData.textColor
                                rotation: modelData.rotation
                                height: parent.height
                                width: parent.width
                                font.bold: modelData.isTextBold
                                visible: !answerRect.editing
                            }

                            TextField {
                                id: inlineTextEditor
                                anchors.fill: parent
                                visible: answerRect.editing
                                enabled: answerRect.editing
                                text: modelData.text
                                color: modelData.textColor === "" ? myColors.answerColor : modelData.textColor
                                font.bold: modelData.isTextBold
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                background: Rectangle {
                                    color: "white"
                                    border.color: "#009ca6"
                                    border.width: 2
                                    radius: 4
                                    opacity: 0.85
                                }
                                onTextChanged: {
                                    if (answerRect.editing)
                                        modelData.text = text;
                                }
                                onAccepted: {
                                    answerRect.editing = false;
                                    inlineTextEditor.focus = false;
                                    mainMouseArea.forceActiveFocus();
                                }
                                onActiveFocusChanged: {
                                    if (!activeFocus && answerRect.editing) {
                                        answerRect.editing = false;
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                drag.target: parent
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                enabled: !answerRect.editing
                                onPressed: mouse => {
                                    // Ctrl+click toggles this fill in the page
                                    // multi-selection without opening the panel.
                                    if (mouse.modifiers & Qt.ControlModifier) {
                                        root.toggleFillSelection(modelData);
                                        root.openFillPanelForSelection();
                                        return;
                                    }
                                    // Keep the group when pressing an already-selected
                                    // fill (so a drag moves the whole selection).
                                    if (!root.isFillSelected(modelData))
                                        root.setSingleFillSelection(modelData);
                                    sideBar.hideAllComponent();
                                    sideBar.fillVisible = true;
                                    sideBar.page = page;
                                    sideBar.section = sectionData;
                                    sideBar.fillList = sectionItem.sectionAnswers;
                                    sideBar.fillIndex = index;
                                    sideBar.sectionIndex = sectionItem.sectionIndex;
                                    root.moveStartOX = modelData.coords.x;
                                    root.moveStartOY = modelData.coords.y;
                                    root.moveSnap = root.snapshotFillSelection();
                                }
                                onPositionChanged: mouse => {
                                    if (drag.active) {
                                        var sx = picture.paintedWidth / picture.sourceSize.width;
                                        var sy = picture.paintedHeight / picture.sourceSize.height;
                                        var curOX = (answerRect.x - (flick.contentWidth / 2 - picture.paintedWidth / 2)) / sx;
                                        var curOY = (answerRect.y - (flick.contentHeight / 2 - picture.paintedHeight / 2)) / sy;
                                        root.applyFillMove(root.moveSnap, modelData,
                                                           curOX - root.moveStartOX, curOY - root.moveStartOY);
                                    }
                                }
                                onReleased: root.setTotalStatus(answerRect, modelData)
                                onDoubleClicked: {
                                    answerRect.editing = true;
                                    Qt.callLater(function() {
                                        inlineTextEditor.forceActiveFocus();
                                        inlineTextEditor.selectAll();
                                    });
                                }
                                onClicked:
                                    // if (mouse.button === Qt.MiddleButton) {
                                    //     sectionItem.currentSection.removeAnswer(index);
                                    // }
                                {}
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
                                    onPositionChanged: {
                                        if (drag.active) {
                                            answerRect.originalWidth += mouseX / (picture.paintedWidth / picture.sourceSize.width);
                                            answerRect.originalHeight += mouseY / (picture.paintedHeight / picture.sourceSize.height);

                                            // Minimum boyutları kontrol et
                                            if (answerRect.originalWidth < 18 / (picture.paintedWidth / picture.sourceSize.width))
                                                answerRect.originalWidth = 18 / (picture.paintedWidth / picture.sourceSize.width);
                                            if (answerRect.originalHeight < 18 / (picture.paintedHeight / picture.sourceSize.height))
                                                answerRect.originalHeight = 18 / (picture.paintedHeight / picture.sourceSize.height);

                                            // Group resize, live: match every other
                                            // selected fill on each drag step.
                                            root.syncSizeLive(modelData, answerRect.originalWidth, answerRect.originalHeight);
                                        }
                                    }
                                    onReleased: {
                                        root.setTotalStatus(answerRect, modelData);
                                        root.syncSizeToSelection(modelData);
                                    }
                                }
                            }
                        }
                    }
                    // circle
                    Repeater {
                        id: answerCircleRepeater
                        model: modelData.answers

                        Item {
                            id: answerCircleRect
                            property real originalWidth: modelData.coords.width
                            property real originalHeight: modelData.coords.height
                            x: (flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.coords.x * (picture.paintedWidth / picture.sourceSize.width)
                            y: (flick.contentHeight / 2 - picture.paintedHeight / 2) + modelData.coords.y * (picture.paintedHeight / picture.sourceSize.height)
                            width: originalWidth * (picture.paintedWidth / picture.sourceSize.width)
                            height: originalHeight * (picture.paintedHeight / picture.sourceSize.height)
                            visible: sectionType === "circle" || sectionType === "circlewithextras"
                            Rectangle {
                                id: circleBorder
                                property bool isSelected: sideBar.circleVisible
                                                          && sideBar.section === sectionData
                                                          && sideBar.circleIndex === index
                                color: "transparent"
                                border.color: isSelected ? "#00e6e6" : "black"
                                border.width: isSelected ? 4 : 2
                                radius: 5
                                anchors.fill: parent
                            }

                            Rectangle {
                                visible: circleBorder.isSelected
                                anchors.fill: parent
                                anchors.margins: -4
                                color: "transparent"
                                border.color: "#00e6e6"
                                border.width: 2
                                radius: 9
                            }

                            MouseArea {
                                anchors.fill: parent
                                drag.target: parent
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                onPressed: {
                                    sideBar.hideAllComponent();
                                    sideBar.circleVisible = true;
                                    sideBar.page = page;
                                    sideBar.section = sectionData;
                                    sideBar.circleList = sectionItem.sectionAnswers;
                                    sideBar.circleIndex = index;
                                    sideBar.sectionIndex = sectionItem.sectionIndex;
                                }
                                onReleased: root.setTotalStatus(answerCircleRect, modelData)

                                onClicked:
                                    // if (mouse.button === Qt.MiddleButton) {
                                    //     sectionItem.currentSection.removeAnswer(index);
                                    // }
                                {}
                            }

                            Rectangle {
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
                                    onPositionChanged: {
                                        if (drag.active) {
                                            answerCircleRect.originalWidth += mouseX / (picture.paintedWidth / picture.sourceSize.width);
                                            answerCircleRect.originalHeight += mouseY / (picture.paintedHeight / picture.sourceSize.height);

                                            // Minimum boyutları kontrol et
                                            if (answerCircleRect.originalWidth < 18 / (picture.paintedWidth / picture.sourceSize.width))
                                                answerCircleRect.originalWidth = 18 / (picture.paintedWidth / picture.sourceSize.width);
                                            if (answerCircleRect.originalHeight < 18 / (picture.paintedHeight / picture.sourceSize.height))
                                                answerCircleRect.originalHeight = 18 / (picture.paintedHeight / picture.sourceSize.height);
                                        }
                                    }
                                    onReleased: root.setTotalStatus(answerCircleRect, modelData)
                                }
                            }
                        }
                    }
                    // fill with color
                    Repeater {
                        id: answersFillwithColorRepeater
                        model: modelData.answers
                        Item {
                            id: answerColorRect
                            property real originalWidth: modelData.coords.width
                            property real originalHeight: modelData.coords.height
                            x: (flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.coords.x * (picture.paintedWidth / picture.sourceSize.width)
                            y: (flick.contentHeight / 2 - picture.paintedHeight / 2) + modelData.coords.y * (picture.paintedHeight / picture.sourceSize.height)
                            width: originalWidth * (picture.paintedWidth / picture.sourceSize.width)
                            height: originalHeight * (picture.paintedHeight / picture.sourceSize.height)
                            visible: sectionType === "fillWithColor"

                            Rectangle {
                                id: answerColor
                                color: modelData.color !== "" ? modelData.color : myColors.darkBorderColor
                                rotation: modelData.rotation
                                height: parent.height
                                width: modelData.isRound ? height : parent.width
                                radius: modelData.isRound ? height / 2 : 2
                                opacity: modelData.opacity ? modelData.opacity : 0.5
                            }

                            // Highlight when this block is the open answer.
                            Rectangle {
                                visible: sideBar.fillwColorVisible
                                         && sideBar.section === sectionData
                                         && sideBar.fillIndex === index
                                anchors.fill: parent
                                anchors.margins: -3
                                color: "transparent"
                                border.color: "#00e6e6"
                                border.width: 3
                                radius: 6
                            }

                            MouseArea {
                                anchors.fill: parent
                                drag.target: parent
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                onPressed: {
                                    sideBar.hideAllComponent();
                                    sideBar.fillwColorVisible = true;
                                    sideBar.page = page;
                                    sideBar.section = sectionData;
                                    sideBar.fillWColorList = sectionItem.sectionAnswers;
                                    sideBar.fillIndex = index;
                                    sideBar.sectionIndex = sectionItem.sectionIndex;
                                }
                                onReleased: root.setTotalStatus(answerColorRect, modelData)
                                onClicked:
                                    // if (mouse.button === Qt.MiddleButton) {
                                    //     sectionItem.currentSection.removeAnswer(index);
                                    // }
                                {}
                            }

                            Rectangle {
                                id: zoomPointFillColor
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
                                    onPositionChanged: {
                                        if (drag.active) {
                                            answerColorRect.originalWidth += mouseX / (picture.paintedWidth / picture.sourceSize.width);
                                            answerColorRect.originalHeight += mouseY / (picture.paintedHeight / picture.sourceSize.height);

                                            // Minimum boyutları kontrol et
                                            if (answerColorRect.originalWidth < 18 / (picture.paintedWidth / picture.sourceSize.width))
                                                answerColorRect.originalWidth = 18 / (picture.paintedWidth / picture.sourceSize.width);
                                            if (answerColorRect.originalHeight < 18 / (picture.paintedHeight / picture.sourceSize.height))
                                                answerColorRect.originalHeight = 18 / (picture.paintedHeight / picture.sourceSize.height);
                                        }
                                    }
                                    onReleased: root.setTotalStatus(answerColorRect, modelData)
                                }
                            }
                        }
                    }

                    // Draw Matched Line
                    Repeater {
                        id: answersDrawMatchedLine
                        model: modelData.answers
                        Item {
                            id: drawMatchedLine
                            property point startPoint: Qt.point((flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.lineBegin.x * (picture.paintedWidth / picture.sourceSize.width), (flick.contentHeight / 2 - picture.paintedHeight / 2) + modelData.lineBegin.y * (picture.paintedHeight / picture.sourceSize.height))
                            property point endPoint: Qt.point((flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.lineEnd.x * (picture.paintedWidth / picture.sourceSize.width), (flick.contentHeight / 2 - picture.paintedHeight / 2) + modelData.lineEnd.y * (picture.paintedHeight / picture.sourceSize.height))
                            // x: (flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.coords.x * (picture.paintedWidth / picture.sourceSize.width)
                            // y: (flick.contentHeight / 2 - picture.paintedHeight / 2) + modelData.coords.y * (picture.paintedHeight / picture.sourceSize.height)
                            // width: modelData.coords.width * (picture.paintedWidth / picture.sourceSize.width)
                            // height: modelData.coords.height * (picture.paintedHeight / picture.sourceSize.height)
                            visible: sectionType === "drawMatchedLine"

                            Item {
                                id: beginRectItem
                                property real originalWidth: modelData.rectBegin.width
                                property real originalHeight: modelData.rectBegin.height
                                x: (flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.rectBegin.x * (picture.paintedWidth / picture.sourceSize.width)
                                y: (flick.contentHeight / 2 - picture.paintedHeight / 2) + modelData.rectBegin.y * (picture.paintedHeight / picture.sourceSize.height)
                                width: originalWidth * (picture.paintedWidth / picture.sourceSize.width)
                                height: originalHeight * (picture.paintedHeight / picture.sourceSize.height)

                                Rectangle {
                                    id: beginRect
                                    color: modelData.color !== "" ? modelData.color : myColors.darkBorderColor
                                    visible: true
                                    rotation: modelData.rotation
                                    height: beginRectItem.originalHeight * (picture.paintedHeight / picture.sourceSize.height)
                                    width: modelData.isRound ? height : beginRectItem.originalWidth * (picture.paintedWidth / picture.sourceSize.width)
                                    radius: modelData.isRound ? height / 2 : 2
                                    opacity: modelData.opacity ? modelData.opacity : 0.5
                                }

                                Rectangle {
                                    visible: sideBar.drawMatchedVisible
                                             && sideBar.section === sectionData
                                             && sideBar.fillIndex === index
                                    anchors.fill: parent
                                    anchors.margins: -3
                                    color: "transparent"
                                    border.color: "#00e6e6"
                                    border.width: 3
                                    radius: 6
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    drag.target: parent
                                    onPressed: {
                                        sideBar.hideAllComponent();
                                        sideBar.drawMatchedVisible = true;
                                        sideBar.page = page;
                                        sideBar.section = sectionData;
                                        sideBar.drawMatchedLineList = sectionItem.sectionAnswers;
                                        sideBar.fillIndex = index;
                                        sideBar.sectionIndex = sectionItem.sectionIndex;
                                    }
                                    onReleased: {
                                        var adjustedX = (beginRectItem.x - (flick.contentWidth / 2 - picture.paintedWidth / 2));
                                        var adjustedY = (beginRectItem.y - (flick.contentHeight / 2 - picture.paintedHeight / 2));
                                        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                                        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                                        var adjustedW = beginRectItem.width * (picture.sourceSize.width / picture.paintedWidth);
                                        var adjustedH = beginRectItem.height * (picture.sourceSize.height / picture.paintedHeight);
                                        modelData.rectBegin = Qt.rect(originalX, originalY, adjustedW, adjustedH);
                                        root.lastSize.width = adjustedW;
                                        root.lastSize.height = adjustedH;
                                        // config.bookSets[0].saveToJson();
                                        print("Changes Are Saved Page Detail set status");
                                    }
                                }
                                Rectangle {
                                    id: zoomPointRectBegin
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
                                        onPositionChanged: {
                                            if (drag.active) {
                                                beginRectItem.originalWidth += mouseX / (picture.paintedWidth / picture.sourceSize.width);
                                                beginRectItem.originalHeight += mouseY / (picture.paintedHeight / picture.sourceSize.height);

                                                // Minimum boyutları kontrol et
                                                if (beginRectItem.originalWidth < 18 / (picture.paintedWidth / picture.sourceSize.width))
                                                    beginRectItem.originalWidth = 18 / (picture.paintedWidth / picture.sourceSize.width);
                                                if (beginRectItem.originalHeight < 18 / (picture.paintedHeight / picture.sourceSize.height))
                                                    beginRectItem.originalHeight = 18 / (picture.paintedHeight / picture.sourceSize.height);
                                            }
                                        }
                                        onReleased: {
                                            var adjustedX = (beginRectItem.x - (flick.contentWidth / 2 - picture.paintedWidth / 2));
                                            var adjustedY = (beginRectItem.y - (flick.contentHeight / 2 - picture.paintedHeight / 2));
                                            var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                                            var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                                            var adjustedW = beginRectItem.width * (picture.sourceSize.width / picture.paintedWidth);
                                            var adjustedH = beginRectItem.height * (picture.sourceSize.height / picture.paintedHeight);
                                            modelData.rectBegin = Qt.rect(originalX, originalY, adjustedW, adjustedH);
                                            root.lastSize.width = adjustedW;
                                            root.lastSize.height = adjustedH;
                                            // config.bookSets[0].saveToJson();
                                            print("Changes Are Saved Page Detail set status");
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: beginPoint
                                color: "blue"
                                width: 10
                                height: 10
                                border.color: "black"
                                border.width: 1
                                x: drawMatchedLine.startPoint.x
                                y: drawMatchedLine.startPoint.y

                                MouseArea {
                                    anchors.fill: parent
                                    drag {
                                        target: parent
                                        axis: Drag.XAndYAxis
                                    }
                                    onPressed: {
                                        sideBar.hideAllComponent();
                                        sideBar.drawMatchedVisible = true;
                                        sideBar.page = page;
                                        sideBar.section = sectionData;
                                        sideBar.drawMatchedLineList = sectionItem.sectionAnswers;
                                        sideBar.fillIndex = index;
                                        sideBar.sectionIndex = sectionItem.sectionIndex;
                                    }

                                    onPositionChanged: {
                                        var adjustedX = (beginPoint.x - (flick.contentWidth / 2 - picture.paintedWidth / 2));
                                        var adjustedY = (beginPoint.y - (flick.contentHeight / 2 - picture.paintedHeight / 2));
                                        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                                        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                                        modelData.lineBegin = Qt.point(originalX, originalY);
                                        // config.bookSets[0].saveToJson();
                                        print("Changes Are Saved Page Detail set status");
                                    }
                                }
                            }

                            Rectangle {
                                id: endPoint
                                color: "red"
                                width: 10
                                height: 10
                                border.color: "black"
                                border.width: 1
                                x: drawMatchedLine.endPoint.x
                                y: drawMatchedLine.endPoint.y

                                MouseArea {
                                    anchors.fill: parent
                                    drag {
                                        target: parent
                                        axis: Drag.XAndYAxis
                                    }
                                    onPressed: {
                                        sideBar.hideAllComponent();
                                        sideBar.drawMatchedVisible = true;
                                        sideBar.page = page;
                                        sideBar.section = sectionData;
                                        sideBar.drawMatchedLineList = sectionItem.sectionAnswers;
                                        sideBar.fillIndex = index;
                                        sideBar.sectionIndex = sectionItem.sectionIndex;
                                    }

                                    onPositionChanged: {
                                        var adjustedX = (endPoint.x - (flick.contentWidth / 2 - picture.paintedWidth / 2));
                                        var adjustedY = (endPoint.y - (flick.contentHeight / 2 - picture.paintedHeight / 2));
                                        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                                        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                                        modelData.lineEnd = Qt.point(originalX, originalY);
                                        // config.bookSets[0].saveToJson();
                                        print("Changes Are Saved Page Detail set status");
                                    }
                                }
                            }

                            Shape {
                                id: lineShape

                                property int lineWidth: 2
                                property bool isDashed: false
                                antialiasing: true

                                ShapePath {
                                    strokeWidth: lineShape.lineWidth
                                    strokeColor: myColors.answerColor
                                    fillColor: "purple"
                                    strokeStyle: lineShape.isDashed ? ShapePath.DashLine : ShapePath.SolidLine

                                    startX: drawMatchedLine.startPoint.x
                                    startY: drawMatchedLine.startPoint.y

                                    PathLine {
                                        x: drawMatchedLine.startPoint.x + (drawMatchedLine.endPoint.x - drawMatchedLine.startPoint.x)
                                        y: drawMatchedLine.startPoint.y + (drawMatchedLine.endPoint.y - drawMatchedLine.startPoint.y)
                                    }
                                }
                            }

                            Item {
                                id: endRectItem
                                property real originalWidth: modelData.rectEnd.width
                                property real originalHeight: modelData.rectEnd.height
                                x: (flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.rectEnd.x * (picture.paintedWidth / picture.sourceSize.width)
                                y: (flick.contentHeight / 2 - picture.paintedHeight / 2) + modelData.rectEnd.y * (picture.paintedHeight / picture.sourceSize.height)
                                width: originalWidth * (picture.paintedWidth / picture.sourceSize.width)
                                height: originalHeight * (picture.paintedHeight / picture.sourceSize.height)

                                Rectangle {
                                    id: endRect

                                    color: modelData.color !== "" ? modelData.color : myColors.darkBorderColor
                                    visible: true
                                    rotation: modelData.rotation
                                    height: endRectItem.originalHeight * (picture.paintedHeight / picture.sourceSize.height)
                                    width: modelData.isRound ? height : endRectItem.originalWidth * (picture.paintedWidth / picture.sourceSize.width)
                                    radius: modelData.isRound ? height / 2 : 2
                                    opacity: modelData.opacity ? modelData.opacity : 0.5
                                }

                                Rectangle {
                                    visible: sideBar.drawMatchedVisible
                                             && sideBar.section === sectionData
                                             && sideBar.fillIndex === index
                                    anchors.fill: parent
                                    anchors.margins: -3
                                    color: "transparent"
                                    border.color: "#00e6e6"
                                    border.width: 3
                                    radius: 6
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    drag.target: parent
                                    onPressed: {
                                        sideBar.hideAllComponent();
                                        sideBar.drawMatchedVisible = true;
                                        sideBar.page = page;
                                        sideBar.section = sectionData;
                                        sideBar.drawMatchedLineList = sectionItem.sectionAnswers;
                                        sideBar.fillIndex = index;
                                        sideBar.sectionIndex = sectionItem.sectionIndex;
                                    }

                                    onReleased: {
                                        var adjustedX = (endRectItem.x - (flick.contentWidth / 2 - picture.paintedWidth / 2));
                                        var adjustedY = (endRectItem.y - (flick.contentHeight / 2 - picture.paintedHeight / 2));
                                        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                                        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                                        var adjustedW = endRectItem.width * (picture.sourceSize.width / picture.paintedWidth);
                                        var adjustedH = endRectItem.height * (picture.sourceSize.height / picture.paintedHeight);
                                        modelData.rectEnd = Qt.rect(originalX, originalY, adjustedW, adjustedH);
                                        root.lastSize.width = adjustedW;
                                        root.lastSize.height = adjustedH;
                                        // config.bookSets[0].saveToJson();
                                        print("Changes Are Saved Page Detail set status");
                                    }
                                }

                                Rectangle {
                                    id: zoomPointRectEnd
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
                                        onPositionChanged: {
                                            if (drag.active) {
                                                endRectItem.originalWidth += mouseX / (picture.paintedWidth / picture.sourceSize.width);
                                                endRectItem.originalHeight += mouseY / (picture.paintedHeight / picture.sourceSize.height);

                                                // Minimum boyutları kontrol et
                                                if (endRectItem.originalWidth < 18 / (picture.paintedWidth / picture.sourceSize.width))
                                                    endRectItem.originalWidth = 18 / (picture.paintedWidth / picture.sourceSize.width);
                                                if (endRectItem.originalHeight < 18 / (picture.paintedHeight / picture.sourceSize.height))
                                                    endRectItem.originalHeight = 18 / (picture.paintedHeight / picture.sourceSize.height);
                                            }
                                        }
                                        onReleased: {
                                            var adjustedX = (endRectItem.x - (flick.contentWidth / 2 - picture.paintedWidth / 2));
                                            var adjustedY = (endRectItem.y - (flick.contentHeight / 2 - picture.paintedHeight / 2));
                                            var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                                            var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                                            var adjustedW = endRectItem.width * (picture.sourceSize.width / picture.paintedWidth);
                                            var adjustedH = endRectItem.height * (picture.sourceSize.height / picture.paintedHeight);
                                            modelData.rectEnd = Qt.rect(originalX, originalY, adjustedW, adjustedH);
                                            root.lastSize.width = adjustedW;
                                            root.lastSize.height = adjustedH;
                                            // config.bookSets[0].saveToJson();
                                            print("Changes Are Saved Page Detail set status");
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // activity
                    Rectangle {
                        id: activityRect
                        color: "transparent"
                        x: (flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.activity.coords.x * (picture.paintedWidth / picture.sourceSize.width)
                        y: (flick.contentHeight / 2 - picture.paintedHeight / 2) + modelData.activity.coords.y * (picture.paintedHeight / picture.sourceSize.height)
                        width: modelData.activity.coords.width * (picture.paintedWidth / picture.sourceSize.width)
                        height: modelData.activity.coords.height * (picture.paintedHeight / picture.sourceSize.height)
                        visible: modelData.activity.type !== ""
                        // Highlight when this activity is the one open in the sidebar.
                        Rectangle {
                            visible: sideBar.activityVisible && sideBar.activityModelData === modelData.activity
                            anchors.centerIn: parent
                            width: root.imageHeights + 14
                            height: root.imageHeights + 14
                            radius: 8
                            color: "#3300e6e6"
                            border.color: "#00e6e6"
                            border.width: 2
                        }

                        Image {
                            id: activityImg
                            // fillpicture activities show the magnifier icon; all
                            // other activity types use the generic activity icon.
                            source: modelData.activity.type === "fillpicture"
                                    ? "qrc:/icons/magnifier.svg" : "qrc:/icons/activity.svg"
                            height: parent.height > 0 ? root.imageHeights : 0
                            width: height
                            smooth: true
                            antialiasing: true
                            anchors.centerIn: parent
                        }
                        MouseArea {
                            anchors.fill: parent
                            drag.target: parent
                            onPressed: {
                                sideBar.hideAllComponent();
                                sideBar.activityVisible = true;
                                sideBar.page = page;
                                sideBar.sectionIndex = index;
                                sideBar.activityModelData = modelData.activity;
                                sideBar.sectionModelData = modelData;
                                // Move focus off any sidebar text field so the
                                // c/h shortcuts fire on this just-clicked activity.
                                root.clearTextFocus();
                            }

                            onReleased: {
                                var adjustedX = (activityRect.x - (flick.contentWidth / 2 - picture.paintedWidth / 2));
                                var adjustedY = (activityRect.y - (flick.contentHeight / 2 - picture.paintedHeight / 2));

                                // Zoom seviyesini ve PaintedWidth/PaintedHeight'i hesaba katarak orijinal koordinatları bul
                                var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                                var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                                modelData.activity.coords = Qt.rect(originalX, originalY, modelData.activity.coords.width, modelData.activity.coords.height);
                                // config.bookSets[0].saveToJson();
                                print("Changes Are Saved Page Detail set activity");
                            }
                        }
                    }
                }
            }
        }
    }

    // Crop mode: overlay MouseArea on top of everything (z: 100)
    MouseArea {
        id: cropMouseArea
        anchors.fill: parent
        visible: root.cropMode
        enabled: root.cropMode
        z: 100
        cursorShape: Qt.CrossCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onPressed: mouse => {
                       if (mouse.button === Qt.LeftButton) {
                           root.cropStartX = mouse.x;
                           root.cropStartY = mouse.y;
                           root.cropEndX = mouse.x;
                           root.cropEndY = mouse.y;
                           root.cropDrawing = true;
                       } else if (mouse.button === Qt.RightButton) {
                           root.endCropMode();
                       }
                   }

        onPositionChanged: mouse => {
                               if (root.cropDrawing) {
                                   root.cropEndX = mouse.x;
                                   root.cropEndY = mouse.y;
                               }
                           }

        onReleased: mouse => {
                        if (mouse.button === Qt.LeftButton && root.cropDrawing) {
                            root.cropDrawing = false;
                            root.executeCrop();
                        }
                    }
    }

    // Crop selection rectangle overlay (on top of cropMouseArea)
    Rectangle {
        id: cropRect
        visible: root.cropMode && root.cropDrawing
        z: 101
        color: "#300078D4"
        border.color: "#0078D4"
        border.width: 2
        x: Math.min(root.cropStartX, root.cropEndX)
        y: Math.min(root.cropStartY, root.cropEndY)
        width: Math.abs(root.cropEndX - root.cropStartX)
        height: Math.abs(root.cropEndY - root.cropStartY)
    }

    // Crop mode indicator label
    Rectangle {
        visible: root.cropMode
        z: 102
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 10
        width: cropLabel.width + 20
        height: 30
        color: "#E00078D4"
        radius: 4

        Text {
            id: cropLabel
            anchors.centerIn: parent
            text: "CROP MODE - Draw selection, Right-click or Esc to cancel"
            color: "white"
            font.pixelSize: 12
        }
    }

    function setDefaultZoom() {
        // İçeriği orijinal boyutuna (1x zoom) döndür
        flick.resizeContent(flick.width, flick.height, Qt.point(flick.width / 2, flick.height / 2));
        flick.returnToBounds();

        // İçeriği merkeze al
        flick.contentX = 0;
        flick.contentY = 0;
    }

    function enableRightClick(enabled) {
        mainMouseArea.enabled = enabled;
    }

    function setTotalStatus(rect, modelData) {
        var adjustedX = (rect.x - (flick.contentWidth / 2 - picture.paintedWidth / 2));
        var adjustedY = (rect.y - (flick.contentHeight / 2 - picture.paintedHeight / 2));
        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

        var adjustedW = rect.width * (picture.sourceSize.width / picture.paintedWidth);
        var adjustedH = rect.height * (picture.sourceSize.height / picture.paintedHeight);

        modelData.coords = Qt.rect(originalX, originalY, adjustedW, adjustedH);
        root.lastSize.width = adjustedW;
        root.lastSize.height = adjustedH;

        // config.bookSets[0].saveToJson();
        print("Changes Are Saved Page Detail set status");
    }

    function startCropMode(targetObj, pathProperty) {
        root.cropMode = true;
        root.cropRedetect = false;
        root.cropActivity = targetObj;
        root.cropActivityRef = targetObj;
        root.cropPathProperty = pathProperty || "sectionPath";
        root.cropNewSectionPath = "";
        root.cropPngRect = null;
        root.cropHeaderPick = false;
        root.cropDrawing = false;
        mainMouseArea.cursorShape = Qt.CrossCursor;
        var currentPath = targetObj[root.cropPathProperty] || "";
        print("Crop mode started for property: " + root.cropPathProperty + " = " + currentPath);
    }

    // Crop mode that re-runs circle option detection inside the drawn
    // rect and replaces the activity's answers with the result.
    function startRedetectMode(targetObj) {
        startCropMode(targetObj, "sectionPath");
        root.cropRedetect = true;
        print("Redetect mode started");
    }

    // Crop mode that re-checks the fill sizes inside the drawn rect against
    // the answered PDF: every fill whose center falls in the rect is deleted
    // and replaced with freshly diff-detected ones (text + box re-derived).
    function startFillRedetectMode() {
        if (!sideBar.fillVisible || !sideBar.section)
            return;
        startCropMode(sideBar.section, "sectionPath");
        root.cropFillRedetect = true;
        root.cropFillSectionRef = sideBar.section;
        print("Fill re-check mode started");
    }

    // The drawn rect only PICKS the headerText (no crop, no answers):
    // the instruction line's text is read from the original PDF.
    function startHeaderPickMode(targetObj) {
        startCropMode(targetObj, "sectionPath");
        root.cropHeaderPick = true;
        print("Header pick mode started");
    }

    // The drawn rect is cropped to a small template PNG used by the
    // audio/video icon matcher (Find Audio/Video Icons). No activity,
    // no section update — just an example icon for proto_icon_match.py.
    function startIconCrop(kind) {
        // Set crop state directly — startCropMode() dereferences its
        // targetObj, but an icon crop has no target activity.
        root.cropMode = true;
        root.cropRedetect = false;
        root.cropActivity = null;
        root.cropActivityRef = null;
        root.cropHeaderPick = false;
        root.cropNewSectionPath = "";
        root.cropPngRect = null;
        root.cropIconKind = kind;          // "audio" or "video"
        root.cropDrawing = false;
        mainMouseArea.cursorShape = Qt.CrossCursor;
        print("Icon template crop mode started: " + kind);
    }

    // Audio section is selected: pressing "c" picks the passage to karaoke-align.
    function startPassageCropMode(audioObj) {
        if (!audioObj)
            return;
        root.cropMode = true;
        root.cropRedetect = false;
        root.cropHeaderPick = false;
        root.cropFillRedetect = false;
        root.cropIconKind = "";
        root.cropActivity = null;
        root.cropActivityRef = null;
        root.cropNewSectionPath = "";
        root.cropPngRect = null;
        root.cropPassage = true;
        root.cropPassageAudioRef = audioObj;   // survives endCropMode for the result
        root.cropDrawing = false;
        mainMouseArea.cursorShape = Qt.CrossCursor;
        print("Passage crop mode started for audio: " + (audioObj.audioPath || ""));
    }

    function endCropMode() {
        root.cropMode = false;
        root.cropRedetect = false;
        root.cropHeaderPick = false;
        root.cropFillRedetect = false;   // cropFillSectionRef/Band survive for the result
        root.cropIconKind = "";
        root.cropPassage = false;        // cropPassageAudioRef survives for the result
        root.cropActivity = null;
        root.cropDrawing = false;
        mainMouseArea.cursorShape = Qt.ArrowCursor;
        print("Crop mode ended");
    }

    function executeCrop() {
        // Convert display coordinates to original PNG pixel coordinates
        var selX = Math.min(root.cropStartX, root.cropEndX);
        var selY = Math.min(root.cropStartY, root.cropEndY);
        var selW = Math.abs(root.cropEndX - root.cropStartX);
        var selH = Math.abs(root.cropEndY - root.cropStartY);

        // Minimum selection check
        if (selW < 10 || selH < 10) {
            print("Crop selection too small, ignoring");
            endCropMode();
            return;
        }

        // Display (viewport) coords -> content coords -> original PNG pixel coords
        // mouse.x/y is in viewport space, add flick scroll offset to get content coords
        var contentX = selX + flick.contentX;
        var contentY = selY + flick.contentY;

        // Subtract image centering offset within the content area
        var adjustedX = contentX - (flick.contentWidth / 2 - picture.paintedWidth / 2);
        var adjustedY = contentY - (flick.contentHeight / 2 - picture.paintedHeight / 2);

        // Scale from painted size to original source size
        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);
        var originalW = selW * (picture.sourceSize.width / picture.paintedWidth);
        var originalH = selH * (picture.sourceSize.height / picture.paintedHeight);

        // Clamp to image bounds
        originalX = Math.max(0, originalX);
        originalY = Math.max(0, originalY);
        if (originalX + originalW > picture.sourceSize.width)
            originalW = picture.sourceSize.width - originalX;
        if (originalY + originalH > picture.sourceSize.height)
            originalH = picture.sourceSize.height - originalY;

        // Determine raw directory path from page image_path
        var imagePath = page.image_path.replace(/\\/g, "/");
        var bookDir = imagePath.substring(0, imagePath.indexOf("/images/"));
        var pdfPath = appPath + bookDir.substring(2) + "/raw";

        // Page index (0-based)
        var pageIndex = page.page_number - 1;

        // Fill re-check: re-run fill detection in the rect against the
        // answered PDF (no crop image; coords come back in page-PNG px).
        if (root.cropFillRedetect) {
            root.cropFillBand = { x: originalX, y: originalY, w: originalW, h: originalH };
            pdfProcess.redetectCircleOptions(
                pdfPath, page.page_number,
                originalX, originalY, originalW, originalH,
                picture.sourceSize.width, picture.sourceSize.height,
                "", "fill"
            );
            endCropMode();
            return;
        }

        // Header pick: the rect only selects the instruction text.
        if (root.cropHeaderPick) {
            pdfProcess.detectHeaderText(
                pdfPath, page.page_number,
                originalX, originalY, originalW, originalH,
                picture.sourceSize.width, picture.sourceSize.height
            );
            endCropMode();
            return;
        }

        // Icon template pick: crop the rect to a template PNG for the
        // audio/video icon matcher. No activity / section involved; the
        // pdfProcess.cropCompleted signal carries the path to the toolbar.
        if (root.cropIconKind !== "") {
            var iconOut = appPath + bookDir.substring(2)
                          + "/icon_template_" + root.cropIconKind + ".png";
            pdfProcess.cropSectionFromPdf(
                pdfPath, pageIndex,
                originalX, originalY, originalW, originalH,
                picture.sourceSize.width, picture.sourceSize.height,
                iconOut
            );
            endCropMode();
            return;
        }

        // Passage crop: forced-align the selected audio to the text under the
        // rect and write word-level karaoke timing into audio/audio.json. No
        // crop image; result comes back via pdfProcess.passageCropCompleted.
        if (root.cropPassage) {
            var bookAbs = appPath + bookDir.substring(2);
            var aRel = root.cropPassageAudioRef
                       ? String(root.cropPassageAudioRef.audioPath || "") : "";
            if (aRel === "") {
                print("Passage crop: audio section has no audio path");
                endCropMode();
                return;
            }
            var audioAbs = appPath + aRel.substring(2);          // "./books/.../x.mp3"
            var audioJson = bookAbs + "/audio/audio.json";
            pdfProcess.cropPassageAudio(
                pdfPath, pageIndex,
                originalX, originalY, originalW, originalH,
                picture.sourceSize.width, picture.sourceSize.height,
                audioAbs, audioJson, "en"
            );
            endCropMode();
            return;
        }

        // Output path: generate unique name to bust QML image cache
        var currentPath = root.cropActivity[root.cropPathProperty] || "";
        var sectionDir;
        if (currentPath !== "" && currentPath.indexOf("/") !== -1) {
            sectionDir = currentPath.substring(0, currentPath.lastIndexOf("/") + 1);
        } else {
            // Fallback: use page image directory
            var imgPath = page.image_path.replace(/\\/g, "/");
            sectionDir = imgPath.substring(0, imgPath.lastIndexOf("/") + 1);
        }
        var timestamp = Date.now();
        var newFileName = "p" + page.page_number + "_crop_" + timestamp + ".png";
        var newSectionPath = sectionDir + newFileName;
        var outputPath = appPath + newSectionPath.substring(2);

        // Store new path for onCropCompleted to update sectionPath
        root.cropNewSectionPath = newSectionPath;
        // Store the crop rect (page-PNG px) so dragdrop zones can be
        // re-derived from the page fills after the crop is saved.
        root.cropPngRect = { x: originalX, y: originalY, w: originalW, h: originalH };
        // Persist the same rect on the activity (image_coords) so the reader can
        // map page-pixel karaoke word bboxes into the cropped activity image.
        // Covers both the normal crop and the circle/markwithx redetect path
        // (both reach here). Only activity-image crops carry an imageCoords prop.
        if (root.cropActivity && root.cropPathProperty === "sectionPath"
                && typeof root.cropActivity.imageCoords !== "undefined") {
            root.cropActivity.imageCoords = Qt.rect(originalX, originalY, originalW, originalH);
        }

        print("Crop: PDF=" + pdfPath + " page=" + pageIndex);
        print("Crop: PNG coords x=" + originalX + " y=" + originalY + " w=" + originalW + " h=" + originalH);
        print("Crop: PNG size=" + picture.sourceSize.width + "x" + picture.sourceSize.height);
        print("Crop: Output=" + outputPath);

        // Circle, markwithx and matchTheWords crops always re-detect:
        // the activity type is known, so find the options / marks /
        // word-item pairs under the drawn area too.
        var cropActType = root.cropActivity ? String(root.cropActivity.type || "") : "";
        if (!root.cropRedetect
                && (cropActType === "circle" || cropActType === "markwithx"
                    || cropActType === "matchTheWords")) {
            root.cropRedetect = true;
            print(cropActType + " crop auto-upgraded to re-detect");
        }

        if (root.cropRedetect) {
            var kind = "circle";
            if (cropActType === "markwithx")
                kind = "markwithx";
            else if (cropActType === "matchTheWords")
                kind = "match";
            // pdfPath is the book's raw/ dir; the script resolves the pair.
            pdfProcess.redetectCircleOptions(
                pdfPath, page.page_number,
                originalX, originalY, originalW, originalH,
                picture.sourceSize.width, picture.sourceSize.height,
                outputPath, kind
            );
            endCropMode();
            return;
        }

        pdfProcess.cropSectionFromPdf(
            pdfPath, pageIndex,
            originalX, originalY, originalW, originalH,
            picture.sourceSize.width, picture.sourceSize.height,
            outputPath
        );

        endCropMode();
    }

    // Reads the freshly saved crop to learn its pixel size, then
    // derives the dragdrop zones from the page fills (fills = master).
    Image {
        id: zoneSyncImage
        visible: false
        asynchronous: true
        onStatusChanged: {
            if (status === Image.Ready)
                root.syncDragdropZones();
        }
    }

    // Fills are the single source of truth: every fill whose center
    // lies inside the freshly drawn crop becomes a drop zone in the
    // crop's own pixel space; the fill texts become the word pool.
    function syncDragdropZones() {
        var act = root.cropActivityRef;
        var r = root.cropPngRect;
        if (!act || !r || r.w <= 0 || r.h <= 0)
            return;
        var imgW = zoneSyncImage.sourceSize.width;
        var imgH = zoneSyncImage.sourceSize.height;
        if (imgW <= 0 || imgH <= 0)
            return;
        var sx = imgW / r.w;
        var sy = imgH / r.h;

        var zones = [];
        var secs = page.sections;
        for (var i = 0; i < secs.length; i++) {
            if (secs[i].type !== "fill")
                continue;
            var answers = secs[i].answers;
            for (var j = 0; j < answers.length; j++) {
                var c = answers[j].coords;
                var cx = c.x + c.width / 2;
                var cy = c.y + c.height / 2;
                if (cx < r.x || cx > r.x + r.w || cy < r.y || cy > r.y + r.h)
                    continue;
                zones.push({
                    x: Math.round((c.x - r.x) * sx),
                    y: Math.round((c.y - r.y) * sy),
                    w: Math.round(c.width * sx),
                    h: Math.round(c.height * sy),
                    text: answers[j].text || ""
                });
            }
        }
        if (zones.length === 0) {
            print("Zone sync: no fills inside the crop, answers kept");
            return;
        }
        zones.sort(function(a, b) { return (a.y - b.y) || (a.x - b.x); });

        // Word pool = the fill texts under the crop, reading order.
        var words = [];
        for (var k = 0; k < zones.length; k++)
            if (zones[k].text !== "" && words.indexOf(zones[k].text) === -1)
                words.push(zones[k].text);

        // Group variant: zones stacking into one column share a group
        // (any word of that column is a valid drop).
        if (act.type === "dragdroppicturegroup") {
            var cols = [];
            var byX = zones.slice().sort(function(a, b) { return a.x - b.x; });
            for (var m = 0; m < byX.length; m++) {
                var z = byX[m];
                var host = null;
                for (var n = 0; n < cols.length; n++) {
                    var ov = Math.min(z.x + z.w, cols[n].x1) - Math.max(z.x, cols[n].x0);
                    if (ov > 0.5 * Math.min(z.w, cols[n].x1 - cols[n].x0)) {
                        host = cols[n];
                        break;
                    }
                }
                if (host) {
                    host.zones.push(z);
                    host.x0 = Math.min(host.x0, z.x);
                    host.x1 = Math.max(host.x1, z.x + z.w);
                } else {
                    cols.push({ x0: z.x, x1: z.x + z.w, zones: [z] });
                }
            }
            for (n = 0; n < cols.length; n++) {
                var colTexts = cols[n].zones.map(function(q) { return q.text; });
                for (m = 0; m < cols[n].zones.length; m++)
                    cols[n].zones[m].group = colTexts;
            }
        }

        while (act.answers.length > 0)
            act.removeAnswer(0);
        for (k = 0; k < zones.length; k++) {
            var zz = zones[k];
            act.createNewAnswer(zz.x, zz.y, zz.w, zz.h,
                                act.type === "dragdroppicturegroup" ? "" : zz.text);
            if (zz.group)
                act.answers[act.answers.length - 1].group = zz.group;
        }
        if (act.type !== "fillpicture") {
            // fillpicture has no word pool — the student types.
            act.words = words;
        }
        print("Zone sync: " + zones.length + " zones derived from page fills"
              + (act.type === "fillpicture" ? "" : ", " + words.length + " words"));
    }

    Connections {
        target: pdfProcess
        function onCropCompleted(success, outputPath) {
            if (success) {
                print("Crop saved successfully: " + outputPath);
                // Update target property to new file (unique name busts QML image cache)
                if (root.cropActivityRef && root.cropNewSectionPath !== "") {
                    root.cropActivityRef[root.cropPathProperty] = root.cropNewSectionPath;
                    print(root.cropPathProperty + " updated to: " + root.cropNewSectionPath);
                    // Dragdrop/fillpicture crops: re-derive zones from
                    // the fills under the crop once the image size is
                    // known (fillpicture = same sync, no word pool).
                    var t = String(root.cropActivityRef.type || "");
                    if ((t.indexOf("dragdroppicture") === 0 || t === "fillpicture")
                            && root.cropPngRect) {
                        zoneSyncImage.source = "";
                        zoneSyncImage.source = "file:" + outputPath;
                    }
                }
            } else {
                print("Crop failed for: " + outputPath);
            }
        }

        // Passage karaoke alignment finished: flag the audio section so the
        // reader loads audio.json. The AudioGroupBox shows the busy/result
        // status off the same signal.
        function onPassageCropCompleted(success, audioPath, summaryJson) {
            if (success && root.cropPassageAudioRef) {
                root.cropPassageAudioRef.karaoke = true;
                print("Karaoke attached to " + audioPath + ": " + summaryJson);
            } else if (!success) {
                print("Karaoke alignment failed for: " + audioPath);
            }
            root.cropPassageAudioRef = null;
        }

        function onHeaderTextDetected(success, text) {
            if (!success || !root.cropActivityRef) {
                print("Header pick failed or no target");
                return;
            }
            if (text === "") {
                print("Header pick: no text found in rect");
                return;
            }
            root.cropActivityRef.headerText = text;
            print("Header set: " + text);
        }

        function onCircleRedetectCompleted(success, resultJson, outputPath) {
            if (!success) {
                print("Circle redetect failed for: " + outputPath);
                return;
            }
            var act = root.cropActivityRef;
            if (!act) {
                print("Redetect: no target activity");
                return;
            }
            var res = JSON.parse(resultJson);

            // Fill re-check: replace the fills inside the drawn band with the
            // freshly detected ones. Targets the fill section, not an activity.
            if (res.fill) {
                root.applyFillRedetect(res);
                return;
            }

            // matchTheWords: the result is word list + items, not
            // answer boxes (and there is no section image to apply).
            if (String(act.type || "") === "matchTheWords") {
                if (!res.match_words || res.match_words.length === 0) {
                    print("Match redetect: nothing found in rect, kept as is");
                    return;
                }
                while (act.matchWord.length > 0)
                    act.removeMatchWord(0);
                for (var mi = 0; mi < res.match_words.length; mi++)
                    act.createMatchWord(res.match_words[mi], "");
                while (act.sentences.length > 0)
                    act.removeSentences(0);
                for (var si = 0; si < res.sentences.length; si++) {
                    var sn = res.sentences[si];
                    var rel = "";
                    if (sn.image_path) {
                        rel = sn.image_path;
                        if (rel.indexOf(appPath) === 0)
                            rel = "./" + rel.substring(appPath.length);
                    }
                    act.createSentences(sn.word || "", sn.sentence || "", rel);
                }
                print("Match redetect applied: " + res.match_words.length
                      + " words, " + res.sentences.length + " items");
                return;
            }

            // New crop image (unique name busts the QML image cache)
            if (root.cropNewSectionPath !== "")
                act.sectionPath = root.cropNewSectionPath;

            if (res.answer.length === 0) {
                print("Redetect: no options found in rect, crop applied, answers kept");
                return;
            }

            // Replace answers with the redetected option boxes
            while (act.answers.length > 0)
                act.removeAnswer(0);
            for (var i = 0; i < res.answer.length; i++) {
                var a = res.answer[i];
                act.createNewAnswer(a.coords.x, a.coords.y, a.coords.w, a.coords.h, "");
                if (a.isCorrect)
                    act.answers[act.answers.length - 1].isCorrect = true;
            }
            if (String(act.type || "") === "markwithx") {
                act.markCount = res.markCount !== undefined ? res.markCount : 0;
                print("Redetect applied: " + res.answer.length + " boxes, markCount=" + act.markCount);
            } else {
                act.circleCount = res.circleCount;
                print("Redetect applied: " + res.answer.length + " options, circleCount=" + res.circleCount);
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.cropMode
        onActivated: {
            root.endCropMode();
        }
    }
}
