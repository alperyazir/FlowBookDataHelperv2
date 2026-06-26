import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import "newComponents"

// Help ▸ Dependencies: shows the Python runtime packages (+ ffmpeg) the
// FlowBook scripts need, which are installed, and lets the user install the
// missing pip packages. Status is queried via pdfProcess.checkDependencies().
Dialog {
    id: dependencyDialog
    title: "Dependencies"
    modal: true
    closePolicy: Popup.NoAutoClose
    width: 560
    height: 560
    anchors.centerIn: parent

    property var info: ({})
    property bool checking: false
    property bool installing: false
    property string progress: ""

    function refresh() {
        dependencyDialog.checking = true;
        dependencyDialog.progress = "";
        pdfProcess.checkDependencies();
    }

    // pip-installable packages that are currently missing (ffmpeg excluded).
    function missingPkgs() {
        var out = [];
        var deps = (info && info.deps) ? info.deps : [];
        for (var i = 0; i < deps.length; i++)
            if (!deps[i].installed)
                out.push(deps[i].pkg);
        return out;
    }

    // Everything "Install missing" will install: the missing pip packages plus
    // the "ffmpeg" pseudo-package (handled specially by deps.py) when absent.
    function installTargets() {
        var out = missingPkgs();
        if (info && info.ffmpeg && !info.ffmpeg.installed)
            out.push("ffmpeg");
        return out;
    }

    onOpened: refresh()

    Connections {
        target: pdfProcess
        function onDependenciesChecked(ok, json) {
            dependencyDialog.checking = false;
            if (ok) {
                try {
                    dependencyDialog.info = JSON.parse(json);
                } catch (e) {
                    dependencyDialog.info = ({});
                }
            }
        }
        function onDependenciesInstalled(ok) {
            dependencyDialog.installing = false;
            dependencyDialog.progress = ok ? "Done." : "Install failed.";
            dependencyDialog.refresh();   // re-query status
        }
        function onLogMessage(msg) {
            if (dependencyDialog.installing)
                dependencyDialog.progress = msg;
        }
    }

    header: Rectangle {
        color: "#1A2327"; height: 44
        border.color: "#009ca6"; border.width: 1
        Label {
            text: "Dependencies"
            color: "white"; font.pixelSize: 16; font.bold: true
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left; anchors.leftMargin: 12
        }
    }

    footer: Rectangle {
        color: "#1A2327"; height: 56
        border.color: "#009ca6"; border.width: 1
        RowLayout {
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            AppButton {
                text: dependencyDialog.installing ? "Installing…" : "Install missing"
                variant: "primary"
                width: 150; height: 34
                enabled: !dependencyDialog.installing && !dependencyDialog.checking
                         && dependencyDialog.installTargets().length > 0
                onClicked: {
                    dependencyDialog.installing = true;
                    dependencyDialog.progress = "Starting… (large packages can take several minutes)";
                    pdfProcess.installDependencies(dependencyDialog.installTargets());
                }
            }
            AppButton {
                text: "Close"
                variant: "secondary"
                width: 100; height: 34
                enabled: !dependencyDialog.installing
                onClicked: dependencyDialog.close()
            }
        }
    }

    background: Rectangle {
        color: "#232f34"; border.color: "#009ca6"; border.width: 1; radius: 4
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 10

        Text {
            Layout.fillWidth: true
            text: "Python packages the analysis & karaoke scripts need. "
                  + "Missing ones can be installed here."
            color: "#8aa0a8"; font.pixelSize: 12; wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            text: dependencyDialog.info.python
                  ? ("Python " + dependencyDialog.info.python.version + "  ·  "
                     + dependencyDialog.info.python.executable)
                  : "Python: —"
            color: "#cfe0e6"; font.pixelSize: 11; wrapMode: Text.WrapAnywhere
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#2a3f48" }

        // Package rows.
        Repeater {
            model: dependencyDialog.info.deps ? dependencyDialog.info.deps : []
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text {
                    text: modelData.name
                    color: "white"; font.pixelSize: 14
                    Layout.preferredWidth: 150
                }
                Text {
                    visible: modelData.heavy
                    text: "large download"
                    color: "#8a7000"; font.pixelSize: 10
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: modelData.installed
                          ? ("✓ " + (modelData.version || "installed"))
                          : "✗ not installed"
                    color: modelData.installed ? "#3ecf8e" : "#ff6b6b"
                    font.pixelSize: 13
                }
            }
        }

        // ffmpeg (external binary; installed via the imageio-ffmpeg wheel).
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: dependencyDialog.info.ffmpeg !== undefined
            Text {
                text: "ffmpeg"
                color: "white"; font.pixelSize: 14
                Layout.preferredWidth: 150
            }
            Text {
                visible: !(dependencyDialog.info.ffmpeg && dependencyDialog.info.ffmpeg.installed)
                text: "downloads binary"
                color: "#8a7000"; font.pixelSize: 10
            }
            Item { Layout.fillWidth: true }
            Text {
                text: (dependencyDialog.info.ffmpeg && dependencyDialog.info.ffmpeg.installed)
                      ? "✓ found"
                      : "✗ not installed"
                color: (dependencyDialog.info.ffmpeg && dependencyDialog.info.ffmpeg.installed)
                       ? "#3ecf8e" : "#ff6b6b"
                font.pixelSize: 13
            }
        }

        Item { Layout.fillHeight: true }

        // Busy + progress line.
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            visible: dependencyDialog.checking || dependencyDialog.installing
            BusyIndicator {
                running: dependencyDialog.checking || dependencyDialog.installing
                implicitWidth: 22; implicitHeight: 22
            }
            Text {
                Layout.fillWidth: true
                text: dependencyDialog.checking ? "Checking…" : dependencyDialog.progress
                color: "#cfe0e6"; font.pixelSize: 12; wrapMode: Text.WrapAnywhere
                elide: Text.ElideRight; maximumLineCount: 2
            }
        }
    }
}
