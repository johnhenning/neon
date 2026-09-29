#include "DocumentSession.h"
#include "neon/document.h"
#include <string>
#include <utility>

namespace {
NSString* ns(const std::string& value) {
    return [[NSString alloc] initWithBytes:value.data()
                                    length:value.size()
                                  encoding:NSUTF8StringEncoding];
}
std::string utf8(NSString* value) {
    NSData* bytes = [value dataUsingEncoding:NSUTF8StringEncoding];
    return std::string(static_cast<const char*>(bytes.bytes), bytes.length);
}
BOOL fail(NSError** error, NSString* message) {
    if (error)
        *error = [NSError errorWithDomain:@"NeonDocument"
                                     code:1
                                 userInfo:@{NSLocalizedDescriptionKey : message}];
    return NO;
}
bool keys(id object, NSArray<NSString*>* expected) {
    return [object isKindOfClass:NSDictionary.class] &&
           [[NSSet setWithArray:[object allKeys]] isEqualToSet:[NSSet setWithArray:expected]];
}
bool strings(NSDictionary* object, NSArray<NSString*>* fields) {
    for (NSString* field in fields)
        if (![object[field] isKindOfClass:NSString.class])
            return false;
    return true;
}
// This first editing slice deliberately refuses richer or unknown files instead
// of opening a partial projection and silently discarding their contents.
bool decode(id root, neon::core::Project* project) {
    if (!keys(root, @[ @"schema", @"revision", @"id", @"title", @"documents" ]) ||
        !strings(root, @[ @"id", @"title" ]) ||
        (![root[@"schema"] isEqual:@1] && ![root[@"schema"] isEqual:@2]) ||
        ![root[@"revision"] isKindOfClass:NSString.class])
        return false;
    project->schemaVersion = [root[@"schema"] unsignedIntValue];
    NSString* revision = root[@"revision"];
    if (revision.length == 0 ||
        [revision rangeOfCharacterFromSet:[NSCharacterSet
                                              characterSetWithCharactersInString:@"0123456789"]
                                              .invertedSet]
                .location != NSNotFound)
        return false;
    try {
        project->revision = std::stoull(utf8(revision));
    } catch (...) {
        return false;
    }
    project->id = utf8(root[@"id"]);
    project->title = utf8(root[@"title"]);
    id docs = root[@"documents"];
    if (![docs isKindOfClass:NSArray.class] || [docs count] != 1)
        return false;
    id doc = docs[0];
    if (!keys(doc, @[ @"id", @"title", @"sections" ]) || !strings(doc, @[ @"id", @"title" ]))
        return false;
    id sections = doc[@"sections"];
    if (![sections isKindOfClass:NSArray.class])
        return false;
    neon::core::Document document{utf8(doc[@"id"]), utf8(doc[@"title"]), {}};
    for (id section in sections) {
        if (!keys(section, project->schemaVersion == 1
                               ? @[ @"id", @"title", @"blocks" ]
                               : @[ @"id", @"title", @"blocks", @"trashed" ]) ||
            !strings(section, @[ @"id", @"title" ]))
            return false;
        id blocks = section[@"blocks"];
        if (![blocks isKindOfClass:NSArray.class] || [blocks count] != 1)
            return false;
        id block = blocks[0];
        if (!keys(block, @[ @"id", @"text", @"createdBy", @"lastEditedBy" ]) ||
            !strings(block, @[ @"id", @"text", @"createdBy", @"lastEditedBy" ]))
            return false;
        if (project->schemaVersion == 2 && ![section[@"trashed"] isKindOfClass:NSNumber.class])
            return false;
        document.sections.push_back({utf8(section[@"id"]),
                                     utf8(section[@"title"]),
                                     {{utf8(block[@"id"]), utf8(block[@"text"]),
                                       utf8(block[@"createdBy"]), utf8(block[@"lastEditedBy"])}}});
        document.sections.back().trashed = [section[@"trashed"] boolValue];
    }
    project->documents = {document};
    return neon::core::validate(*project).ok;
}
NSData* encode(const neon::core::Project& project, NSError** error) {
    const auto& document = project.documents[0];
    NSMutableArray* sections = [NSMutableArray array];
    for (const auto& section : document.sections) {
        const auto& block = section.blocks[0];
        [sections addObject:@{
            @"id" : ns(section.id),
            @"title" : ns(section.title),
            @"trashed" : @(section.trashed),
            @"blocks" : @[ @{
                @"id" : ns(block.id),
                @"text" : ns(block.text),
                @"createdBy" : ns(block.createdBy),
                @"lastEditedBy" : ns(block.lastEditedBy)
            } ]
        }];
    }
    return [NSJSONSerialization dataWithJSONObject:@{
        @"schema" : @2,
        @"revision" : ns(std::to_string(project.revision)),
        @"id" : ns(project.id),
        @"title" : ns(project.title),
        @"documents" :
            @[ @{@"id" : ns(document.id), @"title" : ns(document.title), @"sections" : sections} ]
    }
                                           options:NSJSONWritingPrettyPrinted |
                                                   NSJSONWritingSortedKeys
                                             error:error];
}
} // namespace

@implementation NeonDocumentSession {
    neon::core::Project _project;
    NSURL* _url;
    NSString* _actor;
    NSData* _lastSaved;
    BOOL _dirty;
    BOOL _needsMigrationBackup;
    std::size_t _selected;
}
- (instancetype)initWithURL:(NSURL*)url actor:(NSString*)actor error:(NSError**)error {
    self = [super init];
    if (!self)
        return nil;
    if (!url.isFileURL || actor.length == 0) {
        fail(error, @"A local file and actor are required.");
        return nil;
    }
    _url = url;
    _actor = [actor copy];
    if ([[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
        _lastSaved = [NSData dataWithContentsOfURL:url options:0 error:error];
        if (!_lastSaved)
            return nil;
        id root = [NSJSONSerialization JSONObjectWithData:_lastSaved options:0 error:error];
        if (!root)
            return nil;
        if (!decode(root, &_project)) {
            fail(error, @"Unsupported or invalid document. The original file was not changed.");
            return nil;
        }
    } else {
        auto id = [] { return utf8(NSUUID.UUID.UUIDString); };
        _project = {1,
                    0,
                    id(),
                    "My writing",
                    {{id(), "Draft", {{id(), "Opening", {{id(), "", utf8(actor), utf8(actor)}}}}}}};
        _dirty = YES;
    }
    _needsMigrationBackup = _lastSaved && _project.schemaVersion == 1;
    _project.schemaVersion = 2;
    _selected = 0;
    while (_selected < _project.documents[0].sections.size() &&
           _project.documents[0].sections[_selected].trashed)
        ++_selected;
    return self;
}
- (NSString*)text {
    return _selected < _project.documents[0].sections.size()
               ? ns(_project.documents[0].sections[_selected].blocks[0].text)
               : @"";
}
- (NSString*)title {
    return ns(_project.title);
}
- (NSString*)sectionTitle {
    return _selected < _project.documents[0].sections.size()
               ? ns(_project.documents[0].sections[_selected].title)
               : @"No sections";
}
- (NSString*)selectedSectionID {
    return _selected < _project.documents[0].sections.size()
               ? ns(_project.documents[0].sections[_selected].id)
               : @"";
}
- (NSArray<NSDictionary<NSString*, NSString*>*>*)sections {
    NSMutableArray* result = [NSMutableArray array];
    for (const auto& section : _project.documents[0].sections)
        if (!section.trashed)
            [result addObject:@{@"id" : ns(section.id), @"title" : ns(section.title)}];
    return result;
}
- (BOOL)selectSection:(NSString*)identifier error:(NSError**)error {
    for (std::size_t i = 0; i < _project.documents[0].sections.size(); ++i)
        if (!_project.documents[0].sections[i].trashed &&
            _project.documents[0].sections[i].id == utf8(identifier)) {
            _selected = i;
            return YES;
        }
    return fail(error, @"This section is no longer available.");
}
- (BOOL)renameProject:(NSString*)title error:(NSError**)error {
    title = [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    auto result = neon::core::renameProject(&_project, utf8(title));
    if (!result.ok)
        return fail(error, ns(result.message));
    _dirty = YES;
    return YES;
}
- (BOOL)addSection:(NSString*)title error:(NSError**)error {
    title = [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    auto identifier = utf8(NSUUID.UUID.UUIDString);
    auto result =
        neon::core::addSection(&_project, _project.documents[0].id,
                               {identifier,
                                utf8(title),
                                {{utf8(NSUUID.UUID.UUIDString), "", utf8(_actor), utf8(_actor)}}});
    if (!result.ok)
        return fail(error, ns(result.message));
    _selected = _project.documents[0].sections.size() - 1;
    _dirty = YES;
    return YES;
}
- (NSArray<NSDictionary<NSString*, NSString*>*>*)trashedSections {
    NSMutableArray* result = [NSMutableArray array];
    for (const auto& section : _project.documents[0].sections)
        if (section.trashed)
            [result addObject:@{@"id" : ns(section.id), @"title" : ns(section.title)}];
    return result;
}
- (BOOL)renameSection:(NSString*)identifier title:(NSString*)title error:(NSError**)error {
    title = [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    auto result = neon::core::renameSection(&_project, utf8(identifier), utf8(title));
    if (!result.ok)
        return fail(error, ns(result.message));
    _dirty = YES;
    return YES;
}
- (BOOL)setSection:(NSString*)identifier trashed:(BOOL)trashed error:(NSError**)error {
    NSString* previous = self.selectedSectionID;
    auto result = neon::core::trashSection(&_project, utf8(identifier), trashed);
    if (!result.ok)
        return fail(error, ns(result.message));
    _dirty = YES;
    if (![self selectSection:previous error:nil]) {
        _selected = 0;
        while (_selected < _project.documents[0].sections.size() &&
               _project.documents[0].sections[_selected].trashed)
            ++_selected;
    }
    return YES;
}
- (BOOL)moveSection:(NSString*)identifier direction:(NSInteger)direction error:(NSError**)error {
    NSString* previous = self.selectedSectionID;
    auto result = neon::core::moveSection(&_project, utf8(identifier), static_cast<int>(direction));
    if (!result.ok)
        return fail(error, ns(result.message));
    [self selectSection:previous error:nil];
    _dirty = YES;
    return YES;
}
- (BOOL)duplicateSection:(NSString*)identifier error:(NSError**)error {
    for (const auto& section : _project.documents[0].sections) {
        if (section.id != utf8(identifier))
            continue;
        auto copy = section;
        copy.id = utf8(NSUUID.UUID.UUIDString);
        copy.title += " copy";
        copy.trashed = false;
        for (auto& block : copy.blocks)
            block.id = utf8(NSUUID.UUID.UUIDString);
        auto result = neon::core::addSection(&_project, _project.documents[0].id, std::move(copy));
        if (!result.ok)
            return fail(error, ns(result.message));
        _dirty = YES;
        return YES;
    }
    return fail(error, @"This section no longer exists.");
}
- (BOOL)duplicateToURL:(NSURL*)url error:(NSError**)error {
    if ([[NSFileManager defaultManager] fileExistsAtPath:url.path])
        return fail(error, @"The destination already exists.");
    auto copy = _project;
    copy.id = utf8(NSUUID.UUID.UUIDString);
    copy.title += " copy";
    copy.revision = 0;
    for (auto& document : copy.documents) {
        document.id = utf8(NSUUID.UUID.UUIDString);
        for (auto& section : document.sections) {
            section.id = utf8(NSUUID.UUID.UUIDString);
            for (auto& block : section.blocks)
                block.id = utf8(NSUUID.UUID.UUIDString);
        }
    }
    NSData* data = encode(copy, error);
    return data && [data writeToURL:url options:NSDataWritingAtomic error:error];
}
- (BOOL)dirty {
    return _dirty;
}
- (BOOL)replaceText:(NSString*)text error:(NSError**)error {
    if (self.selectedSectionID.length == 0)
        return text.length == 0 ? YES : fail(error, @"Create a section before writing.");
    if (![text canBeConvertedToEncoding:NSUTF8StringEncoding])
        return fail(error, @"The input cannot be represented as Unicode text.");
    const auto previous = _project.revision;
    auto result =
        neon::core::replaceText(&_project, _project.documents[0].sections[_selected].blocks[0].id,
                                utf8(text), utf8(_actor));
    if (!result.ok)
        return fail(error, ns(result.message));
    _dirty |= previous != _project.revision;
    return YES;
}
- (BOOL)save:(NSError**)error {
    if (!_dirty)
        return YES;
    // Detect external changes in this single-process prototype. File coordination
    // and journaled multi-file transactions are a separate release prerequisite.
    if ([[NSFileManager defaultManager] fileExistsAtPath:_url.path]) {
        NSData* current = [NSData dataWithContentsOfURL:_url options:0 error:error];
        if (!current)
            return NO;
        if (!_lastSaved || ![current isEqualToData:_lastSaved])
            return fail(error, @"File changed elsewhere. Your unsaved draft is retained.");
    } else if (_lastSaved) {
        return fail(error, @"Saved file is missing. Your unsaved draft is retained.");
    }
    if (![[NSFileManager defaultManager] createDirectoryAtURL:_url.URLByDeletingLastPathComponent
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:error])
        return NO;
    if (_needsMigrationBackup) {
        NSURL* backup = [_url URLByAppendingPathExtension:@"schema1-backup"];
        if (![[NSFileManager defaultManager] fileExistsAtPath:backup.path] &&
            ![_lastSaved writeToURL:backup options:NSDataWritingAtomic error:error])
            return NO;
    }
    NSData* data = encode(_project, error);
    if (!data || ![data writeToURL:_url options:NSDataWritingAtomic error:error])
        return NO;
    _lastSaved = data;
    _needsMigrationBackup = NO;
    _dirty = NO;
    return YES;
}
@end
