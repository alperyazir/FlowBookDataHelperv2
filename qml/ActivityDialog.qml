import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "activities"

Dialog {
    property string imageSource
    property string headerText
    property var wordLists: []
    property var answers: []
    property var activityModelData
    id: root
    width: mainwindow.width * 0.92
    height: mainwindow.height * 0.92
    modal: true
    anchors.centerIn: parent
    closePolicy: Popup.NoAutoClose // Prevents dialog from closing when clicking outside
    visible: false

    // Rubber-band ("Select") mode for the answer zones (the 'r' tool).
    property bool selectMode: false
    property var currentActivity: null   // the activity component on screen
    onClosed: selectMode = false

    Shortcut {
        sequence: "r"
        enabled: root.visible
        onActivated: root.selectMode = !root.selectMode
    }

    // 'l' aligns the selected answer zones to the leftmost one.
    Shortcut {
        sequence: "l"
        enabled: root.visible
        onActivated: {
            if (root.currentActivity && root.currentActivity.alignSelectedLeft)
                root.currentActivity.alignSelectedLeft();
        }
    }

    // 'b' aligns the selected answer zones to the bottom-most one.
    Shortcut {
        sequence: "b"
        enabled: root.visible
        onActivated: {
            if (root.currentActivity && root.currentActivity.alignSelectedBottom)
                root.currentActivity.alignSelectedBottom();
        }
    }

    // 'f' adds an answer zone at the cursor (like long-press).
    Shortcut {
        sequence: "f"
        enabled: root.visible
        onActivated: {
            if (root.currentActivity && root.currentActivity.addAnswerAtCursor)
                root.currentActivity.addAnswerAtCursor();
        }
    }

    // Escape: exit select mode -> clear the answer selection -> close.
    Shortcut {
        sequence: "Escape"
        enabled: root.visible
        onActivated: {
            if (root.selectMode) {
                root.selectMode = false;
                return;
            }
            if (root.currentActivity && root.currentActivity.selectedAnswers
                && root.currentActivity.selectedAnswers.length > 0) {
                root.currentActivity.clearAnsSelection();
                return;
            }
            root.close();
            sideBar.hideAllComponent();
        }
    }


    // Custom header
    header: Rectangle {
        color: "#1A2327"
        height: 40
        border.color: "#009ca6"
        border.width: 1
        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            spacing: 10
            Label {
                text: "Activity"
                color: "white"
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 16
                font.bold: true
            }
            // The activity type, shown as a pill next to the title.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: typeBadge.text.length > 0
                width: typeBadge.implicitWidth + 18
                height: 22
                radius: 11
                color: "#11343a"
                border.color: "#1c5a63"
                border.width: 1
                Text {
                    id: typeBadge
                    anchors.centerIn: parent
                    text: (root.activityModelData && root.activityModelData.type) || ""
                    color: "#4fd2dc"
                    font.pixelSize: 12
                    font.bold: true
                }
            }
        }
    }

    // Custom footer for buttons
    footer: Rectangle {
        color: "#1A2327"
        height: 60
        border.color: "#009ca6"
        border.width: 1
        RowLayout {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 10
            spacing: 10
            Button {
                text: "Cancel"
                Layout.preferredWidth: 80
                Layout.preferredHeight: 32
                background: Rectangle {
                    color: parent.hovered ? "#2A3337" : "#1A2327"
                    border.color: "#009ca6"
                    border.width: 1
                    radius: 2
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: root.reject()
            }
            // Button {
            //     text: "Answers"
            //     Layout.preferredWidth: 80
            //     Layout.preferredHeight: 32
            //     background: Rectangle {
            //         color: parent.hovered ? "#2A3337" : "#1A2327"
            //         border.color: "#009ca6"
            //         border.width: 1
            //         radius: 2
            //     }
            //     contentItem: Text {
            //         text: parent.text
            //         color: "white"
            //         horizontalAlignment: Text.AlignHCenter
            //         verticalAlignment: Text.AlignVCenter
            //     }
            //     onClicked: root.accept()
            // }
        }
    }

    background: Rectangle {
        color: "#232f34"
        border.color: "#009ca6"
        border.width: 1
    }

    Rectangle {
        id: mainContainer
        anchors.fill: parent
    }

    function createActivityMatchTheWord() {
        clearMainContainer()
        var component = Qt.createComponent("activities/ActivityMatchTheWords.qml")

        var activityMatch = component.createObject(mainContainer, {});
        activityMatch.headerText = root.activityModelData.headerText
        activityMatch.shuffledWords= root.activityModelData.matchWord
        activityMatch.sentences = root.activityModelData.sentences
        // content.enableRightClick(false)

        // activityMatch.onVisibleChanged.connect(function(visible) {
        //     if(!visible) {
        //         content.enableRightClick(true)
        //     }
        // })
    }

    function createActivityDragDropPicture() {
        clearMainContainer()
        var component = Qt.createComponent("activities/ActivityDragDropPicture.qml")
        var activityDragDropPicture = component.createObject(mainContainer, {});
        activityDragDropPicture.headerText = root.activityModelData.headerText
        activityDragDropPicture.shuffledWords= root.activityModelData.words
        activityDragDropPicture.imageSource = "file:" + appPath + root.activityModelData.sectionPath
        activityDragDropPicture.answers = root.activityModelData.answers
        activityDragDropPicture.activityModelData = root.activityModelData
        root.currentActivity = activityDragDropPicture
        // content.enableRightClick(false)
        // activityDragDropPicture.onVisibleChanged.connect(function(visible) {
        //     if(!visible) {
        //         content.enableRightClick(true)
        //     }
        // })

    }

    function createActivityDragDropPictureGroup() {
        clearMainContainer()
        var component = Qt.createComponent("activities/ActivityDragDropPictureGroup.qml")

        var activityDragDropPictureGroup = component.createObject(mainContainer, {});
        activityDragDropPictureGroup.headerText = root.activityModelData.headerText
        activityDragDropPictureGroup.shuffledWords= root.activityModelData.words
        activityDragDropPictureGroup.imageSource = "file:" + appPath + root.activityModelData.sectionPath
        activityDragDropPictureGroup.answers = root.activityModelData.answers
        activityDragDropPictureGroup.activityModelData = root.activityModelData
        root.currentActivity = activityDragDropPictureGroup
        // content.enableRightClick(false)

        // activityDragDropPictureGroup.onVisibleChanged.connect(function(visible) {
        //     if(!visible) {
        //         content.enableRightClick(true)
        //     }
        // })
    }

    function createActivityFillPicture() {
        clearMainContainer()
        var component = Qt.createComponent("activities/ActivityFillPicture.qml")
        var activityDragDropPicture = component.createObject(mainContainer, {});
        activityDragDropPicture.headerText = root.activityModelData.headerText
        activityDragDropPicture.shuffledWords= root.activityModelData.words
        activityDragDropPicture.imageSource = "file:" + appPath + root.activityModelData.sectionPath
        activityDragDropPicture.answers = root.activityModelData.answers
        activityDragDropPicture.activityModelData = root.activityModelData
        root.currentActivity = activityDragDropPicture
        //content.enableRightClick(false)
        // activityDragDropPicture.onVisibleChanged.connect(function(visible) {
        //     if(!visible) {
        //         content.enableRightClick(true)
        //     }
        // })

    }

    function createActivityFindPuzzle() {
        clearMainContainer()
        var component = Qt.createComponent("activities/ActivityFindPuzzle.qml")
        var activityPuzzleWords = component.createObject(mainContainer, {});
        activityPuzzleWords.headerText = root.activityModelData.headerText
        activityPuzzleWords.secretWords= root.activityModelData.words
        activityPuzzleWords.setWords(root.activityModelData.words)
        //content.enableRightClick(false)
        // activityPuzzleWords.onVisibleChanged.connect(function(visible) {
        //     if(!visible) {
        //         //content.enableRightClick(true)
        //     }
        // })

    }

    function createActivityCircle() {
        clearMainContainer()
        var component = Qt.createComponent("activities/ActivityCircle.qml")
        var activityCircle = component.createObject(mainContainer, {});
        activityCircle.headerText = root.activityModelData.headerText
        activityCircle.imageSource = "file:" + appPath + root.activityModelData.sectionPath
        activityCircle.answers = root.activityModelData.answers
        activityCircle.activityModelData = root.activityModelData
        root.currentActivity = activityCircle
        //content.enableRightClick(false)
        // activityCircle.onVisibleChanged.connect(function(visible) {
        //     if(!visible) {
        //         content.enableRightClick(true)
        //     }
        // })
    }

    function createActivityMarkWithX() {
        clearMainContainer()
        var component = Qt.createComponent("activities/ActivityMarkWithX.qml")
        var activityMarkWithX= component.createObject(mainContainer, {});
        activityMarkWithX.headerText = root.activityModelData.headerText
        activityMarkWithX.imageSource = "file:" + appPath + root.activityModelData.sectionPath
        activityMarkWithX.answers = root.activityModelData.answers
        activityMarkWithX.activityModelData = root.activityModelData
        root.currentActivity = activityMarkWithX
        // content.enableRightClick(false)
        // activityMarkWithX.onVisibleChanged.connect(function(visible) {
        //     if(!visible) {
        //         content.enableRightClick(true)
        //     }
        // })

    }


    function clearMainContainer() {
        root.currentActivity = null;
        for (var i = mainContainer.children.length - 1; i >= 0; i--) {
            var child = mainContainer.children[i];
            if (child !== undefined && child !== null) {
                child.destroy();
            }
        }
    }



}
