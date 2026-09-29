#pragma once
#include "formats.h"
#include "store.h"
#include <QLockFile>
#include <QObject>
#include <QQuickTextDocument>
#include <QTextCursor>
#include <QTextDocument>
#include <QTimer>
#include <QVariantList>
#include <memory>
#include <qqmlintegration.h>
class Controller : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("Provided by the application")
    Q_PROPERTY(QVariantList books READ books NOTIFY libraryChanged)
    Q_PROPERTY(QVariantList shelves READ shelves NOTIFY libraryChanged)
    Q_PROPERTY(QVariantList chapters READ chapters NOTIFY bookChanged)
    Q_PROPERTY(QVariantList darlings READ darlings NOTIFY bookChanged)
    Q_PROPERTY(QVariantList stickies READ stickies NOTIFY bookChanged)
    Q_PROPERTY(QVariantMap book READ book NOTIFY bookChanged)
    Q_PROPERTY(QVariantMap settings READ settings NOTIFY libraryChanged)
    Q_PROPERTY(QString chapterId READ chapterId NOTIFY locationChanged)
    Q_PROPERTY(QString tab READ tab NOTIFY locationChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString libraryPath READ libraryPath CONSTANT)
    Q_PROPERTY(bool opened READ opened NOTIFY bookChanged)
    Q_PROPERTY(int wordCount READ wordCount NOTIFY bookChanged)
    Q_PROPERTY(int todayCount READ todayCount NOTIFY bookChanged)
    Q_PROPERTY(QVariantList progress READ progress NOTIFY bookChanged)
  public:
    explicit Controller(QString root, QObject* parent = nullptr);
    QVariantList books() const;
    QVariantList shelves() const;
    QVariantList chapters() const;
    QVariantList darlings() const {
        return darlings_.toVariantList();
    }
    QVariantList stickies() const {
        return stickies_.toVariantList();
    }
    QVariantMap book() const {
        return book_.toVariantMap();
    }
    QVariantMap settings() const {
        return library_.toVariantMap();
    }
    QString chapterId() const {
        return chapter_;
    }
    QString tab() const {
        return tab_;
    }
    QString status() const {
        return status_;
    }
    QString libraryPath() const {
        return store_->root();
    }
    bool opened() const {
        return !book_.isEmpty();
    }
    int wordCount() const;
    int todayCount() const;
    QVariantList progress() const;
    Q_INVOKABLE void attach(QQuickTextDocument* document);
    Q_INVOKABLE void selection(int start, int end, int cursor);
    Q_INVOKABLE bool save();
    Q_INVOKABLE void createBook(const QString& title, const QString& author, const QString& shelf);
    Q_INVOKABLE void openBook(const QString& id);
    Q_INVOKABLE void closeBook();
    Q_INVOKABLE void selectChapter(const QString& id);
    Q_INVOKABLE void selectTab(const QString& tab);
    Q_INVOKABLE void newChapter(const QString& title = QString());
    Q_INVOKABLE void renameChapter(const QString& id, const QString& title);
    Q_INVOKABLE void moveChapter(const QString& id, int direction);
    Q_INVOKABLE void splitChapter();
    Q_INVOKABLE void mergePrevious();
    Q_INVOKABLE void sceneBreak();
    Q_INVOKABLE void format(const QString& style);
    Q_INVOKABLE void undo();
    Q_INVOKABLE void redo();
    Q_INVOKABLE void saveDarling();
    Q_INVOKABLE void restoreDarling(int index);
    Q_INVOKABLE void addSticky(const QString& text);
    Q_INVOKABLE void updateSticky(int index, const QString& text, bool resolved);
    Q_INVOKABLE void setChapterNote(const QString& id, const QString& text);
    Q_INVOKABLE void updateBook(const QVariantMap& changes);
    Q_INVOKABLE void updateSetting(const QString& key, const QVariant& value);
    Q_INVOKABLE void addShelf(const QString& name);
    Q_INVOKABLE void renameShelf(const QString& id, const QString& name);
    Q_INVOKABLE void moveBook(const QString& id, const QString& shelf);
    Q_INVOKABLE void removeFromShelf(const QString& id);
    Q_INVOKABLE void find(const QString& text, bool backwards = false);
    Q_INVOKABLE void replace(const QString& find, const QString& replacement, bool all = false);
    Q_INVOKABLE QStringList spellcheck(const QString& language);
    Q_INVOKABLE QStringList suggestions(const QString& word, const QString& language);
    Q_INVOKABLE void learn(const QString& word);
    Q_INVOKABLE void importFile(const QUrl& url);
    Q_INVOKABLE void importLibrary(const QUrl& url);
    Q_INVOKABLE void exportFile(const QUrl& url, const QString& format);
    Q_INVOKABLE void backup();
    Q_INVOKABLE void emailDraft();
    Q_INVOKABLE void setCover(const QUrl& url);
    Q_INVOKABLE void rerollCover();
    Q_INVOKABLE QString coverUrl(const QString& id, const QString& file) const;
    Q_INVOKABLE bool setApiKey(const QString& key);
    Q_INVOKABLE void generateCover();
    Q_INVOKABLE QStringList fontFamilies() const;
  signals:
    void libraryChanged();
    void bookChanged();
    void locationChanged();
    void statusChanged();
    void documentLoaded(const QString& html);
    void cursorRequested(int position, int anchor);
    void error(const QString& message);
    void notice(const QString& message);

  private:
    std::unique_ptr<neon::Store> store_;
    std::unique_ptr<QLockFile> lock_;
    QJsonObject library_, book_;
    QJsonArray darlings_, stickies_;
    QMap<QString, QJsonObject> catalog_;
    QMap<QString, QString> html_;
    QMap<QString, QByteArray> baseline_, pending_;
    QQuickTextDocument* quick_ = nullptr;
    QTextDocument* document_ = nullptr;
    QTimer autosave_;
    bool loading_ = false;
    QString chapter_, tab_ = "manuscript", status_ = "Saved locally";
    int selectionStart_ = 0, selectionEnd_ = 0, cursor_ = 0;
    struct Snapshot {
        QJsonObject book;
        QJsonArray darlings, stickies;
        QMap<QString, QString> html;
        QString chapter;
    };
    QList<Snapshot> undo_, redo_;
    QString bookId() const {
        return book_["id"].toString();
    }
    QString docPath() const;
    void loadDocument();
    void capture();
    void mark(const QString& path, const QByteArray& bytes);
    void markBook();
    void markLibrary();
    void changed();
    void setStatus(const QString& status);
    void fail(const std::exception& e);
    QString readHtml(const QString& path);
    QTextCursor cursor() const;
    void checkpoint();
    Snapshot snapshot() const;
    void restore(const Snapshot& state);
    QString day() const;
    void trackWords(int previous);
    neon::Manuscript manuscript();
};
