import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Dialog {
    id: newProjectDialog

    title: "New project"
    width: 600
    height: 800
    modal: true
    closePolicy: Popup.NoAutoClose // Prevents dialog from closing when clicking outside
    anchors.centerIn: parent
    standardButtons: Dialog.Ok | Dialog.Cancel
    background: Rectangle {
        color: "#2c2a2a"  // Dark background to match the application
        border.color: "gray"
        border.width: 1
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
                color: "white"  // White text for better visibility
            }

            TextField {
                id: pdfPathTextField
                Layout.fillWidth: true
                readOnly: false
                placeholderText: "pdf path"
                color: "white"
                background: Rectangle {
                    color: "#3a3a3a"  // Darker background for text fields
                    border.color: "gray"
                }
            }

            Button {
                text: "..."
                onClicked: pdfFileDialog.open()
                background: Rectangle {
                    color: "#505050"  // Darker button
                    border.color: "gray"
                }
            }
        }

        // This part will be visible when selected PDF is valid
        Rectangle {
            id: validPdfContent
            Layout.fillWidth: true
            Layout.preferredHeight: 650
            visible: isPdfValid
            border.width: 1
            border.color: "gray"
            color: "#2c2a2a"  // Match background color

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 5

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
                        color: "white"
                        background: Rectangle {
                            color: "#3a3a3a"
                            border.color: "gray"
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
                        color: "white"
                        background: Rectangle {
                            color: "#3a3a3a"
                            border.color: "gray"
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
                            color: "#3a3a3a"
                            border.color: "gray"
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
                                color: "#3a3a3a"
                                border.color: "gray"
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
                                color: highlighted ? "#606060" : "#3a3a3a"
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
                        color: "white"
                        background: Rectangle {
                            color: "#3a3a3a"
                            border.color: "gray"
                        }
                    }

                    Button {
                        text: "..."
                        onClicked: coverFileDialog.open()
                        background: Rectangle {
                            color: "#505050"
                            border.color: "gray"
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
                        color: "white"
                        background: Rectangle {
                            color: "#3a3a3a"
                            border.color: "gray"
                        }
                    }

                    Button {
                        text: "..."
                        onClicked: audioFolderDialog.open()
                        background: Rectangle {
                            color: "#505050"
                            border.color: "gray"
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
                        color: "white"
                        background: Rectangle {
                            color: "#3a3a3a"
                            border.color: "gray"
                        }
                    }

                    Button {
                        text: "..."
                        onClicked: videoFolderDialog.open()
                        background: Rectangle {
                            color: "#505050"
                            border.color: "gray"
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
                        color: "white"
                        text: appPath + "books"
                        background: Rectangle {
                            color: "#3a3a3a"
                            border.color: "gray"
                        }
                    }

                    Button {
                        text: "..."
                        onClicked: outputDialog.open()
                        background: Rectangle {
                            color: "#505050"
                            border.color: "gray"
                        }
                    }
                }

                // Modules and Pages section
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: false
                    Layout.preferredHeight: 350
                    Layout.topMargin: 5
                    border.width: 1
                    border.color: "white"
                    color: "#2c2a2a"

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
                                        onTextChanged: model.name = text
                                        color: "white"
                                        background: Rectangle {
                                            color: "#3a3a3a"
                                            border.color: "gray"
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
                                            color: "#3a3a3a"
                                            border.color: "gray"
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
                                            color: "#3a3a3a"
                                            border.color: "gray"
                                        }
                                    }

                                    Button {
                                        text: "X"
                                        width: 25
                                        height: 25
                                        onClicked: {
                                            modulesModel.remove(index);
                                        }
                                        background: Rectangle {
                                            color: "#505050"
                                            border.color: "white"
                                            radius: 3
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
                            Layout.preferredHeight: 50
                            Layout.topMargin: 10

                            Button {
                                id: addModuleButton
                                anchors.centerIn: parent
                                text: "+"
                                width: 240 // Buton genişliğini daha fazla artırdık
                                height: 40
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
                                    color: "#505050"
                                    border.color: "white"
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
                                    onEntered: parent.background.color = "#606060"
                                    onExited: parent.background.color = "#505050"
                                    onPressed: parent.background.color = "#404040"
                                    onReleased: parent.background.color = buttonHoverArea.containsMouse ? "#606060" : "#505050"
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

        // Build the complete JSON object
        var projectData = {
            "publisher_name": publisherNameEdit.text,
            "book_title": bookTitleEdit.text,
            "language": languageComboBox.currentText,
            "book_pdf_path": pdfPathTextField.text,
            "book_cover_path": coverPathTextField.text,
            "audio_path": audioFolderTextField.text,
            "video_path": videoFolderTextField.text,
            "modules": modulesArray,
            "output_path": outputEdit.text
        };

        // Convert to JSON string
        var jsonString = JSON.stringify(projectData, null, 4);

        console.log("Project JSON data:");
        console.log(jsonString);
        pdfProcess.startProcessing(jsonString);

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
