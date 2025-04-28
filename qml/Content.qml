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
    color: "gray"

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
                active: Math.abs(index - pageView.currentIndex) <= 1 // Sadece aktif ve komşu sayfalar yüklensin
                sourceComponent: pageDetailsComponent
                property var page: pages[index]
                onLoaded: {
                    if (item) {
                        item.page = page;
                        item.outlineEnabled = root.outlineEnabled;
                    }
                }
            }
        }

        Component {
            id: pageDetailsComponent
            // page ve outlineEnabled Loader üzerinden atanıyor
            PageDetails {}
        }

        onCurrentIndexChanged: {
            var loader = pagesRepeater.itemAt(currentIndex);
            if (loader && loader.item) {
                loader.item.setDefaultZoom();
                root.currentPageDetails = loader.item;
            }
            toolBar.currentPageNumber = pageView.currentIndex + pages[0].page_number;
        }
    }

    function goNext() {
        if (pageView.currentIndex < pagesRepeater.count) {
            sideBar.hideAllComponent();
            pageView.currentIndex++;
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
