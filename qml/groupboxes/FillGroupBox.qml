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
    property var selectedList: []
    readonly property int selCount: selectedList.length
    readonly property bool allSelected: fillList && fillList.length > 0
                                        && selectedList.length === fillList.length
    // True when every selected row is already bold (drives the Bold toggle).
    readonly property bool selectionBold: {
        if (selectedList.length === 0)
            return false;
        for (var k = 0; k < selectedList.length; k++) {
            var i = selectedList[k];
            if (i < 0 || i >= fillList.length || !fillList[i].isTextBold)
                return false;
        }
        return true;
    }
    // The list changes identity on add/remove; stale indices would be wrong.
    onFillListChanged: selectedList = []

    function isSel(i) {
        return root.selectedList.indexOf(i) !== -1;
    }
    function toggleSel(i) {
        var arr = root.selectedList.slice();
        var p = arr.indexOf(i);
        if (p === -1)
            arr.push(i);
        else
            arr.splice(p, 1);
        root.selectedList = arr;
    }
    function selectAll() {
        var arr = [];
        for (var i = 0; i < root.fillList.length; i++)
            arr.push(i);
        root.selectedList = arr;
    }
    function boldSelected(b) {
        for (var k = 0; k < root.selectedList.length; k++) {
            var i = root.selectedList[k];
            if (i >= 0 && i < root.fillList.length)
                root.fillList[i].isTextBold = b;
        }
    }
    function deleteSelected() {
        // Remove from the highest index down so earlier indices stay valid.
        var arr = root.selectedList.slice().sort(function (a, b) { return b - a; });
        for (var k = 0; k < arr.length; k++)
            root.removeAnswer(arr[k]);
        root.selectedList = [];
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
                onClicked: root.allSelected ? root.selectedList = [] : root.selectAll()
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
                        color: root.isSel(index) ? "#15323a" : "#1A2327"
                        border.color: pageSelected ? "#00e6e6"
                                      : (root.isSel(index) ? "#009ca6" : "#2f4751")
                        border.width: (pageSelected || root.isSel(index)) ? 2 : 1

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
                            // selectedList (a CheckBox would break its binding on click).
                            Rectangle {
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                                radius: 4
                                color: root.isSel(index) ? "#009ca6" : "#1A2327"
                                border.color: root.isSel(index) ? "#009ca6" : "#445055"
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: "white"
                                    font.pixelSize: 12
                                    visible: root.isSel(index)
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.toggleSel(index)
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
