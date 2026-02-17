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
    color: "#1A2327" // Dark background
    border.color: "#009ca6" // Turquoise border
    border.width: 1

    Row {
        width: parent.width / 3
        height: parent.height
        spacing: 8
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 0
        anchors.left: parent.left
        anchors.leftMargin: 10
        Button {
            anchors.verticalCenter: parent.verticalCenter
            text: "Create"
            width: 70
            height: 40
            background: Rectangle {
                color: "#009ca6"
                radius: 6
            }
            contentItem: Text {
                text: parent.text
                color: "white"
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                anchors.centerIn: parent
            }
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
            background: Rectangle {
                color: "#009ca6"
                radius: 6
            }
            contentItem: Text {
                text: parent.text
                color: "white"
                font.bold: true
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                config.refreshRecentProjects();
                openProject.loadRecentProjects();
                openProject.open();
            }
        }

        Button {
            anchors.verticalCenter: parent.verticalCenter
            text: "Save"
            width: 70
            height: 40
            background: Rectangle {
                color: "#009ca6"
                radius: 6
            }
            contentItem: Text {
                text: parent.text
                color: "white"
                font.bold: true
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {

                save()
            }
        }

        Button {
            anchors.verticalCenter: parent.verticalCenter
            text: "AI Analyze"
            width: 100
            height: 40
            background: Rectangle {
                color: "#009ca6"
                radius: 6
            }
            contentItem: Text {
                text: parent.text
                color: "white"
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                // Read settings.json to check API key
                var settingsPath = appPath + "settings.json";
                var xhr = new XMLHttpRequest();
                xhr.open("GET", "file://" + settingsPath, false);
                try {
                    xhr.send();
                    if (xhr.status === 200 || xhr.status === 0) {
                        var settings = JSON.parse(xhr.responseText);
                        if (settings.gemini_api_key && settings.gemini_api_key.length > 0) {
                            // API key exists, build config path from current project
                            var configPath = appPath + "books/" + openProject.currentProject + "/config.json";
                            console.log("Starting AI Analysis with config: " + configPath);

                            // Save current changes first
                            save();

                            // Start AI analysis
                            pdfProcess.startAIAnalysis(configPath, settingsPath);

                            // Show progress dialog
                            flowProgress.reset();
                            flowProgress.statusText = "AI Analysis in progress...";
                            flowProgress.addLogMessage("Starting AI analysis...");
                            flowProgress.open();
                        } else {
                            toast.show("API key is empty in settings.json");
                        }
                    } else {
                        toast.show("settings.json not found at: " + settingsPath);
                    }
                } catch (e) {
                    toast.show("settings.json not found. Create it with gemini_api_key.");
                    console.log("Settings error: " + e);
                }
            }
        }

        Button {
            anchors.verticalCenter: parent.verticalCenter
            text: "Test"
            width: 70
            height: 40
            background: Rectangle {
                color: "#009ca6"
                radius: 6
            }
            contentItem: Text {
                text: parent.text
                color: "white"
                font.bold: true
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                testDialog.currentProject = openProject.currentProject;
                testDialog.open();
            }
        }

        Button {
            anchors.verticalCenter: parent.verticalCenter
            text: "Package"
            width: 100
            height: 40
            background: Rectangle {
                color: "#009ca6"
                radius: 6
            }
            contentItem: Text {
                text: parent.text
                color: "white"
                font.bold: true
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                packageDialog.currentProject = openProject.currentProject;
                packageDialog.open();
            }
        }

        Button {
            anchors.verticalCenter: parent.verticalCenter
            text: "Games"
            width: 80
            height: 40
            background: Rectangle {
                color: "#009ca6"
                radius: 6
            }
            contentItem: Text {
                text: parent.text
                color: "white"
                font.bold: true
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                gamesDialog.open();
            }
        }
        // CheckBox {
        //     id: checkOutline
        //     checked: false
        //     onCheckedChanged: root.outlineEnabled(checked)
        //     text: "Outline"
        //     anchors.verticalCenter: parent.verticalCenter
        //     height: 40
        // }
    }

    Row {
        id: pagesRow
        height: parent.height * .8
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 0
        Button {
            anchors.verticalCenter: parent.verticalCenter
            text: "<"
            width: 80
            height: parent.height
            background: Rectangle {
                color: "#232f34"
                radius: 6
            }
            contentItem: Text {
                text: parent.text
                color: "#00e6e6"
                font.bold: true
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                content.goPrev();
            }
        }
        TextField {
            id: pageNumberInput
            property int firstPage: pages[0].page_number
            property int lastPage: pages[pages.length - 1].page_number
            width: 80
            height: parent.height
            color: "white" // text color
            background: Rectangle {
                color: "#232f34"
                radius: 6
            }
            selectionColor: "#00e6e6"
            placeholderText: "Page"
            placeholderTextColor: "gray"
            validator: IntValidator {
                bottom: pageNumberInput.firstPage
                top: pageNumberInput.lastPage
            }
            font.pixelSize: 18
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
            width: 80
            height: parent.height
            background: Rectangle {
                color: "#232f34"
                radius: 6
            }
            contentItem: Text {
                text: parent.text
                color: "#00e6e6"
                font.bold: true
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                content.goNext();
            }
        }
    }

    Rectangle {
        id: moduleBtn
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: pagesRow.right
        anchors.leftMargin: 50
        width: 100
        height: 40
        color: "#232f34"
        border.color: "#009ca6"
        border.width: 1
        FlowText {
            id: moduleTxt
            color: "white"
            width: parent.width * .7
            height: parent.height
            anchors.centerIn: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    CheckBox {
        id: moduleSideListCB
        text: "isModuleSideLeft"
        checked: config.bookSets[0].books[0].isModuleSideLeft
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: moduleBtn.right
        anchors.leftMargin: 30
        height: parent.height
        width: 150
        indicator: Rectangle {
            width: 18
            height: 18
            radius: 4
            color: moduleSideListCB.checked ? "#00e6e6" : "#232f34"
            border.color: "#009ca6"
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter
        }

        contentItem: Text {
            text: parent.text
            color: "white"  // Turkuaz renk
            font.pixelSize: 16
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
        }
        onCheckedChanged: {
            config.bookSets[0].books[0].isModuleSideLeft = checked;
            // config.bookSets[0].saveToJson();
        }
    }
    function setModuleText() {
        moduleTxt.text = content.getModuleName();
    }

    // Rectangle {
    //     id: closeBtn
    //     anchors.verticalCenter: parent.verticalCenter
    //     anchors.right: parent.right
    //     anchors.rightMargin: 10
    //     width: 40
    //     height: 40
    //     color: "red"
    //     FlowText {
    //         text: qsTr("X")
    //         color: "white"
    //     }

    //     MouseArea {
    //         anchors.fill: parent
    //         onClicked: {
    //             confirmDialog.open();
    //         }
    //     }
    // }
}
