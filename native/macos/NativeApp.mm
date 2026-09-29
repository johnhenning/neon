#import "EditorialTheme.h"
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
@interface NeonChapterButton : NSButton
@end
@implementation NeonChapterButton
- (NSSize)intrinsicContentSize {
    return NSMakeSize(180, 36);
}
- (void)drawRect:(NSRect)rect {
    (void)rect;
    [NSGraphicsContext saveGraphicsState];
    [NSBezierPath clipRect:self.bounds];
    if (self.state == NSControlStateValueOn) {
        [[NeonAccent() colorWithAlphaComponent:0.16] setFill];
        [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:6 yRadius:6] fill];
    }
    [self.title drawInRect:NSInsetRect(self.bounds, 10, 8)
            withAttributes:@{
                NSFontAttributeName : NeonUI(15),
                NSForegroundColorAttributeName : NeonInk()
            }];
    [NSGraphicsContext restoreGraphicsState];
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
@interface NeonSurface : NSView
@property(nonatomic) BOOL panel;
@end
@implementation NeonSurface
- (void)drawRect:(NSRect)rect {
    [(self.panel ? NeonPanel() : NeonPaper()) setFill];
    NSRectFill(rect);
}
@end
@interface NeonBookCover : NSButton
@property(nonatomic, copy) NSString* titleText;
@end
@implementation NeonBookCover
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
@property(nonatomic, strong) NSTimer* timer;
@property(nonatomic, strong) NSPanel* typography;
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
    self.window.minSize = NSMakeSize(760, 560);
    self.window.delegate = self;
    self.window.toolbarStyle = NSWindowToolbarStyleUnified;
    NSToolbar* toolbar = [[NSToolbar alloc] initWithIdentifier:@"NeonEditorial"];
    toolbar.delegate = self;
    toolbar.displayMode = NSToolbarDisplayModeIconOnly;
    self.window.toolbar = toolbar;
    self.split = [NSSplitViewController new];
    self.sidebar = [NSViewController new];
    NeonSurface* panel = [NeonSurface new];
    panel.panel = YES;
    self.sidebar.view = panel;
    NSSplitViewItem* side = [NSSplitViewItem sidebarWithViewController:self.sidebar];
    side.minimumThickness = 220;
    side.maximumThickness = 290;
    side.canCollapse = YES;
    [self.split addSplitViewItem:side];
    self.content = [NSViewController new];
    self.content.view = [NeonSurface new];
    [self.split addSplitViewItem:[NSSplitViewItem splitViewItemWithViewController:self.content]];
    self.window.contentViewController = self.split;
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
- (void)applyAppearance {
    self.window.appearance =
        NeonAppearance() == 1   ? [NSAppearance appearanceNamed:NSAppearanceNameAqua]
        : NeonAppearance() == 2 ? [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]
                                : nil;
    self.window.backgroundColor = NeonPaper();
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
    [app.submenu addItemWithTitle:@"Typography…"
                           action:@selector(showTypography:)
                    keyEquivalent:@","];
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
    return @[ @"sidebar", @"library", NSToolbarFlexibleSpaceItemIdentifier, @"type", @"new" ];
}
- (NSArray*)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar {
    return [self toolbarDefaultItemIdentifiers:toolbar];
}
- (NSToolbarItem*)toolbar:(NSToolbar*)toolbar
        itemForItemIdentifier:(NSString*)identifier
    willBeInsertedIntoToolbar:(BOOL)flag {
    (void)toolbar;
    (void)flag;
    NSDictionary* config = @{
        @"sidebar" : @[ @"Toggle sidebar", @"sidebar.left", @"toggleSidebar:" ],
        @"library" : @[ @"Library", @"books.vertical", @"showLibrary:" ],
        @"type" : @[ @"Typography", @"textformat", @"showTypography:" ],
        @"new" : @[ @"New Project", @"plus", @"newProject:" ]
    };
    NSArray* item = config[identifier];
    NSToolbarItem* result = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
    result.label = item[0];
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
    [self clear:self.sidebar.view];
    NSMutableArray* rows = [NSMutableArray
        arrayWithObjects:label(@"NEON", NeonUI(12), NeonMuted()),
                         button(@"Library", @"books.vertical", self, @selector(showLibrary:)), nil];
    if (self.session) {
        [rows addObject:label(self.session.title, NeonSerif(23), NeonInk())];
        [rows addObject:label(@"MANUSCRIPT", NeonUI(11), NeonMuted())];
        NSInteger index = 0;
        for (NSDictionary* section in self.session.sections) {
            NSButton* row = [NeonChapterButton
                buttonWithTitle:[NSString stringWithFormat:@"%ld   %@", ++index, section[@"title"]]
                         target:self
                         action:@selector(selectSection:)];
            row.tag = index - 1;
            row.alignment = NSTextAlignmentLeft;
            row.buttonType = NSButtonTypePushOnPushOff;
            row.state = [section[@"id"] isEqualToString:self.session.selectedSectionID]
                            ? NSControlStateValueOn
                            : NSControlStateValueOff;
            [rows addObject:row];
        }
        [rows addObject:button(@"New Section", @"plus", self, @selector(newSection:))];
    } else {
        [rows addObject:label(@"ON THIS MAC", NeonUI(11), NeonMuted())];
    }
    NSScrollView* scroll = [NSScrollView new];
    scroll.drawsBackground = NO;
    scroll.hasVerticalScroller = YES;
    pin(scroll, self.sidebar.view);
    NSStackView* stack = column(rows, 22);
    stack.edgeInsets = NSEdgeInsetsMake(28, 20, 28, 16);
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.documentView = stack;
    [stack.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor].active = YES;
}
- (void)showLibrary:(id)sender {
    (void)sender;
    if (![self flush])
        return;
    self.editor = nil;
    self.session = nil;
    self.selectedURL = nil;
    self.status = nil;
    self.window.title = @"Neon";
    self.window.subtitle = @"Library";
    [self buildSidebar];
    [self clear:self.content.view];
    NSError* error = nil;
    self.projects = [self.library projects:&error];
    if (!self.projects) {
        [self showError:error];
        return;
    }
    NSScrollView* scroll = [NSScrollView new];
    scroll.drawsBackground = NO;
    scroll.hasVerticalScroller = YES;
    pin(scroll, self.content.view);
    NSStackView* stack = column(
        @[
            label(@"Library", NeonSerif(38), NeonInk()),
            label(@"Your projects, saved on this Mac.", NeonUI(15), NeonMuted())
        ],
        14);
    stack.edgeInsets = NSEdgeInsetsMake(36, 40, 36, 40);
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.documentView = stack;
    [stack.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor].active = YES;
    NSInteger index = 0;
    for (NSDictionary* project in self.projects) {
        NeonBookCover* cover = [[NeonBookCover alloc] initWithFrame:NSMakeRect(0, 0, 110, 150)];
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
        NSStackView* row = [NSStackView stackViewWithViews:@[
            cover, column(@[ title, label(detail, NeonUI(14), NeonMuted()) ], 10)
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
    self.window.subtitle = @"Manuscript";
    [self buildSidebar];
    NSTextField* kicker = label(@"MANUSCRIPT", NeonUI(12), NeonMuted());
    kicker.alignment = NSTextAlignmentCenter;
    NSTextField* heading = label(self.session.sectionTitle, NeonSerif(38), NeonInk());
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
    scroll.drawsBackground = NO;
    self.editor = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 650, 400)];
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
- (void)styleEditor {
    if (!self.editor)
        return;
    NSRange selection = self.editor.selectedRange;
    self.editor.font = NeonSerif(NeonTextSize());
    NSMutableParagraphStyle* paragraph = [NSMutableParagraphStyle new];
    paragraph.lineSpacing = NeonLineSpacing();
    paragraph.paragraphSpacing = 18;
    self.editor.defaultParagraphStyle = paragraph;
    [self.editor.textStorage addAttributes:@{
        NSFontAttributeName : NeonSerif(NeonTextSize()),
        NSParagraphStyleAttributeName : paragraph,
        NSForegroundColorAttributeName : NeonInk()
    }
                                     range:NSMakeRange(0, self.editor.string.length)];
    self.editor.typingAttributes = @{
        NSFontAttributeName : NeonSerif(NeonTextSize()),
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
    (void)sender;
    if (self.typography)
        return;
    self.typography = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 360, 300)
                                                 styleMask:NSWindowStyleMaskTitled
                                                   backing:NSBackingStoreBuffered
                                                     defer:NO];
    self.typography.title = @"Typography";
    self.typography.appearance = self.window.appearance;
    NSSlider* size = [NSSlider sliderWithValue:NeonTextSize()
                                      minValue:16
                                      maxValue:32
                                        target:self
                                        action:@selector(changeSize:)];
    NSSlider* space = [NSSlider sliderWithValue:NeonLineSpacing()
                                       minValue:2
                                       maxValue:16
                                         target:self
                                         action:@selector(changeSpacing:)];
    NSSegmentedControl* appearance =
        [NSSegmentedControl segmentedControlWithLabels:@[ @"System", @"Light", @"Dark" ]
                                          trackingMode:NSSegmentSwitchTrackingSelectOne
                                                target:self
                                                action:@selector(changeAppearance:)];
    appearance.selectedSegment = NeonAppearance();
    NSStackView* stack = column(
        @[
            label(@"Literata", NeonSerif(24), NeonInk()),
            label(@"Text size", NeonUI(14), NeonMuted()), size,
            label(@"Line spacing", NeonUI(14), NeonMuted()), space, appearance,
            button(@"Done", nil, self, @selector(closeTypography:))
        ],
        10);
    stack.edgeInsets = NSEdgeInsetsMake(20, 24, 20, 24);
    pin(stack, self.typography.contentView);
    [self.window beginSheet:self.typography completionHandler:nil];
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
    [self.window endSheet:self.typography];
    self.typography = nil;
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
    self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    [self performSelector:@selector(captureDark) withObject:nil afterDelay:1];
}
- (void)captureDark {
    [self capture:@"native-editor-dark.png"];
    printf("Shared Mac editor/navigation/reopen passed\n");
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
