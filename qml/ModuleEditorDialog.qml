import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml.Models

Dialog {
    id: root
    modal: true
    closePolicy: Popup.NoAutoClose
    anchors.centerIn: parent
    width: parent.width * 0.75
    height: parent.height * 0.85

    property var book: (config && config.bookSets && config.bookSets[0]
                        && config.bookSets[0].books && config.bookSets[0].books[0])
                       ? config.bookSets[0].books[0] : null
    property var modules: book ? book.modules : []
    property var selectedPages: []

    function refreshModules() {
        modules = book ? book.modules : [];
    }

    function isSelected(pageNumber) {
        return selectedPages.indexOf(pageNumber) !== -1;
    }

    function togglePageSelection(pageNumber) {
        var s = selectedPages.slice();
        var idx = s.indexOf(pageNumber);
        if (idx === -1) s.push(pageNumber);
        else s.splice(idx, 1);
        selectedPages = s;
    }

    function setSingleSelection(pageNumber) {
        selectedPages = [pageNumber];
    }

    function clearSelection() {
        selectedPages = [];
    }

    Connections {
        target: root.book
        function onModulesChanged() { root.refreshModules(); }
    }

    onOpened: { refreshModules(); clearSelection(); }

    background: Rectangle {
        color: "#232f34"
        border.color: "#009ca6"
        border.width: 1
        radius: 4
    }

    header: Rectangle {
        color: "#1A2327"
        height: 44
        border.color: "#009ca6"
        border.width: 1

        Label {
            text: "Module Editor"
            color: "white"
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 12
            font.pixelSize: 16
            font.bold: true
        }

        Label {
            text: root.selectedPages.length > 1
                  ? (root.selectedPages.length + " pages selected · drag any to move all")
                  : "Drag to move · Ctrl/Cmd+Click for multi-select · ⋮⋮ to reorder"
            color: root.selectedPages.length > 1 ? "#ffd24a" : "#8aa0a6"
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: headerButtons.left
            anchors.rightMargin: 12
            font.pixelSize: 12
            font.italic: true
        }

        Row {
            id: headerButtons
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 10
            spacing: 8

            Button {
                text: "Save"
                width: 80
                height: 30
                background: Rectangle {
                    color: parent.hovered ? "#0b6a70" : "#009ca6"
                    border.color: "#00e6e6"
                    border.width: 1
                    radius: 2
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    if (config && config.bookSets && config.bookSets[0]) {
                        config.bookSets[0].saveToJson();
                        if (typeof toast !== "undefined") toast.show("Modules saved!");
                    }
                    root.close();
                }
            }

            Button {
                text: "Close"
                width: 80
                height: 30
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
                onClicked: root.close()
            }
        }
    }

    // Overlay where the dragged module handle is re-parented so it can move freely
    Item {
        id: dragOverlay
        anchors.fill: parent
        z: 2000
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        // Top: Add-page input bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            color: "#1A2327"
            border.color: "#009ca6"
            border.width: 1
            radius: 4

            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 8

                Label {
                    text: "Add Page #"
                    color: "#8aa0a6"
                    font.pixelSize: 13
                }

                TextField {
                    id: addPageInput
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 30
                    placeholderText: "e.g. 95"
                    placeholderTextColor: "gray"
                    color: "white"
                    validator: IntValidator { bottom: 1 }
                    background: Rectangle {
                        color: "#232f34"
                        border.color: "#009ca6"
                        border.width: 1
                        radius: 2
                    }
                    onAccepted: addPageBtn.clicked()
                }

                Button {
                    id: addPageBtn
                    text: "Add to first module"
                    Layout.preferredHeight: 30
                    enabled: addPageInput.text.length > 0
                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? "#0b6a70" : "#009ca6") : "#2A3337"
                        border.color: "#00e6e6"
                        border.width: 1
                        radius: 2
                    }
                    contentItem: Text {
                        text: parent.text
                        color: parent.enabled ? "white" : "#666"
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 8
                        rightPadding: 8
                    }
                    onClicked: {
                        if (!root.book) return;
                        var pn = parseInt(addPageInput.text);
                        if (isNaN(pn) || pn <= 0) {
                            addPageStatus.text = "Invalid page number.";
                            addPageStatus.color = "#ff9999";
                            return;
                        }
                        var err = root.book.addPageToFirstModule(pn);
                        if (err && err.length > 0) {
                            addPageStatus.text = err;
                            addPageStatus.color = "#ffb36b";
                        } else {
                            addPageStatus.text = "Page " + pn + " added.";
                            addPageStatus.color = "#7ed9a3";
                            addPageInput.text = "";
                        }
                    }
                }

                Label {
                    id: addPageStatus
                    Layout.fillWidth: true
                    text: ""
                    color: "#8aa0a6"
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#1A2327"
            border.color: "#009ca6"
            border.width: 1
            radius: 4

            ListView {
                id: modulesList
                anchors.fill: parent
                anchors.margins: 6
                clip: true
                spacing: 6
                cacheBuffer: 10000  // keep all delegates alive for reliable item access

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    active: true
                }

                displaced: Transition {
                    NumberAnimation { properties: "x,y"; duration: 250; easing.type: Easing.OutQuad }
                }
                move: Transition {
                    NumberAnimation { properties: "x,y"; duration: 250; easing.type: Easing.OutQuad }
                }

                model: DelegateModel {
                    id: visualModel
                    model: root.modules

                    delegate: DropArea {
                        id: delegateRoot
                        required property var modelData
                        required property int index
                        property var moduleObj: modelData
                        property int visualIndex: DelegateModel.itemsIndex

                        width: modulesList.width
                        height: moduleRect.implicitHeight
                        keys: ["module", "page"]

                        onEntered: function(drag) {
                            if (drag.source && drag.source.isModuleHandle) {
                                var oldIdx = drag.source.visualIndex;
                                var newIdx = delegateRoot.visualIndex;
                                if (oldIdx !== newIdx && oldIdx >= 0 && newIdx >= 0) {
                                    visualModel.items.move(oldIdx, newIdx);
                                }
                            }
                        }

                        onDropped: function(drop) {
                            if (drop.source && drop.source.draggedPages !== undefined
                                    && !drop.source.isModuleHandle) {
                                var pages = drop.source.draggedPages;
                                var mod = delegateRoot.moduleObj;
                                if (mod && root.book && pages && pages.length > 0) {
                                    var mIdx = root.modules.indexOf(mod);
                                    if (mIdx >= 0) {
                                        Qt.callLater(function() {
                                            if (root.book) root.book.movePagesToModule(pages, mIdx);
                                        });
                                        root.clearSelection();
                                    }
                                }
                            }
                        }

                        Rectangle {
                            id: moduleRect
                            anchors.left: parent.left
                            anchors.right: parent.right
                            implicitHeight: moduleContent.implicitHeight + 16
                            height: implicitHeight
                            color: delegateRoot.containsDrag ? "#0d3a3e" : "#232f34"
                            border.color: delegateRoot.containsDrag ? "#00e6e6" : "#009ca6"
                            border.width: 1
                            radius: 4
                            opacity: moduleHandle.Drag.active ? 0.35 : 1.0

                            Behavior on opacity {
                                NumberAnimation { duration: 150 }
                            }

                            ColumnLayout {
                                id: moduleContent
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    // Drag handle — this is the Drag.source for module reorder
                                    Rectangle {
                                        id: moduleHandle
                                        property bool isModuleHandle: true
                                        property int visualIndex: delegateRoot.visualIndex
                                        property var moduleRef: delegateRoot.moduleObj

                                        Layout.preferredWidth: 24
                                        Layout.preferredHeight: 30
                                        radius: 3
                                        color: dragHandler.active ? "#00535a"
                                             : (hoverArea.hovered ? "#2A3337" : "#1A2327")
                                        border.color: dragHandler.active ? "#00e6e6" : "#009ca6"
                                        border.width: 1
                                        scale: dragHandler.active ? 1.1 : 1.0

                                        Behavior on scale {
                                            NumberAnimation { duration: 150; easing.type: Easing.OutBack }
                                        }

                                        Drag.active: dragHandler.active
                                        Drag.source: moduleHandle
                                        Drag.keys: ["module"]
                                        Drag.hotSpot.x: width / 2
                                        Drag.hotSpot.y: height / 2

                                        Text {
                                            anchors.centerIn: parent
                                            text: "⋮⋮"
                                            color: "white"
                                            font.pixelSize: 14
                                            font.bold: true
                                        }

                                        HoverHandler { id: hoverArea }

                                        DragHandler {
                                            id: dragHandler
                                            target: moduleHandle
                                            onActiveChanged: {
                                                if (!active) {
                                                    // Collect visual order and commit to C++
                                                    var newOrder = [];
                                                    for (var i = 0; i < modulesList.count; i++) {
                                                        var d = modulesList.itemAtIndex(i);
                                                        if (d && d.moduleObj) newOrder.push(d.moduleObj);
                                                    }
                                                    if (newOrder.length === root.modules.length) {
                                                        Qt.callLater(function() {
                                                            if (root.book) root.book.reorderModules(newOrder);
                                                        });
                                                    }
                                                }
                                            }
                                        }

                                        states: State {
                                            when: dragHandler.active
                                            ParentChange {
                                                target: moduleHandle
                                                parent: dragOverlay
                                            }
                                            PropertyChanges {
                                                target: moduleHandle
                                                z: 999
                                            }
                                        }
                                    }

                                    Label {
                                        text: "Module"
                                        color: "#8aa0a6"
                                        font.pixelSize: 12
                                    }

                                    TextField {
                                        Layout.preferredWidth: 260
                                        text: delegateRoot.moduleObj ? delegateRoot.moduleObj.name : ""
                                        color: "white"
                                        placeholderText: "Module name"
                                        placeholderTextColor: "gray"
                                        background: Rectangle {
                                            color: "#1A2327"
                                            border.color: "#009ca6"
                                            border.width: 1
                                            radius: 2
                                        }
                                        onEditingFinished: {
                                            if (root.book && delegateRoot.moduleObj
                                                    && text !== delegateRoot.moduleObj.name) {
                                                var mIdx = root.modules.indexOf(delegateRoot.moduleObj);
                                                var newName = text;
                                                if (mIdx >= 0) {
                                                    Qt.callLater(function() {
                                                        if (root.book) root.book.renameModule(mIdx, newName);
                                                    });
                                                }
                                            }
                                        }
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        text: delegateRoot.moduleObj
                                              ? (delegateRoot.moduleObj.pages.length + " page(s)")
                                              : ""
                                        color: "#8aa0a6"
                                        font.pixelSize: 12
                                        horizontalAlignment: Text.AlignRight
                                    }

                                    Button {
                                        text: "Delete"
                                        enabled: root.modules.length > 1
                                        Layout.preferredWidth: 80
                                        Layout.preferredHeight: 28
                                        background: Rectangle {
                                            color: parent.hovered && parent.enabled ? "#4a1a1a" : "#1A2327"
                                            border.color: parent.enabled ? "#d9534f" : "#555"
                                            border.width: 1
                                            radius: 2
                                        }
                                        contentItem: Text {
                                            text: parent.text
                                            color: parent.enabled ? "#ffb3b0" : "#777"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        onClicked: {
                                            if (!delegateRoot.moduleObj) return;
                                            confirmDelete.pageCount = delegateRoot.moduleObj.pages.length;
                                            confirmDelete.moduleName = delegateRoot.moduleObj.name;
                                            confirmDelete.targetModule = delegateRoot.moduleObj;
                                            confirmDelete.open();
                                        }
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: pagesGrid.implicitHeight
                                                            + (emptyText.visible ? 18 : 0)

                                    DelegateModel {
                                        id: pagesVisualModel
                                        model: delegateRoot.moduleObj ? delegateRoot.moduleObj.pages : []

                                        delegate: DropArea {
                                            id: pageDropArea
                                            required property var modelData
                                            required property int index
                                            width: 54
                                            height: 42
                                            keys: ["page"]

                                            property int visualIndex: DelegateModel.itemsIndex
                                            property var pageRef: modelData
                                            property int pageNumber: modelData ? modelData.page_number : -1
                                            property bool selected: root.isSelected(pageNumber)
                                            property var sourceModuleRef: delegateRoot.moduleObj

                                            onEntered: function(drag) {
                                                if (drag.source && !drag.source.isModuleHandle
                                                        && drag.source.sourceModuleRef === delegateRoot.moduleObj) {
                                                    var srcIdx = drag.source.srcVisualIndex;
                                                    var tgtIdx = pageDropArea.visualIndex;
                                                    if (srcIdx !== undefined && srcIdx >= 0
                                                            && tgtIdx >= 0 && srcIdx !== tgtIdx) {
                                                        pagesVisualModel.items.move(srcIdx, tgtIdx);
                                                    }
                                                }
                                            }

                                            onDropped: function(drop) {
                                                if (!drop.source || drop.source.isModuleHandle) return;
                                                if (!drop.source.draggedPages) return;
                                                var mIdx = root.modules.indexOf(delegateRoot.moduleObj);
                                                if (mIdx < 0) return;

                                                if (drop.source.sourceModuleRef === delegateRoot.moduleObj) {
                                                    // Same module — commit visual order
                                                    var newOrder = [];
                                                    for (var i = 0; i < pagesGrid.count; i++) {
                                                        var d = pagesGrid.itemAtIndex(i);
                                                        if (d && d.pageRef) newOrder.push(d.pageRef);
                                                    }
                                                    var mod = delegateRoot.moduleObj;
                                                    if (mod && newOrder.length === mod.pages.length) {
                                                        Qt.callLater(function() {
                                                            if (root.book) root.book.reorderPagesInModule(mIdx, newOrder);
                                                        });
                                                        root.clearSelection();
                                                    }
                                                } else {
                                                    // Cross-module: insert at the position of the page that was hovered.
                                                    var pages = drop.source.draggedPages;
                                                    var insertAt = pageDropArea.visualIndex;
                                                    Qt.callLater(function() {
                                                        if (root.book) root.book.movePagesToModule(pages, mIdx, insertAt);
                                                    });
                                                    root.clearSelection();
                                                }
                                            }

                                            Rectangle {
                                                id: pageCard
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 48
                                                height: 36
                                                radius: 3

                                                // Properties exposed on Drag.source
                                                property bool isModuleHandle: false
                                                property int srcVisualIndex: pageDropArea.visualIndex
                                                property var sourceModuleRef: pageDropArea.sourceModuleRef
                                                property int pageNumber: pageDropArea.pageNumber
                                                property var draggedPages: (pageDropArea.selected
                                                                            && root.selectedPages.length > 1)
                                                                           ? root.selectedPages.slice()
                                                                           : [pageDropArea.pageNumber]

                                                color: {
                                                    if (pageMouse.drag.active) return "#00535a";
                                                    if (pageDropArea.selected) return "#115e64";
                                                    return "#0f4e53";
                                                }
                                                border.color: pageDropArea.selected ? "#ffd24a" : "#00e6e6"
                                                border.width: pageDropArea.selected ? 2 : 1
                                                scale: pageMouse.drag.active ? 1.1 : 1.0

                                                Behavior on scale {
                                                    NumberAnimation { duration: 120 }
                                                }

                                                Drag.active: pageMouse.drag.active
                                                Drag.source: pageCard
                                                Drag.hotSpot.x: width / 2
                                                Drag.hotSpot.y: height / 2
                                                Drag.keys: ["page"]

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: pageCard.pageNumber
                                                    color: "white"
                                                    font.pixelSize: 14
                                                    font.bold: true
                                                }

                                                Rectangle {
                                                    visible: pageMouse.drag.active
                                                             && pageCard.draggedPages.length > 1
                                                    width: 22
                                                    height: 22
                                                    radius: 11
                                                    color: "#ffd24a"
                                                    border.color: "#1A2327"
                                                    border.width: 1
                                                    anchors.top: parent.top
                                                    anchors.right: parent.right
                                                    anchors.topMargin: -8
                                                    anchors.rightMargin: -8
                                                    z: 1

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: pageCard.draggedPages.length
                                                        color: "#1A2327"
                                                        font.pixelSize: 11
                                                        font.bold: true
                                                    }
                                                }

                                                MouseArea {
                                                    id: pageMouse
                                                    anchors.fill: parent
                                                    drag.target: pageCard
                                                    cursorShape: drag.active ? Qt.ClosedHandCursor
                                                                             : Qt.OpenHandCursor

                                                    onPressed: function(mouse) {
                                                        var multi = (mouse.modifiers & Qt.ControlModifier)
                                                                 || (mouse.modifiers & Qt.MetaModifier);
                                                        if (multi) {
                                                            root.togglePageSelection(pageCard.pageNumber);
                                                        } else if (!pageDropArea.selected) {
                                                            root.setSingleSelection(pageCard.pageNumber);
                                                        }
                                                    }
                                                    onReleased: pageCard.Drag.drop()
                                                }

                                                states: State {
                                                    when: pageMouse.drag.active
                                                    ParentChange { target: pageCard; parent: dragOverlay }
                                                    AnchorChanges {
                                                        target: pageCard
                                                        anchors.horizontalCenter: undefined
                                                        anchors.verticalCenter: undefined
                                                    }
                                                    PropertyChanges { target: pageCard; z: 999 }
                                                }
                                            }
                                        }
                                    }

                                    GridView {
                                        id: pagesGrid
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        cellWidth: 54
                                        cellHeight: 42
                                        interactive: false
                                        clip: false
                                        cacheBuffer: 10000
                                        model: pagesVisualModel

                                        implicitHeight: {
                                            var cols = Math.max(1, Math.floor(width / cellWidth));
                                            return count === 0 ? 0
                                                 : Math.ceil(count / cols) * cellHeight;
                                        }
                                        height: implicitHeight

                                        displaced: Transition {
                                            NumberAnimation { properties: "x,y"; duration: 200; easing.type: Easing.OutQuad }
                                        }
                                        move: Transition {
                                            NumberAnimation { properties: "x,y"; duration: 200; easing.type: Easing.OutQuad }
                                        }
                                    }

                                    Text {
                                        id: emptyText
                                        visible: !delegateRoot.moduleObj
                                                 || delegateRoot.moduleObj.pages.length === 0
                                        text: "(empty – drop or add pages here)"
                                        color: "#5a7075"
                                        font.italic: true
                                        font.pixelSize: 12
                                        anchors.left: parent.left
                                        anchors.top: parent.top
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Button {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            text: "+  Add Module"
            background: Rectangle {
                color: parent.hovered ? "#2A3337" : "#1A2327"
                border.color: "#009ca6"
                border.width: 1
                radius: 3
            }
            contentItem: Text {
                text: parent.text
                color: "white"
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                if (!root.book) return;
                var nextNum = root.modules.length + 1;
                Qt.callLater(function() {
                    if (root.book) root.book.addModule("Module " + nextNum);
                });
            }
        }
    }

    // Delete confirmation dialog
    Dialog {
        id: confirmDelete
        property int pageCount: 0
        property string moduleName: ""
        property var targetModule: null
        title: "Delete Module"
        anchors.centerIn: parent
        modal: true
        standardButtons: Dialog.Yes | Dialog.No

        background: Rectangle {
            color: "#232f34"
            border.color: "#d9534f"
            border.width: 1
            radius: 4
        }

        Label {
            text: {
                var base = "Delete \"" + confirmDelete.moduleName + "\"?";
                if (confirmDelete.pageCount > 0) {
                    base += "\n\nThis module has " + confirmDelete.pageCount
                          + " page(s). They will be unassigned.";
                }
                return base;
            }
            color: "white"
            wrapMode: Text.Wrap
            width: 340
        }

        onAccepted: {
            if (!root.book || !confirmDelete.targetModule) return;
            var mIdx = root.modules.indexOf(confirmDelete.targetModule);
            confirmDelete.targetModule = null;
            if (mIdx >= 0) {
                Qt.callLater(function() {
                    if (root.book) root.book.removeModule(mIdx);
                });
            }
        }
    }

}
