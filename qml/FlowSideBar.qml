import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform

import "groupboxes"

Rectangle {
    id: root
    property var page: undefined
    property var section: undefined
    property int sectionIndex

    // Default to empty objects so child bindings like X.type === "..."
    // return false (not undefined) before a section is selected. Avoids
    // dozens of startup-time "Cannot read property" errors.
    property var audioModelData: ({})
    property var videoModelData: ({})
    property var activityModelData: ({})
    property var sectionModelData: ({})
    property var fillModelData: ({})
    property var fillList: []
    property int fillIndex
    // Page <-> sidebar shared multi-selection of fill answer objects
    // (rubber-band / Ctrl+click on the page, checkboxes in the Fill panel).
    property var fillSelection: []
    property bool audioVisible: false
    property bool videoVisible: false
    property bool activityVisible: false
    property bool fillVisible: false
    property bool circleVisible: false
    property bool fillwColorVisible: false
    property bool drawMatchedVisible: false
    property var circleList: undefined
    property int circleIndex
    property var fillWColorList: []
    property var drawMatchedLineList: []

    color: "#1A2327" // Dark background


    function saveRemains() {
        if (activityVisible) {
            activityGB.saveRemains()
        }
    }

    // Space shortcut: open the activity, or play/pause audio/video,
    // depending on which panel is currently shown.
    function triggerSpace() {
        if (activityVisible)
            activityGB.openActivityDialog();
        else if (audioVisible)
            audioGB.togglePlay();
        else if (videoVisible)
            videoGB.togglePlay();
    }

    // FileDialog bileşeni
    FileDialog {
        id: fileDialog
        title: "Select a File"
        //folder: StandardPaths.home // Varsayılan başlangıç yolu, değiştirilecektir

        onAccepted: {
            console.log("Selected file: " + fileDialog.file);
            selectedFile = fileDialog.file;
        }

        onRejected: {
            console.log("File selection was canceled");
        }
    }

    ActivityGroupBox {
        id: activityGB
        visible: root.activityVisible
        activityModelData: root.activityModelData
        sectionModelData: root.sectionModelData
        width: parent.width * .98
        height: parent.height / 5 * 4.5

        onRemoveSection: {
            // Drop the sidebar's reference to this activity BEFORE deleting it,
            // so the still-open activity panel never keeps binding to a
            // now-deleted object — that dangling bind froze the canvas (no page
            // nav, no re-selecting another activity) after a delete.
            root.activityVisible = false;
            root.activityModelData = null;
            root.sectionModelData = null;
            page.removeSection(sectionIndex);
        }
    }

    FillGroupBox {
        id: rectangesGB
        visible: root.fillVisible
        fillList: root.fillList
        page: root.page
        sectionIndex: root.sectionIndex
        fillIndex: root.fillIndex
        width: parent.width * .98
        height: parent.height / 5 * 4.5

        onRemoveSection: {
            page.removeSection(secIndex);
        }

        onRemoveAnswer: {
            root.section.removeAnswer(answerIndex);
            root.fillList = root.section.answers;
        }
    }

    CircleGroupBox {
        id: circleGB
        visible: root.circleVisible
        circleList: root.circleList
        page: root.page
        sectionIndex: root.sectionIndex
        circleIndex: root.circleIndex
        width: parent.width * .98
        height: parent.height / 3 * 2

        onRemoveSection: {
            page.removeSection(secIndex);
        }

        onRemoveAnswer: {
            root.section.removeAnswer(answerIndex);
            root.circleList = root.section.answers;
        }
    }

    AudioGroupBox {
        id: audioGB
        visible: root.audioVisible
        audioModelData: root.audioModelData
        sectionIndex: root.sectionIndex
        width: parent.width * .98
        height: parent.height / 3 * 2
        onRemoveSection: {
            page.removeSection(secIndex);
        }
    }

    VideoGroupBox {
        id: videoGB
        visible: root.videoVisible
        videoModelData: root.videoModelData
        sectionIndex: root.sectionIndex
        width: parent.width * .98
        height: parent.height / 3 * 2
        onRemoveSection: {
            page.removeSection(secIndex);
        }
    }

    FillWithColorGroupBox {
        id: fillwColorGB
        visible: root.fillwColorVisible
        fillList: root.fillWColorList
        page: root.page
        sectionIndex: root.sectionIndex
        fillIndex: root.fillIndex
        width: parent.width * .98
        height: parent.height / 3 * 2

        onRemoveSection: {
            page.removeSection(secIndex);
        }

        onRemoveAnswer: {
            root.section.removeAnswer(answerIndex);
            root.fillWColorList = root.section.answers;
        }
    }

    DrawMatchedLineGroupBox {
        id: drawMatchedLineGB
        visible: root.drawMatchedVisible
        drawMatchedLineList: root.drawMatchedLineList
        page: root.page
        sectionIndex: root.sectionIndex
        fillIndex: root.fillIndex
        width: parent.width * .98
        height: parent.height / 3 * 2

        onRemoveSection: {
            page.removeSection(secIndex);
        }

        onRemoveAnswer: {
            root.section.removeAnswer(answerIndex);

            root.drawMatchedLineList = root.section.answers;
        }
    }

    function findBooksFolder(filePath, targetFolder) {
        // filePath'in boş olup olmadığını kontrol edelim
        // if (!filePath || typeof filePath !== 'string') {
        //     console.log("Geçersiz dosya yolu.");
        //     return null;
        // }

        // Yol parçalarını ayır
        var pathParts = filePath.split("/");
        print(pathParts);

        // "books" klasörünü bulana kadar yukarı doğru çık
        var booksIndex = -1;
        for (var i = pathParts.length - 1; i >= 0; i--) {
            if (pathParts[i] === targetFolder) {
                booksIndex = i;
                break;
            }
        }

        // Eğer "books" klasörü bulunursa, yeni yolu oluştur
        if (booksIndex !== -1) {
            var newPath = "./";
            for (booksIndex; booksIndex < pathParts.length; booksIndex++) {
                newPath += pathParts[booksIndex] + "/";
            }

            if (newPath.length > 0) {
                newPath = newPath.substring(0, newPath.length - 1);
            }
            return newPath;
        }

        // "books" klasörü bulunamazsa null döndür
        return null;
    }

    function hideAllComponent() {
        audioVisible = false;
        videoVisible = false;
        activityVisible = false;
        fillVisible = false;
        circleVisible = false;
        fillwColorVisible = false;
        drawMatchedVisible = false;

        activityGB.saveRemains()
    }

}
