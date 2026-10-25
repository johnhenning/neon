#include "LibraryController.h"
#import "Preferences.h"
#include <cstdio>
#include <cstdlib>
#include <string>
static void require(BOOL value, const char* message) {
    if (!value) {
        fprintf(stderr, "%s\n", message);
        exit(1);
    }
}
static NSArray<NSView*>* descendants(NSView* view) {
    NSMutableArray* all = [NSMutableArray arrayWithObject:view];
    for (NSView* child in view.subviews)
        [all addObjectsFromArray:descendants(child)];
    return all;
}
static NSButton* findButton(NSView* root, NSString* title) {
    for (NSView* view in descendants(root))
        if ([view isKindOfClass:NSButton.class] && [((NSButton*)view).title isEqual:title])
            return (NSButton*)view;
    return nil;
}
static BOOL contains(NSView* root, NSString* string) {
    for (NSView* view in descendants(root))
        if ([view isKindOfClass:NSTextField.class] &&
            [((NSTextField*)view).stringValue containsString:string])
            return YES;
    return NO;
}
int main(int argc, const char* argv[]) {
    (void)argc;
    (void)argv;
    @autoreleasepool {
        [NSApplication sharedApplication];
        NeonLibraryController* c = [NeonLibraryController new];
        [c updateWithRecords:@[] error:nil];
        require(contains(c.view, @"Begin anywhere."), "true empty welcome missing");
        require(contains(c.view, @"0 projects"), "empty count incorrect");
        require(!findButton(c.view, @"Import a document").enabled, "unavailable import enabled");
        require(c.sidebarView.frame.size.width == 248, "library sidebar measure incorrect");
        NSDictionary* record = @{
            @"projectID" : @"stable-a",
            @"title" : @"A long title that must remain accessible without modifying the document",
            @"modified" : [NSDate date],
            @"lastOpened" : [NSDate date],
            @"preset" : @"book",
            @"favorite" : @YES
        };
        c.selectedProjectID = @"stable-a";
        [c updateWithRecords:@[ record ] error:nil];
        __block NSString* action;
        __block NSString* identity;
        c.onAction = ^(NSString* name, NSDictionary* row) {
          action = name;
          identity = row[@"projectID"];
        };
        [findButton(c.view, record[@"title"]) performClick:nil];
        require([action isEqual:@"open"] && [identity isEqual:@"stable-a"],
                "open must carry stable record");
        [c setLibraryView:NeonLibraryList];
        require([c.selectedProjectID isEqual:@"stable-a"], "list switch lost selection");
        NSUInteger covers = 0;
        for (NSView* v in descendants(c.view))
            if ([NSStringFromClass(v.class) isEqual:@"NeonLibraryCover"]) {
                covers++;
                require(v.frame.size.width == 70 && v.frame.size.height == 104,
                        "list cover geometry incorrect");
                require([v valueForKey:@"image"] == nil,
                        "ordinary document acquired fixture image");
            }
        require(covers == 1, "list cover missing");
        [c selectFilter:NeonLibraryFavorites];
        require(c.presentation.records.count == 1, "favorite filter incorrect");
        [c selectFilter:NeonLibraryRecent];
        require(c.presentation.records.count == 1, "recent filter incorrect");
        [c selectFilter:NeonLibraryTrash];
        require(!contains(c.view, @"Begin anywhere."), "empty filter wrongly shown as welcome");
        NSError* error =
            [NSError errorWithDomain:@"test"
                                code:1
                            userInfo:@{NSLocalizedDescriptionKey : @"Enumeration failed"}];
        [c updateWithRecords:nil error:error];
        require(contains(c.view, @"Unable to load projects") &&
                    !contains(c.view, @"Begin anywhere."),
                "failure misrepresented as empty");
        [c selectFilter:NeonLibraryAll];
        [c updateWithRecords:@[ record ] error:nil];
        [c setLibraryView:NeonLibraryGrid];
        for (NSView* v in descendants(c.view))
            if ([NSStringFromClass(v.class) isEqual:@"NeonLibraryCover"])
                require(fabs(v.frame.size.height / v.frame.size.width - 1.46) < .001,
                        "grid cover ratio incorrect");
        puts("Library controller state, action, geometry and fallback checks passed");
    }
}
