#include "LibraryController.h"
#import "Controls.h"
#import <QuartzCore/QuartzCore.h>
@interface NeonLibraryCommandButton : NeonButton
@end
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
    NeonLibraryCommandButton* result = [[NeonLibraryCommandButton alloc] initWithFrame:frame];
    result.kind = ([title isEqual:@"List view"] || [title isEqual:@"Grid view"])
                      ? NeonButtonQuiet
                      : NeonButtonSecondary;
    [result addAction:[UIAction actionWithHandler:^(__kindof UIAction* action) {
              (void)action;
              block();
            }]
        forControlEvents:UIControlEventTouchUpInside];
    // Registering a UIAction can replace UIButton's cold title attributes.
    [result setTitle:title forState:UIControlStateNormal];
    [parent addSubview:result];
    return result;
}
} // namespace
@implementation NeonLibraryCommandButton
- (void)setConfiguration:(UIButtonConfiguration*)configuration {
    UIButtonConfiguration* value = [configuration copy];
    value.titleLineBreakMode = NSLineBreakByTruncatingTail;
    value.titleTextAttributesTransformer = ^NSDictionary*(NSDictionary* incoming) {
      NSMutableDictionary* attributes = [incoming mutableCopy];
      attributes[NSFontAttributeName] = NeonUI(15);
      return attributes;
    };
    if (self.kind == NeonButtonPrimary)
        value.contentInsets = NSDirectionalEdgeInsetsMake(8, 16, 8, 16);
    if ([[self titleForState:UIControlStateNormal] isEqual:@"•••"])
        value.contentInsets = NSDirectionalEdgeInsetsZero;
    [super setConfiguration:value];
    self.titleLabel.numberOfLines = 1;
}
@end
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
    value.background.cornerRadius = 0;
    value.contentInsets = NSDirectionalEdgeInsetsMake(12, 20, 12, 20);
    value.background.strokeWidth = 0;
    value.background.backgroundColor =
        self.chosen ? [NeonAccent() colorWithAlphaComponent:0.12] : UIColor.clearColor;
    BOOL selected = self.chosen;
    value.baseForegroundColor = selected ? NeonAccent() : NeonInk();
    value.titleTextAttributesTransformer = ^NSDictionary*(NSDictionary* incoming) {
      NSMutableDictionary* attributes = [incoming mutableCopy];
      attributes[NSFontAttributeName] = selected ? NeonUISemibold(14) : NeonUI(14);
      attributes[NSForegroundColorAttributeName] = selected ? NeonAccent() : NeonInk();
      return attributes;
    };
    value.image = nil;
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
    UIColor* foreground = self.enabled ? NeonInk() : NeonMuted();
    UIFont* font = self.editorialFont ?: NeonUI(16);
    value.baseForegroundColor = foreground;
    value.titleTextAttributesTransformer = ^NSDictionary*(NSDictionary* incoming) {
      NSMutableDictionary* attributes = [incoming mutableCopy];
      attributes[NSFontAttributeName] = font;
      attributes[NSForegroundColorAttributeName] = foreground;
      return attributes;
    };
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
@interface NeonLibraryController () <UIContextMenuInteractionDelegate>
@property(nonatomic) NSMapTable<UIView*, NSDictionary*>* contextRecords;
@property(nonatomic) NeonLibraryQuery* query;
@property(nonatomic) NeonLibraryPresentation* presentation;
@property(nonatomic) NSArray<NSDictionary*>* source;
@property(nonatomic) NSError* sourceError;
@property(nonatomic) UIScrollView* scroll;
@property(nonatomic) UIView* footer;
@property(nonatomic) CGFloat renderedWidth;
@end
@implementation NeonLibraryController
- (UIView*)statusFooter {
    return self.footer;
}
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
    // Assets preserve their 24pt SVG roots at 3x. The native wrapper is 20pt;
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
        _contextRecords = [NSMapTable weakToStrongObjectsMapTable];
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
    CGFloat viewport = self.parentViewController ? self.parentViewController.view.bounds.size.width
                                                 : self.view.bounds.size.width;
    CGFloat statusHeight = viewport <= 600 ? 36 : 36.5;
    if (self.renderedWidth != self.view.bounds.size.width ||
        self.scroll.frame.size.height != MAX(0, self.view.bounds.size.height - statusHeight))
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
- (UIContextMenuConfiguration*)contextMenuInteraction:(UIContextMenuInteraction*)interaction
                       configurationForMenuAtLocation:(CGPoint)location {
    (void)location;
    NSDictionary* record = [self.contextRecords objectForKey:interaction.view];
    if (!record)
        return nil;
    __weak NeonLibraryController* weak = self;
    return [UIContextMenuConfiguration
        configurationWithIdentifier:record[@"projectID"]
                    previewProvider:nil
                     actionProvider:^UIMenu*(NSArray<UIMenuElement*>* suggested) {
                       (void)suggested;
                       return [weak menu:record];
                     }];
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
    CGFloat statusHeight =
        (self.parentViewController ? self.parentViewController.view.bounds.size.width : w) <= 600
            ? 36
            : 36.5;
    self.scroll.frame = CGRectMake(0, 0, w, MAX(0, h - statusHeight));
    CGFloat footerWidth =
        self.footer.superview == self.view ? w : self.footer.superview.bounds.size.width;
    CGFloat footerBottom =
        self.footer.superview.bounds.size.height -
        (self.footer.superview == self.view ? 0 : self.footer.superview.safeAreaInsets.bottom);
    self.footer.frame =
        CGRectMake(0, MAX(0, footerBottom - statusHeight), footerWidth, statusHeight);
    self.view.backgroundColor = NeonPaper();
    self.footer.backgroundColor = NeonPanel();
    for (UIView* child in self.scroll.subviews.copy)
        [child removeFromSuperview];
    for (UIView* child in self.footer.subviews.copy)
        [child removeFromSuperview];
    CGFloat viewportWidth =
        self.parentViewController ? self.parentViewController.view.bounds.size.width : w;
    BOOL narrow = viewportWidth <= 600;
    BOOL medium = viewportWidth > 600 && viewportWidth <= 850;
    CGFloat x = narrow ? 20 : (medium ? 28 : 32), m = MAX(0, w - 2 * x);
    CGFloat top = narrow ? 24 : (medium ? 28 : 32);
    __weak NeonLibraryController* weak = self;
    label(self.scroll, @"Library", NeonSerif(narrow ? 28 : 32), NeonInk(),
          CGRectMake(x, top, m, narrow ? 41.5 : 47.5));
    label(self.scroll, @"A place for your next idea.", NeonUI(15), NeonMuted(),
          CGRectMake(x, top + (narrow ? 41.5 : 47.5) + 8, m, 21.5));
    CGFloat commandsY = top + (narrow ? 89 : 18.75);
    CGFloat commandsX = narrow ? x : (medium ? x + 180.3359375 : x + m - 191.4609375);
    button(self.scroll, self.query.view == NeonLibraryGrid ? @"List view" : @"Grid view",
           CGRectMake(commandsX, commandsY, 78.0390625, 39.5), ^{
             [weak setLibraryView:weak.query.view == NeonLibraryGrid ? NeonLibraryList
                                                                     : NeonLibraryGrid];
           });
    button(self.scroll, @"New project",
           CGRectMake(narrow ? x + m - 107.421875 : commandsX + 84.0390625, commandsY + 1,
                      107.421875, 37.5),
           ^{
             [weak send:@"new" record:nil];
           })
        .kind = NeonButtonPrimary;
    CGFloat y = top + (narrow ? 128.5 + 22 : 77 + 28);
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
        NSInteger columns = viewportWidth > 850 ? 3 : 2;
        CGFloat gap = narrow ? 14 : 22;
        CGFloat tile = (m - gap * (columns - 1)) / columns;
        NSUInteger i = 0;
        for (NSDictionary* r in self.presentation.records) {
            BOOL list = self.query.view == NeonLibraryList;
            CGFloat rx = list ? x : x + (i % columns) * (tile + gap),
                    ry = y + (list ? i * 151 : (i / columns) * (narrow ? 246.5 : 301.5)),
                    cw = list ? m : tile, ch = list ? 65 : (narrow ? 170 : 220);
            UIView* cover = [[UIView alloc] initWithFrame:CGRectMake(rx, ry, cw, ch)];
            cover.backgroundColor = NeonPanel();
            cover.layer.cornerRadius = 0;
            cover.layer.borderWidth = 1;
            cover.layer.borderColor = [NeonInk() colorWithAlphaComponent:0.14].CGColor;
            cover.clipsToBounds = YES;
            NSString* fixture = self.fixtureIDs[r[@"projectID"]] ?: r[@"fixtureID"];
            NSString* titleText = [r[@"title"] length] ? r[@"title"] : @"Untitled";
            NSString* initialText = [titleText hasPrefix:@"The "] && titleText.length > 4
                                        ? [titleText substringFromIndex:4]
                                        : titleText;
            NSString* glyph =
                [fixture isEqual:@"neon.fixture.quiet-sea"] || [titleText isEqual:@"The Quiet Sea"]
                    ? @"≈"
                    : [initialText
                          substringWithRange:[initialText
                                                 rangeOfComposedCharacterSequenceAtIndex:0]];
            UILabel* placeholder = label(cover, glyph, NeonSerif(28), NeonAccent(), cover.bounds);
            placeholder.textAlignment = NSTextAlignmentCenter;
            placeholder.autoresizingMask =
                UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [self.scroll addSubview:cover];
            UIButton* open = [UIButton buttonWithType:UIButtonTypeCustom];
            open.frame = cover.frame;
            [self.contextRecords setObject:r forKey:open];
            [open addInteraction:[[UIContextMenuInteraction alloc] initWithDelegate:self]];
            open.accessibilityLabel = [@"Open " stringByAppendingString:r[@"title"] ?: @"Untitled"];
            [open addAction:[UIAction actionWithHandler:^(__kindof UIAction* a) {
                    (void)a;
                    [weak send:@"open" record:r];
                  }]
                forControlEvents:UIControlEventTouchUpInside];
            [self.scroll addSubview:open];
            CGFloat tx = rx, ty = ry + ch + 13, tw = list ? m : tile;
            NeonLibraryTitleButton* title = [[NeonLibraryTitleButton alloc]
                initWithFrame:CGRectMake(tx, ty, tw, narrow ? 22 : 25)];
            title.editorialFont = NeonSerif(narrow ? 15 : 17);
            [title addAction:[UIAction actionWithHandler:^(__kindof UIAction* action) {
                     (void)action;
                     [weak send:@"open" record:r];
                   }]
                forControlEvents:UIControlEventTouchUpInside];
            [title setTitle:r[@"title"] ?: @"Untitled" forState:UIControlStateNormal];
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
            if ([date isKindOfClass:NSDate.class]) {
                if ([NSCalendar.currentCalendar isDateInToday:date])
                    edited = @"Edited today";
                else if ([NSCalendar.currentCalendar isDateInYesterday:date])
                    edited = @"Edited yesterday";
                else
                    edited = [@"Edited " stringByAppendingString:edited];
            }
            label(self.scroll,
                  [r[@"error"] length] > 0
                      ? @"Unable to read project"
                      : [NSString stringWithFormat:@"%@ · %@", r[@"preset"] ?: @"Project", edited],
                  NeonUI(narrow ? 12 : 12.5), NeonMuted(),
                  CGRectMake(tx, ty + (narrow ? 25 : 27.5), tw, narrow ? 17.5 : 18));
            UIMenu* projectMenu = [self menu:r];
            [self.contextRecords setObject:r forKey:title];
            [title addInteraction:[[UIContextMenuInteraction alloc] initWithDelegate:self]];
            __weak NeonLibraryTitleButton* weakTitle = title;
            NSMutableArray* accessibilityActions = [NSMutableArray new];
            for (UIMenuElement* item in projectMenu.children) {
                if (![item isKindOfClass:UIAction.class])
                    continue;
                UIAction* action = (UIAction*)item;
                [accessibilityActions
                    addObject:[[UIAccessibilityCustomAction alloc]
                                   initWithName:action.title
                                  actionHandler:^BOOL(UIAccessibilityCustomAction* custom) {
                                    (void)custom;
                                    [weakTitle sendAction:action];
                                    return YES;
                                  }]];
            }
            title.accessibilityCustomActions = accessibilityActions;
            open.accessibilityCustomActions = accessibilityActions;
            i++;
        }
        y += self.query.view == NeonLibraryList
                 ? i * 151
                 : ((i + columns - 1) / columns) * (narrow ? 246.5 : 301.5);
    }
    self.scroll.contentSize = CGSizeMake(w, y + 32);
    NSString* count =
        self.presentation.error
            ? @"Projects unavailable"
            : [NSString
                  stringWithFormat:@"%lu %@ · On this device",
                                   (unsigned long)self.presentation.records.count,
                                   self.presentation.records.count == 1 ? @"project" : @"projects"];
    UILabel* countLabel = label(self.footer, count, NeonUI(narrow ? 11 : 13), NeonMuted(),
                                CGRectMake(narrow ? 12 : 15, narrow ? 10 : 9,
                                           MAX(0, footerWidth - 130), narrow ? 16 : 18.5));
    countLabel.accessibilityIdentifier =
        self.presentation.error ? @"library-projects-unavailable"
                                : [NSString stringWithFormat:@"library-project-count-%lu",
                                                             self.presentation.records.count];
    label(self.footer, @"Local first", NeonUI(narrow ? 11 : 13), NeonMuted(),
          CGRectMake(footerWidth - 100, narrow ? 10 : 9, 88, narrow ? 16 : 18.5));
}
@end
