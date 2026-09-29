#pragma once
#include <QByteArray>
#include <QJsonArray>
#include <QJsonObject>
#include <QMap>
#include <QString>
#include <stdexcept>
namespace neon {
class Error : public std::runtime_error {
  public:
    explicit Error(const QString& s) : std::runtime_error(s.toStdString()) {}
};
class Store {
  public:
    explicit Store(QString root);
    QString root() const {
        return root_;
    }
    QString path(const QString& relative) const;
    bool exists(const QString& relative) const;
    QByteArray read(const QString& relative, bool optional = false) const;
    QJsonObject object(const QString& relative, bool optional = false) const;
    QJsonArray array(const QString& relative, bool optional = false) const;
    void write(const QString& relative, const QByteArray& bytes);
    void transaction(const QMap<QString, QByteArray>& files);
    void initialize();
    void recover();
    QStringList bookIds() const;
    static QByteArray encode(const QJsonObject& o);
    static QByteArray encode(const QJsonArray& a);
    static QString id(const QString& prefix);
    static QString safeId(const QString& id);

  private:
    QString root_;
};
} // namespace neon
