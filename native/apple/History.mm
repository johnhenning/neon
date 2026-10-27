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
    return time;
}
NSString* entryKind(NSDictionary* entry) {
    return [entry[@"kind"] isEqual:@"checkpoint"]  ? @"Checkpoint"
           : [entry[@"kind"] isEqual:@"automatic"] ? @"Automatic save"
                                                   : @"Restored version";
}
NSAttributedString* rowText(NSDictionary* entry, BOOL narrow) {
    NSMutableAttributedString* text = [[NSMutableAttributedString alloc]
        initWithString:[entry[@"label"] stringByAppendingString:@"\n"]
            attributes:@{
                NSFontAttributeName : NeonUISemibold(14),
                NSForegroundColorAttributeName : NeonInk()
            }];
    NSString* metadata = [NSString
        stringWithFormat:@"%@%@%@", entryDetail(entry), narrow ? @" · " : @"\n", entryKind(entry)];
    [text appendAttributedString:[[NSAttributedString alloc]
                                     initWithString:metadata
                                         attributes:@{
                                             NSFontAttributeName : NeonUI(narrow ? 11 : 12),
                                             NSForegroundColorAttributeName : NeonMuted()
                                         }]];
    NSMutableParagraphStyle* paragraph = [NSMutableParagraphStyle new];
    paragraph.paragraphSpacing = narrow ? 2 : 5;
    paragraph.lineBreakMode = NSLineBreakByTruncatingTail;
    [text addAttribute:NSParagraphStyleAttributeName
                 value:paragraph
                 range:NSMakeRange(0, text.length)];
    return text;
}
} // namespace
#if TARGET_OS_OSX
@interface NeonHistorySelect : NSPopUpButton
@end
@implementation NeonHistorySelect
- (void)drawRect:(NSRect)rect {
    (void)rect;
    NSBezierPath* shape = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, .5, .5)
                                                          xRadius:5
                                                          yRadius:5];
    [NeonPaper() setFill];
    [shape fill];
    [NeonLine() setStroke];
    [shape stroke];
    NSDictionary* attrs = @{
        NSFontAttributeName : NeonUI(13),
        NSForegroundColorAttributeName : self.enabled ? NeonInk() : NeonMuted()
    };
    NSSize size = [self.titleOfSelectedItem sizeWithAttributes:attrs];
    NSRect titleRect = NSMakeRect(8, (self.bounds.size.height - size.height) / 2,
                                  self.bounds.size.width - 30, size.height);
    // Single-line point drawing uses the same baseline geometry as the arrow.
    // drawWithRect without line-fragment layout anchors the popup title incorrectly.
    [NSGraphicsContext saveGraphicsState];
    NSRectClip(titleRect);
    [self.titleOfSelectedItem drawAtPoint:titleRect.origin withAttributes:attrs];
    [NSGraphicsContext restoreGraphicsState];
    [@"▾" drawAtPoint:NSMakePoint(self.bounds.size.width - 20,
                                  (self.bounds.size.height - size.height) / 2)
        withAttributes:attrs];
}
@end
@interface NeonHistoryHeader : NSView
@end
@implementation NeonHistoryHeader
- (BOOL)isFlipped {
    return YES;
}
- (void)drawRect:(NSRect)rect {
    [NeonPaper() setFill];
    NSRectFill(NSIntersectionRect(rect, self.bounds));
    [NeonLine() setFill];
    NSRectFill(NSMakeRect(0, NSHeight(self.bounds) - 1, NSWidth(self.bounds), 1));
}
- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    self.needsDisplay = YES;
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
#if !TARGET_OS_OSX
@interface NeonHistoryHeader : UIView
@end
@implementation NeonHistoryHeader
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = NeonPaper();
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}
- (void)drawRect:(CGRect)rect {
    (void)rect;
    [NeonLine() setFill];
    UIRectFill(CGRectMake(0, CGRectGetHeight(self.bounds) - 1, CGRectGetWidth(self.bounds), 1));
}
@end
#endif
#if TARGET_OS_OSX
@interface NeonHistoryTab : NSButton
@property(nonatomic) BOOL chosen;
@end
@implementation NeonHistoryTab
- (void)setChosen:(BOOL)chosen {
    _chosen = chosen;
    self.needsDisplay = YES;
}
- (void)drawRect:(NSRect)rect {
    (void)rect;
    if (self.chosen) {
        [NeonPaper() setFill];
        [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, 2, 3) xRadius:4
                                         yRadius:4] fill];
    }
    NSDictionary* attributes = @{
        NSFontAttributeName : self.font ?: NeonUI(13),
        NSForegroundColorAttributeName : NeonInk()
    };
    NSSize size = [self.title sizeWithAttributes:attributes];
    [self.title drawAtPoint:NSMakePoint((self.bounds.size.width - size.width) / 2,
                                        (self.bounds.size.height - size.height) / 2)
             withAttributes:attributes];
}
@end
#else
@interface NeonHistoryTab : UIButton
@property(nonatomic) BOOL chosen;
@end
@implementation NeonHistoryTab
- (void)setChosen:(BOOL)chosen {
    _chosen = chosen;
    self.backgroundColor = chosen ? NeonPaper() : UIColor.clearColor;
    self.accessibilityTraits =
        UIAccessibilityTraitButton | (chosen ? UIAccessibilityTraitSelected : 0);
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
    BOOL _compactRows;
    BOOL _restoring;
    NSString* _restoreID;
#if TARGET_OS_OSX
    NSView* _dialog;
    NSView* _dialogCard;
    NSTextField* _dialogTitle;
    NSTextField* _dialogBody;
    NSTextField* _nameLabel;
    NSTextField* _noteLabel;
    NSTextField* _checkpointName;
    NSTextView* _checkpointNote;
    NSScrollView* _noteScroll;
    NSButton* _dialogCancel;
    NSButton* _dialogSubmit;
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
    NSTextField* _versions;
    NSTextField* _footer;
    NSView* _timeline;
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
    UIView* _dialog;
    UIScrollView* _dialogCard;
    UILabel* _dialogTitle;
    UILabel* _dialogBody;
    UILabel* _nameLabel;
    UILabel* _noteLabel;
    UITextField* _checkpointName;
    UITextView* _checkpointNote;
    UIView* _noteScroll;
    UIButton* _dialogCancel;
    UIButton* _dialogSubmit;
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
    UILabel* _versions;
    UILabel* _footer;
    UIView* _timeline;
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
    _working = [NSTextField wrappingLabelWithString:@""];
    _versions = [NSTextField labelWithString:@"Versions"];
    _footer = [NSTextField
        labelWithString:@"Saved on this device · Your working copy is preserved before restore."];
    _timeline = [NSView new];
    _timeline.wantsLayer = YES;
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
    column.resizingMask = NSTableColumnAutoresizingMask;
    _table.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
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
    _chapter = [[NeonHistorySelect alloc] initWithFrame:NSZeroRect pullsDown:NO];
    _chapter.target = self;
    _chapter.action = @selector(chapterChanged:);
#else
    self.view = [UIView new];
    self.view.backgroundColor = NeonPaper();
    self.view.tintColor = NeonAccent();
    self.title = @"Version history";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    _header = [NeonHistoryHeader new];
    _title = [UILabel new];
    _title.text = @"Version history";
    _detail = [UILabel new];
    _working = [UILabel new];
    _working.numberOfLines = 2;
    _versions = [UILabel new];
    _versions.text = @"Versions";
    _footer = [UILabel new];
    _footer.text = @"Saved on this device · Your working copy is preserved before restore.";
    _footer.numberOfLines = 2;
    _timeline = [UIView new];
    _timeline.backgroundColor = NeonPanel();
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
    _table.separatorStyle = UITableViewCellSeparatorStyleNone;
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
    _title.font = NeonUIBold(14);
    _title.textColor = NeonInk();
    _previewTitle.font = NeonSerif(24);
    _previewTitle.textColor = NeonInk();
    _working.font = NeonUI(13);
    _working.textColor = NeonInk();
    _versions.font = NeonSerif(22);
    _versions.textColor = NeonInk();
    _footer.font = NeonUI(12);
    _footer.textColor = NeonMuted();
    _detail.font = NeonUI(12);
    _detail.textColor = NeonMuted();
    _note.font = NeonUI(14);
    _note.textColor = NeonMuted();
#if TARGET_OS_OSX
    NSPopUpButton* filter = [[NeonHistorySelect alloc] initWithFrame:NSZeroRect pullsDown:NO];
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
    _tabs = [NSView new];
    _tabs.wantsLayer = YES;
#else
    _tabs = [UIView new];
    _tabs.backgroundColor = NeonPanel();
#endif
    _tabs.layer.cornerRadius = 7;
    NSArray* tabNames = @[ @"Read version", @"Compare", @"Details" ];
    for (NSInteger index = 0; index < 3; ++index) {
#if TARGET_OS_OSX
        NeonHistoryTab* button = [NeonHistoryTab buttonWithTitle:tabNames[index]
                                                          target:self
                                                          action:@selector(modeChanged:)];
        button.bordered = NO;
        button.font = NeonUI(13);
#else
        NeonHistoryTab* button = [NeonHistoryTab buttonWithType:UIButtonTypeCustom];
        [button setTitle:tabNames[index] forState:UIControlStateNormal];
        [button setTitleColor:NeonInk() forState:UIControlStateNormal];
        button.titleLabel.font = NeonUI(13);
        button.layer.cornerRadius = 4;
        [button addTarget:self
                      action:@selector(modeChanged:)
            forControlEvents:UIControlEventTouchUpInside];
#endif
        button.tag = index;
        button.chosen = index == 0;
        [_tabs addSubview:button];
    }
#if TARGET_OS_OSX
    for (NSButton* button in @[ _back, _checkpoint, _restore, _searchToggle ]) {
        button.bordered = NO;
        button.font = NeonUI(14);
        button.contentTintColor = NeonInk();
    }
    _restore.wantsLayer = YES;
    _restore.layer.borderWidth = 1;
    _restore.layer.cornerRadius = 5;
#else
    for (UIButton* button in @[ _back, _checkpoint, _restore, _searchToggle ]) {
        button.titleLabel.font = NeonUI(14);
        [button setTitleColor:NeonInk() forState:UIControlStateNormal];
    }
    _restore.layer.borderWidth = 1;
    _restore.layer.cornerRadius = 5;
#endif
    _back.accessibilityLabel = @"Back to editor";
    _chapter.accessibilityLabel = @"Chapter to preview";
    _table.accessibilityLabel = @"Saved versions, newest first";
    _preview.accessibilityLabel = @"Read-only revision preview";
    _comparison.accessibilityLabel = @"Working copy comparison, read only";
    for (id child in @[
             _header, _timeline, _title,   _detail,       _back,     _checkpoint,     _versions,
             _footer, _scope,    _working, _searchToggle, _search,   _list,           _previewTitle,
             _note,   _restore,  _tabs,    _chapter,      _document, _currentDocument
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
    CGFloat width = self.view.bounds.size.width, height = self.view.bounds.size.height, top = 0;
#if !TARGET_OS_OSX
    top = self.view.safeAreaInsets.top;
    height -= self.view.safeAreaInsets.bottom;
#endif
    BOOL narrow = width <= 600, medium = width <= 850;
    BOOL reloadRows = narrow != _compactRows;
    _compactRows = narrow;
    CGFloat bar = narrow ? 64 : 68, timeline = narrow ? width : (medium ? 210 : 240),
            pad = narrow ? 16 : (medium ? 20 : 28);
    _header.frame = CGRectMake(0, 0, width, top + bar);
    _back.frame = CGRectMake(narrow ? 12 : 20, top + 12, narrow ? 65 : 66.1, 40);
    CGFloat headingX = narrow ? 87 : timeline + pad;
    CGFloat headingWidth = MAX(0, width - (narrow ? 153 : 204) - headingX);
    _title.frame = CGRectMake(headingX, top + 12, headingWidth, 20);
    _detail.frame = CGRectMake(headingX, top + 35, headingWidth, 18);
    _title.font = NeonUISemibold(narrow ? 13 : 14);
    _checkpoint.frame = CGRectMake(width - (narrow ? 145 : 184), top + 12, narrow ? 133 : 164, 40);
    CGFloat start = top + bar;
    _versions.frame = CGRectMake(narrow ? 12 : 20, start + (narrow ? 12 : 24),
                                 narrow ? 62 : timeline - 40, narrow ? 20 : 32);
    _versions.font = narrow ? NeonUISemibold(13) : NeonSerif(22);
    _scope.frame =
        CGRectMake(narrow ? 82 : 20, start + (narrow ? 8 : 72), timeline - (narrow ? 134 : 76), 32);
    _searchToggle.frame = CGRectMake(timeline - 48, start + (narrow ? 2 : 66), 44, 44);
    _working.hidden = narrow;
    _working.frame = CGRectMake(20, start + 118, timeline - 40, 48);
    CGFloat listY = start + (narrow ? 46 : 190);
    _search.frame = CGRectMake(12, listY, timeline - 24, 40);
    if (!_search.hidden)
        listY += 44;
    CGFloat listHeight = narrow ? 128 : MAX(60, height - listY);
    _list.frame = CGRectMake(0, listY, timeline, listHeight);
    _timeline.frame =
        CGRectMake(0, start, timeline, narrow ? (listY - start + listHeight) : height - start);
    CGFloat detailY = narrow ? listY + listHeight : start;
    CGFloat x = narrow ? pad : timeline + pad, content = width - x - pad;
    CGFloat titleY = detailY + (narrow ? 18 : 26);
    _previewTitle.frame = CGRectMake(x, titleY, MAX(40, content - 98), 38);
    _previewTitle.font = NeonSerif(narrow ? 22 : 24);
    _restore.frame = CGRectMake(width - pad - 82, titleY, 82, 34);
#if TARGET_OS_OSX
    BOOL hasNote = _note.stringValue.length > 0;
    [self.view.effectiveAppearance performAsCurrentDrawingAppearance:^{
      _timeline.layer.backgroundColor = NeonPanel().CGColor;
      _tabs.layer.backgroundColor = NeonPanel().CGColor;
      _restore.layer.borderColor = NeonLine().CGColor;
    }];
#else
    BOOL hasNote = _note.text.length > 0;
    _restore.layer.borderColor = NeonLine().CGColor;
#endif
    _note.hidden = !hasNote;
    _note.font = NeonUI(narrow ? 12 : 14);
    _note.frame = CGRectMake(x, titleY + 42, content, 36);
    CGFloat controlsY = titleY + (hasNote ? 94 : 58),
            tabsWidth = medium ? content : MIN(280, content - 236);
    _tabs.frame = CGRectMake(x, controlsY, tabsWidth, 34);
    CGFloat buttonX = 3;
    for (NeonHistoryTab* button in _tabs.subviews) {
        CGFloat buttonWidth = (tabsWidth - 6) / 3;
        button.frame = CGRectMake(buttonX, 3, buttonWidth, 28);
        buttonX += buttonWidth;
#if TARGET_OS_OSX
        button.font = NeonUI(narrow ? 12 : 13);
#else
        button.titleLabel.font = NeonUI(narrow ? 12 : 13);
#endif
    }
    _chapter.frame = medium ? CGRectMake(x, controlsY + 44, content, 34)
                            : CGRectMake(width - pad - 220, controlsY, 220, 34);
    CGFloat documentY = controlsY + (medium ? 78 : 34) + (narrow ? 30 : 44);
    CGFloat footerHeight = 42;
    _footer.frame = CGRectMake(x, height - footerHeight, content, footerHeight);
    CGFloat documentHeight = MAX(24, height - footerHeight - documentY);
    BOOL compare = _mode == 1;
    _currentDocument.hidden = !compare;
    if (compare && !medium) {
        CGFloat half = (content - 24) / 2;
        _document.frame = CGRectMake(x, documentY, half, documentHeight);
        _currentDocument.frame = CGRectMake(x + half + 24, documentY, half, documentHeight);
    } else if (compare) {
        CGFloat half = MAX(12, (documentHeight - 16) / 2);
        _document.frame = CGRectMake(x, documentY, content, half);
        _currentDocument.frame = CGRectMake(x, documentY + half + 16, content, half);
    } else
        _document.frame = CGRectMake(x, documentY, content, documentHeight);
#if TARGET_OS_OSX
    _table.rowHeight = narrow ? 58 : 101;
    for (NSTextView* text in @[ _preview, _comparison ])
        text.textContainerInset = NSMakeSize(0, 0);
#else
    _table.rowHeight = narrow ? 58 : 101;
    for (UITextView* text in @[ _preview, _comparison ])
        text.textContainerInset = UIEdgeInsetsZero;
#endif
    if (reloadRows) {
        [_table reloadData];
        [self renderPreview];
    }
    [self layoutDialog];
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
    NSString* working = [NSString stringWithFormat:@"● Working copy\n   %lu words · Saved locally",
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
    _mode = [sender tag];
    for (NeonHistoryTab* button in [sender superview].subviews)
        if ([button isKindOfClass:NeonHistoryTab.class])
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
        text = @"No matching revisions.";
    if (_snapshot) {
        if (_mode == 2) {
            text = [NSString
                stringWithFormat:
                    @"Type\t%@\nSaved\t%@\nScope\tEntire project · %lu sections\nStorage\tOn this "
                    @"device\nRestore behavior\tSave the current draft first, then make this "
                    @"version the working copy. Existing versions stay in history.",
                    entryKind(entry), entryDetail(entry),
                    (unsigned long)[_snapshot[@"sections"] count]];
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
    if (_mode == 2 && _snapshot) {
        BOOL narrow = self.view.bounds.size.width <= 600;
        NSMutableParagraphStyle* facts = [NSMutableParagraphStyle new];
        facts.headIndent = narrow ? 85 : 120;
        facts.tabStops = @[ [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentLeft
                                                            location:facts.headIndent
                                                             options:@{}] ];
        facts.minimumLineHeight = facts.maximumLineHeight = (narrow ? 13 : 14) * 1.6;
        facts.paragraphSpacing = narrow ? 14 : 20;
        NSMutableAttributedString* content = [[NSMutableAttributedString alloc]
            initWithString:text
                attributes:@{
                    NSFontAttributeName : NeonUI(narrow ? 13 : 14),
                    NSForegroundColorAttributeName : NeonInk(),
                    NSParagraphStyleAttributeName : facts
                }];
        [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                                 options:NSStringEnumerationByParagraphs
                              usingBlock:^(NSString* paragraph, NSRange range, NSRange, BOOL*) {
                                NSRange tab = [paragraph rangeOfString:@"\t"];
                                if (tab.location != NSNotFound)
                                    [content
                                        addAttribute:NSForegroundColorAttributeName
                                               value:NeonMuted()
                                               range:NSMakeRange(range.location, tab.location)];
                              }];
#if TARGET_OS_OSX
        [_preview.textStorage setAttributedString:content];
#else
        _preview.attributedText = content;
#endif
    }
    if (_mode == 0 && saved) {
        BOOL narrow = self.view.bounds.size.width <= 600;
        NSMutableAttributedString* content =
            [[NSMutableAttributedString alloc] initWithString:@"Saved version · Read only\n"
                                                   attributes:@{
                                                       NSFontAttributeName : NeonUI(12),
                                                       NSForegroundColorAttributeName : NeonMuted()
                                                   }];
        NSMutableParagraphStyle* metadata = [NSMutableParagraphStyle new];
        metadata.paragraphSpacing = 16;
        [content addAttribute:NSParagraphStyleAttributeName
                        value:metadata
                        range:NSMakeRange(0, content.length)];
        NSMutableParagraphStyle* heading = [NSMutableParagraphStyle new];
        heading.minimumLineHeight = heading.maximumLineHeight = (narrow ? 22 : 24) * 1.4;
        heading.paragraphSpacing = 24;
        [content
            appendAttributedString:[[NSAttributedString alloc]
                                       initWithString:[NSString
                                                          stringWithFormat:@"%@\n", saved[@"title"]]
                                           attributes:@{
                                               NSFontAttributeName : NeonSerif(narrow ? 22 : 24),
                                               NSForegroundColorAttributeName : NeonInk(),
                                               NSParagraphStyleAttributeName : heading
                                           }]];
        NSMutableParagraphStyle* body = [NSMutableParagraphStyle new];
        body.minimumLineHeight = body.maximumLineHeight = (narrow ? 16 : 17) * 1.8;
        body.paragraphSpacing = 17;
        NSUInteger bodyStart = content.length;
        NSString* manuscript = saved[@"text"] ?: @"";
        [content
            appendAttributedString:[[NSAttributedString alloc]
                                       initWithString:manuscript
                                           attributes:@{
                                               NSFontAttributeName : NeonSerif(narrow ? 16 : 17),
                                               NSForegroundColorAttributeName : NeonInk(),
                                               NSParagraphStyleAttributeName : body
                                           }]];
        [manuscript
            enumerateSubstringsInRange:NSMakeRange(0, manuscript.length)
                               options:NSStringEnumerationByParagraphs
                            usingBlock:^(NSString* paragraph, NSRange, NSRange enclosing, BOOL*) {
                              BOOL blank =
                                  ![paragraph
                                       stringByTrimmingCharactersInSet:NSCharacterSet
                                                                           .whitespaceCharacterSet]
                                       .length;
                              NSUInteger next = NSMaxRange(enclosing);
                              BOOL followed = next < manuscript.length &&
                                              [manuscript characterAtIndex:next] == '\n';
                              if (blank || followed) {
                                  NSMutableParagraphStyle* separated = [body mutableCopy];
                                  separated.paragraphSpacing = 0;
                                  if (blank)
                                      separated.minimumLineHeight = separated.maximumLineHeight =
                                          17;
                                  [content addAttribute:NSParagraphStyleAttributeName
                                                  value:separated
                                                  range:NSMakeRange(bodyStart + enclosing.location,
                                                                    enclosing.length)];
                              }
                            }];
#if TARGET_OS_OSX
        [_preview.textStorage setAttributedString:content];
#else
        _preview.attributedText = content;
#endif
    }
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
                style.minimumLineHeight = style.maximumLineHeight = 25.5;
                style.paragraphSpacing = 12;
                NSMutableDictionary* attributes = [@{
                    NSFontAttributeName : NeonSerif(15),
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
    [self showDialog:NO];
}
- (void)showDialog:(BOOL)restoring {
    if (_dialog)
        return;
    _restoring = restoring;
    _restoreID = [_selected copy];
#if TARGET_OS_OSX
    _dialog = [NSView new];
    _dialog.wantsLayer = YES;
    _dialog.layer.backgroundColor = [NSColor.blackColor colorWithAlphaComponent:.25].CGColor;
    _dialogCard = [NeonHistoryBackground new];
    _dialogCard.wantsLayer = YES;
    _dialogTitle =
        [NSTextField labelWithString:restoring ? @"Restore this version?" : @"Save a checkpoint"];
    _dialogBody = [NSTextField
        wrappingLabelWithString:restoring ? @"This version will become the working copy. A "
                                            @"checkpoint of the current draft will be saved first."
                                          : @"Preserves the entire project on this device."];
    _nameLabel = [NSTextField labelWithString:@"Checkpoint name"];
    _noteLabel = [NSTextField labelWithString:@"Note"];
    _checkpointName = [NSTextField new];
    _checkpointName.placeholderString = @"e.g. Before revising the ending";
    _checkpointName.font = NeonUI(14);
    _checkpointName.backgroundColor = NeonPanel();
    _checkpointName.textColor = NeonInk();
    _checkpointName.target = self;
    _checkpointName.action = @selector(submitDialog);
    _checkpointNote = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 360, 80)];
    _checkpointNote.font = NeonUI(14);
    _checkpointNote.backgroundColor = NeonPanel();
    _checkpointNote.textColor = NeonInk();
    _checkpointNote.textContainerInset = NSMakeSize(10, 10);
    _checkpointNote.autoresizingMask = NSViewWidthSizable;
    _noteScroll = [NSScrollView new];
    _noteScroll.documentView = _checkpointNote;
    _noteScroll.hasVerticalScroller = YES;
    _dialogCancel = [NSButton buttonWithTitle:@"Cancel"
                                       target:self
                                       action:@selector(dismissDialog)];
    _dialogSubmit = [NSButton buttonWithTitle:restoring ? @"Restore version" : @"Save checkpoint"
                                       target:self
                                       action:@selector(submitDialog)];
    for (NSButton* button in @[ _dialogCancel, _dialogSubmit ]) {
        button.bordered = NO;
        button.font = NeonUI(14);
    }
    _dialogSubmit.wantsLayer = YES;
    _dialogSubmit.layer.backgroundColor = NeonAccent().CGColor;
    _dialogSubmit.contentTintColor = NeonPaper();
    _dialogSubmit.layer.cornerRadius = 5;
    _checkpointName.nextKeyView = _checkpointNote;
    _checkpointNote.nextKeyView = _dialogCancel;
    _dialogCancel.nextKeyView = _dialogSubmit;
    _dialogSubmit.nextKeyView = _checkpointName;
#else
    _dialog = [UIView new];
    _dialog.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:.25];
    _dialog.accessibilityViewIsModal = YES;
    _dialogCard = [UIScrollView new];
    _dialogCard.backgroundColor = NeonPaper();
    _dialogCard.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    _dialogTitle = [UILabel new];
    _dialogTitle.text = restoring ? @"Restore this version?" : @"Save a checkpoint";
    _dialogBody = [UILabel new];
    _dialogBody.numberOfLines = 0;
    _dialogBody.text = restoring ? @"This version will become the working copy. A checkpoint of "
                                   @"the current draft will be saved first."
                                 : @"Preserves the entire project on this device.";
    _nameLabel = [UILabel new];
    _nameLabel.text = @"Checkpoint name";
    _noteLabel = [UILabel new];
    _noteLabel.text = @"Note";
    _checkpointName = [UITextField new];
    _checkpointName.placeholder = @"e.g. Before revising the ending";
    _checkpointName.font = NeonUI(14);
    _checkpointName.backgroundColor = NeonPanel();
    _checkpointName.textColor = NeonInk();
    _checkpointName.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 32)];
    _checkpointName.leftViewMode = UITextFieldViewModeAlways;
    _checkpointName.returnKeyType = UIReturnKeyDone;
    [_checkpointName addTarget:self
                        action:@selector(submitDialog)
              forControlEvents:UIControlEventEditingDidEndOnExit];
    _checkpointNote = [UITextView new];
    _checkpointNote.font = NeonUI(14);
    _checkpointNote.backgroundColor = NeonPanel();
    _checkpointNote.textColor = NeonInk();
    _checkpointNote.textContainerInset = UIEdgeInsetsMake(10, 10, 10, 10);
    _noteScroll = _checkpointNote;
    _dialogCancel = [UIButton buttonWithType:UIButtonTypeSystem];
    [_dialogCancel setTitle:@"Cancel" forState:UIControlStateNormal];
    [_dialogCancel addTarget:self
                      action:@selector(dismissDialog)
            forControlEvents:UIControlEventTouchUpInside];
    _dialogSubmit = [UIButton buttonWithType:UIButtonTypeSystem];
    [_dialogSubmit setTitle:restoring ? @"Restore version" : @"Save checkpoint"
                   forState:UIControlStateNormal];
    [_dialogSubmit addTarget:self
                      action:@selector(submitDialog)
            forControlEvents:UIControlEventTouchUpInside];
    for (UIButton* button in @[ _dialogCancel, _dialogSubmit ])
        button.titleLabel.font = NeonUI(14);
    _dialogSubmit.backgroundColor = NeonAccent();
    [_dialogSubmit setTitleColor:NeonPaper() forState:UIControlStateNormal];
    _dialogSubmit.layer.cornerRadius = 5;
    _checkpointName.layer.borderWidth = 1;
    _checkpointName.layer.borderColor = NeonLine().CGColor;
    _checkpointName.layer.cornerRadius = 5;
    _checkpointNote.layer.borderWidth = 1;
    _checkpointNote.layer.borderColor = NeonLine().CGColor;
    _checkpointNote.layer.cornerRadius = 5;
#endif
    _dialogTitle.font = NeonSerif(24);
    _dialogTitle.textColor = NeonInk();
    _dialogBody.font = NeonUI(14);
    _dialogBody.textColor = NeonMuted();
    for (id label in @[ _nameLabel, _noteLabel ]) {
        [label setFont:NeonUI(14)];
        [label setTextColor:NeonInk()];
    }
    _checkpointName.accessibilityLabel = @"Checkpoint name";
    _checkpointNote.accessibilityLabel = @"Note";
    _dialogCard.layer.cornerRadius = 14;
    _dialogCard.layer.borderWidth = 1;
    _dialogCard.layer.borderColor = NeonLine().CGColor;
    [_dialog addSubview:_dialogCard];
    [self.view addSubview:_dialog];
    for (id child in @[
             _dialogTitle, _dialogBody, _nameLabel, _checkpointName, _noteLabel, _noteScroll,
             _dialogCancel, _dialogSubmit
         ])
        [_dialogCard addSubview:child];
    _nameLabel.hidden = restoring;
    _noteLabel.hidden = restoring;
    _checkpointName.hidden = restoring;
    _noteScroll.hidden = restoring;
    [self layoutDialog];
#if TARGET_OS_OSX
    [self.view.window makeFirstResponder:restoring ? (NSResponder*)_dialogCancel : _checkpointName];
#else
    if (!restoring)
        [_checkpointName becomeFirstResponder];
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification, _dialogTitle);
#endif
}
- (void)layoutDialog {
    if (!_dialog)
        return;
    _dialog.frame = self.view.bounds;
    BOOL narrow = self.view.bounds.size.width <= 600;
    CGFloat pad = narrow ? 22 : 28;
    CGFloat width = MIN(440, self.view.bounds.size.width - (narrow ? 32 : 48)),
            fullHeight = _restoring ? 250 : 420;
    CGFloat available = self.view.bounds.size.height, top = 0;
#if !TARGET_OS_OSX
    top = self.view.safeAreaInsets.top;
    available = MIN(available - self.view.safeAreaInsets.bottom,
                    self.view.keyboardLayoutGuide.layoutFrame.origin.y) -
                top;
#endif
    CGFloat height = MIN(fullHeight, MAX(180, available - 32));
    _dialogCard.frame = CGRectMake((self.view.bounds.size.width - width) / 2,
                                   top + (available - height) / 2, width, height);
    CGFloat content = width - pad * 2;
    _dialogTitle.font = NeonSerif(narrow ? 22 : 24);
    _dialogTitle.frame = CGRectMake(pad, pad, content, 38);
    _nameLabel.frame = CGRectMake(pad, pad + 62, content, 20);
    _checkpointName.frame = CGRectMake(pad, pad + 90, content, 40);
    _noteLabel.frame = CGRectMake(pad, pad + 148, content, 20);
    _noteScroll.frame = CGRectMake(pad, pad + 176, content, 80);
    _dialogBody.frame =
        CGRectMake(pad, _restoring ? pad + 60 : pad + 276, content, _restoring ? 80 : 40);
    CGFloat buttonsY = fullHeight - pad - 40;
    _dialogSubmit.frame = CGRectMake(width - pad - 144, buttonsY, 144, 40);
    _dialogCancel.frame = CGRectMake(width - pad - 228, buttonsY, 76, 40);
#if !TARGET_OS_OSX
    _dialogCard.contentSize = CGSizeMake(width, fullHeight);
#endif
}
- (void)dismissDialog {
#if !TARGET_OS_OSX
    [_dialog endEditing:YES];
#endif
    [_dialog removeFromSuperview];
    _dialog = nil;
    _dialogCard = nil;
#if TARGET_OS_OSX
    [self.view.window makeFirstResponder:_restoring ? _restore : _checkpoint];
#else
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification,
                                    _restoring ? _restore : _checkpoint);
#endif
}
- (void)cancelOperation:(id)sender {
    (void)sender;
    [self dismissDialog];
}
#if !TARGET_OS_OSX
- (NSArray<UIKeyCommand*>*)keyCommands {
    return @[ [UIKeyCommand keyCommandWithInput:UIKeyInputEscape
                                  modifierFlags:0
                                         action:@selector(dismissDialog)] ];
}
#endif
- (void)submitDialog {
    if (_restoring) {
        NSUInteger count = self.session.history.count;
        [self performRestore:_restoreID];
        if (self.session.history.count > count)
            [self dismissDialog];
        return;
    }
#if TARGET_OS_OSX
    NSString* title = _checkpointName.stringValue;
    NSString* note = _checkpointNote.string;
#else
    NSString* title = _checkpointName.text;
    NSString* note = _checkpointNote.text;
#endif
    if (![title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
             .length) {
#if TARGET_OS_OSX
        _dialogBody.stringValue = @"Give this checkpoint a name.";
        [self.view.window makeFirstResponder:_checkpointName];
#else
        _dialogBody.text = @"Give this checkpoint a name.";
        [_checkpointName becomeFirstResponder];
#endif
        return;
    }
    NSUInteger count = self.session.history.count;
    [self saveCheckpoint:title note:note];
    if (self.session.history.count > count)
        [self dismissDialog];
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
    if (_selected)
        [self showDialog:YES];
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
    BOOL narrow = self.view.bounds.size.width <= 600;
    NSView* cell = [[NSView alloc]
        initWithFrame:NSMakeRect(0, 0, tableView.bounds.size.width, tableView.rowHeight)];
    NSTextField* field = [NSTextField wrappingLabelWithString:@""];
    field.attributedStringValue = rowText(_entries[row], narrow);
    field.frame =
        NSMakeRect(narrow ? 28 : 36, 8, MAX(40, cell.bounds.size.width - (narrow ? 40 : 56)),
                   cell.bounds.size.height - 16);
    field.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    NSView* dot = [[NSView alloc]
        initWithFrame:NSMakeRect(narrow ? 13 : 19, cell.bounds.size.height - (narrow ? 21 : 30), 6,
                                 6)];
    dot.wantsLayer = YES;
    dot.layer.cornerRadius = 3;
    dot.layer.borderWidth = 1;
    dot.layer.borderColor = NeonAccent().CGColor;
    [cell addSubview:dot];
    [cell addSubview:field];
    return cell;
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
    BOOL narrow = self.view.bounds.size.width <= 600;
    UILabel* text = [UILabel new];
    text.numberOfLines = narrow ? 2 : 3;
    text.attributedText = rowText(_entries[path.row], narrow);
    text.frame =
        CGRectMake(narrow ? 28 : 36, 8, MAX(40, tableView.bounds.size.width - (narrow ? 40 : 56)),
                   tableView.rowHeight - 16);
    text.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    UIView* dot =
        [[UIView alloc] initWithFrame:CGRectMake(narrow ? 13 : 19, narrow ? 15 : 24, 6, 6)];
    dot.layer.cornerRadius = 3;
    dot.layer.borderWidth = 1;
    dot.layer.borderColor = NeonAccent().CGColor;
    [cell.contentView addSubview:dot];
    [cell.contentView addSubview:text];
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
