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

    property var audioModelData: undefined
    property var videoModelData: undefined
    property var activityModelData: undefined
    property var sectionModelData: undefined
    property var fillModelData: undefined
    property var fillList: []
    property int fillIndex
    property bool audioVisible: false
    property bool videoVisible: false
    property bool activityVisible: false
    property bool fillVisible: false
    property bool circleVisible: false
    property bool fillwColorVisible: value
    property bool drawMatchedVisible: value
    property var circleList: undefined
    property int circleIndex
    property var fillWColorList: []
    property var drawMatchedLineList: []

    color: "#1A2327" // Dark background

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
            page.removeSection(sectionIndex);

            config.bookSets[0].saveToJson();
            toast.show("Changes are saved to File Activity GroupBox On remove Section!");
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
        height: parent.height / 3 * 2

        onRemoveSection: {
            page.removeSection(secIndex);
            config.bookSets[0].saveToJson();
            toast.show("Changes are saved to File!");
        }

        onRemoveAnswer: {
            root.section.removeAnswer(answerIndex);
            config.bookSets[0].saveToJson();
            toast.show("Answer Removed!");

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
            config.bookSets[0].saveToJson();
            toast.show("Changes are saved to File!");
        }

        onRemoveAnswer: {
            root.section.removeAnswer(answerIndex);
            config.bookSets[0].saveToJson();
            toast.show("Answer Removed!");

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

            config.bookSets[0].saveToJson();
            toast.show("Changes are saved to File!");
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

            config.bookSets[0].saveToJson();
            toast.show("Changes are saved to File!");
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
            config.bookSets[0].saveToJson();
            toast.show("Changes are saved to File!");
        }

        onRemoveAnswer: {
            root.section.removeAnswer(answerIndex);
            config.bookSets[0].saveToJson();
            toast.show("Answer Removed!");

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
            config.bookSets[0].saveToJson();
            toast.show("Changes are saved to File!");
        }

        onRemoveAnswer: {
            root.section.removeAnswer(answerIndex);
            config.bookSets[0].saveToJson();
            toast.show("Answer Removed!");

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
    }
}
