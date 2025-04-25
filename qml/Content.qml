import QtQuick
import QtQuick.Controls


Rectangle {
    property var pages: config.bookSets[0].books[0].pages
    property bool outlineEnabled
    property var currentPageDetails
    id: root
    height: parent.height
    width: parent.width
    color: "gray"

    SwipeView {
        id: pageView
        height: parent.height
        width: parent.width
        clip:true
        interactive: true
        Repeater {
            id: pagesRepeater
            model: config.bookSets[0].books[0].pages
            PageDetails {
                id: pageDetails
                page: modelData
                outlineEnabled: root.outlineEnabled
            }
        }

        onCurrentIndexChanged: {
            pagesRepeater.itemAt(currentIndex).setDefaultZoom()
            currentPageDetails = pagesRepeater.itemAt(currentIndex)
            toolBar.currentPageNumber = pageView.currentIndex + pages[0].page_number
        }
    }

    function goNext() {
        if (pageView.currentIndex < pagesRepeater.count) {
            sideBar.hideAllComponent()
            pageView.currentIndex++
        }
    }

    function goPrev() {
        if (pageView.currentIndex>0) {
            sideBar.hideAllComponent()
            pageView.currentIndex--
        }
    }

    function goToPage(pageNumber) {
        if (pageNumber < pagesRepeater.count && pageNumber>0) {
            sideBar.hideAllComponent()
            pageView.currentIndex = pageNumber
        }
    }

    function enableRightClick(enabled) {
        currentPageDetails.enableRightClick(enabled)
    }
}

