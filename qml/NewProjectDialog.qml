import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Dialog {
    id: root
    property var additionalFiles: []

    title: "New project"
    modal: true
    closePolicy: Popup.NoAutoClose // Prevents dialog from closing when clicking outside
    anchors.centerIn: parent

    // Custom header
    header: Rectangle {
        color: "#1A2327"
        height: parent.height * .07
        border.color: "#009ca6"
        border.width: 1

        Label {
            text: "New project"
            color: "white"
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            font.pixelSize: 16
            font.bold: true
        }
    }

    // Custom footer for buttons
    footer: Rectangle {
        id: footRect
        color: "#1A2327"
        height: parent.height * .07
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
                Layout.preferredHeight: footRect.height * 0.6

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

            Button {
                text: "OK"
                Layout.preferredWidth: 80
                Layout.preferredHeight: footRect.height * 0.6
                enabled: isPdfValid

                background: Rectangle {
                    color: parent.enabled ? (parent.hovered ? "#2A3337" : "#1A2327") : "darkgray"
                    border.color: "#009ca6"
                    border.width: 1
                    radius: 2
                }

                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? "white" : "black"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: root.accept()
            }
        }
    }

    background: Rectangle {
        color: "#232f34"
        border.color: "#009ca6"
        border.width: 1
        radius: 4
    }

    property string selectedPdfPath: ""
    property bool isPdfValid: false

    // Reset function to clear all form fields
    function resetForm() {
        pdfPathTextField.text = "";
        selectedPdfPath = "";
        isPdfValid = false;
        publisherNameEdit.text = "";
        bookTitleEdit.text = "";
        languageComboBox.currentIndex = 0;
        coverPathTextField.text = "";
        audioFolderTextField.text = "";
        videoFolderTextField.text = "";
        outputEdit.text = appPath + "books";
        modulesModel.clear();

        // Sadece tek bir modül ekle
        modulesModel.append({
            name: "Module 1",
            startPage: "1",
            endPage: "10"
        });
    }

    // File dialog for selecting files
    FileDialog {
        id: pdfFileDialog
        title: "Select Book PDF"
        nameFilters: ["PDF files (*.pdf)"]
        onAccepted: {
            selectedPdfPath = selectedFile;
            pdfPathTextField.text = selectedFile.toString().replace("file://", "");
            validatePdf();
        }
    }

    FileDialog {
        id: coverFileDialog
        title: "Select Book Cover"
        nameFilters: ["Image files (*.jpg *.jpeg *.png)"]
        onAccepted: {
            coverPathTextField.text = selectedFile.toString().replace("file://", "");
        }
    }

    FolderDialog {
        id: audioFolderDialog
        title: "Select Audio Folder"
        onAccepted: {
            audioFolderTextField.text = selectedFolder.toString().replace("file://", "");
        }
    }

    FolderDialog {
        id: videoFolderDialog
        title: "Select Video Folder"
        onAccepted: {
            videoFolderTextField.text = selectedFolder.toString().replace("file://", "");
        }
    }

    FolderDialog {
        id: outputDialog
        title: "Select OutPut Folder"
        onAccepted: {
            outputEdit.text = selectedFolder.toString().replace("file://", "");
        }
    }

    // Birden fazla dosya seçmek için dialog
    FileDialog {
        id: additionalFilesDialog
        title: "Select Additional Files"
        fileMode: FileDialog.OpenFiles // Birden fazla dosya seçimi

        // Son seçilen klasörü kullan
        currentFolder: lastSelectedFolder !== "" ? "file://" + lastSelectedFolder : StandardPaths.standardLocations(StandardPaths.DocumentsLocation)[0]

        onAccepted: {
            // Seçilen dosyaları additionalFiles modeline ekle
            var newFiles = [];
            for (var i = 0; i < additionalFiles.length; i++) {
                newFiles.push(additionalFiles[i]);
            }

            for (var j = 0; j < selectedFiles.length; j++) {
                var fileUrl = selectedFiles[j];
                var filePath = fileUrl.toString().replace(/^(file:\/{2})/, "");

                // Windows için düzeltme
                if (Qt.platform.os === "windows") {
                    filePath = filePath.replace(/^\//, "");
                }

                // Son '/' karakterinden sonraki kısmı dosya adı olarak al
                var fileName = filePath.substring(filePath.lastIndexOf('/') + 1);
                if (fileName === "") {
                    // Windows için backslash kontrolü
                    fileName = filePath.substring(filePath.lastIndexOf('\\') + 1);
                }

                newFiles.push({
                    fileUrl: fileUrl,
                    filePath: filePath,
                    fileName: fileName
                });
            }

            additionalFiles = newFiles;
            console.log("Additional files:", additionalFiles.length);
        }
    }

    // Function to validate PDF
    function validatePdf() {
        // Here we would check if the PDF is valid
        // For now, we'll just set it to true if a file is selected
        isPdfValid = selectedPdfPath !== "";
    }

    // Main content area
    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // PDF Selection
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Label {
                text: "Select BookPdf"
                Layout.preferredWidth: 120
                color: "white"
            }

            TextField {
                id: pdfPathTextField
                Layout.fillWidth: true
                readOnly: false
                placeholderText: "pdf path"
                placeholderTextColor: "gray"
                color: "white"
                background: Rectangle {
                    color: "#1A2327"
                    border.color: "#009ca6"
                    border.width: 1
                    radius: 2
                }
            }

            Button {
                text: "..."
                onClicked: pdfFileDialog.open()
                background: Rectangle {
                    color: "#1A2327"
                    border.color: "#009ca6"
                    border.width: 1
                    radius: 2
                }
                contentItem: Text {
                    text: "..."
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: parent.background.color = "#2A3337"
                    onExited: parent.background.color = "#1A2327"
                    onPressed: parent.background.color = "#0A1317"
                    onReleased: parent.background.color = containsMouse ? "#2A3337" : "#1A2327"
                    onClicked: pdfFileDialog.open()
                }
            }
        }

        // This part will be visible when selected PDF is valid
        Rectangle {
            id: validPdfContent
            Layout.fillWidth: true
            Layout.preferredHeight: root.height * 0.8
            visible: isPdfValid
            border.width: 1
            border.color: "#009ca6"
            color: "#232f34"
            radius: 4

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 5
                spacing: 1

                // Publisher Name
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    Label {
                        text: "Publisher Name"
                        Layout.preferredWidth: 120
                        color: "white"
                    }

                    TextField {
                        id: publisherNameEdit
                        Layout.fillWidth: true
                        readOnly: false
                        placeholderText: "publisher name"
                        placeholderTextColor: "gray"
                        color: "white"
                        background: Rectangle {
                            color: "#1A2327"
                            border.color: "#009ca6"
                            border.width: 1
                            radius: 2
                        }
                    }
                }

                // Book Title
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Label {
                        text: "Book Title"
                        Layout.preferredWidth: 120
                        color: "white"
                    }

                    TextField {
                        id: bookTitleEdit
                        Layout.fillWidth: true
                        readOnly: false
                        placeholderText: "book title"
                        placeholderTextColor: "gray"
                        color: "white"
                        background: Rectangle {
                            color: "#1A2327"
                            border.color: "#009ca6"
                            border.width: 1
                            radius: 2
                        }
                    }
                }

                // Language
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Label {
                        text: "Language"
                        Layout.preferredWidth: 120
                        color: "white"
                    }

                    ComboBox {
                        id: languageComboBox
                        Layout.fillWidth: true
                        model: ["en", "tr", "de"]
                        currentIndex: 0 // Default en

                        background: Rectangle {
                            color: "#1A2327"
                            border.color: "#009ca6"
                            border.width: 1
                            radius: 2
                        }

                        contentItem: Text {
                            text: languageComboBox.displayText
                            color: "white"
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 10
                        }

                        popup: Popup {
                            y: languageComboBox.height
                            width: languageComboBox.width
                            implicitHeight: contentItem.implicitHeight
                            padding: 1

                            contentItem: ListView {
                                clip: true
                                implicitHeight: contentHeight
                                model: languageComboBox.popup.visible ? languageComboBox.delegateModel : null

                                ScrollIndicator.vertical: ScrollIndicator {}
                            }

                            background: Rectangle {
                                color: "#1A2327"
                                border.color: "#009ca6"
                                border.width: 1
                            }
                        }

                        delegate: ItemDelegate {
                            width: languageComboBox.width
                            contentItem: Text {
                                text: modelData
                                color: "white"
                                verticalAlignment: Text.AlignVCenter
                            }
                            highlighted: languageComboBox.highlightedIndex === index
                            background: Rectangle {
                                color: highlighted ? "#2A3337" : "#1A2327"
                            }
                        }
                    }
                }

                // Book Cover
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Label {
                        text: "Book Cover"
                        Layout.preferredWidth: 120
                        color: "white"
                    }

                    TextField {
                        id: coverPathTextField
                        Layout.fillWidth: true
                        readOnly: false
                        placeholderText: "cover image"
                        placeholderTextColor: "gray"
                        color: "white"
                        background: Rectangle {
                            color: "#1A2327"
                            border.color: "#009ca6"
                            border.width: 1
                            radius: 2
                        }
                    }

                    Button {
                        text: "..."
                        onClicked: coverFileDialog.open()
                        background: Rectangle {
                            color: "#1A2327"
                            border.color: "#009ca6"
                            border.width: 1
                            radius: 2
                        }
                        contentItem: Text {
                            text: "..."
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: parent.background.color = "#2A3337"
                            onExited: parent.background.color = "#1A2327"
                            onPressed: parent.background.color = "#0A1317"
                            onReleased: parent.background.color = containsMouse ? "#2A3337" : "#1A2327"
                            onClicked: coverFileDialog.open()
                        }
                    }
                }

                // Audio
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Label {
                        text: "Audio"
                        Layout.preferredWidth: 120
                        color: "white"
                    }

                    TextField {
                        id: audioFolderTextField
                        Layout.fillWidth: true
                        readOnly: false
                        placeholderText: "folder"
                        placeholderTextColor: "gray"
                        color: "white"
                        background: Rectangle {
                            color: "#1A2327"
                            border.color: "#009ca6"
                            border.width: 1
                            radius: 2
                        }
                    }

                    Button {
                        text: "..."

                        background: Rectangle {
                            color: "#1A2327"
                            border.color: "#009ca6"
                            border.width: 1
                            radius: 2
                        }
                        contentItem: Text {
                            text: "..."
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: parent.background.color = "#2A3337"
                            onExited: parent.background.color = "#1A2327"
                            onPressed: parent.background.color = "#0A1317"
                            onReleased: parent.background.color = containsMouse ? "#2A3337" : "#1A2327"
                            onClicked: {
                                audioFolderDialog.currentFolder = selectedPdfPath.replace("file://", "");
                                audioFolderDialog.open();
                            }
                        }
                    }
                }

                // Video
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Label {
                        text: "Video"
                        Layout.preferredWidth: 120
                        color: "white"
                    }

                    TextField {
                        id: videoFolderTextField
                        Layout.fillWidth: true
                        readOnly: false
                        placeholderText: "folder"
                        placeholderTextColor: "gray"
                        color: "white"
                        background: Rectangle {
                            color: "#1A2327"
                            border.color: "#009ca6"
                            border.width: 1
                            radius: 2
                        }
                    }

                    Button {
                        text: "..."
                        onClicked: videoFolderDialog.open()
                        background: Rectangle {
                            color: "#1A2327"
                            border.color: "#009ca6"
                            border.width: 1
                            radius: 2
                        }
                        contentItem: Text {
                            text: "..."
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: parent.background.color = "#2A3337"
                            onExited: parent.background.color = "#1A2327"
                            onPressed: parent.background.color = "#0A1317"
                            onReleased: parent.background.color = containsMouse ? "#2A3337" : "#1A2327"
                            onClicked: {
                                videoFolderDialog.currentFolder = selectedPdfPath.replace("file://", "");
                                videoFolderDialog.open();
                            }
                        }
                    }
                }

                // Publisher Name
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Label {
                        text: "Output Folder"
                        Layout.preferredWidth: 120
                        color: "white"
                    }

                    TextField {
                        id: outputEdit
                        Layout.fillWidth: true
                        readOnly: false
                        placeholderText: "Output Path"
                        placeholderTextColor: "gray"
                        color: "white"
                        text: appPath + "books"

                        background: Rectangle {
                            color: "#1A2327"
                            border.color: "#009ca6"
                            border.width: 1
                            radius: 2
                        }
                    }

                    Button {
                        text: "..."
                        onClicked: outputDialog.open()
                        background: Rectangle {
                            color: "#1A2327"
                            border.color: "#009ca6"
                            border.width: 1
                            radius: 2
                        }
                        contentItem: Text {
                            text: "..."
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: parent.background.color = "#2A3337"
                            onExited: parent.background.color = "#1A2327"
                            onPressed: parent.background.color = "#0A1317"
                            onReleased: parent.background.color = containsMouse ? "#2A3337" : "#1A2327"
                            onClicked: outputDialog.open()
                        }
                    }
                }
                /*
                // Ayrıştırıcı
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#009ca6"
                }

                // Ek dosyalar başlığı
                Label {
                    text: "Additional Files"
                    font.bold: true
                    color: "white"
                }

                // Dosya seçme butonu ve seçilen dosyaları gösterecek liste
                RowLayout {
                    Layout.fillWidth: true

                    Button {
                        text: "Select Files"
                        Layout.preferredWidth: 120
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
                        onClicked: additionalFilesDialog.open()
                    }

                    // "Clear All" butonu
                    Button {
                        text: "Clear All"
                        visible: additionalFiles.length > 0
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
                        onClicked: {
                            additionalFiles = []
                        }
                    }

                    // Seçilen dosya sayısını gösteren etiket
                    Label {
                        text: additionalFiles.length > 0 ? additionalFiles.length + " file(s) selected" : "No files selected"
                        color: "white"
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                    }
                }


                // Seçilen dosyaları gösteren liste
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(150, additionalFilesList.contentHeight + 10)
                    color: "#1A2327"
                    border.color: "#009ca6"
                    border.width: 1
                    visible: additionalFiles.length > 0

                    ListView {
                        id: additionalFilesList
                        anchors.fill: parent
                        anchors.margins: 5
                        model: additionalFiles
                        clip: true

                        ScrollBar.vertical: ScrollBar {}

                        delegate: RowLayout {
                            width: additionalFilesList.width
                            spacing: 5

                            // Dosya adı
                            Label {
                                text: modelData.fileName
                                color: "white"
                                Layout.fillWidth: true
                                elide: Text.ElideMiddle
                            }

                            // Silme ikonu
                            Button {
                                text: "✕"
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
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
                                onClicked: {
                                    var newFiles = [];
                                    for (var i = 0; i < additionalFiles.length; i++) {
                                        if (i !== index) {
                                            newFiles.push(additionalFiles[i]);
                                        }
                                    }
                                    additionalFiles = newFiles;
                                }
                            }
                        }
                    }
                }
                */
                // Modules and Pages section
                Rectangle {
                    id: moduleRect
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: parent.height * 0.35
                    Layout.topMargin: 5
                    border.width: 1
                    border.color: "#009ca6"
                    color: "#1A2327"
                    radius: 4

                    ColumnLayout {
                        id: colm
                        anchors.fill: parent
                        anchors.margins: 5
                        spacing: 2

                        // Headers
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            Label {
                                text: "Modules Name"
                                Layout.preferredWidth: colm.width / 2
                                horizontalAlignment: Text.AlignHCenter
                                font.bold: true
                                font.pixelSize: 16
                                color: "white"
                            }

                            Label {
                                text: "Pages"
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                font.bold: true
                                font.pixelSize: 16
                                color: "white"
                            }
                        }

                        // Module rows list
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.topMargin: 5
                            Layout.bottomMargin: 5

                            ListView {
                                id: modulesList
                                anchors.fill: parent
                                clip: true
                                spacing: -5

                                // ScrollBar ekleyelim
                                ScrollBar.vertical: ScrollBar {
                                    id: modulesScrollBar
                                    active: true
                                    policy: ScrollBar.AsNeeded
                                }

                                model: ListModel {
                                    id: modulesModel
                                }

                                delegate: RowLayout {
                                    width: modulesList.width - (modulesScrollBar.visible ? modulesScrollBar.width + 5 : 0)
                                    height: 35
                                    spacing: 2

                                    TextField {
                                        text: model.name
                                        Layout.preferredWidth: 200
                                        placeholderText: "Enter Module Name"
                                        placeholderTextColor: "gray"
                                        onTextChanged: model.name = text
                                        color: "white"
                                        background: Rectangle {
                                            color: "#1A2327"
                                            border.color: "#009ca6"
                                            border.width: 1
                                            radius: 2
                                        }
                                    }

                                    TextField {
                                        text: model.startPage
                                        Layout.preferredWidth: 70
                                        horizontalAlignment: Text.AlignHCenter
                                        validator: IntValidator {
                                            bottom: 1
                                        }
                                        onTextChanged: model.startPage = text
                                        color: "white"
                                        background: Rectangle {
                                            color: "#1A2327"
                                            border.color: "#009ca6"
                                            border.width: 1
                                            radius: 2
                                        }
                                    }

                                    Label {
                                        text: "—"
                                        horizontalAlignment: Text.AlignHCenter
                                        Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                                        Layout.preferredWidth: 15
                                        color: "white"
                                    }

                                    TextField {
                                        text: model.endPage
                                        Layout.preferredWidth: 70
                                        horizontalAlignment: Text.AlignHCenter
                                        validator: IntValidator {
                                            bottom: 1
                                        }
                                        onTextChanged: model.endPage = text
                                        color: "white"
                                        background: Rectangle {
                                            color: "#1A2327"
                                            border.color: "#009ca6"
                                            border.width: 1
                                            radius: 2
                                        }
                                    }

                                    Button {
                                        text: "X"
                                        width: 25
                                        height: 25
                                        visible: modulesModel.count > 1
                                        onClicked: {
                                            modulesModel.remove(index);
                                        }
                                        background: Rectangle {
                                            color: "#1A2327"
                                            border.color: "#009ca6"
                                            border.width: 1
                                            radius: 2
                                        }
                                        contentItem: Text {
                                            text: "X"
                                            color: "white"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                            font.pixelSize: 12
                                            font.bold: true
                                        }
                                    }
                                }
                            }
                        }

                        // Add button
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: moduleRect * 0.3
                            Layout.topMargin: 10

                            Button {
                                id: addModuleButton
                                anchors.centerIn: parent
                                text: "+"
                                width: 240 // Buton genişliğini daha fazla artırdık
                                height: 20
                                onClicked: {
                                    // Son eklenen modülün bilgilerini alalım
                                    var lastIndex = modulesModel.count - 1;
                                    var lastName = modulesModel.get(lastIndex).name;
                                    var lastEndPage = modulesModel.get(lastIndex).endPage;

                                    // Yeni modül adını hazırlayalım
                                    var newName = "";
                                    var namePrefix = "";
                                    var nameNumber = 1;

                                    // Önceki modül adından sayı ve prefix ayırma
                                    if (lastName.includes(" ")) {
                                        namePrefix = lastName.substring(0, lastName.lastIndexOf(" "));
                                        var lastNumber = parseInt(lastName.substring(lastName.lastIndexOf(" ") + 1));
                                        if (!isNaN(lastNumber)) {
                                            nameNumber = lastNumber + 1;
                                        }
                                        newName = namePrefix + " " + nameNumber;
                                    } else {
                                        // Eğer boşluk yoksa, sayı var mı kontrol et
                                        var match = lastName.match(/(\D+)(\d+)/);
                                        if (match) {
                                            namePrefix = match[1];
                                            nameNumber = parseInt(match[2]) + 1;
                                            newName = namePrefix + nameNumber;
                                        } else {
                                            // Hiç sayı yoksa veya format beklenmeyen bir şekildeyse
                                            newName = "Module " + (modulesModel.count + 1);
                                        }
                                    }

                                    // Yeni başlangıç sayfası, son modülün bitiş sayfasından 1 fazla
                                    var newStartPage = parseInt(lastEndPage) + 1;
                                    if (isNaN(newStartPage)) {
                                        newStartPage = 1; // Geçerli değilse varsayılan 1
                                    }

                                    // Yeni modül ekle
                                    modulesModel.append({
                                        name: newName,
                                        startPage: newStartPage.toString(),
                                        endPage: ""
                                    });
                                }
                                background: Rectangle {
                                    color: "#1A2327"
                                    border.color: "#009ca6"
                                    border.width: 1
                                    radius: 4
                                }
                                contentItem: Text {
                                    text: "+"
                                    color: "white"
                                    font.pixelSize: 20
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                // Hover effect
                                MouseArea {
                                    id: buttonHoverArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onEntered: parent.background.color = "#2A3337"
                                    onExited: parent.background.color = "#1A2327"
                                    onPressed: parent.background.color = "#0A1317"
                                    onReleased: parent.background.color = buttonHoverArea.containsMouse ? "#2A3337" : "#1A2327"
                                    onClicked: parent.clicked()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Handle dialog result
    onAccepted: {
        // Process the data and create a new project
        console.log("Creating new project with PDF: " + selectedPdfPath);
        // Create JSON object from dialog inputs
        var modulesArray = [];

        // Collect all modules data
        for (var i = 0; i < modulesModel.count; i++) {
            var module = modulesModel.get(i);
            modulesArray.push({
                "module_name": module.name,
                "start": parseInt(module.startPage),
                "end": parseInt(module.endPage)
            });
        }

        var pdfPath = pdfPathTextField.text;
        var bookCoverPath = coverPathTextField.text;
        var audioPath = audioFolderTextField.text;
        var videoPath = videoFolderTextField.text;

        // Build the complete JSON object
        var projectData = {
            "publisher_name": publisherNameEdit.text,
            "book_title": bookTitleEdit.text,
            "language": languageComboBox.currentText,
            "book_pdf_path": pdfPath.startsWith("/") ? pdfPath.slice(1) : pdfPath,
            "book_cover_path": bookCoverPath.startsWith("/") ? bookCoverPath.slice(1) : bookCoverPath,
            "audio_path": audioPath.startsWith("/") ? audioPath.slice(1) : audioPath,
            "video_path": videoPath.startsWith("/") ? videoPath.slice(1) : videoPath,
            "modules": modulesArray,
            "output_path": outputEdit.text
        };

        // Convert to JSON string
        var jsonString = JSON.stringify(projectData, null, 4);

        console.log("Project JSON data:");
        console.log(jsonString);
        pdfProcess.startProcessing(jsonString);

        // if (additionalFiles.length > 0) {
        //     var filePaths = [];
        //     for (var i = 0; i < additionalFiles.length; i++) {
        //         filePaths.push(additionalFiles[i].filePath);
        //     }

        //     // raw klasörüne kopyala
        //     pdfProcess.copyAdditionalFiles(filePaths);
        // }

        // Reset form fields
        resetForm();
    }

    onRejected: {
        // Reset form fields
        resetForm();
    }

    // Initialize form when dialog opens
    onOpened: {
        // Dialog açıldığında sıfırla
        resetForm();
    }
}
