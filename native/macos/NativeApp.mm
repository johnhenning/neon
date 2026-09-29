#include "MacRepository.h"
#include "neon/workspace.h"
#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#include <cstdio>
#include <cstdlib>
#include <memory>
#include <string>

namespace {
NSString* ns(const std::string& value) {
    return [[NSString alloc] initWithBytes:value.data()
                                    length:value.size()
                                  encoding:NSUTF8StringEncoding];
}
std::string utf8(NSString* value) {
    NSData* data = [value dataUsingEncoding:NSUTF8StringEncoding];
    return {static_cast<const char*>(data.bytes), data.length};
}
NSTextField* label(NSString* text, NSFont* font, NSColor* color) {
    NSTextField* view = [NSTextField wrappingLabelWithString:text];
    view.font = font;
    view.textColor = color;
    return view;
}
NSFont* serif(CGFloat size) {
    return [NSFont fontWithName:@"Baskerville" size:size] ?: [NSFont systemFontOfSize:size];
}
NSStackView* column(NSArray<NSView*>* views, CGFloat spacing) {
    NSStackView* stack = [NSStackView stackViewWithViews:views];
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = spacing;
    return stack;
}
void pin(NSView* child, NSView* parent, CGFloat margin) {
    child.translatesAutoresizingMaskIntoConstraints = NO;
    [parent addSubview:child];
    [NSLayoutConstraint activateConstraints:@[
        [child.leadingAnchor constraintEqualToAnchor:parent.leadingAnchor constant:margin],
        [child.trailingAnchor constraintEqualToAnchor:parent.trailingAnchor constant:-margin],
        [child.topAnchor constraintEqualToAnchor:parent.topAnchor constant:margin],
        [child.bottomAnchor constraintEqualToAnchor:parent.bottomAnchor constant:-margin]
    ]];
}
NSButton* button(NSString* title, NSString* symbol, id target, SEL action) {
    NSButton* view = [NSButton buttonWithTitle:title target:target action:action];
    view.bezelStyle = NSBezelStyleRounded;
    if (symbol) {
        view.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:title];
        view.imagePosition = NSImageLeading;
    }
    return view;
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

// Cover illustration is rasterized when invalidated; its layer is composited by Core Animation.
@interface NeonCover : NSButton
@property(nonatomic) NSString* bookTitle;
@property(nonatomic) NSString* author;
@property(nonatomic) NSInteger design;
@end
@implementation NeonCover
- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.wantsLayer = YES;
        self.layer.cornerRadius = 5;
        self.layer.masksToBounds = YES;
        self.bordered = NO;
    }
    return self;
}
- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    NSArray<NSColor*>* colors = @[
        [NSColor colorWithRed:0.13 green:0.25 blue:0.29 alpha:1],
        [NSColor colorWithRed:0.47 green:0.27 blue:0.20 alpha:1],
        [NSColor colorWithRed:0.31 green:0.32 blue:0.24 alpha:1]
    ];
    [colors[self.design % colors.count] setFill];
    NSRectFill(self.bounds);
    [[NSColor colorWithWhite:1 alpha:0.10] setFill];
    for (int i = 0; i < 7; ++i) {
        NSBezierPath* path =
            [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(-65 + i * 22, 30 + i * 9, 210, 145)];
        path.lineWidth = 1.4;
        [[NSColor colorWithWhite:1 alpha:0.17] setStroke];
        [path stroke];
    }
    [[NSColor colorWithWhite:0 alpha:0.14] setFill];
    NSRectFill(NSMakeRect(0, 0, 9, self.bounds.size.height));
    NSMutableParagraphStyle* style = [NSMutableParagraphStyle new];
    style.alignment = NSTextAlignmentLeft;
    [self.bookTitle drawInRect:NSMakeRect(25, 137, self.bounds.size.width - 44, 112)
                withAttributes:@{
                    NSFontAttributeName : serif(29),
                    NSForegroundColorAttributeName : NSColor.whiteColor,
                    NSParagraphStyleAttributeName : style
                }];
    [self.author.uppercaseString drawInRect:NSMakeRect(25, 25, self.bounds.size.width - 44, 20)
                             withAttributes:@{
                                 NSFontAttributeName : [NSFont systemFontOfSize:9
                                                                         weight:NSFontWeightMedium],
                                 NSKernAttributeName : @1.6,
                                 NSForegroundColorAttributeName : NSColor.whiteColor
                             }];
}
@end

@interface NeonApp
    : NSObject <NSApplicationDelegate, NSWindowDelegate, NSToolbarDelegate, NSTextViewDelegate> {
    std::unique_ptr<neon::core::LibraryRepository> repository_;
    std::unique_ptr<neon::core::Workspace> workspace_;
    std::string selectedBook_;
    std::string selectedChapter_;
}
@property(nonatomic) NSWindow* window;
@property(nonatomic) NSSplitViewController* split;
@property(nonatomic) NSViewController* sidebar;
@property(nonatomic) NSViewController* content;
@property(nonatomic) NSTextView* editor;
@property(nonatomic) NSTextField* status;
@property(nonatomic) NSTimer* saveTimer;
@property(nonatomic) BOOL loading;
@property(nonatomic) BOOL smoke;
@property(nonatomic) NSString* directory;
@end

@implementation NeonApp
- (void)applicationDidFinishLaunching:(NSNotification*)notification {
    (void)notification;
    NSArray<NSString*>* args = NSProcessInfo.processInfo.arguments;
    self.smoke = [args containsObject:@"--smoke-test"];
    self.directory =
        self.smoke ? [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]
                   : [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
                                                           NSUserDomainMask, YES) firstObject]
                         stringByAppendingPathComponent:@"Neon Native Prototype"];
    repository_ = neon::mac::makeRepository(utf8(self.directory));
    workspace_ = std::make_unique<neon::core::Workspace>(*repository_);
    auto opened = workspace_->open();
    if (!opened.ok) {
        [self showError:ns(opened.message)];
        [NSApp terminate:nil];
        return;
    }
    if (self.smoke) {
        workspace_->addBook(
            {"sea",
             "The Quiet Sea",
             "A. Writer",
             {{"arrival",
               "The arrival",
               "The sea was quiet that morning. Mara stood at the end of the pier, holding a "
               "letter she had promised never to open.\n\nBeyond the harbor, a single light moved "
               "through the fog. It had been there yesterday, too, and the day before.\n\nShe "
               "tucked the envelope into her coat and began to walk.",
               {}},
              {"tide",
               "Low tide",
               "By noon the water had drawn back from the old stone steps.",
               {}}}});
        workspace_->addBook(
            {"orchard", "The Orchard\nat Dusk", "A. Writer", {{"one", "Chapter one", "", {}}}});
        workspace_->addBook(
            {"letters", "Letters from\nElsewhere", "A. Writer", {{"one", "Chapter one", "", {}}}});
        workspace_->save();
    }
    self.window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 1180, 780)
                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                            NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                    backing:NSBackingStoreBuffered
                      defer:NO];
    self.window.title = @"Neon";
    self.window.subtitle = @"Native preview";
    self.window.minSize = NSMakeSize(860, 580);
    self.window.delegate = self;
    self.window.toolbarStyle = NSWindowToolbarStyleUnified;
    self.window.titlebarSeparatorStyle = NSTitlebarSeparatorStyleLine;
    NSToolbar* toolbar = [[NSToolbar alloc] initWithIdentifier:@"NeonToolbar"];
    toolbar.delegate = self;
    toolbar.displayMode = NSToolbarDisplayModeIconOnly;
    self.window.toolbar = toolbar;
    self.split = [NSSplitViewController new];
    self.sidebar = [NSViewController new];
    NSVisualEffectView* sidebar = [NSVisualEffectView new];
    sidebar.material = NSVisualEffectMaterialSidebar;
    sidebar.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    sidebar.state = NSVisualEffectStateFollowsWindowActiveState;
    sidebar.wantsLayer = YES;
    self.sidebar.view = sidebar;
    NSSplitViewItem* side = [NSSplitViewItem sidebarWithViewController:self.sidebar];
    side.minimumThickness = 195;
    side.maximumThickness = 250;
    [self.split addSplitViewItem:side];
    self.content = [NSViewController new];
    self.content.view = [NSView new];
    self.content.view.wantsLayer = YES;
    [self.split addSplitViewItem:[NSSplitViewItem splitViewItemWithViewController:self.content]];
    self.window.contentViewController = self.split;
    [self installMenu];
    [self showLibrary:nil];
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    if (self.smoke) {
        [self performSelector:@selector(captureLibrary) withObject:nil afterDelay:2];
    }
}
- (void)showError:(NSString*)message {
    if (self.smoke) {
        fprintf(stderr, "Neon native: %s\n", message.UTF8String);
        exit(2);
    }
    NSAlert* alert = [NSAlert new];
    alert.messageText = @"Your draft has not been discarded";
    alert.informativeText = message;
    [alert runModal];
}
- (void)installMenu {
    NSMenu* menu = [NSMenu new];
    NSMenuItem* appItem = [NSMenuItem new];
    NSMenu* appMenu = [[NSMenu alloc] initWithTitle:@"Neon"];
    [appMenu addItemWithTitle:@"About Neon" action:@selector(about:) keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:@"Quit Neon" action:@selector(terminate:) keyEquivalent:@"q"];
    appItem.submenu = appMenu;
    [menu addItem:appItem];
    NSMenuItem* fileItem = [[NSMenuItem alloc] initWithTitle:@"File" action:nil keyEquivalent:@""];
    NSMenu* file = [[NSMenu alloc] initWithTitle:@"File"];
    NSMenuItem* create = [file addItemWithTitle:@"New Book…"
                                         action:@selector(newBook:)
                                  keyEquivalent:@"n"];
    create.target = self;
    NSMenuItem* save = [file addItemWithTitle:@"Save"
                                       action:@selector(saveAction:)
                                keyEquivalent:@"s"];
    save.target = self;
    fileItem.submenu = file;
    [menu addItem:fileItem];
    NSMenuItem* editItem = [[NSMenuItem alloc] initWithTitle:@"Edit" action:nil keyEquivalent:@""];
    NSMenu* edit = [[NSMenu alloc] initWithTitle:@"Edit"];
    [edit addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
    NSMenuItem* redo = [edit addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"z"];
    redo.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    [edit addItem:[NSMenuItem separatorItem]];
    [edit addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [edit addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [edit addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [edit addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    editItem.submenu = edit;
    [menu addItem:editItem];
    NSMenuItem* formatItem = [[NSMenuItem alloc] initWithTitle:@"Format"
                                                        action:nil
                                                 keyEquivalent:@""];
    NSMenu* format = [[NSMenu alloc] initWithTitle:@"Format"];
    NSMenuItem* fonts = [format addItemWithTitle:@"Show Fonts"
                                          action:@selector(orderFrontFontPanel:)
                                   keyEquivalent:@"t"];
    fonts.target = NSFontManager.sharedFontManager;
    [format addItemWithTitle:@"Check Spelling" action:@selector(checkSpelling:) keyEquivalent:@";"];
    formatItem.submenu = format;
    [menu addItem:formatItem];
    NSApp.mainMenu = menu;
}
- (void)about:(id)sender {
    (void)sender;
    [NSApp orderFrontStandardAboutPanelWithOptions:@{
        NSAboutPanelOptionApplicationName : @"Neon — Native Prototype",
        NSAboutPanelOptionApplicationVersion : @"0.2 prototype",
        NSAboutPanelOptionCredits : [[NSAttributedString alloc]
            initWithString:@"Inspired by NEO, created by Hugh Howey.\nAn independent native "
                           @"implementation.\nC++23 core · AppKit UI · Core Animation\nFeature "
                           @"parity is not yet complete."]
    }];
}
- (NSArray<NSToolbarItemIdentifier>*)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar {
    (void)toolbar;
    return @[ @"library", NSToolbarFlexibleSpaceItemIdentifier, @"fonts", @"new" ];
}
- (NSArray<NSToolbarItemIdentifier>*)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar {
    return [self toolbarDefaultItemIdentifiers:toolbar];
}
- (NSToolbarItem*)toolbar:(NSToolbar*)toolbar
        itemForItemIdentifier:(NSToolbarItemIdentifier)identifier
    willBeInsertedIntoToolbar:(BOOL)flag {
    (void)toolbar;
    (void)flag;
    NSToolbarItem* item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
    item.target = self;
    if ([identifier isEqualToString:@"library"]) {
        item.label = @"Library";
        item.image = [NSImage imageWithSystemSymbolName:@"books.vertical"
                               accessibilityDescription:@"Library"];
        item.action = @selector(showLibrary:);
    } else if ([identifier isEqualToString:@"new"]) {
        item.label = @"New Book";
        item.image = [NSImage imageWithSystemSymbolName:@"square.and.pencil"
                               accessibilityDescription:@"New Book"];
        item.action = @selector(newBook:);
    } else {
        item.label = @"Typography";
        item.image = [NSImage imageWithSystemSymbolName:@"textformat"
                               accessibilityDescription:@"Typography"];
        item.target = NSFontManager.sharedFontManager;
        item.action = @selector(orderFrontFontPanel:);
    }
    item.toolTip = item.label;
    return item;
}
- (void)clearView:(NSView*)view {
    for (NSView* child in view.subviews.copy)
        [child removeFromSuperview];
}
- (const neon::core::Book*)currentBook {
    for (const auto& book : workspace_->library().books)
        if (book.id == selectedBook_)
            return &book;
    return nullptr;
}
- (void)buildSidebar {
    [self clearView:self.sidebar.view];
    NSMutableArray<NSView*>* views = [NSMutableArray array];
    [views addObject:label(@"NEON", [NSFont systemFontOfSize:11 weight:NSFontWeightBold],
                           NSColor.secondaryLabelColor)];
    [views addObject:button(@"All Books", @"books.vertical", self, @selector(showLibrary:))];
    const auto* book = [self currentBook];
    if (book) {
        [views
            addObject:label(@"MANUSCRIPT", [NSFont systemFontOfSize:10 weight:NSFontWeightSemibold],
                            NSColor.secondaryLabelColor)];
        NSInteger index = 0;
        for (const auto& chapter : book->chapters) {
            NSButton* row = button(ns(chapter.title), @"doc.text", self, @selector(selectChapter:));
            row.tag = index++;
            row.bezelStyle = NSBezelStyleRecessed;
            row.buttonType = NSButtonTypePushOnPushOff;
            row.state =
                chapter.id == selectedChapter_ ? NSControlStateValueOn : NSControlStateValueOff;
            row.alignment = NSTextAlignmentLeft;
            [views addObject:row];
        }
    } else {
        [views addObject:label(@"ON THIS MAC",
                               [NSFont systemFontOfSize:10 weight:NSFontWeightSemibold],
                               NSColor.secondaryLabelColor)];
        [views addObject:label([NSString stringWithFormat:@"%lu books",
                                                          workspace_->library().books.size()],
                               [NSFont systemFontOfSize:13], NSColor.secondaryLabelColor)];
        [views
            addObject:label(@"A quiet place\nfor your next story.", serif(22), NSColor.labelColor)];
    }
    NSStackView* stack = column(views, 20);
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.sidebar.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.sidebar.view.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:self.sidebar.view.trailingAnchor
                                             constant:-16],
        [stack.topAnchor constraintEqualToAnchor:self.sidebar.view.topAnchor constant:28]
    ]];
    NSTextField* credit = label(@"Inspired by Hugh Howey’s NEO", [NSFont systemFontOfSize:10],
                                NSColor.tertiaryLabelColor);
    credit.translatesAutoresizingMaskIntoConstraints = NO;
    [self.sidebar.view addSubview:credit];
    [NSLayoutConstraint activateConstraints:@[
        [credit.leadingAnchor constraintEqualToAnchor:self.sidebar.view.leadingAnchor constant:20],
        [credit.trailingAnchor constraintEqualToAnchor:self.sidebar.view.trailingAnchor
                                              constant:-16],
        [credit.bottomAnchor constraintEqualToAnchor:self.sidebar.view.bottomAnchor constant:-20]
    ]];
}
- (void)showLibrary:(id)sender {
    (void)sender;
    if (![self flush])
        return;
    self.editor = nil;
    selectedBook_.clear();
    selectedChapter_.clear();
    self.window.title = @"Neon";
    self.window.subtitle = @"Library";
    [self buildSidebar];
    [self clearView:self.content.view];
    NSScrollView* scroll = [NSScrollView new];
    scroll.hasVerticalScroller = YES;
    scroll.drawsBackground = NO;
    scroll.wantsLayer = YES;
    pin(scroll, self.content.view, 0);
    NSStackView* contents = column(
        @[
            label(@"YOUR LIBRARY", [NSFont systemFontOfSize:10 weight:NSFontWeightSemibold],
                  NSColor.secondaryLabelColor),
            label(@"Stories in the making.", serif(37), NSColor.labelColor),
            label(@"Pick up where you left off, or begin something new.",
                  [NSFont systemFontOfSize:13], NSColor.secondaryLabelColor)
        ],
        14);
    contents.edgeInsets = NSEdgeInsetsMake(38, 38, 38, 38);
    contents.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.documentView = contents;
    [contents.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor].active = YES;
    NSInteger index = 0;
    NSStackView* row = nil;
    for (const auto& book : workspace_->library().books) {
        if (index % 3 == 0) {
            row = [NSStackView stackViewWithViews:@[]];
            row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
            row.spacing = 26;
            row.alignment = NSLayoutAttributeTop;
            [contents addArrangedSubview:row];
            [contents setCustomSpacing:30 afterView:contents.arrangedSubviews[2]];
        }
        NeonCover* cover = [[NeonCover alloc] initWithFrame:NSMakeRect(0, 0, 192, 280)];
        cover.bookTitle = ns(book.title);
        cover.author = ns(book.author);
        cover.design = index;
        cover.target = self;
        cover.action = @selector(openBook:);
        cover.tag = index++;
        cover.accessibilityLabel = [@"Open " stringByAppendingString:ns(book.title)];
        [cover.widthAnchor constraintEqualToConstant:192].active = YES;
        [cover.heightAnchor constraintEqualToConstant:280].active = YES;
        NSUInteger count = 0;
        for (const auto& chapter : book.chapters)
            count += words(ns(chapter.text));
        NSStackView* card = column(
            @[
                cover, label([NSString stringWithFormat:@"%lu words  ·  Draft", count],
                             [NSFont systemFontOfSize:11], NSColor.secondaryLabelColor)
            ],
            12);
        [row addArrangedSubview:card];
    }
    [contents addArrangedSubview:button(@"New Book", @"plus", self, @selector(newBook:))];
}
- (void)openBook:(NSControl*)sender {
    if (![self flush])
        return;
    if (sender.tag < 0 ||
        static_cast<std::size_t>(sender.tag) >= workspace_->library().books.size())
        return;
    const auto& book = workspace_->library().books[sender.tag];
    selectedBook_ = book.id;
    selectedChapter_ = book.chapters.front().id;
    [self showEditor];
}
- (void)selectChapter:(NSControl*)sender {
    if (![self flush])
        return;
    const auto* book = [self currentBook];
    if (!book || sender.tag < 0 || static_cast<std::size_t>(sender.tag) >= book->chapters.size())
        return;
    selectedChapter_ = book->chapters[sender.tag].id;
    [self showEditor];
}
- (void)showEditor {
    self.loading = YES;
    self.editor = nil;
    [self clearView:self.content.view];
    const auto* book = [self currentBook];
    if (!book)
        return;
    const neon::core::Chapter* chapter = nullptr;
    for (const auto& item : book->chapters)
        if (item.id == selectedChapter_)
            chapter = &item;
    if (!chapter)
        return;
    self.window.title = ns(book->title);
    self.window.subtitle = @"Manuscript";
    [self buildSidebar];
    NSStackView* stack = column(
        @[
            label(@"MANUSCRIPT", [NSFont systemFontOfSize:10 weight:NSFontWeightSemibold],
                  NSColor.secondaryLabelColor),
            label(ns(chapter->title), serif(34), NSColor.labelColor)
        ],
        12);
    stack.edgeInsets = NSEdgeInsetsMake(30, 40, 16, 40);
    pin(stack, self.content.view, 0);
    NSScrollView* scroll = [NSScrollView new];
    scroll.hasVerticalScroller = YES;
    scroll.borderType = NSNoBorder;
    scroll.wantsLayer = YES;
    scroll.drawsBackground = YES;
    scroll.backgroundColor = NSColor.textBackgroundColor;
    self.editor = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 600, 400)];
    self.editor.minSize = NSMakeSize(0, 400);
    self.editor.maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
    self.editor.verticallyResizable = YES;
    self.editor.horizontallyResizable = NO;
    self.editor.autoresizingMask = NSViewWidthSizable;
    self.editor.textContainer.containerSize = NSMakeSize(600, CGFLOAT_MAX);
    self.editor.textContainer.widthTracksTextView = YES;
    self.editor.textContainerInset = NSMakeSize(24, 24);
    self.editor.wantsLayer = YES;
    self.editor.richText = YES;
    self.editor.importsGraphics = NO;
    self.editor.allowsUndo = YES;
    self.editor.usesFontPanel = YES;
    self.editor.automaticQuoteSubstitutionEnabled = YES;
    self.editor.automaticDashSubstitutionEnabled = YES;
    self.editor.continuousSpellCheckingEnabled = NO;
    self.editor.font = serif(20);
    self.editor.textColor = NSColor.textColor;
    self.editor.backgroundColor = NSColor.textBackgroundColor;
    NSMutableParagraphStyle* paragraph = [NSMutableParagraphStyle new];
    paragraph.lineSpacing = 5;
    paragraph.paragraphSpacing = 14;
    NSDictionary* attributes = @{
        NSFontAttributeName : serif(20),
        NSForegroundColorAttributeName : NSColor.textColor,
        NSParagraphStyleAttributeName : paragraph
    };
    NSAttributedString* text = nil;
    if (!chapter->richText.empty()) {
        NSData* rtf = [NSData dataWithBytes:chapter->richText.data()
                                     length:chapter->richText.size()];
        text = [[NSAttributedString alloc] initWithRTF:rtf documentAttributes:nil];
    }
    if (!text)
        text = [[NSAttributedString alloc] initWithString:ns(chapter->text) attributes:attributes];
    [self.editor.textStorage setAttributedString:text];
    self.editor.typingAttributes = attributes;
    self.editor.delegate = self;
    scroll.documentView = self.editor;
    [stack addArrangedSubview:scroll];
    [scroll.widthAnchor constraintEqualToAnchor:stack.widthAnchor constant:-80].active = YES;
    [scroll.heightAnchor constraintGreaterThanOrEqualToConstant:200].active = YES;
    [scroll setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationVertical];
    self.status =
        label(@"Saved on this Mac", [NSFont systemFontOfSize:11], NSColor.secondaryLabelColor);
    [stack addArrangedSubview:self.status];
    self.loading = NO;
    [self.window makeFirstResponder:self.editor];
}
- (void)textDidChange:(NSNotification*)notification {
    (void)notification;
    if (self.loading)
        return;
    [self captureDraft];
    self.status.stringValue =
        [NSString stringWithFormat:@"%lu words  ·  Unsaved changes", words(self.editor.string)];
    [self.saveTimer invalidate];
    self.saveTimer = [NSTimer scheduledTimerWithTimeInterval:0.7
                                                      target:self
                                                    selector:@selector(saveAction:)
                                                    userInfo:nil
                                                     repeats:NO];
}
- (void)captureDraft {
    if (!self.editor || selectedBook_.empty())
        return;
    const auto* book = [self currentBook];
    if (!book)
        return;
    for (const auto& existing : book->chapters) {
        if (existing.id != selectedChapter_)
            continue;
        auto chapter = existing;
        chapter.text = utf8(self.editor.string);
        NSData* rtf = [self.editor RTFFromRange:NSMakeRange(0, self.editor.string.length)];
        if (!rtf) {
            [self showError:@"Could not encode rich text. Keep this window open."];
            return;
        }
        const auto* bytes = static_cast<const std::uint8_t*>(rtf.bytes);
        chapter.richText.assign(bytes, bytes + rtf.length);
        workspace_->updateChapter(selectedBook_, chapter);
        return;
    }
}
- (BOOL)flush {
    [self.saveTimer invalidate];
    auto result = workspace_->save();
    if (!result.ok) {
        self.status.stringValue = @"Save failed — draft retained";
        [self showError:ns(result.message)];
        return NO;
    }
    if (self.editor)
        self.status.stringValue = [NSString
            stringWithFormat:@"%lu words  ·  Saved on this Mac", words(self.editor.string)];
    return YES;
}
- (void)saveAction:(id)sender {
    (void)sender;
    [self captureDraft];
    [self flush];
}
- (BOOL)windowShouldClose:(NSWindow*)sender {
    (void)sender;
    [self captureDraft];
    return [self flush];
}
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication*)sender {
    (void)sender;
    [self captureDraft];
    return [self flush] ? NSTerminateNow : NSTerminateCancel;
}
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender {
    (void)sender;
    return YES;
}
- (void)newBook:(id)sender {
    (void)sender;
    if (![self flush])
        return;
    NSAlert* alert = [NSAlert new];
    alert.messageText = @"Begin a new story";
    alert.informativeText = @"Give it a working title. You can shape the story as you go.";
    NSTextField* title = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 26)];
    title.placeholderString = @"Untitled";
    alert.accessoryView = title;
    [alert addButtonWithTitle:@"Create Book"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] != NSAlertFirstButtonReturn)
        return;
    neon::core::Book book{utf8(NSUUID.UUID.UUIDString),
                          utf8(title.stringValue.length ? title.stringValue : @"Untitled"),
                          "",
                          {{utf8(NSUUID.UUID.UUIDString), "Chapter one", "", {}}}};
    auto result = workspace_->addBook(book);
    if (!result.ok) {
        [self showError:ns(result.message)];
        return;
    }
    selectedBook_ = book.id;
    selectedChapter_ = book.chapters[0].id;
    if ([self flush])
        [self showEditor];
}
- (void)capture:(NSString*)filename {
    NSTask* task = [NSTask new];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/sbin/screencapture"];
    task.arguments = @[ @"-x", filename ];
    NSError* error = nil;
    if (![task launchAndReturnError:&error])
        [self showError:error.localizedDescription];
    [task waitUntilExit];
    if (task.terminationStatus != 0)
        exit(3);
}
- (void)captureLibrary {
    [self capture:@"native-bookshelf.png"];
    NSButton* selection = [NSButton new];
    selection.tag = 0;
    [self openBook:selection];
    [self performSelector:@selector(captureEditor) withObject:nil afterDelay:1];
}
- (void)captureEditor {
    [self capture:@"native-editor.png"];
    // Exercise the real AppKit editor -> C++ command -> repository -> reopen path.
    [self.editor setSelectedRange:NSMakeRange(self.editor.string.length, 0)];
    [self.editor insertText:@"\n\nA new beginning." replacementRange:self.editor.selectedRange];
    [self saveAction:nil];
    auto reopenedRepository = neon::mac::makeRepository(utf8(self.directory));
    neon::core::Workspace reopened(*reopenedRepository);
    if (!reopened.open().ok ||
        reopened.library().books[0].chapters[0].text.find("A new beginning.") ==
            std::string::npos ||
        reopened.library().books[0].chapters[0].richText.empty())
        exit(4);
    printf("Native editor persistence smoke passed\n");
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
