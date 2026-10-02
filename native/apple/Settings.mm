#include "Settings.h"
#import "ContextMenu.h"

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
            @"default" : @(TARGET_OS_IPHONE ? 18 : 20),
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
            @"title" : @"Text column width",
            @"category" : @"Writing",
            @"kind" : @"number",
            @"min" : @480,
            @"max" : @960,
            @"step" : @40,
            @"default" : @640,
            @"unit" : @"pt",
            @"detail" : @"Maximum width; adapts to smaller windows"
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
            @"title" : @"Appearance",
            @"category" : @"Appearance",
            @"kind" : @"appearance",
            @"detail" : @"System, Light or Dark"
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
    return [NSUserDefaults.standardUserDefaults objectForKey:item[@"key"]] ?: item[@"default"];
}
NSString* numberLabel(NSDictionary* item) {
    return [NSString stringWithFormat:@"%.0f %@", [value(item) doubleValue], item[@"unit"]];
}
void reset() {
    for (NSDictionary* item in settings())
        [NSUserDefaults.standardUserDefaults removeObjectForKey:item[@"key"]];
}
} // namespace

#if TARGET_OS_IPHONE
@interface NeonSettingsController ()
@property(nonatomic, strong) NSArray<NSDictionary*>* visibleSettings;
@property(nonatomic, strong) UISearchController* search;
@end
@implementation NeonSettingsController
- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Settings";
    self.view.backgroundColor = NeonPanel();
    self.tableView.tintColor = NeonAccent();
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 82;
    self.visibleSettings = settings();
    self.search = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.search.searchResultsUpdater = self;
    self.search.obscuresBackgroundDuringPresentation = NO;
    self.search.searchBar.placeholder = @"Search settings";
    self.navigationItem.searchController = self.search;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self
                                                      action:@selector(done)];
}
- (NSUInteger)visibleSettingCount {
    return self.visibleSettings.count;
}
- (void)filterSettings:(NSString*)query {
    self.visibleSettings = matches(query);
    [self.tableView reloadData];
}
- (void)updateSearchResultsForSearchController:(UISearchController*)controller {
    [self filterSettings:controller.searchBar.text];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView {
    (void)tableView;
    return 3;
}
- (NSArray*)itemsForSection:(NSInteger)section {
    NSString* category = section == 0 ? @"Writing" : @"Appearance";
    return [self.visibleSettings
        filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"category == %@", category]];
}
- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    return section == 2 ? (self.search.searchBar.text.length ? 0 : 1)
                        : [self itemsForSection:section].count;
}
- (NSString*)tableView:(UITableView*)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView;
    if (section == 2 || ![self itemsForSection:section].count)
        return nil;
    return section == 0 ? @"Writing · This device" : @"Appearance · This device";
}
- (NSString*)tableView:(UITableView*)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    if (section == 2)
        return self.visibleSettings.count
                   ? @"Personal editor preferences. Document content and export styles are "
                     @"unchanged."
                   : @"No settings found. Try “font”, “spacing” or “appearance”.";
    return nil;
}
- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)path {
    (void)tableView;
    UITableViewCell* cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                                   reuseIdentifier:nil];
    cell.backgroundColor = NeonPaper();
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if (path.section == 2) {
        cell.textLabel.text = @"Reset Device Preferences…";
        cell.textLabel.textColor = NeonAccent();
        cell.accessibilityTraits = UIAccessibilityTraitButton;
        return cell;
    }
    NSDictionary* item = [self itemsForSection:path.section][path.row];
    NSString* key = item[@"key"];
    UILabel* title = [UILabel new];
    title.text = item[@"title"];
    title.font = NeonUI(17);
    title.textColor = NeonInk();
    title.numberOfLines = 0;
    UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:@[ title ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 8;
    NSString* kind = item[@"kind"];
    if ([kind isEqual:@"toggle"]) {
        UISwitch* control = [UISwitch new];
        control.onTintColor = NeonAccent();
        control.on = [value(item) boolValue];
        control.accessibilityIdentifier = key;
        control.accessibilityLabel = item[@"title"];
        [control addTarget:self
                      action:@selector(toggle:)
            forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = control;
    } else if ([kind isEqual:@"number"]) {
        UILabel* current = [UILabel new];
        current.text = numberLabel(item);
        current.font = NeonUI(16);
        current.textColor = NeonMuted();
        UIStepper* stepper = [UIStepper new];
        stepper.minimumValue = [item[@"min"] doubleValue];
        stepper.maximumValue = [item[@"max"] doubleValue];
        stepper.stepValue = [item[@"step"] doubleValue];
        stepper.value = [value(item) doubleValue];
        stepper.accessibilityIdentifier = key;
        stepper.accessibilityLabel = item[@"title"];
        stepper.accessibilityValue = numberLabel(item);
        __weak NeonSettingsController* weakSelf = self;
        __weak UIStepper* weakStepper = stepper;
        [stepper addAction:[UIAction actionWithHandler:^(UIAction* action) {
                   (void)action;
                   [NSUserDefaults.standardUserDefaults setDouble:weakStepper.value forKey:key];
                   current.text = numberLabel(item);
                   weakStepper.accessibilityValue = current.text;
                   [weakSelf changed];
                 }]
            forControlEvents:UIControlEventValueChanged];
        UIStackView* row = [[UIStackView alloc] initWithArrangedSubviews:@[ current, stepper ]];
        row.distribution = UIStackViewDistributionEqualSpacing;
        [stack addArrangedSubview:row];
    } else if ([kind isEqual:@"font"]) {
        __weak NeonSettingsController* weakSelf = self;
        for (NSString* name in @[ @"Literata", @"Source Sans 3", @"System Serif" ]) {
            UIButton* font = [UIButton buttonWithType:UIButtonTypeSystem];
            [font setTitle:[NSString stringWithFormat:@"%@  %@", name,
                                                      [NeonFontChoice() isEqual:name] ? @"✓" : @""]
                  forState:UIControlStateNormal];
            font.titleLabel.font = NeonFontNamed(name, 20);
            font.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
            font.accessibilityLabel = name;
            font.accessibilityTraits |=
                [NeonFontChoice() isEqual:name] ? UIAccessibilityTraitSelected : 0;
            [font.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
            [font addAction:[UIAction actionWithHandler:^(UIAction* action) {
                    (void)action;
                    [NSUserDefaults.standardUserDefaults setObject:name forKey:@"manuscriptFont"];
                    [weakSelf changed];
                    [weakSelf.tableView reloadData];
                  }]
                forControlEvents:UIControlEventTouchUpInside];
            [stack addArrangedSubview:font];
        }
    } else {
        UISegmentedControl* control =
            [[UISegmentedControl alloc] initWithItems:@[ @"System", @"Light", @"Dark" ]];
        control.selectedSegmentIndex = NeonAppearance();
        control.accessibilityLabel = @"Appearance";
        [control addTarget:self
                      action:@selector(appearance:)
            forControlEvents:UIControlEventValueChanged];
        [stack addArrangedSubview:control];
    }
    if (item[@"detail"]) {
        UILabel* detail = [UILabel new];
        detail.text = item[@"detail"];
        detail.font = NeonUI(13);
        detail.textColor = NeonMuted();
        detail.numberOfLines = 0;
        [stack addArrangedSubview:detail];
    }
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
        [stack.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:12],
        [stack.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-12]
    ]];
    return cell;
}
- (void)toggle:(UISwitch*)sender {
    [NSUserDefaults.standardUserDefaults setBool:sender.on forKey:sender.accessibilityIdentifier];
    [self changed];
}
- (void)appearance:(UISegmentedControl*)sender {
    [NSUserDefaults.standardUserDefaults setInteger:sender.selectedSegmentIndex
                                             forKey:@"appearance"];
    [self changed];
}
- (void)changed {
    self.overrideUserInterfaceStyle = NeonAppearance() == 1   ? UIUserInterfaceStyleLight
                                      : NeonAppearance() == 2 ? UIUserInterfaceStyleDark
                                                              : UIUserInterfaceStyleUnspecified;
    self.navigationController.overrideUserInterfaceStyle = self.overrideUserInterfaceStyle;
    if (self.preferencesChanged)
        self.preferencesChanged();
}
- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)path {
    (void)tableView;
    if (path.section != 2)
        return;
    UIAlertController* alert = [UIAlertController
        alertControllerWithTitle:@"Reset device preferences?"
                         message:@"Reset editor typography, writing assistance and appearance on "
                                 @"this device. Your documents are unchanged."
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    __weak NeonSettingsController* weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction* action) {
                                              (void)action;
                                              reset();
                                              [weakSelf changed];
                                              [weakSelf.tableView reloadData];
                                            }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)done {
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
#else
@interface NeonSettingsToggle : NSButton
@end
@implementation NeonSettingsToggle
- (NSSize)intrinsicContentSize {
    return NSMakeSize(38, 24);
}
- (void)drawRect:(NSRect)rect {
    (void)rect;
    NSRect track = NSInsetRect(self.bounds, 1, 2);
    [(self.state == NSControlStateValueOn ? NeonAccent()
                                          : [NeonMuted() colorWithAlphaComponent:0.4]) setFill];
    [[NSBezierPath bezierPathWithRoundedRect:track xRadius:10 yRadius:10] fill];
    [NeonPaper() setFill];
    CGFloat x = self.state == NSControlStateValueOn ? NSMaxX(track) - 18 : NSMinX(track) + 2;
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(x, NSMinY(track) + 2, 16, 16)] fill];
}
@end
@interface NeonSettingsColumn : NSStackView
@end
@implementation NeonSettingsColumn
- (BOOL)isFlipped {
    return YES;
}
@end
namespace {
NSTextField* caption(NSString* text, NSFont* font, NSColor* color) {
    NSTextField* field = [NSTextField wrappingLabelWithString:text];
    field.font = font;
    field.textColor = color;
    return field;
}
NSStackView* vertical(NSArray<NSView*>* children, CGFloat spacing) {
    NeonSettingsColumn* stack = [[NeonSettingsColumn alloc] initWithFrame:NSZeroRect];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = spacing;
    for (NSView* child in children)
        [stack addArrangedSubview:child];
    return stack;
}
} // namespace
@interface NeonSettingsController ()
@property(nonatomic, strong) NSSearchField* search;
@property(nonatomic, strong) NSScrollView* scroll;
@property(nonatomic, strong) NSArray<NSDictionary*>* visibleSettings;
@end
@implementation NeonSettingsController
- (void)loadView {
    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 580, 660)];
    self.search = [[NSSearchField alloc] initWithFrame:NSZeroRect];
    self.search.placeholderString = @"Search settings";
    self.search.delegate = self;
    self.search.accessibilityLabel = @"Search settings";
    self.scroll = [NSScrollView new];
    self.scroll.drawsBackground = NO;
    self.scroll.hasVerticalScroller = YES;
    self.scroll.autohidesScrollers = YES;
    NSTextField* scope =
        caption(@"Personal editor preferences · This Mac", NeonUI(13), NeonMuted());
    for (NSView* child in @[ self.search, scope, self.scroll ]) {
        child.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:child];
    }
    [NSLayoutConstraint activateConstraints:@[
        [self.search.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [self.search.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [self.search.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:20],
        [scope.leadingAnchor constraintEqualToAnchor:self.search.leadingAnchor],
        [scope.topAnchor constraintEqualToAnchor:self.search.bottomAnchor constant:12],
        [self.scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scroll.topAnchor constraintEqualToAnchor:scope.bottomAnchor constant:12],
        [self.scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    [self filterSettings:@""];
}
- (NSUInteger)visibleSettingCount {
    return self.visibleSettings.count;
}
- (void)controlTextDidChange:(NSNotification*)note {
    if (note.object == self.search)
        [self filterSettings:self.search.stringValue];
}
- (void)filterSettings:(NSString*)query {
    self.visibleSettings = matches(query);
    NSMutableArray* rows = [NSMutableArray array];
    NSString* category = @"";
    for (NSDictionary* item in self.visibleSettings) {
        if (![category isEqual:item[@"category"]]) {
            category = item[@"category"];
            [rows addObject:caption(category, NeonSerif(25), NeonInk())];
        }
        NSMutableArray* labels =
            [NSMutableArray arrayWithObject:caption(item[@"title"], NeonUI(16), NeonInk())];
        if (item[@"detail"])
            [labels addObject:caption(item[@"detail"], NeonUI(12), NeonMuted())];
        NSStackView* text = vertical(labels, 5);
        [text.widthAnchor constraintEqualToConstant:260].active = YES;
        NSView* control;
        NSString* kind = item[@"kind"];
        if ([kind isEqual:@"toggle"]) {
            NeonSettingsToggle* toggle = [NeonSettingsToggle new];
            toggle.buttonType = NSButtonTypeSwitch;
            toggle.state = [value(item) boolValue] ? NSControlStateValueOn : NSControlStateValueOff;
            toggle.target = self;
            toggle.action = @selector(toggle:);
            toggle.identifier = item[@"key"];
            toggle.accessibilityLabel = item[@"title"];
            control = toggle;
        } else if ([kind isEqual:@"number"]) {
            NSTextField* number = caption(numberLabel(item), NeonUI(15), NeonMuted());
            [number.widthAnchor constraintEqualToConstant:70].active = YES;
            NSStepper* stepper = [NSStepper new];
            stepper.minValue = [item[@"min"] doubleValue];
            stepper.maxValue = [item[@"max"] doubleValue];
            stepper.increment = [item[@"step"] doubleValue];
            stepper.doubleValue = [value(item) doubleValue];
            stepper.identifier = item[@"key"];
            stepper.accessibilityLabel = item[@"title"];
            stepper.target = self;
            stepper.action = @selector(number:);
            control = [NSStackView stackViewWithViews:@[ number, stepper ]];
        } else if ([kind isEqual:@"font"]) {
            NSPopUpButton* font = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
            [font addItemsWithTitles:@[ @"Literata", @"Source Sans 3", @"System Serif" ]];
            for (NSMenuItem* entry in font.itemArray)
                entry.attributedTitle = [[NSAttributedString alloc]
                    initWithString:entry.title
                        attributes:@{NSFontAttributeName : NeonFontNamed(entry.title, 16)}];
            [font selectItemWithTitle:NeonFontChoice()];
            font.target = self;
            font.action = @selector(font:);
            font.accessibilityLabel = @"Editor font";
            control = font;
        } else {
            NSSegmentedControl* appearance =
                [NSSegmentedControl segmentedControlWithLabels:@[ @"System", @"Light", @"Dark" ]
                                                  trackingMode:NSSegmentSwitchTrackingSelectOne
                                                        target:self
                                                        action:@selector(appearance:)];
            appearance.selectedSegment = NeonAppearance();
            appearance.selectedSegmentBezelColor = NeonAccent();
            control = appearance;
        }
        NSStackView* row = [NSStackView stackViewWithViews:@[ text, control ]];
        row.spacing = 24;
        [rows addObject:row];
    }
    if (!rows.count)
        [rows addObject:caption(@"No settings found. Try “font”, “spacing” or “appearance”.",
                                NeonUI(16), NeonMuted())];
    if (!query.length) {
        [rows addObject:caption(@"Document content and export styles are unchanged.", NeonUI(13),
                                NeonMuted())];
        NSButton* resetButton = [NSButton buttonWithTitle:@"Reset Device Preferences…"
                                                   target:self
                                                   action:@selector(resetPreferences:)];
        resetButton.bezelStyle = NSBezelStyleRounded;
        [rows addObject:resetButton];
    }
    NSStackView* stack = vertical(rows, 24);
    stack.edgeInsets = NSEdgeInsetsMake(16, 24, 24, 24);
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    self.scroll.documentView = stack;
    [stack.widthAnchor constraintEqualToAnchor:self.scroll.contentView.widthAnchor].active = YES;
}
- (void)changed {
    self.view.window.appearance =
        NeonAppearance() == 1   ? [NSAppearance appearanceNamed:NSAppearanceNameAqua]
        : NeonAppearance() == 2 ? [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]
                                : nil;
    self.view.window.backgroundColor = NeonPanel();
    if (self.preferencesChanged)
        self.preferencesChanged();
}
- (void)toggle:(NeonSettingsToggle*)sender {
    [NSUserDefaults.standardUserDefaults setBool:sender.state == NSControlStateValueOn
                                          forKey:sender.identifier];
    [self changed];
}
- (void)number:(NSStepper*)sender {
    [NSUserDefaults.standardUserDefaults setDouble:sender.doubleValue forKey:sender.identifier];
    for (NSDictionary* item in settings())
        if ([item[@"key"] isEqual:sender.identifier]) {
            NSTextField* label = (id)((NSStackView*)sender.superview).arrangedSubviews.firstObject;
            label.stringValue = numberLabel(item);
            break;
        }
    [self changed];
}
- (void)font:(NSPopUpButton*)sender {
    [NSUserDefaults.standardUserDefaults setObject:sender.titleOfSelectedItem
                                            forKey:@"manuscriptFont"];
    [self changed];
}
- (void)appearance:(NSSegmentedControl*)sender {
    [NSUserDefaults.standardUserDefaults setInteger:sender.selectedSegment forKey:@"appearance"];
    [self changed];
}
- (void)resetPreferences:(id)sender {
    (void)sender;
    NSAlert* alert = [NSAlert new];
    alert.messageText = @"Reset device preferences?";
    alert.informativeText = @"Reset editor typography, writing assistance and appearance on this "
                            @"Mac. Your documents are unchanged.";
    [alert addButtonWithTitle:@"Reset"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert beginSheetModalForWindow:self.view.window
                  completionHandler:^(NSModalResponse response) {
                    if (response != NSAlertFirstButtonReturn)
                        return;
                    reset();
                    [self changed];
                    [self filterSettings:self.search.stringValue];
                  }];
}
@end
#endif
