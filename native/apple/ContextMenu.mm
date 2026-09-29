#include "ContextMenu.h"
#import <QuartzCore/QuartzCore.h>
@implementation NeonMenuAction
@end
NeonMenuAction* NeonAction(NSString* title, NSString* symbol, BOOL enabled, BOOL destructive,
                           void (^perform)(void)) {
    NeonMenuAction* action = [NeonMenuAction new];
    action.title = title;
    action.symbol = symbol;
    action.enabled = enabled;
    action.destructive = destructive;
    action.perform = perform;
    return action;
}
#if TARGET_OS_IPHONE
static __weak UIViewController* mobileMenu;
void NeonDismissMenu() {
    [mobileMenu dismissViewControllerAnimated:NO completion:nil];
}
@interface NeonMenuController : UIViewController <UIPopoverPresentationControllerDelegate>
@property(nonatomic, strong) NSArray<NeonMenuAction*>* actions;
@end
@implementation NeonMenuController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = NeonPanel();
    self.view.accessibilityViewIsModal = YES;
    UIStackView* stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 2;
    for (NeonMenuAction* item in self.actions) {
        UIButton* row = [UIButton buttonWithType:UIButtonTypeSystem];
        UIButtonConfiguration* config = [UIButtonConfiguration plainButtonConfiguration];
        config.title = item.title;
        config.image = [UIImage systemImageNamed:item.symbol];
        config.imagePadding = 12;
        config.contentInsets = NSDirectionalEdgeInsetsMake(8, 12, 8, 12);
        config.baseForegroundColor = item.destructive ? UIColor.systemRedColor : NeonInk();
        row.configuration = config;
        row.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
        row.titleLabel.font = NeonUI(16);
        row.enabled = item.enabled;
        row.accessibilityLabel = item.title;
        [row.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
        __weak NeonMenuController* weakSelf = self;
        [row addAction:[UIAction actionWithHandler:^(UIAction* action) {
               (void)action;
               [weakSelf dismissViewControllerAnimated:NO
                                            completion:^{
                                              if (item.perform)
                                                  item.perform();
                                            }];
             }]
            forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:row];
    }
    UIScrollView* scroll = [UIScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scroll];
    [scroll addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8],
        [scroll.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:8],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-8],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor]
    ]];
}
- (UIModalPresentationStyle)
    adaptivePresentationStyleForPresentationController:(UIPresentationController*)controller
                                       traitCollection:(UITraitCollection*)traits {
    (void)controller;
    (void)traits;
    return UIModalPresentationNone;
}
@end
void NeonShowMenu(UIViewController* host, UIView* anchor, CGRect rect,
                  NSArray<NeonMenuAction*>* actions) {
    if (host.presentedViewController)
        return;
    NeonMenuController* menu = [NeonMenuController new];
    menu.actions = actions;
    mobileMenu = menu;
    menu.preferredContentSize = CGSizeMake(280, MIN(540, actions.count * 46 + 16));
    menu.modalPresentationStyle = UIModalPresentationPopover;
    menu.popoverPresentationController.sourceView = anchor;
    menu.popoverPresentationController.sourceRect = rect;
    menu.popoverPresentationController.delegate = menu;
    menu.popoverPresentationController.backgroundColor = NeonPanel();
    [host presentViewController:menu animated:YES completion:nil];
}
#else
static NSPopover* activeMenu;
void NeonDismissMenu() {
    [activeMenu close];
    activeMenu = nil;
}
@interface NeonMenuButton : NSButton
@property(nonatomic, strong) NeonMenuAction* command;
@end
@implementation NeonMenuButton
- (BOOL)acceptsFirstResponder {
    return YES;
}
- (void)drawRect:(NSRect)rect {
    (void)rect;
    BOOL highlighted = self.highlighted || self.window.firstResponder == self;
    if (highlighted) {
        [[NeonAccent() colorWithAlphaComponent:0.16] setFill];
        [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:6 yRadius:6] fill];
    }
    NSColor* color = !self.enabled              ? NeonMuted()
                     : self.command.destructive ? NSColor.systemRedColor
                                                : NeonInk();
    NSImage* icon = [NSImage imageWithSystemSymbolName:self.command.symbol
                              accessibilityDescription:nil];
    icon = [icon imageWithSymbolConfiguration:[NSImageSymbolConfiguration
                                                  configurationWithPaletteColors:@[ color ]]];
    [icon drawInRect:NSMakeRect(12, 10, 16, 16)];
    [self.command.title
            drawInRect:NSMakeRect(40, 8, self.bounds.size.width - 48, 24)
        withAttributes:@{NSFontAttributeName : NeonUI(15), NSForegroundColorAttributeName : color}];
}
- (void)keyDown:(NSEvent*)event {
    if (event.keyCode == 53) {
        [activeMenu close];
        return;
    }
    if (event.keyCode == 36 || event.keyCode == 49) {
        [self performClick:nil];
        return;
    }
    if (event.keyCode == 125 || event.keyCode == 126) {
        NSView* next = event.keyCode == 125 ? self.nextKeyView : self.previousKeyView;
        [self.window makeFirstResponder:next];
        [self.superview setNeedsDisplay:YES];
        return;
    }
    [super keyDown:event];
}
@end
@interface NeonMenuSurface : NSView
@end
@implementation NeonMenuSurface
- (void)drawRect:(NSRect)rect {
    [NeonPanel() setFill];
    NSRectFill(rect);
}
@end
@interface NeonMenuController : NSViewController
@property(nonatomic, strong) NSArray<NeonMenuAction*>* actions;
@end
@implementation NeonMenuController
- (void)loadView {
    self.view =
        [[NeonMenuSurface alloc] initWithFrame:NSMakeRect(0, 0, 280, self.actions.count * 36 + 16)];

    NSMutableArray<NSButton*>* rows = [NSMutableArray array];
    NSInteger i = 0;
    for (NeonMenuAction* item in self.actions) {
        NeonMenuButton* row = [[NeonMenuButton alloc]
            initWithFrame:NSMakeRect(8, self.view.bounds.size.height - 44 - i++ * 36, 264, 36)];
        row.command = item;
        row.title = item.title;
        row.enabled = item.enabled;
        row.bordered = NO;
        row.focusRingType = NSFocusRingTypeNone;
        row.target = self;
        row.action = @selector(choose:);
        row.accessibilityLabel = item.title;
        [self.view addSubview:row];
        if (item.enabled)
            [rows addObject:row];
    }
    for (NSUInteger n = 0; n < rows.count; ++n)
        rows[n].nextKeyView = rows[(n + 1) % rows.count];
    self.view.nextKeyView = rows.firstObject;
}
- (void)viewDidAppear {
    [super viewDidAppear];
    [self.view.window makeFirstResponder:self.view.nextKeyView];
}
- (void)choose:(NeonMenuButton*)sender {
    void (^perform)(void) = sender.command.perform;
    [activeMenu close];
    activeMenu = nil;
    if (perform)
        perform();
}
@end
void NeonShowMenu(NSView* anchor, NSRect rect, NSArray<NeonMenuAction*>* actions) {
    [activeMenu close];
    NeonMenuController* controller = [NeonMenuController new];
    controller.actions = actions;
    activeMenu = [NSPopover new];
    activeMenu.behavior = NSPopoverBehaviorTransient;
    activeMenu.contentViewController = controller;
    activeMenu.appearance = anchor.effectiveAppearance;
    [activeMenu showRelativeToRect:rect ofView:anchor preferredEdge:NSRectEdgeMaxY];
}
#endif
