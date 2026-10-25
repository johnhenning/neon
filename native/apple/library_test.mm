#include "LibraryPresentation.h"
#include "LibraryStore.h"
#include "Preferences.h"
#include <cstdlib>

namespace {
void check(BOOL condition, NSString* message) {
    if (!condition) {
        NSLog(@"FAIL: %@", message);
        std::abort();
    }
}
NeonLibraryPresentation* project(NSArray* rows, NeonLibraryQuery* query, NSString* selection,
                                 NSDate* now) {
    return [[NeonLibraryPresentation alloc] initWithRecords:rows
                                                      error:nil
                                                      query:query
                                          selectedProjectID:selection
                                                        now:now];
}
} // namespace
int main() {
    @autoreleasepool {
        NSURL* directory =
            [NSURL fileURLWithPath:[NSTemporaryDirectory()
                                       stringByAppendingPathComponent:NSUUID.UUID.UUIDString]
                       isDirectory:YES];
        // An arbitrary active library root may itself be named Trash.
        NSURL* temporaryRoot = directory;
        directory = [directory URLByAppendingPathComponent:@"Trash" isDirectory:YES];
        NeonLibraryStore* store = [[NeonLibraryStore alloc] initWithDirectory:directory];
        NSError* error = nil;
        NeonLibraryQuery* query = [[NeonLibraryQuery alloc] init];
        NSDate* now = NSDate.date;
        check([store projects:&error].count == 0 && !error, @"genuine empty enumeration");
        check(project(@[], query, nil, now).records.count == 0, @"zero records");
        NSURL* first = [store createProject:@"A very long manuscript title that must retain its "
                                            @"identity across presentations and layouts"
                                      error:&error];
        check(first != nil, @"create project");
        NSData* bytes = [NSData dataWithContentsOfURL:first];
        NSArray* rows = [store projects:&error];
        NSString* identifier = rows[0][@"projectID"];
        check(![rows[0][@"trashed"] boolValue],
              @"active root named Trash does not imply trashed membership");
        check(identifier.length && project(rows, query, identifier, now).records.count == 1,
              @"one record identity");
        query.filter = NeonLibraryRecent;
        check(project(rows, query, identifier, now).records.count == 0,
              @"enumeration does not record opens");
        check([store openProjectURL:first error:&error] != nil, @"successful user open");
        rows = [store projects:&error];
        now = NSDate.date;
        check(project(rows, query, identifier, now).records.count == 1,
              @"successful open appears in Recent");
        [store setFavorite:YES projectID:identifier];
        query.filter = NeonLibraryFavorites;
        rows = [store projects:&error];
        check(project(rows, query, identifier, now).records.count == 1,
              @"favorite filters actual preference");
        [store setFavorite:NO projectID:identifier];
        check(project([store projects:&error], query, identifier, now).records.count == 0,
              @"unfavorite removes project from favorite filter");
        [store setFavorite:YES projectID:identifier];
        query.view = NeonLibraryList;
        query.sort = NeonLibraryTitle;
        [query savePreferences];
        NeonLibraryQuery* reopened = [[NeonLibraryQuery alloc] init];
        check(reopened.view == NeonLibraryList && reopened.sort == NeonLibraryTitle,
              @"preference restoration");
        check([project(rows, query, identifier, now).selectedProjectID isEqual:identifier],
              @"view retains selected identity");
        check([[NSData dataWithContentsOfURL:first] isEqual:bytes],
              @"view query favorite and open do not change manuscript bytes");
        NSURL* copy = [store duplicateProject:first error:&error];
        NeonDocumentSession* duplicate = [store openURL:copy error:&error];
        check(duplicate && ![duplicate.projectID isEqual:identifier],
              @"duplicate independent identity");
        check(![NeonPreferences()
                  boolForKey:[@"library.favorite." stringByAppendingString:duplicate.projectID]],
              @"duplicate is not favorite");
        check([store createProject:@"Third" error:&error] != nil, @"third project");
        query.filter = NeonLibraryAll;
        check(project([store projects:&error], query, identifier, now).records.count == 3,
              @"three projects");
        NSArray* all = project([store projects:&error], query, nil, now).records;
        query.filter = NeonLibraryDevice;
        check([project([store projects:&error], query, nil, now).records isEqual:all],
              @"device and all represent the same local provider");
        query.filter = NeonLibraryAll;
        NeonDocumentSession* original = [store openURL:first error:&error];
        check([original renameProject:@"Renamed" error:&error] && [original save:&error] &&
                  [original.projectID isEqual:identifier],
              @"rename retains identity");
        check([store setProject:first trashed:YES error:&error], @"trash succeeds");
        query.filter = NeonLibraryTrash;
        NSArray* trash = [store trashedProjects:&error];
        check(project(trash, query, identifier, now).records.count == 1 &&
                  [trash[0][@"favorite"] boolValue],
              @"trash retains favorite identity");
        query.filter = NeonLibraryAll;
        check(project(trash, query, identifier, now).records.count == 0, @"all excludes trash");
        check([store setProject:trash[0][@"url"] trashed:NO error:&error], @"restore succeeds");
        query.filter = NeonLibraryFavorites;
        check(project([store projects:&error], query, identifier, now).records.count == 1,
              @"restored favorite");
        NSURL* invalid = [directory URLByAppendingPathComponent:@"corrupt.json"];
        check([@"invalid" writeToURL:invalid
                          atomically:YES
                            encoding:NSUTF8StringEncoding
                               error:&error],
              @"corrupt fixture");
        rows = [store projects:&error];
        check(rows.count == 4, @"corrupt project remains visible");
        BOOL found = NO;
        for (NSDictionary* row in rows)
            if ([[row[@"url"] URLByResolvingSymlinksInPath]
                    isEqual:invalid.URLByResolvingSymlinksInPath])
                found = [row[@"error"] length] > 0;
        check(found, @"corrupt project exposes error");
        error = nil;
        check([store openProjectURL:invalid error:&error] == nil && error != nil,
              @"failed open stays failure");
        NeonLibraryStore* badStore = [[NeonLibraryStore alloc] initWithDirectory:invalid];
        error = nil;
        rows = [badStore projects:&error];
        NeonLibraryPresentation* failed =
            [[NeonLibraryPresentation alloc] initWithRecords:rows
                                                       error:error
                                                       query:query
                                           selectedProjectID:identifier
                                                         now:now];
        check(rows == nil && failed.error != nil,
              @"enumeration failure distinguishable from empty");
        check([NeonLibraryPresentation artworkForFixtureID:@"neon.fixture.quiet-sea"] != nil &&
                  [NeonLibraryPresentation artworkForFixtureID:@"The Quiet Sea"] == nil &&
                  [NeonLibraryPresentation artworkForFixtureID:identifier] == nil,
              @"only explicit fixture identities have sample art");
        NSMutableArray* many = [NSMutableArray array];
        for (NSInteger i = 99; i >= 0; --i)
            [many addObject:@{
                @"projectID" : [NSString stringWithFormat:@"%03ld", static_cast<long>(i)],
                @"title" : @"Same title",
                @"modified" : now,
                @"lastOpened" : [now dateByAddingTimeInterval:-30 * 24 * 60 * 60],
                @"favorite" : @YES,
                @"trashed" : @NO
            }];
        query.filter = NeonLibraryRecent;
        for (NSInteger sort = NeonLibraryModified; sort <= NeonLibraryLastOpened; ++sort) {
            query.sort = static_cast<NeonLibrarySort>(sort);
            NeonLibraryPresentation* result = project(many, query, @"050", now);
            check(result.records.count == 100 && [result.records[0][@"projectID"] isEqual:@"000"] &&
                      [result.selectedProjectID isEqual:@"050"],
                  @"many inclusive recent boundary deterministic ties and selection");
        }
        NSMutableDictionary* newer = [many.lastObject mutableCopy];
        newer[@"projectID"] = @"newest";
        newer[@"title"] = @"Z title";
        newer[@"lastOpened"] = now;
        [many addObject:newer];
        query.sort = NeonLibraryTitle;
        check([project(many, query, nil, now).records[0][@"projectID"] isEqual:@"newest"],
              @"Recent sorts by last successful open even with saved title preference");
        [many removeLastObject];
        check(project(many, query, @"missing", now).selectedProjectID == nil,
              @"invisible selection cleared");
        check(project(many, query, nil, [now dateByAddingTimeInterval:1]).records.count == 0,
              @"recent excludes older than boundary");
        check(project(many, query, nil, [now dateByAddingTimeInterval:-31 * 24 * 60 * 60])
                      .records.count == 0,
              @"recent excludes future open");
        [[NSFileManager defaultManager] removeItemAtURL:temporaryRoot error:nil];
        NSLog(@"Library presentation and persistence tests passed");
    }
}
