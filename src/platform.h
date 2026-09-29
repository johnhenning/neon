#pragma once
#include <QString>
#include <QStringList>
namespace platform {
QStringList misspellings(const QString& text, const QString& language);
QStringList suggestions(const QString& word, const QString& language);
void learnWord(const QString& word);
bool storeSecret(const QString& name, const QString& secret);
QString secret(const QString& name);
bool shareFile(const QString& path, const QString& subject, const QString& body);
} // namespace platform
