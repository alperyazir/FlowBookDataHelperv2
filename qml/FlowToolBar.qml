import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import "newComponents"

Rectangle {
    id: root
    property var pages: (config && config.bookSets && config.bookSets.length > 0
                         && config.bookSets[0].books && config.bookSets[0].books.length > 0)
                        ? config.bookSets[0].books[0].pages : []
    property int currentPageNumber: 0
    signal outlineEnabled(bool enabled)
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 50
    color: "#1A2327" // Dark background
    border.color: "#009ca6" // Turquoise border
    border.width: 1

    // ===== Menu bar (top row) =====
    Row {
        id: menuRow
        height: 30
        spacing: 2
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 8

        MenuButton {
            text: "File"
            onClicked: fileMenu.open()
            AppMenu {
                id: fileMenu
                y: parent.height + 2
                AppMenuItem { text: "New Project"; onTriggered: newProjectDialog.open() }
                AppMenuItem {
                    text: "Open…"
                    onTriggered: {
                        config.refreshRecentProjects();
                        openProject.loadRecentProjects();
                        openProject.open();
                    }
                }
                AppMenuItem { text: "Save"; onTriggered: save() }
            }
        }

        MenuButton {
            text: "Project"
            onClicked: projectMenu.open()
            AppMenu {
                id: projectMenu
                y: parent.height + 2
                AppMenuItem { text: "Analyze…"; onTriggered: analyzeConfirmDialog.open() }
                AppMenuItem {
                    text: "Test"
                    onTriggered: {
                        testDialog.currentProject = openProject.currentProject;
                        testDialog.open();
                    }
                }
                AppMenuItem {
                    text: "Optimize PDFs…"
                    onTriggered: optimizeDialog.open()
                }
                AppMenuItem {
                    text: "Package"
                    onTriggered: {
                        packageDialog.currentProject = openProject.currentProject;
                        packageDialog.open();
                    }
                }
                AppMenuItem { text: "Games"; onTriggered: gamesDialog.open() }
            }
        }

        MenuButton {
            text: "Settings"
            onClicked: settingsMenu.open()
            AppMenu {
                id: settingsMenu
                y: parent.height + 2
                implicitWidth: 240
                AppMenuItem {
                    text: "Auto-save"
                    checkable: true
                    checked: mainwindow.autoSaveEnabled
                    onTriggered: mainwindow.autoSaveEnabled = !mainwindow.autoSaveEnabled
                }
            }
        }

        MenuButton {
            text: "Help"
            onClicked: helpMenu.open()
            AppMenu {
                id: helpMenu
                y: parent.height + 2
                implicitWidth: 200
                AppMenuItem { text: "Keyboard Shortcuts"; onTriggered: shortcutsDialog.open() }
                AppMenuItem { text: "Dependencies"; onTriggered: dependencyDialog.open() }
            }
        }

        // Analyze regenerates all sections. Optionally crop one audio and/or
        // video icon first; the OpenCV matcher (proto_icon_match.py) then
        // positions the media buttons. Two actions: icons only, or analyze
        // followed by the icon pass.
        Dialog {
            id: analyzeConfirmDialog
            modal: true
            anchors.centerIn: Overlay.overlay
            width: 520
            padding: 20

            property string audioIconPath: ""
            property string videoIconPath: ""
            // when true, run the icon matcher right after Analyze finishes.
            property bool runIconsAfterAnalyze: false

            function bookConfigPath() {
                return config.bookSets[0].bookDirectoryName + "/config.json";
            }
            // doSave: flush the in-memory model to config.json first. The
            // post-Analyze chain MUST pass false — Analyze already wrote
            // config.json on disk and the in-memory model is still stale
            // (reloaded asynchronously), so saving would clobber it.
            function runIconMatch(doSave) {
                if (doSave)
                    save();
                pdfProcess.matchIcons(bookConfigPath(),
                                      audioIconPath, videoIconPath);
                flowProgress.reset();
                flowProgress.statusText = "Finding audio/video icons...";
                flowProgress.addLogMessage("Matching icon templates...");
                flowProgress.open();
            }

            // Crop template flow reuses pdfProcess.cropSectionFromPdf; the
            // chaining handler runs the matcher after Analyze completes.
            Connections {
                target: pdfProcess
                // Identify an icon-template crop by its output path (icon
                // crops write icon_template_<kind>.png), not by transient
                // state — so an abandoned crop can't poison a later activity
                // crop, and normal activity crops are ignored here.
                function onCropCompleted(success, outputPath) {
                    var isAudio = outputPath.indexOf("icon_template_audio") !== -1;
                    var isVideo = outputPath.indexOf("icon_template_video") !== -1;
                    if (!isAudio && !isVideo)
                        return;
                    if (success) {
                        if (isAudio)
                            analyzeConfirmDialog.audioIconPath = outputPath;
                        else
                            analyzeConfirmDialog.videoIconPath = outputPath;
                    }
                    analyzeConfirmDialog.open();
                }
                function onAiAnalysisCompleted(success) {
                    if (!analyzeConfirmDialog.runIconsAfterAnalyze)
                        return;
                    analyzeConfirmDialog.runIconsAfterAnalyze = false;
                    if (success
                        && (analyzeConfirmDialog.audioIconPath !== ""
                            || analyzeConfirmDialog.videoIconPath !== ""))
                        analyzeConfirmDialog.runIconMatch(false);  // disk fresh
                }
            }

            background: Rectangle {
                color: "#1A2327"
                border.color: "#009ca6"
                border.width: 1
                radius: 8
            }

            FileDialog {
                id: audioIconFileDialog
                title: "Select audio icon image"
                nameFilters: ["Images (*.png *.jpg *.jpeg *.bmp)"]
                onAccepted: analyzeConfirmDialog.audioIconPath =
                            selectedFile.toString().replace("file://", "")
            }
            FileDialog {
                id: videoIconFileDialog
                title: "Select video icon image"
                nameFilters: ["Images (*.png *.jpg *.jpeg *.bmp)"]
                onAccepted: analyzeConfirmDialog.videoIconPath =
                            selectedFile.toString().replace("file://", "")
            }

            contentItem: Column {
                spacing: 14

                Row {
                    spacing: 8
                    Text {
                        width: 90; text: "Audio icon:"; color: "#9fb3ba"
                        font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter
                    }
                    Rectangle {
                        width: 218; height: 32; radius: 6
                        color: "#232f34"; border.color: "#2a3a42"
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                            verticalAlignment: Text.AlignVCenter; elide: Text.ElideLeft
                            text: analyzeConfirmDialog.audioIconPath === "" ? "— none —"
                                                                       : analyzeConfirmDialog.audioIconPath
                            color: analyzeConfirmDialog.audioIconPath === "" ? "#667788" : "#00e6e6"
                            font.pixelSize: 12
                        }
                    }
                    Button {
                        text: "Crop"; width: 76; height: 32
                        anchors.verticalCenter: parent.verticalCenter
                        background: Rectangle {
                            color: parent.hovered ? "#00b3be" : "#009ca6"; radius: 6
                        }
                        contentItem: Text {
                            text: parent.text; color: "white"; font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            analyzeConfirmDialog.close();
                            content.goToFirstMediaPage("audio");
                            content.startIconCrop("audio");
                        }
                    }
                    Button {
                        text: "File…"; width: 70; height: 32
                        anchors.verticalCenter: parent.verticalCenter
                        background: Rectangle {
                            color: parent.hovered ? "#2A3337" : "#1A2327"
                            border.color: "#445055"; radius: 6
                        }
                        contentItem: Text {
                            text: parent.text; color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: audioIconFileDialog.open()
                    }
                }

                Row {
                    spacing: 8
                    Text {
                        width: 90; text: "Video icon:"; color: "#9fb3ba"
                        font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter
                    }
                    Rectangle {
                        width: 218; height: 32; radius: 6
                        color: "#232f34"; border.color: "#2a3a42"
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8
                            verticalAlignment: Text.AlignVCenter; elide: Text.ElideLeft
                            text: analyzeConfirmDialog.videoIconPath === "" ? "— none —"
                                                                       : analyzeConfirmDialog.videoIconPath
                            color: analyzeConfirmDialog.videoIconPath === "" ? "#667788" : "#00e6e6"
                            font.pixelSize: 12
                        }
                    }
                    Button {
                        text: "Crop"; width: 76; height: 32
                        anchors.verticalCenter: parent.verticalCenter
                        background: Rectangle {
                            color: parent.hovered ? "#00b3be" : "#009ca6"; radius: 6
                        }
                        contentItem: Text {
                            text: parent.text; color: "white"; font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            analyzeConfirmDialog.close();
                            content.goToFirstMediaPage("video");
                            content.startIconCrop("video");
                        }
                    }
                    Button {
                        text: "File…"; width: 70; height: 32
                        anchors.verticalCenter: parent.verticalCenter
                        background: Rectangle {
                            color: parent.hovered ? "#2A3337" : "#1A2327"
                            border.color: "#445055"; radius: 6
                        }
                        contentItem: Text {
                            text: parent.text; color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: videoIconFileDialog.open()
                    }
                }

                Row {
                    anchors.right: parent.right
                    spacing: 10

                    Button {
                        text: "Cancel"
                        width: 90; height: 36
                        background: Rectangle {
                            color: parent.hovered ? "#2A3337" : "#1A2327"
                            border.color: "#445055"; border.width: 1; radius: 6
                        }
                        contentItem: Text {
                            text: parent.text; color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: analyzeConfirmDialog.close()
                    }

                    // Run Analyze, then the icon matcher (if an icon was cropped).
                    Button {
                        text: "Analyze"
                        width: 110; height: 36
                        enabled: !pdfProcess.aiAnalyzing
                        background: Rectangle {
                            color: !parent.enabled ? "#5a8d91"
                                                   : (parent.hovered ? "#00b3be" : "#009ca6")
                            radius: 6
                        }
                        contentItem: Text {
                            text: parent.text; color: "white"; font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            if (pdfProcess.aiAnalyzing)
                                return;
                            analyzeConfirmDialog.close();

                            var configPath = analyzeConfirmDialog.bookConfigPath();
                            var settingsPath = appPath + "settings.json";

                            // chain the icon pass after Analyze if a template is set
                            analyzeConfirmDialog.runIconsAfterAnalyze =
                                (analyzeConfirmDialog.audioIconPath !== ""
                                 || analyzeConfirmDialog.videoIconPath !== "");

                            save();
                            pdfProcess.startAIAnalysis(configPath, settingsPath);

                            flowProgress.reset();
                            flowProgress.statusText = "AI Analysis in progress...";
                            flowProgress.addLogMessage("Starting AI analysis...");
                            flowProgress.open();
                        }
                    }
                }
            }
        }

    }

    // separator: menu group | toolbar controls
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: menuRow.right
        anchors.leftMargin: 12
        width: 1
        height: 24
        color: "#2a3a42"
    }

    Row {
        id: pagesRow
        height: 38
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8
        anchors.verticalCenter: parent.verticalCenter

        Button {
            anchors.verticalCenter: parent.verticalCenter
            text: "<"
            width: 112
            height: parent.height
            background: Rectangle {
                color: "#232f34"
                radius: 6
            }
            contentItem: Text {
                text: parent.text
                color: "#00e6e6"
                font.bold: true
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                content.goPrev();
            }
        }
        TextField {
            id: pageNumberInput
            property int firstPage: (pages && pages.length > 0) ? pages[0].page_number : 0
            property int lastPage: (pages && pages.length > 0) ? pages[pages.length - 1].page_number : 0
            width: 80
            height: parent.height
            color: "white" // text color
            background: Rectangle {
                color: "#232f34"
                radius: 6
            }
            selectionColor: "#00e6e6"
            placeholderText: "Page"
            placeholderTextColor: "gray"
            validator: IntValidator {
                bottom: pageNumberInput.firstPage
                top: pageNumberInput.lastPage
            }
            font.pixelSize: 18
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.currentPageNumber
            onAccepted: {
                var page = parseInt(text);
                content.goToPage(page - pages[0].page_number);
                focus = false;
            }
        }
        Button {
            anchors.verticalCenter: parent.verticalCenter
            text: ">"
            width: 112
            height: parent.height
            background: Rectangle {
                color: "#232f34"
                radius: 6
            }
            contentItem: Text {
                text: parent.text
                color: "#00e6e6"
                font.bold: true
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                content.goNext();
            }
        }
    }

    // Book title — a static label left of the nav. Anchored to pagesRow —
    // NOT inside it — so the centered nav stays put no matter how long the
    // title gets. Switching books is done from the left-gutter switcher, so
    // this is no longer clickable.
    Item {
        id: bookTitleArea
        anchors.left: menuRow.right
        anchors.leftMargin: 20
        anchors.right: pagesRow.left
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        height: 36

        Text {
            id: bookTitleText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, bookTitleArea.width)
            text: (config && config.bookSets && config.bookSets.length > 0
                   && config.bookSets[0].bookTitle) ? config.bookSets[0].bookTitle : ""
            color: "#eef7f8"
            font.pixelSize: 15
            font.bold: true
            font.letterSpacing: 0.3
            elide: Text.ElideRight
        }
    }

    // Module chip — click opens the module editor.
    Rectangle {
        id: moduleChip
        anchors.left: pagesRow.right
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        height: 28
        width: Math.min(moduleLabel.implicitWidth + 26, 220)
        radius: 14
        visible: moduleLabel.text.length > 0
        color: moduleChipArea.containsMouse ? "#1d2c33" : "transparent"
        border.color: moduleChipArea.containsMouse ? "#2a8e96" : "#27535b"
        border.width: 1
        Behavior on color { ColorAnimation { duration: 90 } }
        Text {
            id: moduleLabel
            anchors.centerIn: parent
            width: parent.width - 18
            horizontalAlignment: Text.AlignHCenter
            text: ""
            color: "#00e6e6"
            font.pixelSize: 13
            elide: Text.ElideRight
        }
        MouseArea {
            id: moduleChipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: moduleEditorDialog.open()
        }
    }

    // Refresh the module label when the page (and so the module) changes.
    function setModuleText() {
        moduleLabel.text = content.getModuleName() || "";
    }

    // Clear menu on the far right (opens Clear Page / Clear Book).
    AppButton {
        id: clearQuick
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 12
        text: "Clear"
        variant: "danger"
        onClicked: clearMenu.open()
        AppMenu {
            id: clearMenu
            implicitWidth: 180
            y: parent.height + 4
            x: parent.width - width            // right-aligned, opens leftward
            AppMenuItem { text: "Clear Page"; danger: true; onTriggered: clearPageConfirmDialog.open() }
            AppMenuItem { text: "Clear Book"; danger: true; onTriggered: clearConfirmDialog.open() }
        }
    }


    Dialog {
        id: clearConfirmDialog
        modal: true
        anchors.centerIn: Overlay.overlay
        width: 420
        padding: 20

        background: Rectangle {
            color: "#1A2327"
            border.color: "#d9534f"
            border.width: 1
            radius: 8
        }

        contentItem: Column {
            spacing: 16

            Text {
                width: parent.width
                text: "Clear deletes the sections (fill, audio, video, "
                      + "activities...) on ALL pages of the book. This cannot be "
                      + "undone.\n\nContinue?"
                color: "white"
                font.pixelSize: 14
                wrapMode: Text.WordWrap
            }

            Row {
                anchors.right: parent.right
                spacing: 10

                Button {
                    text: "Cancel"
                    width: 90
                    height: 36
                    background: Rectangle {
                        color: parent.hovered ? "#2A3337" : "#1A2327"
                        border.color: "#445055"
                        border.width: 1
                        radius: 6
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: clearConfirmDialog.close()
                }

                Button {
                    text: "Clear"
                    width: 90
                    height: 36
                    background: Rectangle {
                        color: parent.hovered ? "#d9534f" : "#a94442"
                        radius: 6
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        clearConfirmDialog.close();
                        var n = 0;
                        for (var i = 0; i < root.pages.length; i++) {
                            if (root.pages[i].sections.length > 0) {
                                root.pages[i].sections = [];
                                n++;
                            }
                        }
                        console.log("Clear: removed sections from " + n + " page(s)");
                    }
                }
            }
        }
    }

    // Confirms clearing the sections of the currently shown page only.
    Dialog {
        id: clearPageConfirmDialog
        modal: true
        anchors.centerIn: Overlay.overlay
        width: 420
        padding: 20

        background: Rectangle {
            color: "#1A2327"
            border.color: "#d9534f"
            border.width: 1
            radius: 8
        }

        contentItem: Column {
            spacing: 16

            Text {
                width: parent.width
                text: "Clear deletes the sections on the current page (page "
                      + root.currentPageNumber + ") only. This cannot be undone."
                      + "\n\nContinue?"
                color: "white"
                font.pixelSize: 14
                wrapMode: Text.WordWrap
            }

            Row {
                anchors.right: parent.right
                spacing: 10

                Button {
                    text: "Cancel"
                    width: 90
                    height: 36
                    background: Rectangle {
                        color: parent.hovered ? "#2A3337" : "#1A2327"
                        border.color: "#445055"
                        border.width: 1
                        radius: 6
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: clearPageConfirmDialog.close()
                }

                Button {
                    text: "Clear"
                    width: 90
                    height: 36
                    background: Rectangle {
                        color: parent.hovered ? "#d9534f" : "#a94442"
                        radius: 6
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        clearPageConfirmDialog.close();
                        if (content.pageDetails && content.pageDetails.page) {
                            content.pageDetails.page.sections = [];
                            console.log("Clear page: page " + root.currentPageNumber);
                        }
                    }
                }
            }
        }
    }

    // Keyboard-shortcuts cheat sheet (Help ▸ Keyboard Shortcuts).
    Dialog {
        id: shortcutsDialog
        modal: true
        anchors.centerIn: Overlay.overlay
        width: 580
        height: Math.min(mainwindow.height * 0.82, 760)
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        // Grouped list of every shortcut we wired up.
        property var helpSections: [
            {
                title: "Page editor",
                items: [
                    { k: "A", d: "Add an audio section at the cursor" },
                    { k: "V", d: "Add a video section at the cursor" },
                    { k: "F", d: "Add a fill at the cursor" },
                    { k: "H", d: "Pick the open activity's header text (like its Pick button)" },
                    { k: "C", d: "Crop the open activity, or re-check the open Fill panel's sizes vs the answered PDF" },
                    { k: "R", d: "Toggle the fill-select (rubber-band) tool" },
                    { k: "B", d: "Bold / unbold the selected fills" },
                    { k: "←", d: "Align the selected fills to the leftmost one" },
                    { k: "→", d: "Align the selected fills to the rightmost one" },
                    { k: "↑", d: "Align the selected fills to the top-most one" },
                    { k: "↓", d: "Align the selected fills to the bottom-most one" },
                    { k: "← →", d: "Previous / next page (when nothing is selected)" },
                    { k: "↑ ↓", d: "Jump 10 pages forward / back (when nothing is selected)" },
                    { k: "Space", d: "Open the selected activity, or play / pause audio-video" },
                    { k: "Del", d: "Delete the selected section (also Backspace)" },
                    { k: "Esc", d: "Clear the current selection" },
                    { k: "Ctrl+S", d: "Save" }
                ]
            },
            {
                title: "Add an activity — press A, then:",
                items: [
                    { k: "A F", d: "Fill-picture activity" },
                    { k: "A D", d: "Drag & drop picture" },
                    { k: "A G", d: "Drag & drop picture group" },
                    { k: "A C", d: "Circle activity" },
                    { k: "A M", d: "Match the words" },
                    { k: "A P", d: "Puzzle / find words" },
                    { k: "A X", d: "Mark with X" }
                ]
            },
            {
                title: "Activity editor (while an activity is open)",
                items: [
                    { k: "R", d: "Toggle the select (rubber-band) mode" },
                    { k: "F", d: "Add an answer zone at the cursor" },
                    { k: "←", d: "Align the selected zones to the leftmost one" },
                    { k: "→", d: "Align the selected zones to the rightmost one" },
                    { k: "↑", d: "Align the selected zones to the top-most one" },
                    { k: "↓", d: "Align the selected zones to the bottom-most one" },
                    { k: "Esc", d: "Exit select mode / clear selection / close" }
                ]
            }
        ]

        header: Rectangle {
            color: "#1A2327"
            height: 44
            border.color: "#009ca6"
            border.width: 1
            Label {
                text: "Keyboard Shortcuts"
                color: "white"
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 12
                font.pixelSize: 16
                font.bold: true
            }
        }

        footer: Rectangle {
            color: "#1A2327"
            height: 56
            border.color: "#009ca6"
            border.width: 1
            AppButton {
                text: "Close"
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 100
                height: 34
                onClicked: shortcutsDialog.close()
            }
        }

        background: Rectangle {
            color: "#232f34"
            border.color: "#009ca6"
            border.width: 1
            radius: 4
        }

        contentItem: Flickable {
            id: helpFlick
            clip: true
            contentHeight: helpColumn.implicitHeight + 24
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Column {
                id: helpColumn
                x: 16
                y: 12
                width: helpFlick.width - 32
                spacing: 18

                Repeater {
                    model: shortcutsDialog.helpSections

                    Column {
                        required property var modelData
                        width: helpColumn.width
                        spacing: 6

                        Text {
                            text: parent.modelData.title
                            color: "#4fd2dc"
                            font.pixelSize: 13
                            font.bold: true
                            bottomPadding: 2
                        }

                        Repeater {
                            model: parent.modelData.items

                            Row {
                                required property var modelData
                                width: parent.width
                                spacing: 12

                                Rectangle {
                                    width: 78
                                    height: 26
                                    radius: 6
                                    color: "#11343a"
                                    border.color: "#1c5a63"
                                    border.width: 1
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text {
                                        anchors.centerIn: parent
                                        text: parent.parent.modelData.k
                                        color: "#4fd2dc"
                                        font.pixelSize: 12
                                        font.bold: true
                                    }
                                }

                                Text {
                                    width: parent.width - 78 - 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: parent.modelData.d
                                    color: "#cfe8ea"
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Rectangle {
    //     id: closeBtn
    //     anchors.verticalCenter: parent.verticalCenter
    //     anchors.right: parent.right
    //     anchors.rightMargin: 10
    //     width: 40
    //     height: 40
    //     color: "red"
    //     FlowText {
    //         text: qsTr("X")
    //         color: "white"
    //     }

    //     MouseArea {
    //         anchors.fill: parent
    //         onClicked: {
    //             confirmDialog.open();
    //         }
    //     }
    // }
}
