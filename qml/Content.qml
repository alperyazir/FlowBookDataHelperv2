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
    // Re-evaluated whenever the book reloads (e.g. after Analyze): does this
    // book have any page the analysis flagged for review?
    property bool anyReview: (pages && pages.length > 0) ? hasAnyReviewPage() : false
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

    // Jump to the next page the analysis flagged for review (wraps around).
    // Returns false when the book has nothing flagged.
    function goToNextReviewPage() {
        if (!pages || pages.length === 0) return false;
        for (var k = 1; k <= pages.length; k++) {
            var i = (root.currentPageIndex + k) % pages.length;
            if (pages[i] && pages[i].needsReview) {
                sideBar.hideAllComponent();
                root.currentPageIndex = i;
                return true;
            }
        }
        return false;
    }

    function hasAnyReviewPage() {
        if (!pages) return false;
        for (var i = 0; i < pages.length; i++)
            if (pages[i] && pages[i].needsReview) return true;
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

    // --- Activity-to-activity navigation (the dialog's ‹ › arrows) -----------
    // Only the types the dialog can actually show; coloring and ordering are
    // authored on the page, so stepping onto one would open an empty dialog.
    function dialogActivity(sec) {
        var a = sec ? sec.activity : null;
        return (a && a.type !== "" && a.type !== "coloring" && a.type !== "ordering")
                ? a : null;
    }

    // Every activity in the book, in page order then reading order.
    function activityList() {
        var out = [];
        if (!pages) return out;
        for (var p = 0; p < pages.length; p++) {
            var secs = pages[p] ? pages[p].sections : null;
            if (!secs) continue;
            for (var s = 0; s < secs.length; s++)
                if (dialogActivity(secs[s]))
                    out.push({ pageIndex: p, sectionIndex: s });
        }
        return out;
    }

    function activityCount() {
        return activityList().length;
    }

    // Put a page on screen and open one of its activities in the sidebar —
    // the same state clicking that activity's button on the page produces.
    function selectActivity(pageIndex, sectionIndex) {
        if (!pages || pageIndex < 0 || pageIndex >= pages.length) return null;
        var pg = pages[pageIndex];
        var sec = (pg && pg.sections) ? pg.sections[sectionIndex] : null;
        var act = dialogActivity(sec);
        if (!act) return null;
        if (pageIndex !== root.currentPageIndex)
            root.currentPageIndex = pageIndex;      // turns the page underneath
        sideBar.hideAllComponent();
        sideBar.activityVisible = true;
        sideBar.page = pg;
        sideBar.sectionIndex = sectionIndex;
        sideBar.activityModelData = act;
        sideBar.sectionModelData = sec;
        return act;
    }

    // Step `delta` activities from the one open in the sidebar. Wraps at the
    // ends of the book so the arrows never dead-end. Returns the activity.
    function stepActivity(delta) {
        var list = activityList();
        if (list.length === 0) return null;
        var cur = -1;
        for (var i = 0; i < list.length; i++) {
            if (list[i].pageIndex === root.currentPageIndex
                    && list[i].sectionIndex === sideBar.sectionIndex) {
                cur = i;
                break;
            }
        }
        var ni = (cur < 0) ? 0 : (cur + delta + list.length) % list.length;
        return selectActivity(list[ni].pageIndex, list[ni].sectionIndex);
    }

    function enableRightClick(enabled) {
        currentPageDetails.enableRightClick(enabled);
    }

    function startCropMode(targetObj, pathProperty) {
        pageDetails.startCropMode(targetObj, pathProperty);
    }

    function startMatchColumnCrop(targetObj, side) {
        pageDetails.startMatchColumnCrop(targetObj, side);
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
