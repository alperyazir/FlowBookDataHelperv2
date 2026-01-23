import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

import "games"

Dialog {
    id: gamesDialog
    width: parent.width * 0.85
    height: parent.height * 0.85
    anchors.centerIn: parent
    modal: true
    visible: false
    padding: 0

    // Remove title and header
    header: null
    closePolicy: Popup.NoAutoClose // Prevents dialog from closing when clicking outside

    // Load games.json when dialog opens
    onOpened: {
        // Load games.json file
        if (!gamesParser.loadFromFile("games.json")) {
            console.error("Failed to load games.json");
        }
    }

    // Helper property to get current quiz game
    property var currentQuizGame: {
        if (!gamesParser.levels || levelTabBar.currentIndex < 0 || levelTabBar.currentIndex >= gamesParser.levels.length) {
            return null;
        }

        let level = gamesParser.levels[levelTabBar.currentIndex];
        if (!level || !level.quizGames || level.quizGames.length === 0) {
            return null;
        }

        // Get all game types and find the selected Quiz game
        let gameTypes = gameTypeTabs.getGameTypes();
        if (gameTypes.length === 0 || gameTypeTabs.selectedGameType >= gameTypes.length) {
            return null;
        }

        let selectedGame = gameTypes[gameTypeTabs.selectedGameType];
        if (selectedGame && selectedGame.type === "Quiz" && selectedGame.games.length > 0) {
            return selectedGame.games[0];
        }

        return null;
    }

    // Helper property to get current memory game
    property var currentMemoryGame: {
        if (!gamesParser.levels || levelTabBar.currentIndex < 0 || levelTabBar.currentIndex >= gamesParser.levels.length) {
            return null;
        }

        let level = gamesParser.levels[levelTabBar.currentIndex];
        if (!level || !level.memoryGames || level.memoryGames.length === 0) {
            return null;
        }

        // Get all game types and find the selected Memory game
        let gameTypes = gameTypeTabs.getGameTypes();
        if (gameTypes.length === 0 || gameTypeTabs.selectedGameType >= gameTypes.length) {
            return null;
        }

        let selectedGame = gameTypes[gameTypeTabs.selectedGameType];
        if (selectedGame && selectedGame.type === "Memory" && selectedGame.games.length > 0) {
            return selectedGame.games[0];
        }

        return null;
    }

    // Helper property to get current order game
    property var currentOrderGame: {
        if (!gamesParser.levels || levelTabBar.currentIndex < 0 || levelTabBar.currentIndex >= gamesParser.levels.length) {
            return null;
        }

        let level = gamesParser.levels[levelTabBar.currentIndex];
        if (!level || !level.orderGames || level.orderGames.length === 0) {
            return null;
        }

        // Get all game types and find the selected Order game
        let gameTypes = gameTypeTabs.getGameTypes();
        if (gameTypes.length === 0 || gameTypeTabs.selectedGameType >= gameTypes.length) {
            return null;
        }

        let selectedGame = gameTypes[gameTypeTabs.selectedGameType];
        if (selectedGame && selectedGame.type === "Order" && selectedGame.games.length > 0) {
            return selectedGame.games[0];
        }

        return null;
    }

    // Helper property to get current selector game
    property var currentSelectorGame: {
        if (!gamesParser.levels || levelTabBar.currentIndex < 0 || levelTabBar.currentIndex >= gamesParser.levels.length) {
            return null;
        }

        let level = gamesParser.levels[levelTabBar.currentIndex];
        if (!level || !level.selectorGames || level.selectorGames.length === 0) {
            return null;
        }

        // Get all game types and find the selected Selector game
        let gameTypes = gameTypeTabs.getGameTypes();
        if (gameTypes.length === 0 || gameTypeTabs.selectedGameType >= gameTypes.length) {
            return null;
        }

        let selectedGame = gameTypes[gameTypeTabs.selectedGameType];
        if (selectedGame && selectedGame.type === "Selector" && selectedGame.games.length > 0) {
            return selectedGame.games[0];
        }

        return null;
    }

    // Helper property to get current builder game
    property var currentBuilderGame: {
        if (!gamesParser.levels || levelTabBar.currentIndex < 0 || levelTabBar.currentIndex >= gamesParser.levels.length) {
            return null;
        }

        let level = gamesParser.levels[levelTabBar.currentIndex];
        if (!level || !level.builderGames || level.builderGames.length === 0) {
            return null;
        }

        // Get all game types and find the selected Builder game
        let gameTypes = gameTypeTabs.getGameTypes();
        if (gameTypes.length === 0 || gameTypeTabs.selectedGameType >= gameTypes.length) {
            return null;
        }

        let selectedGame = gameTypes[gameTypeTabs.selectedGameType];
        if (selectedGame && selectedGame.type === "Builder" && selectedGame.games.length > 0) {
            return selectedGame.games[0];
        }

        return null;
    }

    // Helper property to get current crosspuzzle game
    property var currentCrosspuzzleGame: {
        if (!gamesParser.levels || levelTabBar.currentIndex < 0 || levelTabBar.currentIndex >= gamesParser.levels.length) {
            return null;
        }

        let level = gamesParser.levels[levelTabBar.currentIndex];
        if (!level || !level.crosspuzzleGames || level.crosspuzzleGames.length === 0) {
            return null;
        }

        // Get all game types and find the selected Crosspuzzle game
        let gameTypes = gameTypeTabs.getGameTypes();
        if (gameTypes.length === 0 || gameTypeTabs.selectedGameType >= gameTypes.length) {
            return null;
        }

        let selectedGame = gameTypes[gameTypeTabs.selectedGameType];
        if (selectedGame && selectedGame.type === "Crosspuzzle" && selectedGame.games.length > 0) {
            return selectedGame.games[0];
        }

        return null;
    }

    // Helper property to get current race game
    property var currentRaceGame: {
        if (!gamesParser.levels || levelTabBar.currentIndex < 0 || levelTabBar.currentIndex >= gamesParser.levels.length) {
            return null;
        }

        let level = gamesParser.levels[levelTabBar.currentIndex];
        if (!level || !level.raceGames || level.raceGames.length === 0) {
            return null;
        }

        // Get all game types and find the selected Race game
        let gameTypes = gameTypeTabs.getGameTypes();
        if (gameTypes.length === 0 || gameTypeTabs.selectedGameType >= gameTypes.length) {
            return null;
        }

        let selectedGame = gameTypes[gameTypeTabs.selectedGameType];
        if (selectedGame && selectedGame.type === "Race" && selectedGame.games.length > 0) {
            return selectedGame.games[0];
        }

        return null;
    }

    // Question deletion confirmation dialog
    property int questionToDelete: -1
    property int gameToDelete: -1
    property int levelToDelete: -1

    Dialog {
        id: deleteQuestionDialog
        title: "Delete Question"
        modal: true
        anchors.centerIn: parent
        width: 300
        height: 150

        Text {
            text: "Are you sure you want to delete this question?"
            anchors.centerIn: parent
            color: "#FFFFFF"
            font.pixelSize: 14
        }

        Row {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            Button {
                text: "Cancel"
                onClicked: {
                    deleteQuestionDialog.close();
                    questionToDelete = -1;
                }
            }

            Button {
                text: "Delete"
                onClicked: {
                    let selectedGame = gameTypeTabs.getGameTypes()[gameTypeTabs.selectedGameType];
                    if (selectedGame.type === "Quiz" && currentQuizGame && questionToDelete >= 0) {
                        gamesParser.removeQuestionFromGame(currentQuizGame, questionToDelete);
                        console.log("Quiz question", questionToDelete + 1, "deleted");

                        // Scroll to bottom after deletion
                        Qt.callLater(function () {
                            quizQuestionsListView.positionViewAtEnd();
                        });
                    } else if (selectedGame.type === "Memory" && currentMemoryGame && questionToDelete >= 0) {
                        gamesParser.removeQuestionFromMemoryGame(currentMemoryGame, questionToDelete);
                        console.log("Memory question", questionToDelete + 1, "deleted");

                        // Scroll to bottom after deletion
                        Qt.callLater(function () {
                            memoryQuestionsListView.positionViewAtEnd();
                        });
                    } else if (selectedGame.type === "Order" && currentOrderGame && questionToDelete >= 0) {
                        gamesParser.removeQuestionFromOrderGame(currentOrderGame, questionToDelete);
                        console.log("Order question", questionToDelete + 1, "deleted");

                        // Scroll to bottom after deletion
                        Qt.callLater(function () {
                            orderQuestionsListView.positionViewAtEnd();
                        });
                    } else if (selectedGame.type === "Selector" && currentSelectorGame && questionToDelete >= 0) {
                        gamesParser.removeQuestionFromSelectorGame(currentSelectorGame, questionToDelete);
                        console.log("Selector question", questionToDelete + 1, "deleted");

                        // Scroll to bottom after deletion
                        Qt.callLater(function () {
                            selectorQuestionsListView.positionViewAtEnd();
                        });
                    } else if (selectedGame.type === "Builder" && currentBuilderGame && questionToDelete >= 0) {
                        gamesParser.removeQuestionFromBuilderGame(currentBuilderGame, questionToDelete);
                        console.log("Builder question", questionToDelete + 1, "deleted");

                        // Scroll to bottom after deletion
                        Qt.callLater(function () {
                            builderQuestionsListView.positionViewAtEnd();
                        });
                    } else if (selectedGame.type === "Crosspuzzle" && currentCrosspuzzleGame && questionToDelete >= 0) {
                        gamesParser.removeQuestionFromCrosspuzzleGame(currentCrosspuzzleGame, questionToDelete);
                        console.log("Crosspuzzle question", questionToDelete + 1, "deleted");

                        // Scroll to bottom after deletion
                        Qt.callLater(function () {
                            crosspuzzleQuestionsListView.positionViewAtEnd();
                        });
                    } else if (selectedGame.type === "Race" && currentRaceGame && questionToDelete >= 0) {
                        gamesParser.removeQuestionFromRaceGame(currentRaceGame, questionToDelete);
                        console.log("Race question", questionToDelete + 1, "deleted");

                        // Scroll to bottom after deletion
                        Qt.callLater(function () {
                            raceQuestionsListView.positionViewAtEnd();
                        });
                    } else {
                        console.log("Delete failed - selectedGameType:", selectedGame.type, "questionToDelete:", questionToDelete);
                    }

                    deleteQuestionDialog.close();
                    questionToDelete = -1;
                }
            }
        }
    }

    // Game deletion confirmation dialog
    Dialog {
        id: deleteGameDialog
        title: "Delete Game"
        modal: true
        anchors.centerIn: parent
        width: 400
        height: 250

        // Custom header
        header: Rectangle {
            width: parent.width
            height: 50
            color: "#1A2327"
            border.color: "#009ca6"
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "Delete Game"
                color: "#FFFFFF"
                font.pixelSize: 18
                font.bold: true
            }
        }

        contentItem: Column {
            spacing: 25
            anchors.fill: parent
            anchors.margins: 25

            // Warning icon area
            Rectangle {
                width: 60
                height: 60
                radius: 30
                color: "#d2232b"
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    anchors.centerIn: parent
                    text: "!"
                    color: "#FFFFFF"
                    font.pixelSize: 32
                    font.bold: true
                }
            }

            Text {
                text: "Are you sure you want to delete this game?"
                color: "#FFFFFF"
                font.pixelSize: 16
                anchors.horizontalCenter: parent.horizontalCenter
                wrapMode: Text.WordWrap
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                text: "This action cannot be undone."
                color: "#CCCCCC"
                font.pixelSize: 13
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                font.italic: true
            }
        }

        background: Rectangle {
            color: "#1A2327"
            border.color: "#009ca6"
            border.width: 2
            radius: 8
        }

        footer: Rectangle {
            width: parent.width
            height: 60
            color: "transparent"

            Row {
                spacing: 15
                anchors.centerIn: parent

                Button {
                    text: "Cancel"
                    width: 120
                    height: 40
                    background: Rectangle {
                        color: "#1A2327"
                        border.color: "#009ca6"
                        border.width: 1
                        radius: 6
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#FFFFFF"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 14
                    }
                    onClicked: {
                        deleteGameDialog.close();
                        gameToDelete = -1;
                    }
                }

                Button {
                    text: "Delete"
                    width: 120
                    height: 40
                    background: Rectangle {
                        color: "#d2232b"
                        border.color: "#d2232b"
                        border.width: 1
                        radius: 6
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#FFFFFF"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 14
                        font.bold: true
                    }
                    onClicked: {
                        if (gameToDelete >= 0) {
                            // Remove the game from the current level
                            let currentLevel = gamesParser.levels[levelTabBar.currentIndex];
                            if (currentLevel) {
                                let gameTypes = gameTypeTabs.getGameTypes();
                                if (gameTypes.length > 0 && gameTypeTabs.selectedGameType < gameTypes.length) {
                                    let selectedGame = gameTypes[gameTypeTabs.selectedGameType];

                                    // Remove from appropriate game array based on type
                                    if (selectedGame.type === "Quiz" && currentLevel.quizGames) {
                                        currentLevel.quizGames.splice(gameToDelete, 1);
                                    } else if (selectedGame.type === "Memory" && currentLevel.memoryGames) {
                                        currentLevel.memoryGames.splice(gameToDelete, 1);
                                    } else if (selectedGame.type === "Order" && currentLevel.orderGames) {
                                        currentLevel.orderGames.splice(gameToDelete, 1);
                                    } else if (selectedGame.type === "Selector" && currentLevel.selectorGames) {
                                        currentLevel.selectorGames.splice(gameToDelete, 1);
                                    } else if (selectedGame.type === "Builder" && currentLevel.builderGames) {
                                        currentLevel.builderGames.splice(gameToDelete, 1);
                                    } else if (selectedGame.type === "Crosspuzzle" && currentLevel.crosspuzzleGames) {
                                        currentLevel.crosspuzzleGames.splice(gameToDelete, 1);
                                    } else if (selectedGame.type === "Race" && currentLevel.raceGames) {
                                        currentLevel.raceGames.splice(gameToDelete, 1);
                                    }

                                    console.log(selectedGame.type + " game", gameToDelete + 1, "deleted");

                                    // Emit change signal to update UI
                                    gamesParser.levelsChanged();

                                    // Select the first remaining tab after deletion
                                    Qt.callLater(function () {
                                        let remainingGameTypes = gameTypeTabs.getGameTypes();
                                        if (remainingGameTypes.length > 0) {
                                            gameTypeTabs.selectedGameType = 0;
                                        }
                                    });
                                }
                            }
                        }

                        deleteGameDialog.close();
                        gameToDelete = -1;
                    }
                }
            }
        }
    }

    // Level deletion confirmation dialog
    Dialog {
        id: deleteLevelDialog
        title: "Delete Level"
        modal: true
        anchors.centerIn: parent
        width: 400
        height: 250

        // Custom header
        header: Rectangle {
            width: parent.width
            height: 50
            color: "#1A2327"
            border.color: "#009ca6"
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "Delete Level"
                color: "#FFFFFF"
                font.pixelSize: 18
                font.bold: true
            }
        }

        contentItem: Column {
            spacing: 25
            anchors.fill: parent
            anchors.margins: 25

            // Warning icon area
            Rectangle {
                width: 60
                height: 60
                radius: 30
                color: "#d2232b"
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    anchors.centerIn: parent
                    text: "!"
                    color: "#FFFFFF"
                    font.pixelSize: 32
                    font.bold: true
                }
            }

            Text {
                text: "Are you sure you want to delete this level?"
                color: "#FFFFFF"
                font.pixelSize: 16
                anchors.horizontalCenter: parent.horizontalCenter
                wrapMode: Text.WordWrap
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                text: "This action cannot be undone."
                color: "#CCCCCC"
                font.pixelSize: 13
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                font.italic: true
            }
        }

        background: Rectangle {
            color: "#1A2327"
            border.color: "#009ca6"
            border.width: 2
            radius: 8
        }

        footer: Rectangle {
            width: parent.width
            height: 60
            color: "transparent"

            Row {
                spacing: 15
                anchors.centerIn: parent

                Button {
                    text: "Cancel"
                    width: 120
                    height: 40
                    background: Rectangle {
                        color: "#1A2327"
                        border.color: "#009ca6"
                        border.width: 1
                        radius: 6
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#FFFFFF"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 14
                    }
                    onClicked: {
                        deleteLevelDialog.close();
                        levelToDelete = -1;
                    }
                }

                Button {
                    text: "Delete"
                    width: 120
                    height: 40
                    background: Rectangle {
                        color: "#d2232b"
                        border.color: "#d2232b"
                        border.width: 1
                        radius: 6
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#FFFFFF"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 14
                        font.bold: true
                    }
                    onClicked: {
                        if (levelToDelete >= 0) {
                            // Remove the level from the levels array
                            gamesParser.levels.splice(levelToDelete, 1);

                            console.log("Level", levelToDelete + 1, "deleted");

                            // Emit change signal to update UI
                            gamesParser.levelsChanged();

                            // Select the first remaining level after deletion
                            Qt.callLater(function () {
                                if (gamesParser.levels.length > 0) {
                                    levelTabBar.currentIndex = 0;
                                }
                            });
                        }

                        deleteLevelDialog.close();
                        levelToDelete = -1;
                    }
                }
            }
        }
    }

    // Custom footer
    footer: Rectangle {
        width: parent.width
        height: 50
        color: "#1A2327"

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Button {
                text: "Cancel"
                width: 120
                height: 40
                background: Rectangle {
                    color: "#1A2327"
                    border.color: "#009ca6"
                    border.width: 1
                    radius: 4
                }
                contentItem: Text {
                    text: parent.text
                    color: "#FFFFFF"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    // Show close confirmation dialog instead of directly closing
                    closeConfirmationDialog.open();
                }
            }

            Button {
                text: "Save"
                width: 120
                height: 40
                background: Rectangle {
                    color: "#1A2327"
                    border.color: "#009ca6"
                    border.width: 1
                    radius: 4
                }
                contentItem: Text {
                    text: parent.text
                    color: "#FFFFFF"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    // Save games to JSON file
                    if (!gamesParser.saveToFile()) {
                        console.error("Failed to save games.json");
                    } else {
                        console.log("Games saved successfully");
                    }
                    gamesDialog.accept();
                }
            }
        }
    }

    background: Rectangle {
        color: "#1A2327"
        border.color: "#009ca6"
        border.width: 2
        radius: 0
    }

    contentItem: ColumnLayout {
        spacing: 10
        anchors.fill: parent
        anchors.margins: 0

        // Title bar
        Rectangle {
            Layout.fillWidth: true
            height: 40
            color: "#1A2327"
            border.color: "#009ca6"
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "Game Editor"
                color: "#FFFFFF"
                font.pixelSize: 16
                font.bold: true
            }

            // Save button
            Rectangle {
                id: saveButton
                width: 40
                height: 30
                radius: 4
                color: "#009ca6"
                anchors {
                    right: parent.right
                    rightMargin: 10
                    verticalCenter: parent.verticalCenter
                }

                // Save (Disk) Icon
                Canvas {
                    id: saveIcon
                    anchors.centerIn: parent
                    width: 16
                    height: 16

                    onPaint: {
                        var ctx = getContext("2d");

                        // Clear canvas
                        ctx.reset();

                        // Draw floppy disk icon
                        ctx.fillStyle = "white";

                        // Main body of the disk
                        ctx.beginPath();
                        ctx.rect(0, 0, 16, 16);
                        ctx.fill();

                        // Inner rectangle (label area)
                        ctx.fillStyle = "#009ca6";
                        ctx.beginPath();
                        ctx.rect(2, 2, 12, 4);
                        ctx.fill();

                        // Bottom part (disk slot)
                        ctx.fillStyle = "#009ca6";
                        ctx.beginPath();
                        ctx.rect(3, 8, 10, 6);
                        ctx.fill();

                        // Small rectangle (metal slider)
                        ctx.fillStyle = "white";
                        ctx.beginPath();
                        ctx.rect(11, 9, 1, 4);
                        ctx.fill();
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        // Save games.json file
                        if (gamesParser.saveToFile()) {
                            console.log("Games saved successfully to games.json");

                            // Show a brief save confirmation
                            saveConfirmation.visible = true;
                            saveConfirmationTimer.restart();
                        } else {
                            console.error("Failed to save games.json");
                        }
                    }
                }
            }

            // Save confirmation message
            Rectangle {
                id: saveConfirmation
                width: 150
                height: 30
                radius: 4
                color: "#4CAF50"  // Green color
                visible: false
                anchors {
                    right: saveButton.left
                    rightMargin: 10
                    verticalCenter: parent.verticalCenter
                }

                Text {
                    anchors.centerIn: parent
                    text: "Saved successfully!"
                    color: "white"
                    font.pixelSize: 12
                    font.bold: true
                }

                // Timer to hide the confirmation message
                Timer {
                    id: saveConfirmationTimer
                    interval: 2000  // 2 seconds
                    onTriggered: {
                        saveConfirmation.visible = false;
                    }
                }
            }
        }

        // Level tabs
        Rectangle {
            id: levelTabsContainer
            Layout.fillWidth: true
            height: 50
            color: "#1A2327"
            border.color: "#009ca6"
            border.width: 0
            Layout.leftMargin: 10
            Layout.rightMargin: 10

            Row {
                id: levelTabs
                height: parent.height
                spacing: 2

                Repeater {
                    model: gamesParser.levels

                    Rectangle {
                        id: tabRect
                        width: 80
                        height: parent.height
                        color: levelTabBar.currentIndex === index ? "#009ca6" : "#1A2327"
                        border.color: "#009ca6"
                        border.width: 1
                        radius: 4

                        Text {
                            anchors.centerIn: parent
                            text: modelData.level
                            color: "#FFFFFF"
                            font.bold: levelTabBar.currentIndex === index
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: levelTabBar.currentIndex = index
                        }

                        // Close button
                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: "red"

                            anchors {
                                right: parent.right
                                top: parent.top
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: "white"
                                font.pixelSize: 16
                            }

                            MouseArea {
                                anchors.fill: parent
                                z: 1
                                onClicked: {
                                    // Select this level first
                                    levelTabBar.currentIndex = index;

                                    // Set the level to delete
                                    levelToDelete = index;
                                    deleteLevelDialog.open();
                                }
                            }
                        }
                    }
                }

                // Add new level button
                Rectangle {
                    width: 50
                    height: parent.height
                    color: "#1A2327"
                    border.color: "#009ca6"
                    border.width: 1
                    radius: 4

                    Text {
                        anchors.centerIn: parent
                        text: "+"
                        color: "#FFFFFF"
                        font.pixelSize: 24
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            // Add new level functionality
                            var newLevel = gamesParser.createLevel(gamesParser.levels.length + 1, "Module " + (gamesParser.levels.length + 1));
                            levelTabBar.currentIndex = gamesParser.levels.length - 1;
                        }
                    }
                }
            }

            // Invisible TabBar to track current index
            TabBar {
                id: levelTabBar
                visible: false
                currentIndex: 0

                Repeater {
                    model: gamesParser.levels
                    TabButton {}
                }
            }
        }

        // Module name
        Rectangle {
            Layout.fillWidth: true
            height: 50
            color: "#1A2327"
            Layout.leftMargin: 10
            Layout.rightMargin: 10

            RowLayout {
                anchors.fill: parent
                spacing: 10

                Text {
                    text: "Module Name:"
                    color: "#FFFFFF"
                    font.pixelSize: 14
                    Layout.preferredWidth: 100
                }

                TextField {
                    id: moduleNameField
                    Layout.fillWidth: true
                    text: gamesParser.levels[levelTabBar.currentIndex] ? gamesParser.levels[levelTabBar.currentIndex].title : ""
                    color: "#FFFFFF"
                    //placeholderText: "Enter module name"
                    background: Rectangle {
                        color: "#232f34"
                        border.color: "#009ca6"
                        border.width: 1
                        radius: 4
                    }

                    onTextChanged: {
                        if (gamesParser.levels[levelTabBar.currentIndex]) {
                            gamesParser.levels[levelTabBar.currentIndex].title = text;
                        }
                    }
                }
            }
        }

        // Games section
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#232f34"
            border.color: "#009ca6"
            border.width: 1
            radius: 0
            Layout.leftMargin: 10
            Layout.rightMargin: 10
            Layout.bottomMargin: 55 // - Removed to extend to footer

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                // Games header
                Text {
                    text: "Games"
                    color: "#FFFFFF"
                    font.pixelSize: 16
                    font.bold: true
                }

                // Game types
                Flow {
                    id: gameTypeTabs
                    Layout.fillWidth: true
                    spacing: 10
                    height: 50

                    property int selectedGameType: 0

                    // Game types available in the current level
                    function getGameTypes() {
                        if (!gamesParser.levels[levelTabBar.currentIndex])
                            return [];

                        let types = [];
                        let level = gamesParser.levels[levelTabBar.currentIndex];

                        // Add all Quiz games
                        if (level.quizGames && level.quizGames.length > 0) {
                            for (let i = 0; i < level.quizGames.length; i++) {
                                types.push({
                                    type: "Quiz",
                                    games: [level.quizGames[i]]
                                });
                            }
                        }

                        // Add all Race games
                        if (level.raceGames && level.raceGames.length > 0) {
                            for (let i = 0; i < level.raceGames.length; i++) {
                                types.push({
                                    type: "Race",
                                    games: [level.raceGames[i]]
                                });
                            }
                        }

                        // Add all Memory games
                        if (level.memoryGames && level.memoryGames.length > 0) {
                            for (let i = 0; i < level.memoryGames.length; i++) {
                                types.push({
                                    type: "Memory",
                                    games: [level.memoryGames[i]]
                                });
                            }
                        }

                        // Add all Order games
                        if (level.orderGames && level.orderGames.length > 0) {
                            for (let i = 0; i < level.orderGames.length; i++) {
                                types.push({
                                    type: "Order",
                                    games: [level.orderGames[i]]
                                });
                            }
                        }

                        // Add all Selector games
                        if (level.selectorGames && level.selectorGames.length > 0) {
                            for (let i = 0; i < level.selectorGames.length; i++) {
                                types.push({
                                    type: "Selector",
                                    games: [level.selectorGames[i]]
                                });
                            }
                        }

                        // Add all Builder games
                        if (level.builderGames && level.builderGames.length > 0) {
                            for (let i = 0; i < level.builderGames.length; i++) {
                                types.push({
                                    type: "Builder",
                                    games: [level.builderGames[i]]
                                });
                            }
                        }

                        // Add all Crosspuzzle games
                        if (level.crosspuzzleGames && level.crosspuzzleGames.length > 0) {
                            for (let i = 0; i < level.crosspuzzleGames.length; i++) {
                                types.push({
                                    type: "Crosspuzzle",
                                    games: [level.crosspuzzleGames[i]]
                                });
                            }
                        }

                        return types;
                    }

                    Repeater {
                        model: gameTypeTabs.getGameTypes()

                        Rectangle {
                            width: 120  // Increased width to accommodate count
                            height: 40
                            color: gameTypeTabs.selectedGameType === index ? "#009ca6" : "#1A2327"
                            border.color: "#009ca6"
                            border.width: 1
                            radius: 4

                            Text {
                                anchors.centerIn: parent
                                text: {
                                    let gameType = modelData.type;
                                    let questionCount = 0;

                                    if (modelData.games && modelData.games.length > 0) {
                                        if (gameType === "Quiz" && modelData.games[0].questions) {
                                            questionCount = modelData.games[0].questions.length;
                                        } else if (gameType === "Memory" && modelData.games[0].questions) {
                                            questionCount = modelData.games[0].questions.length;
                                        } else if (gameType === "Order" && modelData.games[0].questions) {
                                            questionCount = modelData.games[0].questions.length;
                                        } else if (gameType === "Selector" && modelData.games[0].questions) {
                                            questionCount = modelData.games[0].questions.length;
                                        } else if (gameType === "Builder" && modelData.games[0].questions) {
                                            questionCount = modelData.games[0].questions.length;
                                        } else if (gameType === "Crosspuzzle" && modelData.games[0].questions) {
                                            questionCount = modelData.games[0].questions.length;
                                        } else if (gameType === "Race" && modelData.games[0].questions) {
                                            questionCount = modelData.games[0].questions.length;
                                        }
                                    }

                                    // Add game number to distinguish multiple games of same type
                                    let gameNumber = "";
                                    if (gameType === "Quiz") {
                                        gameNumber = " #" + (index + 1);
                                    } else if (gameType === "Race") {
                                        gameNumber = " #" + (index + 1);
                                    } else if (gameType === "Memory") {
                                        gameNumber = " #" + (index + 1);
                                    } else if (gameType === "Order") {
                                        gameNumber = " #" + (index + 1);
                                    } else if (gameType === "Selector") {
                                        gameNumber = " #" + (index + 1);
                                    } else if (gameType === "Builder") {
                                        gameNumber = " #" + (index + 1);
                                    } else if (gameType === "Crosspuzzle") {
                                        gameNumber = " #" + (index + 1);
                                    }

                                    return gameType + gameNumber + "(" + questionCount + ")";
                                }
                                color: "#FFFFFF"
                                font.bold: gameTypeTabs.selectedGameType === index
                                font.pixelSize: 12
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: gameTypeTabs.selectedGameType = index
                            }

                            // Close button
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                color: "red"
                                anchors {
                                    right: parent.right
                                    top: parent.top
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "×"
                                    color: "white"
                                    font.pixelSize: 16
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        // Select this tab first
                                        gameTypeTabs.selectedGameType = index;

                                        // Get the actual game index from the gameTypes array
                                        let gameTypes = gameTypeTabs.getGameTypes();
                                        if (gameTypes.length > index) {
                                            let selectedGame = gameTypes[index];
                                            let currentLevel = gamesParser.levels[levelTabBar.currentIndex];

                                            // Find the actual index in the level's game array
                                            let actualIndex = -1;
                                            if (selectedGame.type === "Quiz" && currentLevel.quizGames) {
                                                actualIndex = currentLevel.quizGames.indexOf(selectedGame.games[0]);
                                            } else if (selectedGame.type === "Memory" && currentLevel.memoryGames) {
                                                actualIndex = currentLevel.memoryGames.indexOf(selectedGame.games[0]);
                                            } else if (selectedGame.type === "Order" && currentLevel.orderGames) {
                                                actualIndex = currentLevel.orderGames.indexOf(selectedGame.games[0]);
                                            } else if (selectedGame.type === "Selector" && currentLevel.selectorGames) {
                                                actualIndex = currentLevel.selectorGames.indexOf(selectedGame.games[0]);
                                            } else if (selectedGame.type === "Builder" && currentLevel.builderGames) {
                                                actualIndex = currentLevel.builderGames.indexOf(selectedGame.games[0]);
                                            } else if (selectedGame.type === "Crosspuzzle" && currentLevel.crosspuzzleGames) {
                                                actualIndex = currentLevel.crosspuzzleGames.indexOf(selectedGame.games[0]);
                                            } else if (selectedGame.type === "Race" && currentLevel.raceGames) {
                                                actualIndex = currentLevel.raceGames.indexOf(selectedGame.games[0]);
                                            }

                                            gameToDelete = actualIndex;
                                            deleteGameDialog.open();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Add new game type button
                    Rectangle {
                        width: 50
                        height: 40
                        color: "#1A2327"
                        border.color: "#009ca6"
                        border.width: 1
                        radius: 4

                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            color: "#FFFFFF"
                            font.pixelSize: 24
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                // Add new game type dialog
                                addGameTypeDialog.open();
                            }
                        }

                        // Add new game type dialog
                        Dialog {
                            id: addGameTypeDialog
                            title: "Add New Game"
                            modal: true
                            anchors.centerIn: parent
                            width: 400
                            height: 500

                            // Custom header
                            header: Rectangle {
                                width: parent.width
                                height: 50
                                color: "#1A2327"
                                border.color: "#009ca6"
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: "Add New Game"
                                    color: "#FFFFFF"
                                    font.pixelSize: 18
                                    font.bold: true
                                }
                            }

                            contentItem: Column {
                                spacing: 15
                                anchors.fill: parent
                                anchors.margins: 25

                                Text {
                                    text: "Select a game type to add:"
                                    color: "#FFFFFF"
                                    font.pixelSize: 16
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    horizontalAlignment: Text.AlignHCenter
                                }

                                // Game type buttons
                                Grid {
                                    columns: 2
                                    spacing: 15
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    // Quiz Button
                                    Rectangle {
                                        width: 150
                                        height: 60
                                        color: "#1A2327"
                                        border.color: "#009ca6"
                                        border.width: 2
                                        radius: 8

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Quiz"
                                            color: "#FFFFFF"
                                            font.pixelSize: 16
                                            font.bold: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                if (gamesParser.levels[levelTabBar.currentIndex]) {
                                                    let game = gamesParser.createQuizGame();
                                                    gamesParser.addQuizGameToLevel(gamesParser.levels[levelTabBar.currentIndex], game);
                                                }
                                                addGameTypeDialog.close();
                                            }
                                        }
                                    }

                                    // Race Button
                                    Rectangle {
                                        width: 150
                                        height: 60
                                        color: "#1A2327"
                                        border.color: "#009ca6"
                                        border.width: 2
                                        radius: 8

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Race"
                                            color: "#FFFFFF"
                                            font.pixelSize: 16
                                            font.bold: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                if (gamesParser.levels[levelTabBar.currentIndex]) {
                                                    let game = gamesParser.createRaceGame();
                                                    gamesParser.addRaceGameToLevel(gamesParser.levels[levelTabBar.currentIndex], game);
                                                }
                                                addGameTypeDialog.close();
                                            }
                                        }
                                    }

                                    // Memory Button
                                    Rectangle {
                                        width: 150
                                        height: 60
                                        color: "#1A2327"
                                        border.color: "#009ca6"
                                        border.width: 2
                                        radius: 8

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Memory"
                                            color: "#FFFFFF"
                                            font.pixelSize: 16
                                            font.bold: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                if (gamesParser.levels[levelTabBar.currentIndex]) {
                                                    let game = gamesParser.createMemoryGame();
                                                    gamesParser.addMemoryGameToLevel(gamesParser.levels[levelTabBar.currentIndex], game);
                                                }
                                                addGameTypeDialog.close();
                                            }
                                        }
                                    }

                                    // Order Button
                                    Rectangle {
                                        width: 150
                                        height: 60
                                        color: "#1A2327"
                                        border.color: "#009ca6"
                                        border.width: 2
                                        radius: 8

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Order"
                                            color: "#FFFFFF"
                                            font.pixelSize: 16
                                            font.bold: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                if (gamesParser.levels[levelTabBar.currentIndex]) {
                                                    let game = gamesParser.createOrderGame();
                                                    gamesParser.addOrderGameToLevel(gamesParser.levels[levelTabBar.currentIndex], game);
                                                }
                                                addGameTypeDialog.close();
                                            }
                                        }
                                    }

                                    // Selector Button
                                    Rectangle {
                                        width: 150
                                        height: 60
                                        color: "#1A2327"
                                        border.color: "#009ca6"
                                        border.width: 2
                                        radius: 8

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Selector"
                                            color: "#FFFFFF"
                                            font.pixelSize: 16
                                            font.bold: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                if (gamesParser.levels[levelTabBar.currentIndex]) {
                                                    let game = gamesParser.createSelectorGame();
                                                    gamesParser.addSelectorGameToLevel(gamesParser.levels[levelTabBar.currentIndex], game);
                                                }
                                                addGameTypeDialog.close();
                                            }
                                        }
                                    }

                                    // Builder Button
                                    Rectangle {
                                        width: 150
                                        height: 60
                                        color: "#1A2327"
                                        border.color: "#009ca6"
                                        border.width: 2
                                        radius: 8

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Builder"
                                            color: "#FFFFFF"
                                            font.pixelSize: 16
                                            font.bold: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                if (gamesParser.levels[levelTabBar.currentIndex]) {
                                                    let game = gamesParser.createBuilderGame();
                                                    gamesParser.addBuilderGameToLevel(gamesParser.levels[levelTabBar.currentIndex], game);
                                                }
                                                addGameTypeDialog.close();
                                            }
                                        }
                                    }

                                    // Crosspuzzle Button
                                    Rectangle {
                                        width: 150
                                        height: 60
                                        color: "#1A2327"
                                        border.color: "#009ca6"
                                        border.width: 2
                                        radius: 8

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Crosspuzzle"
                                            color: "#FFFFFF"
                                            font.pixelSize: 16
                                            font.bold: true
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: {
                                                if (gamesParser.levels[levelTabBar.currentIndex]) {
                                                    let game = gamesParser.createCrosspuzzleGame();
                                                    gamesParser.addCrosspuzzleGameToLevel(gamesParser.levels[levelTabBar.currentIndex], game);
                                                }
                                                addGameTypeDialog.close();
                                            }
                                        }
                                    }
                                }
                            }

                            background: Rectangle {
                                color: "#1A2327"
                                border.color: "#009ca6"
                                border.width: 2
                                radius: 8
                            }

                            footer: Rectangle {
                                width: parent.width
                                height: 60
                                color: "transparent"

                                Row {
                                    spacing: 15
                                    anchors.centerIn: parent

                                    Button {
                                        text: "Cancel"
                                        width: 120
                                        height: 40
                                        background: Rectangle {
                                            color: "#1A2327"
                                            border.color: "#009ca6"
                                            border.width: 1
                                            radius: 6
                                        }
                                        contentItem: Text {
                                            text: parent.text
                                            color: "#FFFFFF"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            font.pixelSize: 14
                                        }
                                        onClicked: addGameTypeDialog.close()
                                    }
                                }
                            }
                        }
                    }
                }

                // Game content area
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    // Quiz questions ListView
                    ListView {
                        id: quizQuestionsListView
                        anchors.fill: parent
                        visible: {
                            let gameTypes = gameTypeTabs.getGameTypes();
                            if (gameTypes.length === 0 || gameTypeTabs.selectedGameType >= gameTypes.length) {
                                return false;
                            }
                            let selectedGame = gameTypes[gameTypeTabs.selectedGameType];
                            return selectedGame && selectedGame.type === "Quiz" && selectedGame.games.length > 0;
                        }

                        model: {
                            return currentQuizGame ? currentQuizGame.questions : [];
                        }

                        // Enable mouse wheel scrolling
                        flickableDirection: Flickable.VerticalFlick
                        boundsBehavior: Flickable.StopAtBounds

                        // Mouse wheel support
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: function (wheel) {
                                if (wheel.angleDelta.y > 0) {
                                    quizQuestionsListView.contentY = Math.max(0, quizQuestionsListView.contentY - 120);
                                } else {
                                    let maxContentY = Math.max(0, quizQuestionsListView.contentHeight - quizQuestionsListView.height);
                                    quizQuestionsListView.contentY = Math.min(maxContentY, quizQuestionsListView.contentY + 120);
                                }
                            }
                        }

                        delegate: Item {
                            width: quizQuestionsListView.width
                            height: quizQuestionsListView.height * 0.4

                            QuizQuestionCard {
                                width: parent ? parent.width * 0.75 : 600  // Safe fallback
                                height: parent ? parent.height : 300      // Safe fallback
                                anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined

                                // Set question ID (index + 1 for 1-based numbering)
                                questionId: index + 1

                                // Quiz question data binding - use modelData directly
                                quizQuestion: modelData

                                // Handle option addition
                                onOptionAdded: {
                                    if (modelData) {
                                        // Check maximum limit (5 options)
                                        if (modelData.answers.length >= 5) {
                                            console.log("Maximum 5 options allowed per question");
                                            return;
                                        }

                                        // Create new answer using gamesParser
                                        let newAnswer = gamesParser.createQuizAnswer("", false);

                                        // Add to question using gamesParser method
                                        gamesParser.addAnswerToQuestion(modelData, newAnswer);

                                        console.log("New option added to question", index + 1, "Total options:", modelData.answers.length + 1);
                                    }
                                }

                                // Handle option deletion
                                onOptionDeleted: function (optionIndex) {
                                    if (modelData) {
                                        // Check minimum limit (3 options)
                                        if (modelData.answers.length <= 3) {
                                            console.log("Minimum 3 options required per question");
                                            return;
                                        }

                                        // Remove answer using gamesParser method
                                        gamesParser.removeAnswerFromQuestion(modelData, optionIndex);

                                        console.log("Option", optionIndex + 1, "deleted from question", index + 1, "Total options:", modelData.answers.length - 1);
                                    }
                                }

                                // Handle question deletion
                                onQuestionDeleted: {
                                    if (currentQuizGame) {
                                        questionToDelete = index; // Set the question index to delete
                                        deleteQuestionDialog.open();
                                    }
                                }
                            }
                        }

                        spacing: 10
                        clip: true

                        // Add bottom padding to ensure last item is fully visible
                        bottomMargin: 20

                        // Footer item for Add New Question button
                        footer: Item {
                            width: parent.width
                            height: 60

                            Rectangle {
                                id: addNewQuestionBtn
                                width: parent.width * 0.75
                                height: 50
                                radius: 6
                                color: "#009ca6" // Turquoise background
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    text: "Add New Question"
                                    anchors.centerIn: parent
                                    color: "white"
                                    font.pixelSize: 16
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        print("Add New Question");
                                        if (currentQuizGame) {
                                            // Create new question using gamesParser with default 3 answers
                                            let newQuestion = gamesParser.createQuizQuestion("", "");

                                            // Add to quiz game using gamesParser method
                                            gamesParser.addQuestionToGame(currentQuizGame, newQuestion);

                                            console.log("New question added. Total questions:", currentQuizGame.questions.length);

                                            // Scroll to bottom to show new question
                                            Qt.callLater(function () {
                                                quizQuestionsListView.positionViewAtEnd();
                                            });
                                        }
                                    }
                                }
                            }
                        }

                        // Scroll indicators
                        ScrollBar.vertical: ScrollBar {
                            active: true
                            policy: ScrollBar.AsNeeded
                        }
                    }

                    // Memory questions ListView
                    ListView {
                        id: memoryQuestionsListView
                        anchors.fill: parent
                        visible: {
                            let gameTypes = gameTypeTabs.getGameTypes();
                            if (gameTypes.length === 0 || gameTypeTabs.selectedGameType >= gameTypes.length) {
                                return false;
                            }
                            let selectedGame = gameTypes[gameTypeTabs.selectedGameType];
                            return selectedGame && selectedGame.type === "Memory" && selectedGame.games.length > 0;
                        }

                        model: {
                            let gameTypes = gameTypeTabs.getGameTypes();
                            if (gameTypes.length === 0 || gameTypeTabs.selectedGameType >= gameTypes.length) {
                                return [];
                            }
                            let selectedGame = gameTypes[gameTypeTabs.selectedGameType];
                            if (selectedGame && selectedGame.type === "Memory" && selectedGame.games.length > 0) {
                                return selectedGame.games[0].questions;
                            }
                            return [];
                        }

                        // Enable mouse wheel scrolling
                        flickableDirection: Flickable.VerticalFlick
                        boundsBehavior: Flickable.StopAtBounds

                        // Mouse wheel support
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: function (wheel) {
                                if (wheel.angleDelta.y > 0) {
                                    memoryQuestionsListView.contentY = Math.max(0, memoryQuestionsListView.contentY - 120);
                                } else {
                                    let maxContentY = Math.max(0, memoryQuestionsListView.contentHeight - memoryQuestionsListView.height);
                                    memoryQuestionsListView.contentY = Math.min(maxContentY, memoryQuestionsListView.contentY + 120);
                                }
                            }
                        }

                        delegate: Item {
                            width: memoryQuestionsListView.width
                            height: memoryQuestionsListView.height * 0.4

                            MemoryQuestionCard {
                                width: parent ? parent.width * 0.75 : 600  // Safe fallback
                                height: parent ? parent.height : 300      // Safe fallback
                                anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined

                                // Set question ID (index + 1 for 1-based numbering)
                                questionId: index + 1

                                // Memory question data binding
                                memoryQuestion: modelData

                                // Handle question deletion
                                onQuestionDeleted: {
                                    if (currentMemoryGame) {
                                        questionToDelete = index;
                                        deleteQuestionDialog.open();
                                    }
                                }
                            }
                        }

                        spacing: 10
                        clip: true

                        // Add bottom padding to ensure last item is fully visible
                        bottomMargin: 20

                        // Footer item for Add New Question button
                        footer: Item {
                            width: parent.width
                            height: 60

                            Rectangle {
                                id: addNewMemoryQuestionBtn
                                width: parent.width * 0.75
                                height: 50
                                radius: 6
                                color: "#009ca6" // Turquoise background
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    text: "Add New Memory Card"
                                    anchors.centerIn: parent
                                    color: "white"
                                    font.pixelSize: 16
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        print("Add New Memory Question");
                                        if (currentMemoryGame) {
                                            // Create new memory question using gamesParser
                                            let newQuestion = gamesParser.createMemoryQuestion("");

                                            // Add to memory game using gamesParser method
                                            gamesParser.addQuestionToMemoryGame(currentMemoryGame, newQuestion);

                                            console.log("New memory question added. Total questions:", currentMemoryGame.questions.length);

                                            // Scroll to bottom to show new question
                                            Qt.callLater(function () {
                                                memoryQuestionsListView.positionViewAtEnd();
                                            });
                                        }
                                    }
                                }
                            }
                        }

                        // Scroll indicators
                        ScrollBar.vertical: ScrollBar {
                            active: true
                            policy: ScrollBar.AsNeeded
                        }
                    }

                    // Order questions ListView
                    ListView {
                        id: orderQuestionsListView
                        anchors.fill: parent
                        visible: {
                            let gameTypes = gameTypeTabs.getGameTypes();
                            if (gameTypes.length === 0 || gameTypeTabs.selectedGameType >= gameTypes.length) {
                                return false;
                            }
                            let selectedGame = gameTypes[gameTypeTabs.selectedGameType];
                            return selectedGame && selectedGame.type === "Order" && selectedGame.games.length > 0;
                        }

                        model: {
                            let gameTypes = gameTypeTabs.getGameTypes();
                            if (gameTypes.length === 0 || gameTypeTabs.selectedGameType >= gameTypes.length) {
                                return [];
                            }
                            let selectedGame = gameTypes[gameTypeTabs.selectedGameType];
                            if (selectedGame && selectedGame.type === "Order" && selectedGame.games.length > 0) {
                                return selectedGame.games[0].questions;
                            }
                            return [];
                        }

                        // Enable mouse wheel scrolling
                        flickableDirection: Flickable.VerticalFlick
                        boundsBehavior: Flickable.StopAtBounds

                        // Mouse wheel support
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: function (wheel) {
                                if (wheel.angleDelta.y > 0) {
                                    orderQuestionsListView.contentY = Math.max(0, orderQuestionsListView.contentY - 120);
                                } else {
                                    let maxContentY = Math.max(0, orderQuestionsListView.contentHeight - orderQuestionsListView.height);
                                    orderQuestionsListView.contentY = Math.min(maxContentY, orderQuestionsListView.contentY + 120);
                                }
                            }
                        }

                        delegate: Item {
                            width: orderQuestionsListView.width
                            height: orderQuestionsListView.height * 0.4

                            OrderQuestionCard {
                                width: parent ? parent.width * 0.75 : 600  // Safe fallback
                                height: parent ? parent.height : 300      // Safe fallback
                                anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined

                                // Set question ID (index + 1 for 1-based numbering)
                                questionId: index + 1

                                // Order question data binding
                                orderQuestion: modelData

                                // Handle question deletion
                                onQuestionDeleted: {
                                    if (currentOrderGame) {
                                        questionToDelete = index;
                                        deleteQuestionDialog.open();
                                    }
                                }
                            }
                        }

                        spacing: 10
                        clip: true

                        // Add bottom padding to ensure last item is fully visible
                        bottomMargin: 20

                        // Footer item for Add New Question button
                        footer: Item {
                            width: parent.width
                            height: 60

                            Rectangle {
                                id: addNewOrderQuestionBtn
                                width: parent.width * 0.75
                                height: 50
                                radius: 6
                                color: "#009ca6" // Turquoise background
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    text: "Add New Order Question"
                                    anchors.centerIn: parent
                                    color: "white"
                                    font.pixelSize: 16
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        print("Add New Order Question");
                                        if (currentOrderGame) {
                                            // Create new order question using gamesParser
                                            let newQuestion = gamesParser.createOrderQuestion([]);

                                            // Add to order game using gamesParser method
                                            gamesParser.addQuestionToOrderGame(currentOrderGame, newQuestion);

                                            console.log("New order question added. Total questions:", currentOrderGame.questions.length);

                                            // Scroll to bottom to show new question
                                            Qt.callLater(function () {
                                                orderQuestionsListView.positionViewAtEnd();
                                            });
                                        }
                                    }
                                }
                            }
                        }

                        // Scroll indicators
                        ScrollBar.vertical: ScrollBar {
                            active: true
                            policy: ScrollBar.AsNeeded
                        }
                    }

                    // Selector questions ListView
                    ListView {
                        id: selectorQuestionsListView
                        anchors.fill: parent
                        visible: {
                            let gameTypes = gameTypeTabs.getGameTypes();
                            if (gameTypes.length === 0 || gameTypeTabs.selectedGameType >= gameTypes.length) {
                                return false;
                            }
                            let selectedGame = gameTypes[gameTypeTabs.selectedGameType];
                            return selectedGame && selectedGame.type === "Selector" && selectedGame.games.length > 0;
                        }

                        model: {
                            let gameTypes = gameTypeTabs.getGameTypes();
                            if (gameTypes.length === 0 || gameTypeTabs.selectedGameType >= gameTypes.length) {
                                return [];
                            }
                            let selectedGame = gameTypes[gameTypeTabs.selectedGameType];
                            if (selectedGame && selectedGame.type === "Selector" && selectedGame.games.length > 0) {
                                return selectedGame.games[0].questions;
                            }
                            return [];
                        }

                        // Enable mouse wheel scrolling
                        flickableDirection: Flickable.VerticalFlick
                        boundsBehavior: Flickable.StopAtBounds

                        // Mouse wheel support
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: function (wheel) {
                                if (wheel.angleDelta.y > 0) {
                                    selectorQuestionsListView.contentY = Math.max(0, selectorQuestionsListView.contentY - 120);
                                } else {
                                    let maxContentY = Math.max(0, selectorQuestionsListView.contentHeight - selectorQuestionsListView.height);
                                    selectorQuestionsListView.contentY = Math.min(maxContentY, selectorQuestionsListView.contentY + 120);
                                }
                            }
                        }

                        delegate: Item {
                            width: selectorQuestionsListView.width
                            height: selectorQuestionsListView.height * 0.65  // Reduced from 0.8 to 0.65

                            SelectorQuestionCard {
                                width: parent ? parent.width * 0.75 : 600  // Safe fallback
                                height: parent ? parent.height : 400      // Safe fallback
                                anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined

                                // Set question ID (index + 1 for 1-based numbering)
                                questionId: index + 1

                                // Selector question data binding
                                selectorQuestion: modelData

                                // Handle option addition
                                onOptionAdded: {
                                    if (currentSelectorGame && modelData) {
                                        // Create new selector answer using gamesParser
                                        let newAnswer = gamesParser.createSelectorAnswer("", "", false);

                                        // Add to selector question using gamesParser method
                                        gamesParser.addAnswerToSelectorQuestion(modelData, newAnswer);

                                        console.log("New selector option added. Total options:", modelData.answers.length);
                                    }
                                }

                                // Handle option deletion
                                onOptionDeleted: function (index) {
                                    if (currentSelectorGame && modelData) {
                                        console.log("deleting Selector Option", index);
                                        gamesParser.removeAnswerFromSelectorQuestion(modelData, index);
                                        console.log("Selector option", index + 1, "deleted from question", questionId, "Total options:", modelData.answers.length);
                                    }
                                }

                                // Handle question deletion
                                onQuestionDeleted: {
                                    if (currentSelectorGame) {
                                        questionToDelete = index;
                                        deleteQuestionDialog.open();
                                    }
                                }
                            }
                        }

                        spacing: 10
                        clip: true

                        // Add bottom padding to ensure last item is fully visible
                        bottomMargin: 20

                        // Footer item for Add New Question button
                        footer: Item {
                            width: parent.width
                            height: 60

                            Rectangle {
                                id: addNewSelectorQuestionBtn
                                width: parent.width * 0.75
                                height: 50
                                radius: 6
                                color: "#009ca6" // Turquoise background
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    text: "Add New Selector Question"
                                    anchors.centerIn: parent
                                    color: "white"
                                    font.pixelSize: 16
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        print("Add New Selector Question");
                                        if (currentSelectorGame) {
                                            // Create new selector question using gamesParser
                                            let newQuestion = gamesParser.createSelectorQuestion("", "", "", "");

                                            // Add to selector game using gamesParser method
                                            gamesParser.addQuestionToSelectorGame(currentSelectorGame, newQuestion);

                                            console.log("New selector question added. Total questions:", currentSelectorGame.questions.length);

                                            // Scroll to bottom to show new question
                                            Qt.callLater(function () {
                                                selectorQuestionsListView.positionViewAtEnd();
                                            });
                                        }
                                    }
                                }
                            }
                        }

                        // Scroll indicators
                        ScrollBar.vertical: ScrollBar {
                            active: true
                            policy: ScrollBar.AsNeeded
                        }
                    }

                    // Builder questions ListView
                    ListView {
                        id: builderQuestionsListView
                        anchors.fill: parent
                        visible: {
                            let gameTypes = gameTypeTabs.getGameTypes();
                            if (gameTypes.length === 0 || gameTypeTabs.selectedGameType >= gameTypes.length) {
                                return false;
                            }
                            let selectedGame = gameTypes[gameTypeTabs.selectedGameType];
                            return selectedGame && selectedGame.type === "Builder" && selectedGame.games.length > 0;
                        }

                        model: {
                            let gameTypes = gameTypeTabs.getGameTypes();
                            if (gameTypes.length === 0 || gameTypeTabs.selectedGameType >= gameTypes.length) {
                                return [];
                            }
                            let selectedGame = gameTypes[gameTypeTabs.selectedGameType];
                            if (selectedGame && selectedGame.type === "Builder" && selectedGame.games.length > 0) {
                                return selectedGame.games[0].questions;
                            }
                            return [];
                        }

                        // Enable mouse wheel scrolling
                        flickableDirection: Flickable.VerticalFlick
                        boundsBehavior: Flickable.StopAtBounds

                        // Mouse wheel support
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: function (wheel) {
                                if (wheel.angleDelta.y > 0) {
                                    builderQuestionsListView.contentY = Math.max(0, builderQuestionsListView.contentY - 120);
                                } else {
                                    let maxContentY = Math.max(0, builderQuestionsListView.contentHeight - builderQuestionsListView.height);
                                    builderQuestionsListView.contentY = Math.min(maxContentY, builderQuestionsListView.contentY + 120);
                                }
                            }
                        }

                        delegate: Item {
                            width: builderQuestionsListView.width
                            height: builderQuestionsListView.height * 0.65

                            BuilderQuestionCard {
                                width: parent ? parent.width * 0.75 : 600  // Safe fallback
                                height: parent ? parent.height : 400      // Safe fallback
                                anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined

                                // Set question ID (index + 1 for 1-based numbering)
                                questionId: index + 1

                                // Builder question data binding
                                builderQuestion: modelData

                                // Handle question deletion
                                onQuestionDeleted: {
                                    if (currentBuilderGame) {
                                        questionToDelete = index;
                                        deleteQuestionDialog.open();
                                    }
                                }
                            }
                        }

                        spacing: 10
                        clip: true

                        // Add bottom padding to ensure last item is fully visible
                        bottomMargin: 20

                        // Footer item for Add New Question button
                        footer: Item {
                            width: parent.width
                            height: 60

                            Rectangle {
                                id: addNewBuilderQuestionBtn
                                width: parent.width * 0.75
                                height: 50
                                radius: 6
                                color: "#009ca6" // Turquoise background
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    text: "Add New Builder Question"
                                    anchors.centerIn: parent
                                    color: "white"
                                    font.pixelSize: 16
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        print("Add New Builder Question");
                                        if (currentBuilderGame) {
                                            // Create new builder question using gamesParser
                                            let newQuestion = gamesParser.createBuilderQuestion("", "", "", "", []);

                                            // Add to builder game using gamesParser method
                                            gamesParser.addQuestionToBuilderGame(currentBuilderGame, newQuestion);

                                            console.log("New builder question added. Total questions:", currentBuilderGame.questions.length);

                                            // Scroll to bottom to show new question
                                            Qt.callLater(function () {
                                                builderQuestionsListView.positionViewAtEnd();
                                            });
                                        }
                                    }
                                }
                            }
                        }

                        // Scroll indicators
                        ScrollBar.vertical: ScrollBar {
                            active: true
                            policy: ScrollBar.AsNeeded
                        }
                    }

                    // Crosspuzzle questions ListView
                    ListView {
                        id: crosspuzzleQuestionsListView
                        anchors.fill: parent
                        visible: {
                            let gameTypes = gameTypeTabs.getGameTypes();
                            if (gameTypes.length === 0 || gameTypeTabs.selectedGameType >= gameTypes.length) {
                                return false;
                            }
                            let selectedGame = gameTypes[gameTypeTabs.selectedGameType];
                            return selectedGame && selectedGame.type === "Crosspuzzle" && selectedGame.games.length > 0;
                        }

                        model: {
                            let gameTypes = gameTypeTabs.getGameTypes();
                            if (gameTypes.length === 0 || gameTypeTabs.selectedGameType >= gameTypes.length) {
                                return [];
                            }
                            let selectedGame = gameTypes[gameTypeTabs.selectedGameType];
                            if (selectedGame && selectedGame.type === "Crosspuzzle" && selectedGame.games.length > 0) {
                                return selectedGame.games[0].questions;
                            }
                            return [];
                        }

                        // Enable mouse wheel scrolling
                        flickableDirection: Flickable.VerticalFlick
                        boundsBehavior: Flickable.StopAtBounds

                        // Mouse wheel support
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: function (wheel) {
                                if (wheel.angleDelta.y > 0) {
                                    crosspuzzleQuestionsListView.contentY = Math.max(0, crosspuzzleQuestionsListView.contentY - 120);
                                } else {
                                    let maxContentY = Math.max(0, crosspuzzleQuestionsListView.contentHeight - crosspuzzleQuestionsListView.height);
                                    crosspuzzleQuestionsListView.contentY = Math.min(maxContentY, crosspuzzleQuestionsListView.contentY + 120);
                                }
                            }
                        }

                        delegate: Item {
                            width: crosspuzzleQuestionsListView.width
                            height: crosspuzzleQuestionsListView.height * 0.4  // Reduced from 0.6 to 0.4

                            CrosspuzzleQuestionCard {
                                width: parent ? parent.width * 0.75 : 600  // Safe fallback
                                height: parent ? parent.height : 250      // Reduced from 300 to 250
                                anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined

                                // Set question ID (index + 1 for 1-based numbering)
                                questionId: index + 1

                                // Crosspuzzle question data binding
                                crosspuzzleQuestion: modelData

                                // Handle question deletion
                                onQuestionDeleted: {
                                    if (currentCrosspuzzleGame) {
                                        questionToDelete = index;
                                        deleteQuestionDialog.open();
                                    }
                                }
                            }
                        }

                        spacing: 10
                        clip: true

                        // Add bottom padding to ensure last item is fully visible
                        bottomMargin: 20

                        // Footer item for Add New Question button
                        footer: Item {
                            width: parent.width
                            height: 60

                            Rectangle {
                                id: addNewCrosspuzzleQuestionBtn
                                width: parent.width * 0.75
                                height: 50
                                radius: 6
                                color: "#009ca6" // Turquoise background
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    text: "Add New Crosspuzzle Question"
                                    anchors.centerIn: parent
                                    color: "white"
                                    font.pixelSize: 16
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        print("Add New Crosspuzzle Question");
                                        if (currentCrosspuzzleGame) {
                                            // Create new crosspuzzle question using gamesParser
                                            let newQuestion = gamesParser.createCrosspuzzleQuestion("");

                                            // Add a default answer to the question
                                            let defaultAnswer = gamesParser.createCrosspuzzleAnswer("");
                                            gamesParser.addAnswerToCrosspuzzleQuestion(newQuestion, defaultAnswer);

                                            // Add to crosspuzzle game using gamesParser method
                                            gamesParser.addQuestionToCrosspuzzleGame(currentCrosspuzzleGame, newQuestion);

                                            console.log("New crosspuzzle question added. Total questions:", currentCrosspuzzleGame.questions.length);

                                            // Scroll to bottom to show new question
                                            Qt.callLater(function () {
                                                crosspuzzleQuestionsListView.positionViewAtEnd();
                                            });
                                        }
                                    }
                                }
                            }
                        }

                        // Scroll indicators
                        ScrollBar.vertical: ScrollBar {
                            active: true
                            policy: ScrollBar.AsNeeded
                        }
                    }

                    // Race questions ListView
                    ListView {
                        id: raceQuestionsListView
                        anchors.fill: parent
                        visible: {
                            let gameTypes = gameTypeTabs.getGameTypes();
                            if (gameTypes.length === 0 || gameTypeTabs.selectedGameType >= gameTypes.length) {
                                return false;
                            }
                            let selectedGame = gameTypes[gameTypeTabs.selectedGameType];
                            return selectedGame && selectedGame.type === "Race" && selectedGame.games.length > 0;
                        }

                        model: {
                            let gameTypes = gameTypeTabs.getGameTypes();
                            if (gameTypes.length === 0 || gameTypeTabs.selectedGameType >= gameTypes.length) {
                                return [];
                            }
                            let selectedGame = gameTypes[gameTypeTabs.selectedGameType];
                            if (selectedGame && selectedGame.type === "Race" && selectedGame.games.length > 0) {
                                return selectedGame.games[0].questions;
                            }
                            return [];
                        }

                        // Enable mouse wheel scrolling
                        flickableDirection: Flickable.VerticalFlick
                        boundsBehavior: Flickable.StopAtBounds

                        // Mouse wheel support
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.NoButton
                            onWheel: function (wheel) {
                                if (wheel.angleDelta.y > 0) {
                                    raceQuestionsListView.contentY = Math.max(0, raceQuestionsListView.contentY - 120);
                                } else {
                                    let maxContentY = Math.max(0, raceQuestionsListView.contentHeight - raceQuestionsListView.height);
                                    raceQuestionsListView.contentY = Math.min(maxContentY, raceQuestionsListView.contentY + 120);
                                }
                            }
                        }

                        delegate: Item {
                            width: raceQuestionsListView.width
                            height: raceQuestionsListView.height * 0.65

                            RaceQuestionCard {
                                width: parent ? parent.width * 0.75 : 600  // Safe fallback
                                height: parent ? parent.height : 400      // Safe fallback
                                anchors.horizontalCenter: parent ? parent.horizontalCenter : undefined

                                // Set question ID (index + 1 for 1-based numbering)
                                questionId: index + 1

                                // Race question data binding
                                raceQuestion: modelData

                                // Handle question deletion
                                onQuestionDeleted: {
                                    if (currentRaceGame) {
                                        questionToDelete = index;
                                        deleteQuestionDialog.open();
                                    }
                                }
                            }
                        }

                        spacing: 10
                        clip: true

                        // Add bottom padding to ensure last item is fully visible
                        bottomMargin: 20

                        // Footer item for Add New Question button
                        footer: Item {
                            width: parent.width
                            height: 60

                            Rectangle {
                                id: addNewRaceQuestionBtn
                                width: parent.width * 0.75
                                height: 50
                                radius: 6
                                color: "#009ca6" // Turquoise background
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    text: "Add New Race Question"
                                    anchors.centerIn: parent
                                    color: "white"
                                    font.pixelSize: 16
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        print("Add New Race Question");
                                        if (currentRaceGame) {
                                            // Create new race question using gamesParser
                                            let newQuestion = gamesParser.createRaceQuestion("", "", "");

                                            // Add to race game using gamesParser method
                                            gamesParser.addQuestionToRaceGame(currentRaceGame, newQuestion);

                                            console.log("New race question added. Total questions:", currentRaceGame.questions.length);

                                            // Scroll to bottom to show new question
                                            Qt.callLater(function () {
                                                raceQuestionsListView.positionViewAtEnd();
                                            });
                                        }
                                    }
                                }
                            }
                        }

                        // Scroll indicators
                        ScrollBar.vertical: ScrollBar {
                            active: true
                            policy: ScrollBar.AsNeeded
                        }
                    }

                    // Default content for non-quiz games or empty states
                    Rectangle {
                        anchors.fill: parent
                        color: "#1A2327"
                        border.color: "#009ca6"
                        border.width: 1
                        radius: 4
                        visible: !quizQuestionsListView.visible && !memoryQuestionsListView.visible && !orderQuestionsListView.visible && !selectorQuestionsListView.visible && !builderQuestionsListView.visible && !crosspuzzleQuestionsListView.visible && !raceQuestionsListView.visible

                        Text {
                            anchors.centerIn: parent
                            text: {
                                let gameTypes = gameTypeTabs.getGameTypes();
                                if (gameTypes.length === 0 || gameTypeTabs.selectedGameType >= gameTypes.length) {
                                    return "No questions available";
                                }

                                let selectedGame = gameTypes[gameTypeTabs.selectedGameType];
                                if (selectedGame && selectedGame.games.length > 0) {
                                    let questionsCount = selectedGame.games[0].questions.length;
                                    return questionsCount + " Questions";
                                }

                                return "No questions available";
                            }
                            color: "#FFFFFF"
                            font.pixelSize: 24
                            font.bold: true
                        }
                    }
                }
            }
        }
    }

    // Close confirmation dialog
    Dialog {
        id: closeConfirmationDialog
        title: "Close Game Editor"
        modal: true
        anchors.centerIn: parent
        width: 400
        height: 250

        // Custom header
        header: Rectangle {
            width: parent.width
            height: 50
            color: "#1A2327"
            border.color: "#009ca6"
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "Close Game Editor"
                color: "#FFFFFF"
                font.pixelSize: 18
                font.bold: true
            }
        }

        contentItem: Column {
            spacing: 25
            anchors.fill: parent
            anchors.margins: 25

            // Warning icon area
            Rectangle {
                width: 60
                height: 60
                radius: 30
                color: "#d2232b"
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    anchors.centerIn: parent
                    text: "!"
                    color: "#FFFFFF"
                    font.pixelSize: 32
                    font.bold: true
                }
            }

            Text {
                text: "Are you sure you want to close the Game Editor?"
                color: "#FFFFFF"
                font.pixelSize: 16
                anchors.horizontalCenter: parent.horizontalCenter
                wrapMode: Text.WordWrap
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                text: "Any unsaved changes will be lost."
                color: "#CCCCCC"
                font.pixelSize: 13
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                font.italic: true
            }
        }

        background: Rectangle {
            color: "#1A2327"
            border.color: "#009ca6"
            border.width: 2
            radius: 8
        }

        footer: Rectangle {
            width: parent.width
            height: 60
            color: "transparent"

            Row {
                spacing: 15
                anchors.centerIn: parent

                Button {
                    text: "Cancel"
                    width: 120
                    height: 40
                    background: Rectangle {
                        color: "#1A2327"
                        border.color: "#009ca6"
                        border.width: 1
                        radius: 6
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#FFFFFF"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 14
                    }
                    onClicked: closeConfirmationDialog.close()
                }

                Button {
                    text: "Save & Close"
                    width: 120
                    height: 40
                    background: Rectangle {
                        color: "#009ca6"
                        border.color: "#009ca6"
                        border.width: 1
                        radius: 6
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#FFFFFF"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 14
                        font.bold: true
                    }
                    onClicked: {
                        // Save and close
                        if (gamesParser.saveToFile()) {
                            console.log("Games saved successfully before closing");
                        } else {
                            console.error("Failed to save games.json before closing");
                        }
                        closeConfirmationDialog.close();
                        gamesDialog.close();
                    }
                }

                Button {
                    text: "Close"
                    width: 120
                    height: 40
                    background: Rectangle {
                        color: "#d2232b"
                        border.color: "#d2232b"
                        border.width: 1
                        radius: 6
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#FFFFFF"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 14
                        font.bold: true
                    }
                    onClicked: {
                        closeConfirmationDialog.close();
                        gamesDialog.close();
                    }
                }
            }
        }
    }
}
