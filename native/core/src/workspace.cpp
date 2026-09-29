#include "neon/workspace.h"
#include <algorithm>
#include <set>
#include <string>
#include <utility>

namespace neon::core {
Result Result::success() {
    return {true, {}};
}
Result Result::failure(std::string message) {
    return {false, std::move(message)};
}
Workspace::Workspace(LibraryRepository& repository) : repository_(repository) {}
Result Workspace::open() {
    if (dirty_)
        return Result::failure("Save the current draft before reopening.");
    Library incoming;
    auto result = repository_.load(&incoming);
    if (!result.ok)
        return result;
    std::set<std::string> books;
    for (const auto& book : incoming.books) {
        if (book.id.empty() || !books.insert(book.id).second || book.chapters.empty())
            return Result::failure("Invalid or duplicate book metadata.");
        std::set<std::string> chapters;
        for (const auto& chapter : book.chapters)
            if (chapter.id.empty() || !chapters.insert(chapter.id).second)
                return Result::failure("Invalid or duplicate chapter metadata.");
    }
    library_ = std::move(incoming);
    return Result::success();
}
const Library& Workspace::library() const {
    return library_;
}
bool Workspace::dirty() const {
    return dirty_;
}
Result Workspace::addBook(Book book) {
    if (book.id.empty() || book.title.empty() || book.chapters.empty())
        return Result::failure("A book needs an identifier, title and chapter.");
    if (std::ranges::any_of(library_.books, [&](const auto& b) { return b.id == book.id; }))
        return Result::failure("That book already exists.");
    std::set<std::string> ids;
    for (const auto& chapter : book.chapters)
        if (chapter.id.empty() || !ids.insert(chapter.id).second)
            return Result::failure("Chapter identifiers must be unique.");
    library_.books.push_back(std::move(book));
    dirty_ = true;
    return Result::success();
}
Result Workspace::updateChapter(const std::string& bookId, const Chapter& chapter) {
    for (auto& book : library_.books) {
        if (book.id != bookId)
            continue;
        for (auto& existing : book.chapters) {
            if (existing.id != chapter.id)
                continue;
            existing = chapter;
            dirty_ = true;
            return Result::success();
        }
    }
    return Result::failure("The chapter is no longer in this library.");
}
Result Workspace::save() {
    if (!dirty_)
        return Result::success();
    auto snapshot = library_;
    ++snapshot.revision;
    auto result = repository_.commit(snapshot, library_.revision);
    if (result.ok) {
        library_ = std::move(snapshot);
        dirty_ = false;
    }
    return result;
}
} // namespace neon::core
