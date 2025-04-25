import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform

import "groupboxes"

Rectangle {
    property var page: undefined
    property var section: undefined
    property int sectionIndex

    property var audioModelData: undefined
    property var videoModelData: undefined
    property var activityModelData: undefined
    property var fillModelData: undefined
    property var fillList: []
    property int fillIndex
    property bool audioVisible: false
    property bool videoVisible: false
    property bool activityVisible: false
    property bool fillVisible: false


    property bool circleVisible: false
    property var circleList: undefined
    property int circleIndex


    color: "#131111"
    id: root

    // FileDialog bileşeni
    FileDialog {
        id: fileDialog
        title: "Select a File"
        //folder: StandardPaths.home // Varsayılan başlangıç yolu, değiştirilecektir

        onAccepted: {
            console.log("Selected file: " + fileDialog.file)
            selectedFile = fileDialog.file
        }

        onRejected: {
            console.log("File selection was canceled")
        }
    }

    ActivityGroupBox {
        id: activityGB
        visible: root.activityVisible
        activityModelData: root.activityModelData

        onRemoveSection: {
            page.removeSection(sectionIndex)

            config.bookSets[0].saveToJson();
            toast.show("Changes are saved to File Activity GroupBox On remove Section!")
        }
    }

    FillGroupBox {
        id: rectangesGB
        visible: root.fillVisible
        fillList: root.fillList
        page: root.page
        sectionIndex: root.sectionIndex
        fillIndex: root.fillIndex

        onRemoveSection: {
            page.removeSection(secIndex)
            config.bookSets[0].saveToJson();
            toast.show("Changes are saved to File!")
        }

        onRemoveAnswer: {
            root.section.removeAnswer(answerIndex)
            config.bookSets[0].saveToJson();
            toast.show("Answer Removed!")

            root.fillList = root.section.answers
        }
    }

    CircleGroupBox {
        id: circleGB
        visible: root.circleVisible
        circleList: root.circleList
        page: root.page
        sectionIndex: root.sectionIndex
        circleIndex: root.circleIndex

        onRemoveSection: {
            page.removeSection(secIndex)
            config.bookSets[0].saveToJson();
            toast.show("Changes are saved to File!")
        }

        onRemoveAnswer: {
            root.section.removeAnswer(answerIndex)
            config.bookSets[0].saveToJson();
            toast.show("Answer Removed!")

            root.fillList = root.section.answers
        }
    }

    AudioGroupBox {
        id: audioGB
        visible: root.audioVisible
        audioModelData: root.audioModelData
        sectionIndex: root.sectionIndex
        onRemoveSection: {
            page.removeSection(secIndex)

            config.bookSets[0].saveToJson();
            toast.show("Changes are saved to File!")
        }
    }

    VideoGroupBox {
        id: videoGB
        visible: root.videoVisible
        videoModelData: root.videoModelData
        sectionIndex: root.sectionIndex
        onRemoveSection: {
            page.removeSection(secIndex)

            config.bookSets[0].saveToJson();
            toast.show("Changes are saved to File!")
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
        print(pathParts)

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

            var newPath = "./"
            for (booksIndex; booksIndex < pathParts.length; booksIndex++) {
                newPath += pathParts[booksIndex] + "/"
            }

            if (newPath.length > 0) {
                newPath =  newPath.substring(0, newPath.length - 1);
            }
            return newPath;
        }

        // "books" klasörü bulunamazsa null döndür
        return null;
    }

    function hideAllComponent() {
        audioVisible = false
        videoVisible = false
        activityVisible = false
        fillVisible = false
        circleVisible = false
    }
}



