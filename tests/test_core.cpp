#include "formats.h"
#include "store.h"
#include <QFile>
#include <QTemporaryDir>
#include <QTextDocument>
#include <QtTest>

class CoreTests : public QObject {
    Q_OBJECT
  private slots:
    void roundtrip() {
        QTemporaryDir temp;
        neon::Store store(temp.path());
        store.initialize();
        store.transaction({{"book-test/chapters/ch-1.html", "<p>Hello</p>"}});
        QCOMPARE(store.read("book-test/chapters/ch-1.html"), QByteArray("<p>Hello</p>"));
        QVERIFY(!store.exists(".neon-transaction.json"));
    }
    void traversal() {
        QTemporaryDir temp;
        neon::Store store(temp.path());
        for (const auto& path : {"../escape", "book/../../escape", "/absolute", "a\\b"}) {
            QVERIFY_EXCEPTION_THROWN(store.write(path, "oops"), neon::Error);
        }
    }
    void recovery() {
        QTemporaryDir temp;
        neon::Store store(temp.path());
        store.initialize();
        QJsonObject entries{
            {"book-a/book.json",
             QString::fromLatin1(QByteArray("{\"title\":\"Recovered\"}").toBase64())}};
        store.write(".neon-transaction.json", neon::Store::encode(entries));
        neon::Store reopened(temp.path());
        reopened.initialize();
        QCOMPARE(reopened.object("book-a/book.json")["title"].toString(), QString("Recovered"));
        QVERIFY(!reopened.exists(".neon-transaction.json"));
    }
    void corruptMetadataIsNotReset() {
        QTemporaryDir temp;
        neon::Store store(temp.path());
        store.write("library.json", "broken");
        QVERIFY_EXCEPTION_THROWN(store.initialize(), neon::Error);
        QCOMPARE(store.read("library.json"), QByteArray("broken"));
    }
    void count() {
        QCOMPARE(neon::Formats::words("<p>Hello, world! It’s a story.</p>"), 5);
    }
    void zipRoundtrip() {
        QMap<QString, QByteArray> files{{"mimetype", "application/epub+zip"},
                                        {"chapter.xml", "<p>Écriture</p>"},
                                        {"empty", ""}};
        QCOMPARE(neon::Formats::unzip(neon::Formats::zip(files)), files);
    }
    void zipRejectsTraversal() {
        auto bytes = neon::Formats::zip({{"../escape", "bad"}});
        QVERIFY_EXCEPTION_THROWN(neon::Formats::unzip(bytes), neon::Error);
    }
    void zipRejectsCorruption() {
        auto bytes = neon::Formats::zip({{"file", "content"}});
        bytes[34] = 'X';
        QVERIFY_EXCEPTION_THROWN(neon::Formats::unzip(bytes), neon::Error);
    }
    void docxPreservesTextAndEmphasis() {
        neon::Manuscript book{
            "Title & more",
            "Author",
            "",
            {{"Chapter one", "<p>Hello <b>bold</b> and <i>italic</i> — café.</p>"}}};
        auto data = neon::Formats::exportData(book, "docx");
        auto entries = neon::Formats::unzip(data);
        QVERIFY(entries["word/document.xml"].contains("<w:b/>"));
        auto imported = neon::Formats::importData(data, "docx", "Imported");
        QVERIFY(imported.chapters.size() >= 1);
        auto last = imported.chapters.last();
        QVERIFY(neon::Formats::plain(last.html).contains("café"));
        QVERIFY(last.html.contains("<b>bold</b>"));
    }
    void epubStructure() {
        neon::Manuscript book{"Test", "Author", "", {{"One", "<p>Hello.</p>"}}};
        auto bytes = neon::Formats::exportData(book, "epub");
        auto entries = neon::Formats::unzip(bytes);
        QCOMPARE(bytes.mid(30, 8), QByteArray("mimetype"));
        QVERIFY(entries.contains("META-INF/container.xml"));
        QVERIFY(entries["OEBPS/nav.xhtml"].contains("ch1.xhtml"));
        QVERIFY(entries["OEBPS/content.opf"].contains("version=\"3.0\""));
    }
    void markdownImport() {
        auto m = neon::Formats::importData(
            "## Arrival\n\nA **bold** start.\n\n## Departure\n\nThe end.", "md", "Test");
        QCOMPARE(m.chapters.size(), 2);
        QCOMPARE(m.chapters.first().title, QString("Arrival"));
        QVERIFY(neon::Formats::plain(m.chapters.last().html).contains("The end."));
    }
    void pdfExport() {
        QTemporaryDir dir;
        neon::Manuscript book{"Test", "Author", "", {{"One", "<p>Hello.</p>"}}};
        auto path = dir.filePath("test.pdf");
        QVERIFY(neon::Formats::pdf(book, path));
        QFile file(path);
        QVERIFY(file.open(QIODevice::ReadOnly));
        QVERIFY(file.read(5) == "%PDF-");
    }
};
QTEST_MAIN(CoreTests)
#include "test_core.moc"
