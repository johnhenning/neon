#include "WorkspaceController.h"

@implementation NeonChapterHeading
- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.cell.wraps = YES;
        self.cell.scrollable = NO;
        self.lineBreakMode = NSLineBreakByWordWrapping;
        self.maximumNumberOfLines = 0;
        self.accessibilityElement = YES;
        self.accessibilityRole = NSAccessibilityTextFieldRole;
    }
    return self;
}
- (NSSize)intrinsicContentSize {
    CGFloat width = MAX(1, self.bounds.size.width);
    NSSize size = [self.cell cellSizeForBounds:NSMakeRect(0, 0, width, CGFLOAT_MAX)];
    return NSMakeSize(NSViewNoIntrinsicMetric, MAX(44, ceil(size.height)));
}
- (void)setStringValue:(NSString*)value {
    [super setStringValue:value];
    NSMutableParagraphStyle* paragraph = [NSMutableParagraphStyle new];
    paragraph.minimumLineHeight = 44;
    paragraph.maximumLineHeight = 44;
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    self.attributedStringValue =
        [[NSAttributedString alloc] initWithString:value
                                        attributes:@{
                                            NSFontAttributeName : self.font ?: NeonSerif(32),
                                            NSForegroundColorAttributeName : NeonInk(),
                                            NSParagraphStyleAttributeName : paragraph
                                        }];
    [self invalidateIntrinsicContentSize];
    self.superview.needsLayout = YES;
}
- (void)controlTextDidChange:(NSNotification*)notification {
    (void)notification;
    [self invalidateIntrinsicContentSize];
    self.superview.needsLayout = YES;
}
- (NSArray<NSAccessibilityCustomAction*>*)accessibilityCustomActions {
    return @[ [[NSAccessibilityCustomAction alloc] initWithName:@"Rename"
                                                         target:self
                                                       selector:@selector(accessibleRename)] ];
}
- (BOOL)accessibleRename {
    [self beginRenaming];
    return YES;
}
- (BOOL)control:(NSControl*)control
               textView:(NSTextView*)textView
    doCommandBySelector:(SEL)command {
    if (textView.hasMarkedText)
        return NO;
    return [super control:control textView:textView doCommandBySelector:command];
}
@end

@interface NeonWorkspaceDocument : NSView
@property(nonatomic, weak) NeonWorkspaceController* workspace;
@end
@implementation NeonWorkspaceDocument
- (BOOL)isFlipped {
    return YES;
}
- (void)layout {
    [super layout];
    [self.workspace refreshLayout];
}
@end
@interface NeonWorkspaceRoot : NSView
@property(nonatomic, weak) NeonWorkspaceController* workspace;
@end
@implementation NeonWorkspaceRoot
- (BOOL)isFlipped {
    return YES;
}
- (void)layout {
    [super layout];
    [self.workspace refreshLayout];
}
- (void)drawRect:(NSRect)rect {
    [NeonPaper() setFill];
    (void)rect;
    NSRectFill(self.bounds);
}
@end
@interface NeonWorkspacePanel : NSView
@end
@implementation NeonWorkspacePanel
- (void)drawRect:(NSRect)rect {
    [NeonPanel() setFill];
    (void)rect;
    NSRectFill(self.bounds);
}
- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    self.needsDisplay = YES;
}
@end
@implementation NeonWorkspaceController {
    NeonWorkspaceDocument* _document;
    BOOL _layingOut;
    NSSize _lastViewportSize;
    NSTextField* _mode;
    NSView* _footer;
}
- (instancetype)initWithEditor:(NSTextView*)editor {
    self = [super initWithNibName:nil bundle:nil];
    if (!self)
        return nil;
    _editor = editor;
    _textMeasure = 760;
    _contentInset = 48;
    return self;
}
- (void)loadView {
    NeonWorkspaceRoot* root = [NeonWorkspaceRoot new];
    root.workspace = self;
    root.wantsLayer = YES;
    root.clipsToBounds = YES;
    self.view = root;
    _scrollView = [NSScrollView new];
    _scrollView.hasVerticalScroller = YES;
    _scrollView.autohidesScrollers = YES;
    _scrollView.scrollerStyle = NSScrollerStyleOverlay;
    _scrollView.drawsBackground = NO;
    _scrollView.wantsLayer = YES;
    _document = [NeonWorkspaceDocument new];
    _document.workspace = self;
    _document.wantsLayer = YES;
    _document.clipsToBounds = YES;
    _document.frame = NSMakeRect(0, 0, 640, 800);
    _scrollView.documentView = _document;
    [root addSubview:_scrollView];
    _heading = [NeonChapterHeading new];
    _heading.font = NeonSerif(32);
    _kicker = [NSTextField labelWithString:@""];
    _kicker.font = NeonUI(13);
    _kicker.textColor = NeonAccent();
    [_document addSubview:_kicker];
    [_document addSubview:_heading];
    _guidance = [NSTextField wrappingLabelWithString:@""];
    _guidance.font = NeonUI(13);
    _guidance.textColor = NeonMuted();
    _guidance.hidden = YES;
    [_document addSubview:_guidance];
    [_document addSubview:_editor];
    _sessionSlot = [NeonWorkspacePanel new];
    _sessionSlot.clipsToBounds = YES;
    _sessionSlot.accessibilityIdentifier = @"writing-session-slot";
    _sessionSlot.accessibilityElement = NO;
    [root addSubview:_sessionSlot];
    _footer = [NeonWorkspacePanel new];
    _footer.clipsToBounds = YES;
    [root addSubview:_footer];
    _status = [NSTextField labelWithString:@""];
    _status.font = NeonUI(13);
    _status.textColor = NeonMuted();
    _mode = [NSTextField labelWithString:@"Write"];
    _mode.font = NeonUI(13);
    _mode.textColor = NeonMuted();
    [_footer addSubview:_status];
    [_footer addSubview:_mode];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(textChanged:)
                                               name:NSTextDidChangeNotification
                                             object:_editor];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(textChanged:)
                                               name:NSViewFrameDidChangeNotification
                                             object:_scrollView.contentView];
    _scrollView.contentView.postsFrameChangedNotifications = YES;
}
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}
- (void)textChanged:(NSNotification*)notification {
    (void)notification;
    [self refreshLayout];
}
- (void)setBodyBaselineAdjustment:(CGFloat)value {
    _bodyBaselineAdjustment = value;
    [self refreshLayout];
}
- (void)setContentInset:(CGFloat)inset {
    _contentInset = inset;
    [self refreshLayout];
}
- (void)setTextMeasure:(CGFloat)measure {
    _textMeasure = measure;
    [self refreshLayout];
}
- (void)refreshLayout {
    if (_layingOut || !self.isViewLoaded)
        return;
    _layingOut = YES;
    NSSize viewportSize = self.view.bounds.size;
    BOOL resized = !NSEqualSizes(viewportSize, _lastViewportSize);
    _lastViewportSize = viewportSize;
    CGFloat width = self.view.bounds.size.width, height = self.view.bounds.size.height;
    CGFloat sessionHeight = _sessionSlot.subviews.count ? 44 : 0;
    CGFloat bodyHeight = MAX(0, height - 36 - sessionHeight);
    _scrollView.frame = NSMakeRect(0, 0, width, bodyHeight);
    _sessionSlot.hidden = sessionHeight == 0;
    _sessionSlot.frame = NSMakeRect(0, bodyHeight, width, sessionHeight);
    _footer.frame = NSMakeRect(0, MAX(0, height - 36), width, 36);
    _status.frame = NSMakeRect(12, 8, MAX(0, width - 100), 20);
    _mode.frame = NSMakeRect(MAX(12, width - 62), 8, 50, 20);
    CGFloat viewport = _scrollView.contentSize.width;
    CGFloat inset = MIN(_contentInset, MAX(20, viewport / 8));
    CGFloat measure = MAX(1, MIN(_textMeasure, viewport - inset * 2));
    CGFloat x = inset, y = 36;
    _kicker.frame = NSMakeRect(x - 2, y, measure + 4, 18);
    y += 42;
    _heading.frame = NSMakeRect(x - 2, y + 2, measure + 4, 44);
    CGFloat headingHeight = _heading.intrinsicContentSize.height;
    _heading.frame = NSMakeRect(x - 2, y + 2, measure + 4, headingHeight);
    y += headingHeight + 24 + self.bodyBaselineAdjustment;
    if (!_guidance.hidden && _guidance.stringValue.length) {
        _guidance.frame = NSMakeRect(x, y, measure, 100);
        CGFloat guidanceHeight =
            [_guidance.cell cellSizeForBounds:NSMakeRect(0, 0, measure, CGFLOAT_MAX)].height;
        _guidance.frame = NSMakeRect(x, y, measure, guidanceHeight);
        y += guidanceHeight + 24;
    }
    _editor.frame = NSMakeRect(x, y, measure, MAX(300, _editor.frame.size.height));
    _editor.textContainer.containerSize = NSMakeSize(measure, CGFLOAT_MAX);
    _editor.autoresizingMask = NSViewNotSizable;
    [_editor.layoutManager ensureLayoutForTextContainer:_editor.textContainer];
    CGFloat textHeight =
        ceil([_editor.layoutManager usedRectForTextContainer:_editor.textContainer].size.height);
    textHeight = MAX(300, textHeight + NeonScrollBottomClearance);
    _editor.frame = NSMakeRect(x, y, measure, textHeight);
    _document.frame =
        NSMakeRect(0, 0, viewport, MAX(_scrollView.contentSize.height, y + textHeight + 32));
    _document.needsDisplay = YES;
    [_scrollView tile];
    _layingOut = NO;
    if (resized && _editor.window.firstResponder == _editor)
        [_editor scrollRangeToVisible:_editor.selectedRange];
}
@end
