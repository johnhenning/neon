#include "History.h"
#import "Controls.h"
#include "EditorialTheme.h"
#include <string>

namespace {
NSString* entryDetail(NSDictionary* entry) {
    NSDate* date = [NSDate dateWithTimeIntervalSince1970:[entry[@"createdAt"] doubleValue]];
    NSString* time = [NSDateFormatter localizedStringFromDate:date
                                                    dateStyle:NSDateFormatterMediumStyle
                                                    timeStyle:NSDateFormatterShortStyle];
    return
        [NSString stringWithFormat:@"%@ · Revision %@ · Saved locally", time, entry[@"revision"]];
}
} // namespace
#if TARGET_OS_OSX
@interface NeonHistoryHeader : NSView
@end
@implementation NeonHistoryHeader
- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
      NeonApplyGlassBackdrop(self, 0);
    }];
}
- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    [self.effectiveAppearance performAsCurrentDrawingAppearance:^{
      NeonApplyGlassBackdrop(self, 0);
    }];
}
@end
@interface NeonHistoryRow : NSTableRowView
@end
@implementation NeonHistoryRow
- (void)drawSelectionInRect:(NSRect)rect {
    [[NeonAccent() colorWithAlphaComponent:0.18] setFill];
    NSRectFill(rect);
}
- (NSBackgroundStyle)interiorBackgroundStyle {
    return NSBackgroundStyleNormal;
}
@end
@interface NeonHistoryBackground : NSView
@end
@implementation NeonHistoryBackground
- (BOOL)wantsDefaultClipping {
    return YES;
}
- (BOOL)isFlipped {
    return YES;
}
- (void)drawRect:(NSRect)rect {
    NSRectClip(self.bounds);
    [NeonPaper() setFill];
    NSRectFill(NSIntersectionRect(rect, self.bounds));
}
- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    self.needsDisplay = YES;
}
@end
#endif
@implementation NeonHistoryController {
    NSArray<NSDictionary*>* _entries;
    NSString* _selected;
    NSString* _query;
    NSInteger _scopeIndex;
    NSInteger _mode;
    NSString* _chapterID;
    NSDictionary* _snapshot;
#if TARGET_OS_OSX
    NSView* _header;
    NSButton* _searchToggle;
    NSSearchField* _search;
    NSTextField* _previewTitle;
    NSTableView* _table;
    NSTextView* _preview;
    NSTextView* _comparison;
    NSButton* _restore;
    NSTextField* _detail;
    NSTextField* _title;
    NSTextField* _working;
    NSTextField* _note;
    NSButton* _back;
    NSButton* _checkpoint;
    NSView* _scope;
    NSView* _tabs;
    NSPopUpButton* _chapter;
    NSScrollView* _list;
    NSScrollView* _document;
    NSScrollView* _currentDocument;
#else
    UIView* _header;
    UIButton* _searchToggle;
    UISearchBar* _search;
    UILabel* _previewTitle;
    UITableView* _table;
    UITextView* _preview;
    UITextView* _comparison;
    UIButton* _restore;
    UILabel* _detail;
    UILabel* _title;
    UILabel* _working;
    UILabel* _note;
    UIButton* _back;
    UIButton* _checkpoint;
    UIView* _scope;
    UIView* _tabs;
    UIButton* _chapter;
    UIView* _list;
    UIView* _document;
    UIView* _currentDocument;
#endif
}
- (void)loadView {
#if TARGET_OS_OSX
    self.view = [[NeonHistoryBackground alloc] initWithFrame:NSMakeRect(0, 0, 940, 700)];
    _header = [NeonHistoryHeader new];
    _title = [NSTextField labelWithString:@"Version history"];
    _detail = [NSTextField labelWithString:@""];
    _working = [NSTextField labelWithString:@""];
    _note = [NSTextField wrappingLabelWithString:@""];
    _previewTitle = [NSTextField wrappingLabelWithString:@"Saved version"];
    _back = [NSButton buttonWithTitle:@"← Editor" target:self action:@selector(workspaceChanged:)];
    _checkpoint = [NSButton buttonWithTitle:@"＋ Save checkpoint"
                                     target:self
                                     action:@selector(checkpoint)];
    _restore = [NSButton buttonWithTitle:@"Restore…" target:self action:@selector(restore)];
    _searchToggle = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"magnifyingglass"
                                                        accessibilityDescription:@"Search History"]
                                       target:self
                                       action:@selector(toggleSearch)];
    _search = [NSSearchField new];
    _search.placeholderString = @"Search versions";
    _search.delegate = self;
    _table = [NSTableView new];
    NSTableColumn* column = [[NSTableColumn alloc] initWithIdentifier:@"revision"];
    [_table addTableColumn:column];
    _table.headerView = nil;
    _table.rowHeight = 82;
    _table.style = NSTableViewStyleFullWidth;
    _table.delegate = self;
    _table.dataSource = self;
    _table.backgroundColor = NeonPanel();
    _list = [NSScrollView new];
    _list.documentView = _table;
    _list.hasVerticalScroller = YES;
    _preview = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 600, 400)];
    _comparison = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 300, 400)];
    _document = [NSScrollView new];
    _currentDocument = [NSScrollView new];
    _document.documentView = _preview;
    _currentDocument.documentView = _comparison;
    for (NSScrollView* scroll in @[ _document, _currentDocument ]) {
        scroll.hasVerticalScroller = YES;
        scroll.drawsBackground = NO;
    }
    for (NSTextView* text in @[ _preview, _comparison ]) {
        text.editable = NO;
        text.font = NeonSerif(18);
        text.textColor = NeonInk();
        text.backgroundColor = NeonPaper();
        text.textContainerInset = NSMakeSize(20, 20);
        text.autoresizingMask = NSViewWidthSizable;
    }
    _chapter = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    _chapter.target = self;
    _chapter.action = @selector(chapterChanged:);
#else
    self.view = [UIView new];
    self.view.backgroundColor = NeonPaper();
    self.view.tintColor = NeonAccent();
    self.title = @"Version history";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    _header = [UIView new];
    _title = [UILabel new];
    _title.text = @"Version history";
    _detail = [UILabel new];
    _working = [UILabel new];
    _note = [UILabel new];
    _note.numberOfLines = 2;
    _previewTitle = [UILabel new];
    _previewTitle.numberOfLines = 2;
    _back = [UIButton buttonWithType:UIButtonTypeSystem];
    [_back setTitle:@"← Editor" forState:UIControlStateNormal];
    [_back addTarget:self
                  action:@selector(workspaceChanged:)
        forControlEvents:UIControlEventTouchUpInside];
    _checkpoint = [UIButton buttonWithType:UIButtonTypeSystem];
    [_checkpoint setTitle:@"＋ Save checkpoint" forState:UIControlStateNormal];
    [_checkpoint addTarget:self
                    action:@selector(checkpoint)
          forControlEvents:UIControlEventTouchUpInside];
    _restore = [UIButton buttonWithType:UIButtonTypeSystem];
    [_restore setTitle:@"Restore…" forState:UIControlStateNormal];
    [_restore addTarget:self
                  action:@selector(restore)
        forControlEvents:UIControlEventTouchUpInside];
    _searchToggle = [UIButton buttonWithType:UIButtonTypeSystem];
    [_searchToggle setImage:[UIImage systemImageNamed:@"magnifyingglass"]
                   forState:UIControlStateNormal];
    [_searchToggle addTarget:self
                      action:@selector(toggleSearch)
            forControlEvents:UIControlEventTouchUpInside];
    _search = [UISearchBar new];
    _search.placeholder = @"Search versions";
    _search.searchBarStyle = UISearchBarStyleMinimal;
    _search.delegate = self;
    _table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _table.delegate = self;
    _table.dataSource = self;
    _table.rowHeight = 82;
    _table.backgroundColor = NeonPanel();
    _table.separatorColor = NeonLine();
    _list = _table;
    _preview = [UITextView new];
    _comparison = [UITextView new];
    for (UITextView* text in @[ _preview, _comparison ]) {
        text.editable = NO;
        text.font = NeonSerif(18);
        text.textColor = NeonInk();
        text.backgroundColor = NeonPaper();
        text.textContainerInset = UIEdgeInsetsMake(16, 16, 16, 16);
    }
    _document = _preview;
    _currentDocument = _comparison;
    _chapter = [UIButton buttonWithType:UIButtonTypeSystem];
    _chapter.showsMenuAsPrimaryAction = YES;
    _chapter.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
#endif
    _title.font = NeonSerif(23);
    _title.textColor = NeonInk();
    _previewTitle.font = NeonSerif(26);
    _previewTitle.textColor = NeonInk();
    _working.font = NeonUI(13);
    _working.textColor = NeonAccent();
    _detail.font = NeonUI(12);
    _detail.textColor = NeonMuted();
    _note.font = NeonUI(14);
    _note.textColor = NeonMuted();
#if TARGET_OS_OSX
    NSPopUpButton* filter = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [filter addItemsWithTitles:@[ @"All versions", @"Checkpoints", @"Automatic saves" ]];
    filter.target = self;
    filter.action = @selector(scopeChanged:);
    _scope = filter;
#else
    UIButton* filter = [UIButton buttonWithType:UIButtonTypeSystem];
    [filter setTitle:@"All versions ▾" forState:UIControlStateNormal];
    filter.showsMenuAsPrimaryAction = YES;
    NSMutableArray* filters = [NSMutableArray array];
    __weak NeonHistoryController* weakSelf = self;
    NSArray* names = @[ @"All versions", @"Checkpoints", @"Automatic saves" ];
    for (NSUInteger index = 0; index < names.count; ++index) {
        [filters
            addObject:[UIAction actionWithTitle:names[index]
                                          image:nil
                                     identifier:nil
                                        handler:^(UIAction* action) {
                                          NeonHistoryController* strongSelf = weakSelf;
                                          if (!strongSelf)
                                              return;
                                          strongSelf->_scopeIndex = index;
                                          [(UIButton*)strongSelf->_scope
                                              setTitle:[action.title stringByAppendingString:@" ▾"]
                                              forState:UIControlStateNormal];
                                          [strongSelf reloadHistory];
                                        }]];
    }
    filter.menu = [UIMenu menuWithChildren:filters];
    _scope = filter;
#endif
    _scope.accessibilityLabel = @"Filter versions";
    _search.hidden = YES;
    _searchToggle.accessibilityLabel = @"Search History";
#if TARGET_OS_OSX
    _tabs = NeonPillSelector(@[ @"Read version", @"Compare", @"Details" ], 0, self,
                             @selector(modeChanged:));
#else
    UISegmentedControl* tabs =
        [[UISegmentedControl alloc] initWithItems:@[ @"Read", @"Compare", @"Details" ]];
    [tabs setTitleTextAttributes:@{NSFontAttributeName : NeonUI(13)} forState:UIControlStateNormal];
    tabs.selectedSegmentIndex = 0;
    [tabs addTarget:self
                  action:@selector(modeChanged:)
        forControlEvents:UIControlEventValueChanged];
    _tabs = tabs;
#endif
    _back.accessibilityLabel = @"Back to editor";
    _chapter.accessibilityLabel = @"Chapter to preview";
    _table.accessibilityLabel = @"Saved versions, newest first";
    _preview.accessibilityLabel = @"Read-only revision preview";
    _comparison.accessibilityLabel = @"Working copy comparison, read only";
    NeonApplyGlassBackdrop(_header, 0);
    for (id child in @[
             _header, _title, _detail, _back, _checkpoint, _scope, _working, _searchToggle, _search,
             _list, _previewTitle, _note, _restore, _tabs, _chapter, _document, _currentDocument
         ])
        [self.view addSubview:child];
    [self reloadHistory];
}
#if TARGET_OS_OSX
- (void)viewDidLayout {
    [super viewDidLayout];
    [self layoutHistory];
}
#else
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutHistory];
}
#endif
- (void)layoutHistory {
    CGFloat width = self.view.bounds.size.width, height = self.view.bounds.size.height;
    CGFloat top = 0;
#if !TARGET_OS_OSX
    top = self.view.safeAreaInsets.top;
    height -= self.view.safeAreaInsets.bottom;
#endif
    BOOL narrow = width <= 600;
    _header.frame = CGRectMake(0, 0, width, top + (narrow ? 116 : 72));
    _back.frame = CGRectMake(12, top + 10, 84, 44);
    _title.frame = CGRectMake(108, top + 8, MAX(80, width - 302), 30);
    _detail.frame = CGRectMake(108, top + 40, MAX(80, width - 302), 20);
    _checkpoint.frame = CGRectMake(width - 182, top + 10, 170, 44);
    if (narrow) {
        _header.frame = CGRectMake(0, 0, width, top + 72);
        _back.frame = CGRectMake(8, top + 10, 64, 44);
        _title.font = NeonUI(14);
        _title.frame = CGRectMake(80, top + 14, MAX(70, width - 220), 24);
        _detail.frame = CGRectMake(80, top + 40, MAX(70, width - 220), 20);
        _checkpoint.frame = CGRectMake(width - 134, top + 10, 126, 44);
#if TARGET_OS_OSX
        _checkpoint.font = NeonUI(13);
#else
        _checkpoint.titleLabel.font = NeonUI(13);
#endif
    } else
        _title.font = NeonSerif(23);
    CGFloat start = top + 80;
    CGFloat timelineWidth = narrow ? width : 256;
    _scope.frame = CGRectMake(12, start, timelineWidth - 72, 44);
    _searchToggle.frame = CGRectMake(timelineWidth - 56, start, 44, 44);
    _working.frame = CGRectMake(20, start + 42, timelineWidth - 40, 24);
    _working.hidden = narrow;
    _search.frame = CGRectMake(12, start + (narrow ? 40 : 68), timelineWidth - 24, 36);
    CGFloat listY = start + (narrow ? 48 : 76) + (_search.hidden ? 0 : 40);
    CGFloat timelineHeight = narrow ? 112 : MAX(80, height - listY - 8);
    _list.frame = CGRectMake(0, listY, timelineWidth, timelineHeight);
    CGFloat x = narrow ? 16 : 280;
    CGFloat y = narrow ? listY + timelineHeight + 14 : start;
    CGFloat contentWidth = MAX(100, width - x - 20);
    _previewTitle.frame = CGRectMake(x, y, MAX(40, contentWidth - 92), 40);
    _restore.frame = CGRectMake(width - 106, y, 90, 40);
#if TARGET_OS_OSX
    BOOL hasNote = _note.stringValue.length > 0;
#else
    BOOL hasNote = _note.text.length > 0;
#endif
    _note.hidden = !hasNote;
    _note.frame = CGRectMake(x, y + 44, contentWidth, 40);
    CGFloat controlsY = y + (hasNote ? 90 : 48);
    _tabs.frame = CGRectMake(x, controlsY, MIN(contentWidth, 330), 44);
    _chapter.frame = CGRectMake(x, controlsY + 50, contentWidth, 32);
    CGFloat documentY = controlsY + 92, documentHeight = MAX(60, height - documentY - 12);
    BOOL compare = _mode == 1;
    _currentDocument.hidden = !compare;
    if (compare && !narrow) {
        CGFloat half = (contentWidth - 12) / 2;
        _document.frame = CGRectMake(x, documentY, half, documentHeight);
        _currentDocument.frame = CGRectMake(x + half + 12, documentY, half, documentHeight);
    } else if (compare) {
        CGFloat half = MAX(24, (documentHeight - 8) / 2);
        _document.frame = CGRectMake(x, documentY, contentWidth, half);
        _currentDocument.frame = CGRectMake(x, documentY + half + 8, contentWidth, half);
    } else
        _document.frame = CGRectMake(x, documentY, contentWidth, documentHeight);
}
- (void)toggleSearch {
    _search.hidden = !_search.hidden;
    if (_search.hidden) {
        _query = nil;
#if TARGET_OS_OSX
        _search.stringValue = @"";
        [self.view.window makeFirstResponder:_table];
#else
        _search.text = @"";
        [_search resignFirstResponder];
#endif
        [self reloadHistory];
    } else {
#if TARGET_OS_OSX
        [self.view.window makeFirstResponder:_search];
#else
        [_search becomeFirstResponder];
#endif
    }
    [self layoutHistory];
}
- (void)workspaceChanged:(id)sender {
    (void)sender;
    if (self.showEditor)
        self.showEditor();
}
- (void)scopeChanged:(id)sender {
#if TARGET_OS_OSX
    _scopeIndex = [(NSPopUpButton*)sender indexOfSelectedItem];
#else
    _scopeIndex = [sender tag];
#endif
    for (NeonButton* button in [sender superview].subviews) {
        if (![button isKindOfClass:NeonButton.class])
            continue;
        button.chosen = button == sender;
#if TARGET_OS_OSX
        button.state = button.chosen ? NSControlStateValueOn : NSControlStateValueOff;
#endif
    }
    [self reloadHistory];
}
- (void)reloadHistory {
    NSMutableArray* entries = [NSMutableArray array];
    for (NSDictionary* entry in self.session.history) {
        if ((_scopeIndex == 1 && ![entry[@"kind"] isEqual:@"checkpoint"]) ||
            (_scopeIndex == 2 && ![entry[@"kind"] isEqual:@"automatic"]))
            continue;
        NSString* searchable =
            [NSString stringWithFormat:@"%@ %@", entry[@"label"], entryDetail(entry)];
        if (!_query.length || [searchable localizedCaseInsensitiveContainsString:_query])
            [entries addObject:entry];
    }
    _entries = entries;
    [_table reloadData];
    NSUInteger index =
        [_entries indexOfObjectPassingTest:^BOOL(NSDictionary* entry, NSUInteger idx, BOOL* stop) {
          (void)idx;
          (void)stop;
          return [entry[@"id"] isEqual:_selected];
        }];
    [self selectRevisionAtIndex:index == NSNotFound ? 0 : index];
}
- (void)selectRevisionAtIndex:(NSUInteger)index {
    _selected = index < _entries.count ? _entries[index][@"id"] : nil;
    NSError* error = nil;
    _snapshot = _selected ? [self.session revisionSnapshot:_selected error:&error] : nil;
    NSDictionary* entry = _selected ? _entries[index] : nil;
    NSMutableArray* sections = [_snapshot[@"sections"] mutableCopy] ?: [NSMutableArray array];
    if (_mode == 1 && _snapshot) {
        NSMutableSet* ids = [NSMutableSet set];
        for (NSDictionary* section in sections)
            [ids addObject:section[@"id"]];
        for (NSDictionary* section in self.session.currentSnapshot[@"sections"])
            if (![ids containsObject:section[@"id"]])
                [sections addObject:section];
    }
    BOOL contains = NO;
    for (NSDictionary* section in sections)
        if ([section[@"id"] isEqual:_chapterID])
            contains = YES;
    if (!contains)
        _chapterID = sections.firstObject[@"id"];
    NSString* heading = entry[@"label"] ?: @"No saved versions";
    NSString* note = error.localizedDescription ?: entry[@"note"] ?: @"";
    NSString* working = [NSString stringWithFormat:@"● Working copy · %lu words",
                                                   (unsigned long)self.session.projectWordCount];
    NSString* subtitle = [NSString stringWithFormat:@"%@ · On this device", self.session.title];
#if TARGET_OS_OSX
    _previewTitle.stringValue = heading;
    _note.stringValue = note;
    _working.stringValue = working;
    _detail.stringValue = subtitle;
    [_chapter removeAllItems];
    for (NSDictionary* section in sections) {
        [_chapter addItemWithTitle:[NSString stringWithFormat:@"%@%@", section[@"title"],
                                                              [section[@"trashed"] boolValue]
                                                                  ? @" (Trash)"
                                                                  : @""]];
        _chapter.lastItem.representedObject = section[@"id"];
        if ([section[@"id"] isEqual:_chapterID])
            [_chapter selectItem:_chapter.lastItem];
    }
    if (_selected && _table.selectedRow != (NSInteger)index)
        [_table selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
#else
    _previewTitle.text = heading;
    _note.text = note;
    _working.text = working;
    _detail.text = subtitle;
    NSMutableArray* actions = [NSMutableArray array];
    __weak NeonHistoryController* weakSelf = self;
    for (NSDictionary* section in sections) {
        UIAction* action = [UIAction
            actionWithTitle:[NSString stringWithFormat:@"%@%@", section[@"title"],
                                                       [section[@"trashed"] boolValue] ? @" (Trash)"
                                                                                       : @""]
                      image:nil
                 identifier:nil
                    handler:^(UIAction*) {
                      NeonHistoryController* strongSelf = weakSelf;
                      if (!strongSelf)
                          return;
                      strongSelf->_chapterID = section[@"id"];
                      [strongSelf selectRevisionAtIndex:index];
                    }];
        action.state =
            [section[@"id"] isEqual:_chapterID] ? UIMenuElementStateOn : UIMenuElementStateOff;
        if ([section[@"id"] isEqual:_chapterID])
            [_chapter setTitle:[action.title stringByAppendingString:@" ▾"]
                      forState:UIControlStateNormal];
        [actions addObject:action];
    }
    _chapter.menu = [UIMenu menuWithChildren:actions];
    if (!sections.count)
        [_chapter setTitle:@"No sections" forState:UIControlStateNormal];
    if (_selected)
        [_table selectRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]
                            animated:NO
                      scrollPosition:UITableViewScrollPositionNone];
#endif
    _chapter.enabled = sections.count > 0;
    _restore.enabled = _snapshot != nil;
    [self renderPreview];
    [self layoutHistory];
}
- (void)chapterChanged:(id)sender {
#if TARGET_OS_OSX
    _chapterID = [(NSPopUpButton*)sender selectedItem].representedObject;
#else
    (void)sender;
#endif
    [self renderPreview];
}
- (void)modeChanged:(id)sender {
#if TARGET_OS_OSX
    _mode = [sender tag];
#else
    _mode = [(UISegmentedControl*)sender selectedSegmentIndex];
#endif
    for (NeonButton* button in [sender superview].subviews)
        if ([button isKindOfClass:NeonButton.class])
            button.chosen = button == sender;
    NSUInteger index =
        [_entries indexOfObjectPassingTest:^BOOL(NSDictionary* entry, NSUInteger, BOOL*) {
          return [entry[@"id"] isEqual:_selected];
        }];
    [self selectRevisionAtIndex:index];
    [self layoutHistory];
}
- (void)renderPreview {
    NSDictionary* saved = nil;
    NSDictionary* current = nil;
    for (NSDictionary* section in _snapshot[@"sections"])
        if ([section[@"id"] isEqual:_chapterID])
            saved = section;
    for (NSDictionary* section in self.session.currentSnapshot[@"sections"])
        if ([section[@"id"] isEqual:_chapterID])
            current = section;
    NSDictionary* entry = nil;
    for (NSDictionary* candidate in _entries)
        if ([candidate[@"id"] isEqual:_selected])
            entry = candidate;
    NSString* text = @"No snapshots yet. Save a checkpoint to preserve this version.";
    NSString* comparison = @"";
    if (!_selected && (_query.length || self.session.history.count))
        text = @"No versions match this filter.";
    if (_snapshot) {
        if (_mode == 2) {
            text = [NSString
                stringWithFormat:
                    @"Version details\n\nType: %@\nSaved: %@\nScope: Entire project · %lu "
                    @"sections, including Trash\nStorage: On this device\nAuthor ID: %@\n\nRestore "
                    @"behavior\nThe "
                    @"current draft is saved as a Before restore checkpoint. The selected version "
                    @"becomes a new working revision; existing versions remain in history.",
                    entry[@"kind"], entryDetail(entry),
                    (unsigned long)[_snapshot[@"sections"] count], entry[@"actor"]];
        } else {
            text = [NSString stringWithFormat:@"Saved version · Read only\n\n%@\n\n%@",
                                              saved[@"title"] ?: @"", saved[@"text"] ?: @""];
            if (_mode == 1) {
                NSString* status = [saved[@"text"] isEqual:current[@"text"]]
                                       ? @"No text changes in this section"
                                       : @"Text differs from saved version";
                comparison =
                    [NSString stringWithFormat:@"Working copy · %@\n\n%@\n\n%@", status,
                                               current[@"title"] ?: @"Section not in working copy",
                                               current[@"text"] ?: @""];
            }
        }
    }
#if TARGET_OS_OSX
    _preview.string = text;
    _comparison.string = comparison;
    _preview.textColor = NeonInk();
    _comparison.textColor = NeonInk();
#else
    _preview.text = text;
    _comparison.text = comparison;
#endif
    if (_mode == 1 && _snapshot) {
        NSArray* oldParagraphs = [saved[@"text"] componentsSeparatedByString:@"\n"] ?: @[];
        NSArray* newParagraphs = [current[@"text"] componentsSeparatedByString:@"\n"] ?: @[];
        for (NSInteger side = 0; side < 2; ++side) {
            NSArray* paragraphs = side == 0 ? oldParagraphs : newParagraphs;
            NSArray* other = side == 0 ? newParagraphs : oldParagraphs;
            NSMutableAttributedString* content = [[NSMutableAttributedString alloc]
                initWithString:[NSString
                                   stringWithFormat:@"%@ · Read only\n%@\n\n",
                                                    side == 0 ? @"Saved version" : @"Working copy",
                                                    (side == 0 ? saved[@"title"]
                                                               : current[@"title"])
                                                        ?: (side == 0
                                                                ? @"Section not in saved version"
                                                                : @"Section not in working copy")]
                    attributes:@{
                        NSFontAttributeName : NeonUI(13),
                        NSForegroundColorAttributeName : NeonMuted()
                    }];
            for (NSUInteger index = 0; index < paragraphs.count; ++index) {
                BOOL changed = index >= other.count || ![paragraphs[index] isEqual:other[index]];
                NSString* paragraph = [NSString
                    stringWithFormat:@"%@%@\n\n",
                                     changed ? (side == 0 ? @"− Previous\n" : @"+ Current\n") : @"",
                                     paragraphs[index]];
                NSMutableParagraphStyle* style = [NSMutableParagraphStyle new];
                style.lineSpacing = 6;
                NSMutableDictionary* attributes = [@{
                    NSFontAttributeName : NeonSerif(18),
                    NSForegroundColorAttributeName : NeonInk(),
                    NSParagraphStyleAttributeName : style
                } mutableCopy];
                if (changed)
                    attributes[NSBackgroundColorAttributeName] =
                        [(side == 0 ? NeonDanger() : NeonAccent()) colorWithAlphaComponent:0.10];
                [content
                    appendAttributedString:[[NSAttributedString alloc] initWithString:paragraph
                                                                           attributes:attributes]];
            }
#if TARGET_OS_OSX
            [(side == 0 ? _preview : _comparison).textStorage setAttributedString:content];
#else
            (side == 0 ? _preview : _comparison).attributedText = content;
#endif
        }
    }
}
- (void)problem:(NSError*)error {
#if TARGET_OS_OSX
    [[NSAlert alertWithError:error] runModal];
#else
    UIAlertController* alert =
        [UIAlertController alertControllerWithTitle:@"History could not be updated"
                                            message:error.localizedDescription
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
#endif
}
- (void)saveCheckpoint:(NSString*)name note:(NSString*)note {
    NSError* error = nil;
    if (![self.session createCheckpoint:name note:note error:&error]) {
        [self problem:error];
        return;
    }
    _selected = self.session.history.firstObject[@"id"];
    _scopeIndex = 0;
    _query = nil;
#if TARGET_OS_OSX
    _search.stringValue = @"";
#else
    _search.text = @"";
#endif
#if TARGET_OS_OSX
    [(NSPopUpButton*)_scope selectItemAtIndex:0];
#else
    [(UIButton*)_scope setTitle:@"All versions ▾" forState:UIControlStateNormal];
#endif
    [self reloadHistory];
}
- (void)checkpoint {
#if TARGET_OS_OSX
    NSAlert* alert = [NSAlert new];
    alert.messageText = @"Name this checkpoint";
    NSTextField* field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 320, 28)];
    field.placeholderString = @"For example: Before review";
    NSTextField* note = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 320, 56)];
    note.placeholderString = @"What changed? (optional note)";
    NSStackView* fields = [NSStackView stackViewWithViews:@[ field, note ]];
    fields.orientation = NSUserInterfaceLayoutOrientationVertical;
    fields.spacing = 12;
    fields.frame = NSMakeRect(0, 0, 320, 96);
    alert.accessoryView = fields;
    [alert addButtonWithTitle:@"Save Checkpoint"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] == NSAlertFirstButtonReturn)
        [self saveCheckpoint:field.stringValue note:note.stringValue];
#else
    UIAlertController* alert =
        [UIAlertController alertControllerWithTitle:@"Name this checkpoint"
                                            message:@"Preserves the entire project on this device."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField* field) {
      field.placeholder = @"Before review";
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField* field) {
      field.placeholder = @"What changed? (optional note)";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save Checkpoint"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction*) {
                                              [self
                                                  saveCheckpoint:alert.textFields.firstObject.text
                                                            note:alert.textFields.lastObject.text];
                                            }]];
    [self presentViewController:alert animated:YES completion:nil];
#endif
}
- (void)performRestore:(NSString*)identifier {
    NSError* error = nil;
    if (![self.session restoreRevision:identifier error:&error]) {
        [self problem:error];
        return;
    }
    if (self.didRestore)
        self.didRestore();
    [self reloadHistory];
}
- (void)restore {
    if (!_selected)
        return;
    NSString* identifier = [_selected copy];
    NSString* message = @"This restores the entire project, including its title, sections, and "
                        @"Trash. Your current draft is preserved as a Before restore checkpoint. "
                        @"The restored draft becomes a new revision.";
#if TARGET_OS_OSX
    NSAlert* alert = [NSAlert new];
    alert.messageText = @"Restore as a new version?";
    alert.informativeText = message;
    [alert addButtonWithTitle:@"Restore as New Version"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] == NSAlertFirstButtonReturn)
        [self performRestore:identifier];
#else
    UIAlertController* alert =
        [UIAlertController alertControllerWithTitle:@"Restore as a new version?"
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Restore as New Version"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction*) {
                                              [self performRestore:identifier];
                                            }]];
    [self presentViewController:alert animated:YES completion:nil];
#endif
}
#if TARGET_OS_OSX
- (NSTableRowView*)tableView:(NSTableView*)tableView rowViewForRow:(NSInteger)row {
    (void)tableView;
    (void)row;
    return [NeonHistoryRow new];
}
- (NSInteger)numberOfRowsInTableView:(NSTableView*)tableView {
    (void)tableView;
    return _entries.count;
}
- (NSView*)tableView:(NSTableView*)tableView
    viewForTableColumn:(NSTableColumn*)column
                   row:(NSInteger)row {
    (void)tableView;
    (void)column;
    NSDictionary* entry = _entries[row];
    NSTextField* field =
        [NSTextField wrappingLabelWithString:[NSString stringWithFormat:@"%@\n%@", entry[@"label"],
                                                                        entryDetail(entry)]];
    field.font = NeonUI(12);
    field.textColor = NeonInk();
    return field;
}
- (void)tableViewSelectionDidChange:(NSNotification*)notification {
    (void)notification;
    NSInteger row = _table.selectedRow;
    if (row >= 0 && row < static_cast<NSInteger>(_entries.count) &&
        ![_selected isEqual:_entries[row][@"id"]])
        [self selectRevisionAtIndex:row];
}
- (void)controlTextDidChange:(NSNotification*)notification {
    _query = [notification.object stringValue];
    [self reloadHistory];
}
#else
- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return _entries.count;
}
- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)path {
    (void)tableView;
    UITableViewCell* cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                                   reuseIdentifier:nil];
    NSDictionary* entry = _entries[path.row];
    cell.textLabel.text = entry[@"label"];
    cell.textLabel.font = NeonUI(16);
    cell.textLabel.textColor = NeonInk();
    cell.detailTextLabel.text = entryDetail(entry);
    cell.detailTextLabel.numberOfLines = 0;
    cell.detailTextLabel.textColor = NeonMuted();
    cell.backgroundColor = NeonPanel();
    UIView* selected = [UIView new];
    selected.backgroundColor = [NeonAccent() colorWithAlphaComponent:0.16];
    cell.selectedBackgroundView = selected;
    return cell;
}
- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)path {
    (void)tableView;
    [self selectRevisionAtIndex:path.row];
    [self.view endEditing:YES];
}
- (void)searchBarTextDidBeginEditing:(UISearchBar*)searchBar {
    (void)searchBar;
    _detail.hidden = YES;
}
- (void)searchBarTextDidEndEditing:(UISearchBar*)searchBar {
    (void)searchBar;
    _detail.hidden = NO;
}
- (void)searchBar:(UISearchBar*)searchBar textDidChange:(NSString*)text {
    (void)searchBar;
    _query = text;
    [self reloadHistory];
}
#endif
@end
