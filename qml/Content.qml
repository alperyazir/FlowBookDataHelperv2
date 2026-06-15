import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property var pages: (config && config.bookSets && config.bookSets.length > 0
                         && config.bookSets[0].books && config.bookSets[0].books.length > 0)
                        ? config.bookSets[0].books[0].pages : []
    property bool outlineEnabled
    property var currentPageDetails
    property int currentPageIndex: 0
    property alias pageDetails: pageDetails
    height: parent.height
    width: parent.width
    color: "#1A2327" // Dark background

    Rectangle {
        id: pageView
        height: parent.height
        width: parent.width
        clip: true
        color: "#1A2327" // Dark background
        border.color: "#009ca6" // Turquoise border
        border.width: 1

        PageDetails {
            id: pageDetails
            page: pages[root.currentPageIndex]
        }
    }

    onCurrentPageIndexChanged: {
        if (!pages || pages.length === 0) return;
        pageDetails.page = pages[root.currentPageIndex];
        pageDetails.setDefaultZoom();
        toolBar.currentPageNumber = root.currentPageIndex + pages[0].page_number;
        toolBar.setModuleText();
    }

    function goNext() {
        if (root.currentPageIndex < pages.length) {
            sideBar.hideAllComponent();
            root.currentPageIndex++;
        }
    }

    function getModuleName() {
        for (var i = 0; i < config.bookSets[0].books[0].modules.length; i++) {
            for (var j in config.bookSets[0].books[0].modules[i].pages) {
                if (config.bookSets[0].books[0].pages[root.currentPageIndex] === config.bookSets[0].books[0].modules[i].pages[j]) {
                    return config.bookSets[0].books[0].modules[i].name;
                }
            }
        }
    }

    function goPrev() {
        if (root.currentPageIndex > 0) {
            sideBar.hideAllComponent();
            root.currentPageIndex--;
        }
    }

    function goToPage(pageNumber) {
        if (pageNumber <= pages.length && pageNumber >= 0) {
            sideBar.hideAllComponent();
            root.currentPageIndex = pageNumber;
        }
    }

    // Jump to the first page that already has an audio/video section, so the
    // icon-template Crop lands on a media page. Best-effort: returns false if
    // the book has no such section yet (e.g. before the first Analyze).
    // Jump to the first page that has an audio/video FILE, read straight from
    // the book's audio/ or video/ folder (page-encoded names). Robust: works
    // before any Analyze and regardless of the loaded config's sections.
    function goToFirstMediaPage(kind) {
        if (!pages || pages.length === 0) return false;
        var bookDir = config.bookSets[0].bookDirectoryName;
        var pn = pdfProcess.firstMediaPage(bookDir, kind);
        if (pn > 0) {
            var idx = pn - pages[0].page_number;
            if (idx >= 0 && idx < pages.length) {   // file may name an out-of-range page
                goToPage(idx);
                return true;
            }
        }
        return false;
    }

    // Jump `delta` pages (e.g. ±10), clamped to the book bounds.
    function goBy(delta) {
        if (!pages || pages.length === 0) return;
        var ni = root.currentPageIndex + delta;
        if (ni < 0) ni = 0;
        if (ni > pages.length - 1) ni = pages.length - 1;
        if (ni === root.currentPageIndex) return;
        sideBar.hideAllComponent();
        root.currentPageIndex = ni;
    }

    function enableRightClick(enabled) {
        currentPageDetails.enableRightClick(enabled);
    }

    function startCropMode(targetObj, pathProperty) {
        pageDetails.startCropMode(targetObj, pathProperty);
    }

    function startRedetectMode(targetObj) {
        pageDetails.startRedetectMode(targetObj);
    }

    function startHeaderPickMode(targetObj) {
        pageDetails.startHeaderPickMode(targetObj);
    }

    function startIconCrop(kind) {
        pageDetails.startIconCrop(kind);
    }
}
