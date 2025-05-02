import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtNetwork

Item {
    id: updateChecker
    property string appVersion: "1.0.0" // Current application version
    property string configUrl: "https://drive.google.com/uc?export=download&id=11WMllZeSNdjTwhcPP_Anfpz_xuZiQqrl"

    // Map of component names to their current versions
    property var componentVersions: {
        "FlowBookDataHelper": appVersion,
        "DataFiles": "1.0.0",
        "Templates": "1.0.0"
    }

    // Store update information
    property var pendingUpdates: []

    function checkForUpdates() {
        console.log("Checking for updates...");
        var request = new XMLHttpRequest();
        request.open("GET", configUrl);
        request.onreadystatechange = function () {
            if (request.readyState === XMLHttpRequest.DONE) {
                if (request.status === 200) {
                    try {
                        var config = JSON.parse(request.responseText);
                        processConfigUpdate(config);
                    } catch (e) {
                        console.log("Error parsing config:", e);
                    }
                } else {
                    console.log("Failed to fetch config. Status:", request.status);
                }
            }
        };
        request.send();
    }

    function processConfigUpdate(config) {
        pendingUpdates = [];

        // Check application version
        if (config.application && config.application.version !== appVersion) {
            pendingUpdates.push({
                name: "FlowBookDataHelper",
                currentVersion: appVersion,
                newVersion: config.application.version,
                downloadUrl: config.application.downloadUrl,
                fileName: "FlowBookDataHelper2_Update.exe",
                isApplication: true
            });
        }

        // Check components versions
        if (config.components) {
            for (var i = 0; i < config.components.length; i++) {
                var component = config.components[i];
                if (componentVersions[component.name] && componentVersions[component.name] !== component.version) {
                    pendingUpdates.push({
                        name: component.name,
                        currentVersion: componentVersions[component.name],
                        newVersion: component.version,
                        downloadUrl: component.downloadUrl,
                        fileName: component.fileName,
                        isApplication: false,
                        targetPath: component.targetPath || "."
                    });
                }
            }
        }

        if (pendingUpdates.length > 0) {
            updateInfoText.text = generateUpdateText();
            updateDialog.open();
        } else {
            console.log("No updates available");
        }
    }

    function generateUpdateText() {
        var text = "Aşağıdaki güncellemeler mevcut:\n\n";

        for (var i = 0; i < pendingUpdates.length; i++) {
            var update = pendingUpdates[i];
            text += "• " + update.name + ": " + update.currentVersion + " → " + update.newVersion + "\n";
        }

        return text;
    }

    Dialog {
        id: updateDialog
        title: "Güncellemeler Mevcut"
        width: 500
        height: 300
        anchors.centerIn: parent
        modal: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 15

            Text {
                id: updateInfoText
                text: "Yeni güncellemeler mevcut."
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 10

                Button {
                    text: "Güncelle"
                    onClicked: {
                        updateDialog.close();
                        downloadAllUpdates();
                    }
                }

                Button {
                    text: "Daha Sonra"
                    onClicked: updateDialog.close()
                }
            }
        }
    }

    function downloadAllUpdates() {
        if (pendingUpdates.length === 0) {
            updateCompleteDialog.open();
            return;
        }

        progressDialog.value = 0;
        progressDialog.maximum = pendingUpdates.length;
        progressDialog.open();

        for (var i = 0; i < pendingUpdates.length; i++) {
            downloadUpdate(pendingUpdates[i], i);
        }
    }

    function downloadUpdate(updateInfo, index) {
        console.log("Downloading update for:", updateInfo.name);

        var request = new XMLHttpRequest();
        request.open("GET", updateInfo.downloadUrl);
        request.responseType = "arraybuffer";

        request.onreadystatechange = function () {
            if (request.readyState === XMLHttpRequest.DONE) {
                if (request.status === 200) {
                    try {
                        // Save the downloaded file to appropriate location
                        var fileName = updateInfo.targetPath + "/" + updateInfo.fileName;
                        saveFileToLocal(request.response, fileName);

                        // Update progress
                        progressDialog.value++;
                        progressDialog.text = "İndiriliyor: " + updateInfo.name;

                        // If this was the last download, close progress dialog
                        if (progressDialog.value >= progressDialog.maximum) {
                            progressDialog.close();
                            updateCompleteDialog.open();
                        }

                        // Update our stored version
                        componentVersions[updateInfo.name] = updateInfo.newVersion;
                    } catch (e) {
                        console.log("Error saving file:", e);
                    }
                } else {
                    console.log("Download failed for:", updateInfo.name, "Status:", request.status);
                }
            }
        };

        request.send();
    }

    function saveFileToLocal(data, fileName) {
        // This is a placeholder. We need to implement native file saving.
        // In real application, you would call a C++ method to save the file
        console.log("Would save file to:", fileName);

        // Placeholder for saving to file using Qt C++ integration
        if (typeof fileManager !== "undefined") {
            fileManager.saveFile(data, fileName);
        } else {
            console.log("fileManager not available for saving");
        }
    }

    Dialog {
        id: progressDialog
        title: "Güncelleniyor"
        width: 400
        height: 150
        anchors.centerIn: parent
        modal: true
        closePolicy: Popup.NoAutoClose

        property int value: 0
        property int maximum: 100
        property string text: "Güncelleme indiriliyor..."

        ColumnLayout {
            anchors.fill: parent
            spacing: 15

            Text {
                text: progressDialog.text
                Layout.fillWidth: true
            }

            ProgressBar {
                from: 0
                to: progressDialog.maximum
                value: progressDialog.value
                Layout.fillWidth: true
            }
        }
    }

    Dialog {
        id: updateCompleteDialog
        title: "Güncelleme Tamamlandı"
        width: 400
        height: 150
        anchors.centerIn: parent
        modal: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 15

            Text {
                text: "Tüm güncellemeler başarıyla tamamlandı. Değişikliklerin etkin olması için uygulamayı yeniden başlatmanız gerekebilir."
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 10

                Button {
                    text: "Yeniden Başlat"
                    onClicked: {
                        updateCompleteDialog.close();
                        Qt.quit();
                    }
                }

                Button {
                    text: "Tamam"
                    onClicked: updateCompleteDialog.close()
                }
            }
        }
    }

    Timer {
        id: updateCheckTimer
        interval: 3600000 // Check every hour
        running: true
        repeat: true
        onTriggered: checkForUpdates()
    }

    Component.onCompleted: {
        checkForUpdates();
    }
}
