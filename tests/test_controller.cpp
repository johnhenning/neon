#include "controller.h"
#include <QTemporaryDir>
#include <QTextCursor>
#include <QtTest>

class ControllerTests : public QObject {
    Q_OBJECT
  private slots:
    void wholeBookSearchAndReplace() {
        QTemporaryDir directory;
        QTextDocument document;
        Controller controller(directory.path());
        controller.attachDocument(&document);
        controller.createBook("Search", "Writer", "");
        const auto first = controller.chapterId();
        document.setHtml("<p>One <b>harbor</b>.</p>");
        QVERIFY(controller.save());
        controller.newChapter("Second");
        const auto second = controller.chapterId();
        document.setHtml("<p>Another HARBOR.</p>");
        QVERIFY(controller.save());
        controller.selectChapter(first);
        controller.selection(0, 0, 0);
        controller.find("harbor");
        QCOMPARE(controller.chapterId(), first);
        controller.find("harbor");
        QCOMPARE(controller.chapterId(), second);
        controller.find("harbor");
        QCOMPARE(controller.chapterId(), first);
        controller.find("harbor", true);
        QCOMPARE(controller.chapterId(), second);
        controller.replace("harbor", "bay", true);
        QCOMPARE(document.toPlainText(), QString("Another bay."));
        controller.selectChapter(first);
        QCOMPARE(document.toPlainText(), QString("One bay."));
        controller.undo();
        controller.selectChapter(first);
        QCOMPARE(document.toPlainText(), QString("One harbor."));
        controller.selectChapter(second);
        QCOMPARE(document.toPlainText(), QString("Another HARBOR."));
        QVERIFY(controller.save());
    }
    void splitIsOneUndoStep() {
        QTemporaryDir directory;
        QTextDocument document;
        Controller controller(directory.path());
        controller.attachDocument(&document);
        controller.createBook("Split", "", "");
        document.setPlainText("Alpha Beta");
        QVERIFY(controller.save());
        controller.selection(6, 6, 6);
        controller.splitChapter();
        QCOMPARE(controller.chapters().size(), 2);
        QCOMPARE(document.toPlainText(), QString("Beta"));
        controller.undo();
        QCOMPARE(controller.chapters().size(), 1);
        QCOMPARE(document.toPlainText(), QString("Alpha Beta"));
        controller.redo();
        QCOMPARE(controller.chapters().size(), 2);
        QCOMPARE(document.toPlainText(), QString("Beta"));
    }
    void emptyNeoBookOpensSafely() {
        QTemporaryDir directory;
        neon::Store store(directory.path());
        store.initialize();
        store.write("book-empty/book.json",
                    neon::Store::encode(QJsonObject{
                        {"id", "book-empty"}, {"title", "Empty"}, {"chapterOrder", QJsonArray{}}}));
        QTextDocument document;
        Controller controller(directory.path());
        controller.attachDocument(&document);
        controller.openBook("book-empty");
        QVERIFY(controller.opened());
        QCOMPARE(controller.chapters().size(), 1);
        document.setPlainText("A fresh beginning.");
        QVERIFY(controller.save());
        controller.closeBook();
        controller.openBook("book-empty");
        QCOMPARE(document.toPlainText(), QString("A fresh beginning."));
    }
};
QTEST_MAIN(ControllerTests)
#include "test_controller.moc"
