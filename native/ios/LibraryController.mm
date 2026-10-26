#include "LibraryController.h"
#import "Controls.h"
#import <QuartzCore/QuartzCore.h>
namespace {
UILabel* label(UIView* parent, NSString* value, UIFont* font, UIColor* color, CGRect frame) {
    UILabel* result = [[UILabel alloc] initWithFrame:frame];
    result.text = value;
    result.font = font;
    result.textColor = color;
    result.numberOfLines = 0;
    [parent addSubview:result];
    return result;
}
NeonButton* button(UIView* parent, NSString* title, CGRect frame, void (^block)(void)) {
    NeonButton* result = [[NeonButton alloc] initWithFrame:frame];
    [result setTitle:title forState:UIControlStateNormal];
    result.kind = NeonButtonSecondary;
    [result addAction:[UIAction actionWithHandler:^(__kindof UIAction* action) {
              (void)action;
              block();
            }]
        forControlEvents:UIControlEventTouchUpInside];
    [parent addSubview:result];
    return result;
}
} // namespace
// NeonButton rebuilds its configuration for selection/hover/focus. Preserve the
// static navigation image through those updates without changing shared controls.
@interface NeonLibraryFilterButton : NeonButton
@property(nonatomic, strong) UIImage* navigationImage;
@end
@implementation NeonLibraryFilterButton
- (void)setNavigationImage:(UIImage*)image {
    _navigationImage = image;
    [self setConfiguration:self.configuration];
}
- (void)setConfiguration:(UIButtonConfiguration*)configuration {
    UIButtonConfiguration* value = [configuration copy];
    if (self.navigationImage) {
        value.image = self.navigationImage;
        value.imagePadding = 8;
        value.imagePlacement = NSDirectionalRectEdgeLeading;
    }
    [super setConfiguration:value];
}
@end
// Keep project titles editorial through every shared control state refresh.
@interface NeonLibraryTitleButton : NeonButton
@property(nonatomic, strong) UIFont* editorialFont;
@end
@implementation NeonLibraryTitleButton
- (void)setEditorialFont:(UIFont*)font {
    _editorialFont = font;
    [self setConfiguration:self.configuration];
}
- (void)setConfiguration:(UIButtonConfiguration*)configuration {
    UIButtonConfiguration* value = UIButtonConfiguration.plainButtonConfiguration;
    NSString* title = [self titleForState:UIControlStateNormal] ?: @"";
    value.attributedTitle = [[NSAttributedString alloc]
        initWithString:title
            attributes:@{
                NSFontAttributeName : self.editorialFont ?: NeonUI(16),
                NSForegroundColorAttributeName : self.enabled ? NeonInk() : NeonMuted()
            }];
    value.contentInsets = NSDirectionalEdgeInsetsZero;
    value.titleLineBreakMode = NSLineBreakByTruncatingTail;
    value.background.backgroundColor = UIColor.clearColor;
    // NeonButton supplies the native keyboard/Focus Engine outline. Carry it
    // through while discarding its filled secondary background and title font.
    value.background.strokeColor = configuration.background.strokeColor;
    value.background.strokeWidth = configuration.background.strokeWidth;
    value.background.cornerRadius = configuration.background.cornerRadius;
    [super setConfiguration:value];
}
@end
@interface NeonLibraryController ()
@property(nonatomic) NeonLibraryQuery* query;
@property(nonatomic) NeonLibraryPresentation* presentation;
@property(nonatomic) NSArray<NSDictionary*>* source;
@property(nonatomic) NSError* sourceError;
@property(nonatomic) UIScrollView* scroll;
@property(nonatomic) UIView* footer;
@property(nonatomic) CGFloat renderedWidth;
@end
@implementation NeonLibraryController
+ (UIImage*)navigationImageForFilter:(NeonLibraryFilter)filter {
    NSArray* names = @[ @"library", @"recent", @"favorites", @"device", @"trash" ];
    if (filter < NeonLibraryAll || filter > NeonLibraryTrash)
        return nil;
    NSString* path = [NSBundle.mainBundle pathForResource:names[filter]
                                                   ofType:@"png"
                                              inDirectory:@"icons"];
    UIImage* pixels = [UIImage imageWithContentsOfFile:path];
    NSAssert(pixels.CGImage, @"Missing bundled Library navigation artwork: %@", names[filter]);
    if (!pixels.CGImage)
        return nil;
    UIImage* root = [UIImage imageWithCGImage:pixels.CGImage
                                        scale:3
                                  orientation:UIImageOrientationUp];
    // Assets preserve their24pt SVG roots at3x. The native wrapper is20pt;
    // changing point scale fits the untouched raster without altering proportions.
    CGFloat pointScale = root.scale * root.size.width / 20;
    return [[UIImage imageWithCGImage:root.CGImage
                                scale:pointScale
                          orientation:UIImageOrientationUp]
        imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}
+ (NeonButton*)navigationButtonForFilter:(NeonLibraryFilter)filter {
    NeonLibraryFilterButton* button = [NeonLibraryFilterButton buttonWithType:UIButtonTypeSystem];
    button.navigationImage = [self navigationImageForFilter:filter];
    return button;
}
- (instancetype)init {
    if ((self = [super init])) {
        _query = [NeonLibraryQuery new];
        _fixtureIDs = @{};
    }
    return self;
}
- (void)loadView {
    self.view = [UIView new];
    self.view.backgroundColor = NeonPaper();
    self.scroll = [UIScrollView new];
    [self.view addSubview:self.scroll];
    self.footer = [UIView new];
    self.footer.backgroundColor = NeonPanel();
    [self.view addSubview:self.footer];
    [self render];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (self.renderedWidth != self.view.bounds.size.width ||
        self.footer.frame.origin.y != self.view.bounds.size.height - 40)
        [self render];
}
- (void)traitCollectionDidChange:(UITraitCollection*)previous {
    [super traitCollectionDidChange:previous];
    [self render];
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
- (UIMenu*)menu:(NSDictionary*)record {
    __weak NeonLibraryController* weak = self;
    NSMutableArray* actions = [NSMutableArray new];
    BOOL trash = [record[@"trashed"] boolValue];
    NSArray* titles = trash ? @[ @"Restore", @"Delete permanently" ] : @[
        @"Open", @"Rename", @"Duplicate",
        [record[@"favorite"] boolValue] ? @"Remove favorite" : @"Favorite", @"Move to Trash"
    ];
    NSArray* keys = trash ? @[ @"restore", @"delete" ]
                          : @[ @"open", @"rename", @"duplicate", @"favorite", @"trash" ];
    for (NSUInteger i = 0; i < titles.count; i++) {
        NSString* key = keys[i];
        UIAction* action = [UIAction actionWithTitle:titles[i]
                                               image:nil
                                          identifier:nil
                                             handler:^(__kindof UIAction* value) {
                                               (void)value;
                                               [weak send:key record:record];
                                             }];
        if ([key isEqual:@"trash"] || [key isEqual:@"delete"])
            action.attributes = UIMenuElementAttributesDestructive;
        [actions addObject:action];
    }
    return [UIMenu menuWithChildren:actions];
}
- (UIMenu*)navigationMenu {
    NSMutableArray* actions = [NSMutableArray new];
    __weak NeonLibraryController* weak = self;
    NSArray* titles = @[ @"All projects", @"Recent", @"Favorites", @"On this device", @"Trash" ];
    for (NSInteger i = 0; i < 5; i++) {
        UIAction* a = [UIAction
            actionWithTitle:titles[i]
                      image:[NeonLibraryController navigationImageForFilter:(NeonLibraryFilter)i]
                 identifier:nil
                    handler:^(__kindof UIAction* value) {
                      (void)value;
                      [weak selectFilter:(NeonLibraryFilter)i];
                    }];
        a.state = self.query.filter == i ? UIMenuElementStateOn : UIMenuElementStateOff;
        [actions addObject:a];
    }
    [actions addObject:[UIAction actionWithTitle:self.query.view == NeonLibraryGrid ? @"List view"
                                                                                    : @"Grid view"
                                           image:nil
                                      identifier:nil
                                         handler:^(__kindof UIAction* value) {
                                           (void)value;
                                           [weak setLibraryView:weak.query.view == NeonLibraryGrid
                                                                    ? NeonLibraryList
                                                                    : NeonLibraryGrid];
                                         }]];
    NSArray* sorts = @[ @"Date modified", @"Title", @"Last opened" ];
    for (NSInteger i = 0; i < 3; i++) {
        UIAction* a = [UIAction actionWithTitle:sorts[i]
                                          image:nil
                                     identifier:nil
                                        handler:^(__kindof UIAction* value) {
                                          (void)value;
                                          weak.query.sort = (NeonLibrarySort)i;
                                          [weak.query savePreferences];
                                          [weak render];
                                        }];
        a.state = self.query.sort == i ? UIMenuElementStateOn : UIMenuElementStateOff;
        [actions addObject:a];
    }
    [actions addObject:[UIAction actionWithTitle:@"Settings"
                                           image:nil
                                      identifier:nil
                                         handler:^(__kindof UIAction* value) {
                                           (void)value;
                                           [weak send:@"settings" record:nil];
                                         }]];
    return [UIMenu menuWithChildren:actions];
}
- (void)render {
    if (!self.scroll)
        return;
    self.presentation = [[NeonLibraryPresentation alloc] initWithRecords:self.source
                                                                   error:self.sourceError
                                                                   query:self.query
                                                       selectedProjectID:self.selectedProjectID
                                                                     now:[NSDate date]];
    self.selectedProjectID = self.presentation.selectedProjectID;
    CGFloat w = self.view.bounds.size.width, h = self.view.bounds.size.height;
    self.renderedWidth = w;
    self.scroll.frame = CGRectMake(0, 0, w, MAX(0, h - 40));
    self.footer.frame = CGRectMake(0, MAX(0, h - 40), w, 40);
    self.view.backgroundColor = NeonPaper();
    self.footer.backgroundColor = NeonPanel();
    for (UIView* child in self.scroll.subviews.copy)
        [child removeFromSuperview];
    for (UIView* child in self.footer.subviews.copy)
        [child removeFromSuperview];
    CGFloat m = MIN(!self.usesSidebarNavigation && w >= 700 && w < 1000 ? 720 : 820,
                    MAX(0, w - 40)),
            x = (w - m) / 2;
    __weak NeonLibraryController* weak = self;
    label(self.scroll, @"Library", NeonSerif(32), NeonInk(), CGRectMake(x, 24, m - 44, 46));
    label(self.scroll, @"A place for your next idea.", NeonUI(14), NeonMuted(),
          CGRectMake(x, 86, m, 28));
    if (!self.usesSidebarNavigation && w < 1000) {
        NeonButton* all = button(self.scroll, @"All projects", CGRectMake(x, 138, 116, 44), ^{
          [weak selectFilter:NeonLibraryAll];
        });
        all.kind = NeonButtonSelection;
        all.chosen = self.query.filter == NeonLibraryAll;
        NeonButton* recent = button(self.scroll, @"Recent", CGRectMake(x + 124, 138, 72, 44), ^{
          [weak selectFilter:NeonLibraryRecent];
        });
        recent.kind = NeonButtonSelection;
        recent.chosen = self.query.filter == NeonLibraryRecent;
    } else
        button(self.scroll, self.query.view == NeonLibraryGrid ? @"List view" : @"Grid view",
               CGRectMake(x + m - 240, 138, 100, 44), ^{
                 [weak setLibraryView:weak.query.view == NeonLibraryGrid ? NeonLibraryList
                                                                         : NeonLibraryGrid];
               });
    button(
        self.scroll, @"New project",
        CGRectMake(!self.usesSidebarNavigation && w < 1000 ? x + 204 : x + m - 132, 138, 132, 44),
        ^{
          [weak send:@"new" record:nil];
        })
        .kind = NeonButtonPrimary;
    CGFloat y = 198;
    if (self.presentation.error) {
        label(self.scroll, @"Unable to load projects", NeonSerif(24), NeonInk(),
              CGRectMake(x, y, m, 44));
        label(self.scroll, self.presentation.error.localizedDescription, NeonUI(14), NeonMuted(),
              CGRectMake(x, y + 52, m, 100));
        y += 168;
    } else if (!self.presentation.records.count) {
        BOOL welcome = self.source.count == 0 && (self.query.filter == NeonLibraryAll ||
                                                  self.query.filter == NeonLibraryDevice);
        label(self.scroll, welcome ? @"Begin anywhere." : @"No projects here yet.", NeonSerif(32),
              NeonInk(), CGRectMake(x + 24, y + 24, m - 48, 52));
        if (welcome) {
            label(self.scroll,
                  @"A book, a paper, a letter. Choose a starting point and make it yours.",
                  NeonSerif(20), NeonMuted(), CGRectMake(x + 24, y + 100, m - 48, 110));
            button(self.scroll, @"Create a project",
                   CGRectMake(x + 24, y + 234, MIN(240, m - 48), 44),
                   ^{
                     [weak send:@"new" record:nil];
                   })
                .kind = NeonButtonPrimary;
            NeonButton* import = button(self.scroll, @"Import a document",
                                        CGRectMake(x + 24, y + 302, MIN(240, m - 48), 44),
                                        ^{
                                        });
            import.enabled = NO;
            import.accessibilityHint = @"Document import is not available yet";
            label(self.scroll, @"No account needed. Your work stays on your device.", NeonUI(13),
                  NeonMuted(), CGRectMake(x + 24, y + 370, m - 48, 44));
        }
        y += 440;
    } else {
        NSInteger columns = m >= 700 ? 3 : 2;
        CGFloat tile = (m - 24 * (columns - 1)) / columns;
        NSUInteger i = 0;
        for (NSDictionary* r in self.presentation.records) {
            BOOL list = self.query.view == NeonLibraryList;
            CGFloat rx = list ? x : x + (i % columns) * (tile + 24),
                    ry = y + (list ? i * 144 : (i / columns) * (tile * 1.46 + 86)),
                    cw = list ? 70 : tile, ch = list ? 104 : tile * 1.46;
            if (list) {
                UIView* panel = [[UIView alloc] initWithFrame:CGRectMake(rx, ry, m, 128)];
                panel.backgroundColor = NeonPanel();
                panel.layer.cornerRadius = 12;
                [self.scroll addSubview:panel];
                rx += 12;
                ry += 12;
            }
            UIView* cover = [[UIView alloc] initWithFrame:CGRectMake(rx, ry, cw, ch)];
            cover.backgroundColor = NeonPanel();
            cover.layer.cornerRadius = 8;
            cover.clipsToBounds = YES;
            NSString* fixture = self.fixtureIDs[r[@"projectID"]] ?: r[@"fixtureID"];
            NSString* stem = fixture ? [NeonLibraryPresentation artworkForFixtureID:fixture] : nil;
            NSString* path = stem ? [[NSBundle mainBundle] pathForResource:stem
                                                                    ofType:@"png"
                                                               inDirectory:@"artwork"]
                                  : nil;
            UIImage* image = path ? [UIImage imageWithContentsOfFile:path] : nil;
            UIImageView* artwork = [[UIImageView alloc]
                initWithImage:image ?: [UIImage systemImageNamed:@"book.closed"]];
            artwork.contentMode =
                image ? UIViewContentModeScaleAspectFill : UIViewContentModeCenter;
            artwork.tintColor = NeonMuted();
            artwork.frame = cover.bounds;
            artwork.autoresizingMask =
                UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [cover addSubview:artwork];
            [self.scroll addSubview:cover];
            UIButton* open = [UIButton buttonWithType:UIButtonTypeCustom];
            open.frame = cover.frame;
            open.accessibilityLabel = [@"Open " stringByAppendingString:r[@"title"] ?: @"Untitled"];
            [open addAction:[UIAction actionWithHandler:^(__kindof UIAction* a) {
                    (void)a;
                    [weak send:@"open" record:r];
                  }]
                forControlEvents:UIControlEventTouchUpInside];
            [self.scroll addSubview:open];
            CGFloat tx = list ? rx + 86 : rx, ty = list ? ry : ry + ch + 8,
                    tw = list ? m - 110 : tile;
            NeonLibraryTitleButton* title = [[NeonLibraryTitleButton alloc]
                initWithFrame:CGRectMake(tx, ty, list ? tw : MAX(0, tw - 52), 34)];
            title.editorialFont = list ? NeonSerif(24) : NeonUI(16);
            [title setTitle:r[@"title"] ?: @"Untitled" forState:UIControlStateNormal];
            [title addAction:[UIAction actionWithHandler:^(__kindof UIAction* action) {
                     (void)action;
                     [weak send:@"open" record:r];
                   }]
                forControlEvents:UIControlEventTouchUpInside];
            [self.scroll addSubview:title];
            title.accessibilityIdentifier =
                [@"library-title-" stringByAppendingString:r[@"projectID"]];
            title.isAccessibilityElement = YES;
            title.accessibilityLabel = r[@"title"] ?: @"Untitled";
            title.accessibilityTraits = UIAccessibilityTraitButton;
            title.titleLabel.isAccessibilityElement = NO;
            title.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
            title.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
            NSDate* date = r[@"modified"];
            NSString* edited =
                [date isKindOfClass:[NSDate class]]
                    ? [NSDateFormatter localizedStringFromDate:date
                                                     dateStyle:NSDateFormatterMediumStyle
                                                     timeStyle:NSDateFormatterNoStyle]
                    : @"Unknown date";
            label(self.scroll,
                  [r[@"error"] length] > 0
                      ? @"Unable to read project"
                      : [NSString stringWithFormat:@"%@ · %@", r[@"preset"] ?: @"Project", edited],
                  NeonUI(13), NeonMuted(), CGRectMake(tx, ty + 34, tw, 24));
            NeonButton* more =
                button(self.scroll, @"•••",
                       CGRectMake(list ? tx + 110 : tx + tw - 44, list ? ty + 64 : ty, 44, 34),
                       ^{
                       });
            more.menu = [self menu:r];
            more.showsMenuAsPrimaryAction = YES;
            more.accessibilityLabel =
                [@"Actions for " stringByAppendingString:r[@"title"] ?: @"Untitled"];
            if (list)
                label(self.scroll, @"On this device", NeonUI(13), NeonMuted(),
                      CGRectMake(tx, ty + 64, 110, 24));
            i++;
        }
        y += self.query.view == NeonLibraryList
                 ? i * 144
                 : ((i + columns - 1) / columns) * (tile * 1.46 + 86);
    }
    self.scroll.contentSize = CGSizeMake(w, y + 32);
    NSString* count =
        self.presentation.error
            ? @"Projects unavailable"
            : [NSString
                  stringWithFormat:@"%lu %@ · On this device",
                                   (unsigned long)self.presentation.records.count,
                                   self.presentation.records.count == 1 ? @"project" : @"projects"];
    UILabel* countLabel =
        label(self.footer, count, NeonUI(13), NeonMuted(), CGRectMake(12, 12, MAX(0, w - 130), 18));
    countLabel.accessibilityIdentifier =
        self.presentation.error ? @"library-projects-unavailable"
                                : [NSString stringWithFormat:@"library-project-count-%lu",
                                                             self.presentation.records.count];
    label(self.footer, @"Local first", NeonUI(13), NeonMuted(), CGRectMake(w - 100, 12, 88, 18));
}
@end
