#include "Settings.h"
#import "ContextMenu.h"
#import "Preferences.h"

namespace {
NSArray<NSDictionary*>* settings() {
    return @[
        @{
            @"key" : @"manuscriptFont",
            @"title" : @"Editor font",
            @"category" : @"Writing",
            @"kind" : @"font",
            @"detail" : @"Typeface for reading and editing"
        },
        @{
            @"key" : @"manuscriptSize",
            @"title" : @"Text size",
            @"category" : @"Writing",
            @"kind" : @"number",
            @"min" : @16,
            @"max" : @32,
            @"step" : @1,
            @"default" : @(TARGET_OS_IPHONE ? 17 : 19),
            @"unit" : @"pt"
        },
        @{
            @"key" : @"manuscriptSpacing",
            @"title" : @"Line spacing",
            @"category" : @"Writing",
            @"kind" : @"number",
            @"min" : @2,
            @"max" : @16,
            @"step" : @1,
            @"default" : @8,
            @"unit" : @"pt"
        },
        @{
            @"key" : @"paragraphSpacing",
            @"title" : @"Paragraph spacing",
            @"category" : @"Writing",
            @"kind" : @"number",
            @"min" : @0,
            @"max" : @24,
            @"step" : @1,
            @"default" : @4,
            @"unit" : @"pt"
        },
        @{
            @"key" : @"textMeasure",
            @"title" : @"Line width",
            @"category" : @"Writing",
            @"kind" : @"number",
            @"min" : @480,
            @"max" : @960,
            @"step" : @40,
            @"default" : @760,
            @"unit" : @"pt",
            @"detail" : @""
        },
        @{
            @"key" : @"spellcheck",
            @"title" : @"Check spelling",
            @"category" : @"Writing",
            @"kind" : @"toggle",
            @"default" : @YES,
            @"detail" : @"Underline misspelled words"
        },
        @{
            @"key" : @"smartQuotes",
            @"title" : @"Smart quotes",
            @"category" : @"Writing",
            @"kind" : @"toggle",
            @"default" : @YES,
            @"detail" : @"Use typographic quotation marks as you type"
        },
        @{
            @"key" : @"smartDashes",
            @"title" : @"Smart dashes",
            @"category" : @"Writing",
            @"kind" : @"toggle",
            @"default" : @YES,
            @"detail" : @"Substitute typographic dashes as you type"
        },
        @{
            @"key" : @"showWordCount",
            @"title" : @"Show word count",
            @"category" : @"Writing",
            @"kind" : @"toggle",
            @"default" : @YES,
            @"detail" : @"Display the chapter count beside save status"
        },
        @{
            @"key" : @"appearance",
            @"title" : @"Dark appearance",
            @"category" : @"Appearance",
            @"kind" : @"appearance",
            @"detail" : @"A softer palette for evening writing."
        },
        @{
            @"key" : @"liquidGlass",
            @"title" : @"Liquid Glass",
            @"category" : @"Appearance",
            @"kind" : @"toggle",
            @"default" : @YES,
            @"detail" : @"Translucent navigation and controls."
        },
        @{
            @"key" : @"automaticCheckpoints",
            @"title" : @"Automatic checkpoints",
            @"category" : @"History",
            @"kind" : @"toggle",
            @"default" : @YES,
            @"detail" : @"Preserve a snapshot while saving, at most once a minute. Document saving "
                        @"stays on."
        },
        @{
            @"key" : @"reduceMotion",
            @"title" : @"Reduce motion",
            @"category" : @"Accessibility",
            @"kind" : @"toggle",
            @"default" : @NO,
            @"detail" : @"Use short fades instead of movement."
        },
        @{
            @"key" : @"reduceTransparency",
            @"title" : @"Reduce transparency",
            @"category" : @"Accessibility",
            @"kind" : @"toggle",
            @"default" : @NO,
            @"detail" : @"Use opaque surfaces for clearer contrast."
        }
    ];
}
NSArray<NSDictionary*>* matches(NSString* query) {
    NSString* clean =
        [query stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!clean.length)
        return settings();
    return [settings()
        filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary* item,
                                                                          NSDictionary* bindings) {
          (void)bindings;
          NSString* words = [NSString stringWithFormat:@"%@ %@ %@", item[@"title"],
                                                       item[@"category"], item[@"detail"] ?: @""];
          return [words localizedCaseInsensitiveContainsString:clean];
        }]];
}
id value(NSDictionary* item) {
    return [NeonPreferences() objectForKey:item[@"key"]] ?: item[@"default"];
}
NSString* numberLabel(NSDictionary* item) {
    return [NSString stringWithFormat:@"%.0f %@", [value(item) doubleValue], item[@"unit"]];
}
void reset() {
    for (NSDictionary* item in settings())
        [NeonPreferences() removeObjectForKey:item[@"key"]];
}
} // namespace

namespace {
NSArray<NSString*>* primaryKeys() {
    return @[
        @"appearance", @"liquidGlass", @"manuscriptSize", @"textMeasure", @"spellcheck",
        @"automaticCheckpoints", @"reduceMotion", @"reduceTransparency"
    ];
}
NSArray* choices(NSString* key) {
    if ([key isEqual:@"manuscriptSize"])
        return @[ @"Small · 17 pt", @"Standard · 19 pt", @"Large · 22 pt" ];
    if ([key isEqual:@"textMeasure"])
        return @[ @"Comfortable", @"Wide" ];
    return @[ @"Literata", @"Source Sans 3", @"System Serif" ];
}
NSString* choiceLabel(NSString* key) {
    if ([key isEqual:@"manuscriptSize"]) {
        NSInteger size = (NSInteger)NeonTextSize();
        return size == 17   ? choices(key)[0]
               : size == 19 ? choices(key)[1]
               : size == 22 ? choices(key)[2]
                            : [NSString stringWithFormat:@"Custom · %ld pt", (long)size];
    }
    if ([key isEqual:@"textMeasure"])
        return NeonTextMeasure() > 760 ? @"Wide" : @"Comfortable";
    return NeonFontChoice();
}
void setChoice(NSString* key, NSUInteger index) {
    if ([key isEqual:@"manuscriptSize"])
        [NeonPreferences() setInteger:[@[ @17, @19, @22 ][index] integerValue] forKey:key];
    else if ([key isEqual:@"textMeasure"])
        [NeonPreferences() setDouble:index == 0 ? 760 : 960 forKey:key];
    else
        [NeonPreferences() setObject:choices(key)[index] forKey:key];
}
} // namespace
#if TARGET_OS_IPHONE
@interface NeonSettingsCheck : UIButton
@property(nonatomic) BOOL checked;
@end
@implementation NeonSettingsCheck
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent*)event {
    (void)event;
    return CGRectContainsPoint(CGRectInset(self.bounds, -13, 0), point);
}
- (void)setChecked:(BOOL)value {
    _checked = value;
    self.accessibilityValue = value ? @"On" : @"Off";
    [self setNeedsDisplay];
}
- (void)drawRect:(CGRect)rect {
    (void)rect;
    CGRect box =
        CGRectMake((self.bounds.size.width - 18) / 2, (self.bounds.size.height - 18) / 2, 18, 18);
    UIBezierPath* path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(box, .5, .5)
                                                    cornerRadius:2];
    [(self.checked ? NeonAccent() : NeonPaper()) setFill];
    [path fill];
    [(self.checked ? NeonAccent() : NeonMuted()) setStroke];
    [path stroke];
    if (self.checked) {
        UIBezierPath* tick = [UIBezierPath bezierPath];
        [tick moveToPoint:CGPointMake(box.origin.x + 4, box.origin.y + 9)];
        [tick addLineToPoint:CGPointMake(box.origin.x + 8, box.origin.y + 13)];
        [tick addLineToPoint:CGPointMake(box.origin.x + 14, box.origin.y + 5)];
        tick.lineWidth = 2;
        [NeonPaper() setStroke];
        [tick stroke];
    }
}
@end
#else
@interface NeonSettingsPaper : NSView
@end
@implementation NeonSettingsPaper
- (BOOL)isFlipped {
    return YES;
}
- (void)drawRect:(NSRect)rect {
    [NeonPaper() setFill];
    NSRectFill(rect);
}
- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    self.needsDisplay = YES;
}
@end
@interface NeonSettingsCheck : NSButton
@end
@implementation NeonSettingsCheck
- (void)drawRect:(NSRect)rect {
    (void)rect;
    NSRect box =
        NSMakeRect((self.bounds.size.width - 18) / 2, (self.bounds.size.height - 18) / 2, 18, 18);
    NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(box, .5, .5)
                                                         xRadius:2
                                                         yRadius:2];
    [(self.state == NSControlStateValueOn ? NeonAccent() : NeonPaper()) setFill];
    [path fill];
    [(self.state == NSControlStateValueOn ? NeonAccent() : NeonMuted()) setStroke];
    [path stroke];
    if (self.state == NSControlStateValueOn) {
        NSBezierPath* tick = [NSBezierPath bezierPath];
        [tick moveToPoint:NSMakePoint(box.origin.x + 4, box.origin.y + 9)];
        [tick lineToPoint:NSMakePoint(box.origin.x + 8, box.origin.y + 13)];
        [tick lineToPoint:NSMakePoint(box.origin.x + 14, box.origin.y + 5)];
        tick.lineWidth = 2;
        [NeonPaper() setStroke];
        [tick stroke];
    }
}
@end
#endif

@interface NeonSettingsController ()
@property(nonatomic, strong) NSArray<NSDictionary*>* visibleSettings;
@property(nonatomic, copy) NSString* query;
@property(nonatomic) BOOL advanced;
@end
@implementation NeonSettingsController {
    NSString* _headerStyle;
#if TARGET_OS_IPHONE
    UIView* _header;
    UIButton* _back;
    UILabel* _headerTitle;
    UILabel* _headerSubtitle;
    UIView* _intro;
#else
    NSView* _header;
    NSButton* _back;
    NSTextField* _headerTitle;
    NSTextField* _headerSubtitle;
    NSScrollView* _scroll;
    NSView* _document;
    NSMutableArray<NSDictionary*>* _blocks;
#endif
}
- (void)loadView {
    self.visibleSettings = settings();
    self.query = @"";
#if TARGET_OS_IPHONE
    self.view = [UIView new];
    self.view.backgroundColor = NeonPaper();
    _header = [UIView new];
    _back = [UIButton buttonWithType:UIButtonTypeSystem];
    [_back setTitle:@"← Back" forState:UIControlStateNormal];
    [_back addTarget:self action:@selector(done) forControlEvents:UIControlEventTouchUpInside];
    _back.titleLabel.font = NeonUI(14);
    [_back setTitleColor:NeonInk() forState:UIControlStateNormal];
    _headerTitle = [UILabel new];
    _headerTitle.text = @"Settings";
    _headerSubtitle = [UILabel new];
    _headerSubtitle.text = @"Personalize your writing space";
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = NeonPaper();
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.sectionHeaderTopPadding = 0;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 70;
    [self.view addSubview:self.tableView];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.navigationController.navigationBarHidden = YES;
#else
    self.view = [[NeonSettingsPaper alloc] initWithFrame:NSMakeRect(0, 0, 760, 760)];
    _header = [NSView new];
    _back = [NSButton buttonWithTitle:@"← Back" target:self action:@selector(done)];
    _back.bordered = NO;
    _back.font = NeonUI(14);
    _back.contentTintColor = NeonInk();
    _headerTitle = [NSTextField labelWithString:@"Settings"];
    _headerSubtitle = [NSTextField labelWithString:@"Personalize your writing space"];
    _scroll = [NSScrollView new];
    _scroll.drawsBackground = NO;
    _scroll.hasVerticalScroller = YES;
    _scroll.autohidesScrollers = YES;
    _document = [NeonSettingsPaper new];
    _scroll.documentView = _document;
    [self.view addSubview:_scroll];
#endif
    _back.accessibilityLabel = @"Back";
    _back.accessibilityIdentifier = @"settings-back";
    _headerTitle.font = NeonUISemibold(14);
    _headerTitle.textColor = NeonInk();
    _headerSubtitle.font = NeonUI(12);
    _headerSubtitle.textColor = NeonMuted();
    NeonApplyGlassBackdrop(_header, 0);
    for (id child in @[ _header, _back, _headerTitle, _headerSubtitle ])
        [self.view addSubview:child];
    [self rebuild];
}
- (NSUInteger)visibleSettingCount {
    return self.visibleSettings.count;
}
- (void)filterSettings:(NSString*)query {
    self.query = query ?: @"";
    self.visibleSettings = matches(query);
    [self rebuild];
}
- (NSArray<NSDictionary*>*)itemsForSection:(NSInteger)section {
    NSString* category =
        @[ @"Appearance", @"Writing", @"History", @"Accessibility", @"Advanced" ][MIN(section, 4)];
    NSMutableArray* result = [NSMutableArray array];
    NSArray* keys = primaryKeys();
    for (NSString* key in keys)
        for (NSDictionary* item in self.visibleSettings)
            if ([item[@"key"] isEqual:key] && [item[@"category"] isEqual:category])
                [result addObject:item];
    if (section == 4 || self.query.length)
        for (NSDictionary* item in self.visibleSettings)
            if (![keys containsObject:item[@"key"]] &&
                (section == 4 ? !self.query.length : [item[@"category"] isEqual:category]))
                [result addObject:item];
    return result;
}
- (void)done {
    if (self.closeSettings) {
        self.closeSettings();
        return;
    }
#if TARGET_OS_IPHONE
    [self dismissViewControllerAnimated:!NeonReduceMotion() completion:nil];
#endif
}
- (void)browseHistory {
    if (self.showHistory)
        self.showHistory();
}
- (void)toggleAdvanced {
    self.advanced = !self.advanced;
    [self rebuild];
}
- (void)resetPreferences {
#if TARGET_OS_IPHONE
    UIAlertController* alert =
        [UIAlertController alertControllerWithTitle:@"Reset device preferences?"
                                            message:@"Your documents are unchanged."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction*) {
                                              reset();
                                              [self changed];
                                              [self rebuild];
                                            }]];
    [self presentViewController:alert animated:!NeonReduceMotion() completion:nil];
#else
    NSAlert* alert = [NSAlert new];
    alert.messageText = @"Reset device preferences?";
    alert.informativeText = @"Your documents are unchanged.";
    [alert addButtonWithTitle:@"Reset"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert beginSheetModalForWindow:self.view.window
                  completionHandler:^(NSModalResponse response) {
                    if (response == NSAlertFirstButtonReturn) {
                        reset();
                        [self changed];
                        [self rebuild];
                    }
                  }];
#endif
}
- (void)followSystem {
    [NeonPreferences() setInteger:0 forKey:@"appearance"];
    [self changed];
    [self rebuild];
}
- (void)changed {
#if TARGET_OS_IPHONE
    if (!self.preferencesChanged)
        self.overrideUserInterfaceStyle = NeonAppearance() == 1   ? UIUserInterfaceStyleLight
                                          : NeonAppearance() == 2 ? UIUserInterfaceStyleDark
                                                                  : UIUserInterfaceStyleUnspecified;
#else
    if (!self.preferencesChanged)
        self.view.window.appearance =
            NeonAppearance() == 1   ? [NSAppearance appearanceNamed:NSAppearanceNameAqua]
            : NeonAppearance() == 2 ? [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]
                                    : nil;
    self.view.needsDisplay = YES;
#endif
    if (self.preferencesChanged)
        self.preferencesChanged();
    [self layoutSettings];
}
#if TARGET_OS_IPHONE
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutSettings];
}
- (void)updateSearchResultsForSearchController:(UISearchController*)controller {
    [self filterSettings:controller.searchBar.text];
}
- (UIView*)labels:(NSDictionary*)item {
    UILabel* title = [UILabel new];
    title.text = item[@"title"];
    title.font = NeonUI(14);
    title.textColor = NeonInk();
    title.numberOfLines = 0;
    UIStackView* labels = [[UIStackView alloc] initWithArrangedSubviews:@[ title ]];
    labels.axis = UILayoutConstraintAxisVertical;
    labels.spacing = 4;
    NSString* detail = item[@"detail"];
    if ([item[@"key"] isEqual:@"manuscriptSize"])
        detail = @"Adjust the manuscript text.";
    if (detail.length) {
        UILabel* subtitle = [UILabel new];
        subtitle.text = detail;
        subtitle.font = NeonUI(12);
        subtitle.textColor = NeonMuted();
        subtitle.numberOfLines = 0;
        [labels addArrangedSubview:subtitle];
    }
    return labels;
}
- (UIView*)control:(NSDictionary*)item {
    NSString* key = item[@"key"];
    if ([item[@"kind"] isEqual:@"toggle"] || [key isEqual:@"appearance"]) {
        NeonSettingsCheck* check = [NeonSettingsCheck buttonWithType:UIButtonTypeCustom];
        check.checked =
            [key isEqual:@"appearance"] ? NeonAppearance() == 2 : [value(item) boolValue];
        check.accessibilityIdentifier = key;
        check.accessibilityLabel = item[@"title"];
        [check addTarget:self
                      action:@selector(toggle:)
            forControlEvents:UIControlEventTouchUpInside];
        [check.widthAnchor constraintEqualToConstant:18].active = YES;
        [check.heightAnchor constraintEqualToConstant:44].active = YES;
        return check;
    }
    if ([primaryKeys() containsObject:key] || [item[@"kind"] isEqual:@"font"]) {
        UIButton* menu = [UIButton buttonWithType:UIButtonTypeSystem];
        menu.showsMenuAsPrimaryAction = YES;
        [menu setTitle:[choiceLabel(key) stringByAppendingString:@" ▾"]
              forState:UIControlStateNormal];
        menu.titleLabel.font = NeonUI(self.view.bounds.size.width <= 600 ? 12 : 14);
        [menu setTitleColor:NeonInk() forState:UIControlStateNormal];
        menu.backgroundColor = NeonPanel();
        menu.layer.borderColor = NeonLine().CGColor;
        menu.layer.borderWidth = 1;
        menu.layer.cornerRadius = 5;
        menu.accessibilityLabel = item[@"title"];
        NSMutableArray* actions = [NSMutableArray array];
        __weak NeonSettingsController* weak = self;
        NSArray* titles = choices(key);
        for (NSUInteger index = 0; index < titles.count; ++index)
            [actions addObject:[UIAction actionWithTitle:titles[index]
                                                   image:nil
                                              identifier:nil
                                                 handler:^(UIAction*) {
                                                   setChoice(key, index);
                                                   [weak changed];
                                                   [weak rebuild];
                                                 }]];
        menu.menu = [UIMenu menuWithChildren:actions];
        CGFloat menuWidth =
            MIN(self.view.bounds.size.width <= 600 ? 145 : 180,
                [choiceLabel(key) sizeWithAttributes:@{NSFontAttributeName : menu.titleLabel.font}]
                        .width +
                    30);
        [menu.widthAnchor constraintEqualToConstant:menuWidth].active = YES;
        [menu.heightAnchor constraintEqualToConstant:36].active = YES;
        return menu;
    }
    UILabel* current = [UILabel new];
    current.text = numberLabel(item);
    current.font = NeonUI(14);
    current.textColor = NeonMuted();
    UIStepper* stepper = [UIStepper new];
    stepper.minimumValue = [item[@"min"] doubleValue];
    stepper.maximumValue = [item[@"max"] doubleValue];
    stepper.stepValue = [item[@"step"] doubleValue];
    stepper.value = [value(item) doubleValue];
    stepper.accessibilityIdentifier = key;
    stepper.accessibilityLabel = item[@"title"];
    __weak NeonSettingsController* weak = self;
    __weak UIStepper* weakStepper = stepper;
    [stepper addAction:[UIAction actionWithHandler:^(UIAction*) {
               [NeonPreferences() setDouble:weakStepper.value forKey:key];
               current.text = numberLabel(item);
               [weak changed];
             }]
        forControlEvents:UIControlEventValueChanged];
    UIStackView* row = [[UIStackView alloc] initWithArrangedSubviews:@[ current, stepper ]];
    row.spacing = 8;
    return row;
}
- (void)toggle:(NeonSettingsCheck*)check {
    check.checked = !check.checked;
    if ([check.accessibilityIdentifier isEqual:@"appearance"])
        [NeonPreferences() setInteger:check.checked ? 2 : 1 forKey:@"appearance"];
    else
        [NeonPreferences() setBool:check.checked forKey:check.accessibilityIdentifier];
    [self changed];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView {
    (void)tableView;
    return self.advanced && !self.query.length ? 5 : 4;
}
- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    return [self itemsForSection:section].count +
           (section == 2 && self.showHistory && !self.query.length ? 1 : 0);
}
- (UIView*)tableView:(UITableView*)tableView viewForHeaderInSection:(NSInteger)section {
    (void)tableView;
    UILabel* label = [UILabel new];
    label.text = @[ @"Appearance", @"Writing", @"History", @"Accessibility", @"Advanced" ][section];
    label.font = NeonUISemibold(13);
    label.textColor = NeonMuted();
    UIView* view = [UIView new];
    [view addSubview:label];
    label.frame = CGRectMake(0, 28, self.tableView.bounds.size.width, 18);
    return view;
}
- (CGFloat)tableView:(UITableView*)tableView heightForHeaderInSection:(NSInteger)section {
    (void)tableView;
    return [self itemsForSection:section].count ? 58.5 : 0;
}
- (CGFloat)tableView:(UITableView*)tableView heightForFooterInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return 0;
}
- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)path {
    (void)tableView;
    UITableViewCell* cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                   reuseIdentifier:nil];
    cell.backgroundColor = NeonPaper();
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    NSArray* items = [self itemsForSection:path.section];
    if ((NSUInteger)path.row >= items.count) {
        cell.textLabel.text = @"Browse version history →";
        cell.textLabel.font = NeonUI(14);
        cell.textLabel.textColor = NeonAccent();
        return cell;
    }
    NSDictionary* item = items[path.row];
    UIView* labels = [self labels:item];
    UIView* control = [self control:item];
    UIStackView* row = [[UIStackView alloc] initWithArrangedSubviews:@[ labels, control ]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = self.view.bounds.size.width <= 600 ? 14 : 24;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:row];
    UIView* line = [UIView new];
    line.backgroundColor = NeonLine();
    line.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:line];
    [NSLayoutConstraint activateConstraints:@[
        [row.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor],
        [row.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor],
        [row.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:16],
        [row.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-16],
        [line.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor],
        [line.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor],
        [line.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor],
        [line.heightAnchor constraintEqualToConstant:1]
    ]];
    return cell;
}
- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)path {
    (void)tableView;
    NSArray* items = [self itemsForSection:path.section];
    if (path.section == 2 && path.row == (NSInteger)items.count) {
        [self browseHistory];
        return;
    }
    if ((NSUInteger)path.row >= items.count)
        return;
    NSDictionary* item = items[path.row];
    NSString* key = item[@"key"];
    if ([key isEqual:@"appearance"])
        [NeonPreferences() setInteger:NeonAppearance() == 2 ? 1 : 2 forKey:key];
    else if ([item[@"kind"] isEqual:@"toggle"])
        [NeonPreferences() setBool:![value(item) boolValue] forKey:key];
    else
        return;
    UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:path];
    for (UIView* child in cell.contentView.subviews)
        if ([child isKindOfClass:UIStackView.class]) {
            UIView* control = ((UIStackView*)child).arrangedSubviews.lastObject;
            if ([control isKindOfClass:NeonSettingsCheck.class])
                ((NeonSettingsCheck*)control).checked =
                    [key isEqual:@"appearance"] ? NeonAppearance() == 2 : [value(item) boolValue];
        }
    [self changed];
}
- (void)rebuild {
    if (!self.isViewLoaded)
        return;
    [self.tableView reloadData];
    [self layoutSettings];
}
- (void)layoutSettings {
    CGFloat width = self.view.bounds.size.width, top = self.view.safeAreaInsets.top;
    NSString* style =
        [NSString stringWithFormat:@"%ld:%d", (long)self.traitCollection.userInterfaceStyle,
                                   NeonGlassEnabled()];
    if (![_headerStyle isEqual:style]) {
        _headerStyle = style;
        NeonApplyGlassBackdrop(_header, 0);
    }
    BOOL narrow = width <= 600;
    CGFloat headerHeight = narrow ? 64 : 68;
    _header.frame = CGRectMake(0, 0, width, top + headerHeight);
    _back.frame = CGRectMake(narrow ? 12 : 20, top + 12, 66.1, 40);
    _headerTitle.frame = CGRectMake(narrow ? 87 : 106.1, top + 12, width - 130, 20);
    _headerSubtitle.frame = CGRectMake(narrow ? 87 : 106.1, top + 35, width - 130, 18);
    CGFloat outer = MIN(width, 760), pad = narrow ? 20 : 40;
    self.tableView.frame = CGRectMake(
        (width - outer) / 2 + pad, top + headerHeight, outer - pad * 2,
        self.view.bounds.size.height - top - headerHeight - self.view.safeAreaInsets.bottom);
    CGFloat textWidth = self.tableView.bounds.size.width;
    if (!_intro || fabs(_intro.bounds.size.width - textWidth) > .5) {
        _intro = [[UIView alloc] initWithFrame:CGRectMake(0, 0, textWidth, narrow ? 108 : 116)];
        UILabel* heading =
            [[UILabel alloc] initWithFrame:CGRectMake(0, narrow ? 24 : 28, textWidth, 42)];
        heading.text = @"Your writing, your way.";
        heading.font = NeonSerif(narrow ? 25 : 28);
        heading.textColor = NeonInk();
        heading.adjustsFontSizeToFitWidth = YES;
        UILabel* intro =
            [[UILabel alloc] initWithFrame:CGRectMake(0, narrow ? 76 : 80, textWidth, 36)];
        intro.text = @"Personal preferences apply to this device.";
        intro.font = NeonUI(14);
        intro.textColor = NeonMuted();
        intro.numberOfLines = 2;
        [_intro addSubview:heading];
        [_intro addSubview:intro];
        self.tableView.tableHeaderView = _intro;
    }
    UIView* existingFooter = self.tableView.tableFooterView;
    if (existingFooter && fabs(existingFooter.bounds.size.width - textWidth) < .5 &&
        existingFooter.tag == (self.advanced ? 1 : 0))
        return;
    UIView* footer =
        [[UIView alloc] initWithFrame:CGRectMake(0, 0, textWidth, self.advanced ? 204 : 108)];
    footer.tag = self.advanced ? 1 : 0;
    UILabel* saved = [[UILabel alloc] initWithFrame:CGRectMake(0, 24, textWidth, 20)];
    saved.text = @"Changes apply immediately to your writing space.";
    saved.font = NeonUI(12);
    saved.textColor = NeonMuted();
    [footer addSubview:saved];
    UIButton* advanced = [UIButton buttonWithType:UIButtonTypeSystem];
    advanced.frame = CGRectMake(0, 56, textWidth, 44);
    [advanced setTitle:self.advanced ? @"Hide advanced preferences ▴" : @"Advanced preferences ▾"
              forState:UIControlStateNormal];
    advanced.titleLabel.font = NeonUI(13);
    [advanced setTitleColor:NeonMuted() forState:UIControlStateNormal];
    advanced.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    [advanced addTarget:self
                  action:@selector(toggleAdvanced)
        forControlEvents:UIControlEventTouchUpInside];
    [footer addSubview:advanced];
    if (self.advanced) {
        UIButton* system = [UIButton buttonWithType:UIButtonTypeSystem];
        system.frame = CGRectMake(0, 104, textWidth, 44);
        [system setTitle:@"Use system appearance" forState:UIControlStateNormal];
        [system addTarget:self
                      action:@selector(followSystem)
            forControlEvents:UIControlEventTouchUpInside];
        [footer addSubview:system];
    }
    if (self.advanced) {
        UIButton* resetButton = [UIButton buttonWithType:UIButtonTypeSystem];
        resetButton.frame = CGRectMake(0, 152, textWidth, 44);
        [resetButton setTitle:@"Reset device preferences…" forState:UIControlStateNormal];
        resetButton.titleLabel.font = NeonUI(13);
        [resetButton addTarget:self
                        action:@selector(resetPreferences)
              forControlEvents:UIControlEventTouchUpInside];
        [footer addSubview:resetButton];
    }
    self.tableView.tableFooterView = footer;
}
#else
- (void)viewDidLayout {
    [super viewDidLayout];
    [self layoutSettings];
}
- (void)controlTextDidChange:(NSNotification*)notification {
    NSText* editor = [notification.object currentEditor];
    NSRange selection = editor ? editor.selectedRange : NSMakeRange(0, 0);
    [self filterSettings:[notification.object stringValue]];
    for (NSView* child in _document.subviews) {
        if ([child isKindOfClass:NSSearchField.class]) {
            [self.view.window makeFirstResponder:child];
            NSText* replacement = [(NSSearchField*)child currentEditor];
            replacement.selectedRange = selection;
            break;
        }
    }
}
- (NSTextField*)label:(NSString*)text font:(NSFont*)font color:(NSColor*)color {
    NSTextField* label = [NSTextField wrappingLabelWithString:text ?: @""];
    label.font = font;
    label.textColor = color;
    return label;
}
- (NSView*)control:(NSDictionary*)item {
    NSString* key = item[@"key"];
    if ([item[@"kind"] isEqual:@"toggle"] || [key isEqual:@"appearance"]) {
        NeonSettingsCheck* check = [NeonSettingsCheck new];
        check.buttonType = NSButtonTypeSwitch;
        check.title = @"";
        check.state =
            ([key isEqual:@"appearance"] ? NeonAppearance() == 2 : [value(item) boolValue])
                ? NSControlStateValueOn
                : NSControlStateValueOff;
        check.identifier = key;
        check.accessibilityLabel = item[@"title"];
        check.target = self;
        check.action = @selector(toggle:);
        return check;
    }
    if ([primaryKeys() containsObject:key] || [item[@"kind"] isEqual:@"font"]) {
        NSButton* menu = [NSButton buttonWithTitle:[choiceLabel(key) stringByAppendingString:@" ▾"]
                                            target:self
                                            action:@selector(choose:)];
        menu.bordered = NO;
        menu.font = NeonUI(14);
        menu.contentTintColor = NeonInk();
        menu.identifier = key;
        menu.accessibilityLabel = item[@"title"];
        menu.wantsLayer = YES;
        menu.layer.cornerRadius = 5;
        menu.layer.borderWidth = 1;
        return menu;
    }
    NSTextField* current = [self label:numberLabel(item) font:NeonUI(14) color:NeonMuted()];
    NSStepper* stepper = [NSStepper new];
    stepper.minValue = [item[@"min"] doubleValue];
    stepper.maxValue = [item[@"max"] doubleValue];
    stepper.increment = [item[@"step"] doubleValue];
    stepper.doubleValue = [value(item) doubleValue];
    stepper.identifier = key;
    stepper.accessibilityLabel = item[@"title"];
    stepper.target = self;
    stepper.action = @selector(number:);
    NSStackView* stack = [NSStackView stackViewWithViews:@[ current, stepper ]];
    stack.spacing = 8;
    return stack;
}
- (void)toggle:(NeonSettingsCheck*)sender {
    if ([sender.identifier isEqual:@"appearance"])
        [NeonPreferences() setInteger:sender.state == NSControlStateValueOn ? 2 : 1
                               forKey:@"appearance"];
    else
        [NeonPreferences() setBool:sender.state == NSControlStateValueOn forKey:sender.identifier];
    [self changed];
}
- (void)choose:(NSButton*)sender {
    NSMenu* menu = [NSMenu new];
    NSArray* titles = choices(sender.identifier);
    for (NSUInteger index = 0; index < titles.count; ++index) {
        NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:titles[index]
                                                      action:@selector(selectedChoice:)
                                               keyEquivalent:@""];
        item.target = self;
        item.representedObject = @{@"key" : sender.identifier, @"index" : @(index)};
        [menu addItem:item];
    }
    [menu popUpMenuPositioningItem:nil
                        atLocation:NSMakePoint(0, sender.bounds.size.height)
                            inView:sender];
}
- (void)selectedChoice:(NSMenuItem*)sender {
    setChoice(sender.representedObject[@"key"],
              [sender.representedObject[@"index"] unsignedIntegerValue]);
    [self changed];
    [self rebuild];
}
- (void)number:(NSStepper*)sender {
    [NeonPreferences() setDouble:sender.doubleValue forKey:sender.identifier];
    for (NSDictionary* item in settings())
        if ([item[@"key"] isEqual:sender.identifier])
            ((NSTextField*)((NSStackView*)sender.superview).arrangedSubviews.firstObject)
                .stringValue = numberLabel(item);
    [self changed];
}
- (void)addBlock:(NSView*)view kind:(NSString*)kind item:(NSDictionary*)item {
    [_document addSubview:view];
    [_blocks addObject:@{@"view" : view, @"kind" : kind, @"item" : item ?: @{}}];
}
- (void)rebuild {
    if (!self.isViewLoaded)
        return;
    for (NSView* child in [_document.subviews copy])
        [child removeFromSuperview];
    _blocks = [NSMutableArray array];
    [self addBlock:[self label:@"Your writing, your way." font:NeonSerif(28) color:NeonInk()]
              kind:@"introTitle"
              item:nil];
    [self addBlock:[self label:@"Personal preferences apply to this device."
                          font:NeonUI(14)
                         color:NeonMuted()]
              kind:@"intro"
              item:nil];
    NSInteger sections = self.advanced && !self.query.length ? 5 : 4;
    for (NSInteger section = 0; section < sections; ++section) {
        NSArray* items = [self itemsForSection:section];
        if (!items.count)
            continue;
        [self addBlock:[self label:@[
                  @"Appearance", @"Writing", @"History", @"Accessibility", @"Advanced"
              ][section]
                              font:NeonUISemibold(13)
                             color:NeonMuted()]
                  kind:@"section"
                  item:nil];
        for (NSDictionary* item in items) {
            NSView* row = [NSView new];
            row.identifier = @"settingsRow";
            NSTextField* title = [self label:item[@"title"] font:NeonUI(14) color:NeonInk()];
            title.identifier = @"rowTitle";
            NSString* detail = [item[@"key"] isEqual:@"manuscriptSize"]
                                   ? @"Adjust the manuscript text."
                                   : item[@"detail"];
            NSTextField* subtitle = [self label:detail font:NeonUI(12) color:NeonMuted()];
            subtitle.identifier = @"rowDetail";
            NSView* control = [self control:item];
            NSBox* line = [NSBox new];
            line.boxType = NSBoxSeparator;
            line.identifier = @"rowLine";
            for (NSView* child in @[ title, subtitle, control, line ])
                [row addSubview:child];
            [self addBlock:row kind:@"row" item:item];
        }
        if (section == 2 && self.showHistory && !self.query.length) {
            NSButton* history = [NSButton buttonWithTitle:@"Browse version history →"
                                                   target:self
                                                   action:@selector(browseHistory)];
            history.bordered = NO;
            history.font = NeonUI(14);
            history.contentTintColor = NeonAccent();
            history.alignment = NSTextAlignmentLeft;
            [self addBlock:history kind:@"history" item:nil];
        }
    }
    [self addBlock:[self label:self.query.length && !self.visibleSettings.count
                                   ? @"No settings found."
                                   : @"Changes apply immediately to your writing space."
                          font:NeonUI(12)
                         color:NeonMuted()]
              kind:@"saved"
              item:nil];
    NSButton* advanced = [NSButton
        buttonWithTitle:self.advanced ? @"Hide advanced preferences ▴" : @"Advanced preferences ▾"
                 target:self
                 action:@selector(toggleAdvanced)];
    advanced.bordered = NO;
    advanced.font = NeonUI(13);
    advanced.contentTintColor = NeonMuted();
    advanced.alignment = NSTextAlignmentLeft;
    [self addBlock:advanced kind:@"advanced" item:nil];
    if (self.advanced) {
        NSButton* system = [NSButton buttonWithTitle:@"Use system appearance"
                                              target:self
                                              action:@selector(followSystem)];
        system.bordered = NO;
        system.font = NeonUI(13);
        system.alignment = NSTextAlignmentLeft;
        [self addBlock:system kind:@"advanced" item:nil];
        NSButton* resetButton = [NSButton buttonWithTitle:@"Reset device preferences…"
                                                   target:self
                                                   action:@selector(resetPreferences)];
        resetButton.bordered = NO;
        resetButton.font = NeonUI(13);
        resetButton.alignment = NSTextAlignmentLeft;
        [self addBlock:resetButton kind:@"advanced" item:nil];
        NSSearchField* search = [NSSearchField new];
        search.placeholderString = @"Search settings";
        search.delegate = self;
        search.stringValue = self.query;
        [self addBlock:search kind:@"advanced" item:nil];
    }
    [self layoutSettings];
}
- (void)layoutSettings {
    CGFloat width = self.view.bounds.size.width;
    BOOL narrow = width <= 600;
    CGFloat header = narrow ? 64 : 68;
    _header.frame = NSMakeRect(0, 0, width, header);
    _back.frame = NSMakeRect(narrow ? 12 : 20, 12, 66.1, 40);
    _headerTitle.frame = NSMakeRect(narrow ? 87 : 106.1, 12, width - 130, 20);
    _headerSubtitle.frame = NSMakeRect(narrow ? 87 : 106.1, 35, width - 130, 18);
    NSString* style = [NSString
        stringWithFormat:@"%@:%d", self.view.effectiveAppearance.name, NeonGlassEnabled()];
    if (![_headerStyle isEqual:style]) {
        _headerStyle = style;
        [self.view.effectiveAppearance performAsCurrentDrawingAppearance:^{
          NeonApplyGlassBackdrop(_header, 0);
        }];
    }
    _scroll.frame = NSMakeRect(0, header, width, self.view.bounds.size.height - header);
    CGFloat outer = MIN(width, 760), pad = narrow ? 20 : 40, content = outer - pad * 2,
            x = (width - outer) / 2 + pad, y = narrow ? 24 : 28;
    for (NSDictionary* block in _blocks) {
        NSView* view = block[@"view"];
        NSString* kind = block[@"kind"];
        if ([kind isEqual:@"row"]) {
            NSDictionary* item = block[@"item"];
            NSView* control = view.subviews[2];
            CGFloat controlWidth =
                ([item[@"kind"] isEqual:@"toggle"] || [item[@"key"] isEqual:@"appearance"])
                    ? 18
                    : MIN(narrow ? 145 : 180,
                          [choiceLabel(item[@"key"])
                              sizeWithAttributes:@{NSFontAttributeName : NeonUI(narrow ? 12 : 14)}]
                                  .width +
                              30);
            CGFloat labelWidth = MAX(80, content - controlWidth - (narrow ? 14 : 24));
            NSTextField* title = (id)view.subviews[0];
            NSTextField* detail = (id)view.subviews[1];
            CGFloat titleHeight =
                ceil([title.stringValue boundingRectWithSize:NSMakeSize(labelWidth, 1000)
                                                     options:NSStringDrawingUsesLineFragmentOrigin
                                                  attributes:@{NSFontAttributeName : title.font}]
                         .size.height);
            CGFloat detailHeight =
                detail.stringValue.length
                    ? ceil([detail.stringValue
                               boundingRectWithSize:NSMakeSize(labelWidth, 1000)
                                            options:NSStringDrawingUsesLineFragmentOrigin
                                         attributes:@{NSFontAttributeName : detail.font}]
                               .size.height)
                    : 0;
            CGFloat labels = titleHeight + (detailHeight ? detailHeight + 4 : 0),
                    height = MAX(labels, 36) + 32;
            view.frame = NSMakeRect(x, y, content, height);
            // Native row coordinate system is bottom-up.
            title.frame =
                NSMakeRect(0, (height + labels) / 2 - titleHeight, labelWidth, titleHeight);
            detail.frame = NSMakeRect(0, (height - labels) / 2, labelWidth, detailHeight);
            control.frame = NSMakeRect(content - controlWidth, (height - 36) / 2, controlWidth, 36);
            view.subviews.lastObject.frame = NSMakeRect(0, 0, content, 1);
            if ([control isKindOfClass:NSButton.class] &&
                ![control isKindOfClass:NeonSettingsCheck.class]) {
                [control.effectiveAppearance performAsCurrentDrawingAppearance:^{
                  control.layer.backgroundColor = NeonPanel().CGColor;
                  control.layer.borderColor = NeonLine().CGColor;
                }];
                ((NSButton*)control).font = NeonUI(narrow ? 12 : 14);
            }
            y += height;
        } else {
            CGFloat h = 20;
            if ([kind isEqual:@"introTitle"]) {
                ((NSTextField*)view).font = NeonSerif(narrow ? 25 : 28);
                h = 42;
            } else if ([kind isEqual:@"intro"]) {
                y += 10;
                h = 28;
            } else if ([kind isEqual:@"section"]) {
                y += 28;
                h = 30;
            } else if ([kind isEqual:@"saved"]) {
                y += 24;
                h = 20;
            } else if ([kind isEqual:@"history"])
                h = 48;
            else if ([kind isEqual:@"advanced"])
                h = 36;
            view.frame = NSMakeRect(x, y, content, h);
            y += h;
        }
    }
    _document.frame = NSMakeRect(0, 0, width, MAX(y + 28, _scroll.contentView.bounds.size.height));
}
#endif
@end
