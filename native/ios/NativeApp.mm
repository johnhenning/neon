#import "ContextMenu.h"
#import "Controls.h"
#import "EditorialTheme.h"
#import "History.h"
#import "InlineTitle.h"
#import "LibraryController.h"
#import "LibraryStore.h"
#import "Preferences.h"
#import "Settings.h"
#import "UITestFixtures.h"
#import "WorkspaceController.h"
#import <UIKit/UIKit.h>

// A navigation link must keep its Figma typography through UIButton state updates.
@interface NeonBreadcrumbButton : NeonButton
@end
@implementation NeonBreadcrumbButton
- (void)setConfiguration:(UIButtonConfiguration*)configuration {
    UIButtonConfiguration* value = [configuration copy];
    value.titleLineBreakMode = NSLineBreakByClipping;
    value.contentInsets = NSDirectionalEdgeInsetsZero;
    value.baseForegroundColor = NeonAccent();
    value.titleTextAttributesTransformer = ^NSDictionary*(NSDictionary* incoming) {
      NSMutableDictionary* attributes = [incoming mutableCopy];
      attributes[NSFontAttributeName] = NeonUI(13);
      attributes[NSForegroundColorAttributeName] = NeonAccent();
      return attributes;
    };
    [super setConfiguration:value];
    self.titleLabel.numberOfLines = 1;
}
@end

namespace {
void quietNavigationActions(UINavigationItem* item) {
    if (@available(iOS 26.0, *)) {
        for (UIBarButtonItem* action in item.leftBarButtonItems)
            action.hidesSharedBackground = YES;
        for (UIBarButtonItem* action in item.rightBarButtonItems)
            action.hidesSharedBackground = YES;
    }
}
NSURL* focusDiagnosticURL() {
    NSURL* support = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                            inDomains:NSUserDomainMask]
                         .firstObject;
    return [support URLByAppendingPathComponent:@"neon-focus-diagnostics.log"];
}
void recordFocusDiagnostic(NSString* message) {
    if (![NSProcessInfo.processInfo.arguments containsObject:@"--ui-testing"])
        return;
    NSFileHandle* file = [NSFileHandle fileHandleForWritingAtPath:focusDiagnosticURL().path];
    if (!file)
        return;
    if ([file seekToEndOfFile] < 65536)
        [file writeData:[[message stringByAppendingString:@"\n"]
                            dataUsingEncoding:NSUTF8StringEncoding]];
    [file closeFile];
}
UIView* focusedView(UIView* root) {
    if (root.isFirstResponder)
        return root;
    for (UIView* child in root.subviews) {
        UIView* match = focusedView(child);
        if (match)
            return match;
    }
    return nil;
}
NSString* focusAncestry(UIView* target) {
    NSMutableArray<NSString*>* chain = [NSMutableArray array];
    for (UIView* view = target; view && chain.count < 20; view = view.superview) {
        NSMutableArray<NSString*>* gestures = [NSMutableArray array];
        for (UIGestureRecognizer* gesture in view.gestureRecognizers)
            [gestures addObject:[NSString stringWithFormat:@"%@:state=%ld:enabled=%d:cancels=%d",
                                                           NSStringFromClass(gesture.class),
                                                           static_cast<NSInteger>(gesture.state),
                                                           gesture.enabled,
                                                           gesture.cancelsTouchesInView]];
        NSString* textFlags = [view isKindOfClass:UITextView.class]
                                  ? [NSString stringWithFormat:@":editable=%d:selectable=%d",
                                                               ((UITextView*)view).editable,
                                                               ((UITextView*)view).selectable]
                                  : @"";
        [chain addObject:[NSString
                             stringWithFormat:
                                 @"%@:interaction=%d:hidden=%d:alpha=%.2f:frame=%@%@:gestures=[%@]",
                                 NSStringFromClass(view.class), view.userInteractionEnabled,
                                 view.hidden, view.alpha, NSStringFromCGRect(view.frame), textFlags,
                                 [gestures componentsJoinedByString:@","]]];
    }
    return [chain componentsJoinedByString:@" -> "];
}
} // namespace
@interface NeonDiagnosticWindow : UIWindow
@property(nonatomic) NSUInteger recordedTouches;
@end
@implementation NeonDiagnosticWindow
- (void)sendEvent:(UIEvent*)event {
    UITouch* touch = event.allTouches.anyObject;
    BOOL record = touch.phase == UITouchPhaseEnded && self.recordedTouches < 40;
    if (record) {
        ++self.recordedTouches;
        recordFocusDiagnostic(
            [NSString stringWithFormat:@"touch ended point=%@ target=%@ responder=%@",
                                       NSStringFromCGPoint([touch locationInView:self]),
                                       focusAncestry(touch.view),
                                       NSStringFromClass(focusedView(self).class)]);
    }
    [super sendEvent:event];
    if (record)
        dispatch_async(dispatch_get_main_queue(), ^{
          recordFocusDiagnostic([NSString
              stringWithFormat:@"after dispatch responder=%@", focusAncestry(focusedView(self))]);
        });
}
@end
// Keep the next simulator failure actionable without changing UIKit focus behavior.
@interface NeonManuscriptView : UITextView
@property(nonatomic) NSUInteger focusDiagnosticCount;
@property(nonatomic, copy) void (^compositionEnded)(void);
@end
@implementation NeonManuscriptView
- (void)unmarkText {
    [super unmarkText];
    if (self.compositionEnded)
        self.compositionEnded();
}
- (CGPoint)accessibilityActivationPoint {
    // UITextView's default point can fall on the rounded top/leading edge when
    // lineFragmentPadding and the top text inset are zero. A tap there hits the
    // controller background instead of the manuscript (see CI touch trace #55).
    // Expose an interior point; UIKit still owns tap recognition and focus.
    CGRect frame = UIAccessibilityConvertFrameToScreenCoordinates(self.bounds, self);
    return CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));
}
- (UIView*)hitTest:(CGPoint)point withEvent:(UIEvent*)event {
    UIView* hit = [super hitTest:point withEvent:event];
    if (event && CGRectContainsPoint(self.bounds, point) && self.focusDiagnosticCount < 8 &&
        [NSProcessInfo.processInfo.arguments containsObject:@"--ui-testing"]) {
        ++self.focusDiagnosticCount;
        NSMutableArray<NSString*>* ancestry = [NSMutableArray array];
        for (UIView* view = hit; view; view = view.superview)
            [ancestry addObject:NSStringFromClass(view.class)];
        NSLog(@"Neon focus hit: point=%@ frame=%@ editable=%d selectable=%d responder=%d "
               "window=%d ancestry=%@",
              NSStringFromCGPoint(point), NSStringFromCGRect(self.frame), self.editable,
              self.selectable, self.isFirstResponder, self.window != nil,
              [ancestry componentsJoinedByString:@" -> "]);
    }
    return hit;
}
@end
// Library is a contained full-workspace destination; the editor's split stack
// stays intact until a successful document open or an explicit Library return.
@interface NeonLibraryShell : UIViewController
@property(nonatomic, strong) NeonLibraryController* library;
@property(nonatomic, strong) UINavigationBar* bar;
@property(nonatomic, strong) UIStackView* filters;
@property(nonatomic, strong) NSMutableArray<NeonButton*>* filterButtons;
- (void)refreshNavigation;
@end
@implementation NeonLibraryShell
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = NeonPaper();
    self.view.accessibilityViewIsModal = YES;
    self.bar = [UINavigationBar new];
    UINavigationItem* item = [[UINavigationItem alloc] initWithTitle:@"Neon"];
    item.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    [self.bar setItems:@[ item ]];
    [self.view addSubview:self.bar];
    [self addChildViewController:self.library];
    [self.view addSubview:self.library.view];
    [self.library didMoveToParentViewController:self];
    self.filters = [UIStackView new];
    self.filters.axis = UILayoutConstraintAxisVertical;
    self.filters.spacing = 8;
    self.filters.layoutMarginsRelativeArrangement = YES;
    self.filters.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(24, 16, 24, 16);
    self.filterButtons = [NSMutableArray array];
    __weak NeonLibraryShell* weak = self;
    NSArray* titles = @[ @"All projects", @"Recent", @"Favorites", @"On this device", @"Trash" ];
    for (NSUInteger i = 0; i < titles.count; ++i) {
        NeonButton* button = [NeonLibraryController navigationButtonForFilter:(NeonLibraryFilter)i];
        button.kind = NeonButtonSelection;
        [button setTitle:titles[i] forState:UIControlStateNormal];
        button.accessibilityLabel = titles[i];
        button.imageView.isAccessibilityElement = NO;
        button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
        [button.heightAnchor constraintGreaterThanOrEqualToConstant:NeonMinimumTouchTarget].active =
            YES;
        [button addAction:[UIAction actionWithHandler:^(__kindof UIAction* action) {
                  (void)action;
                  [weak.library selectFilter:(NeonLibraryFilter)i];
                }]
            forControlEvents:UIControlEventTouchUpInside];
        [self.filters addArrangedSubview:button];
        [self.filterButtons addObject:button];
    }
    [self.filters addArrangedSubview:[UIView new]];
    [self.view addSubview:self.filters];
    [self refreshNavigation];
}
- (void)refreshNavigation {
    if (!self.isViewLoaded)
        return;
    UINavigationBarAppearance* appearance = [UINavigationBarAppearance new];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = NeonPanel();
    appearance.titleTextAttributes =
        @{NSFontAttributeName : NeonUI(13), NSForegroundColorAttributeName : NeonInk()};
    self.bar.standardAppearance = appearance;
    self.bar.scrollEdgeAppearance = appearance;
    self.bar.tintColor = NeonMuted();
    self.filters.backgroundColor = NeonPanel();
    __weak NeonLibraryShell* weak = self;
    UIDeferredMenuElement* currentMenu = [UIDeferredMenuElement
        elementWithUncachedProvider:^(void (^completion)(NSArray<UIMenuElement*>*)) {
          completion([weak.library navigationMenu].children ?: @[]);
        }];
    self.bar.topItem.rightBarButtonItems =
        @[ [[UIBarButtonItem alloc] initWithTitle:@"•••"
                                             menu:[UIMenu menuWithChildren:@[ currentMenu ]]] ];
    self.bar.topItem.rightBarButtonItems.firstObject.accessibilityLabel = @"Library actions";
    quietNavigationActions(self.bar.topItem);
    for (NSUInteger i = 0; i < self.filterButtons.count; ++i)
        self.filterButtons[i].chosen = self.library.query.filter == static_cast<NSInteger>(i);
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    quietNavigationActions(self.navigationItem);
    UIEdgeInsets safe = self.view.safeAreaInsets;
    CGFloat width = self.view.bounds.size.width - safe.left - safe.right;
    CGFloat top = safe.top;
    CGFloat height = MAX(0, self.view.bounds.size.height - top - safe.bottom - 56);
    BOOL wide = width >= 1000 && width > self.view.bounds.size.height;
    CGFloat sidebar = wide ? 248 : 0;
    self.bar.frame = CGRectMake(safe.left, top, width, 56);
    self.filters.hidden = !wide;
    self.filters.frame = CGRectMake(safe.left, top + 56, sidebar, height);
    self.library.usesSidebarNavigation = wide;
    self.library.view.frame = CGRectMake(safe.left + sidebar, top + 56, width - sidebar, height);
}
@end
@class NeonCoordinator;
@interface NeonEditor : NeonWorkspaceController <UITextViewDelegate>
@property(nonatomic, strong) UITextView* editor;
@property(nonatomic, strong) UILabel* status;
@property(nonatomic, strong) UILabel* guidance;
@property(nonatomic, strong) NeonChapterHeading* heading;
@property(nonatomic, strong) UIStackView* chapterHeader;
@property(nonatomic, strong) UILabel* chapterKicker;
@property(nonatomic) BOOL wideTypography;
@property(nonatomic, copy) NSString* lastLayoutDiagnostic;
@property(nonatomic) BOOL typographyPending;
@property(nonatomic) BOOL typographyRetryScheduled;
@property(nonatomic, strong) NSLayoutConstraint* headingHeight;
@property(nonatomic) BOOL focusMode;
@property(nonatomic) BOOL returnToManuscript;
@property(nonatomic) BOOL sidebarBeforeFocus;
@property(nonatomic, strong) NSArray<UIBarButtonItem*>* writingActions;
@property(nonatomic, strong) NeonInlineTitle* bookTitle;
@property(nonatomic, strong) NeonDocumentSession* session;
@property(nonatomic, weak) NeonCoordinator* coordinator;
@property(nonatomic, strong) NSTimer* saveTimer;
- (BOOL)flush;
- (void)applyTypography;
- (void)scheduleTypographyRetry;
@end
@interface NeonList : UITableViewController
@property(nonatomic, strong) UIStackView* navigationHeader;
@property(nonatomic, strong) UILabel* navigationProjectTitle;
@property(nonatomic, strong) UILabel* navigationProjectCount;
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
@property(nonatomic, strong) NeonHistoryController* historyController;
@property(nonatomic, strong) NeonEditor* historyEditor;
@property(nonatomic, strong) NeonDocumentSession* historySession;
@property(nonatomic, copy) NSString* historySection;
@property(nonatomic, strong) NeonList* libraryList;
@property(nonatomic, strong) NeonLibraryController* libraryController;
@property(nonatomic, strong) NeonLibraryShell* libraryShell;
@property(nonatomic, strong) NeonList* chapterList;
@property(nonatomic, strong) UINavigationController* navigation;
@property(nonatomic) BOOL sidebarHidden;
@property(nonatomic) BOOL sidebarLayoutInitialized;
@property(nonatomic) BOOL sidebarChoiceExplicit;
@property(nonatomic) BOOL narrowSidebarLayout;
@property(nonatomic, strong) UIView* navigationSnapshot;
@property(nonatomic) BOOL renderingNavigation;
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
- (void)showLibraryShell;
- (void)hideLibraryShell;
- (void)libraryAction:(NSString*)action record:(NSDictionary*)record;
- (void)openProject:(NSInteger)index;
- (void)openSection:(NSInteger)index;
- (void)newProject;
- (void)newSection;
- (void)toggleChapters;
- (void)toggleSidebarVisibility;
- (void)updateNavigationControls;
- (void)showProblem:(NSError*)error;
- (void)applyAppearance;
- (void)showSettings;
- (void)showHistory;
- (void)showCurrentEditor;
- (void)showDestination:(NeonWorkspaceDestination)destination sectionID:(NSString*)sectionID;
- (BOOL)renameInline:(NSString*)title section:(NSString*)identifier;
@end
namespace {
UIImage* workspaceIcon(NSString* name) {
    NSString* path = [NSBundle.mainBundle pathForResource:name ofType:@"png" inDirectory:@"icons"];
    UIImage* pixels = [UIImage imageWithContentsOfFile:path];
    return [[UIImage imageWithCGImage:pixels.CGImage scale:3 orientation:UIImageOrientationUp]
        imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}
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
BOOL breadcrumbFits(UIViewController* editor) {
    [editor.navigationController.view layoutIfNeeded];
    UIStackView* stack = (UIStackView*)editor.navigationItem.titleView;
    UIButton* library = (UIButton*)stack.arrangedSubviews.firstObject;
    CGFloat textWidth = [@"Library" sizeWithAttributes:@{NSFontAttributeName : NeonUI(13)}].width;
    return library.titleLabel.numberOfLines == 1 &&
           library.titleLabel.bounds.size.width >= textWidth - 1 &&
           library.bounds.size.height >= NeonMinimumTouchTarget &&
           fabs(library.titleLabel.font.pointSize - 13) < .1 &&
           CGRectGetMaxX(library.frame) <= CGRectGetMinX(stack.arrangedSubviews[1].frame);
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
    self.bookTitle.font = NeonUI(13);
    self.bookTitle.textAlignment = NSTextAlignmentLeft;
    self.bookTitle.accessibilityLabel = @"Project title";
    self.bookTitle.commitTitle = ^BOOL(NSString* title) {
      return [weakSelf.coordinator renameInline:title section:nil];
    };
    NeonButton* library = [NeonBreadcrumbButton buttonWithType:UIButtonTypeSystem];
    library.kind = NeonButtonQuiet;
    [library setTitle:@"Library" forState:UIControlStateNormal];
    library.accessibilityIdentifier = @"editor-library-breadcrumb";
    [library setContentCompressionResistancePriority:UILayoutPriorityRequired
                                             forAxis:UILayoutConstraintAxisHorizontal];
    [library setContentHuggingPriority:UILayoutPriorityRequired
                               forAxis:UILayoutConstraintAxisHorizontal];
    [library addTarget:self.coordinator
                  action:@selector(showLibrary)
        forControlEvents:UIControlEventTouchUpInside];
    [library.widthAnchor constraintGreaterThanOrEqualToConstant:NeonMinimumTouchTarget].active =
        YES;
    UILabel* separator = label(@"›", NeonUI(13), NeonMuted());
    separator.numberOfLines = 1;
    [separator setContentCompressionResistancePriority:UILayoutPriorityRequired
                                               forAxis:UILayoutConstraintAxisHorizontal];
    UIStackView* breadcrumb =
        [[UIStackView alloc] initWithArrangedSubviews:@[ library, separator, self.bookTitle ]];
    breadcrumb.spacing = NeonBreadcrumbGap;
    breadcrumb.alignment = UIStackViewAlignmentCenter;
    [self.bookTitle setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                    forAxis:UILayoutConstraintAxisHorizontal];
    self.navigationItem.titleView = breadcrumb;
    self.view.backgroundColor = NeonPaper();
    self.view.tintColor = NeonAccent();
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    UIBarButtonItem* history = [[UIBarButtonItem alloc] initWithImage:workspaceIcon(@"history")
                                                                style:UIBarButtonItemStylePlain
                                                               target:self.coordinator
                                                               action:@selector(showHistory)];
    history.accessibilityLabel = @"Version history";
    self.navigationItem.rightBarButtonItems = @[
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(actions)],
        history
    ];
    self.routeDestination = ^BOOL(NeonWorkspaceDestination destination, NSString* sectionID) {
      if (destination != NeonWorkspaceDestinationManuscript &&
          destination != NeonWorkspaceDestinationHistory)
          return NO;
      [weakSelf.coordinator showDestination:destination sectionID:sectionID];
      return YES;
    };
    self.writingActions = self.navigationItem.rightBarButtonItems;
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
                            NeonUI(13), NeonAccent());
    self.chapterKicker = kicker;
    kicker.textAlignment = ![self.session.preset[@"id"] isEqual:@"book"] &&
                                   [self.session.preset[@"centeredHeading"] boolValue]
                               ? NSTextAlignmentCenter
                               : NSTextAlignmentLeft;
    self.heading = [NeonChapterHeading new];
    self.heading.text = self.session.sectionTitle;
    self.heading.font = scaledSerif(24);
    self.heading.adjustsFontForContentSizeCategory = YES;
    self.heading.accessibilityLabel =
        [self.session.preset[@"sectionLabel"] stringByAppendingString:@" title"];
    NSString* identifier = self.session.selectedSectionID;
    if (identifier.length)
        self.heading.commitTitle = ^BOOL(NSString* title) {
          return [weakSelf.coordinator renameInline:title section:identifier];
        };
    self.heading.textAlignment = kicker.textAlignment;
    NSMutableArray* headerViews = [NSMutableArray arrayWithArray:@[ kicker, self.heading ]];
    if (!self.session.text.length && self.session.sectionGuidance.length) {
        self.guidance = label(self.session.sectionGuidance, NeonUI(12), NeonMuted());
        [headerViews addObject:self.guidance];
    }
    UIStackView* header = [[UIStackView alloc] initWithArrangedSubviews:headerViews];
    header.axis = UILayoutConstraintAxisVertical;
    header.alignment = UIStackViewAlignmentCenter;
    header.spacing = 20;
    self.chapterHeader = header;
    self.heading.heightChanged = ^{
      [weakSelf scheduleTypographyRetry];
      [weakSelf.view setNeedsLayout];
    };
    self.headingHeight = [self.heading.heightAnchor constraintEqualToConstant:34];
    self.headingHeight.active = YES;
    [self.heading.widthAnchor constraintEqualToAnchor:header.widthAnchor].active = YES;
    [kicker.widthAnchor constraintEqualToAnchor:header.widthAnchor].active = YES;
    if (self.guidance)
        [self.guidance.widthAnchor constraintEqualToAnchor:header.widthAnchor].active = YES;
    NeonManuscriptView* manuscript = [NeonManuscriptView new];
    manuscript.compositionEnded = ^{
      [weakSelf scheduleTypographyRetry];
    };
    self.editor = manuscript;
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
    // One native scroll surface retains selection, undo and marked-text ownership.
    [self.editor addSubview:header];
    UIView* footer = [UIView new];
    footer.backgroundColor = NeonPanel();
    UILabel* mode = label(@"Write", NeonUI(13), NeonMuted());
    [footer addSubview:self.status];
    [footer addSubview:mode];
    for (UIView* child in @[ self.editor, footer, self.status, mode, self.sessionSlot ])
        child.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.editor];
    [self.view addSubview:self.sessionSlot];
    [self.view addSubview:footer];
    UILayoutGuide* safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.editor.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [self.editor.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [self.editor.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [self.editor.bottomAnchor constraintEqualToAnchor:self.sessionSlot.topAnchor],
        [self.sessionSlot.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [self.sessionSlot.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [self.sessionSlot.heightAnchor constraintEqualToConstant:NeonMinimumTouchTarget],
        [self.sessionSlot.bottomAnchor constraintEqualToAnchor:footer.topAnchor],
        [footer.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [footer.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [footer.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor],
        [footer.heightAnchor constraintGreaterThanOrEqualToConstant:40],
        [self.status.leadingAnchor constraintEqualToAnchor:footer.leadingAnchor constant:12],
        [self.status.topAnchor constraintEqualToAnchor:footer.topAnchor constant:10],
        [self.status.bottomAnchor constraintEqualToAnchor:footer.bottomAnchor constant:-10],
        [self.status.trailingAnchor constraintLessThanOrEqualToAnchor:mode.leadingAnchor
                                                             constant:-8],
        [mode.trailingAnchor constraintEqualToAnchor:footer.trailingAnchor constant:-12],
        [mode.centerYAnchor constraintEqualToAnchor:footer.centerYAnchor]
    ]];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(contentSizeChanged:)
                                               name:UIContentSizeCategoryDidChangeNotification
                                             object:nil];
    [self applyTypography];
}
- (void)contentSizeChanged:(NSNotification*)notification {
    (void)notification;
    [self applyTypography];
    [self.view setNeedsLayout];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    quietNavigationActions(self.navigationItem);
    CGSize viewport = self.view.window.bounds.size;
    BOOL wide = viewport.width >= 1000 && viewport.width > viewport.height;
    if (self.wideTypography != wide) {
        self.wideTypography = wide;
        [self applyTypography];
        [self updateWritingToolbar];
    }
    CGFloat measure =
        [NeonPreferences() objectForKey:@"textMeasure"] ? NeonTextMeasure() : (wide ? 640 : 680);
    CGFloat margin = MAX(24, (self.editor.bounds.size.width - measure) / 2);
    CGFloat width = MAX(1, self.editor.bounds.size.width - 2 * margin);
    self.chapterHeader.spacing = self.focusMode ? 16 : (wide ? 24 : 20);
    CGFloat top = wide ? 48 : 24;
    self.headingHeight.constant =
        ceil([self.heading sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height);
    CGSize headerSize =
        [self.chapterHeader systemLayoutSizeFittingSize:CGSizeMake(width, 0)
                          withHorizontalFittingPriority:UILayoutPriorityRequired
                                verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    self.chapterHeader.frame = CGRectMake(margin, top, width, headerSize.height);
    self.editor.textContainerInset =
        UIEdgeInsetsMake(top + headerSize.height + self.chapterHeader.spacing, margin,
                         NeonScrollBottomClearance, margin);
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--ui-testing"]) {
        NSParagraphStyle* style = self.editor.typingAttributes[NSParagraphStyleAttributeName];
        NSString* diagnostic = [NSString
            stringWithFormat:@"layout viewport=%@ category=%@ bodyFont=%.2f leading=%.2f "
                             @"measure=%.2f headingFont=%.2f editorWidth=%.2f margin=%.2f",
                             NSStringFromCGSize(viewport),
                             self.wideTypography ? @"wide" : @"portrait-or-compact",
                             self.editor.font.pointSize, style.minimumLineHeight, measure,
                             self.heading.font.pointSize, self.editor.bounds.size.width, margin];
        if (![diagnostic isEqual:self.lastLayoutDiagnostic]) {
            recordFocusDiagnostic(diagnostic);
            self.lastLayoutDiagnostic = diagnostic;
        }
    }
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:YES animated:animated];
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self flush];
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;
}
- (void)scheduleTypographyRetry {
    if (!self.typographyPending || self.typographyRetryScheduled)
        return;
    self.typographyRetryScheduled = YES;
    __weak NeonEditor* weakSelf = self;
    // UIKit may clear markedTextRange after its delegate notification. Retry once
    // at the next event boundary; later input callbacks retry if still composing.
    dispatch_async(dispatch_get_main_queue(), ^{
      NeonEditor* editor = weakSelf;
      editor.typographyRetryScheduled = NO;
      if (editor.typographyPending && editor.session && !editor.editor.markedTextRange &&
          !editor.heading.markedTextRange)
          [editor applyTypography];
    });
}
- (void)applyTypography {
    if (!self.editor)
        return;
    if (self.editor.markedTextRange || self.heading.markedTextRange) {
        self.typographyPending = YES;
        return;
    }
    self.typographyPending = NO;
    NSRange selection = self.editor.selectedRange;
    NSMutableParagraphStyle* style = [NSMutableParagraphStyle new];
    BOOL explicitSize = [NeonPreferences() objectForKey:@"manuscriptSize"] != nil;
    CGFloat size = explicitSize ? NeonTextSize() : (self.wideTypography ? 20 : 18);
    UIFont* bodyFont = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:([NeonPreferences() objectForKey:@"manuscriptFont"]
                               ? NeonManuscriptFont(size)
                               : NeonFontNamed(self.session.preset[@"font"], size))];
    BOOL legacySpacing = [NeonPreferences() objectForKey:@"manuscriptSpacing"] != nil;
    style.lineSpacing = legacySpacing ? NeonLineSpacing() : 0;
    CGFloat presetMultiple = [self.session.preset[@"lineHeightMultiple"] doubleValue];
    if (!legacySpacing && presetMultiple <= 1) {
        CGFloat leading = bodyFont.pointSize * (self.wideTypography ? 34.0 / 20 : 30.0 / 18);
        style.minimumLineHeight = leading;
        style.maximumLineHeight = leading;
    }
    UIFont* headingFont = scaledSerif(self.wideTypography ? 32 : 24);
    NSMutableParagraphStyle* headingStyle = [NSMutableParagraphStyle new];
    CGFloat headingLeading = headingFont.pointSize * (self.wideTypography ? 44.0 / 32 : 34.0 / 24);
    headingStyle.minimumLineHeight = headingLeading;
    headingStyle.maximumLineHeight = headingLeading;
    headingStyle.alignment = self.heading.textAlignment;
    if (!self.heading.markedTextRange) {
        NSDictionary* headingAttributes = @{
            NSFontAttributeName : headingFont,
            NSForegroundColorAttributeName : NeonInk(),
            NSParagraphStyleAttributeName : headingStyle
        };
        [self.heading.textStorage addAttributes:headingAttributes
                                          range:NSMakeRange(0, self.heading.text.length)];
        self.heading.typingAttributes = headingAttributes;
        self.heading.font = headingFont;
    }
    BOOL book = [self.session.preset[@"id"] isEqual:@"book"];
    style.paragraphSpacing = [NeonPreferences() objectForKey:@"paragraphSpacing"]
                                 ? NeonParagraphSpacing()
                                 : (book ? (self.wideTypography ? 24 : 20)
                                         : [self.session.preset[@"paragraphSpacing"] doubleValue]);
    style.lineHeightMultiple = (legacySpacing || presetMultiple > 1) ? presetMultiple : 0;
    style.firstLineHeadIndent = book ? 0 : [self.session.preset[@"firstLineIndent"] doubleValue];
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
        NSFontAttributeName : bodyFont,
        NSForegroundColorAttributeName : NeonInk(),
        NSParagraphStyleAttributeName : style
    };
    [self.editor.textStorage addAttributes:attrs range:NSMakeRange(0, self.editor.text.length)];
    self.editor.typingAttributes = attrs;
    self.editor.selectedRange = selection;
    self.editor.font = bodyFont;
}
- (void)textViewDidBeginEditing:(UITextView*)view {
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--ui-testing"])
        NSLog(@"Neon focus began: editable=%d responder=%d window=%d frame=%@", view.editable,
              view.isFirstResponder, view.window != nil, NSStringFromCGRect(view.frame));
}
- (void)textViewDidChangeSelection:(UITextView*)view {
    (void)view;
    [self scheduleTypographyRetry];
}
- (void)textViewDidEndEditing:(UITextView*)view {
    (void)view;
    [self scheduleTypographyRetry];
}
- (void)textViewDidChange:(UITextView*)view {
    [self scheduleTypographyRetry];
    if (view.markedTextRange)
        return;
    NSError* error = nil;
    if (![self.session replaceText:view.text error:&error]) {
        self.status.text = error.localizedDescription;
        return;
    }
    self.guidance.hidden = view.text.length > 0;
    [self.view setNeedsLayout];
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
- (void)updateWritingToolbar {
    if (self.focusMode)
        return;
    if (self.wideTypography && self.writingActions.count == 2) {
        UIBarButtonItem* typography =
            [[UIBarButtonItem alloc] initWithTitle:@"Aa"
                                             style:UIBarButtonItemStylePlain
                                            target:self
                                            action:@selector(typography)];
        typography.accessibilityLabel = @"Typography";
        UIBarButtonItem* search = [[UIBarButtonItem alloc] initWithTitle:@"Search"
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:nil
                                                                  action:nil];
        search.enabled = NO;
        search.accessibilityHint = @"Unavailable in this version";
        self.navigationItem.rightBarButtonItems = @[
            self.writingActions.firstObject, typography, search, self.writingActions.lastObject
        ];
    } else {
        self.navigationItem.rightBarButtonItems = self.writingActions;
    }
}
- (void)toggleFocusMode {
    self.focusMode = !self.focusMode;
    [self.chapterHeader removeArrangedSubview:self.chapterKicker];
    [self.chapterHeader insertArrangedSubview:self.chapterKicker atIndex:self.focusMode ? 1 : 0];
    if (self.focusMode) {
        self.returnToManuscript = self.editor.isFirstResponder;
        self.sidebarBeforeFocus = !self.coordinator.collapsed && !self.coordinator.sidebarHidden;
        if (self.sidebarBeforeFocus)
            [self.coordinator toggleSidebarVisibility];
    } else if (self.returnToManuscript) {
        [self.editor becomeFirstResponder];
    }
    if (self.focusMode) {
        self.navigationItem.rightBarButtonItems =
            @[ [[UIBarButtonItem alloc] initWithTitle:@"Exit focus"
                                                style:UIBarButtonItemStylePlain
                                               target:self
                                               action:@selector(toggleFocusMode)] ];
    } else {
        [self updateWritingToolbar];
        if (self.sidebarBeforeFocus && self.coordinator.sidebarHidden)
            [self.coordinator toggleSidebarVisibility];
    }
    [self.view setNeedsLayout];
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
            NeonAction(self.focusMode ? @"Leave Focus Mode" : @"Focus Mode", @"viewfinder", YES, NO,
                       ^{
                         [self toggleFocusMode];
                       }),
            NeonAction(@"Typography", @"textformat", YES, NO,
                       ^{
                         [self typography];
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
    [NeonPreferences() setObject:sender.accessibilityIdentifier forKey:@"manuscriptFont"];
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
    [NeonPreferences() setDouble:sender.value forKey:@"manuscriptSize"];
    [self.editor applyTypography];
}
- (void)spacingChanged:(UISlider*)sender {
    [NeonPreferences() setDouble:sender.value forKey:@"manuscriptSpacing"];
    [self.editor applyTypography];
}
- (void)appearanceChanged:(UISegmentedControl*)sender {
    [NeonPreferences() setInteger:sender.selectedSegmentIndex forKey:@"appearance"];
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
    self.tableView.estimatedRowHeight = self.chapters ? 52 : 142;
    self.tableView.separatorStyle =
        self.chapters ? UITableViewCellSeparatorStyleSingleLine : UITableViewCellSeparatorStyleNone;
    self.tableView.separatorColor = [NeonInk() colorWithAlphaComponent:0.16];
    self.tableView.separatorInset = UIEdgeInsetsZero;
    self.tableView.separatorInsetReference = UITableViewSeparatorInsetFromCellEdges;
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
    self.navigationItem.rightBarButtonItems.firstObject.title = @"Settings";
    if (self.chapters) {
        UIBarButtonItem* history = [[UIBarButtonItem alloc] initWithImage:workspaceIcon(@"history")
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(history)];
        history.accessibilityLabel = @"Version history";
        self.navigationItem.rightBarButtonItems =
            [self.navigationItem.rightBarButtonItems arrayByAddingObject:history];
    }
    UILongPressGestureRecognizer* hold =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(context:)];
    [self.tableView addGestureRecognizer:hold];
    UITapGestureRecognizer* secondary =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(context:)];
    secondary.buttonMaskRequired = UIEventButtonMaskSecondary;
    // A right-click recognizer must not consume ordinary finger taps.
    secondary.allowedTouchTypes = @[ @(UITouchTypeIndirectPointer) ];
    [self.tableView addGestureRecognizer:secondary];
    if (self.chapters)
        self.navigationItem.leftBarButtonItem =
            [[UIBarButtonItem alloc] initWithTitle:@"Library"
                                             style:UIBarButtonItemStylePlain
                                            target:self
                                            action:@selector(library)];
    if (self.chapters) {
        self.title = @"Project navigation";
        UIBarButtonItem* add = [[UIBarButtonItem alloc]
            initWithTitle:[@"+ Add " stringByAppendingString:[self.coordinator.session
                                                                     .preset[@"sectionLabel"]
                                                                 lowercaseString]]
                    style:UIBarButtonItemStylePlain
                   target:self
                   action:@selector(create)];
        UIBarButtonItem* trash =
            [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"trash"]
                                             style:UIBarButtonItemStylePlain
                                            target:self
                                            action:@selector(trash)];
        trash.accessibilityLabel = @"Deleted chapters";
        self.toolbarItems = @[
            add,
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                          target:nil
                                                          action:nil],
            trash
        ];
        UIBarButtonItem* settings =
            [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"gearshape"]
                                             style:UIBarButtonItemStylePlain
                                            target:self
                                            action:@selector(settings)];
        settings.title = @"Settings";
        settings.accessibilityLabel = @"Settings";
        self.navigationItem.rightBarButtonItems = @[
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose
                                                          target:self.coordinator
                                                          action:@selector(showCurrentEditor)],
            settings
        ];
        UILabel* project = label(self.coordinator.session.title, scaledSerif(24), NeonInk());
        UILabel* count = label(
            [NSString stringWithFormat:@"%@ · %lu %@ · %lu words",
                                       [self.coordinator.session.preset[@"title"] uppercaseString],
                                       self.coordinator.session.sections.count,
                                       [self.coordinator.session.preset[@"sectionsLabel"]
                                           lowercaseString],
                                       self.coordinator.session.projectWordCount],
            NeonUI(13), NeonMuted());
        self.navigationProjectTitle = project;
        self.navigationProjectCount = count;
        NSMutableArray<UIView*>* items = [NSMutableArray arrayWithArray:@[ project, count ]];
        for (NSString* destination in
             @[ @"Manuscript", @"Notes & research", @"Outline", @"Writing goals" ]) {
            NeonButton* button = [NeonButton buttonWithType:UIButtonTypeSystem];
            button.kind = NeonButtonSecondary;
            [button setTitle:destination forState:UIControlStateNormal];
            button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
            button.enabled = [destination isEqual:@"Manuscript"];
            if (button.enabled)
                [button addTarget:self.coordinator
                              action:@selector(showCurrentEditor)
                    forControlEvents:UIControlEventTouchUpInside];
            else
                button.accessibilityHint = @"Unavailable in this version";
            [button.heightAnchor constraintGreaterThanOrEqualToConstant:48].active = YES;
            [items addObject:button];
        }
        self.navigationHeader = [[UIStackView alloc] initWithArrangedSubviews:items];
        self.navigationHeader.axis = UILayoutConstraintAxisVertical;
        self.navigationHeader.spacing = 16;
        self.navigationHeader.layoutMarginsRelativeArrangement = YES;
        self.navigationHeader.directionalLayoutMargins =
            NSDirectionalEdgeInsetsMake(24, 20, 24, 20);
        self.tableView.tableHeaderView = self.navigationHeader;
    }
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    quietNavigationActions(self.navigationItem);
    if (self.navigationHeader) {
        CGFloat width = self.tableView.bounds.size.width;
        CGSize size =
            [self.navigationHeader systemLayoutSizeFittingSize:CGSizeMake(width, 0)
                                 withHorizontalFittingPriority:UILayoutPriorityRequired
                                       verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
        if (!CGSizeEqualToSize(self.navigationHeader.frame.size, size)) {
            self.navigationHeader.frame = CGRectMake(0, 0, width, size.height);
            self.tableView.tableHeaderView = self.navigationHeader;
        }
    }
}
- (void)settings {
    [self.coordinator showSettings];
}
- (void)history {
    [self.coordinator showHistory];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:!self.chapters animated:animated];
    if (self.chapters)
        self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    if (self.chapters) {
        self.navigationProjectTitle.text = self.coordinator.session.title;
        self.navigationProjectCount.text = [NSString
            stringWithFormat:@"%@ · %lu %@ · %lu words",
                             [self.coordinator.session.preset[@"title"] uppercaseString],
                             self.coordinator.session.sections.count,
                             [self.coordinator.session.preset[@"sectionsLabel"] lowercaseString],
                             self.coordinator.session.projectWordCount];
        [self.view setNeedsLayout];
    }
    if (!self.chapters)
        [self.coordinator reloadLibrary];
    [self.tableView reloadData];
    [self.coordinator updateNavigationControls];
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
    [[cell.contentView viewWithTag:902] removeFromSuperview];
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
        title.font = NeonUI(14);
        BOOL current = [identifier isEqual:self.coordinator.session.selectedSectionID];
        title.textColor = current ? NeonAccent() : NeonInk();
        cell.accessibilityTraits =
            current ? UIAccessibilityTraitSelected : UIAccessibilityTraitNone;
        cell.separatorInset = UIEdgeInsetsZero;
        // Persist the active section even when reloadData clears UIKit selection.
        UIView* background = [UIView new];
        background.backgroundColor = current ? NeonSelection() : UIColor.clearColor;
        cell.backgroundView = background;
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
        UILabel* number = label([self.coordinator.session.preset[@"id"] isEqual:@"book"]
                                    ? [NSString stringWithFormat:@"%02ld", (long)path.row + 1]
                                    : @"",
                                NeonUI(14), current ? NeonAccent() : NeonInk());
        UIStackView* row = [[UIStackView alloc] initWithArrangedSubviews:@[ number, title ]];
        row.axis = UILayoutConstraintAxisHorizontal;
        row.alignment = UIStackViewAlignmentCenter;
        row.spacing = 8;
        row.tag = 901;
        row.translatesAutoresizingMaskIntoConstraints = NO;
        [number setContentHuggingPriority:UILayoutPriorityRequired
                                  forAxis:UILayoutConstraintAxisHorizontal];
        [cell.contentView addSubview:row];
        [NSLayoutConstraint activateConstraints:@[
            [row.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
            [row.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor
                                               constant:-8],
            [row.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:4],
            [row.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-4],
            [title.heightAnchor constraintGreaterThanOrEqualToConstant:NeonMinimumTouchTarget]
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
        self.preferredSplitBehavior = UISplitViewControllerSplitBehaviorTile;
        self.displayModeButtonVisibility = UISplitViewControllerDisplayModeButtonVisibilityNever;
        self.presentsWithGesture = NO;
        self.preferredPrimaryColumnWidthFraction = 0.24;
        self.minimumPrimaryColumnWidth = 220;
        self.maximumPrimaryColumnWidth = 290;
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    NeonRegisterFonts();
    self.view.tintColor = NeonAccent();
    NSArray* args = NSProcessInfo.processInfo.arguments;
    self.smoke = [args containsObject:@"--smoke-test"];
    BOOL uiTesting = [args containsObject:@"--ui-testing"];
    BOOL reopen =
        [args containsObject:@"--smoke-reopen"] || [args containsObject:@"--smoke-library"] ||
        [args containsObject:@"--smoke-focus"] || [args containsObject:@"--smoke-typography"] ||
        [args containsObject:@"--smoke-menu"] || [args containsObject:@"--smoke-settings"] ||
        [args containsObject:@"--smoke-history"] || [args containsObject:@"--smoke-preset"];
    NSURL* support = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                            inDomains:NSUserDomainMask]
                         .firstObject;
    NSURL* directory = [support URLByAppendingPathComponent:(self.smoke || reopen || uiTesting)
                                                                ? @"SmokeLibrary"
                                                                : @"Neon Apple Preview"];
    if (self.smoke || uiTesting)
        [[NSFileManager defaultManager] removeItemAtURL:directory error:nil];
    self.library = [[NeonLibraryStore alloc] initWithDirectory:directory];
    NSError* error = nil;
    if (uiTesting) {
        if (!NeonSeedUITestLibrary(self.library, &error))
            [self showProblem:error];
    } else if (self.smoke && ![self.library seedPreview:&error]) {
        [self showProblem:error];
    }
    self.libraryList = [[NeonList alloc] initWithStyle:UITableViewStyleInsetGrouped];
    self.libraryList.coordinator = self;
    self.libraryController = [NeonLibraryController new];
    self.libraryController.fixtureIDs = NeonUITestFixtureIDs();
    __weak NeonCoordinator* weakSelf = self;
    self.libraryController.onFilterChanged = ^(NeonLibraryFilter filter) {
      weakSelf.trashMode = filter == NeonLibraryTrash;
      [weakSelf reloadLibrary];
    };
    self.libraryController.onAction = ^(NSString* action, NSDictionary* record) {
      [weakSelf libraryAction:action record:record];
    };
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
    [self setViewController:[[UINavigationController alloc] initWithRootViewController:welcome]
                  forColumn:UISplitViewControllerColumnSecondary];
    [NSNotificationCenter.defaultCenter
        addObserver:self
           selector:@selector(accessibilityChanged:)
               name:UIAccessibilityReduceTransparencyStatusDidChangeNotification
             object:nil];
    [self reloadLibrary];
    [self applyAppearance];
    [self showLibraryShell];
    if (self.smoke || reopen)
        dispatch_async(dispatch_get_main_queue(), ^{
          [self runSmoke:args support:support];
        });
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    quietNavigationActions(self.navigationItem);
    if (self.libraryShell.parentViewController == self) {
        self.libraryShell.view.frame = self.view.bounds;
        [self.view bringSubviewToFront:self.libraryShell.view];
    }
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self updateNavigationControls];
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
    [self.libraryShell refreshNavigation];
    [self reloadLibrary];
    [self updateNavigationControls];
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
- (void)showLibraryShell {
    if (self.session)
        return;
    if (!self.libraryShell) {
        self.libraryShell = [NeonLibraryShell new];
        self.libraryShell.library = self.libraryController;
    }
    if (!self.libraryShell.parentViewController) {
        [self addChildViewController:self.libraryShell];
        self.libraryShell.view.frame = self.view.bounds;
        self.libraryShell.view.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.view addSubview:self.libraryShell.view];
        [self.libraryShell didMoveToParentViewController:self];
    }
    [self.view bringSubviewToFront:self.libraryShell.view];
    for (UIViewController* child in self.childViewControllers)
        if (child != self.libraryShell)
            child.view.accessibilityElementsHidden = YES;
    [self.libraryShell refreshNavigation];
}
- (void)hideLibraryShell {
    [self.libraryShell willMoveToParentViewController:nil];
    [self.libraryShell.view removeFromSuperview];
    [self.libraryShell removeFromParentViewController];
    for (UIViewController* child in self.childViewControllers)
        child.view.accessibilityElementsHidden = NO;
}
- (void)libraryAction:(NSString*)action record:(NSDictionary*)record {
    if ([action isEqual:@"new"]) {
        [self newProject];
        return;
    }
    if ([action isEqual:@"settings"]) {
        [self showSettings];
        return;
    }
    if (!record[@"projectID"] || !record[@"url"])
        return;
    if ([action isEqual:@"favorite"]) {
        [self.library setFavorite:![record[@"favorite"] boolValue] projectID:record[@"projectID"]];
        [self reloadLibrary];
        return;
    }
    if ([action isEqual:@"open"]) {
        NSUInteger index = [self.projects
            indexOfObjectPassingTest:^BOOL(NSDictionary* candidate, NSUInteger i, BOOL* stop) {
              (void)i;
              (void)stop;
              return [candidate[@"projectID"] isEqual:record[@"projectID"]];
            }];
        if (index != NSNotFound)
            [self openProject:index];
        return;
    }
    NSDictionary* commands = @{
        @"rename" : @"Rename…",
        @"duplicate" : @"Duplicate",
        @"trash" : @"Move to Trash…",
        @"restore" : @"Restore",
        @"delete" : @"Delete Permanently…"
    };
    NSString* command = commands[action];
    if (command)
        [self projectCommand:command url:record[@"url"] title:record[@"title"]];
}
- (void)reloadLibrary {
    NSError* error = nil;
    NSArray* projects =
        self.trashMode ? [self.library trashedProjects:&error] : [self.library projects:&error];
    self.projects = projects ?: @[];
    [self.libraryController updateWithRecords:projects error:error];
    [self.libraryShell refreshNavigation];
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
- (void)transitionNavigation:(void (^)(void))changes {
    if (self.renderingNavigation) {
        changes();
        return;
    }
    [self.navigationSnapshot removeFromSuperview];
    self.navigationSnapshot = nil;
    UIView* snapshot = (!UIAccessibilityIsReduceMotionEnabled() && self.view.window)
                           ? [self.view snapshotViewAfterScreenUpdates:NO]
                           : nil;
    self.renderingNavigation = YES;
    changes();
    self.renderingNavigation = NO;
    [self.view layoutIfNeeded];
    if (!snapshot)
        return;
    snapshot.frame = self.view.bounds;
    snapshot.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    snapshot.userInteractionEnabled = NO;
    snapshot.accessibilityElementsHidden = YES;
    [self.view addSubview:snapshot];
    self.navigationSnapshot = snapshot;
    [UIView animateWithDuration:0.18
        delay:0
        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowUserInteraction
        animations:^{
          snapshot.alpha = 0;
        }
        completion:^(BOOL finished) {
          (void)finished;
          [snapshot removeFromSuperview];
        }];
}
- (void)openProject:(NSInteger)index {
    if (self.editor && ![self.editor flush])
        return;
    [self transitionNavigation:^{
      [self renderProject:index];
    }];
}
- (void)renderProject:(NSInteger)index {
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
    NeonDocumentSession* session = [self.library openProjectURL:url error:&error];
    if (!session) {
        [self showProblem:error];
        return;
    }
    self.libraryController.selectedProjectID = session.projectID;
    [self hideLibraryShell];
    self.session = session;
    if (!self.sidebarLayoutInitialized) {
        self.narrowSidebarLayout = self.view.bounds.size.width < 1000 ||
                                   self.view.bounds.size.width <= self.view.bounds.size.height;
        self.sidebarHidden = self.narrowSidebarLayout;
        self.sidebarLayoutInitialized = YES;
    }
    self.selectedURL = url;
    self.chapterList = [[NeonList alloc] initWithStyle:UITableViewStylePlain];
    self.chapterList.chapters = YES;
    self.chapterList.coordinator = self;
    [self.navigation setViewControllers:@[ self.libraryList, self.chapterList ] animated:NO];
    if (!self.collapsed)
        [self openSection:0];
}
- (void)openSection:(NSInteger)index {
    if (self.editor && ![self.editor flush])
        return;
    [self transitionNavigation:^{
      [self renderSection:index];
    }];
}
- (void)renderSection:(NSInteger)index {
    self.historyController = nil;
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
    BOOL resume = self.historySession == self.session &&
                  [self.historySection isEqual:self.session.selectedSectionID] &&
                  [self.historyEditor.editor.text isEqual:self.session.text];
    NeonEditor* editor = resume ? self.historyEditor : [NeonEditor new];
    self.historyEditor = nil;
    self.historySession = nil;
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
    if (!self.collapsed && self.sidebarHidden)
        [self hideColumn:UISplitViewControllerColumnPrimary];
    [editor loadViewIfNeeded];
    [self applyAppearance];
    [self.chapterList.tableView reloadData];
}
- (void)toggleChapters {
    if (self.collapsed) {
        [self.navigation popToViewController:self.chapterList animated:YES];
        return;
    }
    self.sidebarChoiceExplicit = YES;
    [self toggleSidebarVisibility];
}
- (void)toggleSidebarVisibility {
    self.sidebarHidden = !self.sidebarHidden;
    if (self.sidebarHidden)
        [self hideColumn:UISplitViewControllerColumnPrimary];
    else
        [self showColumn:UISplitViewControllerColumnPrimary];
    [self updateNavigationControls];
}
- (void)updateNavigationControls {
    BOOL compact = self.collapsed;
    UIBarButtonItem* toggle =
        [[UIBarButtonItem alloc] initWithImage:workspaceIcon(compact ? @"navigation" : @"sidebar")
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(toggleChapters)];
    toggle.accessibilityIdentifier = @"navigation-toggle";
    toggle.accessibilityLabel =
        compact ? @"Project navigation" : (self.sidebarHidden ? @"Show sidebar" : @"Hide sidebar");
    toggle.title = toggle.accessibilityLabel;
    for (NeonList* list in
         @[ self.libraryList ?: (id)NSNull.null, self.chapterList ?: (id)NSNull.null ]) {
        if (![list isKindOfClass:NeonList.class])
            continue;
        NSMutableArray* items = [NSMutableArray array];
        if (!compact && !self.sidebarHidden && list == self.navigation.topViewController)
            [items addObject:toggle];
        if (list.chapters)
            [items addObject:[[UIBarButtonItem alloc] initWithTitle:@"Library"
                                                              style:UIBarButtonItemStylePlain
                                                             target:self
                                                             action:@selector(showLibrary)]];
        list.navigationItem.leftBarButtonItems = items;
    }
    UIViewController* content = self.historyController ?: (UIViewController*)self.editor;
    UINavigationController* detail =
        (id)[self viewControllerForColumn:UISplitViewControllerColumnSecondary];
    if (!content && [detail isKindOfClass:UINavigationController.class])
        content = detail.topViewController;
    content.navigationItem.hidesBackButton = YES;
    content.navigationItem.leftBarButtonItem = (compact || self.sidebarHidden) ? toggle : nil;
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
    BOOL narrow = size.width < 1000 || size.width <= size.height;
    if (!self.sidebarLayoutInitialized || narrow != self.narrowSidebarLayout) {
        self.narrowSidebarLayout = narrow;
        if (!self.sidebarChoiceExplicit)
            self.sidebarHidden = narrow;
        self.sidebarLayoutInitialized = YES;
    }
    [transition
        animateAlongsideTransition:nil
                        completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
                          (void)context;
                          UIViewController* content =
                              self.historyController ?: (UIViewController*)self.editor;
                          if (!content) {
                              [self updateNavigationControls];
                              return;
                          }
                          if (self.editor && ![self.editor flush])
                              return;
                          if (self.collapsed) {
                              [self setViewController:nil
                                            forColumn:UISplitViewControllerColumnSecondary];
                              [self.navigation setViewControllers:@[
                                  self.libraryList, self.chapterList, content
                              ]
                                                         animated:NO];
                          } else {
                              [self.navigation
                                  setViewControllers:@[ self.libraryList, self.chapterList ]
                                            animated:NO];
                              [self setViewController:[[UINavigationController alloc]
                                                          initWithRootViewController:content]
                                            forColumn:UISplitViewControllerColumnSecondary];
                              if (self.sidebarHidden)
                                  [self hideColumn:UISplitViewControllerColumnPrimary];
                              else
                                  [self showColumn:UISplitViewControllerColumnPrimary];
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
- (void)showDestination:(NeonWorkspaceDestination)destination sectionID:(NSString*)sectionID {
    if (destination == NeonWorkspaceDestinationHistory) {
        [self showHistory];
        return;
    }
    if (destination != NeonWorkspaceDestinationManuscript)
        return; // Capability gate until the native destination implementation lands.
    if (!sectionID.length || [sectionID isEqual:self.session.selectedSectionID]) {
        [self showCurrentEditor];
        return;
    }
    NSUInteger index = [self.session.sections
        indexOfObjectPassingTest:^BOOL(NSDictionary* section, NSUInteger i, BOOL* stop) {
          (void)i;
          (void)stop;
          return [section[@"id"] isEqual:sectionID];
        }];
    if (index != NSNotFound)
        [self openSection:index];
}
- (void)showCurrentEditor {
    if (self.editor && self.editor.session == self.session && !self.historyController) {
        if (self.collapsed)
            [self.navigation setViewControllers:@[ self.libraryList, self.chapterList, self.editor ]
                                       animated:NO];
        else
            [self showColumn:UISplitViewControllerColumnSecondary];
        [self updateNavigationControls];
        return;
    }
    NSUInteger index = [self.session.sections
        indexOfObjectPassingTest:^BOOL(NSDictionary* section, NSUInteger idx, BOOL* stop) {
          (void)idx;
          (void)stop;
          return [section[@"id"] isEqual:self.session.selectedSectionID];
        }];
    [self openSection:index == NSNotFound ? 0 : index];
}
- (void)showHistory {
    if (!self.session || self.historyController || (self.editor && ![self.editor flush]))
        return;
    self.historyEditor = self.editor;
    self.historySession = self.session;
    self.historySection = self.session.selectedSectionID;
    [self transitionNavigation:^{
      self.editor.session = nil;
      self.editor = nil;
      NeonHistoryController* controller = [NeonHistoryController new];
      controller.session = self.session;
      __weak NeonCoordinator* weakSelf = self;
      controller.showEditor = ^{
        [weakSelf showCurrentEditor];
      };
      controller.didRestore = ^{
        weakSelf.historyEditor = nil;
        weakSelf.historySession = nil;
        [weakSelf.chapterList.tableView reloadData];
      };
      self.historyController = controller;
      if (self.collapsed) {
          [self.navigation setViewControllers:@[ self.libraryList, self.chapterList, controller ]
                                     animated:NO];
      } else {
          [self setViewController:[[UINavigationController alloc]
                                      initWithRootViewController:controller]
                        forColumn:UISplitViewControllerColumnSecondary];
          [self showColumn:UISplitViewControllerColumnSecondary];
      }
      [self applyAppearance];
    }];
}
- (void)newSection {
    [self askTitle:YES];
}
- (void)showLibrary {
    if (self.editor && ![self.editor flush])
        return;
    [self transitionNavigation:^{
      [self renderLibrary];
    }];
}
- (void)renderLibrary {
    self.historyController = nil;
    if (self.editor && ![self.editor flush])
        return;
    self.editor.session = nil;
    self.editor = nil;
    self.session = nil;
    self.selectedURL = nil;
    self.trashMode = self.libraryController.query.filter == NeonLibraryTrash;
    [self.navigation setViewControllers:@[ self.libraryList ] animated:NO];
    UIViewController* blank = [UIViewController new];
    blank.view.backgroundColor = NeonPaper();
    [self setViewController:[[UINavigationController alloc] initWithRootViewController:blank]
                  forColumn:UISplitViewControllerColumnSecondary];
    // The library must be visible, but this does not change the writer's sidebar choice.
    [self showColumn:UISplitViewControllerColumnPrimary];
    [self reloadLibrary];
    [self applyAppearance];
    [self showLibraryShell];
}
- (void)showTrash {
    [self showLibrary];
    if (self.session)
        return;
    [self.libraryController selectFilter:NeonLibraryTrash];
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
- (BOOL)libraryHostSmoke {
    NeonLibrarySmokeRecord(@"begin", YES, @"Library host assertions");
    NeonLibraryFilter filter = self.libraryController.query.filter;
    NeonLibraryView view = self.libraryController.query.view;
    [self.libraryController selectFilter:NeonLibraryAll];
    NSDictionary* record = self.projects.firstObject;
    if (!record)
        return NO;
    BOOL titleStyle = NeonLibraryTitleStyleSmoke(self.libraryController);
    BOOL favorite = [record[@"favorite"] boolValue];
    NSString* openedKey = [@"library.opened." stringByAppendingString:record[@"projectID"]];
    id before = [NeonPreferences() objectForKey:openedKey];
    [self reloadLibrary];
    id after = [NeonPreferences() objectForKey:openedKey];
    __block BOOL valid = YES;
    void (^check)(NSString*, BOOL, NSString*) = ^(NSString* name, BOOL pass, NSString* detail) {
      NeonLibrarySmokeRecord(name, pass, detail);
      valid = pass && valid;
    };
    check(@"title-style", titleStyle, @"see individual title states");
    check(@"source-count", self.projects.count == 3, @(self.projects.count).stringValue);
    check(@"presentation-error", !self.libraryController.presentation.error,
          self.libraryController.presentation.error.localizedDescription);
    check(@"visible-count", self.libraryController.presentation.records.count == 3,
          @(self.libraryController.presentation.records.count).stringValue);
    check(@"shell-mounted", self.libraryShell.parentViewController == self,
          NSStringFromClass(self.libraryShell.parentViewController.class));
    check(@"fixture-identities",
          [self.libraryController.fixtureIDs isEqualToDictionary:NeonUITestFixtureIDs()],
          self.libraryController.fixtureIDs.description);
    check(@"enumeration-no-open", before == after || [before isEqual:after],
          [NSString stringWithFormat:@"before=%@ after=%@", before, after]);
    [self libraryAction:@"favorite" record:record];
    [self.libraryController selectFilter:NeonLibraryFavorites];
    BOOL contains =
        [self.libraryController.presentation.records
            indexOfObjectPassingTest:^BOOL(NSDictionary* item, NSUInteger i, BOOL* stop) {
              (void)i;
              (void)stop;
              return [item[@"projectID"] isEqual:record[@"projectID"]];
            }] != NSNotFound;
    check(@"favorite-filter", contains == !favorite,
          [NSString stringWithFormat:@"before=%d contains=%d", favorite, contains]);
    [self.library setFavorite:favorite projectID:record[@"projectID"]];
    [self.libraryController selectFilter:NeonLibraryAll];
    [self.libraryController setLibraryView:NeonLibraryList];
    check(@"list-view", self.libraryController.query.view == NeonLibraryList, @"requested List");
    [self.libraryController setLibraryView:view];
    [self libraryAction:@"open" record:record];
    NSDate* opened = [NeonPreferences() objectForKey:openedKey];
    check(@"opened-stable-id", [self.session.projectID isEqual:record[@"projectID"]],
          self.session.projectID);
    check(@"open-dismisses-library", self.libraryShell.parentViewController == nil,
          @"shell parent");
    check(@"successful-open-tracked", [opened isKindOfClass:NSDate.class], opened.description);
    [self showLibrary];
    [self.libraryController selectFilter:filter];
    check(@"library-return", self.libraryShell.parentViewController == self, @"shell mounted");
    return valid;
}
- (void)runSmoke:(NSArray*)args support:(NSURL*)support {
    if ([args containsObject:@"--smoke-library"]) {
        marker(support, @"smoke-library.txt", [self libraryHostSmoke]);
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
        [self.editor.view layoutIfNeeded];
        valid = NeonWorkspaceSmoke(self.editor.heading, self.editor.editor) && valid;
        valid = breadcrumbFits(self.editor) && valid;
        self.editor.bookTitle.text = @"A very long project title that must yield to Library";
        [self.editor.bookTitle invalidateIntrinsicContentSize];
        [self.editor.navigationController.view setNeedsLayout];
        valid = breadcrumbFits(self.editor) && valid;
        self.editor.bookTitle.text = projectTitle;
        [self.editor.bookTitle invalidateIntrinsicContentSize];
        [self.editor applyTypography];
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
        UITextView* originalEditor = self.editor.editor;
        originalEditor.selectedRange = NSMakeRange(MIN(5, originalEditor.text.length), 0);
        NSRange selection = originalEditor.selectedRange;
        [self showHistory];
        [self showCurrentEditor];
        valid = valid && self.editor.editor == originalEditor &&
                NSEqualRanges(selection, self.editor.editor.selectedRange);
        [self showHistory];
        NeonHistoryController* controller = self.historyController;
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
        id original = [NeonPreferences() objectForKey:@"paragraphSpacing"];
        stepper.value = 12;
        [stepper sendActionsForControlEvents:UIControlEventValueChanged];
        NSParagraphStyle* paragraph =
            self.editor.editor.typingAttributes[NSParagraphStyleAttributeName];
        valid = valid && stepper && NeonParagraphSpacing() == 12 &&
                paragraph.paragraphSpacing == 12 && [self.editor.editor.text isEqual:draft] &&
                NSEqualRanges(selection, self.editor.editor.selectedRange);
        if (original)
            [NeonPreferences() setObject:original forKey:@"paragraphSpacing"];
        else
            [NeonPreferences() removeObjectForKey:@"paragraphSpacing"];
        controller.preferencesChanged();
        [controller filterSettings:@"no matching setting"];
        valid = valid && controller.visibleSettingCount == 0;
        [controller filterSettings:@""];
        marker(support, @"smoke-settings.txt", valid);
    } else if ([args containsObject:@"--smoke-typography"]) {
        NeonEditor* editor = self.editor;
        NeonWorkspaceCompositionSmoke(
            ^UITextView* {
              return editor.editor;
            },
            ^(CGFloat pointSize) {
              [NeonPreferences() setDouble:pointSize forKey:@"manuscriptSize"];
              [editor applyTypography];
            },
            ^CGFloat {
              return editor.wideTypography ? 34.0 / 20 : 30.0 / 18;
            },
            ^BOOL {
              return editor.typographyPending;
            },
            ^(BOOL valid) {
              [editor applyTypography];
              valid = [editor flush] && valid;
              [editor typography];
              marker(support, @"smoke-typography.txt", valid);
            });
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
    BOOL uiTesting = [NSProcessInfo.processInfo.arguments containsObject:@"--ui-testing"];
    if (uiTesting) {
        [NSFileManager.defaultManager
                   createDirectoryAtURL:focusDiagnosticURL().URLByDeletingLastPathComponent
            withIntermediateDirectories:YES
                             attributes:nil
                                  error:nil];
        [@"Neon test window ready\n" writeToURL:focusDiagnosticURL()
                                     atomically:YES
                                       encoding:NSUTF8StringEncoding
                                          error:nil];
    }
    self.window = uiTesting
                      ? [[NeonDiagnosticWindow alloc] initWithWindowScene:(UIWindowScene*)scene]
                      : [[UIWindow alloc] initWithWindowScene:(UIWindowScene*)scene];
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--control-states"]) {
        UIViewController* fixture = [UIViewController new];
        fixture.view.backgroundColor = NeonPaper();
        UIView* catalog = NeonControlStateFixture();
        catalog.translatesAutoresizingMaskIntoConstraints = NO;
        [fixture.view addSubview:catalog];
        [NSLayoutConstraint activateConstraints:@[
            [catalog.leadingAnchor
                constraintEqualToAnchor:fixture.view.safeAreaLayoutGuide.leadingAnchor],
            [catalog.trailingAnchor
                constraintEqualToAnchor:fixture.view.safeAreaLayoutGuide.trailingAnchor],
            [catalog.topAnchor constraintEqualToAnchor:fixture.view.safeAreaLayoutGuide.topAnchor],
            [catalog.bottomAnchor
                constraintEqualToAnchor:fixture.view.safeAreaLayoutGuide.bottomAnchor]
        ]];
        self.window.rootViewController = fixture;
        [self.window makeKeyAndVisible];
        return;
    }
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
