import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    property var pages: config.bookSets[0].books[0].pages
    property int currentPageNumber: 0
    signal outlineEnabled(bool enabled)
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: 50
    color: "gray"
    border.color: "black"
    border.width: 1

    Row {
        width: parent.width / 3
        height: parent.height
        Button {
            anchors.verticalCenter: parent.verticalCenter
            text: "Create"
            width: 70
            height: 40
            onClicked: {
                console.log("Create clicked");
                newProjectDialog.open();

            }
        }

        Button {
            anchors.verticalCenter: parent.verticalCenter
            text: "Open"
            width: 70
            height: 40
            onClicked: {
                // config.refresh();
                // toast.show("Config Reloaded");

                config.refreshRecentProjects()
                openProject.loadRecentProjects();
                openProject.open()
            }
        }
        CheckBox {
            id: checkOutline
            checked: true
            onCheckedChanged: root.outlineEnabled(checked)
            text: "Outline"
            anchors.verticalCenter: parent.verticalCenter
            height: 40
        }
    }

    Row {
        height: parent.height
        anchors.horizontalCenter: parent.horizontalCenter
        Button {
            anchors.verticalCenter: parent.verticalCenter
            text: "<"
            width: 70
            height: 50
            onClicked: {
                content.goPrev();
            }
        }

        TextField {
            id: pageNumberInput
            property int firstPage: pages[0].page_number
            property int lastPage: pages[pages.length - 1].page_number
            width: 70
            height: 50
            placeholderText: "Page"
            validator: IntValidator {
                bottom: pageNumberInput.firstPage
                top: pageNumberInput.lastPage
            }
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
            width: 70
            height: 50
            onClicked: {
                content.goNext();
            }
        }
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 10
        width: 40
        height: 40
        color: "red"
        FlowText {
            text: qsTr("X")
            color: "white"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                confirmDialog.open();
            }
        }
    }
}
