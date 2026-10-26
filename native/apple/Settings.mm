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
            @"title" : @"Text column width",
            @"category" : @"Writing",
            @"kind" : @"number",
            @"min" : @480,
            @"max" : @960,
            @"step" : @40,
            @"default" : @760,
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
            @"detail" : @"Follow your device, or choose a palette for writing"
        },
        @{
            @"key" : @"liquidGlass",
            @"title" : @"Liquid Glass",
            @"category" : @"Appearance",
            @"kind" : @"toggle",
            @"default" : @YES,
            @"detail" : @"Translucent navigation and controls; respects reduced transparency"
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
            @"detail" :
                @"Use short fades instead of movement. Device accessibility settings also apply."
        },
        @{
            @"key" : @"reduceTransparency",
            @"title" : @"Reduce transparency",
            @"category" : @"Accessibility",
            @"kind" : @"toggle",
            @"default" : @NO,
            @"detail" : @"Use opaque surfaces for clearer contrast. Device accessibility settings "
                        @"also apply."
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

#if TARGET_OS_IPHONE
@interface NeonSettingsController ()
@property(nonatomic, strong) NSArray<NSDictionary*>* visibleSettings;
@property(nonatomic, strong) UISearchController* search;
@property(nonatomic) BOOL regularRows;
@end
@implementation NeonSettingsController
- (instancetype)init {
    return [super initWithStyle:UITableViewStyleGrouped];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Settings";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.navigationController.navigationBar.tintColor = NeonAccent();
    self.view.backgroundColor = NeonPaper();
    self.tableView.tintColor = NeonAccent();
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 82;
    self.visibleSettings = settings();
    UIView* intro = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 118)];
    UILabel* heading = [[UILabel alloc] initWithFrame:CGRectMake(20, 16, 280, 44)];
    heading.text = @"Your writing, your way.";
    heading.font = NeonSerif(25);
    heading.adjustsFontSizeToFitWidth = YES;
    heading.minimumScaleFactor = 0.8;
    heading.textColor = NeonInk();
    heading.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UILabel* detail = [[UILabel alloc] initWithFrame:CGRectMake(20, 65, 280, 40)];
    detail.text = @"Changes apply immediately on this device.";
    detail.numberOfLines = 2;
    detail.font = NeonUI(14);
    detail.textColor = NeonMuted();
    detail.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [intro addSubview:heading];
    [intro addSubview:detail];
    self.tableView.tableHeaderView = intro;
    self.search = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.search.searchResultsUpdater = self;
    self.search.obscuresBackgroundDuringPresentation = NO;
    self.search.searchBar.placeholder = @"Search settings";
    self.navigationItem.searchController = self.search;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Done"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(done)];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    BOOL regular = self.view.bounds.size.width >= 600;
    if (regular != self.regularRows) {
        self.regularRows = regular;
        [self.tableView reloadData];
    }
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
    return 5;
}
- (NSArray*)itemsForSection:(NSInteger)section {
    NSString* category = @[ @"Appearance", @"Writing", @"History", @"Accessibility" ][section];
    return [self.visibleSettings
        filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"category == %@", category]];
}
- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    if (section == 4)
        return self.search.searchBar.text.length ? 0 : 1;
    return [self itemsForSection:section].count +
           (section == 2 && self.showHistory && !self.search.searchBar.text.length ? 1 : 0);
}
- (NSString*)tableView:(UITableView*)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView;
    if (section == 4 || ![self itemsForSection:section].count)
        return nil;
    return @[ @"Appearance", @"Writing", @"History", @"Accessibility" ][section];
}
- (void)tableView:(UITableView*)tableView
    willDisplayHeaderView:(UIView*)view
               forSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    if ([view isKindOfClass:UITableViewHeaderFooterView.class]) {
        UITableViewHeaderFooterView* header = (UITableViewHeaderFooterView*)view;
        header.textLabel.font = NeonUI(13);
        header.textLabel.textColor = NeonMuted();
    }
}
- (NSString*)tableView:(UITableView*)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    if (section == 4)
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
    if (path.section == 4) {
        cell.textLabel.text = @"Reset Device Preferences…";
        cell.textLabel.textColor = NeonAccent();
        cell.accessibilityTraits = UIAccessibilityTraitButton;
        return cell;
    }
    if (path.section == 2 && path.row == (NSInteger)[self itemsForSection:2].count) {
        cell.textLabel.text = @"Browse version history →";
        cell.textLabel.font = NeonUI(17);
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
                   [NeonPreferences() setDouble:weakStepper.value forKey:key];
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
        UIButton* font = [UIButton buttonWithType:UIButtonTypeSystem];
        [font setTitle:[NeonFontChoice() stringByAppendingString:@" ▾"]
              forState:UIControlStateNormal];
        font.titleLabel.font = NeonUI(16);
        font.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
        font.accessibilityLabel = @"Editor font";
        font.showsMenuAsPrimaryAction = YES;
        [font.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
        NSMutableArray* choices = [NSMutableArray array];
        for (NSString* name in @[ @"Literata", @"Source Sans 3", @"System Serif" ]) {
            UIAction* choice = [UIAction actionWithTitle:name
                                                   image:nil
                                              identifier:nil
                                                 handler:^(UIAction*) {
                                                   [NeonPreferences() setObject:name
                                                                         forKey:@"manuscriptFont"];
                                                   [weakSelf changed];
                                                   [weakSelf.tableView reloadData];
                                                 }];
            choice.state =
                [NeonFontChoice() isEqual:name] ? UIMenuElementStateOn : UIMenuElementStateOff;
            [choices addObject:choice];
        }
        font.menu = [UIMenu menuWithChildren:choices];
        [stack addArrangedSubview:font];
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
    UIStackView* content = stack;
    if (self.view.bounds.size.width >= 600 && ![kind isEqual:@"toggle"]) {
        UIView* control = stack.arrangedSubviews[1];
        [stack removeArrangedSubview:control];
        [control removeFromSuperview];
        content = [[UIStackView alloc] initWithArrangedSubviews:@[ stack, control ]];
        content.axis = UILayoutConstraintAxisHorizontal;
        content.alignment = UIStackViewAlignmentCenter;
        content.spacing = 24;
        [control.widthAnchor constraintEqualToConstant:220].active = YES;
    }
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [cell.contentView addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
        [content.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor
                                               constant:-16],
        [content.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:12],
        [content.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-12]
    ]];
    return cell;
}
- (void)toggle:(UISwitch*)sender {
    [NeonPreferences() setBool:sender.on forKey:sender.accessibilityIdentifier];
    [self changed];
}
- (void)appearance:(UISegmentedControl*)sender {
    [NeonPreferences() setInteger:sender.selectedSegmentIndex forKey:@"appearance"];
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
    if (path.section == 2 && path.row == (NSInteger)[self itemsForSection:2].count &&
        self.showHistory) {
        self.showHistory();
        return;
    }
    if (path.section != 4)
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
@interface NeonSettingsPaper : NSView
@end
@implementation NeonSettingsPaper
- (BOOL)wantsDefaultClipping {
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
    [field setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                    forOrientation:NSLayoutConstraintOrientationVertical];
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
    self.view = [[NeonSettingsPaper alloc] initWithFrame:NSMakeRect(0, 0, 580, 660)];
    self.search = [[NSSearchField alloc] initWithFrame:NSZeroRect];
    self.search.placeholderString = @"Search settings";
    self.search.delegate = self;
    self.search.accessibilityLabel = @"Search settings";
    self.scroll = [NSScrollView new];
    self.scroll.drawsBackground = NO;
    self.scroll.hasVerticalScroller = YES;
    self.scroll.autohidesScrollers = YES;
    NSTextField* heading = caption(@"Your writing, your way.", NeonSerif(28), NeonInk());
    NSTextField* scope =
        caption(@"Personalize your writing space · Changes apply immediately on this Mac",
                NeonUI(13), NeonMuted());
    for (NSView* child in @[ heading, self.search, scope, self.scroll ]) {
        child.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:child];
    }
    [NSLayoutConstraint activateConstraints:@[
        [self.search.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [self.search.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [heading.leadingAnchor constraintEqualToAnchor:self.search.leadingAnchor],
        [heading.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:24],
        [heading.trailingAnchor constraintEqualToAnchor:self.search.trailingAnchor],
        [self.search.topAnchor constraintEqualToAnchor:heading.bottomAnchor constant:16],
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
    NSMutableArray* ordered = [NSMutableArray array];
    for (NSString* group in @[ @"Appearance", @"Writing", @"History", @"Accessibility" ])
        for (NSDictionary* item in self.visibleSettings)
            if ([item[@"category"] isEqual:group])
                [ordered addObject:item];
    for (NSDictionary* item in ordered) {
        if (![category isEqual:item[@"category"]]) {
            category = item[@"category"];
            [rows addObject:caption(category, NeonUI(13), NeonMuted())];
        }
        NSMutableArray* labels =
            [NSMutableArray arrayWithObject:caption(item[@"title"], NeonUI(16), NeonInk())];
        if (item[@"detail"])
            [labels addObject:caption(item[@"detail"], NeonUI(12), NeonMuted())];
        NSStackView* text = vertical(labels, 5);
        [text.widthAnchor constraintLessThanOrEqualToConstant:640].active = YES;
        [text.widthAnchor constraintGreaterThanOrEqualToConstant:100].active = YES;
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
        NSView* spacer = [NSView new];
        spacer.identifier = @"settingsSpacer";
        [spacer setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
        [spacer.widthAnchor constraintGreaterThanOrEqualToConstant:0].active = YES;
        NSStackView* row = [NSStackView stackViewWithViews:@[ text, spacer, control ]];
        row.identifier = @"settingsRow";
        row.spacing = 16;
        row.edgeInsets = NSEdgeInsetsMake(14, 16, 14, 16);
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:64].active = YES;
        [row setContentCompressionResistancePriority:NSLayoutPriorityRequired
                                      forOrientation:NSLayoutConstraintOrientationVertical];
        NSBox* divider = [NSBox new];
        divider.boxType = NSBoxSeparator;
        divider.translatesAutoresizingMaskIntoConstraints = NO;
        [row addSubview:divider];
        [NSLayoutConstraint activateConstraints:@[
            [divider.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
            [divider.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
            [divider.bottomAnchor constraintEqualToAnchor:row.bottomAnchor]
        ]];
        [rows addObject:row];
        if ([item[@"key"] isEqual:@"automaticCheckpoints"] && self.showHistory) {
            NSButton* history = [NSButton buttonWithTitle:@"Browse version history →"
                                                   target:self
                                                   action:@selector(browseHistory:)];
            history.font = NeonUI(15);
            [rows addObject:history];
        }
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
    NSStackView* stack = vertical(rows, 12);
    stack.edgeInsets = NSEdgeInsetsMake(16, 24, 24, 24);
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    self.scroll.documentView = stack;
    [stack.widthAnchor constraintEqualToAnchor:self.scroll.contentView.widthAnchor].active = YES;
    for (NSView* row in rows)
        if ([row.identifier isEqual:@"settingsRow"])
            [row.widthAnchor constraintEqualToAnchor:stack.widthAnchor constant:-48].active = YES;
    [self layoutSettingRows];
}
- (void)viewDidLayout {
    [super viewDidLayout];
    [self layoutSettingRows];
}
- (void)layoutSettingRows {
    BOOL narrow = self.view.bounds.size.width < 560;
    for (NSView* view in ((NSStackView*)self.scroll.documentView).arrangedSubviews) {
        if (![view.identifier isEqual:@"settingsRow"])
            continue;
        NSStackView* row = (NSStackView*)view;
        row.orientation = narrow ? NSUserInterfaceLayoutOrientationVertical
                                 : NSUserInterfaceLayoutOrientationHorizontal;
        row.alignment = narrow ? NSLayoutAttributeLeading : NSLayoutAttributeCenterY;
        for (NSView* child in row.arrangedSubviews)
            if ([child.identifier isEqual:@"settingsSpacer"])
                child.hidden = narrow;
    }
}
- (void)browseHistory:(id)sender {
    (void)sender;
    if (self.showHistory)
        self.showHistory();
}
- (void)changed {
    self.view.window.appearance =
        NeonAppearance() == 1   ? [NSAppearance appearanceNamed:NSAppearanceNameAqua]
        : NeonAppearance() == 2 ? [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]
                                : nil;
    self.view.window.backgroundColor = NeonPaper();
    self.view.needsDisplay = YES;
    if (self.preferencesChanged)
        self.preferencesChanged();
}
- (void)toggle:(NeonSettingsToggle*)sender {
    [NeonPreferences() setBool:sender.state == NSControlStateValueOn forKey:sender.identifier];
    [self changed];
}
- (void)number:(NSStepper*)sender {
    [NeonPreferences() setDouble:sender.doubleValue forKey:sender.identifier];
    for (NSDictionary* item in settings())
        if ([item[@"key"] isEqual:sender.identifier]) {
            NSTextField* label = (id)((NSStackView*)sender.superview).arrangedSubviews.firstObject;
            label.stringValue = numberLabel(item);
            break;
        }
    [self changed];
}
- (void)font:(NSPopUpButton*)sender {
    [NeonPreferences() setObject:sender.titleOfSelectedItem forKey:@"manuscriptFont"];
    [self changed];
}
- (void)appearance:(NSSegmentedControl*)sender {
    [NeonPreferences() setInteger:sender.selectedSegment forKey:@"appearance"];
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
