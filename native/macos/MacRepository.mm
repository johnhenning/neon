#include "MacRepository.h"
#import <Foundation/Foundation.h>
#include <fcntl.h>
#include <memory>
#include <string>
#include <sys/file.h>
#include <unistd.h>
#include <utility>

namespace neon::mac {
namespace {
NSString* ns(const std::string& value) {
    return [[NSString alloc] initWithBytes:value.data()
                                    length:value.size()
                                  encoding:NSUTF8StringEncoding];
}
std::string string(NSString* value) {
    NSData* data = [value dataUsingEncoding:NSUTF8StringEncoding];
    return std::string(static_cast<const char*>(data.bytes), data.length);
}
class MacRepository final : public core::LibraryRepository {
  public:
    explicit MacRepository(const std::string& directory) {
        directory_ = ns(directory);
        path_ = [directory_ stringByAppendingPathComponent:@"library-v1.json"];
    }
    core::Result load(core::Library* destination) override {
        @autoreleasepool {
            return read(destination);
        }
    }
    core::Result commit(const core::Library& snapshot, std::uint64_t expected) override {
        @autoreleasepool {
            NSError* error = nil;
            if (![[NSFileManager defaultManager] createDirectoryAtPath:directory_
                                           withIntermediateDirectories:YES
                                                            attributes:nil
                                                                 error:&error])
                return core::Result::failure(string(error.localizedDescription));
            NSString* lockPath = [directory_ stringByAppendingPathComponent:@"writer.lock"];
            int descriptor = open(lockPath.fileSystemRepresentation, O_CREAT | O_RDWR, 0600);
            if (descriptor < 0)
                return core::Result::failure("Cannot open the library lock.");
            if (flock(descriptor, LOCK_EX | LOCK_NB) != 0) {
                close(descriptor);
                return core::Result::failure("Another Neon process is saving this library.");
            }
            core::Library current;
            auto result = read(&current);
            if (result.ok && current.revision != expected)
                result = core::Result::failure("The library changed elsewhere. Your draft is "
                                               "retained; save a recovery copy before reopening.");
            if (result.ok) {
                NSMutableArray* books = [NSMutableArray array];
                for (const auto& book : snapshot.books) {
                    NSMutableArray* chapters = [NSMutableArray array];
                    for (const auto& chapter : book.chapters) {
                        NSData* rich = [NSData dataWithBytes:chapter.richText.data()
                                                      length:chapter.richText.size()];
                        [chapters addObject:@{
                            @"id" : ns(chapter.id),
                            @"title" : ns(chapter.title),
                            @"text" : ns(chapter.text),
                            @"rtf" : [rich base64EncodedStringWithOptions:0]
                        }];
                    }
                    [books addObject:@{
                        @"id" : ns(book.id),
                        @"title" : ns(book.title),
                        @"author" : ns(book.author),
                        @"chapters" : chapters
                    }];
                }
                NSData* data = [NSJSONSerialization
                    dataWithJSONObject:@{
                        @"schema" : @1,
                        @"revision" : @(snapshot.revision),
                        @"books" : books
                    }
                               options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                 error:&error];
                if (!data || ![data writeToFile:path_ options:NSDataWritingAtomic error:&error])
                    result = core::Result::failure(string(error.localizedDescription));
            }
            flock(descriptor, LOCK_UN);
            close(descriptor);
            return result;
        }
    }

  private:
    NSString* directory_;
    NSString* path_;
    core::Result read(core::Library* destination) {
        if (![[NSFileManager defaultManager] fileExistsAtPath:path_]) {
            *destination = {};
            return core::Result::success();
        }
        NSError* error = nil;
        NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path_
                                                                                    error:&error];
        if (!attributes || [attributes fileSize] > 64 * 1024 * 1024)
            return core::Result::failure(
                "Cannot read library or library exceeds prototype size limit.");
        NSData* data = [NSData dataWithContentsOfFile:path_ options:0 error:&error];
        id json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&error] : nil;
        if (![json isKindOfClass:[NSDictionary class]] || ![json[@"schema"] isEqual:@1] ||
            ![json[@"revision"] isKindOfClass:[NSNumber class]] ||
            ![json[@"books"] isKindOfClass:[NSArray class]])
            return core::Result::failure(
                "Invalid library metadata. The original file has not been changed.");
        core::Library library;
        library.revision = [json[@"revision"] unsignedLongLongValue];
        for (id object in json[@"books"]) {
            if (![object isKindOfClass:[NSDictionary class]] ||
                ![object[@"id"] isKindOfClass:[NSString class]] ||
                ![object[@"title"] isKindOfClass:[NSString class]] ||
                ![object[@"author"] isKindOfClass:[NSString class]] ||
                ![object[@"chapters"] isKindOfClass:[NSArray class]])
                return core::Result::failure("Invalid book metadata.");
            core::Book book{
                string(object[@"id"]), string(object[@"title"]), string(object[@"author"]), {}};
            for (id item in object[@"chapters"]) {
                if (![item isKindOfClass:[NSDictionary class]] ||
                    ![item[@"id"] isKindOfClass:[NSString class]] ||
                    ![item[@"title"] isKindOfClass:[NSString class]] ||
                    ![item[@"text"] isKindOfClass:[NSString class]] ||
                    ![item[@"rtf"] isKindOfClass:[NSString class]])
                    return core::Result::failure("Invalid chapter metadata.");
                NSData* rich = [[NSData alloc] initWithBase64EncodedString:item[@"rtf"] options:0];
                if (!rich)
                    return core::Result::failure("Invalid rich text encoding.");
                core::Chapter chapter{
                    string(item[@"id"]), string(item[@"title"]), string(item[@"text"]), {}};
                if (rich.length) {
                    const auto* bytes = static_cast<const std::uint8_t*>(rich.bytes);
                    chapter.richText.assign(bytes, bytes + rich.length);
                }
                book.chapters.push_back(std::move(chapter));
            }
            library.books.push_back(std::move(book));
        }
        *destination = std::move(library);
        return core::Result::success();
    }
};
} // namespace
std::unique_ptr<core::LibraryRepository> makeRepository(const std::string& directory) {
    return std::make_unique<MacRepository>(directory);
}
} // namespace neon::mac
