#include "History.h"
#include "EditorialTheme.h"
#include <string>

namespace {
NSString* entryDetail(NSDictionary* entry) {
    NSDate* date = [NSDate dateWithTimeIntervalSince1970:[entry[@"createdAt"] doubleValue]];
    NSString* time = [NSDateFormatter localizedStringFromDate:date
                                                    dateStyle:NSDateFormatterMediumStyle
                                                    timeStyle:NSDateFormatterShortStyle];
    return [NSString
        stringWithFormat:@"%@ · Revision %@ · %@", time, entry[@"revision"], entry[@"actor"]];
}
} // namespace
#if TARGET_OS_OSX
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
- (void)drawRect:(NSRect)rect {
    [NeonPaper() setFill];
    NSRectFill(rect);
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
    BOOL _checkpointsOnly;
#if TARGET_OS_OSX
    NSSearchField* _search;
    NSTextField* _previewTitle;
    NSTableView* _table;
    NSTextView* _preview;
    NSButton* _restore;
    NSTextField* _detail;
#else
    UISearchBar* _search;
    UILabel* _previewTitle;
    UITableView* _table;
    UITextView* _preview;
    UIButton* _restore;
    UILabel* _detail;
#endif
}
- (void)loadView {
#if TARGET_OS_OSX
    self.view = [[NeonHistoryBackground alloc] initWithFrame:NSMakeRect(0, 0, 740, 640)];
    NSTextField* title = [NSTextField labelWithString:@"Version History"];
    title.font = NeonSerif(26);
    title.textColor = NeonInk();
    NSView* scope =
        NeonPillSelector(@[ @"All Versions", @"Checkpoints" ], 0, self, @selector(scopeChanged:));
    NSButton* searchButton = [NSButton buttonWithTitle:@"Search History"
                                                target:self
                                                action:@selector(toggleSearch)];
    NSStackView* filters = [NSStackView stackViewWithViews:@[ scope, searchButton ]];
    filters.spacing = 12;
    NSSearchField* search = [NSSearchField new];
    search.placeholderString = @"Search checkpoints, revisions, or authors";
    search.delegate = self;
    _search = search;
    search.hidden = YES;
    _detail = [NSTextField
        wrappingLabelWithString:
            @"Automatic snapshots are captured while saving, at most once a minute. Checkpoints "
            @"preserve an exact version. Scope: entire project, including Trash."];
    _detail.font = NeonUI(12);
    _detail.textColor = NeonMuted();
    _table = [NSTableView new];
    NSTableColumn* column = [[NSTableColumn alloc] initWithIdentifier:@"revision"];
    column.title = @"Local history";
    column.width = 660;
    [_table addTableColumn:column];
    _table.headerView = nil;
    _table.rowHeight = 64;
    _table.style = NSTableViewStyleFullWidth;
    _table.gridStyleMask = NSTableViewSolidHorizontalGridLineMask;
    _table.gridColor = [NeonMuted() colorWithAlphaComponent:0.18];
    _table.accessibilityLabel = @"Saved versions, newest first";
    _table.delegate = self;
    _table.dataSource = self;
    _table.backgroundColor = NeonPanel();
    NSScrollView* list = [NSScrollView new];
    list.documentView = _table;
    list.hasVerticalScroller = YES;
    list.drawsBackground = NO;
    _preview = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 680, 200)];
    _preview.editable = NO;
    _preview.font = NeonSerif(16);
    _preview.textColor = NeonInk();
    _preview.backgroundColor = NeonPaper();
    _preview.textContainerInset = NSMakeSize(12, 12);
    _preview.autoresizingMask = NSViewWidthSizable;
    NSScrollView* preview = [NSScrollView new];
    preview.documentView = _preview;
    preview.hasVerticalScroller = YES;
    preview.drawsBackground = NO;
    _previewTitle = [NSTextField wrappingLabelWithString:@"Version Preview"];
    _previewTitle.font = NeonUI(14);
    _previewTitle.textColor = NeonMuted();
    NSButton* checkpoint = [NSButton buttonWithTitle:@"New Checkpoint…"
                                              target:self
                                              action:@selector(checkpoint)];
    _restore = [NSButton buttonWithTitle:@"Restore as New Version…"
                                  target:self
                                  action:@selector(restore)];
    NSStackView* buttons = [NSStackView stackViewWithViews:@[ checkpoint, _restore ]];
    buttons.spacing = 12;
    NSStackView* stack = [NSStackView stackViewWithViews:@[
        title, _detail, filters, search, list, _previewTitle, preview, buttons
    ]];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [stack.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:24],
        [stack.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-24],
        [list.heightAnchor constraintEqualToConstant:120],
        [preview.heightAnchor constraintGreaterThanOrEqualToConstant:60]
    ]];
    for (NSView* child in @[ search, _detail, list, _previewTitle, preview ])
        [child.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
#else
    self.view = [UIView new];
    self.view.backgroundColor = NeonPaper();
    self.view.tintColor = NeonAccent();
    self.title = @"Version History";
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Search History"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(toggleSearch)];
    UIView* workspace =
        NeonPillSelector(@[ @"Editor", @"History" ], 1, self, @selector(workspaceChanged:));
    self.navigationItem.titleView = workspace;
    UIView* scope =
        NeonPillSelector(@[ @"All Versions", @"Checkpoints" ], 0, self, @selector(scopeChanged:));
    UISearchBar* search = [UISearchBar new];
    search.placeholder = @"Search local history";
    search.delegate = self;
    _search = search;
    search.hidden = YES;
    search.searchBarStyle = UISearchBarStyleMinimal;
    _detail = [UILabel new];
    _detail.text = @"Automatic snapshots: at most once a minute while saving. Checkpoints capture "
                   @"an exact version. Scope: entire project, including Trash.";
    _detail.numberOfLines = 0;
    _detail.font = NeonUI(12);
    _detail.textColor = NeonMuted();
    _table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _table.dataSource = self;
    _table.delegate = self;
    _table.backgroundColor = NeonPanel();
    _table.rowHeight = UITableViewAutomaticDimension;
    _table.estimatedRowHeight = 68;
    _table.accessibilityLabel = @"Saved versions, newest first";
    _table.separatorColor = [NeonMuted() colorWithAlphaComponent:0.18];
    _previewTitle = [UILabel new];
    _previewTitle.numberOfLines = 0;
    _previewTitle.font = NeonUI(14);
    _previewTitle.textColor = NeonMuted();
    _preview = [UITextView new];
    _preview.editable = NO;
    _preview.font = NeonSerif(16);
    _preview.textColor = NeonInk();
    _preview.backgroundColor = NeonPaper();
    UIButton* checkpoint = [UIButton buttonWithType:UIButtonTypeSystem];
    [checkpoint setTitle:@"New Checkpoint…" forState:UIControlStateNormal];
    [checkpoint addTarget:self
                   action:@selector(checkpoint)
         forControlEvents:UIControlEventTouchUpInside];
    _restore = [UIButton buttonWithType:UIButtonTypeSystem];
    [_restore setTitle:@"Restore as New Version…" forState:UIControlStateNormal];
    [_restore addTarget:self
                  action:@selector(restore)
        forControlEvents:UIControlEventTouchUpInside];
    UIStackView* buttons = [[UIStackView alloc] initWithArrangedSubviews:@[ checkpoint, _restore ]];
    buttons.axis = UILayoutConstraintAxisVertical;
    buttons.spacing = 4;
    UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        _detail, scope, search, _table, _previewTitle, _preview, buttons
    ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    UILayoutGuide* safe = self.view.safeAreaLayoutGuide;
    NSLayoutConstraint* listHeight = [_table.heightAnchor constraintEqualToAnchor:safe.heightAnchor
                                                                       multiplier:0.28];
    listHeight.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [stack.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8],
        [stack.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor
                                           constant:-12],
        listHeight, [_preview.heightAnchor constraintGreaterThanOrEqualToConstant:60]
    ]];
#endif
    _preview.accessibilityLabel = @"Read-only revision preview";
    [self reloadHistory];
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
}
- (void)workspaceChanged:(id)sender {
    if ([sender tag] == 0 && self.showEditor)
        self.showEditor();
}
- (void)scopeChanged:(id)sender {
    _checkpointsOnly = [sender tag] == 1;
#if TARGET_OS_OSX
    for (NSButton* button in [sender superview].subviews) {
        if (![button isKindOfClass:NSButton.class])
            continue;
        button.state = button == sender ? NSControlStateValueOn : NSControlStateValueOff;
        button.accessibilityValue = button == sender ? @"Selected" : @"Not selected";
        button.needsDisplay = YES;
    }
#else
    for (UIButton* button in [sender superview].subviews) {
        if (![button isKindOfClass:UIButton.class])
            continue;
        UIButtonConfiguration* config = button.configuration;
        config.baseBackgroundColor =
            button == sender ? [NeonAccent() colorWithAlphaComponent:0.22] : UIColor.clearColor;
        config.baseForegroundColor = button == sender ? NeonAccent() : NeonMuted();
        button.configuration = config;
        button.accessibilityTraits =
            UIAccessibilityTraitButton | (button == sender ? UIAccessibilityTraitSelected : 0);
    }
#endif
    [self reloadHistory];
}
- (void)reloadHistory {
    NSMutableArray* entries = [NSMutableArray array];
    for (NSDictionary* entry in self.session.history) {
        if (_checkpointsOnly && ![entry[@"kind"] isEqual:@"checkpoint"])
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
    NSString* heading = _selected ? [NSString stringWithFormat:@"%@ — Read-only preview\n%@",
                                                               _entries[index][@"label"],
                                                               entryDetail(_entries[index])]
                                  : @"Version Preview";
    NSError* error = nil;
    NSString* preview =
        _selected
            ? [self.session previewRevision:_selected error:&error]
            : (_query.length ? @"No matching revisions."
                             : @"No snapshots yet. Create a checkpoint to preserve this version.");
#if TARGET_OS_OSX
    _previewTitle.stringValue = heading;
    _preview.string = preview ?: error.localizedDescription;
    _preview.textColor = NeonInk();
    if (_selected)
        [_table selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
#else
    _previewTitle.text = heading;
    _preview.text = preview ?: error.localizedDescription;
    if (_selected)
        [_table selectRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]
                            animated:NO
                      scrollPosition:UITableViewScrollPositionNone];
#endif
    _restore.enabled = _selected != nil && preview != nil;
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
- (void)saveCheckpoint:(NSString*)name {
    NSError* error = nil;
    if (![self.session createCheckpoint:name error:&error]) {
        [self problem:error];
        return;
    }
    [self reloadHistory];
}
- (void)checkpoint {
#if TARGET_OS_OSX
    NSAlert* alert = [NSAlert new];
    alert.messageText = @"Name this checkpoint";
    NSTextField* field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 320, 28)];
    field.placeholderString = @"For example: Before review";
    alert.accessoryView = field;
    [alert addButtonWithTitle:@"Save Checkpoint"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] == NSAlertFirstButtonReturn)
        [self saveCheckpoint:field.stringValue];
#else
    UIAlertController* alert =
        [UIAlertController alertControllerWithTitle:@"Name this checkpoint"
                                            message:@"Preserves the entire project on this device."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField* field) {
      field.placeholder = @"Before review";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save Checkpoint"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction*) {
                                              [self
                                                  saveCheckpoint:alert.textFields.firstObject.text];
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
