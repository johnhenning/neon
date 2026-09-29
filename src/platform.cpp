#include "platform.h"
#ifndef Q_OS_MACOS
#include <QDesktopServices>
#include <QUrl>
namespace platform {
QStringList misspellings(const QString&, const QString&) {
    return {};
}
QStringList suggestions(const QString&, const QString&) {
    return {};
}
void learnWord(const QString&) {}
bool storeSecret(const QString&, const QString&) {
    return false;
}
QString secret(const QString&) {
    return {};
}
bool shareFile(const QString& path, const QString&, const QString&) {
    return QDesktopServices::openUrl(QUrl::fromLocalFile(path));
}
} // namespace platform
#endif
