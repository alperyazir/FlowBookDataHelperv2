import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property var pages: config.bookSets[0].books[0].pages
    property bool outlineEnabled
    property var currentPageDetails
    height: parent.height
    width: parent.width
    color: "#1A2327" // Dark background

    SwipeView {
        id: pageView
        height: parent.height
        width: parent.width
        clip: true
        interactive: true

        Repeater {
            id: pagesRepeater
            model: pages.length

            Loader {
                id: pageLoader
                active: Math.abs(index - pageView.currentIndex) <= 1
                sourceComponent: pageDetailsComponent
                property var page: pages[index]
                onLoaded: {
                    if (item) {
                        item.page = page;
                    }
                }
            }
        }

        Component {
            id: pageDetailsComponent
            PageDetails {}
        }

        onCurrentIndexChanged: {
            var loader = pagesRepeater.itemAt(currentIndex);
            if (loader && loader.item) {
                loader.item.setDefaultZoom();
                root.currentPageDetails = loader.item;
            }
            toolBar.currentPageNumber = pageView.currentIndex + pages[0].page_number;
            toolBar.setModuleText();
        }
    }

    function goNext() {
        if (pageView.currentIndex < pagesRepeater.count) {
            sideBar.hideAllComponent();
            pageView.currentIndex++;
        }
    }

    function getModuleName() {
        for (var i = 0; i < config.bookSets[0].books[0].modules.length; i++) {
            for (var j in config.bookSets[0].books[0].modules[i].pages) {
                if (config.bookSets[0].books[0].pages[pageView.currentIndex] === config.bookSets[0].books[0].modules[i].pages[j]) {
                    return config.bookSets[0].books[0].modules[i].name;
                }
            }
        }
    }

    function goPrev() {
        if (pageView.currentIndex > 0) {
            sideBar.hideAllComponent();
            pageView.currentIndex--;
        }
    }

    function goToPage(pageNumber) {
        if (pageNumber < pagesRepeater.count && pageNumber > 0) {
            sideBar.hideAllComponent();
            pageView.currentIndex = pageNumber;
        }
    }

    function enableRightClick(enabled) {
        currentPageDetails.enableRightClick(enabled);
    }
}
