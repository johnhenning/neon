#include "neon/workspace.h"
#include <cstdlib>
#include <iostream>

using neon::core::Book;
using neon::core::Library;
using neon::core::Result;
class MemoryRepository final : public neon::core::LibraryRepository {
  public:
    Library disk;
    bool reject = false;
    Result load(Library* value) override {
        *value = disk;
        return Result::success();
    }
    Result commit(const Library& value, std::uint64_t expected) override {
        if (reject || disk.revision != expected)
            return Result::failure("Injected failure or conflict");
        disk = value;
        return Result::success();
    }
};
void check(bool condition, const char* message) {
    if (!condition) {
        std::cerr << message << '\n';
        std::exit(1);
    }
}
int main() {
    MemoryRepository repository;
    neon::core::Workspace workspace(repository);
    check(workspace.open().ok, "open empty");
    Book book{"book", "A story", "Writer", {{"chapter", "One", "Original", {1, 2, 3}}}};
    check(workspace.addBook(book).ok, "create");
    check(!workspace.addBook(book).ok, "reject duplicate");
    repository.reject = true;
    check(!workspace.save().ok && workspace.dirty(), "save failure retains edits");
    check(!workspace.open().ok, "reopen must not discard unsaved edits");
    repository.reject = false;
    check(workspace.save().ok && !workspace.dirty(), "save succeeds");
    neon::core::Workspace reopened(repository);
    check(reopened.open().ok, "reopen saved");
    check(reopened.library().books[0].chapters[0].richText.size() == 3, "preserve rich payload");
    auto chapter = book.chapters[0];
    chapter.text = "Revised";
    check(workspace.updateChapter("book", chapter).ok, "update");
    ++repository.disk.revision;
    check(!workspace.save().ok && workspace.dirty(), "external revision conflict retains edits");
    check(workspace.library().books[0].chapters[0].text == "Revised", "draft retained");
    std::cout << "Portable workspace scenarios passed\n";
}
