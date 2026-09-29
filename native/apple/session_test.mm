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
        NSData* data = [NSData dataWithContentsOfURL:file];
        NSMutableDictionary* future = [[NSJSONSerialization JSONObjectWithData:data
                                                                       options:0
                                                                         error:&error] mutableCopy];
        future[@"schema"] = @3;
        NSData* unknown = [NSJSONSerialization dataWithJSONObject:future options:0 error:&error];
        check([unknown writeToURL:file atomically:YES], "write future schema fixture");
        check(![[NeonDocumentSession alloc] initWithURL:file actor:@"author" error:&error],
              "refuse future schema");
        check([[NSData dataWithContentsOfURL:file] isEqualToData:unknown], "preserve future file");
        [[NSFileManager defaultManager] removeItemAtURL:directory error:nil];
        std::cout << "Apple semantic save/reopen/conflict scenarios passed\n";
    }
}
