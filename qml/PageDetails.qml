import QtQuick
import QtQuick.Controls
import "newComponents"

Item {
    id: root
    property real imageHeights: mainwindow.height * 30 / 1080 * flick.zoomLevel
    property var page
    property bool outlineEnabled: true
    property string currentSelectionType: "";
    property size lastSize: Qt.size(100,50)

    property bool fillingModeEnabled: false
    property var activeFillRectangle
    property var fillList: []
    property var newSection
    property var activeSession
    property real startRectX: 0
    property real startRectY: 0

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
                           flick.interactive = true; // Enable Flickable interaction
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
                            flick.interactive = false; // Disable Flickable interaction
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

                               if (root.fillingModeEnabled) {
                                   canvas.requestPaint();
                               }
                           }

        onWheel: event => {
                     if (event.angleDelta.y > 0)
                     //flick.zoomIn()
                     {} else
                     //flick.zoomOut()
                     {}
                     event.accepted = true;
                 }

        onPressAndHold: {
            var adjustedX = mainMouseArea.mouseX + flick.contentX;
            var adjustedY = mainMouseArea.mouseY + flick.contentY;

            // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
            var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
            var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

            if (currentSelectionType === "fill" ){
                root.activeSession = root.page.getAvailableSection("fill");
            }
            else if (currentSelectionType === "circle" ) {
                root.activeSession = root.page.getAvailableSection("circle");
            }

            // if(root.activeSession.answers.length>1) {
            //     lastWidth = root.activeSession.answers[root.activeSession.answers.length -2].width
            //     lastHeight = root.activeSession.answers[root.activeSession.answers.length -2].height
            // }
            var answer = root.activeSession.createNewAnswer(originalX, originalY, lastSize.width, lastSize.height);

            sideBar.hideAllComponent();
            sideBar.fillVisible = true;
            sideBar.page = page;
            sideBar.section = activeSession;
            sideBar.fillList = activeSession.answers;

            config.bookSets[0].saveToJson();
            print("Changes Are Saved activity Fill on Triggered");
        }

        Menu {
            id: menu
            MenuItem {
                text: "Audio"
                onTriggered: {
                    canvas.clearCanvas();
                    var adjustedX = mainMouseArea.mouseX + flick.contentX;
                    var adjustedY = mainMouseArea.mouseY + flick.contentY;

                    // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                    var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                    var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                    root.page.createNewAudioSection(originalX, originalY, root.imageHeights, root.imageHeights, "Enter the audio path");
                    config.bookSets[0].saveToJson();
                    print("Changes Are Saved activity Audio on Triggered");
                    currentSelectionType = ""
                }
            }
            MenuItem {
                text: "Video"
                onTriggered: {
                    canvas.clearCanvas();
                    var adjustedX = mainMouseArea.mouseX + flick.contentX;
                    var adjustedY = mainMouseArea.mouseY + flick.contentY;

                    // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                    var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                    var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                    root.page.createNewVideoSection(originalX, originalY, root.imageHeights, root.imageHeights, "Enter the video path");
                    config.bookSets[0].saveToJson();
                    print("Changes Are Saved activity Video on Triggered");
                    currentSelectionType = ""
                }
            }
            MenuItem {
                text: "Fill"
                highlighted: currentSelectionType == "fill"
                onTriggered: {
                    root.fillingModeEnabled = true;
                    // canvas.requestPaint()
                    currentSelectionType = "fill"

                    var adjustedX = mainMouseArea.mouseX + flick.contentX;
                    var adjustedY = mainMouseArea.mouseY + flick.contentY;

                    // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                    var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                    var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                    root.activeSession = root.page.getAvailableSection("fill");
                    var lastWidth = 100;
                    var lastHeight = 50;

                    // if(root.activeSession.answers.length>1) {
                    //     lastWidth = root.activeSession.answers[root.activeSession.answers.length -2].width
                    //     lastHeight = root.activeSession.answers[root.activeSession.answers.length -2].height
                    // }
                    var answer = root.activeSession.createNewAnswer(originalX, originalY, lastSize.width, lastSize.height);

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
                    var adjustedX = mainMouseArea.mouseX + flick.contentX;
                    var adjustedY = mainMouseArea.mouseY + flick.contentY;
                    currentSelectionType = "circle"

                    // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                    var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                    var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                    root.activeSession = root.page.getAvailableSection("circle");
                    var lastWidth = 100;
                    var lastHeight = 50;

                    // if(root.activeSession.answers.length>1) {
                    //     lastWidth = root.activeSession.answers[root.activeSession.answers.length -2].width
                    //     lastHeight = root.activeSession.answers[root.activeSession.answers.length -2].height
                    // }
                    var answer = root.activeSession.createNewAnswer(originalX, originalY, lastSize.width, lastSize.height);

                    sideBar.hideAllComponent();
                    sideBar.circleVisible = true;
                    sideBar.page = page;
                    sideBar.section = activeSession;
                    sideBar.circleList = activeSession.answers;

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
                        var adjustedX = mainMouseArea.mouseX + flick.contentX;
                        var adjustedY = mainMouseArea.mouseY + flick.contentY;

                        // Zoom yapılmış görüntüde tıklanan noktayı orijinal görüntüye çevirme
                        var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                        var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                        root.page.createNewActivity(originalX, originalY, root.imageHeights, root.imageHeights, "dragdroppicture");
                        config.bookSets[0].saveToJson();
                        print("Changes Are Saved activity Drag Drop on Triggered");
                        currentSelectionType = ""
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
                        currentSelectionType = ""
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
                        currentSelectionType = ""
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
                        currentSelectionType = ""
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
                        currentSelectionType = ""
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
                        currentSelectionType = ""
                    }
                }
            }
        }
    }

    Flickable {
        id: flick
        property int startX: 0
        anchors.fill: parent
        clip: true
        contentHeight: parent.height
        contentWidth: parent.width
        interactive: false
        boundsMovement: Flickable.StopAtBounds

        property real lastContentHeight
        property real lastContentWidth

        property real minZoom: 1.0
        property real maxZoom: 4.0
        property real zoomLevel: 1
        property real zoomStep: 0.1
        property real pinchCenter: 1

        PinchArea {
            id: pinchArea
            width: Math.max(flick.contentWidth, flick.width)
            height: Math.max(flick.contentHeight, flick.height)
            pinch.target: flick.picture
            pinch.maximumScale: 2.0
            pinch.minimumScale: 1.0
            pinch.dragAxis: Pinch.XAndYAxis

            onPinchUpdated: {
                var previousZoomLevel = flick.zoomLevel;
                flick.zoomLevel = previousZoomLevel + (pinch.scale - pinch.previousScale);
                flick.pinchCenter = pinch.center;
                if (flick.zoomLevel < flick.maxZoom && flick.zoomLevel > flick.minZoom) {
                    flick.resizeContent(flick.width * flick.zoomLevel, flick.height * flick.zoomLevel, flick.pinchCenter);
                } else {
                    flick.zoomLevel = previousZoomLevel;
                }
            }

            onPinchFinished: flick.returnToBounds()
        }

        Image {
            id: picture
            source: qsTr("file:" + appPath + page.image_path)
            fillMode: Image.PreserveAspectFit
            width: Math.max(flick.contentWidth, flick.width)
            height: Math.max(flick.contentHeight, flick.height)
            Repeater {
                id: sections
                model: page.sections
                Item {
                    property var currentSection: modelData
                    id: sectionItem
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
                            x: (flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.coords.x * (picture.paintedWidth / picture.sourceSize.width)
                            y: (flick.contentHeight / 2 - picture.paintedHeight / 2) + modelData.coords.y * (picture.paintedHeight / picture.sourceSize.height)
                            width: modelData.coords.width * (picture.paintedWidth / picture.sourceSize.width)
                            height: modelData.coords.height * (picture.paintedHeight / picture.sourceSize.height)
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
                                }
                                onReleased: answerRect.setStatus()
                                onClicked: {
                                    if (mouse.button === Qt.MiddleButton) {
                                        sectionItem.currentSection.removeAnswer(index)
                                        config.bookSets[0].saveToJson();
                                        toast.show("Changes are saved to File!")
                                    }
                                }


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
                                            var adjustedX = (mouseX - (flick.contentWidth / 2 - picture.paintedWidth / 2));
                                            var adjustedY = (mouseY - (flick.contentHeight / 2 - picture.paintedHeight / 2));
                                            var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                                            var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                                            // Mouse hareketini zoom seviyesine göre ölçekle
                                            answerRect.width = answerRect.width + (originalX);
                                            answerRect.height = answerRect.height + (originalY);

                                            print(mouseX, mouseY, answerRect.width, answerRect.height)

                                            // Minimum boyutları belirle
                                            if (answerRect.width < 20)
                                                answerRect.width = 20;
                                            if (answerRect.height < 10)
                                                answerRect.height = 10;
                                        }
                                    }
                                    onReleased: answerRect.setStatus()
                                }
                            }
                            function setStatus() {
                                var adjustedX = (answerRect.x - (flick.contentWidth / 2 - picture.paintedWidth / 2));
                                var adjustedY = (answerRect.y - (flick.contentHeight / 2 - picture.paintedHeight / 2));
                                var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                                var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                                var adjustedW = answerRect.width * (picture.sourceSize.width / picture.paintedWidth);
                                var adjustedH = answerRect.height * (picture.sourceSize.height / picture.paintedHeight);
                                modelData.coords = Qt.rect(originalX, originalY, adjustedW, adjustedH);
                                lastSize.width = adjustedW
                                lastSize.height = adjustedH
                                config.bookSets[0].saveToJson();
                                print("Changes Are Saved Page Detail set status");
                            }
                        }
                    }
                    // circle
                    Repeater {
                        id: answerCircleRepeater
                        model: modelData.answers

                        Item {
                            id: answerCircleRect
                            x: (flick.contentWidth / 2 - picture.paintedWidth / 2) + modelData.coords.x * (picture.paintedWidth / picture.sourceSize.width)
                            y: (flick.contentHeight / 2 - picture.paintedHeight / 2) + modelData.coords.y * (picture.paintedHeight / picture.sourceSize.height)
                            width: modelData.coords.width * (picture.paintedWidth / picture.sourceSize.width)
                            height: modelData.coords.height * (picture.paintedHeight / picture.sourceSize.height)
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
                                }
                                onReleased: answerCircleRect.setStatus()

                                onClicked: {
                                    if (mouse.button === Qt.MiddleButton) {
                                        sectionItem.currentSection.removeAnswer(index)
                                        config.bookSets[0].saveToJson();
                                        toast.show("Changes are saved to File!")
                                    }
                                }
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
                                            var adjustedX = (mouseX - (flick.contentWidth / 2 - picture.paintedWidth / 2));
                                            var adjustedY = (mouseY - (flick.contentHeight / 2 - picture.paintedHeight / 2));
                                            var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                                            var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                                            // Mouse hareketini zoom seviyesine göre ölçekle
                                            answerCircleRect.width = answerCircleRect.width + (originalX);
                                            answerCircleRect.height = answerCircleRect.height + (originalY);

                                            // Minimum boyutları belirle
                                            if (answerCircleRect.width < 20)
                                                answerCircleRect.width = 20;
                                            if (answerCircleRect.height < 10)
                                                answerCircleRect.height = 10;
                                        }
                                    }
                                    onReleased: answerCircleRect.setStatus()


                                }
                            }
                            function setStatus() {
                                var adjustedX = (answerCircleRect.x - (flick.contentWidth / 2 - picture.paintedWidth / 2));
                                var adjustedY = (answerCircleRect.y - (flick.contentHeight / 2 - picture.paintedHeight / 2));
                                var originalX = adjustedX * (picture.sourceSize.width / picture.paintedWidth);
                                var originalY = adjustedY * (picture.sourceSize.height / picture.paintedHeight);

                                var adjustedW = answerCircleRect.width * (picture.sourceSize.width / picture.paintedWidth);
                                var adjustedH = answerCircleRect.height * (picture.sourceSize.height / picture.paintedHeight);
                                modelData.coords = Qt.rect(originalX, originalY, adjustedW, adjustedH);
                                lastSize.width = adjustedW
                                lastSize.height = adjustedH
                                config.bookSets[0].saveToJson();
                                print("Changes Are Saved Page Detail set status circle");
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

        function zoomIn() {
            var newZoom = flick.zoomLevel + zoomStep;

            if (newZoom <= flick.maxZoom) {
                flick.zoomLevel = newZoom;
                flick.resizeContent(flick.width * flick.zoomLevel, flick.height * flick.zoomLevel, Qt.point(flick.contentWidth / 2, flick.contentHeight / 2));
                flick.returnToBounds();
            } else {
                flick.zoomLevel = flick.maxZoom;
            }
        }

        function zoomOut() {
            var newZoom = flick.zoomLevel - zoomStep;

            if (newZoom >= flick.minZoom) {
                flick.zoomLevel = newZoom;
                flick.resizeContent(flick.width * flick.zoomLevel, flick.height * flick.zoomLevel, Qt.point(flick.contentWidth / 2, flick.contentHeight / 2));
                flick.returnToBounds();
            } else {
                flick.zoomLevel = flick.minZoom;
            }
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        visible: root.fillingModeEnabled && outlineEnabled
        onPaint: {
            var ctx = canvas.getContext("2d");
            ctx.clearRect(0, 0, canvas.width, canvas.height);

            ctx.strokeStyle = "red";
            ctx.lineWidth = 2;

            // Yatay çizgi
            ctx.beginPath();
            ctx.moveTo(0, mainMouseArea.mouseY);
            ctx.lineTo(canvas.width, mainMouseArea.mouseY);
            ctx.stroke();

            // Dikey çizgi
            ctx.beginPath();
            ctx.moveTo(mainMouseArea.mouseX, 0);
            ctx.lineTo(mainMouseArea.mouseX, canvas.height);
            ctx.stroke();
        }

        function clearCanvas() {
            var ctx = canvas.getContext("2d");
            ctx.clearRect(0, 0, canvas.width, canvas.height);
        }
    }

    function setDefaultZoom() {
        flick.zoomLevel = 1.0;
        flick.zoomIn();
        flick.zoomOut();
    }

    function enableRightClick(enabled) {
        mainMouseArea.enabled = enabled;
    }
}
