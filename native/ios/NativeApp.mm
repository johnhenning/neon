#import "ContextMenu.h"
#import "EditorialTheme.h"
#import "History.h"
#import "InlineTitle.h"
#import "LibraryStore.h"
#import "Settings.h"
#import <UIKit/UIKit.h>

@class NeonCoordinator;
@interface NeonEditor : UIViewController <UITextViewDelegate>
@property(nonatomic, strong) UITextView* editor;
@property(nonatomic, strong) UILabel* status;
@property(nonatomic, strong) UILabel* guidance;
@property(nonatomic, strong) NeonInlineTitle* heading;
@property(nonatomic, strong) NeonInlineTitle* bookTitle;
@property(nonatomic, strong) NeonDocumentSession* session;
@property(nonatomic, weak) NeonCoordinator* coordinator;
@property(nonatomic, strong) NSTimer* saveTimer;
- (BOOL)flush;
- (void)applyTypography;
@end
@interface NeonList : UITableViewController
@property(nonatomic, weak) NeonCoordinator* coordinator;
@property(nonatomic) BOOL chapters;
@end
@interface NeonTypography : UIViewController <UIPopoverPresentationControllerDelegate>
@property(nonatomic, weak) NeonEditor* editor;

@end
@interface NeonCoordinator : UISplitViewController <UISplitViewControllerDelegate>
@property(nonatomic, strong) NeonLibraryStore* library;
@property(nonatomic, strong) NSArray<NSDictionary*>* projects;
@property(nonatomic, strong) NeonDocumentSession* session;
@property(nonatomic, strong) NSURL* selectedURL;
@property(nonatomic, strong) NeonEditor* editor;
@property(nonatomic, strong) NeonList* libraryList;
@property(nonatomic, strong) NeonList* chapterList;
@property(nonatomic, strong) UINavigationController* navigation;
@property(nonatomic) BOOL sidebarHidden;
@property(nonatomic, copy) NSString* pendingPreset;
@property(nonatomic) BOOL smoke;
@property(nonatomic) BOOL trashMode;
- (void)showLibrary;
- (void)showTrash;
- (void)projectMenu:(NSInteger)index
               host:(UIViewController*)host
             anchor:(UIView*)anchor
               rect:(CGRect)rect;
- (void)sectionMenu:(NSInteger)index
               host:(UIViewController*)host
             anchor:(UIView*)anchor
               rect:(CGRect)rect;
- (void)sectionCommand:(NSString*)command identifier:(NSString*)identifier;
- (void)projectCommand:(NSString*)command url:(NSURL*)url title:(NSString*)title;
- (void)showSectionTrash:(UIViewController*)host anchor:(UIView*)anchor;

- (void)reloadLibrary;
- (void)openProject:(NSInteger)index;
- (void)openSection:(NSInteger)index;
- (void)newProject;
- (void)newSection;
- (void)toggleChapters;
- (void)showProblem:(NSError*)error;
- (void)applyAppearance;
- (void)showSettings;
- (void)showHistory;
- (BOOL)renameInline:(NSString*)title section:(NSString*)identifier;
@end
namespace {
UIFont* scaledSerif(CGFloat size) {
    return
        [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody] scaledFontForFont:NeonSerif(size)];
}
UILabel* label(NSString* text, UIFont* font, UIColor* color) {
    UILabel* label = [UILabel new];
    label.text = text;
    label.font = font;
    label.textColor = color;
    label.numberOfLines = 0;
    label.adjustsFontForContentSizeCategory = YES;
    return label;
}
UIView* settingControl(UIView* root, NSString* identifier) {
    if ([root.accessibilityIdentifier isEqual:identifier])
        return root;
    for (UIView* child in root.subviews) {
        UIView* match = settingControl(child, identifier);
        if (match)
            return match;
    }
    return nil;
}
NSUInteger wordCount(NSString* text) {
    __block NSUInteger count = 0;
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                             options:NSStringEnumerationByWords
                          usingBlock:^(NSString*, NSRange, NSRange, BOOL*) {
                            ++count;
                          }];
    return count;
}
UIImage* cover(NSString* title) {
    UIGraphicsImageRenderer* renderer =
        [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(88, 124)];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext* context) {
      (void)context;
      [[UIColor colorWithRed:0.86 green:0.83 blue:0.76 alpha:1] setFill];
      UIRectFill(CGRectMake(0, 0, 88, 124));
      [[UIColor colorWithRed:0.25 green:0.39 blue:0.42 alpha:1] setFill];
      UIRectFill(CGRectMake(0, 88, 88, 36));
      [[UIColor colorWithRed:0.13 green:0.26 blue:0.29 alpha:1] setFill];
      [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(-10, 105, 120, 40)] fill];
      [title drawInRect:CGRectMake(10, 14, 68, 72)
          withAttributes:@{
              NSFontAttributeName : NeonSerif(14),
              NSForegroundColorAttributeName : UIColor.blackColor
          }];
    }];
}
void marker(NSURL* directory, NSString* name, BOOL pass) {
    [(pass ? @"PASS" : @"FAIL") writeToURL:[directory URLByAppendingPathComponent:name]
                                atomically:YES
                                  encoding:NSUTF8StringEncoding
                                     error:nil];
}
} // namespace
@implementation NeonEditor
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.session.title;
    __weak NeonEditor* weakSelf = self;
    self.bookTitle = [[NeonInlineTitle alloc] initWithFrame:CGRectMake(0, 0, 180, 36)];
    self.bookTitle.text = self.session.title;
    self.bookTitle.font = NeonUI(18);
    self.bookTitle.textAlignment = NSTextAlignmentCenter;
    self.bookTitle.accessibilityLabel = @"Project title";
    self.bookTitle.commitTitle = ^BOOL(NSString* title) {
      return [weakSelf.coordinator renameInline:title section:nil];
    };
    self.navigationItem.titleView = self.bookTitle;
    self.view.backgroundColor = NeonPaper();
    self.view.tintColor = NeonAccent();
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"sidebar.left"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(chapters)];
    self.navigationItem.leftBarButtonItem.title = self.session.preset[@"sectionsLabel"];
    self.navigationItem.leftBarButtonItem.accessibilityLabel =
        [@"Show or hide " stringByAppendingString:self.session.preset[@"sectionsLabel"]];
    UIBarButtonItem* typography =
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"textformat"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(typography)];
    typography.accessibilityLabel = @"Typography";
    self.navigationItem.rightBarButtonItems = @[
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(actions)],
        typography
    ];
    NSUInteger number =
        [self.session.sections
            indexOfObjectPassingTest:^BOOL(NSDictionary* item, NSUInteger i, BOOL* stop) {
              (void)i;
              (void)stop;
              return [item[@"id"] isEqual:self.session.selectedSectionID];
            }] +
        1;
    UILabel* kicker = label(self.session.sections.count
                                ? [[self.session sectionLabelAtIndex:number - 1] uppercaseString]
                                : [self.session.preset[@"documentLabel"] uppercaseString],
                            NeonUI(12), NeonMuted());
    kicker.textAlignment = [self.session.preset[@"centeredHeading"] boolValue]
                               ? NSTextAlignmentCenter
                               : NSTextAlignmentLeft;
    self.heading = [NeonInlineTitle new];
    self.heading.text = self.session.sectionTitle;
    self.heading.font = scaledSerif(32);
    self.heading.adjustsFontForContentSizeCategory = YES;
    self.heading.accessibilityLabel =
        [self.session.preset[@"sectionLabel"] stringByAppendingString:@" title"];
    NSString* identifier = self.session.selectedSectionID;
    if (identifier.length)
        self.heading.commitTitle = ^BOOL(NSString* title) {
          return [weakSelf.coordinator renameInline:title section:identifier];
        };
    self.heading.textAlignment = kicker.textAlignment;
    UIView* rule = [UIView new];
    rule.backgroundColor = [NeonAccent() colorWithAlphaComponent:0.5];
    NSMutableArray* headerViews = [NSMutableArray arrayWithArray:@[ kicker, self.heading, rule ]];
    if (!self.session.text.length && self.session.sectionGuidance.length) {
        self.guidance = label(self.session.sectionGuidance, NeonUI(12), NeonMuted());
        [headerViews addObject:self.guidance];
    }
    UIStackView* header = [[UIStackView alloc] initWithArrangedSubviews:headerViews];
    header.axis = UILayoutConstraintAxisVertical;
    header.alignment = UIStackViewAlignmentCenter;
    header.spacing = 20;
    [self.heading.widthAnchor constraintEqualToAnchor:header.widthAnchor].active = YES;
    [kicker.widthAnchor constraintEqualToAnchor:header.widthAnchor].active = YES;
    if (self.guidance)
        [self.guidance.widthAnchor constraintEqualToAnchor:header.widthAnchor].active = YES;
    self.editor = [UITextView new];
    self.editor.delegate = self;
    self.editor.backgroundColor = NeonPaper();
    self.editor.textColor = NeonInk();
    self.editor.text = self.session.text;
    self.editor.editable = self.session.selectedSectionID.length > 0;
    self.editor.accessibilityLabel = self.session.preset[@"documentLabel"];
    self.editor.accessibilityIdentifier = @"manuscript";
    self.editor.adjustsFontForContentSizeCategory = YES;
    self.editor.textContainer.lineFragmentPadding = 0;
    self.status = label(@"Saved on this device", NeonUI(13), NeonMuted());
    self.status.accessibilityIdentifier = @"saveStatus";
    for (UIView* view in @[ header, self.editor, self.status ]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:view];
    }
    UILayoutGuide* safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:safe.topAnchor constant:54],
        [header.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:24],
        [header.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-24],
        [rule.widthAnchor constraintEqualToConstant:130],
        [rule.heightAnchor constraintEqualToConstant:1],
        [self.editor.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:28],
        [self.editor.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [self.editor.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [self.editor.bottomAnchor constraintEqualToAnchor:self.status.topAnchor constant:-8],
        [self.status.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:24],
        [self.status.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-24],
        [self.status.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor
                                                 constant:-10]
    ]];
    [self applyTypography];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat margin = MAX(24, (self.editor.bounds.size.width - NeonTextMeasure()) / 2);
    self.editor.textContainerInset = UIEdgeInsetsMake(12, margin, 30, margin);
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self flush];
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;
}
- (void)applyTypography {
    if (!self.editor || self.editor.markedTextRange)
        return;
    NSRange selection = self.editor.selectedRange;
    NSMutableParagraphStyle* style = [NSMutableParagraphStyle new];
    style.lineSpacing = NeonLineSpacing();
    style.paragraphSpacing = [NSUserDefaults.standardUserDefaults objectForKey:@"paragraphSpacing"]
                                 ? NeonParagraphSpacing()
                                 : [self.session.preset[@"paragraphSpacing"] doubleValue];
    style.lineHeightMultiple = [self.session.preset[@"lineHeightMultiple"] doubleValue];
    style.firstLineHeadIndent = [self.session.preset[@"firstLineIndent"] doubleValue];
    for (NSDictionary* section in self.session.sections)
        if ([section[@"id"] isEqual:self.session.selectedSectionID] &&
            [section[@"role"] isEqual:@"references"]) {
            style.firstLineHeadIndent = 0;
            style.headIndent = 24;
        }
    self.editor.spellCheckingType = NeonWritingPreference(@"spellcheck")
                                        ? UITextSpellCheckingTypeYes
                                        : UITextSpellCheckingTypeNo;
    self.editor.smartQuotesType =
        NeonWritingPreference(@"smartQuotes") ? UITextSmartQuotesTypeYes : UITextSmartQuotesTypeNo;
    self.editor.smartDashesType =
        NeonWritingPreference(@"smartDashes") ? UITextSmartDashesTypeYes : UITextSmartDashesTypeNo;
    [self.view setNeedsLayout];
    NSDictionary* attrs = @{
        NSFontAttributeName : [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
            scaledFontForFont:([NSUserDefaults.standardUserDefaults objectForKey:@"manuscriptFont"]
                                   ? NeonManuscriptFont(NeonTextSize())
                                   : NeonFontNamed(self.session.preset[@"font"], NeonTextSize()))],
        NSForegroundColorAttributeName : NeonInk(),
        NSParagraphStyleAttributeName : style
    };
    [self.editor.textStorage addAttributes:attrs range:NSMakeRange(0, self.editor.text.length)];
    self.editor.typingAttributes = attrs;
    self.editor.selectedRange = selection;
    self.editor.font = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:([NSUserDefaults.standardUserDefaults objectForKey:@"manuscriptFont"]
                               ? NeonManuscriptFont(NeonTextSize())
                               : NeonFontNamed(self.session.preset[@"font"], NeonTextSize()))];
}
- (void)textViewDidChange:(UITextView*)view {
    if (view.markedTextRange)
        return;
    NSError* error = nil;
    if (![self.session replaceText:view.text error:&error]) {
        self.status.text = error.localizedDescription;
        return;
    }
    self.guidance.hidden = view.text.length > 0;
    self.status.text = @"Unsaved changes";
    [self.saveTimer invalidate];
    __weak NeonEditor* weakSelf = self;
    self.saveTimer = [NSTimer scheduledTimerWithTimeInterval:0.6
                                                     repeats:NO
                                                       block:^(NSTimer* timer) {
                                                         (void)timer;
                                                         [weakSelf flush];
                                                       }];
}
- (BOOL)flush {
    [self.saveTimer invalidate];
    if (!self.isViewLoaded || !self.session)
        return YES;
    if (self.editor.markedTextRange)
        [self.editor unmarkText];
    NSError* error = nil;
    BOOL saved =
        [self.session replaceText:self.editor.text error:&error] && [self.session save:&error];
    self.status.text =
        saved ? (NeonWritingPreference(@"showWordCount")
                     ? [NSString stringWithFormat:@"%lu words  ·  Saved on this device",
                                                  wordCount(self.editor.text)]
                     : @"Saved on this device")
              : error.localizedDescription;
    return saved;
}
- (void)save {
    [self flush];
}
- (void)chapters {
    if ([self flush])
        [self.coordinator toggleChapters];
}
- (void)typography {
    NeonTypography* controller = [NeonTypography new];
    controller.editor = self;
    UINavigationController* nav =
        [[UINavigationController alloc] initWithRootViewController:controller];
    nav.modalPresentationStyle =
        self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular
            ? UIModalPresentationPopover
            : UIModalPresentationPageSheet;
    nav.preferredContentSize = CGSizeMake(340, 560);
    nav.popoverPresentationController.barButtonItem =
        self.navigationItem.rightBarButtonItems.lastObject;
    nav.popoverPresentationController.delegate = controller;
    nav.sheetPresentationController.prefersGrabberVisible = YES;
    nav.sheetPresentationController.detents = @[ UISheetPresentationControllerDetent.largeDetent ];
    nav.view.tintColor = NeonAccent();
    [self presentViewController:nav animated:YES completion:nil];
}
- (void)actions {
    NeonShowMenu(
        self, self.view,
        CGRectMake(self.view.bounds.size.width - 44, self.view.safeAreaInsets.top, 1, 1), @[
            NeonAction(@"Rename Project…", @"pencil", YES, NO,
                       ^{
                         [self.coordinator projectCommand:@"Rename…"
                                                      url:self.coordinator.selectedURL
                                                    title:self.session.title];
                       }),
            NeonAction([NSString stringWithFormat:@"New %@…", self.session.preset[@"sectionLabel"]],
                       @"plus", YES, NO,
                       ^{
                         [self.coordinator newSection];
                       }),
            NeonAction(
                [NSString stringWithFormat:@"%@ Actions…", self.session.preset[@"sectionLabel"]],
                @"doc.text", self.session.sections.count > 0, NO,
                ^{
                  NSUInteger i = [self.session.sections
                      indexOfObjectPassingTest:^BOOL(NSDictionary* item, NSUInteger n, BOOL* stop) {
                        (void)n;
                        (void)stop;
                        return [item[@"id"] isEqual:self.session.selectedSectionID];
                      }];
                  [self.coordinator sectionMenu:i
                                           host:self
                                         anchor:self.view
                                           rect:CGRectMake(self.view.bounds.size.width - 44,
                                                           self.view.safeAreaInsets.top, 1, 1)];
                }),
            NeonAction([@"Deleted " stringByAppendingString:self.session.preset[@"sectionsLabel"]],
                       @"arrow.uturn.backward", self.session.trashedSections.count > 0, NO,
                       ^{
                         [self.coordinator showSectionTrash:self anchor:self.view];
                       }),
            NeonAction(@"History…", @"clock.arrow.circlepath", YES, NO,
                       ^{
                         [self.coordinator showHistory];
                       }),
            NeonAction(@"Move Project to Trash…", @"trash", YES, YES,
                       ^{
                         [self.coordinator projectCommand:@"Move to Trash…"
                                                      url:self.coordinator.selectedURL
                                                    title:self.session.title];
                       })
        ]);
}
- (UIMenu*)textView:(UITextView*)textView
    editMenuForTextInRange:(NSRange)range
          suggestedActions:(NSArray<UIMenuElement*>*)suggestedActions {
    (void)suggestedActions;
    BOOL selected = range.length > 0;
    NeonShowMenu(
        self, textView, [textView caretRectForPosition:textView.selectedTextRange.start], @[
            NeonAction(@"Undo", @"arrow.uturn.backward", textView.undoManager.canUndo, NO,
                       ^{
                         [textView.undoManager undo];
                       }),
            NeonAction(@"Redo", @"arrow.uturn.forward", textView.undoManager.canRedo, NO,
                       ^{
                         [textView.undoManager redo];
                       }),
            NeonAction(@"Cut", @"scissors", selected && textView.editable, NO,
                       ^{
                         [textView cut:nil];
                       }),
            NeonAction(@"Copy", @"doc.on.doc", selected, NO,
                       ^{
                         [textView copy:nil];
                       }),
            NeonAction(@"Paste", @"doc.on.clipboard",
                       UIPasteboard.generalPasteboard.hasStrings && textView.editable, NO,
                       ^{
                         [textView paste:nil];
                       }),
            NeonAction(@"Select All", @"selection.pin.in.out", textView.text.length > 0, NO,
                       ^{
                         [textView selectAll:nil];
                       })
        ]);
    // An empty menu suppresses UIKit actions; nil would request the stock menu.
    return [UIMenu menuWithTitle:@"" children:@[]];
}
@end
@implementation NeonTypography
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Typography";
    self.view.backgroundColor = NeonPanel();
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                      target:self
                                                      action:@selector(done)];
    UISlider* size = [UISlider new];
    size.minimumValue = 16;
    size.maximumValue = 32;
    size.value = NeonTextSize();
    size.accessibilityLabel = @"Text size";
    [size addTarget:self
                  action:@selector(sizeChanged:)
        forControlEvents:UIControlEventValueChanged];
    UISlider* spacing = [UISlider new];
    spacing.minimumValue = 2;
    spacing.maximumValue = 16;
    spacing.value = NeonLineSpacing();
    spacing.accessibilityLabel = @"Line spacing";
    [spacing addTarget:self
                  action:@selector(spacingChanged:)
        forControlEvents:UIControlEventValueChanged];
    UISegmentedControl* appearance =
        [[UISegmentedControl alloc] initWithItems:@[ @"System", @"Light", @"Dark" ]];
    appearance.selectedSegmentIndex = NeonAppearance();
    [appearance addTarget:self
                   action:@selector(appearanceChanged:)
         forControlEvents:UIControlEventValueChanged];
    NSMutableArray* fontRows = [NSMutableArray array];
    for (NSString* name in @[ @"Literata", @"Source Sans 3", @"System Serif" ]) {
        UIButton* row = [UIButton buttonWithType:UIButtonTypeSystem];
        row.accessibilityIdentifier = name;
        [row setTitle:[NSString stringWithFormat:@"%@   %@", name,
                                                 [NeonFontChoice() isEqual:name] ? @"✓" : @""]
             forState:UIControlStateNormal];
        row.titleLabel.font = NeonFontNamed(name, 20);
        row.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        row.backgroundColor = [NeonInk() colorWithAlphaComponent:0.06];
        row.layer.cornerRadius = 8;
        [row.heightAnchor constraintEqualToConstant:44].active = YES;
        [row addTarget:self
                      action:@selector(fontChanged:)
            forControlEvents:UIControlEventTouchUpInside];
        [fontRows addObject:row];
    }
    UIStackView* fonts = [[UIStackView alloc] initWithArrangedSubviews:fontRows];
    fonts.axis = UILayoutConstraintAxisVertical;
    fonts.spacing = 1;
    UIButton* more = [UIButton buttonWithType:UIButtonTypeSystem];
    [more setTitle:@"More Options  ›" forState:UIControlStateNormal];
    more.titleLabel.font = NeonUI(17);
    [more addTarget:self
                  action:@selector(moreOptions)
        forControlEvents:UIControlEventTouchUpInside];
    UIStackView* stack = [[UIStackView alloc] initWithArrangedSubviews:@[
        label(@"Font", NeonUI(15), NeonMuted()), fonts,
        label(@"Text size", NeonUI(15), NeonMuted()), size,
        label(@"Line spacing", NeonUI(15), NeonMuted()), spacing,
        label(@"Appearance", NeonUI(15), NeonMuted()), appearance, more
    ]];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 12;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor
                                            constant:24],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor
                                             constant:-24],
        [stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor
                                        constant:20]
    ]];
}
- (void)fontChanged:(UIButton*)sender {
    [NSUserDefaults.standardUserDefaults setObject:sender.accessibilityIdentifier
                                            forKey:@"manuscriptFont"];
    for (UIButton* row in ((UIStackView*)sender.superview).arrangedSubviews)
        [row setTitle:[NSString
                          stringWithFormat:@"%@   %@", row.accessibilityIdentifier,
                                           [NeonFontChoice() isEqual:row.accessibilityIdentifier]
                                               ? @"✓"
                                               : @""]
             forState:UIControlStateNormal];
    [self.editor applyTypography];
}
- (void)moreOptions {
    NeonCoordinator* coordinator = self.editor.coordinator;
    [self dismissViewControllerAnimated:YES
                             completion:^{
                               [coordinator showSettings];
                             }];
}
- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:
    (UIPresentationController*)controller {
    (void)controller;
    return UIModalPresentationNone;
}
- (void)sizeChanged:(UISlider*)sender {
    [NSUserDefaults.standardUserDefaults setDouble:sender.value forKey:@"manuscriptSize"];
    [self.editor applyTypography];
}
- (void)spacingChanged:(UISlider*)sender {
    [NSUserDefaults.standardUserDefaults setDouble:sender.value forKey:@"manuscriptSpacing"];
    [self.editor applyTypography];
}
- (void)appearanceChanged:(UISegmentedControl*)sender {
    [NSUserDefaults.standardUserDefaults setInteger:sender.selectedSegmentIndex
                                             forKey:@"appearance"];
    [self.editor.coordinator applyAppearance];
}
- (void)done {
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
@implementation NeonList
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.chapters ? self.coordinator.session.title : @"Library";
    self.view.backgroundColor = NeonPanel();
    self.tableView.backgroundColor = NeonPanel();
    self.tableView.tintColor = NeonAccent();
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = self.chapters ? 72 : 142;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.navigationItem.rightBarButtonItems = @[
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"gearshape"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(settings)],
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                      target:self
                                                      action:@selector(create)],
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"trash"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(trash)]
    ];
    self.navigationItem.rightBarButtonItems.firstObject.accessibilityLabel = @"Settings";
    if (self.chapters) {
        UIBarButtonItem* history = [[UIBarButtonItem alloc]
            initWithImage:[UIImage systemImageNamed:@"clock.arrow.circlepath"]
                    style:UIBarButtonItemStylePlain
                   target:self
                   action:@selector(history)];
        history.accessibilityLabel = @"History";
        self.navigationItem.rightBarButtonItems =
            [self.navigationItem.rightBarButtonItems arrayByAddingObject:history];
    }
    UILongPressGestureRecognizer* hold =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(context:)];
    [self.tableView addGestureRecognizer:hold];
    UITapGestureRecognizer* secondary =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(context:)];
    secondary.buttonMaskRequired = UIEventButtonMaskSecondary;
    [self.tableView addGestureRecognizer:secondary];
    if (self.chapters)
        self.navigationItem.leftBarButtonItem =
            [[UIBarButtonItem alloc] initWithTitle:@"Library"
                                             style:UIBarButtonItemStylePlain
                                            target:self
                                            action:@selector(library)];
}
- (void)settings {
    [self.coordinator showSettings];
}
- (void)history {
    [self.coordinator showHistory];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (!self.chapters)
        [self.coordinator reloadLibrary];
    [self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return self.chapters ? self.coordinator.session.sections.count
                         : self.coordinator.projects.count;
}
- (NSString*)tableView:(UITableView*)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView;
    (void)section;
    return self.chapters ? [self.coordinator.session.preset[@"documentLabel"] uppercaseString]
                         : @"ON THIS DEVICE";
}
- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)path {
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"project"];
    if (!cell)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:@"project"];
    [[cell.contentView viewWithTag:901] removeFromSuperview];
    UIListContentConfiguration* content = [cell defaultContentConfiguration];
    if (self.chapters) {
        NSDictionary* section = self.coordinator.session.sections[path.row];
        content.text = section[@"title"];
        content.secondaryText = [self.coordinator.session sectionLabelAtIndex:path.row];
        content.image = [UIImage systemImageNamed:@"doc.text"];
        content.textProperties.font = NeonUI(18);
        content.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(18, 20, 18, 20);
    } else {
        NSDictionary* project = self.coordinator.projects[path.row];
        content.text = project[@"title"];
        content.secondaryText =
            [project[@"error"] length]
                ? project[@"error"]
                : [NSString stringWithFormat:@"%@ · %@ %@", project[@"preset"],
                                             project[@"sections"],
                                             [project[@"sectionLabel"] lowercaseString]];
        content.image = cover(project[@"title"]);
        content.imageProperties.maximumSize = CGSizeMake(74, 108);
        content.textProperties.font = scaledSerif(21);
        content.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(14, 20, 14, 16);
    }
    content.textProperties.color = NeonInk();
    content.secondaryTextProperties.color = NeonMuted();
    content.secondaryTextProperties.font = NeonUI(14);
    content.textToSecondaryTextVerticalPadding = 8;
    content.imageToTextPadding = 18;
    content.imageProperties.tintColor = NeonAccent();
    cell.contentConfiguration = self.chapters ? nil : content;
    if (self.chapters) {
        NSDictionary* section = self.coordinator.session.sections[path.row];
        NSString* identifier = section[@"id"];
        NeonInlineTitle* title = [NeonInlineTitle new];
        title.text = section[@"title"];
        title.font = NeonUI(18);
        title.accessibilityLabel =
            [self.coordinator.session.preset[@"sectionLabel"] stringByAppendingString:@" title"];
        __weak NeonList* weakSelf = self;
        title.commitTitle = ^BOOL(NSString* value) {
          return [weakSelf.coordinator renameInline:value section:identifier];
        };
        title.activateTitle = ^{
          NSArray* sections = weakSelf.coordinator.session.sections;
          NSUInteger index = [sections
              indexOfObjectPassingTest:^BOOL(NSDictionary* item, NSUInteger i, BOOL* stop) {
                (void)i;
                (void)stop;
                return [item[@"id"] isEqual:identifier];
              }];
          if (index != NSNotFound)
              [weakSelf.coordinator openSection:index];
        };
        UILabel* subtitle =
            label([self.coordinator.session sectionLabelAtIndex:path.row], NeonUI(13), NeonMuted());
        UIStackView* row = [[UIStackView alloc] initWithArrangedSubviews:@[ title, subtitle ]];
        row.axis = UILayoutConstraintAxisVertical;
        row.spacing = 4;
        row.tag = 901;
        row.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:row];
        [NSLayoutConstraint activateConstraints:@[
            [row.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:20],
            [row.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor
                                               constant:-8],
            [row.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:10],
            [row.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-10],
            [title.heightAnchor constraintGreaterThanOrEqualToConstant:44]
        ]];
    }
    cell.backgroundColor =
        UIAccessibilityIsReduceTransparencyEnabled() ? NeonPanel() : UIColor.clearColor;
    UIButton* more = [UIButton buttonWithType:UIButtonTypeSystem];
    [more setImage:[UIImage systemImageNamed:@"ellipsis"] forState:UIControlStateNormal];
    more.frame = CGRectMake(0, 0, 44, 44);
    more.tag = path.row;
    more.accessibilityLabel = self.chapters ? [self.coordinator.session.preset[@"sectionLabel"]
                                                  stringByAppendingString:@" actions"]
                                            : @"Project actions";
    [more addTarget:self action:@selector(more:) forControlEvents:UIControlEventTouchUpInside];
    cell.accessoryView = more;
    UIView* selected = [UIView new];
    selected.backgroundColor = [NeonAccent() colorWithAlphaComponent:0.12];
    cell.selectedBackgroundView = selected;
    cell.accessibilityIdentifier =
        [NSString stringWithFormat:@"%@-%ld", self.chapters ? @"section" : @"project", path.row];
    return cell;
}
- (void)tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)path {
    (void)tableView;
    if (self.chapters)
        [self.coordinator openSection:path.row];
    else
        [self.coordinator openProject:path.row];
}
- (void)create {
    if (self.chapters)
        [self.coordinator newSection];
    else
        [self.coordinator newProject];
}
- (void)library {
    [self.coordinator showLibrary];
}
- (void)trash {
    if (self.chapters)
        [self.coordinator showSectionTrash:self anchor:self.view];
    else if (self.coordinator.trashMode)
        [self.coordinator showLibrary];
    else
        [self.coordinator showTrash];
}
- (void)more:(UIButton*)sender {
    if (self.chapters)
        [self.coordinator sectionMenu:sender.tag host:self anchor:sender rect:sender.bounds];
    else
        [self.coordinator projectMenu:sender.tag host:self anchor:sender rect:sender.bounds];
}
- (void)context:(UIGestureRecognizer*)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan &&
        ![gesture isKindOfClass:UITapGestureRecognizer.class])
        return;
    CGPoint point = [gesture locationInView:self.tableView];
    NSIndexPath* path = [self.tableView indexPathForRowAtPoint:point];
    if (!path)
        return;
    CGRect rect = CGRectMake(point.x, point.y, 1, 1);
    if (self.chapters)
        [self.coordinator sectionMenu:path.row host:self anchor:self.tableView rect:rect];
    else
        [self.coordinator projectMenu:path.row host:self anchor:self.tableView rect:rect];
}
@end
@implementation NeonCoordinator
- (instancetype)init {
    self = [super initWithStyle:UISplitViewControllerStyleDoubleColumn];
    if (self) {
        self.delegate = self;
        self.preferredDisplayMode = UISplitViewControllerDisplayModeOneBesideSecondary;
        self.preferredPrimaryColumnWidthFraction = 0.30;
        self.minimumPrimaryColumnWidth = 280;
        self.maximumPrimaryColumnWidth = 360;
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    NeonRegisterFonts();
    self.view.tintColor = NeonAccent();
    NSArray* args = NSProcessInfo.processInfo.arguments;
    self.smoke = [args containsObject:@"--smoke-test"];
    BOOL reopen =
        [args containsObject:@"--smoke-reopen"] || [args containsObject:@"--smoke-library"] ||
        [args containsObject:@"--smoke-focus"] || [args containsObject:@"--smoke-typography"] ||
        [args containsObject:@"--smoke-menu"] || [args containsObject:@"--smoke-settings"] ||
        [args containsObject:@"--smoke-history"] || [args containsObject:@"--smoke-preset"];
    NSURL* support = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                            inDomains:NSUserDomainMask]
                         .firstObject;
    NSURL* directory =
        [support URLByAppendingPathComponent:(self.smoke || reopen) ? @"SmokeLibrary"
                                                                    : @"Neon Apple Preview"];
    if (self.smoke)
        [[NSFileManager defaultManager] removeItemAtURL:directory error:nil];
    self.library = [[NeonLibraryStore alloc] initWithDirectory:directory];
    NSError* error = nil;
    if (self.smoke && ![self.library seedPreview:&error])
        [self showProblem:error];
    self.libraryList = [[NeonList alloc] initWithStyle:UITableViewStyleInsetGrouped];
    self.libraryList.coordinator = self;
    self.navigation = [[UINavigationController alloc] initWithRootViewController:self.libraryList];
    self.navigation.navigationBar.prefersLargeTitles = YES;
    [self setViewController:self.navigation forColumn:UISplitViewControllerColumnPrimary];
    UIViewController* welcome = [UIViewController new];
    welcome.view.backgroundColor = NeonPaper();
    UILabel* hint = label(@"A quiet place for your next idea.", scaledSerif(28), NeonMuted());
    hint.textAlignment = NSTextAlignmentCenter;
    hint.translatesAutoresizingMaskIntoConstraints = NO;
    [welcome.view addSubview:hint];
    [NSLayoutConstraint activateConstraints:@[
        [hint.centerYAnchor constraintEqualToAnchor:welcome.view.centerYAnchor],
        [hint.leadingAnchor constraintEqualToAnchor:welcome.view.leadingAnchor constant:32],
        [hint.trailingAnchor constraintEqualToAnchor:welcome.view.trailingAnchor constant:-32]
    ]];
    [self setViewController:welcome forColumn:UISplitViewControllerColumnSecondary];
    [NSNotificationCenter.defaultCenter
        addObserver:self
           selector:@selector(accessibilityChanged:)
               name:UIAccessibilityReduceTransparencyStatusDidChangeNotification
             object:nil];
    [self reloadLibrary];
    [self applyAppearance];
    if (self.smoke || reopen)
        dispatch_async(dispatch_get_main_queue(), ^{
          [self runSmoke:args support:support];
        });
}
- (void)accessibilityChanged:(NSNotification*)note {
    (void)note;
    [self applyAppearance];
}
- (void)applyAppearance {
    UIUserInterfaceStyle style = NeonAppearance() == 1   ? UIUserInterfaceStyleLight
                                 : NeonAppearance() == 2 ? UIUserInterfaceStyleDark
                                                         : UIUserInterfaceStyleUnspecified;
    self.view.window.overrideUserInterfaceStyle = style;
    self.overrideUserInterfaceStyle = style;
    UINavigationBarAppearance* appearance = [UINavigationBarAppearance new];
    BOOL opaque = UIAccessibilityIsReduceTransparencyEnabled();
    self.view.backgroundColor = NeonPaper();
    if (opaque) {
        [appearance configureWithOpaqueBackground];
        appearance.backgroundColor = NeonPaper();
    } else if (@available(iOS 26.0, *)) {
        // Leave native Liquid Glass navigation backgrounds unmodified. The paper
        // beneath supplies the warm hue without covering the system material.
    } else {
        [appearance configureWithDefaultBackground];
        appearance.backgroundColor = [NeonPaper() colorWithAlphaComponent:0.25];
    }
    for (NeonList* list in
         @[ self.libraryList ?: (id)NSNull.null, self.chapterList ?: (id)NSNull.null ]) {
        if (![list isKindOfClass:NeonList.class])
            continue;
        list.tableView.backgroundColor = opaque ? NeonPanel() : UIColor.clearColor;
        if (opaque)
            list.tableView.backgroundView = nil;
        else {
            UIVisualEffectView* material = [[UIVisualEffectView alloc]
                initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial]];
            material.contentView.backgroundColor = [NeonPanel() colorWithAlphaComponent:0.18];
            list.tableView.backgroundView = material;
        }
        [list.tableView reloadData];
    }
    appearance.titleTextAttributes =
        @{NSFontAttributeName : NeonUI(18), NSForegroundColorAttributeName : NeonInk()};
    appearance.largeTitleTextAttributes =
        @{NSFontAttributeName : NeonSerif(34), NSForegroundColorAttributeName : NeonInk()};
    self.navigation.navigationBar.standardAppearance = appearance;
    self.navigation.navigationBar.scrollEdgeAppearance = appearance;
    self.navigation.navigationBar.tintColor = NeonAccent();
    UINavigationController* detail =
        (id)[self viewControllerForColumn:UISplitViewControllerColumnSecondary];
    if ([detail isKindOfClass:UINavigationController.class]) {
        detail.navigationBar.standardAppearance = appearance;
        detail.navigationBar.scrollEdgeAppearance = appearance;
        detail.navigationBar.tintColor = NeonAccent();
    }
}
- (BOOL)renameInline:(NSString*)title section:(NSString*)identifier {
    if (!self.session || (self.editor && ![self.editor flush]))
        return NO;
    NSError* error = nil;
    BOOL changed = identifier ? [self.session renameSection:identifier title:title error:&error]
                              : [self.session renameProject:title error:&error];
    if (!changed || ![self.session save:&error]) {
        [self showProblem:error];
        return NO;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      self.editor.title = self.session.title;
      self.editor.bookTitle.text = self.session.title;
      self.editor.heading.text = self.session.sectionTitle;
      self.chapterList.title = self.session.title;
      [self.chapterList.tableView reloadData];
    });
    return YES;
}
- (void)showSettings {
    NeonSettingsController* controller = [NeonSettingsController new];
    __weak NeonCoordinator* weakSelf = self;
    controller.preferencesChanged = ^{
      [weakSelf applyAppearance];
      [weakSelf.editor applyTypography];
      if ([weakSelf.editor.status.text containsString:@"Saved on this device"])
          weakSelf.editor.status.text =
              NeonWritingPreference(@"showWordCount")
                  ? [NSString stringWithFormat:@"%lu words  ·  Saved on this device",
                                               wordCount(weakSelf.editor.editor.text)]
                  : @"Saved on this device";
    };
    UINavigationController* nav =
        [[UINavigationController alloc] initWithRootViewController:controller];
    nav.overrideUserInterfaceStyle = self.overrideUserInterfaceStyle;
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}
- (void)reloadLibrary {
    NSError* error = nil;
    NSArray* projects =
        self.trashMode ? [self.library trashedProjects:&error] : [self.library projects:&error];
    if (!projects) {
        [self showProblem:error];
        return;
    }
    self.projects = projects;
    self.libraryList.title = self.trashMode ? @"Trash" : @"Library";
    self.libraryList.navigationItem.leftBarButtonItem =
        self.trashMode ? [[UIBarButtonItem alloc] initWithTitle:@"Library"
                                                          style:UIBarButtonItemStylePlain
                                                         target:self
                                                         action:@selector(showLibrary)]
                       : nil;
    [self.libraryList.tableView reloadData];
}
- (void)showProblem:(NSError*)error {
    UIAlertController* alert =
        [UIAlertController alertControllerWithTitle:@"Could not open or save"
                                            message:error.localizedDescription
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)openProject:(NSInteger)index {
    if (index < 0 || index >= static_cast<NSInteger>(self.projects.count))
        return;
    if (self.trashMode) {
        [self projectMenu:index
                     host:self.libraryList
                   anchor:self.libraryList.view
                     rect:CGRectMake(40, 80, 1, 1)];
        return;
    }
    if (self.editor && ![self.editor flush])
        return;
    NSError* error = nil;
    NSURL* url = self.projects[index][@"url"];
    NeonDocumentSession* session = [self.library openURL:url error:&error];
    if (!session) {
        [self showProblem:error];
        return;
    }
    self.session = session;
    self.selectedURL = url;
    self.chapterList = [[NeonList alloc] initWithStyle:UITableViewStyleInsetGrouped];
    self.chapterList.chapters = YES;
    self.chapterList.coordinator = self;
    [self.navigation setViewControllers:@[ self.libraryList, self.chapterList ] animated:NO];
    if (!self.collapsed)
        [self openSection:0];
}
- (void)openSection:(NSInteger)index {
    if (self.session.sections.count &&
        (index < 0 || index >= static_cast<NSInteger>(self.session.sections.count)))
        return;
    if (self.editor && ![self.editor flush])
        return;
    NSError* error = nil;
    self.editor.session = nil;
    self.editor = nil;
    if (self.session.sections.count &&
        ![self.session selectSection:self.session.sections[index][@"id"] error:&error]) {
        [self showProblem:error];
        return;
    }
    // Detach the old editor before changing its shared session selection.
    self.editor = nil;
    NeonEditor* editor = [NeonEditor new];
    editor.session = self.session;
    editor.coordinator = self;
    if (self.collapsed)
        [self.navigation setViewControllers:@[ self.libraryList, self.chapterList, editor ]
                                   animated:NO];
    else {
        [self setViewController:[[UINavigationController alloc] initWithRootViewController:editor]
                      forColumn:UISplitViewControllerColumnSecondary];
        [self showColumn:UISplitViewControllerColumnSecondary];
    }
    self.editor = editor;
    [editor loadViewIfNeeded];
    [self applyAppearance];
    [self.chapterList.tableView reloadData];
}
- (void)toggleChapters {
    if (self.collapsed) {
        [self.navigation popToViewController:self.chapterList animated:YES];
        return;
    }
    self.sidebarHidden = !self.sidebarHidden;
    if (self.sidebarHidden)
        [self hideColumn:UISplitViewControllerColumnPrimary];
    else
        [self showColumn:UISplitViewControllerColumnPrimary];
    self.editor.navigationItem.leftBarButtonItem.accessibilityLabel =
        [NSString stringWithFormat:@"%@ %@ sidebar", self.sidebarHidden ? @"Show" : @"Hide",
                                   self.session.preset[@"sectionsLabel"]];
}
- (UISplitViewControllerColumn)splitViewController:(UISplitViewController*)controller
         topColumnForCollapsingToProposedTopColumn:(UISplitViewControllerColumn)column {
    (void)controller;
    (void)column;
    return UISplitViewControllerColumnPrimary;
}
- (void)viewWillTransitionToSize:(CGSize)size
       withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)transition {
    [super viewWillTransitionToSize:size withTransitionCoordinator:transition];
    [transition
        animateAlongsideTransition:nil
                        completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
                          (void)context;
                          if (!self.editor)
                              return;
                          if (![self.editor flush])
                              return;
                          if (self.collapsed) {
                              [self setViewController:nil
                                            forColumn:UISplitViewControllerColumnSecondary];
                              [self.navigation setViewControllers:@[
                                  self.libraryList, self.chapterList, self.editor
                              ]
                                                         animated:NO];
                          } else {
                              [self.navigation
                                  setViewControllers:@[ self.libraryList, self.chapterList ]
                                            animated:NO];
                              [self setViewController:[[UINavigationController alloc]
                                                          initWithRootViewController:self.editor]
                                            forColumn:UISplitViewControllerColumnSecondary];
                              if (self.sidebarHidden)
                                  [self hideColumn:UISplitViewControllerColumnPrimary];
                          }
                          [self applyAppearance];
                        }];
}
- (void)askTitle:(BOOL)section {
    if (self.editor && ![self.editor flush])
        return;
    UIAlertController* alert = [UIAlertController
        alertControllerWithTitle:section
                                     ? [@"New "
                                           stringByAppendingString:self.session
                                                                       .preset[@"sectionLabel"]]
                                     : [@"New "
                                           stringByAppendingString:[self selectedPreset][@"title"]]
                         message:section
                                     ? @"Give it a working title."
                                     : [NSString
                                           stringWithFormat:@"%@\n\n%@",
                                                            [self selectedPreset][@"description"],
                                                            [[[self selectedPreset][@"sections"]
                                                                valueForKey:@"title"]
                                                                componentsJoinedByString:@" · "]]
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField* field) {
      field.placeholder = @"Working title";
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction
                         actionWithTitle:@"Create"
                                   style:UIAlertActionStyleDefault
                                 handler:^(UIAlertAction* action) {
                                   (void)action;
                                   NSString* title = [alert.textFields.firstObject.text
                                       stringByTrimmingCharactersInSet:
                                           NSCharacterSet.whitespaceAndNewlineCharacterSet];
                                   NSError* error = nil;
                                   if (section) {
                                       if (![self.session addSection:title error:&error]) {
                                           [self showProblem:error];
                                           return;
                                       }
                                       self.editor.session = nil;
                                       self.editor = nil;
                                       [self openSection:self.session.sections.count - 1];
                                       if (![self.editor flush])
                                           [self showProblem:
                                                     [NSError
                                                         errorWithDomain:@"Neon"
                                                                    code:1
                                                                userInfo:@{
                                                                    NSLocalizedDescriptionKey :
                                                                        @"The new section is open "
                                                                        @"but could not be saved. "
                                                                        @"Your draft is retained."
                                                                }]];
                                   } else {
                                       NSURL* url =
                                           [self.library createProject:title
                                                                preset:self.pendingPreset ?: @"book"
                                                                 error:&error];
                                       if (!url) {
                                           [self showProblem:error];
                                           return;
                                       }
                                       self.trashMode = NO;
                                       [self reloadLibrary];
                                       NSInteger i = [self.projects
                                           indexOfObjectPassingTest:^BOOL(
                                               NSDictionary* item, NSUInteger index, BOOL* stop) {
                                             (void)index;
                                             (void)stop;
                                             return [item[@"url"] isEqual:url];
                                           }];
                                       [self openProject:i];
                                   }
                                 }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (NSDictionary*)selectedPreset {
    for (NSDictionary* preset in NeonDocumentSession.writingPresets)
        if ([preset[@"id"] isEqual:self.pendingPreset])
            return preset;
    return NeonDocumentSession.writingPresets.firstObject;
}
- (void)newProject {
    if (self.editor && ![self.editor flush])
        return;
    UIAlertController* picker =
        [UIAlertController alertControllerWithTitle:@"Choose a writing preset"
                                            message:@"Each preset includes its own outline, "
                                                    @"terminology, and reading format."
                                     preferredStyle:UIAlertControllerStyleActionSheet];
    for (NSDictionary* preset in NeonDocumentSession.writingPresets)
        [picker addAction:[UIAlertAction actionWithTitle:preset[@"title"]
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction*) {
                                                   self.pendingPreset = preset[@"id"];
                                                   [self askTitle:NO];
                                                 }]];
    [picker addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                               style:UIAlertActionStyleCancel
                                             handler:nil]];
    picker.popoverPresentationController.sourceView = self.view;
    picker.popoverPresentationController.sourceRect =
        CGRectMake(self.view.bounds.size.width / 2, 80, 1, 1);
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)showHistory {
    if (!self.session || (self.editor && ![self.editor flush]))
        return;
    NeonHistoryController* controller = [NeonHistoryController new];
    controller.session = self.session;
    __weak NeonCoordinator* weakSelf = self;
    controller.didRestore = ^{
      [weakSelf refreshAfterStructure];
    };
    UINavigationController* navigation =
        [[UINavigationController alloc] initWithRootViewController:controller];
    navigation.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:navigation animated:YES completion:nil];
}
- (void)newSection {
    [self askTitle:YES];
}
- (void)showLibrary {
    if (self.editor && ![self.editor flush])
        return;
    self.editor.session = nil;
    self.editor = nil;
    self.session = nil;
    self.selectedURL = nil;
    self.trashMode = NO;
    [self.navigation setViewControllers:@[ self.libraryList ] animated:NO];
    UIViewController* blank = [UIViewController new];
    blank.view.backgroundColor = NeonPaper();
    [self setViewController:blank forColumn:UISplitViewControllerColumnSecondary];
    [self showColumn:UISplitViewControllerColumnPrimary];
    [self reloadLibrary];
}
- (void)showTrash {
    [self showLibrary];
    if (self.session)
        return;
    self.trashMode = YES;
    [self reloadLibrary];
}
- (void)projectMenu:(NSInteger)index
               host:(UIViewController*)host
             anchor:(UIView*)anchor
               rect:(CGRect)rect {
    if (index < 0 || index >= static_cast<NSInteger>(self.projects.count))
        return;
    NSDictionary* project = self.projects[index];
    NSMutableArray* actions = [NSMutableArray array];
    for (NSString* command in self.trashMode ? @[ @"Restore", @"Delete Permanently…" ]
                                             : @[ @"Rename…", @"Duplicate", @"Move to Trash…" ])
        [actions
            addObject:NeonAction(command,
                                 [command containsString:@"Trash"] || [command hasPrefix:@"Delete"]
                                     ? @"trash"
                                     : @"pencil",
                                 YES,
                                 [command containsString:@"Trash"] || [command hasPrefix:@"Delete"],
                                 ^{
                                   [self projectCommand:command
                                                    url:project[@"url"]
                                                  title:project[@"title"]];
                                 })];
    NeonShowMenu(host, anchor, rect, actions);
}
- (void)prompt:(NSString*)title value:(NSString*)value completion:(void (^)(NSString*))completion {
    UIAlertController* alert =
        [UIAlertController alertControllerWithTitle:title
                                            message:nil
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField* field) {
      field.text = value;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Rename"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction* action) {
                                              (void)action;
                                              completion(alert.textFields.firstObject.text);
                                            }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)projectCommand:(NSString*)command url:(NSURL*)url title:(NSString*)title {
    if (self.editor && ![self.editor flush])
        return;
    if ([command hasPrefix:@"Rename"]) {
        [self prompt:@"Rename Project"
                 value:title
            completion:^(NSString* value) {
              NSError* error = nil;
              NeonDocumentSession* session = [url isEqual:self.selectedURL]
                                                 ? self.session
                                                 : [self.library openURL:url error:&error];
              if (!session || ![session renameProject:value error:&error] ||
                  ![session save:&error]) {
                  [self showProblem:error];
                  return;
              }
              self.editor.title = self.session.title;
              self.chapterList.title = self.session.title;
              [self reloadLibrary];
            }];
        return;
    }
    void (^perform)(void) = ^{
      NSError* error = nil;
      BOOL success = NO;
      if ([command isEqual:@"Duplicate"])
          success = [self.library duplicateProject:url error:&error] != nil;
      else if ([command hasPrefix:@"Delete"])
          success = [self.library deleteTrashedProject:url error:&error];
      else
          success = [self.library setProject:url
                                     trashed:![command isEqual:@"Restore"]
                                       error:&error];
      if (!success) {
          [self showProblem:error];
          return;
      }
      if ([url isEqual:self.selectedURL] && ![command isEqual:@"Duplicate"]) {
          self.editor.session = nil;
          self.editor = nil;
          [self showLibrary];
      } else
          [self reloadLibrary];
    };
    if ([command isEqual:@"Restore"] || [command isEqual:@"Duplicate"]) {
        perform();
        return;
    }
    UIAlertController* alert = [UIAlertController
        alertControllerWithTitle:[NSString stringWithFormat:@"%@ %@", command, title]
                         message:[command hasPrefix:@"Delete"]
                                     ? @"This permanently deletes the project file and cannot be "
                                       @"undone."
                                     : @"You can restore this project from Trash."
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [alert addAction:[UIAlertAction
                         actionWithTitle:[command hasPrefix:@"Delete"] ? @"Delete Permanently"
                                                                       : @"Move to Trash"
                                   style:UIAlertActionStyleDestructive
                                 handler:^(UIAlertAction* action) {
                                   (void)action;
                                   perform();
                                 }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)sectionMenu:(NSInteger)index
               host:(UIViewController*)host
             anchor:(UIView*)anchor
               rect:(CGRect)rect {
    if (index < 0 || index >= static_cast<NSInteger>(self.session.sections.count))
        return;
    NSString* identifier = self.session.sections[index][@"id"];
    NSMutableArray* actions = [NSMutableArray array];
    for (NSString* command in
         @[ @"Rename…", @"Duplicate", @"Move Up", @"Move Down", @"Move to Trash…" ]) {
        BOOL enabled = !([command isEqual:@"Move Up"] && index == 0) &&
                       !([command isEqual:@"Move Down"] &&
                         index + 1 == static_cast<NSInteger>(self.session.sections.count));
        [actions
            addObject:NeonAction(command, [command containsString:@"Trash"] ? @"trash" : @"pencil",
                                 enabled, [command containsString:@"Trash"], ^{
                                   [self sectionCommand:command identifier:identifier];
                                 })];
    }
    NeonShowMenu(host, anchor, rect, actions);
}
- (void)showSectionTrash:(UIViewController*)host anchor:(UIView*)anchor {
    NSMutableArray* actions = [NSMutableArray array];
    for (NSDictionary* section in self.session.trashedSections)
        [actions addObject:NeonAction([@"Restore " stringByAppendingString:section[@"title"]],
                                      @"arrow.uturn.backward", YES, NO, ^{
                                        [self sectionCommand:@"Restore" identifier:section[@"id"]];
                                      })];
    if (!actions.count)
        [actions
            addObject:NeonAction([@"No deleted "
                                     stringByAppendingString:[self.session.preset[@"sectionsLabel"]
                                                                 lowercaseString]],
                                 @"trash", NO, NO,
                                 ^{
                                 })];
    NeonShowMenu(host, anchor, CGRectMake(40, anchor.safeAreaInsets.top + 20, 1, 1), actions);
}
- (void)refreshAfterStructure {
    NSString* selected = self.session.selectedSectionID;
    self.chapterList.title = self.session.title;
    self.editor.session = nil;
    self.editor = nil;
    NSUInteger index = [self.session.sections
        indexOfObjectPassingTest:^BOOL(NSDictionary* item, NSUInteger i, BOOL* stop) {
          (void)i;
          (void)stop;
          return [item[@"id"] isEqual:selected];
        }];
    [self openSection:index == NSNotFound ? 0 : index];
    NSError* error = nil;
    if (![self.session save:&error])
        [self showProblem:error];
}
- (void)sectionCommand:(NSString*)command identifier:(NSString*)identifier {
    if (self.editor && ![self.editor flush])
        return;
    if ([command hasPrefix:@"Rename"]) {
        NSString* title = @"";
        for (NSDictionary* section in self.session.sections)
            if ([section[@"id"] isEqual:identifier])
                title = section[@"title"];
        [self prompt:[@"Rename " stringByAppendingString:self.session.preset[@"sectionLabel"]]
                 value:title
            completion:^(NSString* value) {
              NSError* error = nil;
              if (![self.session renameSection:identifier title:value error:&error]) {
                  [self showProblem:error];
                  return;
              }
              [self refreshAfterStructure];
            }];
        return;
    }
    NSError* error = nil;
    BOOL success = NO;
    if ([command isEqual:@"Duplicate"])
        success = [self.session duplicateSection:identifier error:&error];
    else if ([command isEqual:@"Move Up"] || [command isEqual:@"Move Down"])
        success = [self.session moveSection:identifier
                                  direction:[command isEqual:@"Move Up"] ? -1 : 1
                                      error:&error];
    else
        success = [self.session setSection:identifier
                                   trashed:![command isEqual:@"Restore"]
                                     error:&error];
    if (!success) {
        [self showProblem:error];
        return;
    }
    [self refreshAfterStructure];
}
- (void)runSmoke:(NSArray*)args support:(NSURL*)support {
    if ([args containsObject:@"--smoke-library"]) {
        marker(support, @"smoke-library.txt", self.projects.count == 3);
        return;
    }
    NSInteger index = [self.projects
        indexOfObjectPassingTest:^BOOL(NSDictionary* item, NSUInteger i, BOOL* stop) {
          (void)i;
          (void)stop;
          return [item[@"title"] isEqualToString:@"The Quiet Sea"];
        }];
    [self openProject:index];
    [self openSection:0];
    if (self.smoke) {
        [self.editor.editor
            insertText:@"\n\nA native Apple draft. Café 👩🏽‍💻 العربية"];
        [self.editor textViewDidChange:self.editor.editor];
        BOOL saved = [self.editor flush];
        NSError* error = nil;
        NeonDocumentSession* reopened = [self.library openURL:self.selectedURL error:&error];
        BOOL valid = saved && [reopened.text containsString:@"A native Apple draft."] &&
                     reopened.sections.count == 2;
        [self openSection:1];
        valid = valid && [self.editor.editor.text containsString:@"By noon"];
        [self openSection:0];
        valid = valid && [self.editor.editor.text containsString:@"A native Apple draft."];
        UITextView* originalEditor = self.editor.editor;
        NSString* draft = originalEditor.text;
        NSRange selection = originalEditor.selectedRange;
        NSString* projectTitle = self.session.title;
        NSString* chapterTitle = self.session.sectionTitle;
        [self.editor.bookTitle beginRenaming];
        self.editor.bookTitle.text = @"Renamed in navigation";
        valid = [self.editor.bookTitle finishRenaming:YES] && valid;
        [self.editor.heading beginRenaming];
        self.editor.heading.text = @"Renamed in manuscript";
        valid = [self.editor.heading finishRenaming:YES] && valid;
        [self.editor.heading beginRenaming];
        self.editor.heading.text = @"Cancelled title";
        [self.editor.heading finishRenaming:NO];
        reopened = [self.library openURL:self.selectedURL error:&error];
        valid = valid && [reopened.title isEqual:@"Renamed in navigation"] &&
                [reopened.sectionTitle isEqual:@"Renamed in manuscript"] &&
                [self.editor.heading.text isEqual:@"Renamed in manuscript"] &&
                self.editor.editor == originalEditor && [originalEditor.text isEqual:draft] &&
                NSEqualRanges(selection, originalEditor.selectedRange);
        valid = [self renameInline:projectTitle section:nil] && valid;
        valid = [self renameInline:chapterTitle section:self.session.selectedSectionID] && valid;
        marker(support, @"smoke-result.txt", valid);
    } else if ([args containsObject:@"--smoke-history"]) {
        NSError* error = nil;
        NSString* original = self.session.text;
        BOOL valid = [self.session createCheckpoint:@"Before review" error:&error];
        NSString* checkpoint = self.session.history.firstObject[@"id"];
        valid = valid && [self.session replaceText:@"An unsaved revision" error:&error] &&
                [self.session restoreRevision:checkpoint error:&error] &&
                [self.session.text isEqual:original];
        [self refreshAfterStructure];
        [self showHistory];
        UINavigationController* navigation = (id)self.presentedViewController;
        NeonHistoryController* controller = (id)navigation.topViewController;
        [controller loadViewIfNeeded];
        [controller selectRevisionAtIndex:1];
        marker(support, @"smoke-history.txt",
               valid && [controller isKindOfClass:NeonHistoryController.class]);
    } else if ([args containsObject:@"--smoke-preset"]) {
        NSError* error = nil;
        NSURL* url = [self.library createProject:@"The tidal study"
                                          preset:@"research"
                                           error:&error];
        self.editor.session = nil;
        self.editor = nil;
        [self reloadLibrary];
        NSUInteger index = [self.projects
            indexOfObjectPassingTest:^BOOL(NSDictionary* project, NSUInteger, BOOL*) {
              return [project[@"url"] isEqual:url];
            }];
        [self openProject:index];
        [self openSection:0];
        NSParagraphStyle* style =
            self.editor.editor.typingAttributes[NSParagraphStyleAttributeName];
        marker(support, @"smoke-preset.txt",
               self.session.sections.count == 6 &&
                   [self.session.sectionTitle isEqual:@"Abstract"] &&
                   style.lineHeightMultiple == 2);
    } else if ([args containsObject:@"--smoke-settings"]) {
        [self showSettings];
        UINavigationController* navigation = (id)self.presentedViewController;
        NeonSettingsController* controller = (id)navigation.topViewController;
        [controller loadViewIfNeeded];
        BOOL valid = controller.visibleSettingCount == 10;
        [controller filterSettings:@"PARAGRAPH"];
        valid = valid && controller.visibleSettingCount == 1;
        UITableViewCell* cell = [controller tableView:controller.tableView
                                cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        UIStepper* stepper = (id)settingControl(cell, @"paragraphSpacing");
        NSString* draft = self.editor.editor.text;
        NSRange selection = self.editor.editor.selectedRange;
        id original = [NSUserDefaults.standardUserDefaults objectForKey:@"paragraphSpacing"];
        stepper.value = 12;
        [stepper sendActionsForControlEvents:UIControlEventValueChanged];
        NSParagraphStyle* paragraph =
            self.editor.editor.typingAttributes[NSParagraphStyleAttributeName];
        valid = valid && stepper && NeonParagraphSpacing() == 12 &&
                paragraph.paragraphSpacing == 12 && [self.editor.editor.text isEqual:draft] &&
                NSEqualRanges(selection, self.editor.editor.selectedRange);
        if (original)
            [NSUserDefaults.standardUserDefaults setObject:original forKey:@"paragraphSpacing"];
        else
            [NSUserDefaults.standardUserDefaults removeObjectForKey:@"paragraphSpacing"];
        controller.preferencesChanged();
        [controller filterSettings:@"no matching setting"];
        valid = valid && controller.visibleSettingCount == 0;
        [controller filterSettings:@""];
        marker(support, @"smoke-settings.txt", valid);
    } else if ([args containsObject:@"--smoke-typography"]) {
        [self.editor typography];
        marker(support, @"smoke-typography.txt", YES);
    } else if ([args containsObject:@"--smoke-menu"]) {
        [self sectionMenu:0
                     host:self.editor
                   anchor:self.editor.view
                     rect:CGRectMake(40, 100, 1, 1)];
        marker(support, @"smoke-menu.txt", YES);
    } else if ([args containsObject:@"--smoke-focus"]) {
        [self toggleChapters];
        marker(support, @"smoke-focus.txt",
               [self.editor.editor.text containsString:@"A native Apple draft."]);
    } else {
        marker(support, @"smoke-reopen.txt",
               [self.editor.editor.text containsString:@"A native Apple draft."]);
    }
}
@end
@interface NeonSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property(nonatomic, strong) UIWindow* window;
@property(nonatomic, strong) NeonCoordinator* coordinator;
@end
@implementation NeonSceneDelegate
- (void)scene:(UIScene*)scene
    willConnectToSession:(UISceneSession*)session
                 options:(UISceneConnectionOptions*)options {
    (void)session;
    (void)options;
    if (![scene isKindOfClass:UIWindowScene.class])
        return;
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene*)scene];
    self.coordinator = [NeonCoordinator new];
    self.window.rootViewController = self.coordinator;
    [self.window makeKeyAndVisible];
    [self.coordinator applyAppearance];
}
- (void)sceneDidEnterBackground:(UIScene*)scene {
    (void)scene;
    [self.coordinator.editor.view endEditing:YES];
    [self.coordinator.editor flush];
}
@end
@interface NeonAppDelegate : UIResponder <UIApplicationDelegate>
@end
@implementation NeonAppDelegate
- (UISceneConfiguration*)application:(UIApplication*)app
    configurationForConnectingSceneSession:(UISceneSession*)session
                                   options:(UISceneConnectionOptions*)options {
    (void)app;
    (void)options;
    UISceneConfiguration* config = [[UISceneConfiguration alloc] initWithName:@"Writing"
                                                                  sessionRole:session.role];
    config.delegateClass = NeonSceneDelegate.class;
    return config;
}
@end
int main(int argc, char* argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(NeonAppDelegate.class));
    }
}
