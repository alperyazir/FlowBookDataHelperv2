import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property var pages: config.bookSets[0].books[0].pages
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

    function enableRightClick(enabled) {
        currentPageDetails.enableRightClick(enabled);
    }

    function startCropMode(targetObj, pathProperty) {
        pageDetails.startCropMode(targetObj, pathProperty);
    }
}
