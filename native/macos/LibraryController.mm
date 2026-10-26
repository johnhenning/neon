#include "LibraryController.h"
#import "Controls.h"
#import <QuartzCore/QuartzCore.h>
@interface NeonLibraryCanvas : NSView
@property(nonatomic, copy) void (^resized)(void);
@property(nonatomic) BOOL panel;
@end
@implementation NeonLibraryCanvas
- (instancetype)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.wantsLayer = YES;
        self.layer.masksToBounds = YES;
    }
    return self;
}
- (BOOL)wantsDefaultClipping {
    return YES;
}
- (BOOL)isFlipped {
    return YES;
}
- (void)setFrameSize:(NSSize)size {
    [super setFrameSize:size];
    if (self.resized)
        self.resized();
}
- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    if (self.resized)
        self.resized();
}
- (void)drawRect:(NSRect)rect {
    [NSGraphicsContext saveGraphicsState];
    NSRectClip(self.bounds);
    [(self.panel ? NeonPanel() : NeonPaper()) setFill];
    NSRectFill(NSIntersectionRect(rect, self.bounds));
    [NSGraphicsContext restoreGraphicsState];
}
@end
@interface NeonLibraryButton : NeonButton
@property(nonatomic, copy) void (^clicked)(void);
@property(nonatomic) BOOL plain;
@property(nonatomic) BOOL navigationRow;
@property(nonatomic) BOOL paperCommand;
@end
@implementation NeonLibraryButton
- (instancetype)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.target = self;
        self.action = @selector(invoke:);
    }
    return self;
}
- (void)drawRect:(NSRect)rect {
    if (self.paperCommand) {
        NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:self.bounds
                                                             xRadius:NeonControlRadius
                                                             yRadius:NeonControlRadius];
        if (self.paperCommand) {
            [NeonPaper() setFill];
            [path fill];
        }
        if (self.window.firstResponder == self) {
            [NeonInk() setStroke];
            path.lineWidth = 2;
            [path stroke];
        }
        self.alphaValue = !self.enabled ? .65 : self.highlighted ? .75 : 1;
        NSDictionary* attributes = @{
            NSFontAttributeName : NeonUI(14),
            NSForegroundColorAttributeName : self.enabled ? NeonInk() : NeonMuted()
        };
        NSSize size = [self.title sizeWithAttributes:attributes];
        [self.title drawAtPoint:NSMakePoint((self.bounds.size.width - size.width) / 2,
                                            (self.bounds.size.height - size.height) / 2)
                 withAttributes:attributes];
        return;
    }
    if (self.navigationRow) {
        [(self.chosen ? NeonSelection() : NeonPanel()) setFill];
        NSRectFill(self.bounds);
        if (self.chosen) {
            [NeonAccent() setStroke];
            [[NSBezierPath bezierPathWithRect:NSInsetRect(self.bounds, .5, .5)] stroke];
        }
        NSImage* original = self.image;
        NSImage* tinted = [NSImage imageWithSize:NSMakeSize(20, 20)
                                         flipped:NO
                                  drawingHandler:^BOOL(NSRect dst) {
                                    [original drawInRect:dst];
                                    [NeonMuted() setFill];
                                    NSRectFillUsingOperation(dst, NSCompositingOperationSourceIn);
                                    return YES;
                                  }];
        [tinted drawInRect:NSMakeRect(16, 14, 20, 20)];
        [self.title drawInRect:NSMakeRect(44, 14, self.bounds.size.width - 60, 24)
                withAttributes:@{
                    NSFontAttributeName : NeonUI(14),
                    NSForegroundColorAttributeName : self.enabled ? NeonInk() : NeonMuted()
                }];
        return;
    }
    if (!self.plain) {
        [super drawRect:rect];
        return;
    }
    if (self.window.firstResponder == self) {
        [NeonAccent() setStroke];
        [[NSBezierPath bezierPathWithRect:NSInsetRect(self.bounds, 1, 1)] stroke];
    }
    NSMutableParagraphStyle* style = [NSMutableParagraphStyle new];
    style.lineBreakMode = NSLineBreakByTruncatingTail;
    style.alignment = self.alignment;
    [self.title drawInRect:NSInsetRect(self.bounds, 0, 1)
            withAttributes:@{
                NSFontAttributeName : self.font ?: NeonUI(14),
                NSForegroundColorAttributeName : NeonInk(),
                NSParagraphStyleAttributeName : style
            }];
}
- (void)invoke:(id)sender {
    (void)sender;
    if (self.clicked)
        self.clicked();
}
@end
@interface NeonLibraryCover : NSView
@property(nonatomic) NSImage* image;
@end
@implementation NeonLibraryCover
- (BOOL)isFlipped {
    return YES;
}
- (void)drawRect:(NSRect)rect {
    (void)rect;
    [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:8 yRadius:8] addClip];
    [NeonPanel() setFill];
    NSRectFill(self.bounds);
    if (self.image && self.image.size.width > 0 && self.image.size.height > 0) {
        CGFloat s = MAX(self.bounds.size.width / self.image.size.width,
                        self.bounds.size.height / self.image.size.height);
        NSSize size = NSMakeSize(self.image.size.width * s, self.image.size.height * s);
        [self.image drawInRect:NSMakeRect((self.bounds.size.width - size.width) / 2,
                                          (self.bounds.size.height - size.height) / 2, size.width,
                                          size.height)
                      fromRect:NSZeroRect
                     operation:NSCompositingOperationSourceOver
                      fraction:1
                respectFlipped:YES
                         hints:nil];
    } else
        [[NSImage imageWithSystemSymbolName:@"book.closed" accessibilityDescription:nil]
            drawInRect:NSMakeRect((self.bounds.size.width - 28) / 2,
                                  (self.bounds.size.height - 32) / 2, 28, 32)];
}
@end
namespace {
NSTextField* label(NSView* parent, NSString* value, NSFont* font, NSColor* color, NSRect frame) {
    NSTextField* f = [NSTextField wrappingLabelWithString:value ?: @""];
    f.font = font;
    f.textColor = color;
    frame.origin.x -= 2;
    frame.size.width += 4;
    f.frame = frame;
    [parent addSubview:f];
    return f;
}
NeonLibraryButton* button(NSView* parent, NSString* title, NSRect frame, void (^block)(void)) {
    NeonLibraryButton* b = [[NeonLibraryButton alloc] initWithFrame:frame];
    b.title = title;
    b.kind = NeonButtonSecondary;
    b.compact = frame.size.height == NeonCompactControlHeight;
    b.clicked = block;
    [parent addSubview:b];
    return b;
}
} // namespace
@interface NeonLibraryController ()
@property(nonatomic) NeonLibraryQuery* query;
@property(nonatomic) NeonLibraryPresentation* presentation;
@property(nonatomic) NSView* sidebarView;
@property(nonatomic) NSArray<NSDictionary*>* source;
@property(nonatomic) NSError* sourceError;
@property(nonatomic) NSScrollView* scroll;
@property(nonatomic) NeonLibraryCanvas* content;
@property(nonatomic) NSView* footer;
@end
@implementation NeonLibraryController
- (instancetype)init {
    if ((self = [super init])) {
        _query = [NeonLibraryQuery new];
        _fixtureIDs = @{};
    }
    return self;
}
- (void)loadView {
    NeonLibraryCanvas* root = [[NeonLibraryCanvas alloc] initWithFrame:NSMakeRect(0, 0, 952, 796)];
    self.view = root;
    self.scroll = [NSScrollView new];
    self.scroll.hasVerticalScroller = YES;
    self.scroll.drawsBackground = NO;
    self.content = [NeonLibraryCanvas new];
    self.scroll.documentView = self.content;
    [root addSubview:self.scroll];
    self.footer = [NeonLibraryCanvas new];
    ((NeonLibraryCanvas*)self.footer).panel = YES;
    [root addSubview:self.footer];
    self.sidebarView = [[NeonLibraryCanvas alloc] initWithFrame:NSMakeRect(0, 0, 248, 796)];
    __weak NeonLibraryController* weak = self;
    root.resized = ^{
      [weak render];
    };
    ((NeonLibraryCanvas*)self.sidebarView).panel = YES;
    ((NeonLibraryCanvas*)self.sidebarView).resized = ^{
      [weak renderSidebar];
    };
    [self render];
}
- (NSView*)sidebarView {
    if (!_sidebarView)
        [self view];
    return _sidebarView;
}
- (void)send:(NSString*)name record:(NSDictionary*)record {
    if (record)
        self.selectedProjectID = record[@"projectID"];
    if (self.onAction)
        self.onAction(name, record);
}
- (void)updateWithRecords:(NSArray<NSDictionary*>*)records error:(NSError*)error {
    self.source = records;
    self.sourceError = error;
    [self view];
    [self render];
}
- (void)selectFilter:(NeonLibraryFilter)filter {
    self.query.filter = filter;
    if (self.onFilterChanged)
        self.onFilterChanged(filter);
    else
        [self render];
}
- (void)setLibraryView:(NeonLibraryView)view {
    self.query.view = view;
    [self.query savePreferences];
    [self render];
}
- (void)menuAction:(NSMenuItem*)item {
    [self send:item.representedObject[@"action"] record:item.representedObject[@"record"]];
}
- (NSMenu*)menu:(NSDictionary*)record {
    NSMenu* menu = [NSMenu new];
    BOOL trash = [record[@"trashed"] boolValue];
    NSArray* names = trash ? @[ @"Restore", @"Delete permanently" ] : @[
        @"Open", @"Rename", @"Duplicate",
        [record[@"favorite"] boolValue] ? @"Remove favorite" : @"Favorite", @"Show in Finder",
        @"Move to Trash"
    ];
    NSArray* keys = trash ? @[ @"restore", @"delete" ]
                          : @[ @"open", @"rename", @"duplicate", @"favorite", @"reveal", @"trash" ];
    for (NSUInteger i = 0; i < names.count; i++) {
        NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:names[i]
                                                      action:@selector(menuAction:)
                                               keyEquivalent:@""];
        item.target = self;
        item.representedObject = @{@"action" : keys[i], @"record" : record};
        [menu addItem:item];
    }
    return menu;
}
- (void)render {
    if (!self.content)
        return;
    self.presentation = [[NeonLibraryPresentation alloc] initWithRecords:self.source
                                                                   error:self.sourceError
                                                                   query:self.query
                                                       selectedProjectID:self.selectedProjectID
                                                                     now:[NSDate date]];
    self.selectedProjectID = self.presentation.selectedProjectID;
    CGFloat w = self.view.bounds.size.width, h = self.view.bounds.size.height,
            m = MIN(820, MAX(240, w - 40)), x = (w - m) / 2;
    self.scroll.frame = NSMakeRect(0, 0, w, MAX(0, h - 40));
    self.footer.frame = NSMakeRect(0, h - 40, w, 40);
    for (NSView* v in self.content.subviews.copy)
        [v removeFromSuperview];
    for (NSView* v in self.footer.subviews.copy)
        [v removeFromSuperview];
    label(self.content, @"Library", NeonSerif(32), NeonInk(), NSMakeRect(x, 24, m, 46));
    label(self.content, @"A place for your next idea.", NeonUI(14), NeonMuted(),
          NSMakeRect(x, 86, m, 28));
    __weak NeonLibraryController* weak = self;
    button(self.content, self.query.view == NeonLibraryGrid ? @"List view" : @"Grid view",
           NSMakeRect(x + m - 196, 138, 87, 28),
           ^{
             [weak setLibraryView:weak.query.view == NeonLibraryGrid ? NeonLibraryList
                                                                     : NeonLibraryGrid];
           })
        .kind = NeonButtonQuiet;
    NeonLibraryButton* create =
        button(self.content, @"New project", NSMakeRect(x + m - 101, 138, 101, 28), ^{
          [weak send:@"new" record:nil];
        });
    create.kind = NeonButtonPrimary;
    create.compact = YES;
    CGFloat y = 190;
    if (self.presentation.error) {
        label(self.content, @"Unable to load projects", NeonSerif(24), NeonInk(),
              NSMakeRect(x, y, m, 40));
        label(self.content, self.presentation.error.localizedDescription, NeonUI(14), NeonMuted(),
              NSMakeRect(x, y + 48, m, 80));
        y += 144;
    } else if (!self.presentation.records.count) {
        BOOL welcome = self.source.count == 0 && (self.query.filter == NeonLibraryAll ||
                                                  self.query.filter == NeonLibraryDevice);
        label(self.content, welcome ? @"Begin anywhere." : @"No projects here yet.", NeonSerif(32),
              NeonInk(), NSMakeRect(x + 24, y + 24, m - 48, 52));
        if (welcome) {
            label(self.content,
                  @"A book, a paper, a letter. Choose a starting point and make it yours.",
                  NeonSerif(20), NeonMuted(), NSMakeRect(x + 24, y + 100, m - 48, 110));
            button(self.content, @"Create a project", NSMakeRect(x + 24, y + 234, 240, 44), ^{
              [weak send:@"new" record:nil];
            }).kind = NeonButtonPrimary;
            NeonLibraryButton* b =
                button(self.content, @"Import a document", NSMakeRect(x + 24, y + 302, 240, 44),
                       ^{
                       });
            b.enabled = NO;
            b.toolTip = @"Document import is not available yet";
            label(self.content, @"No account needed. Your work stays on your device.", NeonUI(13),
                  NeonMuted(), NSMakeRect(x + 24, y + 370, m - 48, 40));
        }
        y += 440;
    } else {
        NSInteger columns = m >= 700 ? 3 : 2;
        CGFloat tile = (m - 24 * (columns - 1)) / columns;
        NSUInteger i = 0;
        for (NSDictionary* r in self.presentation.records) {
            BOOL list = self.query.view == NeonLibraryList;
            CGFloat ry = y + (list ? i * 144 : (i / columns) * (tile * 1.46 + 86)),
                    rx = list ? x : x + (i % columns) * (tile + 24), cw = list ? 70 : tile,
                    ch = list ? 104 : tile * 1.46;
            if (list) {
                NSView* panel = [[NSView alloc] initWithFrame:NSMakeRect(rx, ry, m, 128)];
                panel.wantsLayer = YES;
                panel.layer.backgroundColor = NeonPanel().CGColor;
                panel.layer.cornerRadius = 12;
                [self.content addSubview:panel];
                rx += 12;
                ry += 12;
            }
            NeonLibraryCover* cover =
                [[NeonLibraryCover alloc] initWithFrame:NSMakeRect(rx, ry, cw, ch)];
            NSString* fixture = self.fixtureIDs[r[@"projectID"]] ?: r[@"fixtureID"];
            NSString* stem = fixture ? [NeonLibraryPresentation artworkForFixtureID:fixture] : nil;
            NSString* path = stem ? [[NSBundle mainBundle] pathForResource:stem
                                                                    ofType:@"png"
                                                               inDirectory:@"artwork"]
                                  : nil;
            cover.image = path ? [[NSImage alloc] initWithContentsOfFile:path] : nil;
            [self.content addSubview:cover];
            NeonLibraryButton* open = button(self.content, @"", cover.frame, ^{
              [weak send:@"open" record:r];
            });
            open.plain = YES;
            [open setAccessibilityLabel:[@"Open "
                                            stringByAppendingString:r[@"title"] ?: @"Untitled"]];
            open.menu = [self menu:r];
            CGFloat tx = list ? rx + 86 : rx, ty = list ? ry : ry + ch + 8,
                    tw = list ? m - 110 : tile;
            NeonLibraryButton* title =
                button(self.content, r[@"title"] ?: @"Untitled",
                       NSMakeRect(tx, ty, list ? tw : MAX(0, tw - 40), list ? 34 : 24), ^{
                         [weak send:@"open" record:r];
                       });
            title.plain = YES;
            title.font = list ? NeonSerif(24) : NeonUI(16);
            title.alignment = NSTextAlignmentLeft;
            title.menu = [self menu:r];
            NSDate* date = r[@"modified"];
            NSString* edited =
                [date isKindOfClass:[NSDate class]]
                    ? [NSDateFormatter localizedStringFromDate:date
                                                     dateStyle:NSDateFormatterMediumStyle
                                                     timeStyle:NSDateFormatterNoStyle]
                    : @"Unknown date";
            label(self.content,
                  [r[@"error"] length] > 0
                      ? @"Unable to read project"
                      : [NSString stringWithFormat:@"%@ · %@", r[@"preset"] ?: @"Project", edited],
                  NeonUI(13), NeonMuted(),
                  NSMakeRect(tx, ty + (list ? 42 : 32), tw, list ? 20 : 24));
            NeonLibraryButton* more =
                button(self.content, @"•••",
                       NSMakeRect(list ? tx + 110 : tx + tw - 32, list ? ty + 64 : ty, 32, 24), ^{
                         [[weak menu:r] popUpMenuPositioningItem:nil
                                                      atLocation:NSMakePoint(tx, ty + 24)
                                                          inView:weak.content];
                       });
            more.plain = YES;
            [more setAccessibilityLabel:[@"Actions for "
                                            stringByAppendingString:r[@"title"] ?: @"Untitled"]];
            if (list)
                label(self.content, @"On this device", NeonUI(13), NeonMuted(),
                      NSMakeRect(tx, ty + 70, 110, 18));
            i++;
        }
        y += self.query.view == NeonLibraryList
                 ? i * 144
                 : ((i + columns - 1) / columns) * (tile * 1.46 + 86);
    }
    self.content.frame = NSMakeRect(0, 0, w, MAX(h - 40, y + 32));
    NSString* count =
        self.presentation.error
            ? @"Projects unavailable"
            : [NSString
                  stringWithFormat:@"%@ %@ · On this device", @(self.presentation.records.count),
                                   self.presentation.records.count == 1 ? @"project" : @"projects"];
    NSTextField* countLabel =
        label(self.footer, count, NeonUI(13), NeonMuted(), NSMakeRect(12, 12, MAX(0, w - 130), 18));
    countLabel.accessibilityIdentifier =
        [NSString stringWithFormat:@"library-project-count-%lu", self.presentation.records.count];
    label(self.footer, @"Local first", NeonUI(13), NeonMuted(), NSMakeRect(w - 100, 12, 88, 18));
    [self renderSidebar];
}
- (void)navigationAction:(NSMenuItem*)sender {
    NSDictionary* value = sender.representedObject;
    if (value[@"filter"])
        [self selectFilter:(NeonLibraryFilter)[value[@"filter"] integerValue]];
    else if (value[@"sort"]) {
        self.query.sort = (NeonLibrarySort)[value[@"sort"] integerValue];
        [self.query savePreferences];
        [self render];
    } else if (value[@"view"])
        [self
            setLibraryView:self.query.view == NeonLibraryGrid ? NeonLibraryList : NeonLibraryGrid];
    else
        [self send:@"settings" record:nil];
}
- (NSMenu*)navigationMenu {
    NSMenu* menu = [NSMenu new];
    NSArray* names = @[ @"All projects", @"Recent", @"Favorites", @"On this device", @"Trash" ];
    for (NSInteger i = 0; i < 5; i++) {
        NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:names[i]
                                                      action:@selector(navigationAction:)
                                               keyEquivalent:@""];
        item.target = self;
        item.representedObject = @{@"filter" : @(i)};
        item.state = self.query.filter == i ? NSControlStateValueOn : NSControlStateValueOff;
        [menu addItem:item];
    }
    NSArray* sorts = @[ @"Date modified", @"Title", @"Last opened" ];
    for (NSInteger i = 0; i < 3; i++) {
        NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:sorts[i]
                                                      action:@selector(navigationAction:)
                                               keyEquivalent:@""];
        item.target = self;
        item.representedObject = @{@"sort" : @(i)};
        item.state = self.query.sort == i ? NSControlStateValueOn : NSControlStateValueOff;
        [menu addItem:item];
    }
    NSMenuItem* view = [[NSMenuItem alloc]
        initWithTitle:self.query.view == NeonLibraryGrid ? @"List view" : @"Grid view"
               action:@selector(navigationAction:)
        keyEquivalent:@""];
    view.target = self;
    view.representedObject = @{@"view" : @YES};
    [menu addItem:view];
    NSMenuItem* settings = [[NSMenuItem alloc] initWithTitle:@"Settings"
                                                      action:@selector(navigationAction:)
                                               keyEquivalent:@""];
    settings.target = self;
    settings.representedObject = @{};
    [menu addItem:settings];
    return menu;
}
- (void)renderSidebar {
    CGFloat width = self.sidebarView.bounds.size.width;
    for (NSView* v in self.sidebarView.subviews.copy)
        [v removeFromSuperview];
    label(self.sidebarView, @"Neon", NeonSerif(24), NeonInk(),
          NSMakeRect(20, 20, MAX(0, width - 40), 34));
    label(self.sidebarView, @"Your writing, in one place", NeonUI(13), NeonMuted(),
          NSMakeRect(20, 58, MAX(0, width - 40), 18));
    NSArray* names =
        @[ @"All projects", @"Recent", @"Favorites", @"On this device", @"iCloud Drive", @"Trash" ];
    __weak NeonLibraryController* weak = self;
    for (NSInteger i = 0; i < 6; i++) {
        NSInteger filter = i == 5 ? NeonLibraryTrash : i;
        NeonLibraryButton* row =
            button(self.sidebarView, names[i], NSMakeRect(0, 98 + i * 48, width, 48), ^{
              [weak selectFilter:(NeonLibraryFilter)filter];
            });
        row.navigationRow = YES;
        NSString* icon = @[ @"library", @"recent", @"favorites", @"device", @"cloud", @"trash" ][i];
        NSURL* url = [NSBundle.mainBundle URLForResource:icon
                                           withExtension:@"png"
                                            subdirectory:@"icons"];
        row.image = url ? [[NSImage alloc] initWithContentsOfURL:url] : nil;
        row.accessibilityLabel = names[i];
        row.chosen = i != 4 && self.query.filter == filter;
        row.enabled = i != 4;
        if (i == 4)
            row.toolTip = @"iCloud Drive is not available yet";
        row.kind = NeonButtonSelection;
        row.alignment = NSTextAlignmentLeft;
    }
    button(
        self.sidebarView, @"Settings",
        NSMakeRect(16, MAX(402, self.sidebarView.bounds.size.height - 60), MAX(0, width - 32), 44),
        ^{
          [weak send:@"settings" record:nil];
        })
        .paperCommand = YES;
}
@end
