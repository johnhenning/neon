#pragma once
#include <cstdint>
#include <string>
#include <vector>

namespace neon::core {
// Portable DTOs: no OS paths, UI objects, Qt, Foundation, or persistence encoding.
struct Chapter {
    std::string id;
    std::string title;
    std::string text;
    // Prototype preserves the native editor payload without interpreting it.
    // A shared semantic rich-text model must replace this opaque payload before ports.
    std::vector<std::uint8_t> richText;
};
struct Book {
    std::string id;
    std::string title;
    std::string author;
    std::vector<Chapter> chapters;
};
struct Library {
    std::uint64_t revision = 0;
    std::vector<Book> books;
};
struct Result {
    bool ok;
    std::string message;
    static Result success();
    static Result failure(std::string message);
};
// Implementations own location policy, serialization and atomic commit semantics.
// Calls are serialized by the application; this API does not promise thread safety.
class LibraryRepository {
  public:
    virtual ~LibraryRepository() = default;
    virtual Result load(Library* destination) = 0;
    virtual Result commit(const Library& snapshot, std::uint64_t expectedRevision) = 0;
};
class Workspace {
  public:
    explicit Workspace(LibraryRepository& repository);
    Result open();
    const Library& library() const;
    bool dirty() const;
    Result addBook(Book book);
    Result updateChapter(const std::string& bookId, const Chapter& chapter);
    Result save();

  private:
    LibraryRepository& repository_;
    Library library_;
    bool dirty_ = false;
};
} // namespace neon::core
