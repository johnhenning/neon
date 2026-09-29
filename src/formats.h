#pragma once
#include <QByteArray>
#include <QList>
#include <QMap>
#include <QString>
namespace neon {
struct Chapter {
    QString title;
    QString html;
};
struct Manuscript {
    QString title;
    QString author;
    QString subtitle;
    QList<Chapter> chapters;
};
class Formats {
  public:
    static int words(const QString& html);
    static QString plain(const QString& html);
    static QString html(const Manuscript& book);
    static QByteArray exportData(const Manuscript& book, const QString& format);
    static Manuscript importData(const QByteArray& bytes, const QString& format,
                                 const QString& title);
    static QByteArray zip(const QMap<QString, QByteArray>& entries);
    static QMap<QString, QByteArray> unzip(const QByteArray& bytes);
    static bool pdf(const Manuscript& book, const QString& path);
};
} // namespace neon
