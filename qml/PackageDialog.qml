import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Dialog {
    id: packageDialog
    property string currentProject
    title: "Let's Package"
    modal: true
    closePolicy: Popup.NoAutoClose
    width: 440
    height: 600

    anchors.centerIn: parent

    // Two-step flow: 1 = pick books, 2 = pick platforms.
    property int step: 1

    // Books selected for this package — they all go under data/books/ together
    // (e.g. a paired Student Book + Workbook). Defaults to the open project.
    property var selectedBooks: []

    property var selectedOS: ({
                                  windows: false,
                                  windows78: false,
                                  linux: false,
                                  macos: false
                              })

    onOpened: {
        step = 1;
        selectedBooks = currentProject ? [currentProject] : [];
    }

    function toggleBook(name) {
        var arr = selectedBooks.slice();
        var p = arr.indexOf(name);
        if (p === -1)
            arr.push(name);
        else
            arr.splice(p, 1);
        selectedBooks = arr;
    }

    function doPackage() {
        var platforms = [];
        if (selectedOS.windows)
            platforms.push("windows");
        if (selectedOS.windows78)
            platforms.push("windows78");
        if (selectedOS.linux)
            platforms.push("linux");
        if (selectedOS.macos)
            platforms.push("macos");

        if (packageDialog.selectedBooks.length === 0 || platforms.length === 0)
            return;

        // Build a plain string array (a `var` property holding a JS array can
        // marshal oddly to QStringList).
        var books = [];
        for (var i = 0; i < packageDialog.selectedBooks.length; i++)
            books.push("" + packageDialog.selectedBooks[i]);

        pdfProcess.packageForPlatforms(platforms, books);
        flowProgress.reset();
        flowProgress.statusText = "Packaging is Processing...";
        flowProgress.addLogMessage("Packaging: " + packageDialog.selectedBooks.join(" + "));
        flowProgress.open();
        packageDialog.close();
    }

    header: Rectangle {
        color: "#1A2327"
        height: 40
        border.color: "#009ca6"
        border.width: 1
        Label {
            text: packageDialog.step === 1 ? "Package · Step 1: Books"
                                           : "Package · Step 2: Platforms"
            color: "white"
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            font.pixelSize: 16
            font.bold: true
        }
    }

    footer: Rectangle {
        color: "#1A2327"
        height: 60
        border.color: "#009ca6"
        border.width: 1
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 10

            Button {
                text: "Cancel"
                Layout.preferredWidth: 80
                Layout.preferredHeight: 32
                background: Rectangle {
                    color: parent.hovered ? "#2A3337" : "#1A2327"
                    border.color: "#009ca6"
                    border.width: 1
                    radius: 2
                }
                contentItem: Text {
                    text: parent.text; color: "white"
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: packageDialog.reject()
            }

            Item { Layout.fillWidth: true }

            Button {
                text: "Back"
                visible: packageDialog.step === 2
                Layout.preferredWidth: 80
                Layout.preferredHeight: 32
                background: Rectangle {
                    color: parent.hovered ? "#2A3337" : "#1A2327"
                    border.color: "#009ca6"
                    border.width: 1
                    radius: 2
                }
                contentItem: Text {
                    text: parent.text; color: "white"
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: packageDialog.step = 1
            }

            Button {
                text: "Next"
                visible: packageDialog.step === 1
                enabled: packageDialog.selectedBooks.length > 0
                Layout.preferredWidth: 100
                Layout.preferredHeight: 32
                background: Rectangle {
                    color: !parent.enabled ? "#2a3338" : (parent.hovered ? "#00b3be" : "#009ca6")
                    radius: 2
                }
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? "white" : "#6b7a80"
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: packageDialog.step = 2
            }

            Button {
                text: "Package"
                visible: packageDialog.step === 2
                Layout.preferredWidth: 100
                Layout.preferredHeight: 32
                background: Rectangle {
                    color: parent.hovered ? "#00b3be" : "#009ca6"
                    radius: 2
                }
                contentItem: Text {
                    text: parent.text; color: "white"; font.bold: true
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: packageDialog.doPackage()
            }
        }
    }

    background: Rectangle {
        color: "#232f34"
        border.color: "#009ca6"
        border.width: 1
        radius: 4
    }

    // ---------- Step 1: books ----------
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12
        visible: packageDialog.step === 1

        Label {
            text: "Select Books"
            font.pixelSize: 16
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
            color: "white"
        }
        Text {
            Layout.fillWidth: true
            text: "Pick one book for a single package, or two for a paired set "
                  + "(both go under books/ together)."
            color: "#8aa0a8"
            font.pixelSize: 12
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            border.width: 1
            border.color: "#009ca6"
            radius: 4

            ListView {
                id: bookList
                anchors.fill: parent
                anchors.margins: 6
                clip: true
                spacing: 2
                model: config ? config.recentProject : []
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    id: bookRow
                    required property var modelData
                    readonly property bool sel: packageDialog.selectedBooks.indexOf(modelData) !== -1
                    width: ListView.view ? ListView.view.width : 0
                    height: 34
                    radius: 4
                    color: bookRow.sel ? "#15323a" : (bookMouse.containsMouse ? "#1c2a31" : "transparent")

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        spacing: 10
                        Rectangle {
                            width: 18
                            height: 18
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: bookRow.sel ? "#00e6e6" : "#232f34"
                            border.color: "#009ca6"
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: "#10343a"
                                font.pixelSize: 12
                                font.bold: true
                                visible: bookRow.sel
                            }
                        }
                        Text {
                            text: bookRow.modelData
                            color: "white"
                            font.pixelSize: 14
                            elide: Text.ElideRight
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    MouseArea {
                        id: bookMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: packageDialog.toggleBook(bookRow.modelData)
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: packageDialog.selectedBooks.length > 0
                  ? "Package: " + packageDialog.selectedBooks.join(" + ")
                  : "No books selected"
            color: packageDialog.selectedBooks.length > 0 ? "#4fd2dc" : "#5e7178"
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    // ---------- Step 2: platforms ----------
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12
        visible: packageDialog.step === 2

        Label {
            text: "Select Platforms"
            font.pixelSize: 16
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
            color: "white"
        }
        Text {
            Layout.fillWidth: true
            text: "Package: " + packageDialog.selectedBooks.join(" + ")
            color: "#4fd2dc"
            font.pixelSize: 12
            elide: Text.ElideRight
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            border.width: 1
            border.color: "#009ca6"
            radius: 4

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14

                CheckBox {
                    id: windowsCheck
                    text: "Windows"
                    checked: selectedOS.windows
                    onCheckedChanged: selectedOS.windows = checked
                    indicator: Rectangle {
                        width: 18; height: 18; radius: 4
                        color: windowsCheck.checked ? "#00e6e6" : "#232f34"
                        border.color: "#009ca6"; border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 5
                    }
                    contentItem: Text {
                        text: parent.text; color: "white"; font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.indicator.right; anchors.leftMargin: 10
                    }
                }
                CheckBox {
                    id: windows78Check
                    text: "Windows 7-8"
                    checked: selectedOS.windows78
                    onCheckedChanged: selectedOS.windows78 = checked
                    indicator: Rectangle {
                        width: 18; height: 18; radius: 4
                        color: windows78Check.checked ? "#00e6e6" : "#232f34"
                        border.color: "#009ca6"; border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 5
                    }
                    contentItem: Text {
                        text: parent.text; color: "white"; font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.indicator.right; anchors.leftMargin: 10
                    }
                }
                CheckBox {
                    id: linuxCheck
                    text: "Linux"
                    checked: selectedOS.linux
                    onCheckedChanged: selectedOS.linux = checked
                    indicator: Rectangle {
                        width: 18; height: 18; radius: 4
                        color: linuxCheck.checked ? "#00e6e6" : "#232f34"
                        border.color: "#009ca6"; border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 5
                    }
                    contentItem: Text {
                        text: parent.text; color: "white"; font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.indicator.right; anchors.leftMargin: 10
                    }
                }
                CheckBox {
                    id: macosCheck
                    text: "MacOS"
                    checked: selectedOS.macos
                    onCheckedChanged: selectedOS.macos = checked
                    indicator: Rectangle {
                        width: 18; height: 18; radius: 4
                        color: macosCheck.checked ? "#00e6e6" : "#232f34"
                        border.color: "#009ca6"; border.width: 1
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left; anchors.leftMargin: 5
                    }
                    contentItem: Text {
                        text: parent.text; color: "white"; font.pixelSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.indicator.right; anchors.leftMargin: 10
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
