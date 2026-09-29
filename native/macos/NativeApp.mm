#import "ContextMenu.h"
#import "EditorialTheme.h"
#import "InlineTitle.h"
#import "LibraryStore.h"
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
@interface NeonChapterRow : NSStackView
@property(nonatomic) BOOL currentChapter;
@end
@implementation NeonChapterRow
- (void)drawRect:(NSRect)rect {
    (void)rect;
    if (!self.currentChapter)
        return;
    [[NeonAccent() colorWithAlphaComponent:0.18] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:7 yRadius:7] fill];
    [NeonAccent() setFill];
    [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(0, 7, 3, self.bounds.size.height - 14)
                                     xRadius:1.5
                                     yRadius:1.5] fill];
}
@end

namespace {
NSTextField* label(NSString* text, NSFont* font, NSColor* color) {
    NSTextField* label = [NSTextField wrappingLabelWithString:text];
    label.font = font;
    label.textColor = color;
    return label;
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
- (void)drawRect:(NSRect)rect {
    [(self.panel ? NeonPanel() : NeonPaper()) setFill];
    NSRectFill(rect);
}
@end
@interface NeonTextView : NSTextView
@end
@implementation NeonTextView
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
@property(nonatomic, strong) NSTextField* status;
@property(nonatomic, strong) NeonInlineTitle* windowTitle;
@property(nonatomic, strong) NeonInlineTitle* chapterTitle;
@property(nonatomic, strong) NSView* sidebarBody;
@property(nonatomic, strong) NSView* sidebarMaterial;
- (BOOL)renameInline:(NSString*)title section:(NSString*)identifier;
@property(nonatomic, strong) NSTimer* timer;
@property(nonatomic, strong) NSPopover* typography;
@property(nonatomic, strong) NSPanel* settings;
@property(nonatomic) BOOL trashMode;
- (void)projectMenu:(NSURL*)url title:(NSString*)title anchor:(id)anchor rect:(NSRect)rect;
- (void)sectionMenu:(NSString*)identifier anchor:(NSView*)anchor rect:(NSRect)rect;
- (void)projectCommand:(NSString*)command url:(NSURL*)url title:(NSString*)title;
- (void)sectionCommand:(NSString*)command identifier:(NSString*)identifier;

@property(nonatomic) BOOL smoke;
- (BOOL)flush;
@end
@implementation NeonApp
- (void)applicationDidFinishLaunching:(NSNotification*)note {
    (void)note;
    NeonRegisterFonts();
    self.smoke = [NSProcessInfo.processInfo.arguments containsObject:@"--smoke-test"];
    NSURL* root =
        self.smoke
            ? [NSURL fileURLWithPath:[NSTemporaryDirectory()
                                         stringByAppendingPathComponent:NSUUID.UUID.UUIDString]]
            : [[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                      inDomains:NSUserDomainMask]
                      .firstObject URLByAppendingPathComponent:@"Neon Apple Preview"];
    self.library = [[NeonLibraryStore alloc] initWithDirectory:root];
    NSError* error = nil;
    if (self.smoke && ![self.library seedPreview:&error]) {
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
    self.window.toolbar = toolbar;
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
    [NSWorkspace.sharedWorkspace.notificationCenter
        addObserver:self
           selector:@selector(accessibilityChanged:)
               name:NSWorkspaceAccessibilityDisplayOptionsDidChangeNotification
             object:nil];
    [self applyAppearance];
    [self installMenu];
    [self showLibrary:nil];
    [self.window setFrame:NSInsetRect(NSScreen.mainScreen.visibleFrame, 24, 24) display:YES];
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
    self.window.backgroundColor = NeonPaper();
    [self.sidebarMaterial removeFromSuperview];
    if (NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceTransparency) {
        NeonSurface* opaque = [NeonSurface new];
        opaque.panel = YES;
        self.sidebarMaterial = opaque;
    } else if (@available(macOS 26.0, *)) {
        NSGlassEffectView* glass = [NSGlassEffectView new];
        glass.tintColor = [NeonPanel() colorWithAlphaComponent:0.25];
        glass.cornerRadius = 12;
        self.sidebarMaterial = glass;
    } else {
        NSVisualEffectView* material = [NSVisualEffectView new];
        material.material = NSVisualEffectMaterialSidebar;
        material.blendingMode = NSVisualEffectBlendingModeBehindWindow;
        material.state = NSVisualEffectStateFollowsWindowActiveState;
        self.sidebarMaterial = material;
    }
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
    [file.submenu addItemWithTitle:@"Save" action:@selector(saveAction:) keyEquivalent:@"s"];
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
        @"projectTitle", @"sidebar", @"library", NSToolbarFlexibleSpaceItemIdentifier, @"type",
        @"more", @"new"
    ];
}
- (NSArray*)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar {
    return [self toolbarDefaultItemIdentifiers:toolbar];
}
- (NSToolbarItem*)toolbar:(NSToolbar*)toolbar
        itemForItemIdentifier:(NSString*)identifier
    willBeInsertedIntoToolbar:(BOOL)flag {
    (void)toolbar;
    (void)flag;
    if ([identifier isEqual:@"projectTitle"]) {
        NSToolbarItem* titleItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
        self.windowTitle = [[NeonInlineTitle alloc] initWithFrame:NSMakeRect(0, 0, 210, 26)];
        self.windowTitle.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
        self.windowTitle.stringValue = @"Neon";
        self.windowTitle.accessibilityLabel = @"Project title";
        __weak NeonApp* weakSelf = self;
        self.windowTitle.commitTitle = ^BOOL(NSString* title) {
          return [weakSelf renameInline:title section:nil];
        };
        titleItem.label = @"Project title";
        titleItem.navigational = YES;
        titleItem.view = self.windowTitle;
        [self.windowTitle.widthAnchor constraintEqualToConstant:210].active = YES;
        return titleItem;
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
    result.navigational = [identifier isEqual:@"sidebar"] || [identifier isEqual:@"library"];
    result.toolTip = item[0];
    result.target = self;
    result.action = NSSelectorFromString(item[2]);
    result.image = [NSImage imageWithSystemSymbolName:item[1] accessibilityDescription:item[0]];
    return result;
}
- (void)toggleSidebar:(id)sender {
    [self.split toggleSidebar:sender];
}
- (void)clear:(NSView*)view {
    for (NSView* child in view.subviews.copy)
        [child removeFromSuperview];
}
- (void)buildSidebar {
    [self clear:self.sidebarBody];
    NSMutableArray* rows = [NSMutableArray
        arrayWithObjects:label(@"NEON", NeonUI(12), NeonMuted()),
                         button(@"Library", @"books.vertical", self, @selector(showLibrary:)), nil];
    [rows addObject:button(@"Trash", @"trash", self, @selector(showTrash:))];
    if (self.session) {
        __weak NeonApp* weakSelf = self;
        NeonInlineTitle* book = [NeonInlineTitle new];
        book.stringValue = self.session.title;
        book.font = NeonSerif(23);
        book.accessibilityLabel = @"Project title";
        book.commitTitle = ^BOOL(NSString* title) {
          return [weakSelf renameInline:title section:nil];
        };
        [rows addObject:book];
        [rows addObject:label(@"MANUSCRIPT", NeonUI(11), NeonMuted())];
        NSInteger index = 0;
        for (NSDictionary* section in self.session.sections) {
            NeonInlineTitle* row = [NeonInlineTitle new];
            row.stringValue = section[@"title"];
            row.font = NeonUI(15);
            row.accessibilityLabel = @"Chapter title";
            row.tag = index++;
            NSString* identifier = section[@"id"];
            row.commitTitle = ^BOOL(NSString* title) {
              return [weakSelf renameInline:title section:identifier];
            };
            row.activateTitle = ^{
              NeonApp* app = weakSelf;
              if (![app flush])
                  return;
              NSError* error = nil;
              if (![app.session selectSection:identifier error:&error]) {
                  [app showError:error];
                  return;
              }
              [app showEditor];
            };
            row.contextAction = ^(NSView* anchor, NSRect rect) {
              [weakSelf sectionMenu:identifier anchor:anchor rect:rect];
            };
            row.textColor =
                [identifier isEqual:self.session.selectedSectionID] ? NeonAccent() : NeonInk();
            [row.widthAnchor constraintGreaterThanOrEqualToConstant:70].active = YES;
            [row setContentHuggingPriority:200
                            forOrientation:NSLayoutConstraintOrientationHorizontal];
            [row.heightAnchor constraintGreaterThanOrEqualToConstant:32].active = YES;
            NSButton* more = button(@"", @"ellipsis", self, @selector(chapterActions:));
            more.tag = index - 1;
            BOOL selected = [identifier isEqual:self.session.selectedSectionID];
            NSImageView* check =
                [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:@"checkmark"
                                                          accessibilityDescription:nil]];
            check.contentTintColor = NeonAccent();
            check.alphaValue = selected ? 1 : 0;
            [check.widthAnchor constraintEqualToConstant:12].active = YES;
            [more.widthAnchor constraintEqualToConstant:28].active = YES;
            [more.heightAnchor constraintEqualToConstant:28].active = YES;
            more.toolTip = @"Chapter actions";
            NeonChapterRow* chapter = [NeonChapterRow stackViewWithViews:@[ check, row, more ]];
            chapter.currentChapter = selected;
            chapter.spacing = 7;
            chapter.edgeInsets = NSEdgeInsetsMake(5, 10, 5, 8);
            chapter.accessibilityLabel = section[@"title"];
            chapter.accessibilityValue = selected ? @"Current chapter" : @"Chapter";
            [chapter.widthAnchor constraintEqualToAnchor:self.sidebarBody.widthAnchor constant:-28]
                .active = YES;
            [rows addObject:chapter];
        }
        [rows addObject:button(@"New Chapter", @"plus", self, @selector(newSection:))];
        if (self.session.trashedSections.count)
            [rows addObject:button(@"Deleted chapters", @"arrow.uturn.backward", self,
                                   @selector(sectionTrash:))];
    } else {
        [rows addObject:label(@"ON THIS MAC", NeonUI(11), NeonMuted())];
    }
    NSScrollView* scroll = [NSScrollView new];
    scroll.drawsBackground = NO;
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.scrollerStyle = NSScrollerStyleOverlay;
    pin(scroll, self.sidebarBody);
    NSStackView* stack = column(rows, 22);
    stack.edgeInsets = NSEdgeInsetsMake(28, 20, 28, 16);
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.documentView = stack;
    [stack.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor].active = YES;
}
- (void)showLibrary:(id)sender {
    if (sender != self)
        self.trashMode = NO;
    if (![self flush])
        return;
    self.editor = nil;
    self.session = nil;
    self.selectedURL = nil;
    self.status = nil;
    self.window.title = @"Neon";
    self.window.subtitle = @"";
    self.windowTitle.stringValue = @"Neon";
    self.windowTitle.enabled = NO;
    self.chapterTitle = nil;
    [self buildSidebar];
    [self clear:self.content.view];
    NSError* error = nil;
    self.projects =
        self.trashMode ? [self.library trashedProjects:&error] : [self.library projects:&error];
    if (!self.projects) {
        [self showError:error];
        return;
    }
    NSScrollView* scroll = [NSScrollView new];
    scroll.drawsBackground = NO;
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.scrollerStyle = NSScrollerStyleOverlay;
    pin(scroll, self.content.view);
    NSStackView* stack = column(
        @[
            label(self.trashMode ? @"Trash" : @"Library", NeonSerif(38), NeonInk()),
            label(self.trashMode ? @"Restore a project or delete it permanently."
                                 : @"Your projects, saved on this Mac.",
                  NeonUI(15), NeonMuted())
        ],
        14);
    stack.edgeInsets = NSEdgeInsetsMake(36, 40, 36, 40);
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.documentView = stack;
    [stack.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor].active = YES;
    NSInteger index = 0;
    for (NSDictionary* project in self.projects) {
        NeonBookCover* cover = [[NeonBookCover alloc] initWithFrame:NSMakeRect(0, 0, 110, 150)];
        __weak NeonApp* weakSelf = self;
        NSURL* projectURL = project[@"url"];
        NSString* projectTitle = project[@"title"];
        cover.contextAction = ^(NSView* anchor, NSRect rect) {
          [weakSelf projectMenu:projectURL title:projectTitle anchor:anchor rect:rect];
        };
        cover.titleText = project[@"title"];
        cover.tag = index;
        cover.target = self;
        cover.action = @selector(openProject:);
        cover.accessibilityLabel = [@"Open " stringByAppendingString:project[@"title"]];
        [cover.widthAnchor constraintEqualToConstant:110].active = YES;
        [cover.heightAnchor constraintEqualToConstant:150].active = YES;
        NSButton* title = button(project[@"title"], nil, self, @selector(openProject:));
        title.font = NeonSerif(25);
        title.tag = index++;
        NSString* detail =
            [project[@"error"] length]
                ? project[@"error"]
                : [NSString stringWithFormat:@"%@ sections · On this Mac", project[@"sections"]];
        NSButton* more = button(@"Actions", @"ellipsis", self, @selector(projectActions:));
        more.tag = index - 1;
        NSStackView* row = [NSStackView stackViewWithViews:@[
            cover, column(@[ title, label(detail, NeonUI(14), NeonMuted()), more ], 10)
        ]];
        row.spacing = 24;
        [stack addArrangedSubview:row];
        [stack setCustomSpacing:26 afterView:row];
    }
    if (!self.projects.count)
        [stack addArrangedSubview:label(@"Begin with a working title. The rest can follow.",
                                        NeonSerif(22), NeonMuted())];
    [stack addArrangedSubview:button(@"New Project", @"plus", self, @selector(newProject:))];
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
    NeonDocumentSession* session = [self.library openURL:url error:&error];
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
- (void)showEditor {
    self.editor = nil;
    [self clear:self.content.view];
    self.window.title = self.session.title;
    self.window.subtitle = @"";
    self.windowTitle.stringValue = self.session.title;
    self.windowTitle.enabled = YES;
    self.chapterTitle = nil;
    [self buildSidebar];
    if (!self.session.sections.count) {
        NSStackView* empty = column(
            @[
                label(@"A fresh page", NeonSerif(38), NeonInk()),
                label(@"Create a chapter, or restore one from Deleted chapters.", NeonUI(16),
                      NeonMuted()),
                button(@"New Chapter", @"plus", self, @selector(newSection:))
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
    NSTextField* kicker =
        label([NSString stringWithFormat:@"CHAPTER %lu", number], NeonUI(12), NeonMuted());
    kicker.alignment = NSTextAlignmentCenter;
    NeonInlineTitle* heading = [NeonInlineTitle new];
    heading.stringValue = self.session.sectionTitle;
    heading.font = NeonSerif(38);
    heading.accessibilityLabel = @"Chapter title";
    self.chapterTitle = heading;
    __weak NeonApp* weakSelf = self;
    NSString* identifier = self.session.selectedSectionID;
    heading.commitTitle = ^BOOL(NSString* title) {
      return [weakSelf renameInline:title section:identifier];
    };
    heading.alignment = NSTextAlignmentCenter;
    NSStackView* stack = column(@[ kicker, heading ], 18);
    stack.edgeInsets = NSEdgeInsetsMake(46, 44, 18, 44);
    stack.alignment = NSLayoutAttributeCenterX;
    pin(stack, self.content.view);
    NSBox* rule = [NSBox new];
    rule.boxType = NSBoxSeparator;
    [rule.widthAnchor constraintEqualToConstant:130].active = YES;
    [stack addArrangedSubview:rule];
    [stack setCustomSpacing:30 afterView:rule];
    NSScrollView* scroll = [NSScrollView new];
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.scrollerStyle = NSScrollerStyleOverlay;
    scroll.drawsBackground = NO;
    self.editor = [[NeonTextView alloc] initWithFrame:NSMakeRect(0, 0, 650, 400)];
    self.editor.minSize = NSMakeSize(0, 300);
    self.editor.maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
    self.editor.verticallyResizable = YES;
    self.editor.horizontallyResizable = NO;
    self.editor.autoresizingMask = NSViewWidthSizable;
    self.editor.textContainer.widthTracksTextView = YES;
    self.editor.textContainerInset = NSMakeSize(22, 10);
    self.editor.richText = NO;
    self.editor.allowsUndo = YES;
    self.editor.string = self.session.text;
    self.editor.delegate = self;
    self.editor.backgroundColor = NeonPaper();
    self.editor.textColor = NeonInk();
    [self styleEditor];
    scroll.documentView = self.editor;
    [stack addArrangedSubview:scroll];
    [scroll.widthAnchor constraintLessThanOrEqualToAnchor:stack.widthAnchor constant:-88].active =
        YES;
    [scroll.widthAnchor constraintLessThanOrEqualToConstant:780].active = YES;
    NSLayoutConstraint* preferred = [scroll.widthAnchor constraintEqualToAnchor:stack.widthAnchor
                                                                       constant:-88];
    preferred.priority = 750;
    preferred.active = YES;
    [scroll.heightAnchor constraintGreaterThanOrEqualToConstant:180].active = YES;
    [scroll setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationVertical];
    self.status = label(@"Saved on this Mac", NeonUI(12), NeonMuted());
    [stack addArrangedSubview:self.status];
    [self.window makeFirstResponder:self.editor];
    [self updateStatus:YES];
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
    NSRange selection = self.editor.selectedRange;
    self.editor.font = NeonManuscriptFont(NeonTextSize());
    NSMutableParagraphStyle* paragraph = [NSMutableParagraphStyle new];
    paragraph.lineSpacing = NeonLineSpacing();
    paragraph.paragraphSpacing = 4;
    self.editor.defaultParagraphStyle = paragraph;
    [self.editor.textStorage addAttributes:@{
        NSFontAttributeName : NeonManuscriptFont(NeonTextSize()),
        NSParagraphStyleAttributeName : paragraph,
        NSForegroundColorAttributeName : NeonInk()
    }
                                     range:NSMakeRange(0, self.editor.string.length)];
    self.editor.typingAttributes = @{
        NSFontAttributeName : NeonManuscriptFont(NeonTextSize()),
        NSParagraphStyleAttributeName : paragraph,
        NSForegroundColorAttributeName : NeonInk()
    };
    self.editor.selectedRange = selection;
}
- (void)updateStatus:(BOOL)saved {
    self.status.stringValue =
        [NSString stringWithFormat:@"%lu words  ·  %@", words(self.editor.string),
                                   saved ? @"Saved on this Mac" : @"Unsaved changes"];
}
- (void)textDidChange:(NSNotification*)notification {
    (void)notification;
    if (self.editor.hasMarkedText)
        return;
    NSError* error = nil;
    if (![self.session replaceText:self.editor.string error:&error]) {
        [self showError:error];
        return;
    }
    [self updateStatus:NO];
    [self.timer invalidate];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.6
                                                  target:self
                                                selector:@selector(saveAction:)
                                                userInfo:nil
                                                 repeats:NO];
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
    NSString* title = [self askTitle:@"Start a new project"];
    if (!title)
        return;
    NSError* error = nil;
    NSURL* url = [self.library createProject:title error:&error];
    if (!url) {
        [self showError:error];
        return;
    }
    self.trashMode = NO;
    self.session = [self.library openURL:url error:&error];
    self.selectedURL = url;
    [self showEditor];
}
- (void)newSection:(id)sender {
    (void)sender;
    if (![self flush])
        return;
    NSString* title = [self askTitle:@"New section"];
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
    [NSUserDefaults.standardUserDefaults setObject:sender.identifier forKey:@"manuscriptFont"];
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
    if (self.settings) {
        [self.settings makeKeyAndOrderFront:nil];
        return;
    }
    self.settings = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 480, 300)
                                               styleMask:NSWindowStyleMaskTitled
                                                 backing:NSBackingStoreBuffered
                                                   defer:NO];
    self.settings.title = @"Writing Settings";
    self.settings.appearance = self.window.appearance;
    NeonSurface* surface = [NeonSurface new];
    surface.panel = YES;
    self.settings.contentView = surface;
    NSStackView* stack = column(
        @[
            label(@"Writing", NeonSerif(28), NeonInk()),
            label(@"Typography preferences apply to this Mac. Your document text is unchanged.",
                  NeonUI(16), NeonMuted()),
            button(@"Typography…", @"textformat", self, @selector(settingsTypography:)),
            button(@"Reset Writing Preferences", @"arrow.counterclockwise", self,
                   @selector(resetPreferences:)),
            button(@"Done", nil, self, @selector(closeSettings:))
        ],
        20);
    stack.edgeInsets = NSEdgeInsetsMake(24, 24, 24, 24);
    pin(stack, surface);
    [self.window beginSheet:self.settings completionHandler:nil];
}
- (void)settingsTypography:(id)sender {
    [self showTypography:sender];
}
- (void)resetPreferences:(id)sender {
    (void)sender;
    for (NSString* key in
         @[ @"manuscriptFont", @"manuscriptSize", @"manuscriptSpacing", @"appearance" ])
        [NSUserDefaults.standardUserDefaults removeObjectForKey:key];
    [self applyAppearance];
    [self styleEditor];
}
- (void)closeSettings:(id)sender {
    (void)sender;
    [self.typography close];
    [self.window endSheet:self.settings];
    self.settings = nil;
}
- (void)changeSize:(NSSlider*)sender {
    [NSUserDefaults.standardUserDefaults setDouble:sender.doubleValue forKey:@"manuscriptSize"];
    [self styleEditor];
}
- (void)changeSpacing:(NSSlider*)sender {
    [NSUserDefaults.standardUserDefaults setDouble:sender.doubleValue forKey:@"manuscriptSpacing"];
    [self styleEditor];
}
- (void)changeAppearance:(NSSegmentedControl*)sender {
    [NSUserDefaults.standardUserDefaults setInteger:sender.selectedSegment forKey:@"appearance"];
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
    self.trashMode = YES;
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
    else
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
    if (sender.tag < static_cast<NSInteger>(self.session.sections.count))
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
    task.arguments = @[ @"-x", file ];
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
    [self openProject:button];
    [self performSelector:@selector(captureEditor) withObject:nil afterDelay:1];
}
- (void)captureEditor {
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
    [NSUserDefaults.standardUserDefaults setInteger:2 forKey:@"appearance"];
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
            if (self.split.splitViewItems.firstObject.collapsed == collapsed)
                exit(8);
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
    printf("Shared Mac editor/navigation/reopen and command workflows passed\n");
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
