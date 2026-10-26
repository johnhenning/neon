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
@property(nonatomic) BOOL settingsCommand;
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
        [NeonPanel() setFill];
        NSRectFill(self.bounds);
        NeonDrawSidebarRow(self, self.chosen, self.hovered);
        [self.title drawInRect:NSMakeRect(20, 12, self.bounds.size.width - 40, 22)
                withAttributes:@{
                    NSFontAttributeName : self.settingsCommand ? NeonUI(15)
                    : self.chosen                              ? NeonUISemibold(14)
                                                               : NeonUI(14),
                    NSForegroundColorAttributeName : !self.enabled ? NeonMuted()
                    : self.chosen                                  ? NeonAccent()
                                                                   : NeonInk()
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
@property(nonatomic, copy) NSString* glyph;
@end
@implementation NeonLibraryCover
- (BOOL)isFlipped {
    return YES;
}
- (void)drawRect:(NSRect)rect {
    (void)rect;
    [NSBezierPath clipRect:self.bounds];
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
    } else {
        NSDictionary* attributes =
            @{NSFontAttributeName : NeonSerif(28), NSForegroundColorAttributeName : NeonAccent()};
        NSString* glyph = self.glyph ?: @"";
        NSSize size = [glyph sizeWithAttributes:attributes];
        [glyph drawAtPoint:NSMakePoint((self.bounds.size.width - size.width) / 2,
                                       (self.bounds.size.height - size.height) / 2)
            withAttributes:attributes];
    }
    [NeonLine() setStroke];
    [[NSBezierPath bezierPathWithRect:NSInsetRect(self.bounds, 0.5, 0.5)] stroke];
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
    b.textSize = 15;
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
@property(nonatomic) BOOL showsFooter;
@end
@implementation NeonLibraryController
- (instancetype)init {
    if ((self = [super init])) {
        _query = [NeonLibraryQuery new];
        _fixtureIDs = @{};
        _showsFooter = YES;
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
    self.sidebarView = [[NeonLibraryCanvas alloc] initWithFrame:NSMakeRect(0, 0, 210, 796)];
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
    CGFloat w = self.view.bounds.size.width, h = self.view.bounds.size.height;
    BOOL compact = self.view.window.contentView.bounds.size.width <= 850;
    CGFloat x = compact ? 28 : 32, m = MAX(240, w - 2 * x);
    CGFloat footerHeight = self.showsFooter ? 36.5 : 0;
    self.footer.hidden = !self.showsFooter;
    self.scroll.frame = NSMakeRect(0, 0, w, MAX(0, h - footerHeight));
    self.footer.frame = NSMakeRect(0, h - footerHeight, w, footerHeight);
    for (NSView* v in self.content.subviews.copy)
        [v removeFromSuperview];
    for (NSView* v in self.footer.subviews.copy)
        [v removeFromSuperview];
    label(self.content, @"Library", NeonSerif(32), NeonInk(), NSMakeRect(x, x, m - 220, 47.5));
    label(self.content, @"A place for your next idea.", NeonUI(15), NeonMuted(),
          NSMakeRect(x, x + 55.5, m, 21.5));
    __weak NeonLibraryController* weak = self;
    button(self.content, self.query.view == NeonLibraryGrid ? @"List view" : @"Grid view",
           NSMakeRect(x + m - 191.4609375, x + 18.75, 78.0390625, 39.5),
           ^{
             [weak setLibraryView:weak.query.view == NeonLibraryGrid ? NeonLibraryList
                                                                     : NeonLibraryGrid];
           })
        .kind = NeonButtonQuiet;
    NeonLibraryButton* create =
        button(self.content, @"New project",
               NSMakeRect(x + m - 107.421875, x + 19.75, 107.421875, 37.5), ^{
                 [weak send:@"new" record:nil];
               });
    create.kind = NeonButtonPrimary;
    create.compact = NO;
    create.font = NeonUI(15);
    CGFloat y = x + 105;
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
        NSInteger columns = compact ? 2 : 3;
        CGFloat tile = (m - 22 * (columns - 1)) / columns;
        NSUInteger i = 0;
        for (NSDictionary* r in self.presentation.records) {
            BOOL list = self.query.view == NeonLibraryList;
            CGFloat ry = y + (list ? i * 146.5 : (i / columns) * 301.5),
                    rx = list ? x : x + (i % columns) * (tile + 22), cw = list ? m : tile,
                    ch = list ? 65 : 220;
            NeonLibraryCover* cover =
                [[NeonLibraryCover alloc] initWithFrame:NSMakeRect(rx, ry, cw, ch)];
            NSString* titleText = r[@"title"] ?: @"";
            cover.glyph = [titleText isEqual:@"The Quiet Sea"] ? @"≈"
                          : titleText.length                   ? [titleText substringToIndex:1]
                                                               : @"";
            [self.content addSubview:cover];
            NeonLibraryButton* open = button(self.content, @"", cover.frame, ^{
              [weak send:@"open" record:r];
            });
            open.plain = YES;
            [open setAccessibilityLabel:[@"Open "
                                            stringByAppendingString:r[@"title"] ?: @"Untitled"]];
            open.menu = [self menu:r];
            CGFloat tx = rx, ty = ry + ch + 13, tw = list ? m : tile;
            NeonLibraryButton* title =
                button(self.content, r[@"title"] ?: @"Untitled", NSMakeRect(tx, ty, tw, 25), ^{
                  [weak send:@"open" record:r];
                });
            title.plain = YES;
            title.font = NeonSerif(17);
            title.alignment = NSTextAlignmentLeft;
            title.menu = [self menu:r];
            NSDate* date = r[@"modified"];
            NSString* edited =
                [date isKindOfClass:[NSDate class]]
                    ? [NSDateFormatter localizedStringFromDate:date
                                                     dateStyle:NSDateFormatterMediumStyle
                                                     timeStyle:NSDateFormatterNoStyle]
                    : @"Unknown date";
            if ([date isKindOfClass:NSDate.class]) {
                if ([NSCalendar.currentCalendar isDateInToday:date])
                    edited = @"Edited today";
                else if ([NSCalendar.currentCalendar isDateInYesterday:date])
                    edited = @"Edited yesterday";
                else
                    edited = [@"Edited " stringByAppendingString:edited];
            }
            label(self.content,
                  [r[@"error"] length] > 0
                      ? @"Unable to read project"
                      : [NSString stringWithFormat:@"%@ · %@", r[@"preset"] ?: @"Project", edited],
                  NeonUI(12.5), NeonMuted(), NSMakeRect(tx, ty + 27.5, tw, 18));
            i++;
        }
        y += self.query.view == NeonLibraryList ? i * 146.5 : ((i + columns - 1) / columns) * 301.5;
    }
    self.content.frame = NSMakeRect(0, 0, w, MAX(h - footerHeight, y + 32));
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
    label(self.sidebarView, @"Neon", NeonUISemibold(16), NeonInk(),
          NSMakeRect(20, 24, MAX(0, width - 40), 22));
    label(self.sidebarView, @"Your writing, in one place", NeonUI(12), NeonMuted(),
          NSMakeRect(20, 52, MAX(0, width - 40), 18));
    NSArray* names = @[ @"All projects", @"Recent", @"Favorites", @"On this device" ];
    __weak NeonLibraryController* weak = self;
    for (NSInteger i = 0; i < 4; i++) {
        NSInteger filter = i == 5 ? NeonLibraryTrash : i;
        NeonLibraryButton* row =
            button(self.sidebarView, names[i], NSMakeRect(0, 93.5 + i * 44, width, 44), ^{
              [weak selectFilter:(NeonLibraryFilter)filter];
            });
        row.navigationRow = YES;
        row.accessibilityLabel = names[i];
        row.chosen = i != 4 && self.query.filter == filter;
        row.enabled = i != 4;
        if (i == 4)
            row.toolTip = @"iCloud Drive is not available yet";
        row.kind = NeonButtonSelection;
        row.alignment = NSTextAlignmentLeft;
    }
    NeonLibraryButton* settings =
        button(self.sidebarView, @"Settings",
               NSMakeRect(0, MAX(270, self.sidebarView.bounds.size.height - 69.5), width, 45.5), ^{
                 [weak send:@"settings" record:nil];
               });
    settings.navigationRow = YES;
    settings.settingsCommand = YES;
}
@end
