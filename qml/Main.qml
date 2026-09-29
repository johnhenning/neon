import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Neon

ApplicationWindow {
    id: win
    required property Controller backend
    visible: true
    width: 1240
    height: 840
    minimumWidth: 760
    minimumHeight: 540
    title: backend.opened ? backend.book.title + " — Neon" : "Neon"
    property bool dark: backend.settings.pageTheme === "night"
    property bool focusMode: false
    property bool typewriter: false
    property string activeShelf: ""
    property string panel: "Chapters"
    property string exportFormat: "docx"
    property color ink: dark ? "#ece8df" : "#2d302e"
    property color surface: dark ? "#202622" : "#f0f1eb"
    property color paper: dark ? "#262d27" : "#fffdf7"
    property color muted: dark ? "#b5bbae" : "#697468"
    property color accent: dark ? "#a8c5aa" : "#3c674b"
    property int sprintStart: 0
    property int sprintTarget: 0
    property int enterCount: 0
    color: surface
    palette.window: surface
    palette.windowText: ink
    palette.base: paper
    palette.text: ink
    palette.button: surface
    palette.buttonText: ink
    palette.highlight: accent
    palette.highlightedText: "#ffffff"
    onClosing: function (close) {
        close.accepted = backend.save();
    }

    function ask(title, value, action) {
        prompt.title = title;
        promptField.text = value;
        prompt.action = action;
        prompt.open();
        promptField.forceActiveFocus();
    }
    function toast(message) {
        toastLabel.text = message;
        toastPopup.open();
        toastTimer.restart();
    }
    function showExport(format) {
        exportFormat = format;
        exportDialog.currentFile = "file:///" + (backend.book.title || "Manuscript") + "." + format;
        exportDialog.open();
    }

    Connections {
        target: win.backend
        function onError(message) {
            errorText.text = message;
            errorDialog.open();
        }
        function onNotice(message) {
            win.toast(message);
        }
        function onCursorRequested(position, anchor) {
            editor.select(anchor, position);
            editor.forceActiveFocus();
        }
        function onDocumentLoaded(html) {
            scroll.contentItem.contentY = 0;
        }
    }

    menuBar: MenuBar {
        Menu {
            title: qsTr("File")
            Action {
                text: qsTr("New Book…")
                shortcut: StandardKey.New
                onTriggered: newBook.open()
            }
            Action {
                text: qsTr("Bookshelf")
                shortcut: "Ctrl+Shift+B"
                onTriggered: win.backend.closeBook()
            }
            Action {
                text: qsTr("Import Manuscript…")
                shortcut: "Ctrl+Shift+I"
                onTriggered: importDialog.open()
            }
            Action {
                text: qsTr("Copy Neo Library…")
                onTriggered: libraryImport.open()
            }
            MenuSeparator {}
            Action {
                text: qsTr("Save")
                shortcut: StandardKey.Save
                onTriggered: win.backend.save()
            }
            Menu {
                title: qsTr("Export")
                enabled: win.backend.opened
                Action {
                    text: "Word (.docx)"
                    onTriggered: win.showExport("docx")
                }
                Action {
                    text: "EPUB 3"
                    onTriggered: win.showExport("epub")
                }
                Action {
                    text: "PDF"
                    onTriggered: win.showExport("pdf")
                }
                Action {
                    text: "HTML"
                    onTriggered: win.showExport("html")
                }
                Action {
                    text: "Markdown"
                    onTriggered: win.showExport("md")
                }
                Action {
                    text: "Plain text"
                    onTriggered: win.showExport("txt")
                }
            }
            Action {
                text: qsTr("Email Draft to Myself…")
                shortcut: "Ctrl+E"
                enabled: win.backend.opened
                onTriggered: win.backend.emailDraft()
            }
            Action {
                text: qsTr("Back Up Library Now")
                onTriggered: win.backend.backup()
            }
            Action {
                text: qsTr("Reveal Library")
                onTriggered: Qt.openUrlExternally("file://" + win.backend.libraryPath)
            }
            MenuSeparator {}
            Action {
                text: qsTr("Book Details…")
                enabled: win.backend.opened
                onTriggered: details.open()
            }
            Action {
                text: qsTr("Preferences…")
                onTriggered: preferences.open()
            }
            Action {
                text: qsTr("Quit")
                shortcut: StandardKey.Quit
                onTriggered: win.close()
            }
        }
        Menu {
            title: qsTr("Edit")
            Action {
                text: qsTr("Undo")
                shortcut: StandardKey.Undo
                onTriggered: win.backend.undo()
            }
            Action {
                text: qsTr("Redo")
                shortcut: StandardKey.Redo
                onTriggered: win.backend.redo()
            }
            MenuSeparator {}
            Action {
                text: qsTr("Cut")
                shortcut: StandardKey.Cut
                onTriggered: editor.cut()
            }
            Action {
                text: qsTr("Copy")
                shortcut: StandardKey.Copy
                onTriggered: editor.copy()
            }
            Action {
                text: qsTr("Paste")
                shortcut: StandardKey.Paste
                onTriggered: editor.paste()
            }
            Action {
                text: qsTr("Select All")
                shortcut: StandardKey.SelectAll
                onTriggered: editor.selectAll()
            }
            Action {
                text: qsTr("Find and Replace…")
                shortcut: StandardKey.Find
                onTriggered: searchBar.visible = !searchBar.visible
            }
            Action {
                text: qsTr("Spellcheck Pass…")
                shortcut: "Ctrl+;"
                onTriggered: {
                    spelling.words = win.backend.spellcheck(spellLanguage.currentText);
                    spelling.open();
                }
            }
        }
        Menu {
            title: qsTr("Format")
            Action {
                text: qsTr("Bold")
                shortcut: StandardKey.Bold
                onTriggered: win.backend.format("bold")
            }
            Action {
                text: qsTr("Italic")
                shortcut: StandardKey.Italic
                onTriggered: win.backend.format("italic")
            }
            Action {
                text: qsTr("Poetry Paragraph")
                onTriggered: win.backend.format("poetry")
            }
            MenuSeparator {}
            Action {
                text: qsTr("Align Left")
                onTriggered: win.backend.format("left")
            }
            Action {
                text: qsTr("Center")
                onTriggered: win.backend.format("center")
            }
            Action {
                text: qsTr("Align Right")
                onTriggered: win.backend.format("right")
            }
            Action {
                text: qsTr("Justify")
                onTriggered: win.backend.format("justify")
            }
        }
        Menu {
            title: qsTr("Manuscript")
            enabled: win.backend.opened
            Action {
                text: qsTr("New Chapter")
                onTriggered: win.backend.newChapter("")
            }
            Action {
                text: qsTr("Split Chapter at Cursor")
                onTriggered: win.backend.splitChapter()
            }
            Action {
                text: qsTr("Merge with Previous Chapter")
                onTriggered: win.backend.mergePrevious()
            }
            Action {
                text: qsTr("Scene Break")
                onTriggered: win.backend.sceneBreak()
            }
            Action {
                text: qsTr("Keep Selection in Darlings")
                shortcut: "Ctrl+Shift+D"
                onTriggered: win.backend.saveDarling()
            }
            Action {
                text: qsTr("Add Placeholder…")
                shortcut: "Ctrl+Shift+X"
                onTriggered: win.ask("Placeholder note", "", function (t) {
                    win.backend.addSticky(t);
                })
            }
            Action {
                text: qsTr("Goals and Sprints…")
                shortcut: "Ctrl+,"
                onTriggered: goals.open()
            }
        }
        Menu {
            title: qsTr("View")
            Action {
                text: qsTr("Dark Page")
                checkable: true
                checked: win.dark
                onTriggered: win.backend.updateSetting("pageTheme", checked ? "night" : "day")
            }
            Action {
                text: qsTr("Distraction-Free")
                checkable: true
                checked: win.focusMode
                onTriggered: win.focusMode = checked
            }
            Action {
                text: qsTr("Typewriter Scrolling")
                checkable: true
                checked: win.typewriter
                onTriggered: win.typewriter = checked
            }
            Action {
                text: qsTr("Full Screen")
                shortcut: "Ctrl+Shift+F"
                onTriggered: win.visibility = win.visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen
            }
            Action {
                text: qsTr("Larger Text")
                shortcut: StandardKey.ZoomIn
                onTriggered: win.backend.updateSetting("fontSize", editor.font.pointSize + 1)
            }
            Action {
                text: qsTr("Smaller Text")
                shortcut: StandardKey.ZoomOut
                onTriggered: win.backend.updateSetting("fontSize", Math.max(10, editor.font.pointSize - 1))
            }
        }
        Menu {
            title: qsTr("Help")
            Action {
                text: qsTr("About Neon")
                onTriggered: about.open()
            }
            Action {
                text: qsTr("Neo — Our Inspiration")
                onTriggered: Qt.openUrlExternally("https://github.com/hughhowey/neo")
            }
        }
    }

    header: ToolBar {
        visible: !win.focusMode
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            ToolButton {
                text: win.backend.opened ? "‹ Library" : "NEON"
                onClicked: win.backend.closeBook()
            }
            Label {
                text: win.backend.opened ? win.backend.book.title : "A place for your stories"
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            ToolButton {
                text: win.backend.opened ? "Details" : "+ Shelf"
                onClicked: win.backend.opened ? details.open() : win.ask("New shelf", "", function (t) {
                    win.backend.addShelf(t);
                })
            }
            ToolButton {
                text: win.backend.opened ? "Focus" : "+ Book"
                onClicked: win.backend.opened ? win.focusMode = true : newBook.open()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        RowLayout {
            id: searchBar
            visible: false
            Layout.fillWidth: true
            Layout.margins: 12
            TextField {
                id: searchText
                placeholderText: "Find in chapter"
                Layout.fillWidth: true
                onAccepted: win.backend.find(text)
            }
            TextField {
                id: replacementText
                placeholderText: "Replace with"
                Layout.fillWidth: true
            }
            Button {
                text: "Next"
                onClicked: win.backend.find(searchText.text)
            }
            Button {
                text: "Replace"
                onClicked: win.backend.replace(searchText.text, replacementText.text, false)
            }
            Button {
                text: "All"
                onClicked: win.backend.replace(searchText.text, replacementText.text, true)
            }
            ToolButton {
                text: "×"
                onClicked: searchBar.visible = false
            }
        }

        RowLayout {
            visible: !win.backend.opened
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            Rectangle {
                Layout.preferredWidth: 190
                Layout.fillHeight: true
                color: win.surface
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    Label {
                        text: "YOUR LIBRARY"
                        color: win.muted
                        font.pixelSize: 11
                        font.letterSpacing: 2
                    }
                    Button {
                        text: "All books"
                        flat: true
                        Layout.fillWidth: true
                        onClicked: win.activeShelf = ""
                    }
                    Repeater {
                        model: win.backend.shelves
                        delegate: Button {
                            required property var modelData
                            text: modelData.name
                            flat: true
                            Layout.fillWidth: true
                            onClicked: win.activeShelf = modelData.id
                            onPressAndHold: win.ask("Rename shelf", modelData.name, function (t) {
                                win.backend.renameShelf(modelData.id, t);
                            })
                        }
                    }
                    Item {
                        Layout.fillHeight: true
                    }
                    Label {
                        text: "Inspired by Hugh Howey’s NEO"
                        color: win.muted
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        font.pixelSize: 11
                    }
                    Button {
                        text: "Import…"
                        Layout.fillWidth: true
                        onClicked: importDialog.open()
                    }
                }
            }
            ScrollView {
                id: bookshelfScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                clip: true
                Flow {
                    width: bookshelfScroll.availableWidth
                    spacing: 32
                    padding: 32
                    Repeater {
                        model: win.backend.books
                        delegate: Item {
                            id: card
                            required property var modelData
                            visible: win.activeShelf === "" || modelData.shelfId === win.activeShelf
                            width: visible ? 182 : 0
                            height: visible ? 295 : 0
                            Rectangle {
                                id: cover
                                width: 182
                                height: 250
                                radius: 3
                                color: ["#345047", "#6b433e", "#435772", "#72603e", "#4b455d", "#37615e"][(card.modelData.coverSeed || card.modelData.title.length) % 6]
                                Image {
                                    anchors.fill: parent
                                    source: win.backend.coverUrl(card.modelData.id, card.modelData.coverImage || "")
                                    fillMode: Image.PreserveAspectCrop
                                    visible: source.toString() !== ""
                                }
                                Rectangle {
                                    x: 12
                                    y: 0
                                    width: 1
                                    height: parent.height
                                    color: "#50ffffff"
                                }
                                Rectangle {
                                    x: 38
                                    y: 36
                                    width: 98
                                    height: 98
                                    radius: 49
                                    color: "#18ffffff"
                                    rotation: 30
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: 74
                                    width: 144
                                    text: card.modelData.title
                                    font.family: "Georgia"
                                    font.pixelSize: 25
                                    color: "#fff8df"
                                    wrapMode: Text.WordWrap
                                    horizontalAlignment: Text.AlignHCenter
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 22
                                    width: 144
                                    text: card.modelData.author || "Anonymous"
                                    color: "#eee6ce"
                                    font.pixelSize: 11
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: win.backend.openBook(card.modelData.id)
                                }
                                ProgressBar {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    from: 0
                                    to: card.modelData.wordGoal || 1
                                    value: card.modelData.wordCount || 0
                                    visible: card.modelData.wordGoal > 0
                                }
                            }
                            Label {
                                y: 262
                                text: (card.modelData.wordCount || 0).toLocaleString() + " words"
                                color: win.muted
                                font.pixelSize: 12
                            }
                        }
                    }
                    Button {
                        text: "+\nA new story"
                        width: 182
                        height: 250
                        onClicked: newBook.open()
                    }
                }
            }
        }

        RowLayout {
            visible: win.backend.opened
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            Rectangle {
                visible: !win.focusMode
                Layout.preferredWidth: 245
                Layout.fillHeight: true
                color: win.surface
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    ComboBox {
                        Layout.fillWidth: true
                        model: ["Chapters", "Outline", "Darlings", "Placeholders"]
                        onActivated: win.panel = currentText
                    }
                    ListView {
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                        clip: true
                        spacing: 5
                        model: win.panel === "Darlings" ? win.backend.darlings : win.panel === "Placeholders" ? win.backend.stickies : win.backend.chapters
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: ListView.view.width
                            height: itemColumn.implicitHeight + 20
                            radius: 6
                            color: modelData.id === win.backend.chapterId ? (win.dark ? "#39483a" : "#dce5d7") : "transparent"
                            ColumnLayout {
                                id: itemColumn
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 10
                                Label {
                                    Layout.fillWidth: true
                                    text: win.panel === "Darlings" ? modelData.text : win.panel === "Placeholders" ? (modelData.resolved ? "✓ " : "● ") + modelData.text : (modelData.flagged ? "● " : "") + modelData.title
                                    color: win.ink
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 4
                                    elide: Text.ElideRight
                                }
                                Label {
                                    visible: win.panel === "Chapters" || win.panel === "Outline"
                                    text: (modelData.words || 0) + " words"
                                    color: win.muted
                                    font.pixelSize: 11
                                }
                                TextArea {
                                    visible: win.panel === "Outline"
                                    Layout.fillWidth: true
                                    text: modelData.note || ""
                                    placeholderText: "What happens here?"
                                    wrapMode: TextEdit.Wrap
                                    onActiveFocusChanged: if (!activeFocus)
                                        win.backend.setChapterNote(modelData.id, text)
                                }
                                RowLayout {
                                    Button {
                                        text: win.panel === "Darlings" ? "Restore" : win.panel === "Placeholders" ? "Resolve" : "Open"
                                        onClicked: win.panel === "Darlings" ? win.backend.restoreDarling(index) : win.panel === "Placeholders" ? win.backend.updateSticky(index, modelData.text, !modelData.resolved) : win.backend.selectChapter(modelData.id)
                                    }
                                    ToolButton {
                                        visible: win.panel === "Chapters" || win.panel === "Outline"
                                        text: "↑"
                                        onClicked: win.backend.moveChapter(modelData.id, -1)
                                    }
                                    ToolButton {
                                        visible: win.panel === "Chapters" || win.panel === "Outline"
                                        text: "↓"
                                        onClicked: win.backend.moveChapter(modelData.id, 1)
                                    }
                                }
                            }
                        }
                    }
                    Button {
                        text: "+ Chapter"
                        Layout.fillWidth: true
                        onClicked: win.backend.newChapter("")
                    }
                }
            }
            Rectangle {
                Layout.fillHeight: true
                Layout.fillWidth: true
                color: win.paper
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0
                    RowLayout {
                        visible: !win.focusMode
                        Layout.fillWidth: true
                        Layout.margins: 16
                        Repeater {
                            model: ["manuscript", "notes", "outline"]
                            delegate: Button {
                                required property string modelData
                                text: modelData.charAt(0).toUpperCase() + modelData.slice(1)
                                flat: true
                                highlighted: win.backend.tab === modelData
                                onClicked: win.backend.selectTab(modelData)
                            }
                        }
                        Item {
                            Layout.fillWidth: true
                        }
                        ToolButton {
                            text: "B"
                            font.bold: true
                            onClicked: win.backend.format("bold")
                        }
                        ToolButton {
                            text: "I"
                            font.italic: true
                            onClicked: win.backend.format("italic")
                        }
                        ToolButton {
                            text: "***"
                            onClicked: win.backend.sceneBreak()
                        }
                    }
                    ScrollView {
                        id: scroll
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: availableWidth
                        TextEdit {
                            id: editor
                            width: scroll.availableWidth
                            padding: Math.max(28, (width - 660) / 2)
                            topPadding: 38
                            bottomPadding: win.typewriter ? scroll.height / 2 : 90
                            color: win.ink
                            selectionColor: win.accent
                            selectedTextColor: win.paper
                            font.family: win.backend.settings.fontFamily || "Georgia"
                            font.pointSize: win.backend.settings.fontSize || 16
                            textFormat: TextEdit.RichText
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true
                            persistentSelection: true
                            activeFocusOnTab: true
                            Accessible.name: "Manuscript editor"
                            Component.onCompleted: win.backend.attach(textDocument)
                            onCursorPositionChanged: {
                                win.backend.selection(selectionStart, selectionEnd, cursorPosition);
                                if (win.typewriter && activeFocus)
                                    scroll.contentItem.contentY = Math.max(0, cursorRectangle.y - scroll.height / 2);
                            }
                            onSelectionStartChanged: win.backend.selection(selectionStart, selectionEnd, cursorPosition)
                            onSelectionEndChanged: win.backend.selection(selectionStart, selectionEnd, cursorPosition)
                            Keys.onPressed: function (event) {
                                if (event.key === Qt.Key_Escape) {
                                    win.focusMode = false;
                                    event.accepted = true;
                                    return;
                                }
                                if (event.key === Qt.Key_Return && (event.modifiers & Qt.ShiftModifier)) {
                                    win.backend.format("poetry");
                                    return;
                                }
                                if (event.key !== Qt.Key_Return)
                                    win.enterCount = 0;
                            }
                        }
                    }
                }
            }
        }
    }
    footer: ToolBar {
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            Label {
                text: win.backend.status
                color: win.muted
                Layout.fillWidth: true
            }
            ToolButton {
                visible: win.focusMode
                text: "Exit focus"
                onClicked: win.focusMode = false
            }
            Label {
                visible: win.backend.opened
                text: win.backend.wordCount.toLocaleString() + " words"
            }
            ToolButton {
                visible: win.backend.opened
                text: win.sprintTarget > 0 ? (win.backend.wordCount - win.sprintStart) + " / " + win.sprintTarget + " sprint" : win.backend.todayCount + " today"
                onClicked: goals.open()
            }
        }
    }

    FileDialog {
        id: importDialog
        title: "Import manuscript"
        nameFilters: ["Manuscripts (*.docx *.txt *.md)"]
        onAccepted: win.backend.importFile(selectedFile)
    }
    FileDialog {
        id: exportDialog
        title: "Export manuscript"
        fileMode: FileDialog.SaveFile
        onAccepted: win.backend.exportFile(selectedFile, win.exportFormat)
    }
    FileDialog {
        id: coverDialog
        title: "Choose cover art"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp)"]
        onAccepted: win.backend.setCover(selectedFile)
    }
    FolderDialog {
        id: libraryImport
        title: "Copy books from a Neo library (originals are kept)"
        onAccepted: win.backend.importLibrary(selectedFolder)
    }

    Dialog {
        id: prompt
        anchors.centerIn: parent
        modal: true
        width: 380
        property var action
        standardButtons: Dialog.Ok | Dialog.Cancel
        TextField {
            id: promptField
            width: parent.width
            onAccepted: prompt.accept()
        }
        onAccepted: if (action)
            action(promptField.text)
    }
    Dialog {
        id: newBook
        anchors.centerIn: parent
        modal: true
        title: "Begin a new story"
        width: 400
        standardButtons: Dialog.Ok | Dialog.Cancel
        onOpened: {
            newTitle.text = "";
            newAuthor.text = win.backend.settings.authorName || "";
            newTitle.forceActiveFocus();
        }
        ColumnLayout {
            width: parent.width
            TextField {
                id: newTitle
                placeholderText: "Book title"
                Layout.fillWidth: true
            }
            TextField {
                id: newAuthor
                placeholderText: "Author or pen name"
                Layout.fillWidth: true
            }
        }
        onAccepted: win.backend.createBook(newTitle.text, newAuthor.text, win.activeShelf)
    }
    Dialog {
        id: details
        anchors.centerIn: parent
        modal: true
        title: "Book details"
        width: 440
        standardButtons: Dialog.Save | Dialog.Cancel
        onOpened: {
            bookTitle.text = win.backend.book.title || "";
            bookAuthor.text = win.backend.book.author || "";
            subtitle.text = win.backend.book.subtitle || "";
            series.text = win.backend.book.series || "";
            bookGoal.value = win.backend.book.wordGoal || 0;
        }
        ColumnLayout {
            width: parent.width
            TextField {
                id: bookTitle
                placeholderText: "Title"
                Layout.fillWidth: true
            }
            TextField {
                id: bookAuthor
                placeholderText: "Author"
                Layout.fillWidth: true
            }
            TextField {
                id: subtitle
                placeholderText: "Subtitle"
                Layout.fillWidth: true
            }
            TextField {
                id: series
                placeholderText: "Series"
                Layout.fillWidth: true
            }
            Label {
                text: "Manuscript word goal"
            }
            SpinBox {
                id: bookGoal
                from: 0
                to: 1000000
                stepSize: 1000
                editable: true
            }
            RowLayout {
                Button {
                    text: "Choose cover…"
                    onClicked: coverDialog.open()
                }
                Button {
                    text: "Reroll cover"
                    onClicked: win.backend.rerollCover()
                }
            }
            ComboBox {
                id: shelfChoice
                model: win.backend.shelves
                textRole: "name"
                valueRole: "id"
                Layout.fillWidth: true
            }
            Button {
                text: "Move to shelf"
                onClicked: win.backend.moveBook(win.backend.book.id, shelfChoice.currentValue)
            }
        }
        onAccepted: win.backend.updateBook({
            title: bookTitle.text,
            author: bookAuthor.text,
            subtitle: subtitle.text,
            series: series.text,
            wordGoal: bookGoal.value
        })
    }
    Dialog {
        id: preferences
        anchors.centerIn: parent
        modal: true
        title: "Writing preferences"
        width: 440
        standardButtons: Dialog.Close
        ColumnLayout {
            width: parent.width
            Label {
                text: "Default author"
            }
            TextField {
                text: win.backend.settings.authorName || ""
                Layout.fillWidth: true
                onEditingFinished: win.backend.updateSetting("authorName", text)
            }
            Label {
                text: "Typeface"
            }
            ComboBox {
                model: win.backend.fontFamilies()
                Layout.fillWidth: true
                onActivated: win.backend.updateSetting("fontFamily", currentText)
            }
            Label {
                text: "Text size"
            }
            SpinBox {
                from: 10
                to: 40
                value: win.backend.settings.fontSize || 16
                onValueModified: win.backend.updateSetting("fontSize", value)
            }
            CheckBox {
                text: "Dark page"
                checked: win.dark
                onToggled: win.backend.updateSetting("pageTheme", checked ? "night" : "day")
            }
            CheckBox {
                text: "Typewriter scrolling"
                checked: win.typewriter
                onToggled: win.typewriter = checked
            }
            Label {
                text: "Spellcheck language"
            }
            ComboBox {
                id: spellLanguage
                model: ["en_US", "en_GB", "fr_FR", "de_DE", "es_ES", "it_IT", "nl_NL", "pt_PT", "pl_PL"]
            }
        }
    }
    Dialog {
        id: goals
        anchors.centerIn: parent
        modal: true
        title: "Goals and momentum"
        width: 540
        standardButtons: Dialog.Close
        ColumnLayout {
            width: parent.width
            Label {
                text: win.backend.todayCount + " words today · " + win.backend.wordCount + " in this book"
            }
            RowLayout {
                Label {
                    text: "Daily goal"
                }
                SpinBox {
                    from: 0
                    to: 50000
                    stepSize: 100
                    value: win.backend.settings.dailyGoal || 0
                    editable: true
                    onValueModified: win.backend.updateSetting("dailyGoal", value)
                }
                Label {
                    text: "Day ends at"
                }
                SpinBox {
                    from: 0
                    to: 12
                    value: win.backend.settings.dayEndsAt || 0
                    onValueModified: win.backend.updateSetting("dayEndsAt", value)
                }
            }
            Row {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                spacing: 3
                Repeater {
                    model: win.backend.progress
                    delegate: Rectangle {
                        required property var modelData
                        width: 12
                        height: Math.max(2, Math.min(120, modelData.words / Math.max(1, win.backend.settings.dailyGoal || 1000) * 100))
                        y: 120 - height
                        color: win.accent
                        ToolTip.visible: barMouse.containsMouse
                        ToolTip.text: modelData.date + ": " + modelData.words
                        MouseArea {
                            id: barMouse
                            anchors.fill: parent
                            hoverEnabled: true
                        }
                    }
                }
            }
            Label {
                text: "Words written each day · last 30 days"
            }
            RowLayout {
                SpinBox {
                    id: sprintWords
                    from: 100
                    to: 10000
                    stepSize: 100
                    value: 500
                }
                Button {
                    text: win.sprintTarget ? "End sprint" : "Start word sprint"
                    onClicked: {
                        win.sprintStart = win.backend.wordCount;
                        win.sprintTarget = win.sprintTarget ? 0 : sprintWords.value;
                    }
                }
            }
        }
    }
    Dialog {
        id: spelling
        property var words: []
        anchors.centerIn: parent
        modal: true
        title: "Spellcheck pass"
        width: 430
        height: 440
        standardButtons: Dialog.Close
        ListView {
            anchors.fill: parent
            model: spelling.words
            clip: true
            delegate: RowLayout {
                required property string modelData
                width: ListView.view.width
                Label {
                    text: modelData
                    Layout.fillWidth: true
                }
                Button {
                    text: "Find"
                    onClicked: {
                        win.backend.find(modelData);
                        spelling.close();
                    }
                }
                Button {
                    text: "Learn"
                    onClicked: {
                        win.backend.learn(modelData);
                        spelling.words = win.backend.spellcheck(spellLanguage.currentText);
                    }
                }
            }
        }
    }
    Dialog {
        id: errorDialog
        anchors.centerIn: parent
        modal: true
        title: "Neon needs your attention"
        width: 520
        standardButtons: Dialog.Ok
        Label {
            id: errorText
            width: parent.width
            wrapMode: Text.WordWrap
        }
    }
    Dialog {
        id: about
        anchors.centerIn: parent
        title: "About Neon"
        modal: true
        width: 460
        standardButtons: Dialog.Close
        Label {
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Neon 0.1 — native macOS preview\n\nAn independent C++23 / Qt reimplementation inspired by NEO, the novel-writing application created by Hugh Howey.\n\nOriginal project: github.com/hughhowey/neo\n\nNEO is MIT licensed. Neon is not affiliated with or endorsed by Hugh Howey.\n\nFeature parity and performance validation are in progress."
        }
    }
    Popup {
        id: toastPopup
        x: (win.width - width) / 2
        y: win.height - 120
        width: Math.min(600, win.width - 60)
        Label {
            id: toastLabel
            width: parent.width
            wrapMode: Text.WordWrap
        }
    }
    Timer {
        id: toastTimer
        interval: 4500
        onTriggered: toastPopup.close()
    }
}
