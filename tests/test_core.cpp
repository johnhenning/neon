#include <QtTest>
#include <QTemporaryDir>
#include "store.h"
#include "formats.h"
class CoreTests:public QObject {Q_OBJECT
private slots:
void roundtrip(){QTemporaryDir t;neon::Store s(t.path());s.initialize();s.transaction({{"book-test/chapters/ch-1.html","<p>Hello</p>"}});QCOMPARE(s.read("book-test/chapters/ch-1.html"),QByteArray("<p>Hello</p>"));QVERIFY(!s.exists(".neon-transaction.json"));}
void traversal(){QTemporaryDir t;neon::Store s(t.path());QVERIFY_EXCEPTION_THROWN(s.write("../escape","oops"),neon::Error);}
void count(){QCOMPARE(neon::Formats::words("<p>Hello, world! It’s a story.</p>"),5);}
};
QTEST_MAIN(CoreTests)
#include "test_core.moc"
