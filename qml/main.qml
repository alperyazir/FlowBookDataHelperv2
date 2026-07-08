import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import QtQuick.Controls.Basic

ApplicationWindow {
    id: mainwindow
    visibility: Window.Maximized
    width: 1920// Screen.width
    height: 1080 //Screen.height
    visible: true
    color: "#232f34"

    // When true the 60s saveTimer auto-saves; when false the user must
    // save manually (Save / Ctrl+S). Toggled from the Settings menu.
    property bool autoSaveEnabled: true

    // Set right before Qt.quit() so the onClosing guard lets the app exit
    // instead of re-prompting (Qt.quit re-triggers onClosing).
    property bool forceQuit: false

    function save() {
        console.log("Ctrl+S shortcut activated!");

        sideBar.saveRemains();

        // CRASH-SAFE: Güvenli kaydetme
        try {
            if (config && config.bookSets && config.bookSets.length > 0) {
                config.bookSets[0].saveToJson();
                toast.show("Changes saved successfully!");
            } else {
                console.warn("No data to save!");
                toast.show("No data to save!");
            }
        } catch (error) {
            console.error("Save error:", error);
            toast.show("Save failed! Check console for details.");
        }
    }

    Shortcut {
        sequence: "Ctrl+S"
        onActivated: {
            save()
        }
    }

    // Per-book "show clickable hints" reader option, stored in config.json
    // (Book.show_clickable_hints). Guarded helpers so the Settings toggle never
    // crashes before a book is loaded.
    function clickableHintsEnabled() {
        return !!(config && config.bookSets && config.bookSets.length > 0
                  && config.bookSets[0].books && config.bookSets[0].books.length > 0
                  && config.bookSets[0].books[0].showClickableHints);
    }
    function setClickableHints(on) {
        if (config && config.bookSets && config.bookSets.length > 0
                && config.bookSets[0].books && config.bookSets[0].books.length > 0)
            config.bookSets[0].books[0].showClickableHints = on;
    }

    // Reliable "is there work that would be lost?" check, backed by the C++
    // hash compare (current model vs. last saved/loaded baseline).
    function hasUnsavedChanges() {
        return !!(config && config.bookSets && config.bookSets.length > 0
                  && config.bookSets[0].hasUnsavedChanges());
    }

    // Re-anchor the unsaved-changes baseline after a load. Deferred (callLater)
    // so it runs once the load-time QML bindings have settled — otherwise
    // opening a book and immediately closing would falsely prompt to save.
    function refreshBaselineAfterLoad() {
        Qt.callLater(function() {
            if (config && config.bookSets && config.bookSets.length > 0)
                config.bookSets[0].resetBaseline();
        });
    }

    // Opens the chosen book. Guarded: if the current book has unsaved edits we
    // ask the user (Save / Discard / Cancel) before throwing them away.
    function openBook(name) {
        if (!name || name === openProject.currentProject)
            return;
        if (hasUnsavedChanges()) {
            unsavedDialog.requestSwitch(name);
            return;
        }
        doOpenBook(name);
    }

    // Mirrors OpenProject's "open from recents" flow
    // (config.initialize + gamesParser.loadFromFile on the book directory).
    function doOpenBook(name) {
        if (!name)
            return;
        var projectDir = appPath + "books/" + name;
        openProject.currentProject = name;
        openProject.selectedProjectPath = projectDir;
        config.initialize(true, projectDir);
        gamesParser.loadFromFile(projectDir);
        refreshBaselineAfterLoad();
        console.log("Switched book ->", projectDir);
    }

    // Guarded project load by full path (used by the OpenProject dialog), same
    // unsaved-changes protection as openBook().
    function openProjectPath(path) {
        if (!path)
            return;
        if (hasUnsavedChanges()) {
            unsavedDialog.requestLoadPath(path);
            return;
        }
        doOpenProjectPath(path);
    }
    function doOpenProjectPath(path) {
        if (!path)
            return;
        config.initialize(true, path);
        gamesParser.loadFromFile(path);
        refreshBaselineAfterLoad();
        console.log("Project loaded ->", path);
    }

    // --- Quick-add shortcuts at current mouse position ---
    // `a` acts both as "audio" and as the prefix for activity shortcuts (a+d, a+g, ...).
    // We wait a short window after `a` to see if the next key completes an activity combo.
    property bool awaitingActivityKey: false

    // True while a text editor (header field, word pool, fill text...) holds
    // focus, so single-key shortcuts (c / h / ...) don't steal characters
    // from typing.
    property bool typingInField: {
        var fi = mainwindow.activeFocusItem;
        return !!(fi && fi.cursorPosition !== undefined && fi.selectedText !== undefined);
    }

    // True when the page has no active selection / open panel / live mode, so
    // the arrow keys can page through the book instead of aligning fills.
    readonly property bool nothingSelected:
        !activityDialog.visible && !awaitingActivityKey && !typingInField
        && !sideBar.audioVisible && !sideBar.videoVisible && !sideBar.activityVisible
        && !sideBar.fillVisible && !sideBar.circleVisible && !sideBar.fillwColorVisible
        && !sideBar.drawMatchedVisible && sideBar.fillSelection.length === 0
        && !content.pageDetails.fillSelectMode

    Timer {
        id: activityPrefixTimer
        interval: 450
        onTriggered: commitPendingAudio()
    }

    function commitPendingAudio() {
        if (awaitingActivityKey) {
            awaitingActivityKey = false;
            activityPrefixTimer.stop();
            content.pageDetails.addAudioAtMouse();
        }
    }

    function triggerActivityCombo(type) {
        awaitingActivityKey = false;
        activityPrefixTimer.stop();
        content.pageDetails.addActivityAtMouse(type);
    }

    Shortcut {
        sequence: "a"
        onActivated: {
            // Double-a: first 'a' becomes audio, second starts fresh
            if (awaitingActivityKey) commitPendingAudio();
            awaitingActivityKey = true;
            activityPrefixTimer.restart();
        }
    }

    Shortcut {
        sequence: "v"
        onActivated: {
            commitPendingAudio();
            content.pageDetails.addVideoAtMouse();
        }
    }

    Shortcut {
        sequence: "f"
        enabled: !activityDialog.visible
        onActivated: {
            if (awaitingActivityKey) triggerActivityCombo("fillpicture");
            else content.pageDetails.addFillAtMouse();
        }
    }

    // Activity sub-keys: only meaningful while waiting for activity combo
    Shortcut {
        sequence: "d"
        enabled: awaitingActivityKey
        onActivated: triggerActivityCombo("dragdroppicture")
    }
    Shortcut {
        sequence: "g"
        enabled: awaitingActivityKey
        onActivated: triggerActivityCombo("dragdroppicturegroup")
    }
    // `c`: completes the a→c "add circle" combo, OR — when an activity panel is
    // open on the right — crops that activity (smart crop / auto re-detect per
    // type, exactly like its Crop button), OR — when the Fill panel is open —
    // draws a rect to re-check the fill sizes in it against the answered PDF.
    // Guarded so it never steals a 'c' typed into a text field.
    Shortcut {
        sequence: "c"
        enabled: !typingInField
        onActivated: {
            if (awaitingActivityKey)
                triggerActivityCombo("circle");
            else if (sideBar.activityVisible
                     && String((sideBar.activityModelData
                                && sideBar.activityModelData.type) || "") !== "matchTheWords")
                // Match uses the l / r single-column crops; 'c' does nothing for it.
                content.startCropMode(sideBar.activityModelData);
            else if (sideBar.fillVisible)
                content.pageDetails.startFillRedetectMode();
            else if (sideBar.audioVisible)
                content.pageDetails.startPassageCropMode(sideBar.audioModelData);
        }
    }
    Shortcut {
        sequence: "m"
        enabled: awaitingActivityKey
        onActivated: triggerActivityCombo("matchTheWords")
    }
    Shortcut {
        sequence: "p"
        enabled: awaitingActivityKey
        onActivated: triggerActivityCombo("puzzleFindWords")
    }
    Shortcut {
        sequence: "x"
        enabled: awaitingActivityKey
        onActivated: triggerActivityCombo("markwithx")
    }
    Shortcut {
        sequence: "o"
        enabled: awaitingActivityKey
        onActivated: triggerActivityCombo("ordering")
    }
    // `l`: completes the a→l "add coloring" combo, OR — when a matchTheWords
    // activity is open — crops its LEFT column (the items: word + optional
    // picture) into matchWord.
    Shortcut {
        sequence: "l"
        enabled: awaitingActivityKey
                 || (sideBar.activityVisible && !typingInField
                     && sideBar.activityModelData
                     && String(sideBar.activityModelData.type || "") === "matchTheWords")
        onActivated: {
            if (awaitingActivityKey)
                triggerActivityCombo("coloring");
            else
                content.startMatchColumnCrop(sideBar.activityModelData, "left");
        }
    }

    // `h`: pick the header text of the open activity (read the instruction
    // line from the PDF inside the drawn rect), exactly like its Pick button.
    Shortcut {
        sequence: "h"
        enabled: sideBar.activityVisible && !awaitingActivityKey && !typingInField
        onActivated: content.startHeaderPickMode(sideBar.activityModelData)
    }

    // `r`: for a matchTheWords activity, crop its RIGHT column (the
    // sentences); otherwise toggle the fill-select (rubber-band) tool.
    Shortcut {
        sequence: "r"
        enabled: !typingInField && !awaitingActivityKey && !activityDialog.visible
        onActivated: {
            if (sideBar.activityVisible && sideBar.activityModelData
                    && String(sideBar.activityModelData.type || "") === "matchTheWords")
                content.startMatchColumnCrop(sideBar.activityModelData, "right");
            else
                content.pageDetails.fillSelectMode = !content.pageDetails.fillSelectMode;
        }
    }

    // Left arrow: align the selected fills to the leftmost one.
    Shortcut {
        sequence: "Left"
        enabled: sideBar.fillSelection.length > 1 && !typingInField
                 && !awaitingActivityKey && !activityDialog.visible
        onActivated: content.pageDetails.alignSelectedLeft()
    }

    // Down arrow: align the selected fills to the bottom-most one.
    Shortcut {
        sequence: "Down"
        enabled: sideBar.fillSelection.length > 1 && !typingInField
                 && !awaitingActivityKey && !activityDialog.visible
        onActivated: content.pageDetails.alignSelectedBottom()
    }

    // Right arrow: align the selected fills to the rightmost one.
    Shortcut {
        sequence: "Right"
        enabled: sideBar.fillSelection.length > 1 && !typingInField
                 && !awaitingActivityKey && !activityDialog.visible
        onActivated: content.pageDetails.alignSelectedRight()
    }

    // Up arrow: align the selected fills to the top-most one.
    Shortcut {
        sequence: "Up"
        enabled: sideBar.fillSelection.length > 1 && !typingInField
                 && !awaitingActivityKey && !activityDialog.visible
        onActivated: content.pageDetails.alignSelectedTop()
    }

    // `b`: bold / unbold the selected fills (same as the Fill panel's Bold
    // toggle). If every selected fill is already bold it unbolds them all.
    Shortcut {
        sequence: "b"
        enabled: sideBar.fillSelection.length > 0 && !typingInField
                 && !awaitingActivityKey && !activityDialog.visible
        onActivated: {
            var sel = sideBar.fillSelection;
            var allBold = sel.length > 0;
            for (var i = 0; i < sel.length; i++) {
                if (!sel[i].isTextBold) {
                    allBold = false;
                    break;
                }
            }
            for (var j = 0; j < sel.length; j++)
                sel[j].isTextBold = !allBold;
        }
    }

    // Left / Right arrows page through the book when nothing is selected.
    // (With a 2+ fill selection the arrows align fills instead — see above.)
    Shortcut {
        sequence: "Right"
        enabled: mainwindow.nothingSelected
        onActivated: content.goNext()
    }
    Shortcut {
        sequence: "Left"
        enabled: mainwindow.nothingSelected
        onActivated: content.goPrev()
    }

    // Up / Down arrows jump 10 pages forward / back when nothing is selected.
    Shortcut {
        sequence: "Down"
        enabled: mainwindow.nothingSelected
        onActivated: content.goBy(-10)
    }
    Shortcut {
        sequence: "Up"
        enabled: mainwindow.nothingSelected
        onActivated: content.goBy(10)
    }

    // Space: open the selected activity, or play/pause the selected audio/video.
    Shortcut {
        sequence: "Space"
        enabled: (sideBar.activityVisible || sideBar.audioVisible || sideBar.videoVisible)
                 && !typingInField && !awaitingActivityKey
        onActivated: sideBar.triggerSpace()
    }

    // Escape: clear the current selection (hide the side panel, drop the
    // on-page highlight). When the activity dialog is open, its own Escape
    // handler closes it and clears the selection too.
    Shortcut {
        sequence: "Escape"
        enabled: !activityDialog.visible
                 && (sideBar.audioVisible || sideBar.videoVisible || sideBar.activityVisible
                     || sideBar.fillVisible || sideBar.circleVisible
                     || sideBar.fillwColorVisible || sideBar.drawMatchedVisible
                     || sideBar.fillSelection.length > 0
                     || content.pageDetails.fillSelectMode)
        onActivated: {
            content.pageDetails.fillSelectMode = false;
            content.pageDetails.clearFillSelection();
            sideBar.hideAllComponent();
        }
    }

    Shortcut {
        sequences: ["Delete", "Backspace"]
        // Don't fire while editing a fill's text/color field — there Backspace
        // must edit the text, not delete the selection.
        enabled: !typingInField
        onActivated: content.pageDetails.removeSelectedSection()
    }

    Colors {
        id: myColors
    }

    FlowToolBar {
        id: toolBar
        onOutlineEnabled: {
            content.outlineEnabled = enabled;
        }
    }

    Content {
        id: content
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: parent.width / 9
        anchors.top: toolBar.bottom
        width: parent.width / 1.95
    }

    // Book switcher in the empty left gutter: an arrow tab that opens a list
    // of every book under books/, in order. Selecting one opens it.
    Rectangle {
        id: bookSwitcherTab
        width: 34
        height: 64
        radius: 8
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: content.verticalCenter
        z: 50
        color: (bookSwitcherTabArea.containsMouse || bookSwitcherPopup.opened) ? "#1d2c33" : "#19242a"
        border.color: "#2a8e96"
        border.width: 1
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: bookSwitcherPopup.opened ? "‹" : "›"
            color: "#00e6e6"
            font.pixelSize: 22
            font.bold: true
        }

        MouseArea {
            id: bookSwitcherTabArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (bookSwitcherPopup.opened) {
                    bookSwitcherPopup.close();
                } else {
                    config.refreshRecentProjects();
                    bookSwitcherPopup.open();
                }
            }
        }
    }

    Popup {
        id: bookSwitcherPopup
        property int count: (config && config.recentProject) ? config.recentProject.length : 0
        x: bookSwitcherTab.x + bookSwitcherTab.width + 6
        // Vertically centered on the tab (which sits at the content center).
        y: Math.max(toolBar.height + 8,
                    Math.min(bookSwitcherTab.y + bookSwitcherTab.height / 2 - height / 2,
                             mainwindow.height - height - 12))
        width: 260
        height: Math.max(140, Math.min(mainwindow.height - toolBar.height - 60,
                                       bookSwitcherPopup.count * 38 + 56))
        padding: 8
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: "#202c33"
            border.color: "#33505b"
            border.width: 1
            radius: 10
        }

        contentItem: ListView {
            id: bookListView
            clip: true
            model: config ? config.recentProject : []
            spacing: 2
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            header: Text {
                width: bookListView.width
                leftPadding: 4
                bottomPadding: 6
                text: "Books"
                color: "#9fc4c8"
                font.pixelSize: 13
                font.bold: true
            }

            delegate: Rectangle {
                required property var modelData
                width: ListView.view ? ListView.view.width : 0
                height: 36
                radius: 6
                readonly property bool isCurrent: modelData === openProject.currentProject
                color: isCurrent ? "#009ca6"
                                 : (rowArea.containsMouse ? "#26343b" : "transparent")

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 20
                    text: parent.modelData
                    elide: Text.ElideRight
                    color: parent.isCurrent ? "#10343a" : "#e6f2f3"
                    font.pixelSize: 13
                    font.bold: parent.isCurrent
                }

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        mainwindow.openBook(parent.modelData);
                        bookSwitcherPopup.close();
                    }
                }
            }
        }
    }

    FlowSideBar {
        id: sideBar
        width: parent.width / 3
        anchors.right: parent.right
        anchors.top: toolBar.bottom
        anchors.bottom: parent.bottom
    }

    // Generic "you have unsaved changes" guard, shared by app-close and
    // book-switch. The pending action is remembered so we can run it after the
    // user picks Save / Discard / Cancel.
    //   Save    -> accepted()  : save(), then run pending
    //   Discard -> discarded() : run pending without saving
    //   Cancel  -> rejected()  : do nothing (stay where we are)
    Dialog {
        id: unsavedDialog
        modal: true
        width: 520
        anchors.centerIn: parent
        padding: 0
        closePolicy: Popup.NoAutoClose

        // "exit", "switch" or "load"
        property string pendingAction: ""
        property string pendingBook: ""
        property string pendingPath: ""

        function requestExit() {
            pendingAction = "exit";
            pendingBook = "";
            pendingPath = "";
            open();
        }
        function requestSwitch(name) {
            pendingAction = "switch";
            pendingBook = name;
            pendingPath = "";
            open();
        }
        function requestLoadPath(path) {
            pendingAction = "load";
            pendingBook = "";
            pendingPath = path;
            open();
        }
        function runPending() {
            var action = pendingAction;
            var book = pendingBook;
            var path = pendingPath;
            pendingAction = "";
            pendingBook = "";
            pendingPath = "";
            if (action === "exit") {
                mainwindow.forceQuit = true;
                Qt.quit();
            }
            else if (action === "switch")
                mainwindow.doOpenBook(book);
            else if (action === "load")
                mainwindow.doOpenProjectPath(path);
        }

        background: Rectangle {
            color: "#232f34"
            border.color: "#009ca6"
            border.width: 1
            radius: 4
        }

        header: Rectangle {
            color: "#1A2327"
            height: 44
            border.color: "#009ca6"
            border.width: 1
            Label {
                text: "Unsaved Changes"
                color: "white"
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 14
                font.pixelSize: 16
                font.bold: true
            }
        }

        contentItem: Text {
            text: "You have unsaved changes.\nSave them before continuing?"
            color: "white"
            font.pixelSize: 16
            lineHeight: 1.25
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
            topPadding: 28
            bottomPadding: 28
            leftPadding: 24
            rightPadding: 24
        }

        footer: Rectangle {
            color: "#1A2327"
            height: 64
            border.color: "#009ca6"
            border.width: 1
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                spacing: 10

                // Ghost (destructive) — leave without saving
                Button {
                    text: "Don't Save"
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 36
                    background: Rectangle {
                        color: parent.down ? "#3a2526" : (parent.hovered ? "#2A3337" : "transparent")
                        border.color: "#a94442"
                        border.width: 1
                        radius: 6
                        Behavior on color { ColorAnimation { duration: 90 } }
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#e0a9a7"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: { unsavedDialog.close(); unsavedDialog.runPending(); }
                }

                Item { Layout.fillWidth: true }

                // Ghost — cancel, stay where we are
                Button {
                    text: "Cancel"
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 36
                    background: Rectangle {
                        color: parent.down ? "#2c3e47" : (parent.hovered ? "#22323a" : "transparent")
                        border.color: "#3a5560"
                        border.width: 1
                        radius: 6
                        Behavior on color { ColorAnimation { duration: 90 } }
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#cfe8ea"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        unsavedDialog.pendingAction = "";
                        unsavedDialog.pendingBook = "";
                        unsavedDialog.pendingPath = "";
                        unsavedDialog.close();
                    }
                }

                // Primary — save then proceed
                Button {
                    text: "Save"
                    Layout.preferredWidth: 110
                    Layout.preferredHeight: 36
                    background: Rectangle {
                        color: parent.down ? "#00808a" : (parent.hovered ? "#00b3be" : "#009ca6")
                        radius: 6
                        Behavior on color { ColorAnimation { duration: 90 } }
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: { unsavedDialog.close(); mainwindow.save(); unsavedDialog.runPending(); }
                }
            }
        }
    }

    // Intercept window close (the X button / Cmd+Q): if there's unsaved work,
    // veto the close and ask first. With nothing to lose, close normally.
    onClosing: function(closeEvent) {
        if (!forceQuit && hasUnsavedChanges()) {
            closeEvent.accepted = false;
            unsavedDialog.requestExit();
        }
    }

    FlowToast {
        id: toast
    }

    // Surface Python script failures (crop, re-detect, header pick, …) to the
    // user as a red warning toast instead of only printing to the console.
    Connections {
        target: pdfProcess
        function onScriptError(message) {
            toast.show(message, true);
        }
    }

    ActivityDialog {
        id: activityDialog
    }

    NewProjectDialog {
        id: newProjectDialog
        width: parent.width / 2
        height: parent.height / 6 * 5
        onAccepted: {
            // Show progress dialog when starting processing
            flowProgress.reset();
            flowProgress.statusText = "Processing your project...";
            flowProgress.addLogMessage("Starting project creation...");
            flowProgress.open();
        }
    }

    FlowProgress {
        id: flowProgress
    }

    OpenProject {
        id: openProject
        onLoadRequested: function(path) { mainwindow.openProjectPath(path); }
    }

    TestDialog {
        id: testDialog
    }

    PackageDialog {
        id: packageDialog
    }

    OptimizeDialog {
        id: optimizeDialog
    }

    DependencyDialog {
        id: dependencyDialog
    }

    GamesDialog {
        id: gamesDialog
    }

    ModuleEditorDialog {
        id: moduleEditorDialog
    }

    Connections {
        target: config
        function onBookSetsChanged() {
            print("Book is changed");
            content.currentPageIndex++;
            content.currentPageIndex--;
        }
    }

    // VideoOutput {
    //     id: videoOutput
    //     width: 1000
    //     height: 1000
    //     anchors.centerIn: parent
    // }

    Rectangle {
        id: versionRect
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 20
        width: versionText.width + 20
        height: 40
        color: "#1A2327"
        border.color: versionPulse.running ? "#00e6e6" : "#009ca6"
        border.width: versionPulse.running ? 2 : 1
        radius: 2
        scale: 1.0

        SequentialAnimation {
            id: versionPulse
            NumberAnimation { target: versionRect; property: "scale"; to: 1.2; duration: 180; easing.type: Easing.OutBack }
            NumberAnimation { target: versionRect; property: "scale"; to: 1.0; duration: 320; easing.type: Easing.OutBounce }
        }

        Text {
            id: versionText
            text: "v3.2.2"
            color: "#009ca6"
            anchors.centerIn: parent
            font.pixelSize: 14
        }

        MouseArea {
            id: versionClicker
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor

            property int clickCount: 0

            Timer {
                id: clickResetTimer
                interval: 900
                onTriggered: versionClicker.clickCount = 0
            }

            onClicked: {
                versionClicker.clickCount++;
                clickResetTimer.restart();
                if (versionClicker.clickCount >= 3) {
                    versionClicker.clickCount = 0;
                    clickResetTimer.stop();
                    easterEgg.playVideoOnly();
                } else {
                    easterEgg.burstOnly();
                }
            }
        }
    }

    // Easter-egg layer: confetti burst + greeting card
    Item {
        id: easterEgg
        anchors.fill: parent
        z: 1000

        property var palette: ["#ff3b6b", "#ff6b9d", "#ff91b5", "#ff4d8f", "#e91e63", "#ffd24a", "#f472b6", "#a78bfa"]

        function burstOnly() {
            versionPulse.restart();
            greeting.show();
            var originX = versionRect.x + versionRect.width / 2;
            var originY = versionRect.y + versionRect.height / 2;
            for (var i = 0; i < 32; i++) {
                var angle = (Math.PI * 2) * (i / 32) + (Math.random() - 0.5) * 0.25;
                var speed = 140 + Math.random() * 160;
                confettiComponent.createObject(easterEgg, {
                    x: originX - 4,
                    y: originY - 4,
                    vx: Math.cos(angle) * speed,
                    vy: Math.sin(angle) * speed - 80,
                    tint: palette[Math.floor(Math.random() * palette.length)],
                    lifespan: 1100 + Math.random() * 700,
                    rotEnd: (Math.random() - 0.5) * 1440
                });
            }
        }

        function playVideoOnly() {
            versionPulse.restart();
            greeting.showPersistent();
            videoPopup.play();
        }

        Component {
            id: confettiComponent
            Text {
                id: particle
                property real vx: 0
                property real vy: 0
                property int lifespan: 1500
                property real rotEnd: 0
                property color tint: "#ff6b9d"
                text: "♥"
                color: particle.tint
                font.pixelSize: 16 + Math.floor(Math.random() * 14)
                font.bold: true
                style: Text.Raised
                styleColor: Qt.darker(particle.tint, 1.4)
                antialiasing: true
                opacity: 1.0
                transformOrigin: Item.Center

                ParallelAnimation {
                    running: true
                    NumberAnimation { target: particle; property: "x"; to: particle.x + particle.vx; duration: particle.lifespan; easing.type: Easing.OutQuad }
                    SequentialAnimation {
                        NumberAnimation { target: particle; property: "y"; to: particle.y + particle.vy; duration: particle.lifespan * 0.35; easing.type: Easing.OutQuad }
                        NumberAnimation { target: particle; property: "y"; to: particle.y + particle.vy + 260; duration: particle.lifespan * 0.65; easing.type: Easing.InQuad }
                    }
                    NumberAnimation { target: particle; property: "rotation"; to: particle.rotEnd; duration: particle.lifespan }
                    SequentialAnimation {
                        NumberAnimation { target: particle; property: "scale"; from: 0.4; to: 1.0; duration: 200; easing.type: Easing.OutBack }
                        PauseAnimation { duration: particle.lifespan * 0.35 }
                        NumberAnimation { target: particle; property: "scale"; to: 0.6; duration: particle.lifespan * 0.45; easing.type: Easing.InQuad }
                    }
                    SequentialAnimation {
                        PauseAnimation { duration: particle.lifespan * 0.55 }
                        NumberAnimation { target: particle; property: "opacity"; to: 0; duration: particle.lifespan * 0.45; easing.type: Easing.InQuad }
                    }
                    onFinished: particle.destroy()
                }
            }
        }

        // Greeting card — shows next to version badge for the short burst,
        // or locked at bottom-right while the full-screen video is playing.
        Rectangle {
            id: greeting
            property bool persistentMode: false
            width: greetingRow.implicitWidth + 24
            height: 40
            radius: 20
            x: persistentMode
               ? (easterEgg.width - width - 20)
               : (versionRect.x + versionRect.width + 10)
            y: persistentMode
               ? (easterEgg.height - height - 20)
               : (versionRect.y + (versionRect.height - height) / 2)
            opacity: 0
            scale: 0.6
            visible: opacity > 0.01
            z: 20
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#009ca6" }
                GradientStop { position: 0.5; color: "#0d7a8c" }
                GradientStop { position: 1.0; color: "#7c3aed" }
            }
            border.color: "#00e6e6"
            border.width: 1

            Row {
                id: greetingRow
                anchors.centerIn: parent
                spacing: 6
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Made by Alper"
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                }
            }

            function show() {
                persistentMode = false;
                showAnim.restart();
                hideDelay.restart();
            }

            function showPersistent() {
                persistentMode = true;
                hideDelay.stop();
                showAnim.restart();
            }

            function hide() {
                hideDelay.stop();
                hideAnim.restart();
            }

            ParallelAnimation {
                id: showAnim
                NumberAnimation { target: greeting; property: "opacity"; to: 1.0; duration: 260; easing.type: Easing.OutQuad }
                NumberAnimation { target: greeting; property: "scale"; to: 1.0; duration: 320; easing.type: Easing.OutBack }
            }

            ParallelAnimation {
                id: hideAnim
                NumberAnimation { target: greeting; property: "opacity"; to: 0; duration: 400; easing.type: Easing.InQuad }
                NumberAnimation { target: greeting; property: "scale"; to: 0.6; duration: 400; easing.type: Easing.InQuad }
            }

            Timer {
                id: hideDelay
                interval: 2400
                onTriggered: hideAnim.restart()
            }
        }

        // Full-screen video overlay (triggered on 3× version click)
        Rectangle {
            id: videoPopup
            anchors.fill: parent
            color: "#ee000000"  // near-opaque black backdrop
            opacity: 0
            visible: opacity > 0.01
            z: 10

            property url videoSource: "qrc:/fun/minion.mp4"

            function play() {
                videoPlayer.source = "";
                videoPlayer.source = videoPopup.videoSource;
                videoPlayer.play();
                videoShowAnim.restart();
            }

            function stop() {
                videoPlayer.stop();
                videoHideAnim.restart();
                greeting.hide();
            }

            // Modal backdrop: swallows clicks so dialogs behind don't receive them,
            // but does NOT close the popup on click — only the × button or Escape.
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                onClicked: (mouse) => mouse.accepted = true
                onPressed: (mouse) => mouse.accepted = true
            }

            MediaPlayer {
                id: videoPlayer
                videoOutput: videoOut
                audioOutput: AudioOutput { volume: 0.9 }
                onMediaStatusChanged: {
                    if (mediaStatus === MediaPlayer.EndOfMedia
                            && videoPopup.opacity > 0.5) {
                        videoPopup.stop();
                    }
                }
                onErrorOccurred: function(error, errorString) {
                    console.log("Easter video error:", errorString);
                    videoPopup.stop();
                }
            }

            // Centered video frame with subtle glow
            Rectangle {
                id: videoFrame
                anchors.centerIn: parent
                width: parent.width * 0.85
                height: parent.height * 0.85
                color: "#0b1012"
                radius: 8
                border.color: "#00e6e6"
                border.width: 2
                scale: 0.6

                VideoOutput {
                    id: videoOut
                    anchors.fill: parent
                    anchors.margins: 4
                }

                // Absorb clicks on the video so they don't close via backdrop
                MouseArea { anchors.fill: parent }
            }

            // Close button
            Rectangle {
                width: 42; height: 42
                radius: 21
                color: closeMouse.containsMouse ? "#ff3b6b" : "#1A2327"
                border.color: "#00e6e6"
                border.width: 2
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 24
                z: 2

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: "white"
                    font.pixelSize: 26
                    font.bold: true
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: videoPopup.stop()
                }
            }

            Shortcut {
                sequence: "Escape"
                enabled: videoPopup.opacity > 0.5
                onActivated: videoPopup.stop()
            }

            ParallelAnimation {
                id: videoShowAnim
                NumberAnimation { target: videoPopup; property: "opacity"; to: 1.0; duration: 280; easing.type: Easing.OutQuad }
                NumberAnimation { target: videoFrame; property: "scale"; to: 1.0; duration: 420; easing.type: Easing.OutBack }
            }

            ParallelAnimation {
                id: videoHideAnim
                NumberAnimation { target: videoPopup; property: "opacity"; to: 0; duration: 300; easing.type: Easing.InQuad }
                NumberAnimation { target: videoFrame; property: "scale"; to: 0.6; duration: 300; easing.type: Easing.InQuad }
            }
        }
    }

    Timer {
        id: heartbeatTimer
        interval: 5000 // 5 saniyede bir
        repeat: true
        running: true
        onTriggered: {
            var xhr = new XMLHttpRequest();
            //var url = "http://localhost:3000/api/clients";
            //var url = "https://flowtrack.dreamedtech.com/helper.php";
            //var url = config.url
            var url = "https://flowbook.uk/api/helpers"
            var jsonData = {
                "type": "helper",
                "hostname": config.hostname,
                "os_info": Qt.platform.os,
                "version": Qt.application.version,
                "locked": config.isLocked,
                "active_book": openProject.currentProject,
                "active": activityTracker.active,
                "open_seconds": activityTracker.openSeconds,
                "idle_seconds": activityTracker.idleSeconds,
                "active_seconds": activityTracker.openSeconds - activityTracker.idleSeconds
            };

            // Remote kill switch: the server answers with this host's lock
            // state; apply it. A failed/non-200 request changes nothing
            // (fail-open), so the last state simply sticks.
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText);
                        if (res.hostname === undefined || res.hostname === config.hostname) {
                            if (res.locked !== undefined) {
                                var lock = (res.locked === true || res.locked === 1
                                            || res.locked === "1" || res.locked === "true");
                                config.updateLockStatus(lock);
                            }
                        }
                    } catch (e) {
                        console.log("heartbeat: bad response", e);
                    }
                }
            };

            xhr.open("POST", url);
            xhr.setRequestHeader("Content-Type", "application/json");
            xhr.send(JSON.stringify(jsonData));
        }
    }

    Timer {
        id: saveTimer
        interval: 60000 // every 60 seconds
        repeat: true
        running: mainwindow.autoSaveEnabled
        onTriggered: {
            // The C++ saveToJson(true) is fully guarded:
            //   * skips while a load is in progress
            //   * skips when the serialized hash matches the last save
            //     (this is the real dirty check — bypasses UI markDirty races)
            //   * refuses to write if books/modules collapsed to zero
            // No-op ticks are cheap (one toJson + one md5 compare).
            if (config && config.bookSets && config.bookSets.length > 0) {
                config.bookSets[0].saveToJson(true);
            }
        }
    }

    // Remote lock overlay — declared LAST and given a very high z so it paints
    // on top of the whole UI and swallows input. Its visibility strictly
    // follows the server-driven config.isLocked.
    LockScreen {
        anchors.fill: parent
        z: 100000
        visible: config.isLocked
    }
}
