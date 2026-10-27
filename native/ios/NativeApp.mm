#import "ContextMenu.h"
#import "Controls.h"
#import "EditorialTheme.h"
#import "History.h"
#import "InlineTitle.h"
#import "LibraryController.h"
#import "LibraryStore.h"
#import "Preferences.h"
#import "Settings.h"
#import "TextFormatting.h"
#import "UITestFixtures.h"
#import "WorkspaceController.h"
#import <UIKit/UIKit.h>
#include <string>

@interface NeonLibraryController (StatusChrome)
- (UIView*)statusFooter;
@end

// A navigation link retains its typography through UIButton state updates.
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
      attributes[NSFontAttributeName] = NeonUI(14);
      attributes[NSForegroundColorAttributeName] = NeonAccent();
      return attributes;
    };
    [super setConfiguration:value];
    self.titleLabel.numberOfLines = 1;
}
@end

namespace {
UIImage* sidebarGlyph() {
    static UIImage* glyph;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
      UIGraphicsImageRenderer* renderer =
          [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(20, 20)];
      glyph = [[renderer imageWithActions:^(UIGraphicsImageRendererContext* context) {
        (void)context;
        [UIColor.blackColor setStroke];
        UIBezierPath* border = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(2, 3, 16, 14)
                                                          cornerRadius:2];
        border.lineWidth = 1.4;
        [border stroke];
        UIBezierPath* divider = [UIBezierPath bezierPath];
        [divider moveToPoint:CGPointMake(8, 3)];
        [divider addLineToPoint:CGPointMake(8, 17)];
        divider.lineWidth = 1.4;
        [divider stroke];
      }] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    });
    return glyph;
}
CGFloat fixtureViewportWidth() {
    BOOL testing = NO;
    for (NSString* argument in NSProcessInfo.processInfo.arguments)
        testing = testing || [argument hasPrefix:@"--smoke-"] || [argument isEqual:@"--ui-testing"];
    if (!testing)
        return 0;
    for (NSString* argument in NSProcessInfo.processInfo.arguments)
        if ([argument hasPrefix:@"--viewport-width="])
            return MAX(320, MIN(1024, [[argument substringFromIndex:17] doubleValue]));
    return 0;
}
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
@property(nonatomic, copy) BOOL (^handleListReturn)(void);
@end
@implementation NeonManuscriptView
- (void)insertText:(NSString*)text {
    // Handle generated list markers before UIKit's own list insertion pipeline.
    if ([text isEqual:@"\n"] && !self.markedTextRange && self.handleListReturn &&
        self.handleListReturn())
        return;
    [super insertText:text];
}
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
@property(nonatomic, strong) UIView* bar;
@property(nonatomic, strong) UIButton* navigationToggle;
@property(nonatomic, strong) UIStackView* filters;
@property(nonatomic, strong) NSMutableArray<NeonButton*>* filterButtons;
@property(nonatomic) BOOL filtersOpen;
@property(nonatomic) BOOL regularFiltersHidden;
@property(nonatomic) UIButton* filterScrim;
- (void)refreshNavigation;
@end
@implementation NeonLibraryShell
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = NeonPaper();
    self.view.accessibilityViewIsModal = YES;
    self.bar = [UIView new];
    [self.view addSubview:self.bar];
    self.navigationToggle = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.navigationToggle setImage:sidebarGlyph() forState:UIControlStateNormal];
    self.navigationToggle.accessibilityLabel = @"Library navigation";
    [self.navigationToggle addTarget:self
                              action:@selector(toggleFilters)
                    forControlEvents:UIControlEventTouchUpInside];
    [self.bar addSubview:self.navigationToggle];
    [self addChildViewController:self.library];
    [self.view addSubview:self.library.view];
    [self.library didMoveToParentViewController:self];
    self.filters = [UIStackView new];
    self.filters.axis = UILayoutConstraintAxisVertical;
    self.filters.spacing = 0;
    self.filters.layoutMarginsRelativeArrangement = YES;
    self.filters.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(24, 0, 24, 0);
    self.filterButtons = [NSMutableArray array];
    UILabel* brand = [UILabel new];
    brand.text = @"Neon";
    brand.font = NeonUISemibold(16);
    brand.textColor = NeonInk();
    UILabel* subtitle = [UILabel new];
    subtitle.text = @"Your writing, in one place";
    subtitle.font = NeonUI(12);
    subtitle.textColor = NeonMuted();
    UIView* intro = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 210, 70)];
    [intro.heightAnchor constraintEqualToConstant:70].active = YES;
    brand.frame = CGRectMake(20, 0, 170, 22);
    subtitle.frame = CGRectMake(20, 28, 170, 18);
    [intro addSubview:brand];
    [intro addSubview:subtitle];
    [self.filters addArrangedSubview:intro];
    __weak NeonLibraryShell* weak = self;
    NSArray* titles = @[ @"All projects", @"Recent", @"Favorites", @"On this device" ];
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
                  weak.filtersOpen = NO;
                  [weak.view setNeedsLayout];
                }]
            forControlEvents:UIControlEventTouchUpInside];
        [self.filters addArrangedSubview:button];
        [self.filterButtons addObject:button];
    }
    [self.filters addArrangedSubview:[UIView new]];
    NeonButton* settings = [NeonButton new];
    settings.kind = NeonButtonFlatRow;
    [settings setTitle:@"Settings" forState:UIControlStateNormal];
    settings.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
    [settings.heightAnchor constraintEqualToConstant:45.5].active = YES;
    [settings addAction:[UIAction actionWithHandler:^(__kindof UIAction* action) {
                (void)action;
                if (weak.library.onAction)
                    weak.library.onAction(@"settings", nil);
              }]
        forControlEvents:UIControlEventTouchUpInside];
    [self.filters addArrangedSubview:settings];
    self.filterScrim = [UIButton buttonWithType:UIButtonTypeCustom];
    self.filterScrim.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.2];
    self.filterScrim.accessibilityLabel = @"Close navigation";
    [self.filterScrim addTarget:self
                         action:@selector(toggleFilters)
               forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.filterScrim];
    [self.view addSubview:self.filters];
    [self refreshNavigation];
}
- (void)refreshNavigation {
    if (!self.isViewLoaded)
        return;
    self.bar.backgroundColor = NeonPanel();
    NeonApplyGlassBackdrop(self.bar, 0);
    self.navigationToggle.tintColor = NeonMuted();
    self.navigationToggle.layer.cornerRadius = NeonGlassEnabled() ? 8 : 5;
    self.navigationToggle.layer.borderWidth = NeonGlassEnabled() ? 1 : 0;
    self.navigationToggle.layer.borderColor = [NeonInk() colorWithAlphaComponent:0.10].CGColor;
    self.filters.backgroundColor = NeonPanel();
    self.navigationToggle.menu = [self.library navigationMenu];
    self.navigationToggle.showsMenuAsPrimaryAction = NO;
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
    BOOL wide = width > 600;
    CGFloat sidebar = wide && !self.regularFiltersHidden ? 210 : 0;
    self.bar.frame = CGRectMake(safe.left, top, width, 56);
    self.navigationToggle.frame = CGRectMake(wide ? 16 : 10, 14, 28, 28);
    self.filters.hidden = wide ? self.regularFiltersHidden : !self.filtersOpen;
    self.filterScrim.hidden = wide || !self.filtersOpen;
    self.filterScrim.frame = CGRectMake(0, top + 56, width, height);
    self.filters.frame = CGRectMake(safe.left, top + 56, wide ? sidebar : MIN(260, width * 0.85),
                                    MAX(0, height - (wide ? 36.5 : 36)));
    self.library.usesSidebarNavigation = wide;
    self.library.view.frame = CGRectMake(safe.left + sidebar, top + 56, width - sidebar, height);
    UIView* footer = [self.library statusFooter];
    if (footer.superview != self.view)
        [self.view addSubview:footer];
    footer.frame =
        CGRectMake(safe.left, top + 56 + height - (wide ? 36.5 : 36), width, wide ? 36.5 : 36);
    [self.view bringSubviewToFront:self.filterScrim];
    [self.view bringSubviewToFront:self.filters];
    [self.view bringSubviewToFront:footer];
}
- (void)toggleFilters {
    if (self.view.bounds.size.width > 600) {
        self.regularFiltersHidden = !self.regularFiltersHidden;
        [UIView animateWithDuration:NeonReduceMotion() ? 0 : 0.28
                         animations:^{
                           [self.view setNeedsLayout];
                           [self.view layoutIfNeeded];
                         }];
        return;
    }
    self.filtersOpen = !self.filtersOpen;
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    if (self.filtersOpen && self.view.bounds.size.width <= 600) {
        self.filters.transform = CGAffineTransformMakeTranslation(-260, 0);
        [UIView animateWithDuration:NeonReduceMotion() ? 0 : 0.28
                         animations:^{
                           self.filters.transform = CGAffineTransformIdentity;
                         }];
    }
}
@end
// A dedicated, adaptive starting-point screen keeps creation in the workspace.
@interface NeonPresetPicker : UIViewController
@property(nonatomic) UIView* chrome;
@property(nonatomic, copy) void (^onContinue)(NSString*);
@property(nonatomic) UIScrollView* scroll;
@property(nonatomic) UIView* footer;
@property(nonatomic) UILabel* selection;
@property(nonatomic) NSArray<NeonButton*>* cards;
@property(nonatomic) NSString* selectedID;
@end
@implementation NeonPresetPicker
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"New project";
    self.view.backgroundColor = NeonPaper();
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(cancel)];
    self.chrome = [UIView new];
    self.chrome.backgroundColor = NeonPanel();
    [self.view addSubview:self.chrome];
    UIButton* cancel = [UIButton buttonWithType:UIButtonTypeSystem];
    [cancel setTitle:@"Cancel" forState:UIControlStateNormal];
    cancel.titleLabel.font = NeonUI(13);
    cancel.tintColor = NeonInk();
    cancel.tag = 607;
    [cancel addTarget:self action:@selector(cancel) forControlEvents:UIControlEventTouchUpInside];
    [self.chrome addSubview:cancel];
    UILabel* project = [UILabel new];
    project.text = @"New project";
    project.font = NeonUI(13);
    project.textColor = NeonInk();
    project.textAlignment = NSTextAlignmentRight;
    project.tag = 608;
    [self.chrome addSubview:project];
    self.scroll = [UIScrollView new];
    [self.view addSubview:self.scroll];
    self.footer = [UIView new];
    self.footer.backgroundColor = NeonPanel();
    [self.view addSubview:self.footer];
    self.selection = [UILabel new];
    self.selection.font = NeonUI(13);
    self.selection.textColor = NeonMuted();
    self.selection.numberOfLines = 2;
    [self.footer addSubview:self.selection];
    NeonButton* next = [NeonButton new];
    next.kind = NeonButtonPrimary;
    next.tag = 601;
    [next setTitle:@"Continue" forState:UIControlStateNormal];
    [next addTarget:self action:@selector(proceed) forControlEvents:UIControlEventTouchUpInside];
    [self.footer addSubview:next];
    NSArray* captions = @[
        @"Chapters, parts, front matter", @"Abstract, methods, references",
        @"Subject, lead story, footer", @"Headline, sections, sources",
        @"Introduction, argument, conclusion", @"A clean page. Your own structure."
    ];
    NSMutableArray* cards = [NSMutableArray new];
    NSArray* order = @[ @"book", @"research", @"newsletter", @"article", @"essay", @"blank" ];
    for (NSUInteger i = 0; i < order.count; ++i) {
        NSDictionary* preset = nil;
        for (NSDictionary* candidate in NeonDocumentSession.writingPresets)
            if ([candidate[@"id"] isEqual:order[i]])
                preset = candidate;
        if (!preset)
            continue;
        NeonButton* card = [NeonButton new];
        card.kind = NeonButtonSelection;
        card.accessibilityIdentifier = [@"preset-" stringByAppendingString:order[i]];
        [card setTitle:preset[@"title"] forState:UIControlStateNormal];
        card.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
        UILabel* title = [UILabel new];
        title.text =
            @[ @"Book", @"Research paper", @"Newsletter", @"Article", @"Essay",
               @"Blank document" ][i];
        title.font = NeonSerif(22);
        title.textColor = NeonInk();
        title.tag = 602;
        title.userInteractionEnabled = NO;
        UILabel* caption = [UILabel new];
        caption.text = captions[i];
        caption.font = NeonUI(14);
        caption.textColor = NeonMuted();
        caption.numberOfLines = 2;
        caption.tag = 603;
        caption.userInteractionEnabled = NO;
        [card addSubview:title];
        [card addSubview:caption];
        // Keep the accessibility title while custom labels provide the two-line card.
        [card setTitle:@"" forState:UIControlStateNormal];
        card.accessibilityLabel =
            [NSString stringWithFormat:@"%@. %@", preset[@"title"], captions[i]];
        __weak NeonPresetPicker* weak = self;
        NSString* identifier = order[i];
        [card addAction:[UIAction actionWithHandler:^(__kindof UIAction* action) {
                (void)action;
                weak.selectedID = identifier;
                [weak updateSelection];
              }]
            forControlEvents:UIControlEventTouchUpInside];
        [self.scroll addSubview:card];
        [cards addObject:card];
    }
    self.cards = cards;
    self.selectedID = @"book";
    for (NSArray* entry in @[
             @[ @"What are you writing?", @604 ],
             @[ @"Start with a structure that speaks your language.", @605 ],
             @[ @"You can change the structure and formatting later.", @606 ]
         ]) {
        UILabel* text = [UILabel new];
        text.text = entry[0];
        text.tag = [entry[1] integerValue];
        text.font = text.tag == 604 ? NeonSerif(30) : NeonUI(14);
        text.textColor = text.tag == 604 ? NeonInk() : NeonMuted();
        text.textAlignment = NSTextAlignmentCenter;
        text.numberOfLines = 0;
        [self.scroll addSubview:text];
    }
    [self updateSelection];
}
- (void)updateSelection {
    for (NeonButton* card in self.cards) {
        card.chosen = [card.accessibilityIdentifier
            isEqual:[@"preset-" stringByAppendingString:self.selectedID]];
        card.layer.borderWidth = 1;
        card.layer.borderColor =
            (card.chosen ? NeonAccent() : [NeonInk() colorWithAlphaComponent:0.14]).CGColor;
        card.layer.cornerRadius = 12;
        if (card.chosen)
            self.selection.text =
                [NSString stringWithFormat:@"%@ · %@", ((UILabel*)[card viewWithTag:602]).text,
                                           ((UILabel*)[card viewWithTag:603]).text];
    }
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect safe = self.view.safeAreaLayoutGuide.layoutFrame;
    CGFloat width = safe.size.width;
    BOOL narrow = width <= 600;
    CGFloat contentWidth = MIN(width, 880);
    CGFloat margin = (width - contentWidth) / 2 + (narrow ? 20 : (width <= 850 ? 28 : 40));
    CGFloat footerHeight = narrow ? 61.5 : 73.5;
    self.chrome.frame = CGRectMake(safe.origin.x, safe.origin.y, width, 56);
    NeonApplyGlassBackdrop(self.chrome, 0);
    [self.chrome viewWithTag:607].frame = CGRectMake(narrow ? 12 : 24, 12, 58, 32);
    [self.chrome viewWithTag:608].frame = CGRectMake(width - (narrow ? 112 : 124), 12, 100, 32);
    self.scroll.frame = CGRectMake(safe.origin.x, safe.origin.y + 56, width,
                                   MAX(0, safe.size.height - 56 - footerHeight));
    self.footer.frame =
        CGRectMake(safe.origin.x, CGRectGetMaxY(safe) - footerHeight, width, footerHeight);
    CGFloat footerPadding = narrow ? 16 : 24;
    self.selection.font = NeonUI(narrow ? 12 : 15);
    self.selection.frame =
        CGRectMake(footerPadding, narrow ? 12 : 18, MAX(0, width - footerPadding * 2 - 112), 37.5);
    [self.footer viewWithTag:601].frame =
        CGRectMake(width - footerPadding - 89.453125, narrow ? 12 : 18, 89.453125, 37.5);
    UILabel* heading = (UILabel*)[self.scroll viewWithTag:604];
    heading.font = NeonSerif(narrow ? 26 : 30);
    CGFloat headingHeight =
        ceil([heading sizeThatFits:CGSizeMake(width - 2 * margin, CGFLOAT_MAX)].height);
    heading.frame = CGRectMake(margin, narrow ? 24 : (width <= 850 ? 28 : 32), width - margin * 2,
                               headingHeight);
    UILabel* subtitle = (UILabel*)[self.scroll viewWithTag:605];
    subtitle.font = NeonUI(narrow ? 14 : 15);
    CGFloat subtitleHeight =
        ceil([subtitle sizeThatFits:CGSizeMake(width - 2 * margin, CGFLOAT_MAX)].height);
    subtitle.frame =
        CGRectMake(margin, CGRectGetMaxY(heading.frame) + 14, width - margin * 2, subtitleHeight);
    CGFloat cardsY = CGRectGetMaxY(subtitle.frame) + 26;
    CGFloat gap = narrow ? 12 : 16, cardHeight = narrow ? 86 : 112;
    NSInteger columns = narrow ? 1 : 2;
    CGFloat cardWidth = (width - 2 * margin - gap * (columns - 1)) / columns;
    for (NSUInteger i = 0; i < self.cards.count; ++i) {
        NeonButton* card = self.cards[i];
        card.frame = CGRectMake(margin + (i % columns) * (cardWidth + gap),
                                cardsY + (i / columns) * (cardHeight + gap), cardWidth, cardHeight);
        ((UILabel*)[card viewWithTag:602]).font = NeonSerif(narrow ? 20 : 22);
        [card viewWithTag:602].frame =
            CGRectMake(narrow ? 17 : 19, narrow ? 15 : 24.75, cardWidth - (narrow ? 34 : 38),
                       narrow ? 29.5 : 33);
        [card viewWithTag:603].frame =
            CGRectMake(narrow ? 17 : 19, narrow ? 49.5 : 65.75, cardWidth - (narrow ? 34 : 38), 20);
    }
    CGFloat bottom = cardsY + ceil((double)self.cards.count / columns) * (cardHeight + gap) - gap;
    UILabel* hint = (UILabel*)[self.scroll viewWithTag:606];
    hint.font = NeonUI(narrow ? 14 : 15);
    CGFloat hintHeight =
        ceil([hint sizeThatFits:CGSizeMake(width - 2 * margin, CGFLOAT_MAX)].height);
    hint.frame = CGRectMake(margin, bottom + (narrow ? 14 : 15), width - 2 * margin, hintHeight);
    self.scroll.contentSize =
        CGSizeMake(width, CGRectGetMaxY(hint.frame) + 26 + (narrow ? 24 : 32));
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
}
- (void)cancel {
    [self dismissViewControllerAnimated:!NeonReduceMotion() completion:nil];
}
- (void)proceed {
    NSString* selected = self.selectedID;
    void (^continuation)(NSString*) = self.onContinue;
    [self dismissViewControllerAnimated:!NeonReduceMotion()
                             completion:^{
                               if (continuation)
                                   continuation(selected);
                             }];
}
@end
// Section creation occupies the document pane, retaining the editor for Cancel.
@interface NeonSectionCreation : UIViewController <UITextFieldDelegate>
@property(nonatomic, copy) NSString* sectionLabel;
@property(nonatomic, copy) NSString* projectTitle;
@property(nonatomic, copy) void (^onCancel)(void);
@property(nonatomic, copy) NSString* (^onCreate)(NSString*);
@property(nonatomic) UITextField* titleField;
@property(nonatomic) UILabel* errorLabel;
@property(nonatomic) NeonButton* createButton;
@property(nonatomic) UIView* chrome;
@end
@implementation NeonSectionCreation
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = NeonPaper();
    self.view.accessibilityIdentifier = @"new-section-screen";
    NSString* unit = self.sectionLabel.length ? self.sectionLabel.lowercaseString : @"section";
    self.chrome = [UIView new];
    self.chrome.backgroundColor = NeonPanel();
    self.chrome.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.chrome];
    NeonButton* cancel = [NeonButton new];
    cancel.kind = NeonButtonQuiet;
    [cancel setTitle:@"Cancel" forState:UIControlStateNormal];
    cancel.accessibilityIdentifier = @"new-section-cancel";
    [cancel addTarget:self action:@selector(cancel) forControlEvents:UIControlEventTouchUpInside];
    cancel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.chrome addSubview:cancel];
    UILabel* context = [UILabel new];
    context.text = self.projectTitle;
    context.font = NeonUI(14);
    context.textColor = NeonMuted();
    context.textAlignment = NSTextAlignmentRight;
    context.translatesAutoresizingMaskIntoConstraints = NO;
    [self.chrome addSubview:context];
    UIScrollView* scroll = [UIScrollView new];
    scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scroll];
    UIStackView* form = [UIStackView new];
    form.axis = UILayoutConstraintAxisVertical;
    form.alignment = UIStackViewAlignmentFill;
    form.spacing = 16;
    form.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:form];
    UILabel* heading = [UILabel new];
    heading.text = [@"New " stringByAppendingString:unit];
    heading.font = NeonSerif(30);
    heading.textColor = NeonInk();
    heading.numberOfLines = 0;
    [form addArrangedSubview:heading];
    UILabel* subtitle = [UILabel new];
    subtitle.text = @"Give it a working title. You can change it later.";
    subtitle.font = NeonUI(15);
    subtitle.textColor = NeonMuted();
    subtitle.numberOfLines = 0;
    [form addArrangedSubview:subtitle];
    [form setCustomSpacing:32 afterView:subtitle];
    UILabel* fieldLabel = [UILabel new];
    fieldLabel.text = @"Working title";
    fieldLabel.font = NeonUI(14);
    fieldLabel.textColor = NeonInk();
    [form addArrangedSubview:fieldLabel];
    [form setCustomSpacing:8 afterView:fieldLabel];
    self.titleField = [UITextField new];
    self.titleField.font = NeonUI(17);
    self.titleField.textColor = NeonInk();
    self.titleField.backgroundColor = NeonPanel();
    self.titleField.tintColor = NeonAccent();
    self.titleField.layer.cornerRadius = 6;
    self.titleField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 44)];
    self.titleField.leftViewMode = UITextFieldViewModeAlways;
    self.titleField.placeholder = @"Working title";
    self.titleField.accessibilityLabel = @"Working title";
    self.titleField.accessibilityIdentifier = @"new-section-title";
    self.titleField.returnKeyType = UIReturnKeyDone;
    self.titleField.delegate = self;
    [self.titleField addTarget:self
                        action:@selector(titleChanged)
              forControlEvents:UIControlEventEditingChanged];
    [self.titleField.heightAnchor constraintEqualToConstant:48].active = YES;
    [form addArrangedSubview:self.titleField];
    self.errorLabel = [UILabel new];
    self.errorLabel.font = NeonUI(14);
    self.errorLabel.textColor = UIColor.systemRedColor;
    self.errorLabel.numberOfLines = 0;
    self.errorLabel.hidden = YES;
    self.errorLabel.accessibilityIdentifier = @"new-section-error";
    [form addArrangedSubview:self.errorLabel];
    self.createButton = [NeonButton new];
    self.createButton.kind = NeonButtonPrimary;
    [self.createButton setTitle:[@"Create " stringByAppendingString:unit]
                       forState:UIControlStateNormal];
    self.createButton.accessibilityIdentifier = @"new-section-create";
    self.createButton.enabled = NO;
    [self.createButton addTarget:self
                          action:@selector(create)
                forControlEvents:UIControlEventTouchUpInside];
    UIStackView* actions =
        [[UIStackView alloc] initWithArrangedSubviews:@[ [UIView new], self.createButton ]];
    [self.createButton.heightAnchor constraintEqualToConstant:44].active = YES;
    [form addArrangedSubview:actions];
    UILayoutGuide* safe = self.view.safeAreaLayoutGuide;
    NSLayoutConstraint* preferred =
        [form.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-48];
    preferred.priority = 999;
    [NSLayoutConstraint activateConstraints:@[
        [self.chrome.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [self.chrome.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [self.chrome.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [self.chrome.heightAnchor constraintEqualToConstant:56],
        [cancel.leadingAnchor constraintEqualToAnchor:self.chrome.leadingAnchor constant:12],
        [cancel.centerYAnchor constraintEqualToAnchor:self.chrome.centerYAnchor],
        [cancel.widthAnchor constraintEqualToConstant:64],
        [cancel.heightAnchor constraintEqualToConstant:44],
        [context.leadingAnchor constraintEqualToAnchor:cancel.trailingAnchor constant:16],
        [context.trailingAnchor constraintEqualToAnchor:self.chrome.trailingAnchor constant:-24],
        [context.centerYAnchor constraintEqualToAnchor:self.chrome.centerYAnchor],
        [scroll.topAnchor constraintEqualToAnchor:self.chrome.bottomAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor],
        [form.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:40],
        [form.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor
                                          constant:-32],
        [form.centerXAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.centerXAnchor],
        [scroll.contentLayoutGuide.widthAnchor
            constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],
        [form.widthAnchor constraintLessThanOrEqualToConstant:560],
        preferred
    ]];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    NeonApplyGlassBackdrop(self.chrome, 0);
}
- (NSString*)workingTitle {
    return [self.titleField.text
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}
- (void)titleChanged {
    self.createButton.enabled = self.workingTitle.length > 0;
    self.errorLabel.hidden = YES;
}
- (BOOL)textFieldShouldReturn:(UITextField*)field {
    (void)field;
    [self create];
    return NO;
}
- (void)cancel {
    [self.view endEditing:YES];
    if (self.onCancel)
        self.onCancel();
}
- (void)create {
    NSString* title = self.workingTitle;
    if (!title.length)
        return;
    NSString* error = self.onCreate ? self.onCreate(title) : nil;
    if (error.length) {
        self.errorLabel.text = error;
        self.errorLabel.hidden = NO;
        UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, error);
    }
}
@end
@class NeonCoordinator;
@interface NeonEditor : NeonWorkspaceController <UITextViewDelegate>
@property(nonatomic, strong) UITextView* editor;
@property(nonatomic) UIView* chrome;
@property(nonatomic, copy) NSDictionary* manuscriptTypingAttributes;
@property(nonatomic) UIStackView* chromeBreadcrumb;
@property(nonatomic) UIButton* chromeToggle;
@property(nonatomic) UIButton* chromeHistory;
@property(nonatomic) NSMutableArray<UIButton*>* formatButtons;
@property(nonatomic) UIButton* formatOverflow;
@property(nonatomic) UIButton* writingOverflow;
@property(nonatomic) UIView* formatDivider;
@property(nonatomic) BOOL applyingFormatting;
@property(nonatomic, strong) UILabel* status;
@property(nonatomic) UIView* statusBar;
@property(nonatomic) NSLayoutConstraint* statusFooterHeight;
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
@property(nonatomic, strong) NeonSectionCreation* sectionCreation;
@property(nonatomic, strong) NeonEditor* historyEditor;
@property(nonatomic, strong) NeonDocumentSession* historySession;
@property(nonatomic, copy) NSString* historySection;
@property(nonatomic, strong) NeonList* libraryList;
@property(nonatomic, strong) NeonLibraryController* libraryController;
@property(nonatomic, strong) NeonLibraryShell* libraryShell;
@property(nonatomic, strong) NeonList* chapterList;
@property(nonatomic, strong) UINavigationController* navigation;
@property(nonatomic) BOOL sidebarHidden;
@property(nonatomic) BOOL appearanceInitialized;
@property(nonatomic) UIView* appearanceSnapshot;
@property(nonatomic) BOOL sidebarLayoutInitialized;
@property(nonatomic) BOOL sidebarChoiceExplicit;
@property(nonatomic) BOOL narrowSidebarLayout;
@property(nonatomic, strong) UIView* navigationSnapshot;
@property(nonatomic) BOOL renderingNavigation;
@property(nonatomic) NSTimeInterval navigationDuration;
@property(nonatomic) BOOL chapterTransition;
@property(nonatomic) CGFloat navigationDirection;
@property(nonatomic) UIViewController* navigationOverlay;
- (void)dismissNavigationOverlay;
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
BOOL breadcrumbFits(NeonEditor* editor) {
    [editor.navigationController.view layoutIfNeeded];
    UIStackView* stack = editor.chromeBreadcrumb;
    [editor.view layoutIfNeeded];
    [stack layoutIfNeeded];
    UIButton* library = (UIButton*)stack.arrangedSubviews.firstObject;
    CGFloat textWidth = [@"Library" sizeWithAttributes:@{NSFontAttributeName : NeonUI(14)}].width;
    return library.titleLabel.numberOfLines == 1 &&
           library.titleLabel.bounds.size.width >= textWidth - 1 &&
           library.bounds.size.height >= 32 && fabs(library.titleLabel.font.pointSize - 14) < .1 &&
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
    self.bookTitle.font = NeonUI(14);
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
    [separator.widthAnchor constraintEqualToConstant:12].active = YES;
    [separator setContentCompressionResistancePriority:UILayoutPriorityRequired
                                               forAxis:UILayoutConstraintAxisHorizontal];
    UIStackView* breadcrumb =
        [[UIStackView alloc] initWithArrangedSubviews:@[ library, separator, self.bookTitle ]];
    breadcrumb.spacing = NeonBreadcrumbGap;
    breadcrumb.alignment = UIStackViewAlignmentCenter;
    [self.bookTitle setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                    forAxis:UILayoutConstraintAxisHorizontal];
    self.chromeBreadcrumb = breadcrumb;
    self.chrome = [UIView new];
    self.chrome.backgroundColor = NeonPanel();
    [self.view addSubview:self.chrome];
    [self.chrome addSubview:breadcrumb];
    self.chromeToggle = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.chromeToggle setImage:sidebarGlyph() forState:UIControlStateNormal];
    self.chromeToggle.accessibilityIdentifier = @"navigation-toggle";
    self.chromeToggle.accessibilityLabel = @"Project navigation";
    [self.chromeToggle addTarget:self.coordinator
                          action:@selector(toggleChapters)
                forControlEvents:UIControlEventTouchUpInside];
    [self.chrome addSubview:self.chromeToggle];
    self.chromeHistory = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.chromeHistory setTitle:@"History" forState:UIControlStateNormal];
    self.chromeHistory.titleLabel.font = NeonUI(13);
    self.chromeHistory.accessibilityLabel = @"Version history";
    [self.chromeHistory addTarget:self.coordinator
                           action:@selector(showHistory)
                 forControlEvents:UIControlEventTouchUpInside];
    [self.chrome addSubview:self.chromeHistory];
    [self buildFormattingToolbar];
    [self.chromeHistory addGestureRecognizer:[[UILongPressGestureRecognizer alloc]
                                                 initWithTarget:self
                                                         action:@selector(chromeActions:)]];
    __weak NeonEditor* weakChrome = self;
    self.chromeHistory.accessibilityCustomActions = @[ [[UIAccessibilityCustomAction alloc]
         initWithName:@"Writing actions"
        actionHandler:^BOOL(UIAccessibilityCustomAction* action) {
          (void)action;
          [weakChrome actions];
          return YES;
        }] ];
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
    UILabel* kicker =
        label(self.session.sections.count ? [self.session sectionLabelAtIndex:number - 1]
                                          : self.session.preset[@"documentLabel"],
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
    manuscript.handleListReturn = ^BOOL {
      return [weakSelf continueListAtRange:weakSelf.editor.selectedRange];
    };
    self.editor = manuscript;
    self.editor.delegate = self;
    self.editor.backgroundColor = NeonPaper();
    self.editor.textColor = NeonInk();
    self.editor.text = self.session.text;
    if (self.session.richTextData.length) {
        NSAttributedString* rich = [[NSAttributedString alloc]
                  initWithData:self.session.richTextData
                       options:@{NSDocumentTypeDocumentAttribute : NSRTFTextDocumentType}
            documentAttributes:nil
                         error:nil];
        if (rich && [rich.string isEqual:self.session.text])
            self.editor.attributedText = rich;
    }
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
    for (UIView* child in
         @[ self.editor, footer, self.status, mode, self.sessionSlot, self.chrome ])
        child.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.editor];
    [self.view addSubview:self.sessionSlot];
    [self.view addSubview:footer];
    UILayoutGuide* safe = self.view.safeAreaLayoutGuide;
    self.statusFooterHeight = [footer.heightAnchor constraintEqualToConstant:36.5];
    [NSLayoutConstraint activateConstraints:@[
        [self.chrome.topAnchor constraintEqualToAnchor:safe.topAnchor],
        [self.chrome.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [self.chrome.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [self.chrome.heightAnchor constraintEqualToConstant:56],
        [self.editor.topAnchor constraintEqualToAnchor:self.chrome.bottomAnchor],
        [self.editor.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [self.editor.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [self.editor.bottomAnchor constraintEqualToAnchor:self.sessionSlot.topAnchor],
        [self.sessionSlot.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [self.sessionSlot.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [self.sessionSlot.heightAnchor constraintEqualToConstant:0],
        [self.sessionSlot.bottomAnchor constraintEqualToAnchor:footer.topAnchor],
        [footer.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [footer.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [footer.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor],
        self.statusFooterHeight,
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
    CGSize viewport = self.coordinator.view.bounds.size;
    CGFloat statusHeight = viewport.width <= 600 ? 36 : 36.5;
    self.statusFooterHeight.constant = statusHeight;
    if (self.view.window && self.coordinator.view.window && self.coordinator.editor == self &&
        !self.coordinator.historyController) {
        if (!self.statusBar) {
            self.statusBar = [UIView new];
            self.statusBar.backgroundColor = NeonPanel();
            [self.status removeFromSuperview];
            self.status.translatesAutoresizingMaskIntoConstraints = YES;
            [self.statusBar addSubview:self.status];
            UILabel* mode = label(@"Write", NeonUI(13), NeonMuted());
            mode.tag = 989;
            mode.textAlignment = NSTextAlignmentRight;
            [self.statusBar addSubview:mode];
        }
        if (self.statusBar.superview != self.coordinator.view)
            [self.coordinator.view addSubview:self.statusBar];
        CGRect safe = self.coordinator.view.safeAreaLayoutGuide.layoutFrame;
        CGFloat bottom = MIN(CGRectGetMaxY(safe),
                             self.coordinator.view.keyboardLayoutGuide.layoutFrame.origin.y);
        self.statusBar.frame =
            CGRectMake(safe.origin.x, bottom - statusHeight, safe.size.width, statusHeight);
        CGFloat inset = viewport.width <= 600 ? 12 : 15;
        UIFont* font = NeonUI(viewport.width <= 600 ? 11 : 13);
        self.status.font = font;
        self.status.frame =
            CGRectMake(inset, viewport.width <= 600 ? 10 : 9, MAX(0, safe.size.width - 100),
                       viewport.width <= 600 ? 16 : 18.5);
        UILabel* mode = (UILabel*)[self.statusBar viewWithTag:989];
        mode.font = font;
        mode.frame = CGRectMake(safe.size.width - 80 - inset, viewport.width <= 600 ? 10 : 9, 80,
                                viewport.width <= 600 ? 16 : 18.5);
    }
    BOOL toggleVisible = viewport.width <= 600 || self.coordinator.sidebarHidden;
    CGFloat chromeWidth = self.chrome.bounds.size.width;
    self.chromeToggle.hidden = !toggleVisible;
    self.chromeToggle.frame = CGRectMake(viewport.width <= 600 ? 10 : 16, 14, 28, 28);
    CGFloat leading = toggleVisible ? (viewport.width <= 600 ? 52 : 128) : 24;
    CGFloat historyWidth = 44;
    CGFloat historyInset = viewport.width <= 600 ? 8 : 16;
    [self.chromeHistory setTitle:nil forState:UIControlStateNormal];
    [self.chromeHistory
        setPreferredSymbolConfiguration:[UIImageSymbolConfiguration
                                            configurationWithPointSize:16
                                                                weight:UIImageSymbolWeightRegular]
                        forImageInState:UIControlStateNormal];
    [self.chromeHistory setImage:[UIImage systemImageNamed:@"clock.arrow.circlepath"]
                        forState:UIControlStateNormal];
    self.chromeHistory.frame =
        CGRectMake(chromeWidth - historyInset - historyWidth, 6, historyWidth, 44);
    CGFloat available = CGRectGetMinX(self.chromeHistory.frame) - leading - 120;
    BOOL expandedTools = available >= self.formatButtons.count * 44 + 14;
    CGFloat actionsLeft = CGRectGetMinX(self.chromeHistory.frame);
    self.formatOverflow.hidden = expandedTools;
    self.writingOverflow.hidden = expandedTools;
    self.formatDivider.hidden = !expandedTools;
    if (expandedTools) {
        for (UIButton* control in [self.formatButtons reverseObjectEnumerator]) {
            actionsLeft -= 44;
            control.frame = CGRectMake(actionsLeft, 6, 44, 44);
            control.hidden = NO;
            if ([control.accessibilityIdentifier isEqual:@"format-quote"]) {
                self.formatDivider.frame = CGRectMake(actionsLeft + 44, 19, 1, 18);
                actionsLeft -= 8;
            }
        }
    } else {
        for (UIButton* control in self.formatButtons)
            control.hidden = YES;
        actionsLeft -= 44;
        self.writingOverflow.frame = CGRectMake(actionsLeft, 6, 44, 44);
        actionsLeft -= 44;
        self.formatOverflow.frame = CGRectMake(actionsLeft, 6, 44, 44);
    }
    self.chromeBreadcrumb.frame = CGRectMake(leading, 6, MAX(0, actionsLeft - 8 - leading), 44);
    self.chromeBreadcrumb.spacing = viewport.width <= 600 ? 6 : 8;
    NeonApplyGlassBackdrop(self.chrome, 0);
    for (UIButton* control in @[ self.chromeToggle, self.chromeHistory ]) {
        control.tintColor = NeonInk();
        control.layer.cornerRadius = NeonGlassEnabled() ? 8 : 5;
        control.layer.borderWidth = NeonGlassEnabled() ? 1 : 0;
        control.layer.borderColor = [NeonInk() colorWithAlphaComponent:0.10].CGColor;
    }
    BOOL wide = viewport.width > 600;
    if (self.wideTypography != wide) {
        self.wideTypography = wide;
        [self applyTypography];
        [self updateWritingToolbar];
    }
    CGFloat measure = [NeonPreferences() objectForKey:@"textMeasure"] ? NeonTextMeasure() : 760;
    CGFloat margin = viewport.width <= 600 ? 20 : (self.coordinator.sidebarHidden ? 32 : 48);
    CGFloat width = MAX(1, self.editor.bounds.size.width - 2 * margin);
    CGFloat rightMargin = MAX(margin, self.editor.bounds.size.width - margin - measure);
    self.chapterHeader.spacing = self.focusMode ? 16 : (wide ? 20 : 16);
    CGFloat top = viewport.width <= 600 ? 28 : 36;
    self.headingHeight.constant =
        ceil([self.heading sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height);
    CGSize headerSize =
        [self.chapterHeader systemLayoutSizeFittingSize:CGSizeMake(width, 0)
                          withHorizontalFittingPriority:UILayoutPriorityRequired
                                verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    self.chapterHeader.frame = CGRectMake(margin, top, width, headerSize.height);
    self.editor.textContainerInset = UIEdgeInsetsMake(
        top + headerSize.height + (wide ? 28 : 24), margin, NeonScrollBottomClearance, rightMargin);
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
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
}
- (void)chromeActions:(UILongPressGestureRecognizer*)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan)
        [self actions];
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self flush];
    [self.statusBar removeFromSuperview];
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
    CGFloat size = NeonTextSizeForViewport(self.coordinator.view.bounds.size.width);
    UIFont* bodyFont = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
        scaledFontForFont:([NeonPreferences() objectForKey:@"manuscriptFont"]
                               ? NeonManuscriptFont(size)
                               : NeonFontNamed(self.session.preset[@"font"], size))];
    BOOL legacySpacing = [NeonPreferences() objectForKey:@"manuscriptSpacing"] != nil;
    style.lineSpacing = legacySpacing ? NeonLineSpacing() : 0;
    CGFloat presetMultiple = [self.session.preset[@"lineHeightMultiple"] doubleValue];
    if (!legacySpacing && presetMultiple <= 1) {
        CGFloat leading = bodyFont.pointSize * (self.wideTypography ? 1.85 : 1.8);
        style.minimumLineHeight = leading;
        style.maximumLineHeight = leading;
    }
    UIFont* headingFont = scaledSerif(self.wideTypography ? 30 : 26);
    NSMutableParagraphStyle* headingStyle = [NSMutableParagraphStyle new];
    CGFloat headingLeading = headingFont.pointSize * 1.4;
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
    style.paragraphSpacing =
        [NeonPreferences() objectForKey:@"paragraphSpacing"]
            ? NeonParagraphSpacing()
            : (book ? 24 : [self.session.preset[@"paragraphSpacing"] doubleValue]);
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
    NSDictionary* existingTyping = self.editor.typingAttributes;
    NeonRestyleText(self.editor.textStorage, bodyFont, style);
    // Plain-text manuscripts use a blank line as the paragraph separator. Keep
    // those bytes intact while giving the separator one paragraph gap, rather
    // than adding paragraph spacing on both sides of a full empty text line.
    NSString* text = self.editor.text;
    NSUInteger paragraphStart = 0;
    while (paragraphStart < text.length) {
        NSRange paragraph = [text paragraphRangeForRange:NSMakeRange(paragraphStart, 0)];
        NSUInteger end = NSMaxRange(paragraph);
        if (end < text.length && [text characterAtIndex:end] == '\n' && paragraph.length > 1 &&
            !NeonFormatActive(self.editor.attributedText, paragraph, @"bullet") &&
            !NeonFormatActive(self.editor.attributedText, paragraph, @"numbered") &&
            !NeonFormatActive(self.editor.attributedText, paragraph, @"quote") &&
            !NeonFormatActive(self.editor.attributedText, paragraph, @"heading1") &&
            !NeonFormatActive(self.editor.attributedText, paragraph, @"heading2")) {
            NSMutableParagraphStyle* beforeSeparator = [style mutableCopy];
            beforeSeparator.paragraphSpacing = 0;
            [self.editor.textStorage addAttribute:NSParagraphStyleAttributeName
                                            value:beforeSeparator
                                            range:paragraph];
            NSMutableParagraphStyle* separator = [style mutableCopy];
            separator.paragraphSpacing = 0;
            separator.lineSpacing = 0;
            separator.lineHeightMultiple = 0;
            separator.minimumLineHeight = MAX(1, style.paragraphSpacing);
            separator.maximumLineHeight = MAX(1, style.paragraphSpacing);
            [self.editor.textStorage addAttributes:@{
                NSFontAttributeName : NeonFontNamed(@"Literata", 1),
                NSParagraphStyleAttributeName : separator
            }
                                             range:NSMakeRange(end, 1)];
            paragraphStart = end + 1;
        } else
            paragraphStart = end;
    }
    self.manuscriptTypingAttributes = attrs;
    self.editor.selectedRange = selection;
    self.editor.typingAttributes = NeonRestyleTyping(existingTyping ?: attrs, bodyFont, style);
    [self updateFormattingToolbar];
}
- (void)textViewDidBeginEditing:(UITextView*)view {
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--ui-testing"])
        NSLog(@"Neon focus began: editable=%d responder=%d window=%d frame=%@", view.editable,
              view.isFirstResponder, view.window != nil, NSStringFromCGRect(view.frame));
}
- (void)textViewDidChangeSelection:(UITextView*)view {
    if (self.applyingFormatting)
        return;
    if (!view.markedTextRange && view.selectedRange.length == 0 &&
        self.manuscriptTypingAttributes) {
        view.typingAttributes = NeonRestyleTyping(
            view.typingAttributes, self.manuscriptTypingAttributes[NSFontAttributeName],
            self.manuscriptTypingAttributes[NSParagraphStyleAttributeName]);
    }
    [self updateFormattingToolbar];
    [self scheduleTypographyRetry];
}
- (void)textViewDidEndEditing:(UITextView*)view {
    (void)view;
    [self scheduleTypographyRetry];
}
- (BOOL)continueListAtRange:(NSRange)range {
    UITextView* view = self.editor;
    if (!view || view.markedTextRange)
        return NO;
    NeonFormattingResult* continued =
        NeonContinueList(view.attributedText, range, view.typingAttributes,
                         self.manuscriptTypingAttributes[NSFontAttributeName] ?: NeonSerif(19));
    if (!continued)
        return NO;
    [self applyFormattedText:continued.text
                   selection:continued.selection
                      typing:continued.typingAttributes ?: view.typingAttributes
                        name:@"Continue list"];
    return YES;
}
- (BOOL)textView:(UITextView*)view
    shouldChangeTextInRange:(NSRange)range
            replacementText:(NSString*)replacement {
    if (view == self.editor && [replacement isEqual:@"\n"] && [self continueListAtRange:range])
        return NO;
    return YES;
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
    NSData* rich = [self.editor.attributedText
             dataFromRange:NSMakeRange(0, self.editor.text.length)
        documentAttributes:@{NSDocumentTypeDocumentAttribute : NSRTFTextDocumentType}
                     error:&error];
    BOOL saved = rich &&
                 [self.session replaceRichTextData:rich text:self.editor.text error:&error] &&
                 [self.session save:&error];
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
    nav.popoverPresentationController.sourceView = self.chrome;
    nav.popoverPresentationController.sourceRect =
        self.writingOverflow.hidden ? CGRectMake(self.chrome.bounds.size.width - 132, 6, 44, 44)
                                    : self.writingOverflow.frame;
    nav.popoverPresentationController.delegate = controller;
    nav.sheetPresentationController.prefersGrabberVisible = YES;
    nav.sheetPresentationController.detents = @[ UISheetPresentationControllerDetent.largeDetent ];
    nav.view.tintColor = NeonAccent();
    [self presentViewController:nav animated:!NeonReduceMotion() completion:nil];
}
- (NSArray<NSArray<NSString*>*>*)formattingCommands {
    return @[
        @[ @"body", @"Body text", @"textformat" ],
        @[ @"heading1", @"Heading 1", @"textformat.size.larger" ],
        @[ @"heading2", @"Heading 2", @"textformat.size.smaller" ], @[ @"bold", @"Bold", @"bold" ],
        @[ @"italic", @"Italic", @"italic" ], @[ @"underline", @"Underline", @"underline" ],
        @[ @"bullet", @"Bulleted list", @"list.bullet" ],
        @[ @"numbered", @"Numbered list", @"list.number" ],
        @[ @"quote", @"Block quote", @"text.quote" ]
    ];
}
- (NSArray<NSArray<NSString*>*>*)contextualCommands {
    NSString* preset = self.session.preset[@"id"];
    if ([preset isEqual:@"research"])
        return @[
            @[ @"equation", @"Insert LaTeX source", @"function" ],
            @[ @"citation", @"Insert citation", @"text.book.closed" ]
        ];
    if ([preset isEqual:@"essay"])
        return @[ @[ @"citation", @"Insert citation", @"text.book.closed" ] ];
    if ([preset isEqual:@"article"] || [preset isEqual:@"newsletter"] || [preset isEqual:@"blank"])
        return @[ @[ @"link", @"Insert link", @"link" ] ];
    return @[];
}
- (UIButton*)toolButton:(NSString*)command label:(NSString*)title symbol:(NSString*)symbol {
    UIButton* control = [UIButton buttonWithType:UIButtonTypeSystem];
    [control setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
    [control
        setPreferredSymbolConfiguration:[UIImageSymbolConfiguration
                                            configurationWithPointSize:15
                                                                weight:UIImageSymbolWeightRegular]
                        forImageInState:UIControlStateNormal];
    control.titleLabel.font = NeonUI(13);
    control.tintColor = NeonInk();
    control.accessibilityLabel = title;
    control.accessibilityIdentifier = [@"format-" stringByAppendingString:command];
    control.layer.cornerRadius = 5;
    [control addTarget:self
                  action:@selector(formattingPressed:)
        forControlEvents:UIControlEventTouchUpInside];
    [self.chrome addSubview:control];
    return control;
}
- (void)buildFormattingToolbar {
    self.formatButtons = [NSMutableArray array];
    for (NSArray* item in self.formattingCommands) {
        if ([item[0] isEqual:@"heading1"] || [item[0] isEqual:@"heading2"])
            continue;
        UIButton* control = [self toolButton:item[0] label:item[1] symbol:item[2]];
        if ([item[0] isEqual:@"body"])
            control.showsMenuAsPrimaryAction = YES;
        [self.formatButtons addObject:control];
    }
    self.formatDivider = [UIView new];
    self.formatDivider.backgroundColor = NeonLine();
    [self.chrome addSubview:self.formatDivider];
    for (NSArray* item in self.contextualCommands)
        [self.formatButtons addObject:[self toolButton:item[0] label:item[1] symbol:item[2]]];
    [self.formatButtons addObject:[self toolButton:@"typography"
                                             label:@"Typography"
                                            symbol:@"textformat.size"]];
    [self.formatButtons addObject:[self toolButton:@"focus"
                                             label:@"Focus mode"
                                            symbol:@"arrow.up.left.and.arrow.down.right"]];
    self.formatOverflow = [self toolButton:@"formatting"
                                     label:@"Text formatting"
                                    symbol:@"textformat"];
    self.formatOverflow.showsMenuAsPrimaryAction = YES;
    self.writingOverflow = [self toolButton:@"writing" label:@"Writing tools" symbol:@"ellipsis"];
    self.writingOverflow.showsMenuAsPrimaryAction = YES;
    [self updateFormattingToolbar];
}
- (BOOL)isFormatActive:(NSString*)command {
    if (!self.editor)
        return NO;
    if (!self.editor.selectedRange.length) {
        NSAttributedString* sample =
            [[NSAttributedString alloc] initWithString:@" "
                                            attributes:self.editor.typingAttributes];
        return NeonFormatActive(sample, NSMakeRange(0, 1), command);
    }
    return NeonFormatActive(self.editor.attributedText, self.editor.selectedRange, command);
}
- (UIAction*)formatAction:(NSArray<NSString*>*)item {
    __weak NeonEditor* weakSelf = self;
    UIAction* action = [UIAction actionWithTitle:item[1]
                                           image:[UIImage systemImageNamed:item[2]]
                                      identifier:nil
                                         handler:^(UIAction* selected) {
                                           (void)selected;
                                           [weakSelf performWritingCommand:item[0]];
                                         }];
    action.state = [self isFormatActive:item[0]] ? UIMenuElementStateOn : UIMenuElementStateOff;
    if (([item[0] isEqual:@"undo"] && !self.editor.undoManager.canUndo) ||
        ([item[0] isEqual:@"redo"] && !self.editor.undoManager.canRedo))
        action.attributes = UIMenuElementAttributesDisabled;
    return action;
}
- (void)updateFormattingToolbar {
    if (!self.formatButtons)
        return;
    NSMutableArray* formats = [NSMutableArray array];
    NSMutableArray* styles = [NSMutableArray array];
    for (NSArray* item in self.formattingCommands) {
        UIAction* action = [self formatAction:item];
        [formats addObject:action];
        if ([item[0] isEqual:@"body"] || [item[0] hasPrefix:@"heading"])
            [styles addObject:action];
    }
    self.formatOverflow.menu = [UIMenu menuWithTitle:@"Text formatting" children:formats];
    NSMutableArray* writing = [NSMutableArray array];
    for (NSArray* item in self.contextualCommands)
        [writing addObject:[self formatAction:item]];
    [writing addObject:[self formatAction:@[ @"typography", @"Typography", @"textformat.size" ]]];
    [writing addObject:[self formatAction:@[
                 @"focus", self.focusMode ? @"Exit focus" : @"Focus mode",
                 @"arrow.up.left.and.arrow.down.right"
             ]]];
    [writing addObject:[self formatAction:@[ @"undo", @"Undo", @"arrow.uturn.backward" ]]];
    [writing addObject:[self formatAction:@[ @"redo", @"Redo", @"arrow.uturn.forward" ]]];
    self.writingOverflow.menu = [UIMenu menuWithTitle:@"Writing tools" children:writing];
    for (UIButton* control in self.formatButtons) {
        NSString* command = [control.accessibilityIdentifier substringFromIndex:7];
        BOOL active = [command isEqual:@"focus"] ? self.focusMode : [self isFormatActive:command];
        control.backgroundColor = active ? NeonSelection() : UIColor.clearColor;
        control.tintColor = active ? NeonAccent() : NeonInk();
        control.accessibilityTraits =
            UIAccessibilityTraitButton | (active ? UIAccessibilityTraitSelected : 0);
        if ([command isEqual:@"body"])
            control.menu = [UIMenu menuWithTitle:@"Paragraph style" children:styles];
    }
}
- (void)formattingPressed:(UIButton*)sender {
    NSString* command = [sender.accessibilityIdentifier substringFromIndex:7];
    if ([command isEqual:@"body"] || [command isEqual:@"formatting"] ||
        [command isEqual:@"writing"])
        return;
    [self performWritingCommand:command];
}
- (void)applyFormattedText:(NSAttributedString*)text
                 selection:(NSRange)selection
                    typing:(NSDictionary*)typing
                      name:(NSString*)name {
    NSAttributedString* before = [self.editor.attributedText copy];
    NSRange previousRange = self.editor.selectedRange;
    NSDictionary* previousTyping = [self.editor.typingAttributes copy];
    [self.editor.undoManager registerUndoWithTarget:self
                                            handler:^(NeonEditor* target) {
                                              [target applyFormattedText:before
                                                               selection:previousRange
                                                                  typing:previousTyping
                                                                    name:name];
                                            }];
    [self.editor.undoManager setActionName:name];
    self.applyingFormatting = YES;
    [self.editor.textStorage setAttributedString:text];
    self.editor.selectedRange =
        NSMakeRange(MIN(selection.location, text.length),
                    MIN(selection.length, text.length - MIN(selection.location, text.length)));
    self.editor.typingAttributes = typing;
    self.applyingFormatting = NO;
    [self textViewDidChange:self.editor];
    [self updateFormattingToolbar];
    [self flush];
}
- (void)performWritingCommand:(NSString*)command {
    if ([command isEqual:@"typography"]) {
        [self typography];
        return;
    }
    if ([command isEqual:@"focus"]) {
        [self toggleFocusMode];
        [self updateFormattingToolbar];
        return;
    }
    if ([command isEqual:@"undo"]) {
        [self.editor.undoManager undo];
        return;
    }
    if ([command isEqual:@"redo"]) {
        [self.editor.undoManager redo];
        return;
    }
    if ([command isEqual:@"link"] || [command isEqual:@"equation"] ||
        [command isEqual:@"citation"]) {
        [self insertContextual:command];
        return;
    }
    if (!self.editor || self.editor.markedTextRange)
        return;
    NSRange range = self.editor.selectedRange;
    UIFont* base = self.manuscriptTypingAttributes[NSFontAttributeName] ?: NeonSerif(19);
    NSDictionary* typing = NeonFormatTyping(self.editor.typingAttributes, command, base);
    BOOL inlineCommand = [@[ @"bold", @"italic", @"underline" ] containsObject:command];
    if (!range.length && inlineCommand) {
        [self applyFormattedText:self.editor.attributedText
                       selection:range
                          typing:typing
                            name:@"Formatting"];
    } else {
        NeonFormattingResult* result =
            NeonFormatText(self.editor.attributedText, range, command, base);
        [self applyFormattedText:result.text
                       selection:result.selection
                          typing:typing
                            name:@"Formatting"];
    }
    [self.editor becomeFirstResponder];
}
- (void)insertContextual:(NSString*)command {
    if (!self.editor || self.editor.markedTextRange)
        return;
    NSRange selection = self.editor.selectedRange;
    NSDictionary* typing = [self.editor.typingAttributes copy];
    BOOL link = [command isEqual:@"link"], equation = [command isEqual:@"equation"];
    UIAlertController* dialog = [UIAlertController
        alertControllerWithTitle:link       ? @"Insert link"
                                 : equation ? @"Insert LaTeX source"
                                            : @"Insert citation"
                         message:link ? @"Enter a web or email address."
                                 : equation
                                     ? @"Inserts editable LaTeX source between inline math "
                                       @"delimiters. Equation rendering is not available yet."
                                     : @"Enter the citation text as it should appear in your "
                                       @"manuscript."
                  preferredStyle:UIAlertControllerStyleAlert];
    [dialog addTextFieldWithConfigurationHandler:^(UITextField* field) {
      field.placeholder = link       ? @"https://example.com"
                          : equation ? @"E = mc^2"
                                     : @"(Author, year)";
      field.autocapitalizationType = UITextAutocapitalizationTypeNone;
      if (link) {
          field.keyboardType = UIKeyboardTypeURL;
          if (selection.length && NSMaxRange(selection) <= self.editor.text.length) {
              id existing = [self.editor.attributedText attribute:NSLinkAttributeName
                                                          atIndex:selection.location
                                                   effectiveRange:nil];
              field.text =
                  [existing isKindOfClass:NSURL.class] ? [existing absoluteString] : existing;
          }
      }
    }];
    [dialog addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                               style:UIAlertActionStyleCancel
                                             handler:^(UIAlertAction* action) {
                                               (void)action;
                                               self.editor.selectedRange = selection;
                                               self.editor.typingAttributes = typing;
                                             }]];
    [dialog addAction:[UIAlertAction
                          actionWithTitle:@"Insert"
                                    style:UIAlertActionStyleDefault
                                  handler:^(UIAlertAction* action) {
                                    (void)action;
                                    [self insertContextValue:dialog.textFields.firstObject.text
                                                     command:command
                                                   selection:selection
                                                      typing:typing];
                                  }]];
    [self presentViewController:dialog animated:!NeonReduceMotion() completion:nil];
}
- (BOOL)insertContextValue:(NSString*)value
                   command:(NSString*)command
                 selection:(NSRange)selection
                    typing:(NSDictionary*)typing {
    BOOL link = [command isEqual:@"link"], equation = [command isEqual:@"equation"];
    value = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSURL* url = link ? [NSURL URLWithString:value] : nil;
    NSString* scheme = url.scheme.lowercaseString;
    BOOL webURL = [@[ @"http", @"https" ] containsObject:scheme] && url.host.length > 0;
    BOOL mailURL = [scheme isEqual:@"mailto"] && url.resourceSpecifier.length > 0;
    if (!value.length || (link && (!url || (!webURL && !mailURL)))) {
        self.status.text = link ? @"Enter an http, https, or mailto address."
                                : @"Nothing inserted: enter text first.";
        return NO;
    }
    NSMutableAttributedString* result = [self.editor.attributedText mutableCopy];
    if (NSMaxRange(selection) > result.length)
        return NO;
    NSRange inserted = selection;
    if (link && selection.length) {
        [result addAttribute:NSLinkAttributeName value:url range:selection];
    } else {
        NSString* insertedText = equation ? [NSString stringWithFormat:@"\\(%@\\)", value] : value;
        NSMutableDictionary* attributes = [typing mutableCopy];
        if (link)
            attributes[NSLinkAttributeName] = url;
        NSAttributedString* replacement = [[NSAttributedString alloc] initWithString:insertedText
                                                                          attributes:attributes];
        [result replaceCharactersInRange:selection withAttributedString:replacement];
        inserted = NSMakeRange(selection.location + replacement.length, 0);
    }
    NSMutableDictionary* nextTyping = [typing mutableCopy];
    [nextTyping removeObjectForKey:NSLinkAttributeName];
    [self applyFormattedText:result selection:inserted typing:nextTyping name:@"Insert"];
    [self.editor becomeFirstResponder];
    return YES;
}
- (void)updateWritingToolbar {
    if (!self.focusMode)
        self.navigationItem.rightBarButtonItems = self.writingActions;
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
    size.value = NeonTextSizeForViewport(self.editor.coordinator.view.bounds.size.width);
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
    [self dismissViewControllerAnimated:!NeonReduceMotion()
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
    [self dismissViewControllerAnimated:!NeonReduceMotion() completion:nil];
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
    self.tableView.estimatedRowHeight = self.chapters ? 44 : 142;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
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
        self.title = @"";
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
        self.navigationItem.rightBarButtonItems =
            @[ [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose
                                                             target:self.coordinator
                                                             action:@selector(showCurrentEditor)] ];
        UILabel* project = label(self.coordinator.session.title, NeonUISemibold(16), NeonInk());
        UILabel* count =
            label([NSString stringWithFormat:@"%lu %@ · %lu words",
                                             self.coordinator.session.sections.count,
                                             [self.coordinator.session.preset[@"sectionsLabel"]
                                                 lowercaseString],
                                             self.coordinator.session.projectWordCount],
                  NeonUI(12), NeonMuted());
        self.navigationProjectTitle = project;
        self.navigationProjectCount = count;
        NSMutableArray<UIView*>* items = [NSMutableArray arrayWithArray:@[ project, count ]];
        UIStackView* intro = [[UIStackView alloc] initWithArrangedSubviews:items];
        intro.axis = UILayoutConstraintAxisVertical;
        intro.spacing = 6;
        intro.layoutMarginsRelativeArrangement = YES;
        intro.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(24, 20, 24, 20);
        UIView* chrome = [UIView new];
        chrome.backgroundColor = NeonPanel();
        [chrome.heightAnchor
            constraintEqualToConstant:self.coordinator.view.bounds.size.width <= 600 ? 0 : 56]
            .active = YES;
        chrome.clipsToBounds = YES;
        NeonApplyGlassBackdrop(chrome, 0);
        UIButton* toggle = [UIButton buttonWithType:UIButtonTypeSystem];
        toggle.frame = CGRectMake(16, 14, 28, 28);
        toggle.tintColor = NeonInk();
        toggle.layer.cornerRadius = NeonGlassEnabled() ? 8 : 5;
        toggle.layer.borderWidth = NeonGlassEnabled() ? 1 : 0;
        toggle.layer.borderColor = [NeonInk() colorWithAlphaComponent:0.10].CGColor;
        [toggle setImage:sidebarGlyph() forState:UIControlStateNormal];
        toggle.accessibilityIdentifier = @"navigation-toggle";
        toggle.accessibilityLabel = @"Hide sidebar";
        [toggle addTarget:self.coordinator
                      action:@selector(toggleChapters)
            forControlEvents:UIControlEventTouchUpInside];
        [chrome addSubview:toggle];
        self.navigationHeader = [[UIStackView alloc] initWithArrangedSubviews:@[ chrome, intro ]];
        self.navigationHeader.axis = UILayoutConstraintAxisVertical;
        self.navigationHeader.spacing = 0;
        self.tableView.tableHeaderView = self.navigationHeader;
        UIView* footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 210, 112)];
        NeonButton* addSection = [[NeonButton alloc] initWithFrame:CGRectMake(0, 6, 210, 47)];
        addSection.kind = NeonButtonFlatRow;
        addSection.textSize = 13;
        [addSection
            setTitle:[@"＋ Add "
                         stringByAppendingString:[self.coordinator.session.preset[@"sectionLabel"]
                                                     lowercaseString]]
            forState:UIControlStateNormal];
        addSection.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
        addSection.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [addSection addTarget:self
                       action:@selector(create)
             forControlEvents:UIControlEventTouchUpInside];
        [footer addSubview:addSection];
        NeonButton* settingsRow = [[NeonButton alloc] initWithFrame:CGRectMake(0, 64, 210, 45.5)];
        settingsRow.kind = NeonButtonFlatRow;
        [settingsRow setTitle:@"Settings" forState:UIControlStateNormal];
        settingsRow.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
        settingsRow.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [settingsRow addTarget:self
                        action:@selector(settings)
              forControlEvents:UIControlEventTouchUpInside];
        [footer addSubview:settingsRow];
        self.tableView.tableFooterView = footer;
    }
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    quietNavigationActions(self.navigationItem);
    if (self.chapters && self.tableView.tableFooterView) {
        UIView* footer = self.tableView.tableFooterView;
        CGFloat height =
            MAX(112, self.tableView.bounds.size.height - self.tableView.adjustedContentInset.top -
                         self.tableView.adjustedContentInset.bottom -
                         self.navigationHeader.bounds.size.height -
                         self.coordinator.session.sections.count * 44);
        CGRect frame =
            CGRectMake(0, footer.frame.origin.y, self.tableView.bounds.size.width, height);
        if (!CGSizeEqualToSize(footer.frame.size, frame.size)) {
            footer.frame = frame;
            footer.subviews.lastObject.frame = CGRectMake(
                0, height - (self.coordinator.view.bounds.size.width <= 600 ? 69.5 : 106),
                frame.size.width, 45.5);
            self.tableView.tableFooterView = footer;
        }
    }
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
    [self.navigationController setToolbarHidden:YES animated:animated];
    if (self.chapters) {
        self.navigationController.interactivePopGestureRecognizer.enabled = NO;
        [self.navigationController setNavigationBarHidden:YES animated:NO];
    }
    if (self.chapters) {
        self.navigationProjectTitle.text = self.coordinator.session.title;
        self.navigationProjectCount.text = [NSString
            stringWithFormat:@"%lu %@ · %lu words", self.coordinator.session.sections.count,
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
    return self.chapters ? nil : @"ON THIS DEVICE";
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
        BOOL current = [identifier isEqual:self.coordinator.session.selectedSectionID];
        title.font = current ? NeonUISemibold(14) : NeonUI(14);
        title.textColor = current ? NeonAccent() : NeonInk();
        cell.accessibilityTraits =
            current ? UIAccessibilityTraitSelected : UIAccessibilityTraitNone;
        cell.separatorInset = UIEdgeInsetsZero;
        // Persist the active section even when reloadData clears UIKit selection.
        UIView* background = [UIView new];
        background.backgroundColor =
            current ? [NeonAccent() colorWithAlphaComponent:0.12] : UIColor.clearColor;
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
        UILabel* number =
            label([self.coordinator.session.preset[@"id"] isEqual:@"book"]
                      ? [NSString stringWithFormat:@"%02ld", (long)path.row + 1]
                      : @"",
                  current ? NeonUISemibold(14) : NeonUI(14), current ? NeonAccent() : NeonInk());
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
            [row.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:20],
            [row.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor
                                               constant:-8],
            [row.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:0],
            [row.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:0],
            [title.heightAnchor constraintGreaterThanOrEqualToConstant:NeonMinimumTouchTarget]
        ]];
    }
    cell.backgroundColor = NeonReduceTransparency() ? NeonPanel() : UIColor.clearColor;
    UIButton* more = [UIButton buttonWithType:UIButtonTypeSystem];
    [more setImage:[UIImage systemImageNamed:@"ellipsis"] forState:UIControlStateNormal];
    more.frame = CGRectMake(0, 0, 44, 44);
    more.tag = path.row;
    more.accessibilityLabel = self.chapters ? [self.coordinator.session.preset[@"sectionLabel"]
                                                  stringByAppendingString:@" actions"]
                                            : @"Project actions";
    [more addTarget:self action:@selector(more:) forControlEvents:UIControlEventTouchUpInside];
    cell.accessoryView = self.chapters ? nil : more;
    if (self.chapters) {
        NSString* identifier = self.coordinator.session.sections[path.row][@"id"];
        __weak NeonList* weak = self;
        NSMutableArray* actions = [NSMutableArray new];
        for (NSString* command in
             @[ @"Rename…", @"Duplicate", @"Move Up", @"Move Down", @"Move to Trash…" ]) {
            [actions addObject:[[UIAccessibilityCustomAction alloc]
                                    initWithName:command
                                   actionHandler:^BOOL(UIAccessibilityCustomAction* action) {
                                     (void)action;
                                     [weak.coordinator sectionCommand:command
                                                           identifier:identifier];
                                     return YES;
                                   }]];
        }
        cell.accessibilityCustomActions = actions;
    }
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
        self.preferredPrimaryColumnWidthFraction = 0.205;
        self.minimumPrimaryColumnWidth = 210;
        self.maximumPrimaryColumnWidth = 210;
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
        [args containsObject:@"--smoke-history"] || [args containsObject:@"--smoke-preset"] ||
        [args containsObject:@"--smoke-picker"] || [args containsObject:@"--smoke-navigation"];
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
    [self.appearanceSnapshot.layer removeAllAnimations];
    [self.appearanceSnapshot removeFromSuperview];
    self.appearanceSnapshot = nil;
    UIWindow* window = self.view.window;
    BOOL changed = window && window.overrideUserInterfaceStyle != style;
    UIView* previousAppearance = self.appearanceInitialized && changed && !NeonReduceMotion()
                                     ? [window snapshotViewAfterScreenUpdates:NO]
                                     : nil;
    self.appearanceInitialized = self.appearanceInitialized || window != nil;
    // Change the inherited window appearance once. Applying the same override
    // to each controller separately causes repeated trait/layout transitions.
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (self.view.window.overrideUserInterfaceStyle != style)
        self.view.window.overrideUserInterfaceStyle = style;
    UINavigationBarAppearance* appearance = [UINavigationBarAppearance new];
    BOOL opaque = !NeonGlassEnabled();
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
        list.tableView.backgroundColor = NeonPanel();
        list.tableView.backgroundView = nil;
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
    [CATransaction commit];
    if (previousAppearance) {
        self.appearanceSnapshot = previousAppearance;
        previousAppearance.frame = window.bounds;
        previousAppearance.userInteractionEnabled = NO;
        [window addSubview:previousAppearance];
        [UIView animateWithDuration:0.16
            animations:^{
              previousAppearance.alpha = 0;
            }
            completion:^(BOOL finished) {
              (void)finished;
              [previousAppearance removeFromSuperview];
              if (self.appearanceSnapshot == previousAppearance)
                  self.appearanceSnapshot = nil;
            }];
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
    [self dismissNavigationOverlay];
    NeonSettingsController* controller = [NeonSettingsController new];
    __weak NeonCoordinator* weakSelf = self;
    if (self.session)
        controller.showHistory = ^{
          [weakSelf dismissViewControllerAnimated:!NeonReduceMotion()
                                       completion:^{
                                         [weakSelf showHistory];
                                       }];
        };
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
    nav.navigationBarHidden = YES;
    nav.modalPresentationStyle =
        fixtureViewportWidth() ? UIModalPresentationCurrentContext : UIModalPresentationFullScreen;
    [self presentViewController:nav animated:!NeonReduceMotion() completion:nil];
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
    [self presentViewController:alert animated:!NeonReduceMotion() completion:nil];
}
- (void)transitionNavigation:(void (^)(void))changes {
    if (self.renderingNavigation) {
        changes();
        return;
    }
    [self.navigationSnapshot removeFromSuperview];
    self.navigationSnapshot = nil;
    BOOL chapterOnly = self.chapterTransition && self.editor;
    CGFloat direction = self.navigationDirection ?: 1;
    NSTimeInterval duration = self.navigationDuration ?: 0.44;
    UIView* source = chapterOnly ? self.editor.editor : self.view;
    CGRect snapshotFrame = [source convertRect:source.bounds toView:self.view];
    UIView* snapshot = (!NeonReduceMotion() && self.view.window)
                           ? [source snapshotViewAfterScreenUpdates:NO]
                           : nil;
    self.renderingNavigation = YES;
    changes();
    self.renderingNavigation = NO;
    [self.view layoutIfNeeded];
    if (!snapshot)
        return;
    snapshot.frame = snapshotFrame;
    snapshot.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    snapshot.userInteractionEnabled = NO;
    snapshot.accessibilityElementsHidden = YES;
    [self.view addSubview:snapshot];
    self.navigationSnapshot = snapshot;
    UIView* incoming =
        chapterOnly
            ? self.editor.editor
            : (self.session
                   ? (self.collapsed
                          ? self.navigation.view
                          : [self viewControllerForColumn:UISplitViewControllerColumnSecondary]
                                .view)
                   : self.libraryShell.view);
    CGFloat distance = chapterOnly ? 26 : 75;
    incoming.transform = CGAffineTransformMakeTranslation(direction * distance, 0);
    incoming.alpha = 0;
    [UIView animateWithDuration:duration
        delay:0
        options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState |
                UIViewAnimationOptionAllowUserInteraction
        animations:^{
          snapshot.alpha = 0;
          snapshot.transform = CGAffineTransformMakeTranslation(-direction * distance * 0.35, 0);
          incoming.transform = CGAffineTransformIdentity;
          incoming.alpha = 1;
        }
        completion:^(BOOL finished) {
          (void)finished;
          [snapshot removeFromSuperview];
        }];
}
- (void)openProject:(NSInteger)index {
    self.navigationDuration = 0.44;
    self.chapterTransition = NO;
    self.navigationDirection = 1;
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
        self.narrowSidebarLayout = self.view.bounds.size.width <= 600;
        self.sidebarHidden = self.narrowSidebarLayout;
        self.sidebarLayoutInitialized = YES;
    }
    self.selectedURL = url;
    self.chapterList = [[NeonList alloc] initWithStyle:UITableViewStylePlain];
    self.chapterList.chapters = YES;
    self.chapterList.coordinator = self;
    [self.navigation setViewControllers:@[ self.libraryList, self.chapterList ] animated:NO];
    [self openSection:0];
}
- (void)openSection:(NSInteger)index {
    [self dismissNavigationOverlay];
    if (!self.renderingNavigation) {
        self.navigationDuration = 0.26;
        self.chapterTransition = !self.sectionCreation;
        NSInteger oldIndex = [self.session.sections
            indexOfObjectPassingTest:^BOOL(NSDictionary* section, NSUInteger idx, BOOL* stop) {
              (void)idx;
              (void)stop;
              return [section[@"id"] isEqual:self.session.selectedSectionID];
            }];
        self.navigationDirection = index < oldIndex ? -1 : 1;
    }
    if (self.editor && ![self.editor flush])
        return;
    [self transitionNavigation:^{
      [self renderSection:index];
    }];
}
- (void)renderSection:(NSInteger)index {
    self.sectionCreation = nil;
    [self.navigation setNavigationBarHidden:YES animated:NO];
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
    if (!self.collapsed && !self.sidebarHidden)
        [self showColumn:UISplitViewControllerColumnPrimary];
    if (!self.collapsed && self.sidebarHidden)
        [self hideColumn:UISplitViewControllerColumnPrimary];
    [editor loadViewIfNeeded];
    [self applyAppearance];
    [self.chapterList.tableView reloadData];
}
- (void)toggleChapters {
    if (self.view.bounds.size.width <= 600) {
        if (self.navigationOverlay) {
            [self dismissNavigationOverlay];
            return;
        }
        UIViewController* overlay = [UIViewController new];
        overlay.view.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.2];
        overlay.view.accessibilityViewIsModal = YES;
        [self addChildViewController:overlay];
        CGFloat overlayTop = self.view.safeAreaInsets.top + 56;
        CGFloat overlayBottom = self.view.safeAreaInsets.bottom + 36;
        overlay.view.frame =
            CGRectMake(0, overlayTop, self.view.bounds.size.width,
                       MAX(0, self.view.bounds.size.height - overlayTop - overlayBottom));
        overlay.view.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.view addSubview:overlay.view];
        [overlay didMoveToParentViewController:self];
        UIButton* scrim = [UIButton buttonWithType:UIButtonTypeCustom];
        scrim.frame = overlay.view.bounds;
        scrim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        scrim.accessibilityLabel = @"Close navigation";
        [scrim addTarget:self
                      action:@selector(dismissNavigationOverlay)
            forControlEvents:UIControlEventTouchUpInside];
        [overlay.view addSubview:scrim];
        NeonList* list = [[NeonList alloc] initWithStyle:UITableViewStylePlain];
        list.chapters = YES;
        list.coordinator = self;
        UINavigationController* navigation =
            [[UINavigationController alloc] initWithRootViewController:list];
        [overlay addChildViewController:navigation];
        navigation.view.frame = CGRectMake(0, 0, MIN(260, self.view.bounds.size.width * 0.85),
                                           overlay.view.bounds.size.height);
        navigation.view.autoresizingMask = UIViewAutoresizingFlexibleHeight;
        [overlay.view addSubview:navigation.view];
        [navigation didMoveToParentViewController:overlay];
        self.navigationOverlay = overlay;
        navigation.view.transform =
            CGAffineTransformMakeTranslation(-navigation.view.bounds.size.width, 0);
        overlay.view.alpha = 0;
        [UIView animateWithDuration:NeonReduceMotion() ? 0 : 0.28
                         animations:^{
                           navigation.view.transform = CGAffineTransformIdentity;
                           overlay.view.alpha = 1;
                         }];
        return;
    }
    self.sidebarChoiceExplicit = YES;
    [self toggleSidebarVisibility];
}
- (void)dismissNavigationOverlay {
    UIViewController* overlay = self.navigationOverlay;
    if (!overlay)
        return;
    self.navigationOverlay = nil;
    [overlay willMoveToParentViewController:nil];
    [UIView animateWithDuration:NeonReduceMotion() ? 0 : 0.28
        animations:^{
          overlay.view.alpha = 0;
          overlay.childViewControllers.firstObject.view.transform =
              CGAffineTransformMakeTranslation(-260, 0);
        }
        completion:^(BOOL finished) {
          (void)finished;
          [overlay.view removeFromSuperview];
          [overlay removeFromParentViewController];
        }];
}
- (void)toggleSidebarVisibility {
    self.sidebarHidden = !self.sidebarHidden;
    [UIView animateWithDuration:NeonReduceMotion() ? 0 : 0.28
                     animations:^{
                       if (self.sidebarHidden)
                           [self hideColumn:UISplitViewControllerColumnPrimary];
                       else
                           [self showColumn:UISplitViewControllerColumnPrimary];
                       [self.view layoutIfNeeded];
                     }];
    [self updateNavigationControls];
}
- (void)updateNavigationControls {
    BOOL compact = self.view.bounds.size.width <= 600;
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
        if (list.chapters && !compact)
            list.navigationItem.rightBarButtonItems = @[];
        list.navigationItem.leftBarButtonItems = items;
    }
    UIViewController* content = self.sectionCreation ?: self.historyController ?: (UIViewController*)self.editor;
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
    BOOL narrow = size.width <= 600;
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
                              self.sectionCreation ?: self.historyController ?: (UIViewController*)self.editor;
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
- (void)askProjectTitle {
    if (self.editor && ![self.editor flush])
        return;
    UIAlertController* alert = [UIAlertController
        alertControllerWithTitle:[@"New " stringByAppendingString:[self selectedPreset][@"title"]]
                         message:[NSString stringWithFormat:@"%@\n\n%@",
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
                                 }]];
    [self presentViewController:alert animated:!NeonReduceMotion() completion:nil];
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
    NeonPresetPicker* picker = [NeonPresetPicker new];
    __weak NeonCoordinator* weak = self;
    picker.onContinue = ^(NSString* identifier) {
      weak.pendingPreset = identifier;
      [weak askProjectTitle];
    };
    UINavigationController* navigation =
        [[UINavigationController alloc] initWithRootViewController:picker];
    navigation.modalPresentationStyle =
        fixtureViewportWidth() ? UIModalPresentationCurrentContext : UIModalPresentationFullScreen;
    navigation.overrideUserInterfaceStyle = self.overrideUserInterfaceStyle;
    [self presentViewController:navigation animated:!NeonReduceMotion() completion:nil];
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
    if (self.sectionCreation) {
        [self cancelSectionCreation];
        return;
    }
    [self.navigation setNavigationBarHidden:YES animated:NO];
    [self dismissNavigationOverlay];
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
    self.sectionCreation = nil;
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
      [controller.navigationController setNavigationBarHidden:YES animated:NO];
      if (!self.collapsed)
          [self hideColumn:UISplitViewControllerColumnPrimary];
      [self applyAppearance];
    }];
}
- (void)newSection {
    if (!self.session || self.sectionCreation || (self.editor && ![self.editor flush]))
        return;
    [self dismissNavigationOverlay];
    if (!self.editor)
        [self showCurrentEditor];
    if (!self.editor)
        return;
    [self.editor.view endEditing:YES];
    NeonSectionCreation* page = [NeonSectionCreation new];
    page.sectionLabel = self.session.preset[@"sectionLabel"];
    page.projectTitle = self.session.title;
    __weak NeonCoordinator* weak = self;
    page.onCancel = ^{
      [weak cancelSectionCreation];
    };
    page.onCreate = ^NSString*(NSString* title) {
      NeonCoordinator* coordinator = weak;
      if (!coordinator || !coordinator.sectionCreation)
          return @"This project is no longer open.";
      NSError* error = nil;
      if (![coordinator.session addSection:title error:&error])
          return error.localizedDescription ?: @"Could not create this section.";
      // Do not flush the previous editor after changing the shared session selection.
      coordinator.editor.session = nil;
      coordinator.editor = nil;
      coordinator.sectionCreation = nil;
      [coordinator openSection:coordinator.session.sections.count - 1];
      [coordinator.editor flush];
      return nil;
    };
    self.navigationDuration = 0.28;
    self.chapterTransition = NO;
    self.navigationDirection = 1;
    [self transitionNavigation:^{
      self.sectionCreation = page;
      if (self.collapsed)
          [self.navigation setViewControllers:@[ self.libraryList, self.chapterList, page ]
                                     animated:NO];
      else {
          [self setViewController:[[UINavigationController alloc] initWithRootViewController:page]
                        forColumn:UISplitViewControllerColumnSecondary];
          [self showColumn:UISplitViewControllerColumnSecondary];
      }
      [self applyAppearance];
    }];
}
- (void)cancelSectionCreation {
    if (!self.sectionCreation)
        return;
    self.navigationDuration = 0.28;
    self.chapterTransition = NO;
    self.navigationDirection = -1;
    [self transitionNavigation:^{
      self.sectionCreation = nil;
      if (self.collapsed)
          [self.navigation setViewControllers:@[ self.libraryList, self.chapterList, self.editor ]
                                     animated:NO];
      else
          [self setViewController:[[UINavigationController alloc]
                                      initWithRootViewController:self.editor]
                        forColumn:UISplitViewControllerColumnSecondary];
      [self applyAppearance];
    }];
}
- (void)showLibrary {
    [self dismissNavigationOverlay];
    self.navigationDuration = 0.38;
    self.chapterTransition = NO;
    self.navigationDirection = -1;
    if (self.editor && ![self.editor flush])
        return;
    [self transitionNavigation:^{
      [self renderLibrary];
    }];
}
- (void)renderLibrary {
    self.sectionCreation = nil;
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
    [self presentViewController:alert animated:!NeonReduceMotion() completion:nil];
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
    [self presentViewController:alert animated:!NeonReduceMotion() completion:nil];
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
    marker(support, @"smoke-started.txt", YES);
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
    if ([args containsObject:@"--smoke-formatting"]) {
        NSMutableArray* diagnostics = [NSMutableArray array];
        void (^record)(NSString*, BOOL) = ^(NSString* step, BOOL valid) {
          [diagnostics addObject:[NSString stringWithFormat:@"%@: %d", step, valid]];
        };
        NeonEditor* controller = self.editor;
        UITextView* editor = controller.editor;
        editor.attributedText =
            [[NSAttributedString alloc] initWithString:@"First paragraph\nSecond paragraph"
                                            attributes:controller.manuscriptTypingAttributes];
        [editor.undoManager removeAllActions];
        editor.selectedRange = NSMakeRange(0, 5);
        [editor.undoManager beginUndoGrouping];
        [controller performWritingCommand:@"bold"];
        [editor.undoManager endUndoGrouping];
        BOOL valid = NeonFormatActive(editor.attributedText, NSMakeRange(0, 5), @"bold");
        record(@"bold", valid);
        [editor.undoManager undo];
        valid = valid && !NeonFormatActive(editor.attributedText, NSMakeRange(0, 5), @"bold");
        record(@"undo", valid);
        [editor.undoManager redo];
        valid = valid && NeonFormatActive(editor.attributedText, NSMakeRange(0, 5), @"bold");
        record(@"redo", valid);
        editor.selectedRange = NSMakeRange(6, 9);
        [controller performWritingCommand:@"italic"];
        [controller performWritingCommand:@"underline"];
        [controller applyTypography];
        valid = valid && NeonFormatActive(editor.attributedText, NSMakeRange(6, 9), @"italic") &&
                NeonFormatActive(editor.attributedText, NSMakeRange(6, 9), @"underline") &&
                NeonFormatActive(editor.attributedText, NSMakeRange(0, 5), @"bold");
        record(@"style", valid);
        editor.selectedRange = NSMakeRange(0, editor.text.length);
        [controller performWritingCommand:@"bullet"];
        valid = valid && NeonFormatActive(editor.attributedText, editor.selectedRange, @"bullet") &&
                [editor.text containsString:@"First paragraph"] &&
                [editor.text containsString:@"Second paragraph"];
        [controller performWritingCommand:@"bullet"];
        record(@"list", valid);
        editor.selectedRange = NSMakeRange(0, 5);
        [controller performWritingCommand:@"heading1"];
        [controller applyTypography];
        valid = valid && NeonFormatActive(editor.attributedText, NSMakeRange(0, 5), @"heading1");
        record(@"heading", valid);
        editor.selectedRange = NSMakeRange(editor.text.length, 0);
        [controller performWritingCommand:@"underline"];
        NSDictionary* typing = editor.typingAttributes;
        [editor insertText:@" typed"];
        valid = valid && [typing[NSUnderlineStyleAttributeName] integerValue] != 0 &&
                NeonFormatActive(editor.attributedText, NSMakeRange(editor.text.length - 6, 6),
                                 @"underline");
        record(@"typing", valid);
        valid = valid && [controller flush];
        record(@"flush", valid);
        NSError* error = nil;
        NeonDocumentSession* reopened = [[NeonDocumentSession alloc] initWithURL:self.selectedURL
                                                                           actor:@"format-smoke"
                                                                           error:&error];
        NSAttributedString* rich =
            reopened.richTextData
                ? [[NSAttributedString alloc]
                            initWithData:reopened.richTextData
                                 options:@{NSDocumentTypeDocumentAttribute : NSRTFTextDocumentType}
                      documentAttributes:nil
                                   error:&error]
                : nil;
        valid = valid && rich && [rich.string isEqual:editor.text] &&
                NeonFormatActive(rich, NSMakeRange(0, 5), @"heading1") &&
                NeonFormatActive(rich, NSMakeRange(6, 9), @"italic") &&
                NeonFormatActive(rich, NSMakeRange(rich.length - 6, 6), @"underline");
        record(@"roundtrip", valid);
        NSAttributedString* verified = [editor.attributedText copy];
        [controller applyFormattedText:[[NSAttributedString alloc] initWithString:@""]
                             selection:NSMakeRange(0, 0)
                                typing:controller.manuscriptTypingAttributes
                                  name:@"Fixture"];
        [controller performWritingCommand:@"heading1"];
        [editor insertText:@"New heading"];
        valid = valid && NeonFormatActive(editor.attributedText, NSMakeRange(0, 3), @"heading1");
        record(@"empty-heading", valid);
        [controller applyFormattedText:[[NSAttributedString alloc]
                                           initWithString:@"Existing\n"
                                               attributes:controller.manuscriptTypingAttributes]
                             selection:NSMakeRange(9, 0)
                                typing:controller.manuscriptTypingAttributes
                                  name:@"Fixture"];
        [controller performWritingCommand:@"heading2"];
        [editor insertText:@"Next heading"];
        valid = valid && NeonFormatActive(editor.attributedText, NSMakeRange(9, 4), @"heading2");
        [controller applyFormattedText:[[NSAttributedString alloc]
                                           initWithString:@"Existing\n"
                                               attributes:controller.manuscriptTypingAttributes]
                             selection:NSMakeRange(9, 0)
                                typing:controller.manuscriptTypingAttributes
                                  name:@"Fixture"];
        [controller performWritingCommand:@"quote"];
        [editor insertText:@"Quoted text"];
        valid = valid && NeonFormatActive(editor.attributedText, NSMakeRange(9, 4), @"quote");
        record(@"trailing-paragraph", valid);
        [controller applyFormattedText:[[NSAttributedString alloc] initWithString:@""]
                             selection:NSMakeRange(0, 0)
                                typing:controller.manuscriptTypingAttributes
                                  name:@"Fixture"];
        [controller performWritingCommand:@"numbered"];
        [diagnostics addObject:[@"list-start: " stringByAppendingString:editor.text]];
        [editor insertText:@"First item"];
        [editor insertText:@"\n"];
        [diagnostics addObject:[@"list-enter1: " stringByAppendingString:editor.text]];
        valid = valid && [editor.text containsString:@"2.\t"];
        [editor insertText:@"Second item"];
        [editor insertText:@"\n"];
        [diagnostics addObject:[@"list-enter2: " stringByAppendingString:editor.text]];
        valid = valid && [editor.text containsString:@"3.\t"];
        [editor insertText:@"\n"];
        [diagnostics addObject:[@"list-exit: " stringByAppendingString:editor.text]];
        NSParagraphStyle* afterList = editor.typingAttributes[NSParagraphStyleAttributeName];
        valid = valid && afterList.textLists.count == 0 && ![editor.text containsString:@"3.\t"];
        record(@"list-return", valid);
        [controller applyFormattedText:verified
                             selection:NSMakeRange(verified.length, 0)
                                typing:controller.manuscriptTypingAttributes
                                  name:@"Fixture"];
        NSAttributedString* beforeLink = [editor.attributedText copy];
        valid = valid &&
                ![controller insertContextValue:@"javascript:alert(1)"
                                        command:@"link"
                                      selection:NSMakeRange(0, 5)
                                         typing:controller.manuscriptTypingAttributes] &&
                [beforeLink isEqualToAttributedString:editor.attributedText];
        valid = valid && [controller insertContextValue:@"https://example.com/reference"
                                                command:@"link"
                                              selection:NSMakeRange(0, 5)
                                                 typing:controller.manuscriptTypingAttributes];
        NSURL* insertedLink = [editor.attributedText attribute:NSLinkAttributeName
                                                       atIndex:0
                                                effectiveRange:nil];
        valid = valid && [insertedLink.absoluteString isEqual:@"https://example.com/reference"] &&
                [controller flush];
        reopened = [[NeonDocumentSession alloc] initWithURL:self.selectedURL
                                                      actor:@"link-smoke"
                                                      error:&error];
        rich =
            reopened.richTextData
                ? [[NSAttributedString alloc]
                            initWithData:reopened.richTextData
                                 options:@{NSDocumentTypeDocumentAttribute : NSRTFTextDocumentType}
                      documentAttributes:nil
                                   error:&error]
                : nil;
        NSURL* savedLink =
            rich.length ? [rich attribute:NSLinkAttributeName atIndex:0 effectiveRange:nil] : nil;
        valid = valid && [savedLink.absoluteString isEqual:insertedLink.absoluteString];
        record(@"link-roundtrip", valid);
        [controller.view layoutIfNeeded];
        valid = valid && controller.formatOverflow && controller.writingOverflow &&
                controller.chromeHistory.frame.size.height >= 44;
        record(@"layout", valid);
        [[diagnostics componentsJoinedByString:@"\n"]
            writeToURL:[support URLByAppendingPathComponent:@"smoke-formatting-details.txt"]
            atomically:YES
              encoding:NSUTF8StringEncoding
                 error:nil];
        marker(support, @"smoke-formatting.txt", valid);
        return;
    }
    if ([args containsObject:@"--smoke-section-creation"]) {
        NeonEditor* previous = self.editor;
        NSString* selected = self.session.selectedSectionID;
        NSUInteger count = self.session.sections.count;
        NSRange selection = previous.editor.selectedRange;
        [self newSection];
        [self.sectionCreation loadViewIfNeeded];
        BOOL valid = self.sectionCreation && !self.presentedViewController &&
                     !self.sectionCreation.createButton.enabled;
        self.sectionCreation.titleField.text = @"  ";
        [self.sectionCreation titleChanged];
        [self.sectionCreation create];
        valid = valid && !self.sectionCreation.createButton.enabled &&
                self.session.sections.count == count;
        [self cancelSectionCreation];
        valid = valid && self.editor == previous &&
                [self.session.selectedSectionID isEqual:selected] &&
                NSEqualRanges(previous.editor.selectedRange, selection);
        [self newSection];
        [self.sectionCreation loadViewIfNeeded];
        self.sectionCreation.titleField.text = @"  A new beginning  ";
        [self.sectionCreation titleChanged];
        valid = valid && self.sectionCreation.createButton.enabled;
        [self.sectionCreation create];
        NSError* error = nil;
        NeonDocumentSession* reopened = [self.library openURL:self.selectedURL error:&error];
        valid = valid && !self.sectionCreation && self.session.sections.count == count + 1 &&
                [self.session.sectionTitle isEqual:@"A new beginning"] &&
                reopened.sections.count == count + 1 &&
                [reopened.sections.lastObject[@"title"] isEqual:@"A new beginning"];
        marker(support, @"smoke-section-creation.txt", valid);
    } else if (self.smoke) {
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
    } else if ([args containsObject:@"--smoke-picker"]) {
        [self newProject];
        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
            dispatch_get_main_queue(), ^{
              UINavigationController* navigation = (id)self.presentedViewController;
              NeonPresetPicker* picker = (id)navigation.topViewController;
              [picker.view layoutIfNeeded];
              UIButton* next = (UIButton*)[picker.footer viewWithTag:601];
              [next layoutIfNeeded];
              CGFloat titleWidth =
                  [next.titleLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)].width;
              UIFont* renderedFont =
                  next.titleLabel.attributedText.length
                      ? [next.titleLabel.attributedText attribute:NSFontAttributeName
                                                          atIndex:0
                                                   effectiveRange:nil]
                      : next.titleLabel.font;
              NSString* detail = [NSString
                  stringWithFormat:@"lines=%ld textWidth=%.3f labelWidth=%.3f labelFont=%@ %.2f "
                                   @"renderedFont=%@ %.2f",
                                   (long)next.titleLabel.numberOfLines, titleWidth,
                                   next.titleLabel.bounds.size.width, next.titleLabel.font.fontName,
                                   next.titleLabel.font.pointSize, renderedFont.fontName,
                                   renderedFont.pointSize];
              [detail writeToURL:[support URLByAppendingPathComponent:@"smoke-picker-details.txt"]
                      atomically:YES
                        encoding:NSUTF8StringEncoding
                           error:nil];
              marker(support, @"smoke-picker.txt",
                     picker != nil &&
                         next.titleLabel.bounds.size.height <= renderedFont.lineHeight + 1 &&
                         titleWidth <= next.titleLabel.bounds.size.width + 1 &&
                         fabs(renderedFont.pointSize - 15) < 0.1);
            });
    } else if ([args containsObject:@"--smoke-navigation"]) {
        [self toggleChapters];
        marker(support, @"smoke-navigation.txt",
               self.navigationOverlay != nil || self.view.bounds.size.width > 600);
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
        BOOL valid = controller.visibleSettingCount == 14;
        NSMutableString* diagnostics = [NSMutableString stringWithFormat:@"initial=%d\n", valid];
        id originalSize = [NeonPreferences() objectForKey:@"manuscriptSize"];
        [NeonPreferences() removeObjectForKey:@"manuscriptSize"];
        for (NSNumber* viewport in @[ @335, @600, @768 ]) {
            NeonSettingsController* probe = [NeonSettingsController new];
            [probe loadViewIfNeeded];
            probe.view.frame = CGRectMake(0, 0, viewport.doubleValue, 768);
            UITableViewCell* sizeCell = [probe tableView:probe.tableView
                                   cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0
                                                                            inSection:1]];
            UIButton* sizeControl = (id)settingControl(sizeCell, @"manuscriptSize");
            CGFloat expectedSize = viewport.doubleValue > 600 ? 19 : 17;
            NSString* expectedTitle =
                expectedSize == 19 ? @"Standard · 19 pt ▾" : @"Small · 17 pt ▾";
            valid = valid && [sizeControl.currentTitle isEqual:expectedTitle] &&
                    NeonTextSizeForViewport(viewport.doubleValue) == expectedSize &&
                    [NeonPreferences() objectForKey:@"manuscriptSize"] == nil;
            [NeonPreferences() setDouble:22 forKey:@"manuscriptSize"];
            sizeCell = [probe tableView:probe.tableView
                  cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1]];
            sizeControl = (id)settingControl(sizeCell, @"manuscriptSize");
            valid = valid && [sizeControl.currentTitle isEqual:@"Large · 22 pt ▾"] &&
                    NeonTextSizeForViewport(viewport.doubleValue) == 22 &&
                    [NeonPreferences() doubleForKey:@"manuscriptSize"] == 22;
            [NeonPreferences() removeObjectForKey:@"manuscriptSize"];
        }
        [diagnostics appendFormat:@"size=%d\n", valid];
        NeonSettingsController* resizingProbe = [NeonSettingsController new];
        [resizingProbe loadViewIfNeeded];
        for (NSNumber* viewport in @[ @335, @1024, @335 ]) {
            resizingProbe.view.frame = CGRectMake(0, 0, viewport.doubleValue, 768);
            [resizingProbe.view setNeedsLayout];
            [resizingProbe.view layoutIfNeeded];
            for (UIView* container in @[
                     resizingProbe.tableView.tableHeaderView,
                     resizingProbe.tableView.tableFooterView
                 ])
                for (UIView* content in container.subviews)
                    valid = valid && fabs(content.frame.size.width -
                                          resizingProbe.tableView.bounds.size.width) < .5;
        }
        if (originalSize)
            [NeonPreferences() setObject:originalSize forKey:@"manuscriptSize"];
        if (@available(iOS 26.0, *)) {
            if (NeonGlassEnabled()) {
                UIView* host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 56)];
                NeonApplyGlassBackdrop(host, 0);
                UIView* originalGlass = host.subviews.firstObject;
                host.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
                NeonApplyGlassBackdrop(host, 8);
                valid = valid && originalGlass != nil && host.subviews.count == 1 &&
                        host.subviews.firstObject == originalGlass &&
                        originalGlass.layer.cornerRadius == 8;
                host.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
                NeonApplyGlassBackdrop(host, 0);
                valid =
                    valid && host.subviews.count == 1 && host.subviews.firstObject == originalGlass;
            }
        }
        [diagnostics appendFormat:@"layout-glass=%d\n", valid];
        UITextView* originalEditor = self.editor.editor;
        NSString* originalDraft = originalEditor.text;
        NSRange originalSelection = originalEditor.selectedRange;
        id originalAppearance = [NeonPreferences() objectForKey:@"appearance"];
        id originalReducedMotion = [NeonPreferences() objectForKey:@"reduceMotion"];
        [NeonPreferences() setBool:NO forKey:@"reduceMotion"];
        [NeonPreferences() setInteger:1 forKey:@"appearance"];
        [self applyAppearance];
        UIView* firstSnapshot = self.appearanceSnapshot;
        [NeonPreferences() setInteger:2 forKey:@"appearance"];
        [self applyAppearance];
        valid = valid && firstSnapshot.superview == nil &&
                (!firstSnapshot || firstSnapshot != self.appearanceSnapshot);
        if (!UIAccessibilityIsReduceMotionEnabled())
            valid = valid && firstSnapshot != nil && self.appearanceSnapshot != nil;
        [NeonPreferences() setBool:YES forKey:@"reduceMotion"];
        [NeonPreferences() setInteger:1 forKey:@"appearance"];
        [self applyAppearance];
        valid = valid && self.appearanceSnapshot == nil && self.editor.editor == originalEditor &&
                [originalEditor.text isEqual:originalDraft] &&
                NSEqualRanges(originalSelection, originalEditor.selectedRange);
        if (originalAppearance)
            [NeonPreferences() setObject:originalAppearance forKey:@"appearance"];
        else
            [NeonPreferences() removeObjectForKey:@"appearance"];
        if (originalReducedMotion)
            [NeonPreferences() setObject:originalReducedMotion forKey:@"reduceMotion"];
        else
            [NeonPreferences() removeObjectForKey:@"reduceMotion"];
        [self applyAppearance];
        [diagnostics appendFormat:@"appearance=%d\n", valid];
        [controller filterSettings:@"PARAGRAPH"];
        valid = valid && controller.visibleSettingCount == 1;
        UITableViewCell* cell = [controller tableView:controller.tableView
                                cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:1]];
        UIStepper* stepper = (id)settingControl(cell, @"paragraphSpacing");
        NSString* draft = self.editor.editor.text;
        NSRange selection = self.editor.editor.selectedRange;
        NSRange separatorRange = [draft rangeOfString:@"\n\n"];
        if (separatorRange.location != NSNotFound) {
            self.editor.editor.selectedRange = NSMakeRange(separatorRange.location + 1, 0);
            self.editor.editor.typingAttributes =
                [self.editor.editor.textStorage attributesAtIndex:separatorRange.location + 1
                                                   effectiveRange:nil];
            [self.editor textViewDidChangeSelection:self.editor.editor];
            UIFont* typingFont = self.editor.editor.typingAttributes[NSFontAttributeName];
            UIFont* bodyFont = self.editor.manuscriptTypingAttributes[NSFontAttributeName];
            [diagnostics appendFormat:@"fonts=%@ / %@ equal=%d\n", typingFont, bodyFont,
                                      [typingFont isEqual:bodyFont]];
            // RTF decoding and CoreText trait copies produce equivalent fonts
            // with different descriptor objects. Check the rendered properties.
            UIFontDescriptorSymbolicTraits inlineTraits =
                UIFontDescriptorTraitBold | UIFontDescriptorTraitItalic;
            BOOL sameBodyFont = [typingFont.familyName isEqual:bodyFont.familyName] &&
                                fabs(typingFont.pointSize - bodyFont.pointSize) < .01 &&
                                (typingFont.fontDescriptor.symbolicTraits & inlineTraits) ==
                                    (bodyFont.fontDescriptor.symbolicTraits & inlineTraits);
            valid = valid && sameBodyFont && [self.editor.editor.text isEqual:draft];
            self.editor.editor.selectedRange = selection;
        }
        [diagnostics appendFormat:@"selection=%d\n", valid];
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
        [diagnostics appendFormat:@"final=%d\n", valid];
        [diagnostics writeToURL:[support URLByAppendingPathComponent:@"smoke-settings-details.txt"]
                     atomically:YES
                       encoding:NSUTF8StringEncoding
                          error:nil];
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
              return editor.wideTypography ? 1.85 : 1.8;
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
        if ([args containsObject:@"--ui-testing"]) {
            NSDictionary* project = [NeonUITestFixtureConfiguration()[@"projects"] firstObject];
            NSDictionary* section = [project[@"sections"] firstObject];
            marker(support, @"smoke-reopen.txt",
                   [self.editor.editor.text isEqual:section[@"text"]] &&
                       [self.session.title isEqual:project[@"title"]] &&
                       [self.editor.heading.text isEqual:section[@"title"]]);
        } else {
            marker(support, @"smoke-reopen.txt",
                   [self.editor.editor.text containsString:@"A native Apple draft."]);
        }
    }
}
@end
// Test-only native container: verifies narrow layouts without claiming real Split View.
@interface NeonViewportFixture : UIViewController
@property(nonatomic) NeonCoordinator* workspace;
@end
@implementation NeonViewportFixture
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.darkGrayColor;
    [self addChildViewController:self.workspace];
    self.workspace.definesPresentationContext = YES;
    [self.view addSubview:self.workspace.view];
    [self.workspace didMoveToParentViewController:self];
    if (fixtureViewportWidth() <= 600)
        [self setOverrideTraitCollection:[UITraitCollection traitCollectionWithHorizontalSizeClass:
                                                                UIUserInterfaceSizeClassCompact]
                  forChildViewController:self.workspace];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.workspace.view.frame =
        CGRectMake(0, self.view.safeAreaInsets.top, fixtureViewportWidth(),
                   MIN(768, self.view.bounds.size.height - self.view.safeAreaInsets.top));
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
    if (fixtureViewportWidth()) {
        NeonViewportFixture* fixture = [NeonViewportFixture new];
        fixture.workspace = self.coordinator;
        self.window.rootViewController = fixture;
    } else {
        self.window.rootViewController = self.coordinator;
    }
    [self.window makeKeyAndVisible];
    [self.coordinator applyAppearance];
    if (fixtureViewportWidth() > self.window.bounds.size.width) {
        dispatch_async(dispatch_get_main_queue(), ^{
          UIWindowSceneGeometryPreferencesIOS* geometry =
              [[UIWindowSceneGeometryPreferencesIOS alloc]
                  initWithInterfaceOrientations:UIInterfaceOrientationMaskLandscapeLeft];
          [(UIWindowScene*)scene
              requestGeometryUpdateWithPreferences:geometry
                                      errorHandler:^(NSError* error) {
                                        NSLog(@"Viewport fixture orientation: %@", error);
                                      }];
        });
    }
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
