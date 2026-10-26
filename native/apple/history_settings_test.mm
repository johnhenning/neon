#import "History.h"
#import "Preferences.h"
#import "Settings.h"
#include <cstdlib>
#include <iostream>
#include <string>

namespace {
void check(bool condition, const char* message) {
    if (!condition) {
        std::cerr << message << '\n';
        std::exit(1);
    }
}
NSView* find(NSView* root, BOOL (^predicate)(NSView*)) {
    if (predicate(root))
        return root;
    for (NSView* child in root.subviews)
        if (NSView* match = find(child, predicate))
            return match;
    return nil;
}
void chooseSection(NSPopUpButton* chapter, NSString* identifier) {
    for (NSMenuItem* item in chapter.itemArray)
        if ([item.representedObject isEqual:identifier]) {
            [chapter selectItem:item];
            [NSApp sendAction:chapter.action to:chapter.target from:chapter];
            return;
        }
    check(false, "chapter identifier must be available");
}
void settle(NSView* view) {
    view.needsLayout = YES;
    [view layoutSubtreeIfNeeded];
    [view layoutSubtreeIfNeeded];
}
} // namespace

int main() {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSURL* directory =
            [NSURL fileURLWithPath:[NSTemporaryDirectory()
                                       stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
        NSURL* url = [directory URLByAppendingPathComponent:@"project.json"];
        NSError* error = nil;
        NeonDocumentSession* session = [[NeonDocumentSession alloc] initWithURL:url
                                                                          actor:@"review"
                                                                          error:&error];
        check(session != nil, "create isolated manuscript");
        check([session replaceText:@"Saved paragraph." error:&error] &&
                  [session createCheckpoint:@"First" note:@"Saved note" error:&error],
              "save checkpoint with note");
        NSString* original = session.selectedSectionID;
        check([session addSection:@"New working section" error:&error], "add working section");
        NSString* added = session.selectedSectionID;
        check([session replaceText:@"New paragraph." error:&error], "edit working section");
        NeonHistoryController* history = [NeonHistoryController new];
        history.session = session;
        NSWindow* window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1200, 860)
                                                       styleMask:NSWindowStyleMaskTitled
                                                         backing:NSBackingStoreBuffered
                                                           defer:NO];
        window.contentViewController = history;
        settle(history.view);
        NSButton* searchButton = (id)find(history.view, ^BOOL(NSView* view) {
          return [view isKindOfClass:NSButton.class] &&
                 [view.accessibilityLabel isEqual:@"Search History"];
        });
        NSSearchField* search = (id)find(history.view, ^BOOL(NSView* view) {
          return [view isKindOfClass:NSSearchField.class];
        });
        check(searchButton && search.hidden, "History search starts collapsed");
        [searchButton performClick:nil];
        check(!search.hidden, "History search action reveals field");
        [searchButton performClick:nil];
        check(search.hidden, "History search action closes field");
        NSButton* compare = (id)find(history.view, ^BOOL(NSView* view) {
          return
              [view isKindOfClass:NSButton.class] && [((NSButton*)view).title isEqual:@"Compare"];
        });
        check(compare != nil, "Compare action exists");
        [compare performClick:nil];
        NSPopUpButton* chapter = (id)find(history.view, ^BOOL(NSView* view) {
          return [view.accessibilityLabel isEqual:@"Chapter to preview"];
        });
        check(chapter.numberOfItems == (NSInteger)[session.currentSnapshot[@"sections"] count],
              "comparison includes working-only chapters");
        chooseSection(chapter, added);
        NSTextView* saved = (id)find(history.view, ^BOOL(NSView* view) {
          return [view.accessibilityLabel isEqual:@"Read-only revision preview"];
        });
        NSTextView* current = (id)find(history.view, ^BOOL(NSView* view) {
          return [view.accessibilityLabel isEqual:@"Working copy comparison, read only"];
        });
        check([saved.string containsString:@"Section not in saved version"],
              "explicit missing saved chapter");
        check([current.string containsString:@"New paragraph."], "working chapter text");
        check(!saved.editable && !current.editable && [session.selectedSectionID isEqual:added],
              "comparison preserves read-only state and editor selection");
        check([session setSection:original trashed:YES error:&error], "trash working chapter");
        chooseSection(chapter, original);
        check([saved.string containsString:@"Saved paragraph."],
              "working Trash does not erase saved preview");
        for (NSNumber* height in @[ @568, @768 ]) {
            [window setContentSize:NSMakeSize(335, height.doubleValue)];
            settle(history.view);
            for (NSView* child in history.view.subviews)
                if (!child.hidden)
                    check(NSMaxX(child.frame) <= 335.5 && NSMaxY(child.frame) <= height.doubleValue,
                          "335-point History controls fit both compact heights");
        }
        // Exercise the actual overlay controls instead of invoking persistence directly.
        NSButton* checkpoint = (id)find(history.view, ^BOOL(NSView* view) {
          return [view isKindOfClass:NSButton.class] &&
                 [((NSButton*)view).title isEqual:@"＋ Save checkpoint"];
        });
        NSUInteger beforeDialog = session.history.count;
        [checkpoint performClick:nil];
        NSTextField* name = (id)find(history.view, ^BOOL(NSView* view) {
          return [view.accessibilityLabel isEqual:@"Checkpoint name"];
        });
        NSTextView* note = (id)find(history.view, ^BOOL(NSView* view) {
          return [view.accessibilityLabel isEqual:@"Note"];
        });
        NSButton* submit = (id)find(history.view, ^BOOL(NSView* view) {
          return [view isKindOfClass:NSButton.class] &&
                 [((NSButton*)view).title isEqual:@"Save checkpoint"];
        });
        check(name && note && submit, "checkpoint overlay exposes editable name and note");
        [submit performClick:nil];
        check(session.history.count == beforeDialog && name.window,
              "empty checkpoint title leaves dialog open without saving");
        name.stringValue = @"Overlay checkpoint";
        note.string = @"Multiline note\nSecond line";
        [submit performClick:nil];
        check(session.history.count == beforeDialog + 1 && !name.window,
              "checkpoint overlay saves once and dismisses");
        BOOL savedNote = NO;
        for (NSDictionary* entry in session.history)
            if ([entry[@"note"] isEqual:@"Multiline note\nSecond line"])
                savedNote = YES;
        check(savedNote, "checkpoint overlay persists multiline note");
        [checkpoint performClick:nil];
        NSButton* cancel = (id)find(history.view, ^BOOL(NSView* view) {
          return [view isKindOfClass:NSButton.class] && [((NSButton*)view).title isEqual:@"Cancel"];
        });
        [cancel performClick:nil];
        check(session.history.count == beforeDialog + 1 && !cancel.window,
              "cancel checkpoint leaves history unchanged");
        NeonSettingsController* settings = [NeonSettingsController new];
        __block BOOL browsed = NO;
        settings.showHistory = ^{
          browsed = YES;
        };
        window.contentViewController = settings;
        settle(settings.view);
        check(settings.visibleSettingCount == 14, "settings catalog includes real preferences");
        NSButton* browse = (id)find(settings.view, ^BOOL(NSView* view) {
          return [view isKindOfClass:NSButton.class] &&
                 [((NSButton*)view).title isEqual:@"Browse version history →"];
        });
        check(browse != nil, "History action is visible when connected");
        [browse performClick:nil];
        check(browsed, "History action invokes coordinator");
        for (NSNumber* width in @[ @1200, @335 ]) {
            [window setContentSize:NSMakeSize(width.doubleValue, 860)];
            settle(settings.view);
            NSScrollView* scroll = (id)find(settings.view, ^BOOL(NSView* view) {
              return [view isKindOfClass:NSScrollView.class];
            });
            NSView* stack = scroll.documentView;
            for (NSView* child in stack.subviews) {
                if (![child.identifier isEqual:@"settingsRow"])
                    continue;
                NSView* row = child;
                check(row.bounds.size.width > 0, "settings row laid out");
                for (NSView* part in row.subviews)
                    if (!part.hidden)
                        check(NSMaxX(part.frame) <= row.bounds.size.width + 1,
                              "settings controls fit full-width and compact rows");
            }
        }
        [settings filterSettings:@"PARAGRAPH"];
        check(settings.visibleSettingCount == 1, "case-insensitive preference search");
        [settings filterSettings:@"unmatched preference"];
        check(settings.visibleSettingCount == 0, "empty settings search");
        check([NSFileManager.defaultManager removeItemAtURL:directory error:&error],
              "remove test manuscript");
        std::cout << "history and settings behavior passed\n";
    }
}
