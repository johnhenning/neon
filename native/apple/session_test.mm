#import "DocumentSession.h"
#import "LibraryStore.h"
#include <cstdlib>
#include <iostream>

void check(bool value, const char* message) {
    if (!value) {
        std::cerr << message << '\n';
        std::exit(1);
    }
}
int main() {
    @autoreleasepool {
        NSURL* directory =
            [NSURL fileURLWithPath:[NSTemporaryDirectory()
                                       stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
        NSURL* file = [directory URLByAppendingPathComponent:@"project.json"];
        NSError* error = nil;
        NeonDocumentSession* session = [[NeonDocumentSession alloc] initWithURL:file
                                                                          actor:@"author"
                                                                          error:&error];
        check(session && session.dirty, "new local document");
        NSString* text = @"Café 👩🏽‍💻 العربية\nA second paragraph.";
        check([session replaceText:text error:&error] && [session save:&error], "save Unicode");
        NeonDocumentSession* reopened = [[NeonDocumentSession alloc] initWithURL:file
                                                                           actor:@"editor"
                                                                           error:&error];
        check(reopened && [reopened.text isEqualToString:text] && !reopened.dirty, "reopen");
        check([reopened replaceText:@"Another editor" error:&error] && [reopened save:&error],
              "second edit");
        check([session replaceText:@"Retained draft" error:&error] && ![session save:&error] &&
                  session.dirty && [session.text isEqualToString:@"Retained draft"],
              "conflict retains draft");
        NSString* first = reopened.selectedSectionID;
        check([reopened addSection:@"Second section" error:&error], "add section");
        check([reopened replaceText:@"Separate text" error:&error] && [reopened save:&error],
              "save second");
        check([reopened selectSection:first error:&error] &&
                  [reopened.text isEqualToString:@"Another editor"],
              "first section preserved");
        NeonDocumentSession* multi = [[NeonDocumentSession alloc] initWithURL:file
                                                                        actor:@"author"
                                                                        error:&error];
        check(multi.sections.count == 2 &&
                  [multi selectSection:multi.sections[1][@"id"] error:&error] &&
                  [multi.text isEqualToString:@"Separate text"],
              "all sections reopen");
        NeonLibraryStore* store = [[NeonLibraryStore alloc]
            initWithDirectory:[directory URLByAppendingPathComponent:@"library"]];
        NSURL* created = [store createProject:@"Essay / one" error:&error];
        check(created && [[store projects:&error] count] == 1, "project title never becomes path");
        check(![store createProject:@"  " error:&error] && [[store projects:&error] count] == 1,
              "empty title creates no file");
        NSString* secondID = multi.selectedSectionID;
        check([multi renameSection:secondID title:@"Renamed chapter" error:&error] &&
                  [multi moveSection:secondID direction:-1 error:&error],
              "rename and reorder");
        check([multi setSection:secondID trashed:YES error:&error] && [multi save:&error],
              "trash section");
        check(multi.sections.count == 1 && multi.trashedSections.count == 1, "trash keeps section");
        check([multi setSection:multi.selectedSectionID trashed:YES error:&error] &&
                  multi.sections.count == 0 && multi.selectedSectionID.length == 0 &&
                  [multi save:&error],
              "last section empty state");
        multi = [[NeonDocumentSession alloc] initWithURL:file actor:@"author" error:&error];
        check(multi.sections.count == 0 && multi.trashedSections.count == 2,
              "empty document reopens");
        check([multi setSection:secondID trashed:NO error:&error] &&
                  [multi.text isEqualToString:@"Separate text"],
              "restore retains text");
        check([multi duplicateSection:secondID error:&error] && multi.sections.count == 2 &&
                  [multi save:&error],
              "duplicate section");
        NSURL* copied = [store duplicateProject:created error:&error];
        check(copied && [[store projects:&error] count] == 2, "duplicate project");
        check([store setProject:created trashed:YES error:&error] &&
                  [[store projects:&error] count] == 1,
              "trash project");
        NSURL* trashed = [store trashedProjects:&error][0][@"url"];
        check([store setProject:trashed trashed:NO error:&error] &&
                  [[store projects:&error] count] == 2,
              "restore project");
        check(![store deleteTrashedProject:created error:&error], "cannot purge active project");
        NSMutableDictionary* legacy =
            [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:created]
                                            options:NSJSONReadingMutableContainers
                                              error:&error];
        legacy[@"schema"] = @1;
        [legacy removeObjectForKey:@"history"];
        [legacy removeObjectForKey:@"preset"];
        for (NSMutableDictionary* section in legacy[@"documents"][0][@"sections"]) {
            [section removeObjectForKey:@"trashed"];
            [section removeObjectForKey:@"role"];
        }
        NSData* legacyData = [NSJSONSerialization dataWithJSONObject:legacy options:0 error:&error];
        check([legacyData writeToURL:created atomically:YES], "legacy fixture");
        NeonDocumentSession* migrated = [store openURL:created error:&error];
        check([migrated renameProject:@"Migrated" error:&error] && [migrated save:&error],
              "migrate on edit");
        NSURL* backup = [created URLByAppendingPathExtension:@"schema1-backup"];
        check([[NSData dataWithContentsOfURL:backup] isEqualToData:legacyData],
              "migration backup is original bytes");
        check([store setProject:created trashed:YES error:&error],
              "move migrated project to Trash");
        trashed = [store trashedProjects:&error][0][@"url"];
        check(
            [[NSData dataWithContentsOfURL:[trashed URLByAppendingPathExtension:@"schema1-backup"]]
                isEqualToData:legacyData],
            "backup follows project");
        check(
            [store deleteTrashedProject:trashed error:&error] &&
                ![[NSFileManager defaultManager]
                    fileExistsAtPath:[trashed URLByAppendingPathExtension:@"schema1-backup"].path],
            "permanent delete includes retained backup");
        NSURL* v2URL = [store createProject:@"Schema two" error:&error];
        NSMutableDictionary* v2 =
            [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:v2URL]
                                            options:NSJSONReadingMutableContainers
                                              error:&error];
        v2[@"schema"] = @2;
        [v2 removeObjectForKey:@"preset"];
        [v2 removeObjectForKey:@"history"];
        for (NSMutableDictionary* section in v2[@"documents"][0][@"sections"])
            [section removeObjectForKey:@"role"];
        NSData* v2Bytes = [NSJSONSerialization dataWithJSONObject:v2 options:0 error:&error];
        [v2Bytes writeToURL:v2URL atomically:YES];
        NeonDocumentSession* v2Session = [store openURL:v2URL error:&error];
        check([v2Session.preset[@"id"] isEqual:@"book"] &&
                  [v2Session replaceText:@"Migrated draft" error:&error] &&
                  [v2Session save:&error] &&
                  [[NSData
                      dataWithContentsOfURL:[v2URL URLByAppendingPathExtension:@"schema2-backup"]]
                      isEqualToData:v2Bytes] &&
                  [[v2Session previewRevision:v2Session.history.firstObject[@"id"]
                                        error:&error] containsString:@"Opening"],
              "schema two migration preserves backup and original history");
        // Every preset survives reopening, renaming, duplication, and history restoration.
        for (NSDictionary* preset in NeonDocumentSession.writingPresets) {
            NSURL* presetURL = [store createProject:preset[@"title"]
                                             preset:preset[@"id"]
                                              error:&error];
            NeonDocumentSession* writing = [store openURL:presetURL error:&error];
            check(writing && [writing.preset[@"id"] isEqual:preset[@"id"]] &&
                      writing.sections.count == [preset[@"sections"] count],
                  "preset round trip");
            check(![writing initializePreset:@"book" error:&error],
                  "preset cannot replace existing content");
            NSString* sectionID = writing.selectedSectionID;
            NSString* role = writing.sections.firstObject[@"role"];
            check([writing renameSection:sectionID title:@"Custom heading" error:&error] &&
                      [writing.sections.firstObject[@"role"] isEqual:role],
                  "rename retains semantic role");
            check([writing replaceText:text error:&error] &&
                      [writing createCheckpoint:@"First complete draft" error:&error],
                  "checkpoint saves current draft");
            NSString* checkpoint = writing.history.firstObject[@"id"];
            check([[writing previewRevision:checkpoint error:&error] containsString:text],
                  "preview Unicode revision");
            check([writing replaceText:@"A newer unsaved draft" error:&error] &&
                      [writing restoreRevision:checkpoint error:&error] &&
                      [writing.text isEqual:text],
                  "restore checkpoint as new version");
            NSDictionary* beforeRestore = writing.history[1];
            check([beforeRestore[@"label"] isEqual:@"Before restore"] &&
                      [[writing previewRevision:beforeRestore[@"id"]
                                          error:&error] containsString:@"A newer unsaved draft"],
                  "restore retains unsaved current draft");
            check([writing.history[0][@"revision"] longLongValue] >
                      [writing.history[1][@"revision"] longLongValue],
                  "restore advances revision");
            NSUInteger historyCount = writing.history.count;
            check([writing save:&error] && writing.history.count == historyCount &&
                      ![writing createCheckpoint:@"   " error:&error] &&
                      ![writing restoreRevision:@"missing" error:&error],
                  "no-op and invalid history actions preserve state");
            NeonDocumentSession* stale = [store openURL:presetURL error:&error];
            check([writing replaceText:@"External save" error:&error] && [writing save:&error],
                  "new save");
            NSData* currentBytes = [NSData dataWithContentsOfURL:presetURL];
            check([stale replaceText:@"Keep me" error:&error] &&
                      ![stale restoreRevision:checkpoint error:&error] && stale.dirty &&
                      [stale.text isEqual:@"Keep me"] &&
                      [[NSData dataWithContentsOfURL:presetURL] isEqualToData:currentBytes],
                  "conflicted restore retains draft and file");
            writing = [store openURL:presetURL error:&error];
            check(writing.history.count == historyCount &&
                      [[writing previewRevision:checkpoint error:&error] containsString:text],
                  "history reopens durably");
            NSURL* duplicate = [store duplicateProject:presetURL error:&error];
            NeonDocumentSession* copy = [store openURL:duplicate error:&error];
            check([copy.preset[@"id"] isEqual:preset[@"id"]] && copy.history.count == 0 &&
                      [copy.text isEqual:writing.text],
                  "duplicate keeps preset with independent history");
            check([store setProject:presetURL trashed:YES error:&error],
                  "trash project with history");
            NSURL* trashURL = [[store.directory URLByAppendingPathComponent:@"Trash"]
                URLByAppendingPathComponent:presetURL.lastPathComponent];
            check([store openURL:trashURL error:&error].history.count == historyCount &&
                      [store setProject:trashURL trashed:NO error:&error],
                  "history follows Trash and restore");
            NSMutableDictionary* corrupt =
                [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfURL:presetURL]
                                                options:NSJSONReadingMutableContainers
                                                  error:&error];
            corrupt[@"history"][0][@"project"][@"id"] = @"foreign-project";
            NSData* badHistory = [NSJSONSerialization dataWithJSONObject:corrupt
                                                                 options:0
                                                                   error:&error];
            [badHistory writeToURL:presetURL atomically:YES];
            check(![store openURL:presetURL error:&error] &&
                      [[NSData dataWithContentsOfURL:presetURL] isEqualToData:badHistory],
                  "corrupt history refused without overwrite");
        }
        NSData* data = [NSData dataWithContentsOfURL:file];
        NSMutableDictionary* future = [[NSJSONSerialization JSONObjectWithData:data
                                                                       options:0
                                                                         error:&error] mutableCopy];
        future[@"schema"] = @4;
        NSData* unknown = [NSJSONSerialization dataWithJSONObject:future options:0 error:&error];
        check([unknown writeToURL:file atomically:YES], "write future schema fixture");
        check(![[NeonDocumentSession alloc] initWithURL:file actor:@"author" error:&error],
              "refuse future schema");
        check([[NSData dataWithContentsOfURL:file] isEqualToData:unknown], "preserve future file");
        [[NSFileManager defaultManager] removeItemAtURL:directory error:nil];
        std::cout << "Apple semantic save/reopen/conflict scenarios passed\n";
    }
}
