#include "controller.h"
#include "platform.h"
#include <QBuffer>
#include <QCryptographicHash>
#include <QDateTime>
#include <QDesktopServices>
#include <QDirIterator>
#include <QFileInfo>
#include <QFontDatabase>
#include <QImageReader>
#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QRandomGenerator>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTextBlock>
#include <QTextBlockFormat>
#include <QTextDocumentFragment>
#include <QUrlQuery>
#include <memory>
using neon::Error;
using neon::Formats;
using neon::Manuscript;
using neon::Store;
namespace {
QString now() {
    return QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);
}
QString body(const QString& html) {
    auto a = html.indexOf("<body");
    if (a < 0)
        return html;
    auto start = html.indexOf('>', a) + 1;
    auto end = html.lastIndexOf("</body>");
    return html.mid(start, end - start);
}
} // namespace
Controller::Controller(QString root, QObject* p) : QObject(p) {
    store_ = std::make_unique<Store>(root);
    lock_ = std::make_unique<QLockFile>(store_->root() + "/.neon.lock");
    if (!lock_->tryLock())
        throw Error("This library is already open in another Neon process.");
    store_->initialize();
    library_ = store_->object("library.json");
    baseline_["library.json"] = store_->read("library.json");
    for (const auto& id : store_->bookIds()) {
        auto meta = store_->object(id + "/book.json");
        if (meta["id"].toString() != id)
            throw Error("Book metadata does not match its folder: " + id);
        catalog_[id] = meta;
    }
    autosave_.setInterval(600);
    autosave_.setSingleShot(true);
    connect(&autosave_, &QTimer::timeout, this, [this] { save(); });
}
QVariantList Controller::books() const {
    QVariantList out;
    for (auto i = catalog_.cbegin(); i != catalog_.cend(); ++i) {
        auto b = i.value();
        QString shelf;
        for (const auto& s : library_["shelves"].toArray()) {
            auto o = s.toObject();
            if (o["bookIds"].toArray().contains(i.key())) {
                shelf = o["id"].toString();
                break;
            }
        }
        b["shelfId"] = shelf;
        out << b.toVariantMap();
    }
    return out;
}
QVariantList Controller::shelves() const {
    return library_["shelves"].toArray().toVariantList();
}
QVariantList Controller::chapters() const {
    QVariantList out;
    auto titles = book_["chapterTitles"].toObject(), notes = book_["chapterNotes"].toObject();
    int i = 0;
    for (auto v : book_["chapterOrder"].toArray()) {
        auto id = v.toString();
        bool flagged = false;
        for (auto s : stickies_) {
            auto o = s.toObject();
            if (o["chapterId"] == id && !o["resolved"].toBool())
                flagged = true;
        }
        out << QVariantMap{{"id", id},
                           {"title", titles[id].toString(QString("Chapter %1").arg(++i))},
                           {"note", notes[id].toString()},
                           {"words", Formats::words(html_.value(id))},
                           {"flagged", flagged}};
    }
    return out;
}
int Controller::wordCount() const {
    int n = 0;
    for (auto v : book_["chapterOrder"].toArray())
        n += Formats::words(html_.value(v.toString()));
    return n;
}
QString Controller::day() const {
    return QDateTime::currentDateTime()
        .addSecs(-3600 * library_["dayEndsAt"].toInt())
        .date()
        .toString(Qt::ISODate);
}
int Controller::todayCount() const {
    auto d = book_["dailyCounts"].toObject()[day()].toObject();
    return d["end"].toInt() - d["start"].toInt();
}
QVariantList Controller::progress() const {
    QVariantList out;
    auto counts = book_["dailyCounts"].toObject();
    auto end = QDate::fromString(day(), Qt::ISODate);
    for (int i = 29; i >= 0; --i) {
        auto d = end.addDays(-i).toString(Qt::ISODate);
        auto o = counts[d].toObject();
        out << QVariantMap{{"date", d},
                           {"words", qMax(0, o["end"].toInt() - o["start"].toInt())},
                           {"total", o["end"].toInt()}};
    }
    return out;
}
void Controller::setStatus(const QString& s) {
    status_ = s;
    emit statusChanged();
}
void Controller::fail(const std::exception& e) {
    setStatus("Save or operation failed");
    emit error(QString::fromUtf8(e.what()));
}
void Controller::mark(const QString& p, const QByteArray& b) {
    if (!baseline_.contains(p))
        baseline_[p] = store_->read(p, true);
    pending_[p] = b;
    setStatus("Unsaved changes");
    autosave_.start();
}
void Controller::markBook() {
    if (!opened())
        return;
    book_["modified"] = now();
    book_["wordCount"] = wordCount();
    mark(bookId() + "/book.json", Store::encode(book_));
    catalog_[bookId()] = book_;
    emit bookChanged();
}
void Controller::markLibrary() {
    mark("library.json", Store::encode(library_));
    emit libraryChanged();
}
QString Controller::readHtml(const QString& p) {
    auto b = store_->read(p, true);
    baseline_[p] = b;
    return QString::fromUtf8(b);
}
QString Controller::docPath() const {
    return bookId() + "/" + (tab_ == "manuscript" ? "chapters/" + chapter_ : tab_) + ".html";
}
void Controller::attach(QQuickTextDocument* d) {
    quick_ = d;
    attachDocument(d ? d->textDocument() : nullptr);
}
void Controller::attachDocument(QTextDocument* document) {
    if (document_)
        disconnect(document_, nullptr, this, nullptr);
    document_ = document;
    if (document_)
        connect(document_, &QTextDocument::contentsChanged, this, &Controller::changed);
    loadDocument();
}
void Controller::selection(int start, int end, int pos) {
    selectionStart_ = start;
    selectionEnd_ = end;
    cursor_ = pos;
}
QTextCursor Controller::cursor() const {
    QTextCursor c(document_);
    if (!document_)
        return c;
    auto max = document_->characterCount() - 1;
    c.setPosition(qBound(0, selectionStart_, max));
    c.setPosition(qBound(0, selectionEnd_, max), QTextCursor::KeepAnchor);
    if (selectionStart_ == selectionEnd_)
        c.setPosition(qBound(0, cursor_, max));
    return c;
}
void Controller::loadDocument() {
    if (!document_)
        return;
    loading_ = true;
    QString h = opened() ? html_.value(tab_ == "manuscript" ? chapter_ : tab_) : QString();
    document_->setHtml(h);
    document_->setModified(false);
    loading_ = false;
    selectionStart_ = selectionEnd_ = cursor_ = 0;
    emit documentLoaded(h);
    emit locationChanged();
    emit cursorRequested(0, 0);
}
void Controller::trackWords(int previous) {
    auto counts = book_["dailyCounts"].toObject();
    auto d = counts[day()].toObject();
    if (d.isEmpty())
        d["start"] = previous;
    d["end"] = wordCount();
    counts[day()] = d;
    book_["dailyCounts"] = counts;
}
void Controller::capture() {
    if (!document_ || !opened() || loading_)
        return;
    auto key = tab_ == "manuscript" ? chapter_ : tab_;
    auto current = document_->toHtml();
    if (html_.value(key) == current && !document_->isModified())
        return;
    int previous = wordCount();
    html_[key] = current;
    mark(docPath(), current.toUtf8());
    if (tab_ == "manuscript")
        trackWords(previous);
    markBook();
    document_->setModified(false);
}
void Controller::changed() {
    if (loading_ || !opened())
        return;
    setStatus("Writing…");
    autosave_.start();
}
bool Controller::save() {
    try {
        if (document_ && document_->isModified())
            capture();
        autosave_.stop();
        if (pending_.isEmpty())
            return true;
        for (auto i = pending_.cbegin(); i != pending_.cend(); ++i) {
            auto disk = store_->read(i.key(), true);
            if (disk != baseline_.value(i.key())) {
                auto conflict = "Conflicts/" +
                                QDateTime::currentDateTimeUtc().toString("yyyyMMdd-HHmmsszzz") +
                                "/" + i.key();
                store_->write(conflict, i.value());
                throw Error("External change detected in " + i.key() +
                            ". Your edits were preserved at " + conflict +
                            ". Close and reopen after resolving the conflict.");
            }
        }
        store_->transaction(pending_);
        for (auto i = pending_.cbegin(); i != pending_.cend(); ++i)
            baseline_[i.key()] = i.value();
        pending_.clear();
        setStatus("Saved locally");
        emit libraryChanged();
        return true;
    } catch (const std::exception& e) {
        fail(e);
        return false;
    }
}
void Controller::createBook(const QString& title, const QString& author, const QString& shelf) {
    try {
        if (!save())
            return;
        auto id = Store::id("book-"), ch = Store::id("ch-");
        QJsonObject b{{"id", id},
                      {"title", title.isEmpty() ? "Untitled" : title},
                      {"author", author},
                      {"created", now()},
                      {"modified", now()},
                      {"chapterOrder", QJsonArray{ch}},
                      {"wordGoal", 0},
                      {"wordCount", 0},
                      {"chapterTitles", QJsonObject{{ch, "Chapter 1"}}}};
        mark(id + "/book.json", Store::encode(b));
        mark(id + "/chapters/" + ch + ".html", "<p></p>");
        mark(id + "/darlings.json", "[]");
        mark(id + "/stickies.json", "[]");
        catalog_[id] = b;
        auto shelves = library_["shelves"].toArray();
        for (int i = 0; i < shelves.size(); ++i) {
            auto s = shelves[i].toObject();
            if ((shelf.isEmpty() && i == 0) || s["id"] == shelf) {
                auto ids = s["bookIds"].toArray();
                ids.append(id);
                s["bookIds"] = ids;
                shelves[i] = s;
                break;
            }
        }
        library_["shelves"] = shelves;
        markLibrary();
        if (save())
            openBook(id);
    } catch (const std::exception& e) {
        fail(e);
    }
}
void Controller::openBook(const QString& id) {
    try {
        if (!save())
            return;
        Store::safeId(id);
        auto meta = store_->object(id + "/book.json");
        if (meta["id"] != id)
            throw Error("Invalid book identifier");
        QMap<QString, QString> loaded;
        for (auto v : meta["chapterOrder"].toArray()) {
            auto ch = Store::safeId(v.toString());
            loaded[ch] = readHtml(id + "/chapters/" + ch + ".html");
        }
        loaded["notes"] = readHtml(id + "/notes.html");
        loaded["outline"] = readHtml(id + "/outline.html");
        book_ = meta;
        baseline_[id + "/book.json"] = store_->read(id + "/book.json");
        html_ = loaded;
        darlings_ = store_->array(id + "/darlings.json", true);
        stickies_ = store_->array(id + "/stickies.json", true);
        baseline_[id + "/darlings.json"] = store_->read(id + "/darlings.json", true);
        baseline_[id + "/stickies.json"] = store_->read(id + "/stickies.json", true);
        const auto order = book_["chapterOrder"].toArray();
        chapter_ = order.isEmpty() ? QString() : order.first().toString();
        tab_ = "manuscript";
        undo_.clear();
        redo_.clear();
        loadDocument();
        emit bookChanged();
        if (chapter_.isEmpty())
            newChapter();
    } catch (const std::exception& e) {
        fail(e);
    }
}
void Controller::closeBook() {
    if (!save())
        return;
    book_ = {};
    html_.clear();
    chapter_.clear();
    loadDocument();
    emit bookChanged();
}
void Controller::selectChapter(const QString& id) {
    if (!opened() || !book_["chapterOrder"].toArray().contains(id) || !save())
        return;
    chapter_ = id;
    tab_ = "manuscript";
    loadDocument();
}
void Controller::selectTab(const QString& tab) {
    if (!opened() || !QStringList{"manuscript", "notes", "outline"}.contains(tab) || !save())
        return;
    tab_ = tab;
    loadDocument();
}
Controller::Snapshot Controller::snapshot() const {
    return {book_, darlings_, stickies_, html_, chapter_};
}
void Controller::checkpoint() {
    capture();
    undo_.append(snapshot());
    if (undo_.size() > 30)
        undo_.removeFirst();
    redo_.clear();
}
void Controller::restore(const Snapshot& s) {
    book_ = s.book;
    darlings_ = s.darlings;
    stickies_ = s.stickies;
    html_ = s.html;
    chapter_ = s.chapter;
    tab_ = "manuscript";
    for (auto v : book_["chapterOrder"].toArray())
        mark(bookId() + "/chapters/" + v.toString() + ".html", html_.value(v.toString()).toUtf8());
    mark(bookId() + "/darlings.json", Store::encode(darlings_));
    mark(bookId() + "/stickies.json", Store::encode(stickies_));
    markBook();
    loadDocument();
}
void Controller::undo() {
    if (!document_)
        return;
    if (document_->isUndoAvailable()) {
        document_->undo();
        return;
    }
    if (!undo_.isEmpty()) {
        redo_ << snapshot();
        restore(undo_.takeLast());
    }
}
void Controller::redo() {
    if (!document_)
        return;
    if (document_->isRedoAvailable()) {
        document_->redo();
        return;
    }
    if (!redo_.isEmpty()) {
        undo_ << snapshot();
        restore(redo_.takeLast());
    }
}
void Controller::newChapter(const QString& title) {
    if (!opened() || !save())
        return;
    checkpoint();
    auto ch = Store::id("ch-");
    auto order = book_["chapterOrder"].toArray();
    int at = order.size();
    for (int i = 0; i < order.size(); ++i)
        if (order[i] == chapter_)
            at = i + 1;
    order.insert(at, ch);
    book_["chapterOrder"] = order;
    auto titles = book_["chapterTitles"].toObject();
    if (!title.isEmpty())
        titles[ch] = title;
    book_["chapterTitles"] = titles;
    html_[ch] = "<p></p>";
    mark(bookId() + "/chapters/" + ch + ".html", html_[ch].toUtf8());
    chapter_ = ch;
    tab_ = "manuscript";
    markBook();
    loadDocument();
}
void Controller::renameChapter(const QString& id, const QString& title) {
    if (!book_["chapterOrder"].toArray().contains(id))
        return;
    auto titles = book_["chapterTitles"].toObject();
    titles[id] = title;
    book_["chapterTitles"] = titles;
    markBook();
}
void Controller::moveChapter(const QString& id, int direction) {
    if (!save())
        return;
    auto a = book_["chapterOrder"].toArray();
    for (int i = 0; i < a.size(); ++i)
        if (a[i] == id) {
            int j = i + direction;
            if (j < 0 || j >= a.size())
                return;
            checkpoint();
            a.removeAt(i);
            a.insert(j, id);
            book_["chapterOrder"] = a;
            markBook();
            return;
        }
}
void Controller::splitChapter() {
    if (!document_ || !opened() || tab_ != "manuscript" || !save())
        return;
    checkpoint();
    auto c = cursor();
    c.clearSelection();
    c.movePosition(QTextCursor::End, QTextCursor::KeepAnchor);
    const auto next = c.selection().toHtml();
    c.removeSelectedText();
    capture();
    auto order = book_["chapterOrder"].toArray();
    int at = 0;
    while (at < order.size() && order[at] != chapter_)
        ++at;
    chapter_ = Store::id("ch-");
    order.insert(at + 1, chapter_);
    book_["chapterOrder"] = order;
    html_[chapter_] = next;
    mark(docPath(), next.toUtf8());
    markBook();
    loadDocument();
}
void Controller::mergePrevious() {
    auto a = book_["chapterOrder"].toArray();
    int at = -1;
    for (int i = 0; i < a.size(); ++i)
        if (a[i] == chapter_)
            at = i;
    if (at <= 0 || !save())
        return;
    checkpoint();
    auto prev = a[at - 1].toString();
    html_[prev] = body(html_[prev]) + "<p>***</p>" + body(html_[chapter_]);
    for (int i = 0; i < darlings_.size(); ++i) {
        auto o = darlings_[i].toObject();
        if (o["chapterId"] == chapter_) {
            o["chapterId"] = prev;
            darlings_[i] = o;
        }
    }
    for (int i = 0; i < stickies_.size(); ++i) {
        auto o = stickies_[i].toObject();
        if (o["chapterId"] == chapter_) {
            o["chapterId"] = prev;
            stickies_[i] = o;
        }
    }
    a.removeAt(at);
    book_["chapterOrder"] = a;
    chapter_ = prev;
    mark(docPath(), html_[prev].toUtf8());
    mark(bookId() + "/darlings.json", Store::encode(darlings_));
    mark(bookId() + "/stickies.json", Store::encode(stickies_));
    markBook();
    loadDocument();
}
void Controller::sceneBreak() {
    if (!document_)
        return;
    auto c = cursor();
    c.beginEditBlock();
    c.insertBlock();
    auto f = c.blockFormat();
    f.setAlignment(Qt::AlignCenter);
    c.setBlockFormat(f);
    c.insertText("***");
    c.insertBlock();
    f.setAlignment(Qt::AlignLeft);
    c.setBlockFormat(f);
    c.endEditBlock();
    emit cursorRequested(c.position(), c.position());
}
void Controller::format(const QString& style) {
    if (!document_)
        return;
    auto c = cursor();
    if (style == "bold" || style == "italic") {
        auto f = c.charFormat();
        if (style == "bold")
            f.setFontWeight(f.fontWeight() >= QFont::Bold ? QFont::Normal : QFont::Bold);
        else
            f.setFontItalic(!f.fontItalic());
        c.mergeCharFormat(f);
    } else {
        auto f = c.blockFormat();
        if (style == "poetry") {
            f.setLeftMargin(f.leftMargin() > 0 ? 0 : 32);
            auto cf = c.charFormat();
            cf.setFontItalic(true);
            c.mergeCharFormat(cf);
        } else
            f.setAlignment(style == "center"    ? Qt::AlignHCenter
                           : style == "right"   ? Qt::AlignRight
                           : style == "justify" ? Qt::AlignJustify
                                                : Qt::AlignLeft);
        c.mergeBlockFormat(f);
    }
}
void Controller::saveDarling() {
    if (!document_ || tab_ != "manuscript")
        return;
    auto c = cursor();
    if (!c.hasSelection())
        return;
    checkpoint();
    QString text = document_->toPlainText();
    QJsonObject d{{"id", Store::id("d-")},
                  {"chapterId", chapter_},
                  {"text", c.selectedText()},
                  {"html", c.selection().toHtml()},
                  {"anchorPrefix", text.left(c.selectionStart()).right(60)},
                  {"anchorSuffix", text.mid(c.selectionEnd(), 60)},
                  {"date", now()}};
    darlings_.prepend(d);
    mark(bookId() + "/darlings.json", Store::encode(darlings_));
    c.removeSelectedText();
    capture();
    markBook();
    emit notice("Passage saved to Darlings");
}
void Controller::restoreDarling(int index) {
    if (index < 0 || index >= darlings_.size() || !save())
        return;
    auto d = darlings_[index].toObject();
    auto target = d["chapterId"].toString();
    if (!book_["chapterOrder"].toArray().contains(target)) {
        emit error("The original chapter is missing. The passage remains safely in Darlings.");
        return;
    }
    checkpoint();
    selectChapter(target);
    QString text = document_->toPlainText(), pre = d["anchorPrefix"].toString(),
            post = d["anchorSuffix"].toString();
    int at = -1;
    if (!(pre + post).isEmpty()) {
        at = text.indexOf(pre + post);
        if (at >= 0)
            at += pre.size();
    }
    if (at < 0 && !pre.isEmpty()) {
        at = text.indexOf(pre);
        if (at >= 0)
            at += pre.size();
    }
    if (at < 0) {
        emit notice("Original location changed; restored at the end of its chapter.");
        at = text.size();
    }
    QTextCursor c(document_);
    c.setPosition(at);
    c.insertHtml(d["html"].toString(d["text"].toString().toHtmlEscaped()));
    darlings_.removeAt(index);
    mark(bookId() + "/darlings.json", Store::encode(darlings_));
    capture();
    markBook();
}
void Controller::addSticky(const QString& text) {
    if (!opened() || !document_)
        return;
    auto c = cursor();
    auto id = Store::id("s-");
    auto marker = "[TODO:" + id.right(8) + "]";
    c.insertText(marker);
    stickies_.append(QJsonObject{{"id", id},
                                 {"chapterId", chapter_},
                                 {"text", text},
                                 {"resolved", false},
                                 {"neonMarker", marker}});
    mark(bookId() + "/stickies.json", Store::encode(stickies_));
    capture();
    markBook();
}
void Controller::updateSticky(int index, const QString& text, bool resolved) {
    if (index < 0 || index >= stickies_.size())
        return;
    auto o = stickies_[index].toObject();
    o["text"] = text;
    o["resolved"] = resolved;
    stickies_[index] = o;
    mark(bookId() + "/stickies.json", Store::encode(stickies_));
    emit bookChanged();
}
void Controller::setChapterNote(const QString& id, const QString& text) {
    auto o = book_["chapterNotes"].toObject();
    o[id] = text;
    book_["chapterNotes"] = o;
    markBook();
}
void Controller::updateBook(const QVariantMap& changes) {
    if (!opened())
        return;
    for (auto i = changes.begin(); i != changes.end(); ++i)
        if (QStringList{"title", "subtitle", "series", "author", "wordGoal"}.contains(i.key()))
            book_[i.key()] = QJsonValue::fromVariant(i.value());
    markBook();
}
void Controller::updateSetting(const QString& key, const QVariant& v) {
    if (!QStringList{"authorName", "dailyGoal", "dayEndsAt", "pageTheme", "fontFamily", "fontSize",
                     "typewriter", "focusMode", "language", "spellLanguage", "penNames"}
             .contains(key))
        return;
    library_[key] = QJsonValue::fromVariant(v);
    markLibrary();
}
void Controller::addShelf(const QString& name) {
    if (name.trimmed().isEmpty())
        return;
    auto a = library_["shelves"].toArray();
    a.append(QJsonObject{{"id", Store::id("shelf-")}, {"name", name}, {"bookIds", QJsonArray{}}});
    library_["shelves"] = a;
    markLibrary();
}
void Controller::renameShelf(const QString& id, const QString& name) {
    auto a = library_["shelves"].toArray();
    for (int i = 0; i < a.size(); ++i) {
        auto o = a[i].toObject();
        if (o["id"] == id) {
            o["name"] = name;
            a[i] = o;
        }
    }
    library_["shelves"] = a;
    markLibrary();
}
void Controller::removeFromShelf(const QString& id) {
    auto a = library_["shelves"].toArray();
    for (int i = 0; i < a.size(); ++i) {
        auto o = a[i].toObject();
        auto ids = o["bookIds"].toArray();
        for (int j = ids.size() - 1; j >= 0; --j)
            if (ids[j] == id)
                ids.removeAt(j);
        o["bookIds"] = ids;
        a[i] = o;
    }
    library_["shelves"] = a;
    markLibrary();
}
void Controller::moveBook(const QString& id, const QString& shelf) {
    removeFromShelf(id);
    auto a = library_["shelves"].toArray();
    for (int i = 0; i < a.size(); ++i) {
        auto o = a[i].toObject();
        if (o["id"] == shelf) {
            auto ids = o["bookIds"].toArray();
            ids.append(id);
            o["bookIds"] = ids;
            a[i] = o;
        }
    }
    library_["shelves"] = a;
    markLibrary();
}
void Controller::find(const QString& text, bool backwards) {
    if (!document_ || !opened() || text.isEmpty() || !save())
        return;
    const auto order = book_["chapterOrder"].toArray();
    if (order.isEmpty())
        return;
    int start = 0;
    while (start < order.size() && order[start] != chapter_)
        ++start;
    if (start == order.size())
        start = 0;
    const auto flags = backwards ? QTextDocument::FindBackward : QTextDocument::FindFlags();
    for (int step = 0; step <= order.size(); ++step) {
        const int index = (start + (backwards ? -step : step) + order.size()) % order.size();
        const auto id = order[index].toString();
        QTextDocument candidate;
        candidate.setHtml(html_.value(id));
        int from = backwards ? candidate.characterCount() - 1 : 0;
        if (step == 0 && tab_ == "manuscript")
            from = backwards ? qMin(selectionStart_, selectionEnd_)
                             : qMax(selectionStart_, selectionEnd_);
        const auto match = candidate.find(text, from, flags);
        if (match.isNull())
            continue;
        if (chapter_ != id || tab_ != "manuscript") {
            chapter_ = id;
            tab_ = "manuscript";
            loadDocument();
        }
        selectionStart_ = match.selectionStart();
        selectionEnd_ = match.selectionEnd();
        cursor_ = match.position();
        emit cursorRequested(match.position(), match.anchor());
        return;
    }
    emit notice("No matches in this manuscript");
}
void Controller::replace(const QString& text, const QString& replacement, bool all) {
    if (!document_ || !opened() || text.isEmpty())
        return;
    if (!all) {
        auto c = cursor();
        if (c.selectedText().compare(text, Qt::CaseInsensitive) == 0)
            c.insertText(replacement);
        selectionStart_ = selectionEnd_ = cursor_ = c.position();
        find(text);
        return;
    }
    if (!save())
        return;
    checkpoint();
    int count = 0;
    for (const auto& value : book_["chapterOrder"].toArray()) {
        const auto id = value.toString();
        QTextDocument candidate;
        candidate.setHtml(html_.value(id));
        int from = 0, chapterCount = 0;
        while (true) {
            auto match = candidate.find(text, from);
            if (match.isNull())
                break;
            match.insertText(replacement);
            from = match.position();
            ++chapterCount;
        }
        if (chapterCount == 0)
            continue;
        count += chapterCount;
        html_[id] = candidate.toHtml();
        mark(bookId() + "/chapters/" + id + ".html", html_[id].toUtf8());
    }
    if (count) {
        markBook();
        loadDocument();
    } else {
        undo_.removeLast();
    }
    emit notice(QString("Replaced %1 matches in this manuscript").arg(count));
}
QStringList Controller::spellcheck(const QString& lang) {
    return document_ ? platform::misspellings(document_->toPlainText(), lang) : QStringList();
}
QStringList Controller::suggestions(const QString& word, const QString& lang) {
    return platform::suggestions(word, lang);
}
void Controller::learn(const QString& word) {
    platform::learnWord(word);
}
neon::Manuscript Controller::manuscript() {
    capture();
    Manuscript m{
        book_["title"].toString(), book_["author"].toString(), book_["subtitle"].toString(), {}};
    auto titles = book_["chapterTitles"].toObject();
    int i = 0;
    for (auto v : book_["chapterOrder"].toArray()) {
        QString h = html_.value(v.toString());
        h.remove(QRegularExpression("\\[TODO:[a-zA-Z0-9-]+\\]"));
        m.chapters.append({titles[v.toString()].toString(QString("Chapter %1").arg(++i)), h});
    }
    return m;
}
void Controller::importFile(const QUrl& url) {
    try {
        QFile f(url.toLocalFile());
        if (!f.open(QIODevice::ReadOnly) || f.size() > 64 * 1024 * 1024)
            throw Error("Cannot read manuscript or file is too large");
        auto info = QFileInfo(f);
        auto m = Formats::importData(f.readAll(), info.suffix().toLower(), info.completeBaseName());
        createBook(m.title, library_["authorName"].toString(), "");
        if (!opened())
            return;
        QJsonArray order;
        QJsonObject titles;
        for (const auto& ch : m.chapters) {
            auto id = Store::id("ch-");
            order.append(id);
            titles[id] = ch.title;
            html_[id] = ch.html;
            mark(bookId() + "/chapters/" + id + ".html", ch.html.toUtf8());
        }
        book_["chapterOrder"] = order;
        book_["chapterTitles"] = titles;
        chapter_ = order.first().toString();
        markBook();
        loadDocument();
        save();
        emit notice("Imported manuscript. Review chapter boundaries and formatting.");
    } catch (const std::exception& e) {
        fail(e);
    }
}
void Controller::importLibrary(const QUrl& url) {
    try {
        if (!save())
            return;
        Store source(url.toLocalFile());
        auto lib = source.object("library.json");
        for (const auto& id : source.bookIds()) {
            auto newId = Store::id("book-");
            auto meta = source.object(id + "/book.json");
            QMap<QString, QByteArray> files;
            QDirIterator it(source.path(id), QDir::Files | QDir::NoDotAndDotDot,
                            QDirIterator::Subdirectories);
            while (it.hasNext()) {
                it.next();
                if (it.fileInfo().isSymLink())
                    throw Error("Source contains a symlink");
                auto rel = QDir(source.path(id)).relativeFilePath(it.filePath());
                files[newId + "/" + rel] = source.read(id + "/" + rel);
            }
            meta["id"] = newId;
            meta["neonImportedFrom"] = id;
            files[newId + "/book.json"] = Store::encode(meta);
            store_->transaction(files);
            catalog_[newId] = meta;
            moveBook(newId, library_["shelves"].toArray().first().toObject()["id"].toString());
        }
        save();
        emit libraryChanged();
        emit notice("Books copied into Neon. Your original Neo library is unchanged.");
    } catch (const std::exception& e) {
        fail(e);
    }
}
void Controller::exportFile(const QUrl& url, const QString& format) {
    try {
        if (!opened() || !save())
            return;
        auto m = manuscript();
        auto path = url.toLocalFile();
        if (path.isEmpty())
            throw Error("Choose a local destination");
        if (format == "pdf") {
            if (!Formats::pdf(m, path))
                throw Error("Could not write PDF");
        } else {
            QSaveFile f(path);
            auto data = Formats::exportData(m, format);
            if (!f.open(QIODevice::WriteOnly) || f.write(data) != data.size() || !f.commit())
                throw Error("Could not save export");
        }
        emit notice("Exported " + QFileInfo(path).fileName());
    } catch (const std::exception& e) {
        fail(e);
    }
}
void Controller::backup() {
    try {
        if (!save())
            return;
        QMap<QString, QByteArray> entries;
        QDirIterator it(store_->root(), QDir::Files | QDir::NoDotAndDotDot,
                        QDirIterator::Subdirectories);
        while (it.hasNext()) {
            it.next();
            auto rel = QDir(store_->root()).relativeFilePath(it.filePath());
            if (rel.startsWith("Backups/") || rel.startsWith("Conflicts/") || rel.startsWith('.'))
                continue;
            entries[rel] = store_->read(rel);
        }
        auto name = "Backups/Neon-" + QDate::currentDate().toString(Qt::ISODate) + ".zip";
        auto data = Formats::zip(entries);
        Formats::unzip(data);
        store_->write(name, data);
        QDir backups(store_->root() + "/Backups");
        auto files = backups.entryList({"Neon-*.zip"}, QDir::Files, QDir::Name);
        while (files.size() > 14)
            backups.remove(files.takeFirst());
        emit notice("Backup verified and saved");
    } catch (const std::exception& e) {
        fail(e);
    }
}
void Controller::emailDraft() {
    try {
        if (!opened() || !save())
            return;
        auto m = manuscript();
        auto dir = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/Snapshots";
        QDir().mkpath(dir);
        auto path =
            dir + "/Neon-" + QDateTime::currentDateTimeUtc().toString("yyyyMMdd-HHmmss") + ".pdf";
        if (!Formats::pdf(m, path))
            throw Error("Cannot create PDF snapshot");
        auto hash =
            QCryptographicHash::hash(Formats::exportData(m, "txt"), QCryptographicHash::Sha256)
                .toHex();
        if (!platform::shareFile(path, m.title + " — draft snapshot",
                                 "Created " + now() +
                                     "\nSHA-256 of UTF-8 plain-text export: " + hash))
            throw Error("No email sharing service available. Snapshot saved at " + path);
    } catch (const std::exception& e) {
        fail(e);
    }
}
void Controller::setCover(const QUrl& url) {
    try {
        if (!opened())
            return;
        QImageReader reader(url.toLocalFile());
        auto size = reader.size();
        if (size.width() > 12000 || size.height() > 12000)
            throw Error("Cover image is too large");
        auto image = reader.read();
        if (image.isNull())
            throw Error("Cannot decode cover image");
        image = image.scaled(1200, 1800, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        QByteArray bytes;
        QBuffer buffer(&bytes);
        buffer.open(QIODevice::WriteOnly);
        image.save(&buffer, "PNG");
        auto file = "cover-" + Store::id("") + ".png";
        mark(bookId() + "/" + file, bytes);
        book_["coverImage"] = file;
        markBook();
        save();
    } catch (const std::exception& e) {
        fail(e);
    }
}
void Controller::rerollCover() {
    book_["coverSeed"] = QRandomGenerator::global()->bounded(1000000);
    book_.remove("coverImage");
    markBook();
}
QString Controller::coverUrl(const QString& id, const QString& file) const {
    if (file.isEmpty())
        return {};
    try {
        return QUrl::fromLocalFile(store_->path(Store::safeId(id) + "/" + Store::safeId(file)))
            .toString();
    } catch (...) {
        return {};
    }
}
bool Controller::setApiKey(const QString& key) {
    if (!platform::storeSecret("cover-api-key", key)) {
        emit error("Could not store API key in Keychain");
        return false;
    }
    return true;
}
void Controller::generateCover() {
    emit notice("AI cover generation is not enabled in this preview. Imported and seeded covers "
                "are available.");
}
QStringList Controller::fontFamilies() const {
    return QFontDatabase::families();
}
