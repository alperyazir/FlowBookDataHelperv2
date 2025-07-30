import QtQuick
import QtQuick.Controls
import QtQuick.Shapes

import "newComponents"

Item {
    id: root
    property real imageHeights: (mainwindow.height * 30 / 1080) * (flick.contentWidth / flick.width)
    property var page
    property string currentSelectionType: ""
    property size lastSize: Qt.size(100, 50)

    property bool fillingModeEnabled: false
    property var activeFillRectangle
    property var fillList: []
    property var newSection
    property var activeSession
    property real startRectX: 0
    property real startRectY: 0
    anchors.fill: parent

    MouseArea {
        id: mainMouseArea
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton | Qt.RightButton | Qt.LeftButton
        scrollGestureEnabled: true
        hoverEnabled: true

        property bool dragging: false
        property bool drawing: false
        property real lastX: 0
        property real lastY: 0

        onPressed: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                dragging = true;
                lastX = mouse.x;
                lastY = mouse.y;
                //flick.interactive = true; // Enable Flickable interaction
            } else if (mouse.button === Qt.RightButton) {
                menu.popup(mouse.x, mouse.y);
            } else if ((mouse.button === Qt.LeftButton) && root.fillingModeEnabled)
            // drawing = true
            // var component = Qt.createComponent("newComponents/NewRectangle.qml")
            // root.activeFillRectangle = component.createObject(root, {
            //                                                       "x": mouseArea.mouseX,
            //                                                       "y": mouseArea.mouseY})
            {}
        }

        onReleased: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                dragging = false;
                //flick.interactive = false; // Disable Flickable interaction
            } else if (mouse.button === Qt.LeftButton && root.fillingModeEnabled)
            // fillList.push(activeFillRectangle)
            // sideBar.page = root.page
            // sideBar.fillVisible = true
            // sideBar.fillList = root.fillList

            // var adjustedX = mouseArea.mouseX + flick.contentX
            // var adjustedY = mouseArea.mouseY + flick.contentY

            // // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
            // var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth)
            // var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight)

            // config.bookSets[0].saveToJson();
            // activeFillRectangle.visible = false
            // drawing = false
            {}
        }

        onPositionChanged: mouse => {
            if (dragging) {
                var dx = mouse.x - lastX;
                var dy = mouse.y - lastY;
                flick.contentX -= dx;
                flick.contentY -= dy;
                lastX = mouse.x;
                lastY = mouse.y;
            }
        }

        onWheel: event => {
            // if (event.angleDelta.y > 0) {
            //     flick.zoomIn();
            // } else {
            //     flick.zoomOut();
            // }
            event.accepted = true;
        }

        onPressAndHold: mouse => {
            var adjustedX = mainMouseArea.mouseX - (flick.contentWidth / 2 - picture.paintedWidth / 2);
            var adjustedY = mainMouseArea.mouseY - (flick.contentHeight / 2 - picture.paintedHeight / 2);

            // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
            var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
            var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);
            var answer;
            if (currentSelectionType === "fill") {
                root.activeSession = root.page.getAvailableSection("fill");
                answer = root.activeSession.createNewAnswer(originalX, originalY, root.lastSize.width, root.lastSize.height);
            } else if (currentSelectionType === "circle") {
                root.activeSession = root.page.getAvailableSection("circle");
                answer = root.activeSession.createNewAnswer(originalX, originalY, root.lastSize.width, root.lastSize.height);
            } else if (currentSelectionType === "fillWithColor") {
                root.activeSession = root.page.getAvailableSection("fillWithColor");
                answer = root.activeSession.createNewAnswer(originalX, originalY, root.lastSize.width, root.lastSize.height);
            } else if (currentSelectionType === "drawMatchedLine") {
                root.activeSession = root.page.getAvailableSection("drawMatchedLine");
                answer = root.activeSession.createNewAnswerDrawMacthedLine(originalX, originalY, root.lastSize.width, root.lastSize.height);
            }

            // if(root.activeSession.answers.length>1) {
            //     lastWidth = root.activeSession.answers[root.activeSession.answers.length -2].width
            //     lastHeight = root.activeSession.answers[root.activeSession.answers.length -2].height
            // }

            if (currentSelectionType === "fill") {
                sideBar.hideAllComponent();
                sideBar.fillVisible = true;
                sideBar.page = page;
                sideBar.section = activeSession;
                sideBar.fillList = activeSession.answers;
            } else if (currentSelectionType === "circle") {
                sideBar.hideAllComponent();
                sideBar.circleVisible = true;
                sideBar.page = page;
                sideBar.section = activeSession;
                sideBar.circleList = activeSession.answers;
            } else if (currentSelectionType === "fillWithColor") {
                sideBar.hideAllComponent();
                sideBar.fillwColorVisible = true;
                sideBar.page = page;
                sideBar.section = activeSession;
                sideBar.fillWColorList = activeSession.answers;
            } else if (currentSelectionType === "drawMatchedLine") {
                sideBar.hideAllComponent();
                sideBar.drawMatchedVisible = true;
                sideBar.page = page;
                sideBar.section = activeSession;
                sideBar.drawMatchedLineList = activeSession.answers;
            }

            config.bookSets[0].saveToJson();
            print("Changes Are Saved activity Fill on Triggered");
        }

        Menu {
            id: menu
            MenuItem {
                text: "Audio"
                onTriggered: {
                    var adjustedX = mainMouseArea.mouseX - (flick.contentWidth / 2 - picture.paintedWidth / 2);
                    var adjustedY = mainMouseArea.mouseY - (flick.contentHeight / 2 - picture.paintedHeight / 2);

                    // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                    var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                    var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                    root.page.createNewAudioSection(originalX, originalY, root.imageHeights, root.imageHeights, "Enter the audio path");
                    config.bookSets[0].saveToJson();
                    print("Changes Are Saved activity Audio on Triggered");
                    currentSelectionType = "";
                }
            }
            MenuItem {
                text: "Video"
                onTriggered: {
                    var adjustedX = mainMouseArea.mouseX - (flick.contentWidth / 2 - picture.paintedWidth / 2);
                    var adjustedY = mainMouseArea.mouseY - (flick.contentHeight / 2 - picture.paintedHeight / 2);

                    // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                    var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                    var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                    root.page.createNewVideoSection(originalX, originalY, root.imageHeights, root.imageHeights, "Enter the video path");
                    config.bookSets[0].saveToJson();
                    print("Changes Are Saved activity Video on Triggered");
                    currentSelectionType = "";
                }
            }
            MenuItem {
                text: "Fill"
                highlighted: currentSelectionType == "fill"
                onTriggered: {
                    root.fillingModeEnabled = true;
                    currentSelectionType = "fill";

                    var adjustedX = mainMouseArea.mouseX - (flick.contentWidth / 2 - picture.paintedWidth / 2);
                    var adjustedY = mainMouseArea.mouseY - (flick.contentHeight / 2 - picture.paintedHeight / 2);

                    // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                    var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                    var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                    root.activeSession = root.page.getAvailableSection("fill");

                    // if(root.activeSession.answers.length>1) {
                    //     lastWidth = root.activeSession.answers[root.activeSession.answers.length -2].width
                    //     lastHeight = root.activeSession.answers[root.activeSession.answers.length -2].height
                    // }
                    var answer = root.activeSession.createNewAnswer(originalX, originalY, root.lastSize.width, root.lastSize.height);

                    sideBar.hideAllComponent();
                    sideBar.fillVisible = true;
                    sideBar.page = page;
                    sideBar.section = activeSession;
                    sideBar.fillList = activeSession.answers;

                    config.bookSets[0].saveToJson();
                    print("Changes Are Saved activity Fill on Triggered");
                }
            }
            MenuItem {
                text: "Circle"
                highlighted: currentSelectionType === "circle"
                onTriggered: {
                    currentSelectionType = "circle";

                    var adjustedX = mainMouseArea.mouseX - (flick.contentWidth / 2 - picture.paintedWidth / 2);
                    var adjustedY = mainMouseArea.mouseY - (flick.contentHeight / 2 - picture.paintedHeight / 2);

                    // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                    var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                    var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                    root.activeSession = root.page.getAvailableSection("circle");

                    // if(root.activeSession.answers.length>1) {
                    //     lastWidth = root.activeSession.answers[root.activeSession.answers.length -2].width
                    //     lastHeight = root.activeSession.answers[root.activeSession.answers.length -2].height
                    // }
                    var answer = root.activeSession.createNewAnswer(originalX, originalY, root.lastSize.width, root.lastSize.height);

                    sideBar.hideAllComponent();
                    sideBar.circleVisible = true;
                    sideBar.page = page;
                    sideBar.section = activeSession;
                    sideBar.circleList = activeSession.answers;

                    config.bookSets[0].saveToJson();
                    print("Changes Are Saved activity Circle on Triggered");
                }
            }
            MenuItem {
                text: "Fill with Color"
                highlighted: currentSelectionType === "fillWithColor"
                onTriggered: {
                    currentSelectionType = "fillWithColor";

                    var adjustedX = mainMouseArea.mouseX - (flick.contentWidth / 2 - picture.paintedWidth / 2);
                    var adjustedY = mainMouseArea.mouseY - (flick.contentHeight / 2 - picture.paintedHeight / 2);

                    // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                    var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                    var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                    root.activeSession = root.page.getAvailableSection("fillWithColor");

                    // if(root.activeSession.answers.length>1) {
                    //     lastWidth = root.activeSession.answers[root.activeSession.answers.length -2].width
                    //     lastHeight = root.activeSession.answers[root.activeSession.answers.length -2].height
                    // }
                    var answer = root.activeSession.createNewAnswer(originalX, originalY, root.lastSize.width, root.lastSize.height);

                    sideBar.hideAllComponent();
                    sideBar.fillwColorVisible = true;
                    sideBar.page = page;
                    sideBar.section = activeSession;
                    sideBar.fillWColorList = activeSession.answers;

                    config.bookSets[0].saveToJson();
                    print("Changes Are Saved activity Circle on Triggered");
                }
            }
            MenuItem {
                text: "Draw Matched Line"
                highlighted: currentSelectionType === "drawMatchedLine"
                onTriggered: {
                    currentSelectionType = "drawMatchedLine";
                    var adjustedX = mainMouseArea.mouseX - (flick.contentWidth / 2 - picture.paintedWidth / 2);
                    var adjustedY = mainMouseArea.mouseY - (flick.contentHeight / 2 - picture.paintedHeight / 2);

                    // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                    var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                    var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                    root.activeSession = root.page.getAvailableSection("drawMatchedLine");
                    print(root.activeSession);

                    // if(root.activeSession.answers.length>1) {
                    //     lastWidth = root.activeSession.answers[root.activeSession.answers.length -2].width
                    //     lastHeight = root.activeSession.answers[root.activeSession.answers.length -2].height
                    // }
                    var answer = root.activeSession.createNewAnswerDrawMacthedLine(originalX, originalY, root.lastSize.width, root.lastSize.height);

                    sideBar.hideAllComponent();
                    sideBar.drawMatchedVisible = true;
                    sideBar.page = page;
                    sideBar.section = activeSession;
                    sideBar.drawMatchedLineList = activeSession.answers;

                    config.bookSets[0].saveToJson();
                    print("Changes Are Saved activity Circle on Triggered");
                }
            }

            Menu {
                id: activityMenu
                title: "Activity"
                MenuItem {
                    text: "Drag Drop Picture"
                    onTriggered: {
                        var adjustedX = mainMouseArea.mouseX - (flick.contentWidth / 2 - picture.paintedWidth / 2);
                        var adjustedY = mainMouseArea.mouseY - (flick.contentHeight / 2 - picture.paintedHeight / 2);

                        // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                        root.page.createNewActivity(originalX, originalY, root.imageHeights, root.imageHeights, "dragdroppicture");
                        config.bookSets[0].saveToJson();
                        print("Changes Are Saved activity Drag Drop on Triggered");
                        currentSelectionType = "";
                    }
                }
                MenuItem {
                    text: "Drag Drop Picture Group"
                    onTriggered: {
                        var adjustedX = mainMouseArea.mouseX + flick.contentX;
                        var adjustedY = mainMouseArea.mouseY + flick.contentY;

                        // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                        root.page.createNewActivity(originalX, originalY, root.imageHeights, root.imageHeights, "dragdroppicturegroup");
                        config.bookSets[0].saveToJson();
                        print("Changes Are Saved activity Drag Drop Picture Group on Triggered");
                        currentSelectionType = "";
                    }
                }
                MenuItem {
                    text: "Fill Picture"
                    onTriggered: {
                        var adjustedX = mainMouseArea.mouseX + flick.contentX;
                        var adjustedY = mainMouseArea.mouseY + flick.contentY;

                        // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                        root.page.createNewActivity(originalX, originalY, root.imageHeights, root.imageHeights, "fillpicture");
                        config.bookSets[0].saveToJson();
                        print("Changes Are Saved activity Fill Picture on Triggered");
                        currentSelectionType = "";
                    }
                }
                MenuItem {
                    text: "Circle"
                    onTriggered: {
                        var adjustedX = mainMouseArea.mouseX + flick.contentX;
                        var adjustedY = mainMouseArea.mouseY + flick.contentY;

                        // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                        root.page.createNewActivity(originalX, originalY, root.imageHeights, root.imageHeights, "circle");
                        config.bookSets[0].saveToJson();
                        print("Changes Are Saved Circle on Triggered");
                        currentSelectionType = "";
                    }
                }

                MenuItem {
                    text: "Match"
                    onTriggered: {
                        var adjustedX = mainMouseArea.mouseX + flick.contentX;
                        var adjustedY = mainMouseArea.mouseY + flick.contentY;

                        // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                        root.page.createNewActivity(originalX, originalY, root.imageHeights, root.imageHeights, "matchTheWords");
                        config.bookSets[0].saveToJson();
                        print("Changes Are Saved MenuItem onmatchTheWords Triggered");
                    }
                }

                MenuItem {
                    text: "Puzzle Find Words"
                    onTriggered: {
                        var adjustedX = mainMouseArea.mouseX + flick.contentX;
                        var adjustedY = mainMouseArea.mouseY + flick.contentY;

                        // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                        root.page.createNewActivity(originalX, originalY, root.imageHeights, root.imageHeights, "puzzleFindWords");
                        config.bookSets[0].saveToJson();
                        print("Changes Are Saved MenuItem Puzzle Find Words Triggered");
                        currentSelectionType = "";
                    }
                }

                MenuItem {
                    text: "Mark With X"
                    onTriggered: {
                        var adjustedX = mainMouseArea.mouseX + flick.contentX;
                        var adjustedY = mainMouseArea.mouseY + flick.contentY;

                        // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                        root.page.createNewActivity(originalX, originalY, root.imageHeights, root.imageHeights, "markwithx");
                        config.bookSets[0].saveToJson();
                        print("Changes Are Saved MenuItem Mark With X Triggered");
                        currentSelectionType = "";
                    }
                }
            }
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: parent.height
        contentWidth: parent.width
        interactive: true
        clip: true
        boundsMovement: Flickable.StopAtBounds

        property real lastContentHeight
        property real lastContentWidth

        property real minZoom: 1.0
        property real maxZoom: 4.0
        property real zoomLevel: 1
        property real zoomStep: 0.1
        property real pinchCenter: 1

        PinchArea {
            id: pinch
            width: Math.max(flick.contentWidth, flick.width)
            height: Math.max(flick.contentHeight, flick.height)

            property real initialWidth
            property real initialHeight

            onPinchStarted: {
                initialWidth = flick.contentWidth;
                initialHeight = flick.contentHeight;
            }

            onPinchUpdated: {
                var newWidth = initialWidth * pinch.scale;
                var newHeight = initialHeight * pinch.scale;

                if (newWidth < flick.width || newHeight < flick.height) {
                    flick.resizeContent(flick.width, flick.height, Qt.point(flick.width / 2, flick.height / 2));
                } else {
                    flick.contentX += pinch.previousCenter.x - pinch.center.x;
                    flick.contentY += pinch.previousCenter.y - pinch.center.y;
                    flick.resizeContent(initialWidth * pinch.scale, initialHeight * pinch.scale, pinch.center);
                }
            }

            onPinchFinished: {
                flick.returnToBounds();
            }
        }

        Image {
            id: picture
            source: qsTr("file:" + appPath + page.image_path)
            fillMode: Image.PreserveAspectFit
            width: Math.max(flick.contentWidth, flick.width)
            height: Math.max(flick.contentHeight, flick.height)

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                propagateComposedEvents: true
                pressAndHoldInterval: 500

                onWheel: function (wheel) {
                    if (wheel.angleDelta.y / 120 * flick.contentWidth * 0.1 + flick.contentWidth > flick.width && wheel.angleDelta.y / 120 * flick.contentHeight * 0.1 + flick.contentHeight > flick.height) {
                        flick.resizeContent(wheel.angleDelta.y / 120 * flick.contentWidth * 0.1 + flick.contentWidth, wheel.angleDelta.y / 120 * flick.contentHeight * 0.1 + flick.contentHeight, Qt.point(flick.contentX + flick.width / 2, flick.contentY + flick.height / 2));
                        flick.returnToBounds();
                    } else {
                        flick.resizeContent(flick.width, flick.height, Qt.point(flick.width / 2, flick.height / 2));
                        flick.returnToBounds();
                    }
                }
            }
            Repeater {
                id: sections
                model: page.sections
                Item {
                    id: sectionItem
                    property var currentSection: modelData
                    property var sectionData: modelData
                    property var sectionType: modelData.type
                    property int sectionIndex: index
                    property var sectionAnswers: modelData.answers
                    property var circleIsCorrectArr: []
                    // audio
                    Rectangle {
                        id: sectionRect
                        color: "transparent"
                        visible: modelData.type === "audio" ? true : false
                        x: (flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.coords.x * (picture.paintedWidth / picture.sourceSize.width)
                        y: (flick.contentHeight / 2 - picture.paintedHeight / 2) + modelData.coords.y * (picture.paintedHeight / picture.sourceSize.height)
                        width: modelData.coords.width * (picture.paintedWidth / picture.sourceSize.width)
                        height: modelData.coords.height * (picture.paintedHeight / picture.sourceSize.height)
                        Image {
                            id: audioImage
                            source: "qrc:/icons/sound.svg"
                            height: parent.height > 0 ? root.imageHeights : 0
                            width: height
                            smooth: true
                            antialiasing: true
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            anchors.fill: parent
                            drag.target: parent
                            onPressed: {
                                sideBar.hideAllComponent();
                                sideBar.audioVisible = true;
                                sideBar.page = page;
                                sideBar.sectionIndex = index;
                                sideBar.audioModelData = modelData;
                            }

                            onReleased: {
                                var adjustedX = (sectionRect.x - (flick.contentWidth / 2 - picture.paintedWidth / 2));
                                var adjustedY = (sectionRect.y - (flick.contentHeight / 2 - picture.paintedHeight / 2));

                                // Zoom seviyesini ve PaintedWidth/PaintedHeight'i hesaba katarak orijinal koordinatları bul
                                var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                                var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                                modelData.coords = Qt.rect(originalX, originalY, modelData.coords.width, modelData.coords.height);
                                config.bookSets[0].saveToJson();
                                print("Changes Are Saved Page Detail Audio On Released Triggered");
                            }
                        }
                    }
                    //video
                    Rectangle {
                        id: videoRect
                        color: "transparent"
                        visible: modelData.type === "video" ? true : false
                        x: (flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.coords.x * (picture.paintedWidth / picture.sourceSize.width)
                        y: (flick.contentHeight / 2 - picture.paintedHeight / 2) + modelData.coords.y * (picture.paintedHeight / picture.sourceSize.height)
                        width: modelData.coords.width * (picture.paintedWidth / picture.sourceSize.width)
                        height: modelData.coords.height * (picture.paintedHeight / picture.sourceSize.height)
                        Image {
                            id: videoImg
                            source: "qrc:/icons/video.svg"
                            //fillMode: Image.PreserveAspectFit
                            height: parent.height > 0 ? root.imageHeights : 0
                            width: height
                            smooth: true
                            antialiasing: true
                            anchors.centerIn: parent
                            //mipmap: true
                        }

                        MouseArea {
                            anchors.fill: parent
                            drag.target: parent
                            onPressed: {
                                sideBar.hideAllComponent();
                                sideBar.videoVisible = true;
                                sideBar.page = page;
                                sideBar.sectionIndex = index;
                                sideBar.videoModelData = modelData;
                            }
                            onReleased: {
                                var adjustedX = (videoRect.x - (flick.contentWidth / 2 - picture.paintedWidth / 2));
                                var adjustedY = (videoRect.y - (flick.contentHeight / 2 - picture.paintedHeight / 2));

                                // Zoom seviyesini ve PaintedWidth/PaintedHeight'i hesaba katarak orijinal koordinatları bul
                                var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                                var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                                modelData.coords = Qt.rect(originalX, originalY, modelData.coords.width, modelData.coords.height);
                                config.bookSets[0].saveToJson();
                                print("Changes Are Saved Page Detail vide On Released Triggered");
                            }
                        }
                    }
                    // fill
                    Repeater {
                        id: answersFillRepeater
                        model: modelData.answers
                        Item {
                            id: answerRect
                            property real originalWidth: modelData.coords.width
                            property real originalHeight: modelData.coords.height
                            x: (flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.coords.x * (picture.paintedWidth / picture.sourceSize.width)
                            y: (flick.contentHeight / 2 - picture.paintedHeight / 2) + modelData.coords.y * (picture.paintedHeight / picture.sourceSize.height)
                            width: originalWidth * (picture.paintedWidth / picture.sourceSize.width)
                            height: originalHeight * (picture.paintedHeight / picture.sourceSize.height)
                            visible: sectionType === "fill"

                            Rectangle {

                                color: "#7bd5bd"
                                border.color: "black"
                                border.width: 2
                                radius: 5
                                anchors.fill: parent
                                opacity: 0.4
                            }

                            FlowText {
                                id: answer
                                text: modelData.text
                                color: myColors.answerColor
                                rotation: modelData.rotation
                                height: parent.height
                                width: parent.width
                            }

                            MouseArea {
                                anchors.fill: parent
                                drag.target: parent
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                onPressed: {
                                    sideBar.hideAllComponent();
                                    sideBar.fillVisible = true;
                                    sideBar.page = page;
                                    sideBar.section = sectionData;
                                    sideBar.fillList = sectionItem.sectionAnswers;
                                    sideBar.fillIndex = index;
                                    sideBar.sectionIndex = sectionItem.sectionIndex;
                                }
                                onReleased: root.setTotalStatus(answerRect, modelData)
                                onClicked:
                                // if (mouse.button === Qt.MiddleButton) {
                                //     sectionItem.currentSection.removeAnswer(index);
                                //     config.bookSets[0].saveToJson();
                                //     toast.show("Changes are saved to File!");
                                // }
                                {}
                            }

                            Rectangle {
                                id: zoomPoint
                                color: "black"
                                radius: 15
                                width: radius
                                height: radius

                                anchors.right: parent.right
                                anchors.rightMargin: -width / 2
                                anchors.bottomMargin: -height / 2
                                anchors.bottom: parent.bottom

                                MouseArea {
                                    anchors.fill: parent
                                    drag {
                                        target: parent
                                        axis: Drag.XAndYAxis
                                    }
                                    onPositionChanged: {
                                        if (drag.active) {
                                            answerRect.originalWidth += mouseX / (picture.paintedWidth / picture.sourceSize.width);
                                            answerRect.originalHeight += mouseY / (picture.paintedHeight / picture.sourceSize.height);

                                            // Minimum boyutları kontrol et
                                            if (answerRect.originalWidth < 30 / (picture.paintedWidth / picture.sourceSize.width))
                                                answerRect.originalWidth = 30 / (picture.paintedWidth / picture.sourceSize.width);
                                            if (answerRect.originalHeight < 30 / (picture.paintedHeight / picture.sourceSize.height))
                                                answerRect.originalHeight = 30 / (picture.paintedHeight / picture.sourceSize.height);
                                        }
                                    }
                                    onReleased: root.setTotalStatus(answerRect, modelData)
                                }
                            }
                        }
                    }
                    // circle
                    Repeater {
                        id: answerCircleRepeater
                        model: modelData.answers

                        Item {
                            id: answerCircleRect
                            property real originalWidth: modelData.coords.width
                            property real originalHeight: modelData.coords.height
                            x: (flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.coords.x * (picture.paintedWidth / picture.sourceSize.width)
                            y: (flick.contentHeight / 2 - picture.paintedHeight / 2) + modelData.coords.y * (picture.paintedHeight / picture.sourceSize.height)
                            width: originalWidth * (picture.paintedWidth / picture.sourceSize.width)
                            height: originalHeight * (picture.paintedHeight / picture.sourceSize.height)
                            visible: sectionType === "circle" || sectionType === "circlewithextras"
                            Rectangle {

                                color: "transparent"
                                border.color: "black"
                                border.width: 2
                                radius: 5
                                anchors.fill: parent
                            }

                            MouseArea {
                                anchors.fill: parent
                                drag.target: parent
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                onPressed: {
                                    sideBar.hideAllComponent();
                                    sideBar.circleVisible = true;
                                    sideBar.page = page;
                                    sideBar.section = sectionData;
                                    sideBar.circleList = sectionItem.sectionAnswers;
                                    sideBar.circleIndex = index;
                                    sideBar.sectionIndex = sectionItem.sectionIndex;
                                }
                                onReleased: root.setTotalStatus(answerCircleRect, modelData)

                                onClicked:
                                // if (mouse.button === Qt.MiddleButton) {
                                //     sectionItem.currentSection.removeAnswer(index);
                                //     config.bookSets[0].saveToJson();
                                //     toast.show("Changes are saved to File!");
                                // }
                                {}
                            }

                            Rectangle {
                                color: "black"
                                radius: 15
                                width: radius
                                height: radius
                                anchors.right: parent.right
                                anchors.rightMargin: -width / 2
                                anchors.bottomMargin: -height / 2
                                anchors.bottom: parent.bottom

                                MouseArea {
                                    anchors.fill: parent

                                    drag {
                                        target: parent
                                        axis: Drag.XAndYAxis
                                    }
                                    onPositionChanged: {
                                        if (drag.active) {
                                            answerCircleRect.originalWidth += mouseX / (picture.paintedWidth / picture.sourceSize.width);
                                            answerCircleRect.originalHeight += mouseY / (picture.paintedHeight / picture.sourceSize.height);

                                            // Minimum boyutları kontrol et
                                            if (answerCircleRect.originalWidth < 30 / (picture.paintedWidth / picture.sourceSize.width))
                                                answerCircleRect.originalWidth = 30 / (picture.paintedWidth / picture.sourceSize.width);
                                            if (answerCircleRect.originalHeight < 30 / (picture.paintedHeight / picture.sourceSize.height))
                                                answerCircleRect.originalHeight = 30 / (picture.paintedHeight / picture.sourceSize.height);
                                        }
                                    }
                                    onReleased: root.setTotalStatus(answerCircleRect, modelData)
                                }
                            }
                        }
                    }
                    // fill with color
                    Repeater {
                        id: answersFillwithColorRepeater
                        model: modelData.answers
                        Item {
                            id: answerColorRect
                            property real originalWidth: modelData.coords.width
                            property real originalHeight: modelData.coords.height
                            x: (flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.coords.x * (picture.paintedWidth / picture.sourceSize.width)
                            y: (flick.contentHeight / 2 - picture.paintedHeight / 2) + modelData.coords.y * (picture.paintedHeight / picture.sourceSize.height)
                            width: originalWidth * (picture.paintedWidth / picture.sourceSize.width)
                            height: originalHeight * (picture.paintedHeight / picture.sourceSize.height)
                            visible: sectionType === "fillWithColor"

                            Rectangle {
                                id: answerColor
                                color: modelData.color !== "" ? modelData.color : myColors.darkBorderColor
                                rotation: modelData.rotation
                                height: parent.height
                                width: modelData.isRound ? height : parent.width
                                radius: modelData.isRound ? height / 2 : 2
                                opacity: modelData.opacity ? modelData.opacity : 0.5
                            }

                            MouseArea {
                                anchors.fill: parent
                                drag.target: parent
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                onPressed: {
                                    sideBar.hideAllComponent();
                                    sideBar.fillwColorVisible = true;
                                    sideBar.page = page;
                                    sideBar.section = sectionData;
                                    sideBar.fillWColorList = sectionItem.sectionAnswers;
                                    sideBar.fillIndex = index;
                                    sideBar.sectionIndex = sectionItem.sectionIndex;
                                }
                                onReleased: root.setTotalStatus(answerColorRect, modelData)
                                onClicked:
                                // if (mouse.button === Qt.MiddleButton) {
                                //     sectionItem.currentSection.removeAnswer(index);
                                //     config.bookSets[0].saveToJson();
                                //     toast.show("Changes are saved to File!");
                                // }
                                {}
                            }

                            Rectangle {
                                id: zoomPointFillColor
                                color: "black"
                                radius: 15
                                width: radius
                                height: radius

                                anchors.right: parent.right
                                anchors.rightMargin: -width / 2
                                anchors.bottomMargin: -height / 2
                                anchors.bottom: parent.bottom

                                MouseArea {
                                    anchors.fill: parent
                                    drag {
                                        target: parent
                                        axis: Drag.XAndYAxis
                                    }
                                    onPositionChanged: {
                                        if (drag.active) {
                                            answerColorRect.originalWidth += mouseX / (picture.paintedWidth / picture.sourceSize.width);
                                            answerColorRect.originalHeight += mouseY / (picture.paintedHeight / picture.sourceSize.height);

                                            // Minimum boyutları kontrol et
                                            if (answerColorRect.originalWidth < 30 / (picture.paintedWidth / picture.sourceSize.width))
                                                answerColorRect.originalWidth = 30 / (picture.paintedWidth / picture.sourceSize.width);
                                            if (answerColorRect.originalHeight < 30 / (picture.paintedHeight / picture.sourceSize.height))
                                                answerColorRect.originalHeight = 30 / (picture.paintedHeight / picture.sourceSize.height);
                                        }
                                    }
                                    onReleased: root.setTotalStatus(answerColorRect, modelData)
                                }
                            }
                        }
                    }

                    // Draw Matched Line
                    Repeater {
                        id: answersDrawMatchedLine
                        model: modelData.answers
                        Item {
                            id: drawMatchedLine
                            property point startPoint: Qt.point((flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.lineBegin.x * (picture.paintedWidth / picture.sourceSize.width), (flick.contentHeight / 2 - picture.paintedHeight / 2) + modelData.lineBegin.y * (picture.paintedHeight / picture.sourceSize.height))
                            property point endPoint: Qt.point((flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.lineEnd.x * (picture.paintedWidth / picture.sourceSize.width), (flick.contentHeight / 2 - picture.paintedHeight / 2) + modelData.lineEnd.y * (picture.paintedHeight / picture.sourceSize.height))
                            // x: (flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.coords.x * (picture.paintedWidth / picture.sourceSize.width)
                            // y: (flick.contentHeight / 2 - picture.paintedHeight / 2) + modelData.coords.y * (picture.paintedHeight / picture.sourceSize.height)
                            // width: modelData.coords.width * (picture.paintedWidth / picture.sourceSize.width)
                            // height: modelData.coords.height * (picture.paintedHeight / picture.sourceSize.height)
                            visible: sectionType === "drawMatchedLine"

                            Item {
                                id: beginRectItem
                                property real originalWidth: modelData.rectBegin.width
                                property real originalHeight: modelData.rectBegin.height
                                x: (flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.rectBegin.x * (picture.paintedWidth / picture.sourceSize.width)
                                y: (flick.contentHeight / 2 - picture.paintedHeight / 2) + modelData.rectBegin.y * (picture.paintedHeight / picture.sourceSize.height)
                                width: originalWidth * (picture.paintedWidth / picture.sourceSize.width)
                                height: originalHeight * (picture.paintedHeight / picture.sourceSize.height)

                                Rectangle {
                                    id: beginRect
                                    color: modelData.color !== "" ? modelData.color : myColors.darkBorderColor
                                    visible: true
                                    rotation: modelData.rotation
                                    height: beginRectItem.originalHeight * (picture.paintedHeight / picture.sourceSize.height)
                                    width: modelData.isRound ? height : beginRectItem.originalWidth * (picture.paintedWidth / picture.sourceSize.width)
                                    radius: modelData.isRound ? height / 2 : 2
                                    opacity: modelData.opacity ? modelData.opacity : 0.5
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    drag.target: parent
                                    onPressed: {
                                        sideBar.hideAllComponent();
                                        sideBar.drawMatchedVisible = true;
                                        sideBar.page = page;
                                        sideBar.section = sectionData;
                                        sideBar.drawMatchedLineList = sectionItem.sectionAnswers;
                                        sideBar.fillIndex = index;
                                        sideBar.sectionIndex = sectionItem.sectionIndex;
                                    }
                                    onReleased: {
                                        var adjustedX = (beginRectItem.x - (flick.contentWidth / 2 - picture.paintedWidth / 2));
                                        var adjustedY = (beginRectItem.y - (flick.contentHeight / 2 - picture.paintedHeight / 2));
                                        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                                        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                                        var adjustedW = beginRectItem.width * (picture.sourceSize.width / picture.paintedWidth);
                                        var adjustedH = beginRectItem.height * (picture.sourceSize.height / picture.paintedHeight);
                                        modelData.rectBegin = Qt.rect(originalX, originalY, adjustedW, adjustedH);
                                        root.lastSize.width = adjustedW;
                                        root.lastSize.height = adjustedH;
                                        config.bookSets[0].saveToJson();
                                        print("Changes Are Saved Page Detail set status");
                                    }
                                }
                                Rectangle {
                                    id: zoomPointRectBegin
                                    color: "black"
                                    radius: 15
                                    width: radius
                                    height: radius

                                    anchors.right: parent.right
                                    anchors.rightMargin: -width / 2
                                    anchors.bottomMargin: -height / 2
                                    anchors.bottom: parent.bottom

                                    MouseArea {
                                        anchors.fill: parent
                                        drag {
                                            target: parent
                                            axis: Drag.XAndYAxis
                                        }
                                        onPositionChanged: {
                                            if (drag.active) {
                                                beginRectItem.originalWidth += mouseX / (picture.paintedWidth / picture.sourceSize.width);
                                                beginRectItem.originalHeight += mouseY / (picture.paintedHeight / picture.sourceSize.height);

                                                // Minimum boyutları kontrol et
                                                if (beginRectItem.originalWidth < 30 / (picture.paintedWidth / picture.sourceSize.width))
                                                    beginRectItem.originalWidth = 30 / (picture.paintedWidth / picture.sourceSize.width);
                                                if (beginRectItem.originalHeight < 30 / (picture.paintedHeight / picture.sourceSize.height))
                                                    beginRectItem.originalHeight = 30 / (picture.paintedHeight / picture.sourceSize.height);
                                            }
                                        }
                                        onReleased: {
                                            var adjustedX = (beginRectItem.x - (flick.contentWidth / 2 - picture.paintedWidth / 2));
                                            var adjustedY = (beginRectItem.y - (flick.contentHeight / 2 - picture.paintedHeight / 2));
                                            var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                                            var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                                            var adjustedW = beginRectItem.width * (picture.sourceSize.width / picture.paintedWidth);
                                            var adjustedH = beginRectItem.height * (picture.sourceSize.height / picture.paintedHeight);
                                            modelData.rectBegin = Qt.rect(originalX, originalY, adjustedW, adjustedH);
                                            root.lastSize.width = adjustedW;
                                            root.lastSize.height = adjustedH;
                                            config.bookSets[0].saveToJson();
                                            print("Changes Are Saved Page Detail set status");
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                id: beginPoint
                                color: "blue"
                                width: 10
                                height: 10
                                border.color: "black"
                                border.width: 1
                                x: drawMatchedLine.startPoint.x
                                y: drawMatchedLine.startPoint.y

                                MouseArea {
                                    anchors.fill: parent
                                    drag {
                                        target: parent
                                        axis: Drag.XAndYAxis
                                    }
                                    onPressed: {
                                        sideBar.hideAllComponent();
                                        sideBar.drawMatchedVisible = true;
                                        sideBar.page = page;
                                        sideBar.section = sectionData;
                                        sideBar.drawMatchedLineList = sectionItem.sectionAnswers;
                                        sideBar.fillIndex = index;
                                        sideBar.sectionIndex = sectionItem.sectionIndex;
                                    }

                                    onPositionChanged: {
                                        var adjustedX = (beginPoint.x - (flick.contentWidth / 2 - picture.paintedWidth / 2));
                                        var adjustedY = (beginPoint.y - (flick.contentHeight / 2 - picture.paintedHeight / 2));
                                        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                                        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                                        modelData.lineBegin = Qt.point(originalX, originalY);
                                        config.bookSets[0].saveToJson();
                                        print("Changes Are Saved Page Detail set status");
                                    }
                                }
                            }

                            Rectangle {
                                id: endPoint
                                color: "red"
                                width: 10
                                height: 10
                                border.color: "black"
                                border.width: 1
                                x: drawMatchedLine.endPoint.x
                                y: drawMatchedLine.endPoint.y

                                MouseArea {
                                    anchors.fill: parent
                                    drag {
                                        target: parent
                                        axis: Drag.XAndYAxis
                                    }
                                    onPressed: {
                                        sideBar.hideAllComponent();
                                        sideBar.drawMatchedVisible = true;
                                        sideBar.page = page;
                                        sideBar.section = sectionData;
                                        sideBar.drawMatchedLineList = sectionItem.sectionAnswers;
                                        sideBar.fillIndex = index;
                                        sideBar.sectionIndex = sectionItem.sectionIndex;
                                    }

                                    onPositionChanged: {
                                        var adjustedX = (endPoint.x - (flick.contentWidth / 2 - picture.paintedWidth / 2));
                                        var adjustedY = (endPoint.y - (flick.contentHeight / 2 - picture.paintedHeight / 2));
                                        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                                        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                                        modelData.lineEnd = Qt.point(originalX, originalY);
                                        config.bookSets[0].saveToJson();
                                        print("Changes Are Saved Page Detail set status");
                                    }
                                }
                            }

                            Shape {
                                id: lineShape

                                property int lineWidth: 2
                                property bool isDashed: false
                                antialiasing: true

                                ShapePath {
                                    strokeWidth: lineShape.lineWidth
                                    strokeColor: myColors.answerColor
                                    fillColor: "purple"
                                    strokeStyle: lineShape.isDashed ? ShapePath.DashLine : ShapePath.SolidLine

                                    startX: drawMatchedLine.startPoint.x
                                    startY: drawMatchedLine.startPoint.y

                                    PathLine {
                                        x: drawMatchedLine.startPoint.x + (drawMatchedLine.endPoint.x - drawMatchedLine.startPoint.x)
                                        y: drawMatchedLine.startPoint.y + (drawMatchedLine.endPoint.y - drawMatchedLine.startPoint.y)
                                    }
                                }
                            }

                            Item {
                                id: endRectItem
                                property real originalWidth: modelData.rectEnd.width
                                property real originalHeight: modelData.rectEnd.height
                                x: (flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.rectEnd.x * (picture.paintedWidth / picture.sourceSize.width)
                                y: (flick.contentHeight / 2 - picture.paintedHeight / 2) + modelData.rectEnd.y * (picture.paintedHeight / picture.sourceSize.height)
                                width: originalWidth * (picture.paintedWidth / picture.sourceSize.width)
                                height: originalHeight * (picture.paintedHeight / picture.sourceSize.height)

                                Rectangle {
                                    id: endRect

                                    color: modelData.color !== "" ? modelData.color : myColors.darkBorderColor
                                    visible: true
                                    rotation: modelData.rotation
                                    height: endRectItem.originalHeight * (picture.paintedHeight / picture.sourceSize.height)
                                    width: modelData.isRound ? height : endRectItem.originalWidth * (picture.paintedWidth / picture.sourceSize.width)
                                    radius: modelData.isRound ? height / 2 : 2
                                    opacity: modelData.opacity ? modelData.opacity : 0.5
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    drag.target: parent
                                    onPressed: {
                                        sideBar.hideAllComponent();
                                        sideBar.drawMatchedVisible = true;
                                        sideBar.page = page;
                                        sideBar.section = sectionData;
                                        sideBar.drawMatchedLineList = sectionItem.sectionAnswers;
                                        sideBar.fillIndex = index;
                                        sideBar.sectionIndex = sectionItem.sectionIndex;
                                    }

                                    onReleased: {
                                        var adjustedX = (endRectItem.x - (flick.contentWidth / 2 - picture.paintedWidth / 2));
                                        var adjustedY = (endRectItem.y - (flick.contentHeight / 2 - picture.paintedHeight / 2));
                                        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                                        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                                        var adjustedW = endRectItem.width * (picture.sourceSize.width / picture.paintedWidth);
                                        var adjustedH = endRectItem.height * (picture.sourceSize.height / picture.paintedHeight);
                                        modelData.rectEnd = Qt.rect(originalX, originalY, adjustedW, adjustedH);
                                        root.lastSize.width = adjustedW;
                                        root.lastSize.height = adjustedH;
                                        config.bookSets[0].saveToJson();
                                        print("Changes Are Saved Page Detail set status");
                                    }
                                }

                                Rectangle {
                                    id: zoomPointRectEnd
                                    color: "black"
                                    radius: 15
                                    width: radius
                                    height: radius

                                    anchors.right: parent.right
                                    anchors.rightMargin: -width / 2
                                    anchors.bottomMargin: -height / 2
                                    anchors.bottom: parent.bottom

                                    MouseArea {
                                        anchors.fill: parent
                                        drag {
                                            target: parent
                                            axis: Drag.XAndYAxis
                                        }
                                        onPositionChanged: {
                                            if (drag.active) {
                                                endRectItem.originalWidth += mouseX / (picture.paintedWidth / picture.sourceSize.width);
                                                endRectItem.originalHeight += mouseY / (picture.paintedHeight / picture.sourceSize.height);

                                                // Minimum boyutları kontrol et
                                                if (endRectItem.originalWidth < 30 / (picture.paintedWidth / picture.sourceSize.width))
                                                    endRectItem.originalWidth = 30 / (picture.paintedWidth / picture.sourceSize.width);
                                                if (endRectItem.originalHeight < 30 / (picture.paintedHeight / picture.sourceSize.height))
                                                    endRectItem.originalHeight = 30 / (picture.paintedHeight / picture.sourceSize.height);
                                            }
                                        }
                                        onReleased: {
                                            var adjustedX = (endRectItem.x - (flick.contentWidth / 2 - picture.paintedWidth / 2));
                                            var adjustedY = (endRectItem.y - (flick.contentHeight / 2 - picture.paintedHeight / 2));
                                            var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                                            var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                                            var adjustedW = endRectItem.width * (picture.sourceSize.width / picture.paintedWidth);
                                            var adjustedH = endRectItem.height * (picture.sourceSize.height / picture.paintedHeight);
                                            modelData.rectEnd = Qt.rect(originalX, originalY, adjustedW, adjustedH);
                                            root.lastSize.width = adjustedW;
                                            root.lastSize.height = adjustedH;
                                            config.bookSets[0].saveToJson();
                                            print("Changes Are Saved Page Detail set status");
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // activity
                    Rectangle {
                        id: activityRect
                        color: "transparent"
                        x: (flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.activity.coords.x * (picture.paintedWidth / picture.sourceSize.width)
                        y: (flick.contentHeight / 2 - picture.paintedHeight / 2) + modelData.activity.coords.y * (picture.paintedHeight / picture.sourceSize.height)
                        width: modelData.activity.coords.width * (picture.paintedWidth / picture.sourceSize.width)
                        height: modelData.activity.coords.height * (picture.paintedHeight / picture.sourceSize.height)
                        visible: modelData.activity.type !== ""
                        Image {
                            id: activityImg
                            source: "qrc:/icons/activity.svg"
                            height: parent.height > 0 ? root.imageHeights : 0
                            width: height
                            smooth: true
                            antialiasing: true
                            anchors.centerIn: parent
                        }
                        MouseArea {
                            anchors.fill: parent
                            drag.target: parent
                            onPressed: {
                                sideBar.hideAllComponent();
                                sideBar.activityVisible = true;
                                sideBar.page = page;
                                sideBar.sectionIndex = index;
                                sideBar.activityModelData = modelData.activity;
                                sideBar.sectionModelData = modelData;
                            }

                            onReleased: {
                                var adjustedX = (activityRect.x - (flick.contentWidth / 2 - picture.paintedWidth / 2));
                                var adjustedY = (activityRect.y - (flick.contentHeight / 2 - picture.paintedHeight / 2));

                                // Zoom seviyesini ve PaintedWidth/PaintedHeight'i hesaba katarak orijinal koordinatları bul
                                var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                                var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                                modelData.activity.coords = Qt.rect(originalX, originalY, modelData.activity.coords.width, modelData.activity.coords.height);
                                config.bookSets[0].saveToJson();
                                print("Changes Are Saved Page Detail set activity");
                            }
                        }
                    }
                }
            }
        }
    }

    function setDefaultZoom() {
        // İçeriği orijinal boyutuna (1x zoom) döndür
        flick.resizeContent(flick.width, flick.height, Qt.point(flick.width / 2, flick.height / 2));
        flick.returnToBounds();

        // İçeriği merkeze al
        flick.contentX = 0;
        flick.contentY = 0;
    }

    function enableRightClick(enabled) {
        mainMouseArea.enabled = enabled;
    }

    function setTotalStatus(rect, modelData) {
        var adjustedX = (rect.x - (flick.contentWidth / 2 - picture.paintedWidth / 2));
        var adjustedY = (rect.y - (flick.contentHeight / 2 - picture.paintedHeight / 2));
        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

        var adjustedW = rect.width * (picture.sourceSize.width / picture.paintedWidth);
        var adjustedH = rect.height * (picture.sourceSize.height / picture.paintedHeight);

        modelData.coords = Qt.rect(originalX, originalY, adjustedW, adjustedH);
        root.lastSize.width = adjustedW;
        root.lastSize.height = adjustedH;

        config.bookSets[0].saveToJson();
        print("Changes Are Saved Page Detail set status");
    }
}
