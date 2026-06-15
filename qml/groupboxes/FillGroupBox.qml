import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform

import "../../qml"
import "../newComponents"

GroupBox {
    id: root
    title: ""
    width: parent.width * .98
    padding: 14
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter

    property var fillList: []
    property int fillIndex
    property var page
    property int sectionIndex
    signal removeSection(int secIndex)
    signal removeAnswer(int answerIndex)

    // --- Multi-selection state (indices into fillList) ---
    // Reassigned wholesale on every change so delegate bindings re-evaluate.
    // Selection is shared with the page (rubber-band / Ctrl+click) via
    // sideBar.fillSelection — an array of the selected answer objects. Using
    // object identity means it survives fillList reassignment (no stale
    // indices). The toolbar/ops here act on this section's slice of it.
    readonly property int selCount: {
        var n = 0;
        for (var i = 0; i < fillList.length; i++)
            if (sideBar.fillSelection.indexOf(fillList[i]) !== -1)
                n++;
        return n;
    }
    readonly property bool allSelected: fillList && fillList.length > 0
                                        && selCount === fillList.length
    // True when every selected row in this section is already bold.
    readonly property bool selectionBold: {
        if (selCount === 0)
            return false;
        for (var i = 0; i < fillList.length; i++) {
            var it = fillList[i];
            if (sideBar.fillSelection.indexOf(it) !== -1 && !it.isTextBold)
                return false;
        }
        return true;
    }

    function isSel(item) {
        return sideBar.fillSelection.indexOf(item) !== -1;
    }
    function toggleSel(item) {
        var arr = sideBar.fillSelection.slice();
        var p = arr.indexOf(item);
        if (p === -1)
            arr.push(item);
        else
            arr.splice(p, 1);
        sideBar.fillSelection = arr;
    }
    function selectAll() {
        var arr = sideBar.fillSelection.slice();
        for (var i = 0; i < fillList.length; i++)
            if (arr.indexOf(fillList[i]) === -1)
                arr.push(fillList[i]);
        sideBar.fillSelection = arr;
    }
    function clearSelInList() {
        var arr = [];
        for (var i = 0; i < sideBar.fillSelection.length; i++)
            if (fillList.indexOf(sideBar.fillSelection[i]) === -1)
                arr.push(sideBar.fillSelection[i]);   // keep other sections
        sideBar.fillSelection = arr;
    }
    function boldSelected(b) {
        for (var i = 0; i < fillList.length; i++) {
            var it = fillList[i];
            if (sideBar.fillSelection.indexOf(it) !== -1)
                it.isTextBold = b;
        }
    }
    function deleteSelected() {
        var idxs = [];
        for (var i = 0; i < fillList.length; i++)
            if (sideBar.fillSelection.indexOf(fillList[i]) !== -1)
                idxs.push(i);
        idxs.sort(function (a, b) { return b - a; });   // delete high->low
        for (var k = 0; k < idxs.length; k++)
            root.removeAnswer(idxs[k]);
        clearSelInList();
    }

    background: Rectangle {
        color: "#232f34"
        border.color: "#009ca6"
        border.width: 1
        radius: 8
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        PanelHeader {
            Layout.fillWidth: true
            title: "Fill"
            onCloseClicked: sideBar.fillVisible = false
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#2a3f48" }

        // --- Selection toolbar ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            AppButton {
                text: root.allSelected ? "Clear" : "Select all"
                variant: "secondary"
                Layout.preferredWidth: 100
                Layout.preferredHeight: 30
                enabled: root.fillList && root.fillList.length > 0
                onClicked: root.allSelected ? root.clearSelInList() : root.selectAll()
            }

            Text {
                text: root.selCount + " selected"
                color: root.selCount > 0 ? "#4fd2dc" : "#5e7178"
                font.pixelSize: 12
            }

            Item { Layout.fillWidth: true }

            // Single Bold toggle for the whole selection (binding-driven, so a
            // click doesn't break its checked state).
            Rectangle {
                Layout.preferredWidth: boldRow.implicitWidth + 12
                Layout.preferredHeight: 30
                radius: 6
                color: "transparent"
                opacity: root.selCount > 0 ? 1 : 0.4

                Row {
                    id: boldRow
                    anchors.centerIn: parent
                    spacing: 6
                    Rectangle {
                        width: 20
                        height: 20
                        radius: 4
                        anchors.verticalCenter: parent.verticalCenter
                        color: root.selectionBold ? "#009ca6" : "#1A2327"
                        border.color: root.selectionBold ? "#009ca6" : "#445055"
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            color: "white"
                            font.pixelSize: 12
                            visible: root.selectionBold
                        }
                    }
                    Text {
                        text: "Bold"
                        color: "#cfe8ea"
                        font.pixelSize: 13
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: root.selCount > 0
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.boldSelected(!root.selectionBold)
                }
            }

            AppButton {
                text: "Delete"
                variant: "danger"
                Layout.preferredWidth: 80
                Layout.preferredHeight: 30
                enabled: root.selCount > 0
                onClicked: confirmBox.ask("selected", -1)
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            color: "#16242b"
            border.color: "#2a3f48"
            border.width: 1

            ScrollView {
                anchors.fill: parent
                anchors.margins: 8
                clip: true

                ListView {
                    id: rectRepeater
                    spacing: 6
                    model: root.fillList
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        // The row currently selected on the page (fillIndex) gets a
                        // bright cyan border; multi-selected rows get a teal tint.
                        readonly property bool pageSelected: index === root.fillIndex
                        width: ListView.view ? ListView.view.width : 0
                        height: 46
                        radius: 6
                        color: root.isSel(modelData) ? "#15323a" : "#1A2327"
                        border.color: pageSelected ? "#00e6e6"
                                      : (root.isSel(modelData) ? "#009ca6" : "#2f4751")
                        border.width: (pageSelected || root.isSel(modelData)) ? 2 : 1

                        // Clicking anywhere on the row (gaps) marks this fill as
                        // the one selected on the page. Declared first so the
                        // controls below stay on top and handle their own clicks.
                        MouseArea {
                            anchors.fill: parent
                            onClicked: sideBar.fillIndex = index
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 6

                            // Selection box — fully binding-driven so it tracks
                            // sideBar.fillSelection (a CheckBox would break its binding on click).
                            Rectangle {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                radius: 4
                                color: root.isSel(modelData) ? "#009ca6" : "#1A2327"
                                border.color: root.isSel(modelData) ? "#009ca6" : "#445055"
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: "white"
                                    font.pixelSize: 12
                                    visible: root.isSel(modelData)
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.toggleSel(modelData)
                                }
                            }

                            AppTextField {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                placeholderText: "text"
                                text: modelData.text
                                onTextEdited: modelData.text = text
                                onActiveFocusChanged: if (activeFocus) sideBar.fillIndex = index
                            }
                            AppTextField {
                                Layout.preferredWidth: 56
                                Layout.preferredHeight: 30
                                horizontalAlignment: Text.AlignHCenter
                                placeholderText: "color"
                                text: modelData.textColor
                                onTextEdited: modelData.textColor = text
                                onActiveFocusChanged: if (activeFocus) sideBar.fillIndex = index
                            }

                            // Per-row bold toggle — binding-driven so bulk Bold
                            // updates it too.
                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: 4
                                color: modelData.isTextBold ? "#009ca6" : "#1A2327"
                                border.color: modelData.isTextBold ? "#009ca6" : "#445055"
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: "B"
                                    color: "white"
                                    font.bold: true
                                    font.pixelSize: 13
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: modelData.isTextBold = !modelData.isTextBold
                                }
                            }

                            SpinBox {
                                id: rot
                                Layout.preferredWidth: 84
                                Layout.preferredHeight: 30
                                value: modelData.rotation
                                editable: true
                                from: -180
                                to: 180
                                onValueChanged: modelData.rotation = value

                                background: Rectangle {
                                    color: "#1A2327"
                                    border.color: rot.activeFocus ? "#009ca6" : "#3a4f57"
                                    border.width: 1
                                    radius: 6
                                }
                                contentItem: TextInput {
                                    text: rot.textFromValue(rot.value, rot.locale)
                                    color: "white"
                                    font.pixelSize: 13
                                    horizontalAlignment: Qt.AlignHCenter
                                    verticalAlignment: Qt.AlignVCenter
                                    readOnly: !rot.editable
                                    validator: rot.validator
                                }
                            }

                            AppButton {
                                text: "✕"
                                variant: "danger"
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                leftPadding: 0; rightPadding: 0
                                onClicked: confirmBox.ask("answer", index)
                            }
                        }
                    }
                }
            }
        }
    }

    ConfirmDelete {
        id: confirmBox
        onConfirmed: function(kind, idx) {
            if (kind === "section") {
                root.removeSection(root.sectionIndex);
                sideBar.fillVisible = false;
            } else if (kind === "answer") {
                root.removeAnswer(idx);
            } else if (kind === "selected") {
                root.deleteSelected();
            }
        }
    }
}
