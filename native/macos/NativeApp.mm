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
#import "WorkspaceRoute.h"
#import <QuartzCore/QuartzCore.h>
#include <cstdio>
#include <cstdlib>
#include <string>

@interface NeonColumn : NSStackView
@end
@implementation NeonColumn
- (BOOL)isFlipped {
    return YES;
}
@end
// A temporary visual snapshot must never intercept editing or navigation.
@interface NeonTransitionOverlay : NSImageView
@end
@implementation NeonTransitionOverlay
- (NSView*)hitTest:(NSPoint)point {
    (void)point;
    return nil;
}
@end
// Quiet commands share hover, keyboard focus and disabled states with NeonButton.
@interface NeonPaperCommand : NeonButton
@end
@implementation NeonPaperCommand
- (instancetype)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.kind = NeonButtonQuiet;
        self.compact = YES;
    }
    return self;
}
@end
@interface NeonChapterRow : NSStackView
@property(nonatomic) BOOL currentChapter;
@end
@implementation NeonChapterRow {
    NSTrackingArea* _rowTracking;
    BOOL _hovered;
}
- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (_rowTracking)
        [self removeTrackingArea:_rowTracking];
    _rowTracking =
        [[NSTrackingArea alloc] initWithRect:self.bounds
                                     options:NSTrackingMouseEnteredAndExited |
                                             NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect
                                       owner:self
                                    userInfo:nil];
    [self addTrackingArea:_rowTracking];
}
- (void)mouseEntered:(NSEvent*)event {
    (void)event;
    _hovered = YES;
    self.needsDisplay = YES;
}
- (void)mouseExited:(NSEvent*)event {
    (void)event;
    _hovered = NO;
    self.needsDisplay = YES;
}
- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    self.needsDisplay = YES;
}
- (void)drawRect:(NSRect)rect {
    (void)rect;
    NeonDrawSidebarRow(self, self.currentChapter, _hovered);
}
@end

namespace {
NSTextField* label(NSString* text, NSFont* font, NSColor* color) {
    NSTextField* label = [NSTextField wrappingLabelWithString:text];
    label.font = font;
    label.textColor = color;
    return label;
}
NSImage* workspaceIcon(NSString* name) {
    NSURL* url = [NSBundle.mainBundle URLForResource:name
                                       withExtension:@"png"
                                        subdirectory:@"icons"];
    NSImage* image = url ? [[NSImage alloc] initWithContentsOfURL:url] : nil;
    image.size = NSMakeSize(20, 20);
    [image setTemplate:YES];
    return image;
}
NSButton* button(NSString* title, NSString* symbol, id target, SEL action) {
    NSButton* button = [NSButton buttonWithTitle:title target:target action:action];
    button.bezelStyle = NSBezelStyleRecessed;
    button.bordered = NO;
    button.font = NeonUI(15);
    button.contentTintColor = NeonAccent();
    if (symbol)
        button.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:title];
    button.imagePosition = NSImageLeading;
    return button;
}
NSStackView* column(NSArray<NSView*>* views, CGFloat spacing) {
    NSStackView* stack = [NeonColumn stackViewWithViews:views];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = spacing;
    return stack;
}
void pin(NSView* child, NSView* parent) {
    child.translatesAutoresizingMaskIntoConstraints = NO;
    [parent addSubview:child];
    [NSLayoutConstraint activateConstraints:@[
        [child.leadingAnchor constraintEqualToAnchor:parent.leadingAnchor],
        [child.trailingAnchor constraintEqualToAnchor:parent.trailingAnchor],
        [child.topAnchor constraintEqualToAnchor:parent.topAnchor],
        [child.bottomAnchor constraintEqualToAnchor:parent.bottomAnchor]
    ]];
}
NSView* settingControl(NSView* root, NSString* identifier) {
    if ([root.identifier isEqual:identifier])
        return root;
    for (NSView* child in root.subviews) {
        NSView* match = settingControl(child, identifier);
        if (match)
            return match;
    }
    return nil;
}
NSUInteger words(NSString* text) {
    __block NSUInteger count = 0;
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                             options:NSStringEnumerationByWords
                          usingBlock:^(NSString*, NSRange, NSRange, BOOL*) {
                            ++count;
                          }];
    return count;
}
} // namespace
@interface NeonSliderCell : NSSliderCell
@end
@implementation NeonSliderCell
- (void)drawBarInside:(NSRect)rect flipped:(BOOL)flipped {
    (void)flipped;
    NSRect track = NSMakeRect(rect.origin.x, NSMidY(rect) - 2, rect.size.width, 4);
    [[NeonMuted() colorWithAlphaComponent:0.35] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:track xRadius:2 yRadius:2] fill];
    track.size.width *= (self.doubleValue - self.minValue) / (self.maxValue - self.minValue);
    [NeonAccent() setFill];
    [[NSBezierPath bezierPathWithRoundedRect:track xRadius:2 yRadius:2] fill];
}
@end
@interface NeonSlider : NSSlider
@end
@implementation NeonSlider
+ (Class)cellClass {
    return NeonSliderCell.class;
}
@end
@interface NeonSurface : NSView
@property(nonatomic) BOOL panel;
@end
@implementation NeonSurface
- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    self.needsDisplay = YES;
}
- (void)drawRect:(NSRect)rect {
    [(self.panel ? NeonPanel() : NeonPaper()) setFill];
    NSRectFill(rect);
}
@end
@interface NeonTextView : NSTextView
@property(nonatomic, copy) void (^compositionDidEnd)(void);
@end
@implementation NeonTextView
- (void)unmarkText {
    [super unmarkText];
    if (!self.hasMarkedText && self.compositionDidEnd)
        self.compositionDidEnd();
}
- (NSMenu*)menuForEvent:(NSEvent*)event {
    (void)event;
    return nil;
}
- (void)rightMouseDown:(NSEvent*)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    BOOL selected = self.selectedRange.length > 0;
    NeonShowMenu(self, NSMakeRect(point.x, point.y, 1, 1), @[
        NeonAction(@"Undo", @"arrow.uturn.backward", self.undoManager.canUndo, NO,
                   ^{
                     [self.undoManager undo];
                   }),
        NeonAction(@"Redo", @"arrow.uturn.forward", self.undoManager.canRedo, NO,
                   ^{
                     [self.undoManager redo];
                   }),
        NeonAction(@"Cut", @"scissors", selected, NO,
                   ^{
                     [self cut:nil];
                   }),
        NeonAction(@"Copy", @"doc.on.doc", selected, NO,
                   ^{
                     [self copy:nil];
                   }),
        NeonAction(@"Paste", @"doc.on.clipboard",
                   [NSPasteboard.generalPasteboard stringForType:NSPasteboardTypeString] != nil, NO,
                   ^{
                     [self pasteAsPlainText:nil];
                   }),
        NeonAction(@"Select All", @"selection.pin.in.out", self.string.length > 0, NO,
                   ^{
                     [self selectAll:nil];
                   })
    ]);
}
@end
@interface NeonBookCover : NSButton
@property(nonatomic, copy) void (^contextAction)(NSView*, NSRect);
@property(nonatomic, copy) NSString* titleText;
@end
@implementation NeonBookCover
- (void)rightMouseDown:(NSEvent*)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    if (self.contextAction)
        self.contextAction(self, NSMakeRect(point.x, point.y, 1, 1));
}
- (void)drawRect:(NSRect)rect {
    (void)rect;
    [NSGraphicsContext saveGraphicsState];
    [NSBezierPath clipRect:self.bounds];
    [[NSColor colorWithSRGBRed:0.84 green:0.81 blue:0.72 alpha:1] setFill];
    NSRectFill(self.bounds);
    [[NSColor colorWithSRGBRed:0.24 green:0.37 blue:0.39 alpha:1] setFill];
    NSRectFill(NSMakeRect(0, self.bounds.size.height * 0.72, self.bounds.size.width,
                          self.bounds.size.height * 0.28));
    [[NSColor colorWithSRGBRed:0.13 green:0.26 blue:0.29 alpha:1] setFill];
    [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(-30, self.bounds.size.height - 22, 170, 60)]
        fill];
    [self.titleText drawInRect:NSMakeRect(12, 14, self.bounds.size.width - 24,
                                          self.bounds.size.height * 0.68 - 18)
                withAttributes:@{
                    NSFontAttributeName : NeonSerif(15),
                    NSForegroundColorAttributeName : NSColor.blackColor
                }];
    [NSGraphicsContext restoreGraphicsState];
}
@end
@interface NeonApp
    : NSObject <NSApplicationDelegate, NSWindowDelegate, NSTextViewDelegate, NSToolbarDelegate>
@property(nonatomic, strong) NSWindow* window;
@property(nonatomic, strong) NSSplitViewController* split;
@property(nonatomic, strong) NSViewController* sidebar;
@property(nonatomic, strong) NSViewController* content;
@property(nonatomic, strong) NeonLibraryStore* library;
@property(nonatomic, strong) NSArray<NSDictionary*>* projects;
@property(nonatomic, strong) NeonDocumentSession* session;
@property(nonatomic, strong) NSURL* selectedURL;
@property(nonatomic, strong) NSTextView* editor;
@property(nonatomic, strong) NSTextView* historyEditor;
@property(nonatomic, copy) NSString* historySection;
@property(nonatomic, strong) NeonDocumentSession* historySession;
@property(nonatomic) NSPoint historyScroll;
@property(nonatomic, strong) NSTextField* status;
@property(nonatomic, strong) NSTextField* guidance;
@property(nonatomic, strong) NeonInlineTitle* windowTitle;
@property(nonatomic, strong) NSToolbarItem* workspaceItem;
@property(nonatomic, strong) NSLayoutConstraint* toolbarTitleWidth;
@property(nonatomic, strong) NeonInlineTitle* chapterTitle;
@property(nonatomic, strong) NeonWorkspaceController* workspaceController;
@property(nonatomic, strong) NeonLibraryController* libraryController;
@property(nonatomic, strong) NSTitlebarAccessoryViewController* chromeSpacer;
@property(nonatomic) BOOL focusMode;
@property(nonatomic) BOOL pendingTypography;
@property(nonatomic) BOOL immediateSidebarTransition;
@property(nonatomic) BOOL focusSidebarWasCollapsed;
@property(nonatomic, strong) NSView* sidebarBody;
@property(nonatomic, strong) NSTextField* sidebarSummary;
@property(nonatomic, strong) NSView* sidebarMaterial;
- (BOOL)renameInline:(NSString*)title section:(NSString*)identifier;
@property(nonatomic, strong) NSTimer* timer;
@property(nonatomic, strong) NSPopover* typography;
@property(nonatomic, strong) NSPanel* settings;
@property(nonatomic, strong) NSImageView* transitionOverlay;
@property(nonatomic, strong) NeonHistoryController* historyController;
@property(nonatomic, strong) NSTextField* presetDescription;
@property(nonatomic, strong) NSLayoutConstraint* measureConstraint;
@property(nonatomic) BOOL trashMode;
- (void)projectMenu:(NSURL*)url title:(NSString*)title anchor:(id)anchor rect:(NSRect)rect;
- (void)sectionMenu:(NSString*)identifier anchor:(NSView*)anchor rect:(NSRect)rect;
- (void)projectCommand:(NSString*)command url:(NSURL*)url title:(NSString*)title;
- (void)sectionCommand:(NSString*)command identifier:(NSString*)identifier;

@property(nonatomic) BOOL smoke;
- (BOOL)flush;
@end
@implementation NeonApp
- (void)updateAppIcon {
    NSAppearance* appearance = self.window.effectiveAppearance ?: NSApp.effectiveAppearance;
    NSString* match = [appearance
        bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]];
    NSString* name =
        [match isEqualToString:NSAppearanceNameDarkAqua] ? @"macos-dark" : @"macos-light";
    NSURL* url = [NSBundle.mainBundle URLForResource:name
                                       withExtension:@"png"
                                        subdirectory:@"app-icons"];
    NSImage* icon = url ? [[NSImage alloc] initWithContentsOfURL:url] : nil;
    if (icon)
        NSApp.applicationIconImage = icon;
}
- (void)observeValueForKeyPath:(NSString*)keyPath
                      ofObject:(id)object
                        change:(NSDictionary*)change
                       context:(void*)context {
    if (object == NSApp && [keyPath isEqualToString:@"effectiveAppearance"]) {
        [self updateAppIcon];
        return;
    }
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}
- (void)applicationWillTerminate:(NSNotification*)note {
    (void)note;
    [NSApp removeObserver:self forKeyPath:@"effectiveAppearance"];
}
- (void)applicationDidFinishLaunching:(NSNotification*)note {
    (void)note;
    NeonRegisterFonts();
    [NSApp addObserver:self forKeyPath:@"effectiveAppearance" options:0 context:nil];
    [self updateAppIcon];
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--control-states"]) {
        self.window = [[NSWindow alloc]
            initWithContentRect:NSMakeRect(0, 0, 560, 940)
                      styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                NSWindowStyleMaskResizable
                        backing:NSBackingStoreBuffered
                          defer:NO];
        self.window.contentView = NeonControlStateFixture();
        [self.window makeKeyAndOrderFront:nil];
        [NSApp activateIgnoringOtherApps:YES];
        return;
    }
    self.smoke = [NSProcessInfo.processInfo.arguments containsObject:@"--smoke-test"];
    BOOL uiTesting = [NSProcessInfo.processInfo.arguments containsObject:@"--ui-testing"];
    NSURL* root =
        (self.smoke || uiTesting)
            ? [NSURL fileURLWithPath:[NSTemporaryDirectory()
                                         stringByAppendingPathComponent:NSUUID.UUID.UUIDString]]
            : [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                      inDomains:NSUserDomainMask]
                      .firstObject URLByAppendingPathComponent:@"Neon Apple Preview"];
    self.library = [[NeonLibraryStore alloc] initWithDirectory:root];
    NSError* error = nil;
    if ((uiTesting && !NeonSeedUITestLibrary(self.library, &error)) ||
        (self.smoke && ![self.library seedPreview:&error])) {
        fprintf(stderr, "%s\n", error.localizedDescription.UTF8String);
        exit(2);
    }
    self.window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 1180, 820)
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                            NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                    backing:NSBackingStoreBuffered
                      defer:NO];
    self.window.title = @"Neon";
    self.window.titleVisibility = NSWindowTitleHidden;
    self.window.titlebarAppearsTransparent = YES;
    self.window.minSize = NSMakeSize(760, 560);
    self.window.delegate = self;
    self.window.toolbarStyle = NSWindowToolbarStyleUnified;
    NSToolbar* toolbar = [[NSToolbar alloc] initWithIdentifier:@"NeonEditorial"];
    toolbar.delegate = self;
    toolbar.displayMode = NSToolbarDisplayModeIconOnly;

    self.split = [NSSplitViewController new];
    self.sidebar = [NSViewController new];
    self.sidebar.view = [NSView new];
    self.sidebarBody = [NSView new];
    pin(self.sidebarBody, self.sidebar.view);
    NSSplitViewItem* side = [NSSplitViewItem splitViewItemWithViewController:self.sidebar];
    side.minimumThickness = 220;
    side.maximumThickness = 290;
    side.canCollapse = YES;
    [self.split addSplitViewItem:side];
    self.content = [NSViewController new];
    self.content.view = [NeonSurface new];
    [self.split addSplitViewItem:[NSSplitViewItem splitViewItemWithViewController:self.content]];
    self.window.contentViewController = self.split;
    self.window.toolbar = toolbar;
    self.chromeSpacer = [NSTitlebarAccessoryViewController new];
    NeonSurface* spacer = [[NeonSurface alloc] initWithFrame:NSMakeRect(0, 0, 100, 16)];
    spacer.panel = YES;
    spacer.wantsLayer = YES;
    spacer.clipsToBounds = YES;

    self.chromeSpacer.view = spacer;
    self.chromeSpacer.layoutAttribute = NSLayoutAttributeBottom;
    [self.window addTitlebarAccessoryViewController:self.chromeSpacer];
    [NSWorkspace.sharedWorkspace.notificationCenter
        addObserver:self
           selector:@selector(accessibilityChanged:)
               name:NSWorkspaceAccessibilityDisplayOptionsDidChangeNotification
             object:nil];
    [self applyAppearance];
    [self installMenu];
    [self showLibrary:nil];
    [self.window setFrame:NSInsetRect(NSScreen.mainScreen.visibleFrame, 24, 24) display:YES];
    [self.split.splitView setPosition:self.session ? 264 : 248 ofDividerAtIndex:0];
    if (self.smoke || uiTesting) {
        [self.window setFrame:NSMakeRect(80, 80, 1200, 860) display:YES];
        [self.split.splitView setPosition:self.session ? 264 : 248 ofDividerAtIndex:0];
    }
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    if (self.smoke)
        [self performSelector:@selector(captureLibrary) withObject:nil afterDelay:2];
}
- (void)accessibilityChanged:(NSNotification*)note {
    (void)note;
    [self applyAppearance];
}
- (void)applyAppearance {
    self.window.appearance =
        NeonAppearance() == 1   ? [NSAppearance appearanceNamed:NSAppearanceNameAqua]
        : NeonAppearance() == 2 ? [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]
                                : nil;
    [self updateAppIcon];
    self.window.backgroundColor = NeonPanel();
    [self.sidebarMaterial removeFromSuperview];
    NeonSurface* panel = [NeonSurface new];
    panel.panel = YES;
    self.sidebarMaterial = panel;
    pin(self.sidebarMaterial, self.sidebar.view);
    [self.sidebar.view addSubview:self.sidebarBody
                       positioned:NSWindowAbove
                       relativeTo:self.sidebarMaterial];
    [self.sidebar.view setNeedsDisplay:YES];
    [self.content.view setNeedsDisplay:YES];
    if (self.editor) {
        self.editor.backgroundColor = NeonPaper();
        self.editor.textColor = NeonInk();
    }
}
- (void)showError:(NSError*)error {
    if (self.smoke) {
        fprintf(stderr, "%s\n", error.localizedDescription.UTF8String);
        exit(2);
    }
    NSAlert* alert = [NSAlert new];
    alert.messageText = @"Could not save or open this project";
    alert.informativeText = error.localizedDescription ?: @"Your current draft remains open.";
    [alert runModal];
}
- (void)installMenu {
    NSMenu* menu = [NSMenu new];
    NSMenuItem* app = [NSMenuItem new];
    app.submenu = [[NSMenu alloc] initWithTitle:@"Neon"];
    [app.submenu addItemWithTitle:@"About Neon" action:@selector(about:) keyEquivalent:@""];
    [app.submenu addItemWithTitle:@"Settings…" action:@selector(showSettings:) keyEquivalent:@","];
    [app.submenu addItemWithTitle:@"Quit Neon" action:@selector(terminate:) keyEquivalent:@"q"];
    [menu addItem:app];
    NSMenuItem* file = [NSMenuItem new];
    file.submenu = [[NSMenu alloc] initWithTitle:@"File"];
    [file.submenu addItemWithTitle:@"New Project…"
                            action:@selector(newProject:)
                     keyEquivalent:@"n"];
    [file.submenu addItemWithTitle:@"History…" action:@selector(showHistory:) keyEquivalent:@"H"];
    [file.submenu addItemWithTitle:@"Save" action:@selector(saveAction:) keyEquivalent:@"s"];
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--ui-testing"]) {
        [file.submenu addItemWithTitle:@"Capture fixture"
                                action:@selector(captureFixture:)
                         keyEquivalent:@"p"];
        [file.submenu addItemWithTitle:@"Resize fixture"
                                action:@selector(resizeFixture:)
                         keyEquivalent:@"r"];
    }
    [menu addItem:file];
    NSMenuItem* edit = [NSMenuItem new];
    edit.submenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    for (NSArray* item in @[
             @[ @"Undo", @"undo:", @"z" ], @[ @"Redo", @"redo:", @"Z" ], @[ @"Cut", @"cut:", @"x" ],
             @[ @"Copy", @"copy:", @"c" ], @[ @"Paste", @"paste:", @"v" ],
             @[ @"Select All", @"selectAll:", @"a" ]
         ])
        [edit.submenu addItemWithTitle:item[0]
                                action:NSSelectorFromString(item[1])
                         keyEquivalent:item[2]];
    [menu addItem:edit];
    NSMenuItem* view = [NSMenuItem new];
    view.submenu = [[NSMenu alloc] initWithTitle:@"View"];
    [view.submenu addItemWithTitle:@"Toggle Focus"
                            action:@selector(toggleFocus:)
                     keyEquivalent:@"F"];
    [menu addItem:view];
    NSApp.mainMenu = menu;
}
- (void)about:(id)sender {
    (void)sender;
    [NSApp orderFrontStandardAboutPanelWithOptions:@{
        NSAboutPanelOptionApplicationName : @"Neon",
        NSAboutPanelOptionApplicationVersion : @"Apple preview 0.4",
        NSAboutPanelOptionCredits :
            [[NSAttributedString alloc] initWithString:@"A quiet place for writing."]
    }];
}
- (NSArray*)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar {
    (void)toolbar;
    return @[
        NSToolbarFlexibleSpaceItemIdentifier, @"sidebar", @"sidebarDivider", @"projectTitle",
        NSToolbarFlexibleSpaceItemIdentifier, @"workspace", @"search", @"type", @"more",
        NSToolbarSpaceItemIdentifier
    ];
}
- (NSArray*)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar {
    return [[self toolbarDefaultItemIdentifiers:toolbar]
        arrayByAddingObjectsFromArray:@[ @"sidebar", @"focus" ]];
}
- (NSToolbarItem*)toolbar:(NSToolbar*)toolbar
        itemForItemIdentifier:(NSString*)identifier
    willBeInsertedIntoToolbar:(BOOL)flag {
    (void)toolbar;
    (void)flag;
    if ([identifier isEqual:@"sidebarDivider"])
        return [NSTrackingSeparatorToolbarItem
            trackingSeparatorToolbarItemWithIdentifier:identifier
                                             splitView:self.split.splitView
                                          dividerIndex:0];
    if ([identifier isEqual:@"workspace"]) {
        self.workspaceItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
        self.workspaceItem.label = @"Version history";
        self.workspaceItem.bordered = NO;
        self.workspaceItem.visibilityPriority = NSToolbarItemVisibilityPriorityHigh;
        [self updateHistoryCommand];
        return self.workspaceItem;
    }
    if ([identifier isEqual:@"projectTitle"]) {
        NSToolbarItem* titleItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
        self.windowTitle = [[NeonInlineTitle alloc] initWithFrame:NSMakeRect(0, 0, 210, 26)];
        self.windowTitle.font = NeonUI(13);
        self.windowTitle.stringValue = @"Neon";
        self.windowTitle.accessibilityLabel = @"Project title";
        __weak NeonApp* weakSelf = self;
        self.windowTitle.commitTitle = ^BOOL(NSString* title) {
          return [weakSelf renameInline:title section:nil];
        };
        titleItem.label = @"Project title";
        titleItem.navigational = NO;
        titleItem.bordered = NO;
        NSButton* library = button(@"Library", nil, self, @selector(showLibrary:));
        library.font = NeonUI(13);
        NSStackView* breadcrumb = [NSStackView stackViewWithViews:@[
            library, label(@"›", NeonUI(13), NeonMuted()), self.windowTitle
        ]];
        breadcrumb.spacing = NeonBreadcrumbGap;
        titleItem.view = breadcrumb;
        self.toolbarTitleWidth = [self.windowTitle.widthAnchor constraintEqualToConstant:150];
        self.toolbarTitleWidth.active = YES;
        return titleItem;
    }
    if ([identifier isEqual:@"focus"]) {
        NSToolbarItem* item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
        NeonButton* exit = [NeonButton new];
        exit.title = @"Exit focus";
        exit.kind = NeonButtonSecondary;
        exit.target = self;
        exit.action = @selector(toggleFocus:);
        item.view = exit;
        item.label = @"Exit focus";
        item.bordered = NO;
        return item;
    }
    if ([identifier isEqual:@"search"]) {
        NSToolbarItem* item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
        NeonButton* search = [NeonPaperCommand new];
        search.title = @"Search";
        search.enabled = NO;
        search.toolTip = @"Search is not available yet";
        [search.widthAnchor constraintEqualToConstant:66].active = YES;
        item.view = search;
        item.label = @"Search";
        return item;
    }
    NSDictionary* config = @{
        @"sidebar" : @[ @"Toggle sidebar", @"sidebar.left", @"toggleSidebar:" ],
        @"library" : @[ @"Library", @"books.vertical", @"showLibrary:" ],
        @"type" : @[ @"Typography", @"textformat", @"showTypography:" ],
        @"new" : @[ @"New Project", @"plus", @"newProject:" ],
        @"more" : @[ @"Project actions", @"ellipsis", @"currentProjectMenu:" ]
    };
    NSArray* item = config[identifier];
    NSToolbarItem* result = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
    result.label = item[0];
    // Navigation items can be reordered outside the declared toolbar sequence.
    // Keep the toggle after flexible space, beside the tracking divider.
    result.navigational = NO;
    result.toolTip = item[0];
    result.target = self;
    result.action = NSSelectorFromString(item[2]);
    result.bordered = NO;
    if ([identifier isEqual:@"type"] || [identifier isEqual:@"more"]) {
        NeonPaperCommand* control = [NeonPaperCommand new];
        control.title = [identifier isEqual:@"type"] ? @"Aa" : @"•••";
        control.target = self;
        control.action = NSSelectorFromString(item[2]);
        control.accessibilityLabel = item[0];
        control.toolTip = item[0];
        [control.widthAnchor constraintEqualToConstant:36].active = YES;
        [control.heightAnchor constraintEqualToConstant:NeonCompactControlHeight].active = YES;
        result.view = control;
        return result;
    }
    result.image = [identifier isEqual:@"sidebar"] ? workspaceIcon(@"sidebar")
                                                   : [NSImage imageWithSystemSymbolName:item[1]
                                                               accessibilityDescription:item[0]];
    return result;
}
- (void)toggleFocus:(id)sender {
    (void)sender;
    if (!self.session || self.historyController)
        return;
    NSSplitViewItem* sidebar = self.split.splitViewItems.firstObject;
    if (!self.focusMode) {
        self.focusSidebarWasCollapsed = sidebar.collapsed;
        if (!sidebar.collapsed)
            [self toggleSidebar:nil];
    } else if (!self.focusSidebarWasCollapsed && sidebar.collapsed) {
        [self toggleSidebar:nil];
    }
    self.focusMode = !self.focusMode;
    if (self.focusMode)
        [self.window.toolbar insertItemWithItemIdentifier:@"focus"
                                                  atIndex:self.window.toolbar.items.count];
    else {
        NSUInteger index = [self.window.toolbar.items
            indexOfObjectPassingTest:^BOOL(NSToolbarItem* item, NSUInteger, BOOL*) {
              return [item.itemIdentifier isEqual:@"focus"];
            }];
        if (index != NSNotFound)
            [self.window.toolbar removeItemAtIndex:index];
    }
    [self.window makeFirstResponder:self.editor];
}
- (void)toggleSidebar:(id)sender {
    (void)sender;
    NSSplitViewItem* sidebar = self.split.splitViewItems.firstObject;
    BOOL collapsed = !sidebar.collapsed;
    // Keep one toolbar toggle: against the sidebar edge when open, before the
    // document title when closed. The native separator tracks divider resizing.
    if (collapsed) {
        NSArray<NSToolbarItem*>* items = self.window.toolbar.items;
        NSUInteger divider = [items
            indexOfObjectPassingTest:^BOOL(NSToolbarItem* item, NSUInteger index, BOOL* stop) {
              (void)index;
              (void)stop;
              return [item.itemIdentifier isEqual:@"sidebarDivider"];
            }];
        if (divider != NSNotFound) {
            [self.window.toolbar removeItemAtIndex:divider];
            // Only the flexible space preceding the toggle belongs to the sidebar.
            for (NSUInteger index = 0; index < self.window.toolbar.items.count; ++index) {
                NSString* identifier = self.window.toolbar.items[index].itemIdentifier;
                if ([identifier isEqual:@"sidebar"])
                    break;
                if ([identifier isEqual:NSToolbarFlexibleSpaceItemIdentifier]) {
                    [self.window.toolbar removeItemAtIndex:index];
                    break;
                }
            }
        }
    } else {
        [self.window.toolbar insertItemWithItemIdentifier:NSToolbarFlexibleSpaceItemIdentifier
                                                  atIndex:0];
        NSUInteger toggle = [self.window.toolbar.items
            indexOfObjectPassingTest:^BOOL(NSToolbarItem* item, NSUInteger index, BOOL* stop) {
              (void)index;
              (void)stop;
              return [item.itemIdentifier isEqual:@"sidebar"];
            }];
        if (toggle != NSNotFound)
            [self.window.toolbar insertItemWithItemIdentifier:@"sidebarDivider" atIndex:toggle + 1];
    }
    if (self.immediateSidebarTransition ||
        NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) {
        sidebar.collapsed = collapsed;
        return;
    }
    [NSAnimationContext
        runAnimationGroup:^(NSAnimationContext* context) {
          context.duration = 0.28;
          context.timingFunction =
              [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
          // Animate the native split layout so the manuscript reflows with the
          // pane while preserving the native editor.
          sidebar.animator.collapsed = collapsed;
        }
        completionHandler:nil];
}
- (void)clear:(NSView*)view {
    for (NSView* child in view.subviews.copy)
        [child removeFromSuperview];
}
- (void)buildSidebar {
    [self clear:self.sidebarBody];
    NSMutableArray* rows = [NSMutableArray array];
    NSMutableArray* actions = [NSMutableArray array];
    if (self.session) {
        __weak NeonApp* weakSelf = self;
        NeonInlineTitle* book = [NeonInlineTitle new];
        book.stringValue = self.session.title;
        book.font = NeonSerif(24);
        book.accessibilityLabel = @"Project title";
        book.commitTitle = ^BOOL(NSString* title) {
          return [weakSelf renameInline:title section:nil];
        };
        self.sidebarSummary = label(@"", NeonUI(13), NeonMuted());
        self.sidebarSummary.stringValue =
            [NSString stringWithFormat:@"%lu %@ · %lu words", self.session.sections.count,
                                       [self.session.preset[@"sectionsLabel"] lowercaseString],
                                       self.session.projectWordCount];
        NSStackView* project = column(
            @[
                book,
                label([self.session.preset[@"documentLabel"] uppercaseString], NeonUI(13),
                      NeonMuted()),
                self.sidebarSummary
            ],
            8);
        project.edgeInsets = NSEdgeInsetsMake(24, 24, 24, 24);
        [book.widthAnchor constraintEqualToAnchor:project.widthAnchor constant:-48].active = YES;
        [book setContentCompressionResistancePriority:200
                                       forOrientation:NSLayoutConstraintOrientationHorizontal];
        [project.heightAnchor constraintGreaterThanOrEqualToConstant:138].active = YES;
        [rows addObject:project];
        NSInteger index = 0;
        for (NSDictionary* section in self.session.sections) {
            NeonInlineTitle* row = [NeonInlineTitle new];
            row.stringValue = section[@"title"];
            row.font = NeonUI(14);
            row.accessibilityLabel =
                [self.session.preset[@"sectionLabel"] stringByAppendingString:@" title"];
            row.accessibilityIdentifier = [NSString stringWithFormat:@"section-%ld", index];
            row.tag = index++;
            NSString* identifier = section[@"id"];
            row.commitTitle = ^BOOL(NSString* title) {
              return [weakSelf renameInline:title section:identifier];
            };
            row.activateTitle = ^{
              [weakSelf showDestination:NeonWorkspaceDestinationManuscript sectionID:identifier];
            };
            row.contextAction = ^(NSView* anchor, NSRect rect) {
              [weakSelf sectionMenu:identifier anchor:anchor rect:rect];
            };
            row.textColor =
                [identifier isEqual:self.session.selectedSectionID] ? NeonAccent() : NeonInk();
            [row.widthAnchor constraintGreaterThanOrEqualToConstant:1].active = YES;
            [row setContentCompressionResistancePriority:200
                                          forOrientation:NSLayoutConstraintOrientationHorizontal];
            row.clipsToBounds = YES;
            [row setContentHuggingPriority:200
                            forOrientation:NSLayoutConstraintOrientationHorizontal];
            [row.heightAnchor constraintEqualToConstant:20].active = YES;
            BOOL selected = [identifier isEqual:self.session.selectedSectionID];
            NeonChapterRow* chapter = [[NeonChapterRow alloc] initWithFrame:NSZeroRect];
            if ([self.session.preset[@"numberedSections"] boolValue]) {
                NSTextField* number = label([NSString stringWithFormat:@"%02ld", index], NeonUI(14),
                                            selected ? NeonAccent() : NeonInk());
                [number.widthAnchor constraintEqualToConstant:20].active = YES;
                [chapter addArrangedSubview:number];
            }
            [chapter addArrangedSubview:row];
            chapter.currentChapter = selected;
            [chapter.heightAnchor constraintEqualToConstant:52].active = YES;
            chapter.spacing = 7;
            chapter.alignment = NSLayoutAttributeCenterY;
            chapter.edgeInsets = NSEdgeInsetsMake(4, 16, 4, 16);
            // A semantic row exposes its full sidebar bounds while retaining both controls.
            chapter.accessibilityElement = YES;
            chapter.accessibilityRole = NSAccessibilityGroupRole;
            chapter.accessibilityIdentifier =
                [NSString stringWithFormat:@"section-row-%ld", row.tag];
            chapter.accessibilityLabel = section[@"title"];
            row.accessibilityElement = YES;
            NSButton* more = button(@"Actions", @"ellipsis", self, @selector(chapterActions:));
            more.imagePosition = NSImageOnly;
            more.tag = row.tag;
            [more.widthAnchor constraintEqualToConstant:NeonMinimumTouchTarget].active = YES;
            [more.heightAnchor constraintEqualToConstant:NeonMinimumTouchTarget].active = YES;
            more.accessibilityLabel = @"Actions";
            more.accessibilityIdentifier =
                [NSString stringWithFormat:@"section-actions-%ld", row.tag];
            more.toolTip = [NSString stringWithFormat:@"Actions for %@", section[@"title"]];
            [chapter addArrangedSubview:more];
            chapter.accessibilityChildren = @[ row, more ];
            row.accessibilityValue =
                selected
                    ? [@"Current " stringByAppendingString:self.session.preset[@"sectionLabel"]]
                    : self.session.preset[@"sectionLabel"];
            [rows addObject:chapter];
        }
        [actions addObject:button([@"+  Add "
                                      stringByAppendingString:[self.session.preset[@"sectionLabel"]
                                                                  lowercaseString]],
                                  @"plus", self, @selector(newSection:))];
        if (self.session.trashedSections.count)
            [actions
                addObject:button([@"Deleted "
                                     stringByAppendingString:self.session.preset[@"sectionsLabel"]],
                                 @"arrow.uturn.backward", self, @selector(sectionTrash:))];
    } else {
        [rows addObject:label(@"ON THIS MAC", NeonUI(11), NeonMuted())];
    }
    if (!self.session)
        [actions addObject:button(@"Library", @"chevron.left", self, @selector(showLibrary:))];
    if (self.session) {
        for (NSUInteger index = 0; index < actions.count; ++index) {
            NSButton* original = actions[index];
            NeonButton* command = [NeonPaperCommand new];
            command.title = original.title;
            command.alignment = NSTextAlignmentLeft;
            command.image = original.image;
            command.imagePosition = original.imagePosition;
            command.target = original.target;
            command.action = original.action;
            actions[index] = command;
        }
    }
    if (!self.session)
        [actions addObject:button(@"Trash", @"trash", self, @selector(showTrash:))];
    NSScrollView* scroll = [NSScrollView new];
    scroll.drawsBackground = NO;
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.scrollerStyle = NSScrollerStyleOverlay;
    NSStackView* footer = column(actions, 8);
    footer.edgeInsets = NSEdgeInsetsMake(self.session ? 14 : 6, 16, self.session ? 14 : 6, 16);
    footer.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.sidebarBody addSubview:scroll];
    [self.sidebarBody addSubview:footer];
    for (NSButton* action in actions) {
        if (![action isKindOfClass:NeonButton.class]) {
            action.bordered = YES;
            action.bezelStyle = NSBezelStyleRounded;
        }
        action.font = NeonUI(14);
        action.contentTintColor = NeonInk();
        [action.heightAnchor constraintEqualToConstant:self.session ? NeonCompactControlHeight
                                                                    : NeonMinimumTouchTarget]
            .active = YES;
        if (self.session)
            [action.widthAnchor
                constraintEqualToConstant:MAX(140, action.intrinsicContentSize.width)]
                .active = YES;
        else
            [action.widthAnchor constraintEqualToAnchor:footer.widthAnchor constant:-32].active =
                YES;
    }
    NSArray<NSView*>* arranged = rows;
    NSLayoutYAxisAnchor* top = self.sidebarBody.topAnchor;
    if (self.session && rows.count >= 2) {
        NSStackView* identity = column([rows subarrayWithRange:NSMakeRange(0, 2)], 0);
        identity.translatesAutoresizingMaskIntoConstraints = NO;
        [self.sidebarBody addSubview:identity];
        [NSLayoutConstraint activateConstraints:@[
            [identity.topAnchor constraintEqualToAnchor:self.sidebarBody.topAnchor],
            [identity.leadingAnchor constraintEqualToAnchor:self.sidebarBody.leadingAnchor],
            [identity.trailingAnchor constraintEqualToAnchor:self.sidebarBody.trailingAnchor]
        ]];
        for (NSView* item in identity.arrangedSubviews)
            [item.widthAnchor constraintEqualToAnchor:identity.widthAnchor].active = YES;
        top = identity.bottomAnchor;
        arranged = [rows subarrayWithRange:NSMakeRange(2, rows.count - 2)];
        [scroll.heightAnchor constraintLessThanOrEqualToConstant:312].active = YES;
        NSLayoutConstraint* preferred =
            [scroll.heightAnchor constraintEqualToConstant:MIN(312, arranged.count * 52)];
        preferred.priority = NSLayoutPriorityDefaultLow;
        preferred.active = YES;
        [scroll setContentCompressionResistancePriority:1
                                         forOrientation:NSLayoutConstraintOrientationVertical];
    }
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:top],
        [scroll.leadingAnchor constraintEqualToAnchor:self.sidebarBody.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.sidebarBody.trailingAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:footer.topAnchor],
        [footer.leadingAnchor constraintEqualToAnchor:self.sidebarBody.leadingAnchor],
        [footer.trailingAnchor constraintEqualToAnchor:self.sidebarBody.trailingAnchor],
        [footer.bottomAnchor constraintLessThanOrEqualToAnchor:self.sidebarBody.bottomAnchor]
    ]];
    NSStackView* stack = column(arranged, 0);
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.documentView = stack;
    [stack.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor].active = YES;
    for (NSUInteger i = 0; i < arranged.count; ++i) {
        NSView* row = arranged[i];
        [row.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
        if ([row isKindOfClass:NeonChapterRow.class] && i + 1 < arranged.count &&
            [arranged[i + 1] isKindOfClass:NeonChapterRow.class])
            [stack setCustomSpacing:0 afterView:row];
    }
}
- (void)transitionContent:(void (^)(void))changes {
    [self.transitionOverlay removeFromSuperview];
    self.transitionOverlay = nil;
    NSView* host = self.content.view;
    if (!self.window.visible || !host.subviews.count ||
        NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) {
        changes();
        return;
    }
    NSBitmapImageRep* bitmap = [host bitmapImageRepForCachingDisplayInRect:host.bounds];
    if (!bitmap) {
        changes();
        return;
    }
    [host cacheDisplayInRect:host.bounds toBitmapImageRep:bitmap];
    NSImage* image = [[NSImage alloc] initWithSize:host.bounds.size];
    [image addRepresentation:bitmap];
    changes();
    [host layoutSubtreeIfNeeded];
    NeonTransitionOverlay* overlay = [[NeonTransitionOverlay alloc] initWithFrame:host.bounds];
    overlay.image = image;
    overlay.imageScaling = NSImageScaleAxesIndependently;
    overlay.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    overlay.accessibilityElement = NO;
    [host addSubview:overlay];
    self.transitionOverlay = overlay;
    [NSAnimationContext
        runAnimationGroup:^(NSAnimationContext* context) {
          context.duration = 0.18;
          context.timingFunction =
              [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
          overlay.animator.alphaValue = 0;
        }
        completionHandler:^{
          [overlay removeFromSuperview];
        }];
}
- (void)showLibrary:(id)sender {
    if (![self flush])
        return;
    [self transitionContent:^{
      [self renderLibrary:sender];
    }];
}
- (void)configureToolbarForLibrary:(BOOL)library {
    NSStackView* breadcrumb = (NSStackView*)self.windowTitle.superview;
    if (breadcrumb.arrangedSubviews.count >= 3) {
        breadcrumb.arrangedSubviews[0].hidden = library;
        breadcrumb.arrangedSubviews[1].hidden = library;
    }
    NSToolbar* toolbar = self.window.toolbar;
    if (library) {
        for (NSInteger index = (NSInteger)toolbar.items.count - 1; index >= 0; --index)
            if ([@[ @"workspace", @"type", @"focus" ]
                    containsObject:toolbar.items[index].itemIdentifier])
                [toolbar removeItemAtIndex:index];
    } else {
        for (NSString* name in @[ @"workspace", @"type" ]) {
            BOOL found = NO;
            for (NSToolbarItem* item in toolbar.items)
                found = found || [item.itemIdentifier isEqual:name];
            if (!found) {
                NSString* before = [name isEqual:@"workspace"] ? @"search" : @"more";
                NSUInteger index = [toolbar.items
                    indexOfObjectPassingTest:^BOOL(NSToolbarItem* item, NSUInteger, BOOL*) {
                      return [item.itemIdentifier isEqual:before];
                    }];
                [toolbar
                    insertItemWithItemIdentifier:name
                                         atIndex:index == NSNotFound ? toolbar.items.count : index];
            }
        }
    }
}
- (void)setChromeHeight:(CGFloat)height {
    NSRect frame = self.chromeSpacer.view.frame;
    frame.size.height = height - 52;
    self.chromeSpacer.view.frame = frame;
    self.chromeSpacer.view.needsDisplay = YES;
}
- (void)resizeFixture:(id)sender {
    (void)sender;
    NSRect frame = self.window.frame;
    frame.size = frame.size.width > 800 ? NSMakeSize(760, 560) : NSMakeSize(1200, 860);
    [self.window setFrame:frame display:YES];
}
- (void)captureFixture:(id)sender {
    (void)sender;
    NSString* file = NSProcessInfo.processInfo.environment[@"NEON_CAPTURE_FILE"];
    if (file.length)
        [self capture:file];
}
- (void)reloadLibraryRecords {
    NSError* error = nil;
    self.trashMode = self.libraryController.query.filter == NeonLibraryTrash;
    self.projects =
        self.trashMode ? [self.library trashedProjects:&error] : [self.library projects:&error];
    [self.libraryController updateWithRecords:self.projects error:error];
}
- (void)openProjectRecord:(NSDictionary*)record {
    if (![self flush] || [record[@"trashed"] boolValue])
        return;
    NSError* error = nil;
    NSURL* url = record[@"url"];
    NeonDocumentSession* session = [self.library openProjectURL:url error:&error];
    if (!session) {
        [self showError:error];
        return;
    }
    self.libraryController.selectedProjectID = record[@"projectID"];
    self.session = session;
    self.selectedURL = url;
    self.trashMode = NO;
    [self showEditor];
}
- (void)libraryAction:(NSString*)action record:(NSDictionary*)record {
    if ([action isEqual:@"open"]) {
        [self openProjectRecord:record];
        return;
    }
    if ([action isEqual:@"new"]) {
        [self newProject:nil];
        return;
    }
    if ([action isEqual:@"settings"]) {
        [self showSettings:nil];
        return;
    }
    if ([action isEqual:@"favorite"]) {
        [self.library setFavorite:![record[@"favorite"] boolValue] projectID:record[@"projectID"]];
        [self reloadLibraryRecords];
        return;
    }
    if ([action isEqual:@"reveal"]) {
        NSURL* url = record[@"url"];
        if (url)
            [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[ url ]];
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
    if (command && record) {
        self.trashMode = [record[@"trashed"] boolValue];
        [self projectCommand:command url:record[@"url"] title:record[@"title"]];
    }
}
- (void)renderLibrary:(id)sender {
    (void)sender;
    [self.historyController removeFromParentViewController];
    self.historyController = nil;
    if (self.focusMode) {
        self.immediateSidebarTransition = YES;
        [self toggleFocus:nil];
        self.immediateSidebarTransition = NO;
    }
    [self.workspaceController removeFromParentViewController];
    self.workspaceController = nil;
    self.editor = nil;
    self.session = nil;
    self.status = nil;
    self.selectedURL = nil;
    self.chapterTitle = nil;
    self.guidance = nil;
    [self setChromeHeight:64];
    [self configureToolbarForLibrary:YES];
    self.window.title = @"Neon";
    self.window.subtitle = @"";
    self.windowTitle.stringValue = @"Neon";
    self.windowTitle.enabled = NO;
    [self updateHistoryCommand];
    if (!self.libraryController) {
        self.libraryController = [NeonLibraryController new];
        NSInteger filter = [NeonPreferences() integerForKey:@"library.filter"];
        self.libraryController.query.filter = filter >= NeonLibraryAll && filter <= NeonLibraryTrash
                                                  ? (NeonLibraryFilter)filter
                                                  : NeonLibraryAll;
        __weak NeonApp* weakSelf = self;
        self.libraryController.onAction = ^(NSString* action, NSDictionary* record) {
          [weakSelf libraryAction:action record:record];
        };
        self.libraryController.onFilterChanged = ^(NeonLibraryFilter value) {
          [NeonPreferences() setInteger:value forKey:@"library.filter"];
          [weakSelf reloadLibraryRecords];
        };
    }
    self.libraryController.fixtureIDs = NeonUITestFixtureIDs();
    [self clear:self.sidebarBody];
    [self clear:self.content.view];
    if (!self.libraryController.parentViewController)
        [self.content addChildViewController:self.libraryController];
    pin(self.libraryController.view, self.content.view);
    pin(self.libraryController.sidebarView, self.sidebarBody);
    [self.split.splitView setPosition:248 ofDividerAtIndex:0];
    [self reloadLibraryRecords];
}
- (void)openProject:(NSControl*)sender {
    if (self.trashMode) {
        [self projectActions:sender];
        return;
    }
    if (![self flush] || sender.tag < 0 ||
        sender.tag >= static_cast<NSInteger>(self.projects.count))
        return;
    NSError* error = nil;
    NSURL* url = self.projects[sender.tag][@"url"];
    NeonDocumentSession* session = [self.library openProjectURL:url error:&error];
    if (!session) {
        [self showError:error];
        return;
    }
    self.session = session;
    self.selectedURL = url;
    [self showEditor];
}
- (void)selectSection:(NSControl*)sender {
    if (![self flush] || sender.tag < 0 ||
        sender.tag >= static_cast<NSInteger>(self.session.sections.count))
        return;
    NSError* error = nil;
    if (![self.session selectSection:self.session.sections[sender.tag][@"id"] error:&error]) {
        [self showError:error];
        return;
    }
    [self showEditor];
}
- (void)showDestination:(NeonWorkspaceDestination)destination sectionID:(NSString*)sectionID {
    if (!self.session)
        return;
    if (destination == NeonWorkspaceDestinationHistory) {
        [self showHistory:nil];
        return;
    }
    if (destination != NeonWorkspaceDestinationManuscript)
        return;
    if (sectionID && ![sectionID isEqual:self.session.selectedSectionID]) {
        if (![self flush])
            return;
        NSError* error = nil;
        if (![self.session selectSection:sectionID error:&error]) {
            [self showError:error];
            return;
        }
    }
    [self showEditor];
}
- (void)showEditor {
    [self transitionContent:^{
      [self renderEditor];
    }];
}
- (void)renderEditor {
    [self setChromeHeight:68];
    [self configureToolbarForLibrary:NO];
    if (self.libraryController.parentViewController) {
        [self.libraryController removeFromParentViewController];
        [self.split.splitView setPosition:264 ofDividerAtIndex:0];
    }
    [self.historyController removeFromParentViewController];
    self.historyController = nil;
    [self updateHistoryCommand];
    self.editor = nil;
    [self clear:self.content.view];
    self.window.title = self.session.title;
    self.window.subtitle = @"";
    self.windowTitle.stringValue = self.session.title;
    self.windowTitle.enabled = YES;
    self.chapterTitle = nil;
    self.guidance = nil;
    [self buildSidebar];
    if (!self.session.sections.count) {
        NSStackView* empty = column(
            @[
                label(@"A fresh page", NeonSerif(38), NeonInk()),
                label([NSString
                          stringWithFormat:@"Create a %@, or restore one from Trash.",
                                           [self.session.preset[@"sectionLabel"] lowercaseString]],
                      NeonUI(16), NeonMuted()),
                button([@"New " stringByAppendingString:self.session.preset[@"sectionLabel"]],
                       @"plus", self, @selector(newSection:))
            ],
            24);
        empty.edgeInsets = NSEdgeInsetsMake(80, 48, 80, 48);
        pin(empty, self.content.view);
        return;
    }
    NSUInteger number =
        [self.session.sections
            indexOfObjectPassingTest:^BOOL(NSDictionary* item, NSUInteger i, BOOL* stop) {
              (void)i;
              (void)stop;
              return [item[@"id"] isEqual:self.session.selectedSectionID];
            }] +
        1;
    BOOL bookPreset = [self.session.preset[@"id"] isEqual:@"book"];
    BOOL resume = self.historySession == self.session &&
                  [self.historySection isEqual:self.session.selectedSectionID] &&
                  [self.historyEditor.string isEqual:self.session.text];
    self.editor = resume ? self.historyEditor
                         : [[NeonTextView alloc] initWithFrame:NSMakeRect(0, 0, 650, 400)];
    self.historyEditor = nil;
    self.historySession = nil;
    self.editor.accessibilityIdentifier = @"manuscript";
    self.editor.minSize = NSMakeSize(0, 300);
    self.editor.maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
    self.editor.verticallyResizable = YES;
    self.editor.horizontallyResizable = NO;
    self.editor.autoresizingMask = NSViewWidthSizable;
    self.editor.textContainer.widthTracksTextView = YES;
    self.editor.textContainerInset = NSMakeSize(0, 0);
    self.editor.textContainer.lineFragmentPadding = 0;
    self.editor.richText = NO;
    self.editor.allowsUndo = YES;
    if (!resume)
        self.editor.string = self.session.text;
    self.editor.delegate = self;
    if ([self.editor isKindOfClass:NeonTextView.class]) {
        __weak NeonApp* app = self;
        __weak NSTextView* current = self.editor;
        ((NeonTextView*)self.editor).compositionDidEnd = ^{
          if (app.editor == current && app.pendingTypography)
              [app styleEditor];
        };
    }
    self.editor.backgroundColor = NeonPaper();
    self.editor.textColor = NeonInk();
    [self styleEditor];
    [self.workspaceController removeFromParentViewController];
    self.workspaceController = [[NeonWorkspaceController alloc] initWithEditor:self.editor];
    [self.content addChildViewController:self.workspaceController];
    pin(self.workspaceController.view, self.content.view);
    self.workspaceController.textMeasure = NeonTextMeasure();
    self.workspaceController.bodyBaselineAdjustment =
        [self.session.preset[@"id"] isEqual:@"book"] ? 4 : 0;
    NeonChapterHeading* heading = self.workspaceController.heading;
    heading.stringValue = self.session.sectionTitle;
    heading.accessibilityLabel =
        [self.session.preset[@"sectionLabel"] stringByAppendingString:@" title"];
    self.chapterTitle = heading;
    __weak NeonApp* weakSelf = self;
    NSString* identifier = self.session.selectedSectionID;
    heading.commitTitle = ^BOOL(NSString* title) {
      return [weakSelf renameInline:title section:identifier];
    };
    heading.alignment = !bookPreset && [self.session.preset[@"centeredHeading"] boolValue]
                            ? NSTextAlignmentCenter
                            : NSTextAlignmentLeft;
    self.workspaceController.kicker.alignment = heading.alignment;
    self.workspaceController.kicker.stringValue =
        [[self.session sectionLabelAtIndex:number - 1] uppercaseString];
    if (bookPreset) {
        NSNumberFormatter* ordinal = [NSNumberFormatter new];
        ordinal.numberStyle = NSNumberFormatterSpellOutStyle;
        ordinal.locale = [NSLocale localeWithLocaleIdentifier:@"en_US"];
        self.workspaceController.kicker.stringValue =
            [[NSString stringWithFormat:@"%@ %@", self.session.preset[@"sectionLabel"],
                                        [ordinal stringFromNumber:@(number)]] uppercaseString];
    }
    self.guidance = self.workspaceController.guidance;
    self.guidance.stringValue = self.session.sectionGuidance ?: @"";
    self.guidance.hidden = self.session.text.length > 0 || !self.session.sectionGuidance.length;
    self.status = self.workspaceController.status;
    NSScrollView* scroll = self.workspaceController.scrollView;
    [self.workspaceController refreshLayout];
    [self.window makeFirstResponder:self.editor];
    [self updateStatus:YES];
    if (resume) {
        [self.content.view layoutSubtreeIfNeeded];
        [scroll.contentView scrollToPoint:self.historyScroll];
        [scroll reflectScrolledClipView:scroll.contentView];
    }
}
- (BOOL)renameInline:(NSString*)title section:(NSString*)identifier {
    if (!self.session || ![self flush])
        return NO;
    NSError* error = nil;
    BOOL changed = identifier ? [self.session renameSection:identifier title:title error:&error]
                              : [self.session renameProject:title error:&error];
    if (!changed || ![self.session save:&error]) {
        [self showError:error];
        return NO;
    }
    self.window.title = self.session.title;
    // Defer label refresh until the field editor has finished committing.
    dispatch_async(dispatch_get_main_queue(), ^{
      self.windowTitle.stringValue = self.session ? self.session.title : @"Neon";
      self.chapterTitle.stringValue = self.session.sectionTitle ?: @"";
      [self buildSidebar];
    });
    return YES;
}
- (void)styleEditor {
    if (!self.editor)
        return;
    if (self.editor.hasMarkedText) {
        self.pendingTypography = YES;
        return;
    }
    self.pendingTypography = NO;
    NSRange selection = self.editor.selectedRange;
    self.editor.font = ([NeonPreferences() objectForKey:@"manuscriptFont"]
                            ? NeonManuscriptFont(NeonTextSize())
                            : NeonFontNamed(self.session.preset[@"font"], NeonTextSize()));
    NSMutableParagraphStyle* paragraph = [NSMutableParagraphStyle new];
    paragraph.lineSpacing = NeonLineSpacing();
    paragraph.paragraphSpacing = [NeonPreferences() objectForKey:@"paragraphSpacing"]
                                     ? NeonParagraphSpacing()
                                     : [self.session.preset[@"paragraphSpacing"] doubleValue];
    paragraph.lineHeightMultiple = [self.session.preset[@"lineHeightMultiple"] doubleValue];
    if ([self.session.preset[@"id"] isEqual:@"book"] &&
        ![NeonPreferences() objectForKey:@"manuscriptSpacing"]) {
        paragraph.lineSpacing = 0;
        paragraph.lineHeightMultiple = 0;
        paragraph.minimumLineHeight = NeonTextSize() * 34.0 / 20.0;
        paragraph.maximumLineHeight = paragraph.minimumLineHeight;
    }
    paragraph.firstLineHeadIndent = [self.session.preset[@"firstLineIndent"] doubleValue];
    if ([self.session.preset[@"id"] isEqual:@"book"]) {
        paragraph.firstLineHeadIndent = 0;
        if (![NeonPreferences() objectForKey:@"paragraphSpacing"])
            // Figma's paragraph boxes include 2pt beyond their 34pt line grid.
            // Compensate in AppKit presentation without changing stored preferences.
            paragraph.paragraphSpacing = 26;
    }
    if ([self.session.sections count]) {
        for (NSDictionary* section in self.session.sections)
            if ([section[@"id"] isEqual:self.session.selectedSectionID] &&
                [section[@"role"] isEqual:@"references"]) {
                paragraph.firstLineHeadIndent = 0;
                paragraph.headIndent = 24;
            }
    }
    self.measureConstraint.constant = NeonTextMeasure();
    self.workspaceController.textMeasure = NeonTextMeasure();
    self.workspaceController.bodyBaselineAdjustment =
        [self.session.preset[@"id"] isEqual:@"book"] ? 4 : 0;
    self.editor.continuousSpellCheckingEnabled = NeonWritingPreference(@"spellcheck");
    self.editor.automaticQuoteSubstitutionEnabled = NeonWritingPreference(@"smartQuotes");
    self.editor.automaticDashSubstitutionEnabled = NeonWritingPreference(@"smartDashes");
    self.editor.defaultParagraphStyle = paragraph;
    [self.editor.textStorage addAttributes:@{
        NSFontAttributeName : ([NeonPreferences() objectForKey:@"manuscriptFont"]
                                   ? NeonManuscriptFont(NeonTextSize())
                                   : NeonFontNamed(self.session.preset[@"font"], NeonTextSize())),
        NSParagraphStyleAttributeName : paragraph,
        NSForegroundColorAttributeName : NeonInk()
    }
                                     range:NSMakeRange(0, self.editor.string.length)];
    self.editor.typingAttributes = @{
        NSFontAttributeName : ([NeonPreferences() objectForKey:@"manuscriptFont"]
                                   ? NeonManuscriptFont(NeonTextSize())
                                   : NeonFontNamed(self.session.preset[@"font"], NeonTextSize())),
        NSParagraphStyleAttributeName : paragraph,
        NSForegroundColorAttributeName : NeonInk()
    };
    self.editor.selectedRange = selection;
    [self.workspaceController refreshLayout];
}
- (void)updateStatus:(BOOL)saved {
    self.sidebarSummary.stringValue =
        [NSString stringWithFormat:@"%lu %@ · %lu words", self.session.sections.count,
                                   [self.session.preset[@"sectionsLabel"] lowercaseString],
                                   self.session.projectWordCount];
    NSString* state = saved ? @"Saved on this Mac" : @"Unsaved changes";
    self.status.stringValue =
        NeonWritingPreference(@"showWordCount")
            ? [NSString stringWithFormat:@"%lu words  ·  %@", words(self.editor.string), state]
            : state;
}
- (void)textDidChange:(NSNotification*)notification {
    (void)notification;
    if (self.editor.hasMarkedText)
        return;
    if (self.pendingTypography)
        [self styleEditor];
    NSError* error = nil;
    if (![self.session replaceText:self.editor.string error:&error]) {
        [self showError:error];
        return;
    }
    self.guidance.hidden = self.editor.string.length > 0 || !self.session.sectionGuidance.length;
    [self.workspaceController refreshLayout];
    [self updateStatus:NO];
    [self.timer invalidate];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.6
                                                  target:self
                                                selector:@selector(saveAction:)
                                                userInfo:nil
                                                 repeats:NO];
}
- (void)textDidEndEditing:(NSNotification*)notification {
    (void)notification;
    if (self.pendingTypography && !self.editor.hasMarkedText)
        [self styleEditor];
}
- (BOOL)flush {
    [self.timer invalidate];
    if (!self.session)
        return YES;
    if (self.editor.hasMarkedText)
        [self.editor unmarkText];
    NSError* error = nil;
    if ((self.editor && ![self.session replaceText:self.editor.string error:&error]) ||
        ![self.session save:&error]) {
        [self showError:error];
        return NO;
    }
    if (self.editor)
        [self updateStatus:YES];
    return YES;
}
- (void)saveAction:(id)sender {
    (void)sender;
    [self flush];
}
- (NSString*)askTitle:(NSString*)message {
    NSAlert* alert = [NSAlert new];
    alert.messageText = message;
    NSTextField* field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 320, 28)];
    field.placeholderString = @"Working title";
    alert.accessoryView = field;
    [alert addButtonWithTitle:@"Create"];
    [alert addButtonWithTitle:@"Cancel"];
    return [alert runModal] == NSAlertFirstButtonReturn ? field.stringValue : nil;
}
- (void)newProject:(id)sender {
    (void)sender;
    if (![self flush])
        return;
    NSAlert* alert = [NSAlert new];
    alert.messageText = @"Start a new project";
    NSTextField* titleField = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 380, 28)];
    titleField.placeholderString = @"Working title";
    NSPopUpButton* presets = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 0, 380, 28)
                                                        pullsDown:NO];
    for (NSDictionary* preset in NeonDocumentSession.writingPresets)
        [presets addItemWithTitle:preset[@"title"]];
    presets.target = self;
    presets.action = @selector(presetChanged:);
    self.presetDescription = [NSTextField wrappingLabelWithString:@""];
    self.presetDescription.font = NeonUI(12);
    self.presetDescription.textColor = NeonMuted();
    NSStackView* fields = column(@[ titleField, presets, self.presetDescription ], 12);
    fields.frame = NSMakeRect(0, 0, 380, 190);
    [self.presetDescription.widthAnchor constraintEqualToConstant:380].active = YES;
    [titleField.widthAnchor constraintEqualToConstant:380].active = YES;
    [presets.widthAnchor constraintEqualToConstant:380].active = YES;
    alert.accessoryView = fields;
    [self presetChanged:presets];
    [alert addButtonWithTitle:@"Create"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] != NSAlertFirstButtonReturn)
        return;
    NSError* error = nil;
    NSURL* url = [self.library
        createProject:titleField.stringValue
               preset:NeonDocumentSession.writingPresets[presets.indexOfSelectedItem][@"id"]
                error:&error];
    if (!url) {
        [self showError:error];
        return;
    }
    NeonDocumentSession* session = [self.library openProjectURL:url error:&error];
    if (!session) {
        [self showError:error];
        return;
    }
    self.trashMode = NO;
    self.session = session;
    self.selectedURL = url;
    [self showEditor];
}
- (void)presetChanged:(NSPopUpButton*)sender {
    NSDictionary* preset = NeonDocumentSession.writingPresets[sender.indexOfSelectedItem];
    NSArray* titles = [preset[@"sections"] valueForKey:@"title"];
    self.presetDescription.stringValue =
        [NSString stringWithFormat:@"%@\n\n%@", preset[@"description"],
                                   [titles componentsJoinedByString:@" · "]];
}
- (void)updateHistoryCommand {
    BOOL history = self.historyController != nil;
    NSString* title = history ? @"Back to editor" : @"Version history";
    NSButton* control =
        button(history ? title : @"", history ? @"chevron.left" : @"clock.arrow.circlepath", self,
               @selector(workspaceChanged:));
    if (!history)
        control.image = workspaceIcon(@"history");
    control.accessibilityLabel = title;
    control.toolTip = title;
    control.enabled = self.session != nil;
    [control.heightAnchor constraintEqualToConstant:NeonMinimumTouchTarget].active = YES;
    [control.widthAnchor constraintGreaterThanOrEqualToConstant:NeonMinimumTouchTarget].active =
        YES;
    self.workspaceItem.view = control;
    self.workspaceItem.label = title;
}
- (void)workspaceChanged:(id)sender {
    (void)sender;
    if (self.historyController)
        [self showEditor];
    else
        [self showDestination:NeonWorkspaceDestinationHistory sectionID:nil];
}
- (void)showHistory:(id)sender {
    (void)sender;
    if (!self.session || ![self flush])
        return;
    NeonDismissMenu();
    [self.typography close];
    if (self.historyController)
        return;
    self.historyEditor = self.editor;
    self.historySection = self.session.selectedSectionID;
    self.historySession = self.session;
    self.historyScroll = self.editor.enclosingScrollView.contentView.bounds.origin;
    [self transitionContent:^{
      self.editor = nil;
      self.chapterTitle = nil;
      self.guidance = nil;
      [self clear:self.content.view];
      NeonHistoryController* controller = [NeonHistoryController new];
      controller.session = self.session;
      __weak NeonApp* weakSelf = self;
      controller.showEditor = ^{
        [weakSelf showEditor];
      };
      controller.didRestore = ^{
        weakSelf.historyEditor = nil;
        weakSelf.historySession = nil;
        [weakSelf buildSidebar];
      };
      self.historyController = controller;
      [self updateHistoryCommand];
      [self.content addChildViewController:controller];
      pin(controller.view, self.content.view);
    }];
}
- (void)newSection:(id)sender {
    (void)sender;
    if (![self flush])
        return;
    NSString* title =
        [self askTitle:[@"New " stringByAppendingString:self.session.preset[@"sectionLabel"]]];
    if (!title)
        return;
    NSError* error = nil;
    if (![self.session addSection:title error:&error]) {
        [self showError:error];
        return;
    }
    // The selected section changed. Display its draft before any fallible save.
    [self showEditor];
    [self flush];
}
- (void)showTypography:(id)sender {
    if (self.typography.shown) {
        [self.typography close];
        return;
    }
    NeonDismissMenu();
    self.typography = [NSPopover new];
    self.typography.behavior = NSPopoverBehaviorTransient;
    self.typography.appearance = self.window.effectiveAppearance;
    NSViewController* controller = [NSViewController new];
    NeonSurface* surface = [[NeonSurface alloc] initWithFrame:NSMakeRect(0, 0, 320, 470)];
    surface.panel = YES;
    controller.view = surface;
    self.typography.contentViewController = controller;
    NSMutableArray* controls =
        [NSMutableArray arrayWithObjects:label(@"Typography", NeonUI(23), NeonInk()),
                                         label(@"Font", NeonUI(13), NeonMuted()), nil];
    for (NSString* name in @[ @"Literata", @"Source Sans 3", @"System Serif" ]) {
        NSButton* choice =
            button([NSString stringWithFormat:@"%@   %@", name,
                                              [NeonFontChoice() isEqual:name] ? @"✓" : @""],
                   nil, self, @selector(changeFont:));
        choice.identifier = name;
        choice.font = NeonFontNamed(name, 18);
        choice.font = NeonSerif(19);
        choice.contentTintColor = NeonInk();
        [controls addObject:choice];
    }
    NSSlider* size = [NeonSlider sliderWithValue:NeonTextSize()
                                        minValue:16
                                        maxValue:32
                                          target:self
                                          action:@selector(changeSize:)];
    size.accessibilityLabel = @"Text size";
    NSSlider* space = [NeonSlider sliderWithValue:NeonLineSpacing()
                                         minValue:2
                                         maxValue:16
                                           target:self
                                           action:@selector(changeSpacing:)];
    space.accessibilityLabel = @"Line spacing";
    NSSegmentedControl* appearance =
        [NSSegmentedControl segmentedControlWithLabels:@[ @"System", @"Light", @"Dark" ]
                                          trackingMode:NSSegmentSwitchTrackingSelectOne
                                                target:self
                                                action:@selector(changeAppearance:)];
    appearance.selectedSegment = NeonAppearance();
    appearance.selectedSegmentBezelColor = NeonAccent();
    [controls addObjectsFromArray:@[
        label(@"Text Size", NeonUI(13), NeonMuted()), size,
        label(@"Line Spacing", NeonUI(13), NeonMuted()), space,
        label(@"Appearance", NeonUI(13), NeonMuted()), appearance,
        button(@"More Options…", @"chevron.right", self, @selector(showSettings:))
    ]];
    NSStackView* stack = column(controls, 12);
    stack.edgeInsets = NSEdgeInsetsMake(20, 20, 20, 20);
    pin(stack, surface);
    if ([sender isKindOfClass:NSToolbarItem.class]) {
        [self.typography showRelativeToToolbarItem:sender];
        return;
    }
    NSView* anchor = [sender isKindOfClass:NSView.class] ? sender : self.content.view;
    [self.typography showRelativeToRect:[sender isKindOfClass:NSView.class]
                                            ? anchor.bounds
                                            : NSMakeRect(anchor.bounds.size.width - 50,
                                                         anchor.bounds.size.height - 10, 1, 1)
                                 ofView:anchor
                          preferredEdge:NSRectEdgeMinY];
}
- (void)changeFont:(NSButton*)sender {
    [NeonPreferences() setObject:sender.identifier forKey:@"manuscriptFont"];
    [self styleEditor];
    NSStackView* stack = (id)sender.superview;
    for (NSView* view in stack.arrangedSubviews)
        if ([view isKindOfClass:NSButton.class] && view.identifier)
            ((NSButton*)view).title =
                [NSString stringWithFormat:@"%@   %@", view.identifier,
                                           [view.identifier isEqual:NeonFontChoice()] ? @"✓" : @""];
}
- (void)showSettings:(id)sender {
    (void)sender;
    [self.typography close];
    if (!self.settings) {
        self.settings = [[NSPanel alloc]
            initWithContentRect:NSMakeRect(0, 0, 580, 660)
                      styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                NSWindowStyleMaskResizable
                        backing:NSBackingStoreBuffered
                          defer:NO];
        self.settings.title = @"Settings";
        self.settings.minSize = NSMakeSize(580, 420);
        self.settings.releasedWhenClosed = NO;
        NeonSettingsController* controller = [NeonSettingsController new];
        __weak NeonApp* weakSelf = self;
        controller.preferencesChanged = ^{
          [weakSelf applyAppearance];
          [weakSelf styleEditor];
          if (weakSelf.editor)
              [weakSelf updateStatus:!weakSelf.session.dirty];
        };
        self.settings.contentViewController = controller;
        [self.settings center];
    }
    self.settings.appearance = self.window.appearance;
    self.settings.backgroundColor = NeonPanel();
    [self.settings makeKeyAndOrderFront:nil];
}
- (void)changeSize:(NSSlider*)sender {
    [NeonPreferences() setDouble:sender.doubleValue forKey:@"manuscriptSize"];
    [self styleEditor];
}
- (void)changeSpacing:(NSSlider*)sender {
    [NeonPreferences() setDouble:sender.doubleValue forKey:@"manuscriptSpacing"];
    [self styleEditor];
}
- (void)changeAppearance:(NSSegmentedControl*)sender {
    [NeonPreferences() setInteger:sender.selectedSegment forKey:@"appearance"];
    [self applyAppearance];
    self.typography.appearance = self.window.appearance;
}
- (void)closeTypography:(id)sender {
    (void)sender;
    [self.typography close];
    self.typography = nil;
}
- (NSString*)renameTitle:(NSString*)title {
    NSAlert* alert = [NSAlert new];
    alert.messageText = @"Rename";
    NSTextField* field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 320, 28)];
    field.stringValue = title;
    alert.accessoryView = field;
    [alert addButtonWithTitle:@"Rename"];
    [alert addButtonWithTitle:@"Cancel"];
    return [alert runModal] == NSAlertFirstButtonReturn ? field.stringValue : nil;
}
- (void)showTrash:(id)sender {
    (void)sender;
    if (!self.libraryController)
        [self renderLibrary:nil];
    self.libraryController.query.filter = NeonLibraryTrash;
    [NeonPreferences() setInteger:NeonLibraryTrash forKey:@"library.filter"];
    [self showLibrary:self];
}
- (void)projectActions:(NSControl*)sender {
    if (sender.tag < 0 || sender.tag >= static_cast<NSInteger>(self.projects.count))
        return;
    NSDictionary* project = self.projects[sender.tag];
    [self projectMenu:project[@"url"] title:project[@"title"] anchor:sender rect:sender.bounds];
}
- (void)currentProjectMenu:(id)sender {
    [self.typography close];
    NSRect rect = [sender isKindOfClass:NSView.class] ? ((NSView*)sender).bounds : NSZeroRect;
    if (self.session)
        [self projectMenu:self.selectedURL title:self.session.title anchor:sender rect:rect];
    else if (self.libraryController) {
        NSMenu* menu = [self.libraryController navigationMenu];
        [menu
            popUpMenuPositioningItem:nil
                          atLocation:NSMakePoint(MAX(24, self.content.view.bounds.size.width - 24),
                                                 MAX(24, self.content.view.bounds.size.height - 24))
                              inView:self.content.view];
    } else
        NeonShowMenu(sender, rect, @[
            NeonAction(@"New Project…", @"plus", YES, NO,
                       ^{
                         [self newProject:nil];
                       }),
            NeonAction(@"Trash", @"trash", YES, NO,
                       ^{
                         [self showTrash:nil];
                       })
        ]);
}
- (void)projectMenu:(NSURL*)url title:(NSString*)title anchor:(id)anchor rect:(NSRect)rect {
    NSMutableArray* items = [NSMutableArray array];
    if (self.session && [url isEqual:self.selectedURL] && !self.trashMode)
        [items addObject:NeonAction(self.focusMode ? @"Exit focus" : @"Enter focus", @"viewfinder",
                                    YES, NO, ^{
                                      [self toggleFocus:nil];
                                    })];
    NSArray* commands = self.trashMode ? @[ @"Restore", @"Delete Permanently…" ]
                                       : @[ @"Rename…", @"Duplicate", @"Move to Trash…" ];
    for (NSString* command in commands)
        [items addObject:NeonAction(
                             command,
                             [command containsString:@"Trash"] || [command hasPrefix:@"Delete"]
                                 ? @"trash"
                             : [command isEqual:@"Duplicate"] ? @"doc.on.doc"
                                                              : @"pencil",
                             YES,
                             [command containsString:@"Trash"] || [command hasPrefix:@"Delete"], ^{
                               [self projectCommand:command url:url title:title];
                             })];
    NeonShowMenu(anchor, rect, items);
}
- (void)projectCommand:(NSString*)command url:(NSURL*)url title:(NSString*)title {
    if (![self flush])
        return;
    NSError* error = nil;
    BOOL success = NO;
    if ([command hasPrefix:@"Rename"]) {
        NSString* value = [self renameTitle:title];
        if (!value)
            return;
        NeonDocumentSession* session =
            [url isEqual:self.selectedURL] ? self.session : [self.library openURL:url error:&error];
        success = session && [session renameProject:value error:&error] && [session save:&error];
        if (success && self.session == session) {
            [self showEditor];
            return;
        }
    } else if ([command isEqual:@"Duplicate"])
        success = [self.library duplicateProject:url error:&error] != nil;
    else {
        BOOL restore = [command isEqual:@"Restore"];
        if (!restore) {
            NSAlert* alert = [NSAlert new];
            alert.messageText = [NSString stringWithFormat:@"%@ %@", command, title];
            alert.informativeText =
                [command hasPrefix:@"Delete"]
                    ? @"This permanently deletes the project file. This cannot be undone."
                    : @"You can restore this project from Trash.";
            [alert addButtonWithTitle:[command hasPrefix:@"Delete"] ? @"Delete Permanently"
                                                                    : @"Move to Trash"];
            [alert addButtonWithTitle:@"Cancel"];
            if ([alert runModal] != NSAlertFirstButtonReturn)
                return;
        }
        success = [command hasPrefix:@"Delete"]
                      ? [self.library deleteTrashedProject:url error:&error]
                      : [self.library setProject:url trashed:!restore error:&error];
        if (success && [url isEqual:self.selectedURL]) {
            self.editor = nil;
            self.session = nil;
            self.selectedURL = nil;
        }
    }
    if (!success) {
        [self showError:error];
        return;
    }
    [self showLibrary:self];
}
- (void)chapterActions:(NSControl*)sender {
    if (sender.tag >= 0 && sender.tag < static_cast<NSInteger>(self.session.sections.count))
        [self sectionMenu:self.session.sections[sender.tag][@"id"]
                   anchor:sender
                     rect:sender.bounds];
}
- (void)sectionMenu:(NSString*)identifier anchor:(NSView*)anchor rect:(NSRect)rect {
    NSUInteger index = [self.session.sections
        indexOfObjectPassingTest:^BOOL(NSDictionary* item, NSUInteger i, BOOL* stop) {
          (void)i;
          (void)stop;
          return [item[@"id"] isEqual:identifier];
        }];
    NSMutableArray* actions = [NSMutableArray array];
    for (NSString* command in
         @[ @"Rename…", @"Duplicate", @"Move Up", @"Move Down", @"Move to Trash…" ]) {
        BOOL enabled =
            !([command isEqual:@"Move Up"] && index == 0) &&
            !([command isEqual:@"Move Down"] && index + 1 == self.session.sections.count);
        [actions addObject:NeonAction(command,
                                      [command containsString:@"Trash"] ? @"trash"
                                      : [command hasPrefix:@"Move"]     ? @"arrow.up.arrow.down"
                                                                        : @"pencil",
                                      enabled, [command containsString:@"Trash"], ^{
                                        [self sectionCommand:command identifier:identifier];
                                      })];
    }
    NeonShowMenu(anchor, rect, actions);
}
- (void)sectionTrash:(NSView*)sender {
    NSMutableArray* actions = [NSMutableArray array];
    for (NSDictionary* item in self.session.trashedSections)
        [actions addObject:NeonAction([@"Restore " stringByAppendingString:item[@"title"]],
                                      @"arrow.uturn.backward", YES, NO, ^{
                                        [self sectionCommand:@"Restore" identifier:item[@"id"]];
                                      })];
    NeonShowMenu(sender, sender.bounds, actions);
}
- (void)sectionCommand:(NSString*)command identifier:(NSString*)identifier {
    if (![self flush])
        return;
    NSError* error = nil;
    BOOL success = NO;
    if ([command hasPrefix:@"Rename"]) {
        NSString* title = @"";
        for (NSDictionary* section in self.session.sections)
            if ([section[@"id"] isEqual:identifier])
                title = section[@"title"];
        NSString* value = [self renameTitle:title];
        if (!value)
            return;
        success = [self.session renameSection:identifier title:value error:&error];
    } else if ([command isEqual:@"Duplicate"])
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
        [self showError:error];
        return;
    }
    [self showEditor];
    [self flush];
}
- (BOOL)windowShouldClose:(NSWindow*)sender {
    (void)sender;
    return [self flush];
}
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication*)sender {
    (void)sender;
    return [self flush] ? NSTerminateNow : NSTerminateCancel;
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender {
    (void)sender;
    return YES;
}
- (void)capture:(NSString*)file {
    NSTask* task = [NSTask new];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/sbin/screencapture"];
    // Capture this app window even when another app retains foreground focus.
    task.arguments = @[ @"-x", @"-o", @"-l", @(self.window.windowNumber).stringValue, file ];
    NSError* error = nil;
    if (![task launchAndReturnError:&error])
        [self showError:error];
    [task waitUntilExit];
    if (task.terminationStatus)
        exit(3);
}
- (void)captureLibrary {
    [self capture:@"native-bookshelf.png"];
    NSInteger index = [self.projects
        indexOfObjectPassingTest:^BOOL(NSDictionary* project, NSUInteger i, BOOL* stop) {
          (void)i;
          (void)stop;
          return [project[@"title"] isEqualToString:@"The Quiet Sea"];
        }];
    NSButton* button = [NSButton new];
    button.tag = index;
    @try {
        [self openProject:button];
    } @catch (NSException* exception) {
        fprintf(stderr, "Project opening exception: %s\n", exception.description.UTF8String);
        exit(9);
    }
    [self performSelector:@selector(captureEditor) withObject:nil afterDelay:1];
}
- (void)checkCompositionTypography {
    NSTextView* original = self.editor;
    NeonTextView* composition = [[NeonTextView alloc] initWithFrame:NSMakeRect(0, 0, 640, 300)];
    composition.string = @"draft";
    composition.font = NeonUI(12);
    __weak NeonApp* app = self;
    composition.compositionDidEnd = ^{
      if (app.pendingTypography)
          [app styleEditor];
    };
    self.editor = composition;
    [composition setMarkedText:@"漢字"
                 selectedRange:NSMakeRange(2, 0)
              replacementRange:NSMakeRange(5, 0)];
    NSRange selected = composition.selectedRange;
    [self styleEditor];
    if (!self.pendingTypography || composition.font.pointSize != 12)
        exit(16);
    [composition unmarkText];
    if (self.pendingTypography || composition.font.pointSize != NeonTextSize() ||
        ![composition.string isEqual:@"draft漢字"])
        exit(17);
    if (!NSEqualRanges(selected, composition.selectedRange))
        exit(18);
    self.editor = original;
}
- (void)captureEditor {
    [self checkCompositionTypography];
    [self capture:@"native-editor.png"];
    [self.editor insertText:@"\n\nA new beginning."
           replacementRange:NSMakeRange(self.editor.string.length, 0)];
    if (![self flush])
        exit(4);
    NSError* error = nil;
    NeonDocumentSession* reopened = [self.library openURL:self.selectedURL error:&error];
    if (![reopened.text containsString:@"A new beginning."] || reopened.sections.count != 2)
        exit(4);
    NSString* first = self.session.selectedSectionID;
    NSButton* second = [NSButton new];
    second.tag = 1;
    [self selectSection:second];
    if (![self.editor.string containsString:@"By noon"])
        exit(5);
    if (![self.session selectSection:first error:&error])
        exit(5);
    [self showEditor];
    [NeonPreferences() setInteger:2 forKey:@"appearance"];
    [self applyAppearance];
    [self performSelector:@selector(captureDark) withObject:nil afterDelay:1];
}
- (void)captureDark {
    [self capture:@"native-editor-dark.png"];
    for (NSToolbarItem* item in self.window.toolbar.items)
        if ([item.itemIdentifier isEqual:@"type"])
            [NSApp sendAction:item.action to:item.target from:item];
    [self performSelector:@selector(captureTypography) withObject:nil afterDelay:1];
}
- (void)captureTypography {
    if (!self.typography.shown)
        exit(8);
    [self capture:@"native-typography.png"];
    [self.typography close];
    [self sectionMenu:self.session.selectedSectionID
               anchor:self.sidebar.view
                 rect:NSMakeRect(50, 240, 1, 1)];
    [self performSelector:@selector(captureActions) withObject:nil afterDelay:1];
}
- (void)captureActions {
    [self capture:@"native-context-menu.png"];
    NeonDismissMenu();
    for (NSToolbarItem* item in self.window.toolbar.items) {
        if ([item.itemIdentifier isEqual:@"more"]) {
            if (![NSApp sendAction:item.action to:item.target from:item])
                exit(8);
            NeonDismissMenu();
        }
        if ([item.itemIdentifier isEqual:@"sidebar"]) {
            BOOL collapsed = self.split.splitViewItems.firstObject.collapsed;
            [NSApp sendAction:item.action to:item.target from:item];
            if (self.split.splitViewItems.firstObject.collapsed == collapsed) {
                fprintf(stderr, "Toolbar sidebar action did not toggle the pane\n");
                exit(8);
            }
            [NSApp sendAction:item.action to:item.target from:item];
        }
    }
    NSTextView* originalEditor = self.editor;
    NSString* draft = self.editor.string;
    NSRange selection = self.editor.selectedRange;
    NSString* projectTitle = self.session.title;
    NSString* chapterTitle = self.session.sectionTitle;
    [self.windowTitle beginRenaming];
    self.windowTitle.stringValue = @"Renamed in title bar";
    if (![self.windowTitle finishRenaming:YES] ||
        ![self.session.title isEqual:@"Renamed in title bar"])
        exit(7);
    [self.chapterTitle beginRenaming];
    self.chapterTitle.stringValue = @"Renamed in manuscript";
    if (![self.chapterTitle finishRenaming:YES] ||
        ![self.session.sectionTitle isEqual:@"Renamed in manuscript"])
        exit(7);
    [self.chapterTitle beginRenaming];
    self.chapterTitle.stringValue = @"Cancelled title";
    [self.chapterTitle finishRenaming:NO];
    if (![self.chapterTitle.stringValue isEqual:@"Renamed in manuscript"] ||
        self.editor != originalEditor || ![self.editor.string isEqual:draft] ||
        !NSEqualRanges(selection, self.editor.selectedRange))
        exit(7);
    NSError* error = nil;
    NeonDocumentSession* reopened = [self.library openURL:self.selectedURL error:&error];
    if (![reopened.title isEqual:@"Renamed in title bar"] ||
        ![reopened.sectionTitle isEqual:@"Renamed in manuscript"])
        exit(7);
    if (![self renameInline:projectTitle section:nil] ||
        ![self renameInline:chapterTitle section:self.session.selectedSectionID])
        exit(7);
    NSString* identifier = self.session.selectedSectionID;
    [self sectionCommand:@"Duplicate" identifier:identifier];
    if (self.session.sections.count != 3)
        exit(6);
    [self sectionCommand:@"Move to Trash…" identifier:identifier];
    if (self.session.sections.count != 2 || self.session.trashedSections.count != 1)
        exit(6);
    [self sectionCommand:@"Restore" identifier:identifier];
    if (self.session.sections.count != 3 || self.session.trashedSections.count)
        exit(6);
    [self showSettings:nil];
    [self performSelector:@selector(captureSettings) withObject:nil afterDelay:1];
}
- (void)captureSettings {
    NeonSettingsController* controller = (id)self.settings.contentViewController;
    if (controller.visibleSettingCount != 10)
        exit(10);
    [controller filterSettings:@"PARAGRAPH"];
    if (controller.visibleSettingCount != 1)
        exit(10);
    NSStepper* control = (id)settingControl(controller.view, @"paragraphSpacing");
    if (![control isKindOfClass:NSStepper.class])
        exit(10);
    NSString* draft = self.editor.string;
    NSRange selection = self.editor.selectedRange;
    id original = [NeonPreferences() objectForKey:@"paragraphSpacing"];
    control.doubleValue = 12;
    [NSApp sendAction:control.action to:control.target from:control];
    if (NeonParagraphSpacing() != 12 || self.editor.defaultParagraphStyle.paragraphSpacing != 12 ||
        ![draft isEqual:self.editor.string] || !NSEqualRanges(selection, self.editor.selectedRange))
        exit(10);
    if (original)
        [NeonPreferences() setObject:original forKey:@"paragraphSpacing"];
    else
        [NeonPreferences() removeObjectForKey:@"paragraphSpacing"];
    controller.preferencesChanged();
    [controller filterSettings:@"no matching setting"];
    if (controller.visibleSettingCount)
        exit(10);
    [controller filterSettings:@""];
    [self performSelector:@selector(finishSettingsSmoke) withObject:nil afterDelay:1];
}
- (void)finishSettingsSmoke {
    [self capture:@"native-settings.png"];
    [self.settings close];
    NSError* error = nil;
    if (![self.session createCheckpoint:@"Before review" error:&error])
        exit(11);
    NSString* checkpoint = self.session.history.firstObject[@"id"];
    NSString* original = self.session.text;
    if (![self.session replaceText:@"An unsaved revision" error:&error] ||
        ![self.session restoreRevision:checkpoint error:&error] ||
        ![self.session.text isEqual:original])
        exit(11);
    [self showEditor];
    NSTextView* originalEditor = self.editor;
    originalEditor.selectedRange = NSMakeRange(MIN(5, originalEditor.string.length), 0);
    NSRange selection = originalEditor.selectedRange;
    [self showHistory:nil];
    [self showEditor];
    if (self.editor != originalEditor || !NSEqualRanges(selection, self.editor.selectedRange))
        exit(11);
    [self showHistory:nil];
    [self performSelector:@selector(captureHistory) withObject:nil afterDelay:1];
}
- (void)captureHistory {
    NeonHistoryController* controller = self.historyController;
    [controller selectRevisionAtIndex:1];
    [self capture:@"native-history.png"];
    self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    [self performSelector:@selector(captureHistoryDark) withObject:nil afterDelay:1];
}
- (void)captureHistoryDark {
    [self capture:@"native-history-dark.png"];
    [self showEditor];
    NSError* error = nil;
    NSURL* url = [self.library createProject:@"The tidal study" preset:@"research" error:&error];
    self.session = [self.library openURL:url error:&error];
    self.selectedURL = url;
    if (self.session.sections.count != 6 || ![self.session.sectionTitle isEqual:@"Abstract"])
        exit(12);
    [self showEditor];
    if (self.editor.defaultParagraphStyle.lineHeightMultiple != 2)
        exit(12);
    [self performSelector:@selector(capturePreset) withObject:nil afterDelay:1];
}
- (void)capturePreset {
    [self capture:@"native-research.png"];
    printf("Shared Mac editor/navigation/reopen, commands, settings, history and presets passed\n");
    [NSApp terminate:nil];
}
@end
int main(int argc, const char* argv[]) {
    (void)argc;
    (void)argv;
    @autoreleasepool {
        NSApplication* app = NSApplication.sharedApplication;
        app.activationPolicy = NSApplicationActivationPolicyRegular;
        NeonApp* delegate = [NeonApp new];
        app.delegate = delegate;
        [app run];
    }
}
