#include "Controls.h"
#import <QuartzCore/QuartzCore.h>

#if !TARGET_OS_IPHONE
@interface NeonFieldCell : NSTextFieldCell
@end
@implementation NeonFieldCell
- (NSRect)drawingRectForBounds:(NSRect)bounds {
    NSRect rect = [super drawingRectForBounds:NSInsetRect(bounds, 12, 0)];
    CGFloat height = self.cellSize.height;
    rect.origin.y += MAX(0, (rect.size.height - height) / 2);
    rect.size.height = MIN(rect.size.height, height);
    return rect;
}
@end
#endif

@implementation NeonButton {
#if !TARGET_OS_IPHONE
    NSTrackingArea* _tracking;
#endif
    BOOL _hovered;
}
#if TARGET_OS_IPHONE
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        [self.heightAnchor constraintGreaterThanOrEqualToConstant:NeonMinimumTouchTarget].active =
            YES;
        [self.widthAnchor constraintGreaterThanOrEqualToConstant:NeonMinimumTouchTarget].active =
            YES;
        self.titleLabel.font = NeonUI(14);
        [self addGestureRecognizer:[[UIHoverGestureRecognizer alloc]
                                       initWithTarget:self
                                               action:@selector(hover:)]];
        [self refresh];
    }
    return self;
}
- (void)hover:(UIHoverGestureRecognizer*)gesture {
    _hovered = gesture.state == UIGestureRecognizerStateBegan ||
               gesture.state == UIGestureRecognizerStateChanged;
    [self refresh];
}
- (void)didUpdateFocusInContext:(UIFocusUpdateContext*)context
       withAnimationCoordinator:(UIFocusAnimationCoordinator*)coordinator {
    [super didUpdateFocusInContext:context withAnimationCoordinator:coordinator];
    [self refresh];
}
- (void)setTitle:(NSString*)title forState:(UIControlState)state {
    [super setTitle:title forState:state];
    [self refresh];
}
- (void)refresh {
    UIButtonConfiguration* config = UIButtonConfiguration.filledButtonConfiguration;
    config.title = self.loading               ? @"Loading…"
                   : self.errorMessage.length ? self.errorMessage
                                              : [self titleForState:UIControlStateNormal];
    config.attributedTitle =
        [[NSAttributedString alloc] initWithString:config.title ?: @""
                                        attributes:@{NSFontAttributeName : NeonUI(14)}];
    config.baseBackgroundColor = !self.enabled                    ? NeonPanel()
                                 : self.errorMessage.length       ? NeonDanger()
                                 : self.kind == NeonButtonPrimary ? NeonAccent()
                                 : self.kind == NeonButtonSelection
                                     ? (self.chosen ? NeonSelection() : NeonPaper())
                                     : NeonPanel();
    config.baseForegroundColor = !self.enabled ? NeonMuted()
                                 : (self.kind == NeonButtonPrimary || self.errorMessage.length)
                                     ? NeonActionText()
                                     : NeonInk();
    config.background.cornerRadius = NeonControlRadius;
    config.background.strokeColor = self.kind == NeonButtonSelection
                                        ? (self.chosen ? NeonAccent() : NeonLine())
                                        : UIColor.clearColor;
    config.background.strokeWidth = self.kind == NeonButtonSelection ? 1 : 0;
    config.contentInsets = NSDirectionalEdgeInsetsMake(12, 12, 12, 12);
    config.showsActivityIndicator = self.loading;
    self.configuration = config;
    if (self.focused) {
        config.background.strokeColor = NeonInk();
        config.background.strokeWidth = 3;
        self.configuration = config;
    }
    self.alpha = !self.enabled ? .65 : self.highlighted ? .75 : _hovered ? .90 : 1;
    self.accessibilityValue = self.loading ? @"Loading"
                              : self.kind == NeonButtonSelection
                                  ? (self.chosen ? @"Selected" : @"Not selected")
                                  : self.errorMessage;
    self.accessibilityHint = self.errorMessage;
    self.accessibilityTraits =
        UIAccessibilityTraitButton | (self.chosen ? UIAccessibilityTraitSelected : 0) |
        ((!self.enabled || self.loading) ? UIAccessibilityTraitNotEnabled : 0);
}
- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent*)event {
    if (self.enabled && !self.loading)
        [super sendAction:action to:target forEvent:event];
}
- (void)sendActionsForControlEvents:(UIControlEvents)events {
    if (self.enabled && !self.loading)
        [super sendActionsForControlEvents:events];
}
- (void)setHighlighted:(BOOL)value {
    [super setHighlighted:value];
    [self refresh];
}
#else
- (instancetype)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.bordered = NO;
        self.focusRingType = NSFocusRingTypeExterior;
        [self.heightAnchor constraintGreaterThanOrEqualToConstant:NeonMinimumTouchTarget].active =
            YES;
        [self.widthAnchor constraintGreaterThanOrEqualToConstant:NeonMinimumTouchTarget].active =
            YES;
    }
    return self;
}
- (NSSize)intrinsicContentSize {
    return NSMakeSize(
        MAX(44, [self.title sizeWithAttributes:@{NSFontAttributeName : NeonUI(14)}].width + 24),
        44);
}
- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (_tracking)
        [self removeTrackingArea:_tracking];
    _tracking =
        [[NSTrackingArea alloc] initWithRect:self.bounds
                                     options:NSTrackingMouseEnteredAndExited |
                                             NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect
                                       owner:self
                                    userInfo:nil];
    [self addTrackingArea:_tracking];
}
- (void)mouseEntered:(NSEvent*)event {
    (void)event;
    _hovered = YES;
    [self refresh];
}
- (void)mouseExited:(NSEvent*)event {
    (void)event;
    _hovered = NO;
    [self refresh];
}
- (BOOL)isAccessibilityEnabled {
    return self.enabled && !self.loading;
}
- (BOOL)acceptsFirstResponder {
    return self.enabled && !self.loading;
}
- (BOOL)sendAction:(SEL)action to:(id)target {
    return self.enabled && !self.loading && [super sendAction:action to:target];
}
- (void)performClick:(id)sender {
    if (self.enabled && !self.loading)
        [super performClick:sender];
}
- (void)refresh {
    self.accessibilityValue = self.loading ? @"Loading"
                              : self.kind == NeonButtonSelection
                                  ? (self.chosen ? @"Selected" : @"Not selected")
                                  : self.errorMessage;
    self.accessibilityHelp = self.errorMessage;
    self.needsDisplay = YES;
}
- (void)drawRect:(NSRect)rect {
    (void)rect;
    NSColor* fill = !self.enabled                    ? NeonPanel()
                    : self.errorMessage.length       ? NeonDanger()
                    : self.kind == NeonButtonPrimary ? NeonAccent()
                    : self.kind == NeonButtonSelection
                        ? (self.chosen ? NeonSelection() : NeonPaper())
                        : NeonPanel();
    CGFloat opacity = !self.enabled ? .65 : self.highlighted ? .75 : _hovered ? .90 : 1;
    self.alphaValue = opacity;
    NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, 2, 2)
                                                         xRadius:NeonControlRadius
                                                         yRadius:NeonControlRadius];
    [fill setFill];
    [path fill];
    if (self.kind == NeonButtonSelection) {
        [(self.chosen ? NeonAccent() : NeonLine()) setStroke];
        [path stroke];
    }
    if (self.window.firstResponder == self) {
        [NeonInk() setStroke];
        path.lineWidth = 3;
        [path stroke];
    }
    NSString* text = self.loading               ? @"Loading…"
                     : self.errorMessage.length ? self.errorMessage
                                                : self.title;
    NSDictionary* attributes = @{
        NSFontAttributeName : NeonUI(14),
        NSForegroundColorAttributeName : !self.enabled                 ? NeonMuted()
        : (self.kind == NeonButtonPrimary || self.errorMessage.length) ? NeonActionText()
                                                                       : NeonInk()
    };
    NSSize size = [text sizeWithAttributes:attributes];
    [text drawAtPoint:NSMakePoint((self.bounds.size.width - size.width) / 2,
                                  (self.bounds.size.height - size.height) / 2)
        withAttributes:attributes];
}
- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    [self refresh];
}
#endif
- (void)setKind:(NeonButtonKind)value {
    _kind = value;
    [self refresh];
}
- (void)setLoading:(BOOL)value {
    _loading = value;
#if TARGET_OS_IPHONE
    self.userInteractionEnabled = !value;
#endif
    [self refresh];
}
- (void)setChosen:(BOOL)value {
    _chosen = value;
    [self refresh];
}
- (void)setErrorMessage:(NSString*)value {
    _errorMessage = [value copy];
    [self refresh];
}
- (void)setEnabled:(BOOL)value {
    [super setEnabled:value];
    [self refresh];
}
@end

@implementation NeonField {
#if TARGET_OS_IPHONE
    UILabel* _errorLabel;
#else
    NSTextField* _errorLabel;
#endif
}
- (instancetype)initWithMultiline:(BOOL)multiline label:(NSString*)label {
    if ((self = [super initWithFrame:CGRectZero])) {
        _enabled = YES;
#if TARGET_OS_IPHONE
        self.axis = UILayoutConstraintAxisVertical;
        _singleLine = multiline ? nil : [UITextField new];
        _singleLine.placeholder = label;
        _multiline = multiline ? [UITextView new] : nil;
        UIView* editor = multiline ? _multiline : _singleLine;
        if (multiline) {
            _multiline.textContainerInset = UIEdgeInsetsMake(12, 12, 12, 12);
            _multiline.font = NeonUI(16);
            _multiline.textColor = NeonInk();
        } else {
            _singleLine.font = NeonUI(16);
            _singleLine.textColor = NeonInk();
        }
        editor.accessibilityLabel = label;
        if (!multiline) {
            UIView* padding = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 44)];
            _singleLine.leftView = padding;
            _singleLine.leftViewMode = UITextFieldViewModeAlways;
        }
        editor.backgroundColor = NeonPaper();
        _errorLabel = [UILabel new];
        _errorLabel.textColor = NeonDanger();
        _errorLabel.numberOfLines = 0;
#else
        self.orientation = NSUserInterfaceLayoutOrientationVertical;
        self.alignment = NSLayoutAttributeLeading;
        self.distribution = NSStackViewDistributionFill;
        [self setHuggingPriority:NSLayoutPriorityRequired
                  forOrientation:NSLayoutConstraintOrientationVertical];
        _singleLine = multiline ? nil : [NSTextField new];
        _multiline = multiline ? [NSTextView new] : nil;
        NSView* editor;
        if (multiline) {
            NSScrollView* scroll = [NSScrollView new];
            scroll.hasVerticalScroller = YES;
            _multiline.frame = NSMakeRect(0, 0, 400, 96);
            _multiline.minSize = NSMakeSize(0, 96);
            _multiline.maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
            _multiline.verticallyResizable = YES;
            _multiline.horizontallyResizable = NO;
            _multiline.textContainer.widthTracksTextView = YES;
            _multiline.autoresizingMask = NSViewWidthSizable;
            _multiline.font = NeonUI(16);
            _multiline.textColor = NeonInk();
            _multiline.backgroundColor = NeonPaper();
            _multiline.allowsUndo = YES;
            _multiline.textContainerInset = NSMakeSize(12, 12);
            _multiline.accessibilityLabel = label;
            scroll.documentView = _multiline;
            NSView* shell = [NSView new];
            scroll.translatesAutoresizingMaskIntoConstraints = NO;
            [shell addSubview:scroll];
            [NSLayoutConstraint activateConstraints:@[
                [scroll.leadingAnchor constraintEqualToAnchor:shell.leadingAnchor constant:1],
                [scroll.trailingAnchor constraintEqualToAnchor:shell.trailingAnchor constant:-1],
                [scroll.topAnchor constraintEqualToAnchor:shell.topAnchor constant:1],
                [scroll.bottomAnchor constraintEqualToAnchor:shell.bottomAnchor constant:-1]
            ]];
            editor = shell;
        } else {
            _singleLine.cell = [NeonFieldCell new];
            _singleLine.stringValue = @"";
            _singleLine.placeholderString = label;
            _singleLine.font = NeonUI(16);
            _singleLine.textColor = NeonInk();
            _singleLine.backgroundColor = NeonPaper();
            _singleLine.bordered = NO;
            _singleLine.accessibilityLabel = label;
            editor = _singleLine;
        }
        editor.wantsLayer = YES;
        _errorLabel = [NSTextField wrappingLabelWithString:@""];
        _errorLabel.textColor = NeonDanger();
#endif
        self.spacing = 8;
        editor.layer.cornerRadius = NeonFieldRadius;
        editor.layer.borderWidth = 1;
        editor.layer.borderColor = NeonLine().CGColor;
        if (multiline)
            [editor.heightAnchor constraintGreaterThanOrEqualToConstant:96].active = YES;
        else
            [editor.heightAnchor constraintEqualToConstant:52].active = YES;
        [self addArrangedSubview:editor];
        [self addArrangedSubview:_errorLabel];
        [editor.widthAnchor constraintEqualToAnchor:self.widthAnchor].active = YES;
        _errorLabel.hidden = YES;
#if TARGET_OS_IPHONE
        for (NSString* name in @[
                 UITextFieldTextDidBeginEditingNotification,
                 UITextFieldTextDidEndEditingNotification,
                 UITextViewTextDidBeginEditingNotification, UITextViewTextDidEndEditingNotification
             ])
#else
        for (NSString* name in @[
                 NSControlTextDidBeginEditingNotification, NSControlTextDidEndEditingNotification,
                 NSTextDidBeginEditingNotification, NSTextDidEndEditingNotification
             ])
#endif
            [NSNotificationCenter.defaultCenter addObserver:self
                                                   selector:@selector(refreshChrome)
                                                       name:name
                                                     object:nil];
    }
    return self;
}
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}
- (void)refreshChrome {
#if TARGET_OS_IPHONE
    BOOL focused = _singleLine.isFirstResponder || _multiline.isFirstResponder;
#else
    BOOL focused =
        self.window &&
        (self.window.firstResponder == _multiline ||
         (_singleLine.currentEditor && self.window.firstResponder == _singleLine.currentEditor));
#endif
    CALayer* border = self.arrangedSubviews.firstObject.layer;
    border.borderWidth = focused ? 2 : 1;
    border.borderColor = (self.errorMessage.length ? NeonDanger()
                          : focused                ? NeonAccent()
                                                   : NeonLine())
                             .CGColor;
}
#if TARGET_OS_IPHONE
- (void)traitCollectionDidChange:(UITraitCollection*)previous {
    [super traitCollectionDidChange:previous];
    [self refreshChrome];
}
#else
- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    [self refreshChrome];
}
#endif
- (void)setEnabled:(BOOL)value {
    _enabled = value;
    _singleLine.enabled = value;
    _multiline.editable = value;
#if TARGET_OS_IPHONE
    self.alpha = value ? 1 : .5;
#else
    self.alphaValue = value ? 1 : .5;
#endif
}
- (void)setErrorMessage:(NSString*)value {
    _errorMessage = [value copy];
#if TARGET_OS_IPHONE
    _errorLabel.text = value;
#else
    _errorLabel.stringValue = value ?: @"";
#endif
    _errorLabel.hidden = !value.length;
    [self refreshChrome];
}
@end

@implementation NeonNumericStepper {
#if TARGET_OS_IPHONE
    UILabel* _valueLabel;
#else
    NSTextField* _valueLabel;
#endif
}
- (instancetype)initWithLabel:(NSString*)label
                      minimum:(double)minimum
                      maximum:(double)maximum
                        value:(double)value {
    if ((self = [super initWithFrame:CGRectZero])) {
#if TARGET_OS_IPHONE
        _valueLabel = [UILabel new];
        _stepper = [UIStepper new];
        [_stepper addTarget:self
                      action:@selector(change:)
            forControlEvents:UIControlEventValueChanged];
        _stepper.accessibilityLabel = label;
#else
        self.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        _valueLabel = [NSTextField labelWithString:@""];
        _stepper = [NSStepper new];
        _stepper.target = self;
        _stepper.action = @selector(change:);
        _stepper.accessibilityLabel = label;
#endif
#if TARGET_OS_IPHONE
        _stepper.minimumValue = minimum;
        _stepper.maximumValue = maximum;
#else
        _stepper.minValue = minimum;
        _stepper.maxValue = maximum;
#endif
        self.spacing = 12;
        [self addArrangedSubview:_valueLabel];
        [self addArrangedSubview:_stepper];
        [_stepper.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
        [_stepper.widthAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
        [self.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
        self.value = value;
        self.enabled = YES;
    }
    return self;
}
- (double)value {
#if TARGET_OS_IPHONE
    return _stepper.value;
#else
    return _stepper.doubleValue;
#endif
}
- (void)setValue:(double)value {
#if TARGET_OS_IPHONE
    value = MIN(_stepper.maximumValue, MAX(_stepper.minimumValue, value));
#else
    value = MIN(_stepper.maxValue, MAX(_stepper.minValue, value));
#endif
#if TARGET_OS_IPHONE
    _stepper.value = value;
    _valueLabel.text = [NSString stringWithFormat:@"%g", value];
#else
    _stepper.doubleValue = value;
    _valueLabel.stringValue = [NSString stringWithFormat:@"%g", value];
#endif
}
- (void)setEnabled:(BOOL)value {
    _enabled = value;
    _stepper.enabled = value;
}
- (void)change:(id)sender {
    (void)sender;
    if (!self.enabled)
        return;
    self.value = self.value;
    if (self.valueChanged)
        self.valueChanged(self.value);
}
@end

#if TARGET_OS_IPHONE
@interface NeonControlCatalog : UIStackView
#else
@interface NeonControlCatalog : NSStackView
#endif
@property(nonatomic) NSInteger activations;
@property(nonatomic) BOOL dark;
@property(nonatomic) NSInteger fieldPhase;
@property(nonatomic, strong) NSMutableArray<NeonField*>* fields;
@property(nonatomic, strong) NeonButton* counter;
- (void)activate:(id)sender;
- (void)theme:(id)sender;
- (void)fieldStates:(id)sender;
- (void)select:(NeonButton*)sender;
@end
@implementation NeonControlCatalog
#if !TARGET_OS_IPHONE
- (BOOL)isFlipped {
    return YES;
}
- (void)drawRect:(NSRect)rect {
    [NeonPaper() setFill];
    NSRectFill(rect);
}
- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    self.needsDisplay = YES;
}
#endif
- (void)activate:(id)sender {
    (void)sender;
    self.activations++;
    NSString* title = [NSString stringWithFormat:@"Activations: %ld", (long)self.activations];
#if TARGET_OS_IPHONE
    [self.counter setTitle:title forState:UIControlStateNormal];
#else
    self.counter.title = title;
#endif
}
- (void)fieldStates:(id)sender {
    (void)sender;
    self.fieldPhase = (self.fieldPhase + 1) % 3;
    for (NeonField* field in self.fields) {
        field.errorMessage = self.fieldPhase == 1 ? @"Required value" : @"";
        field.enabled = self.fieldPhase != 2;
    }
}
- (void)select:(NeonButton*)sender {
    sender.chosen = !sender.chosen;
}
- (void)theme:(id)sender {
    (void)sender;
    self.dark = !self.dark;
#if TARGET_OS_IPHONE
    self.window.overrideUserInterfaceStyle =
        self.dark ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
#else
    self.window.appearance =
        [NSAppearance appearanceNamed:self.dark ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua];
#endif
}
@end
#if TARGET_OS_IPHONE
UIView* NeonControlStateFixture() {
    UIScrollView* scroll = [UIScrollView new];
#else
NSView* NeonControlStateFixture() {
    NSScrollView* scroll = [NSScrollView new];
    scroll.hasVerticalScroller = YES;
#endif
    NeonControlCatalog* column = [NeonControlCatalog new];
#if TARGET_OS_IPHONE
    column.axis = UILayoutConstraintAxisVertical;
    column.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:column];
    [NSLayoutConstraint activateConstraints:@[
        [column.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor
                                             constant:16],
        [column.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor
                                              constant:-16],
        [column.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:16],
        [column.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor
                                            constant:-32],
        [column.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor
                                           constant:-32]
    ]];
#else
    column.orientation = NSUserInterfaceLayoutOrientationVertical;
    column.distribution = NSStackViewDistributionFill;
    column.frame = NSMakeRect(0, 0, 520, 900);
    scroll.documentView = column;
#endif
    column.spacing = 12;
    column.fields = [NSMutableArray array];
    for (NSString* state in @[
             @"Activations: 0", @"Secondary", @"Selected", @"Loading", @"Disabled", @"Retry save",
             @"Change theme", @"Field states"
         ]) {
        NeonButton* button = [NeonButton new];
#if TARGET_OS_IPHONE
        [button setTitle:state forState:UIControlStateNormal];
        button.accessibilityIdentifier = state;
#else
        button.title = state;
        button.accessibilityIdentifier = state;
#endif
        button.kind = [state isEqual:@"Selected"]    ? NeonButtonSelection
                      : [state isEqual:@"Secondary"] ? NeonButtonSecondary
                                                     : NeonButtonPrimary;
        button.chosen = button.kind == NeonButtonSelection;
        button.loading = [state isEqual:@"Loading"];
        button.enabled = ![state isEqual:@"Disabled"];
        if ([state isEqual:@"Retry save"])
            button.errorMessage = @"Retry save";
        SEL action = [state isEqual:@"Field states"]   ? @selector(fieldStates:)
                     : [state isEqual:@"Change theme"] ? @selector(theme:)
                     : button.chosen                   ? @selector(select:)
                                                       : @selector(activate:);
#if TARGET_OS_IPHONE
        [button addTarget:column action:action forControlEvents:UIControlEventTouchUpInside];
#else
        button.target = column;
        button.action = action;
#endif
        if (!column.counter)
            column.counter = button;
        [column addArrangedSubview:button];
    }
    for (NSNumber* multi in @[ @NO, @YES ]) {
        NeonField* field = [[NeonField alloc]
            initWithMultiline:multi.boolValue
                        label:multi.boolValue ? @"Description" : @"Project title"];
        [column.fields addObject:field];
        [column addArrangedSubview:field];
        if (multi.boolValue) {
#if TARGET_OS_IPHONE
            field.multiline.text = @"Native multiline description";
#else
            field.multiline.string = @"Native multiline description";
#endif
            [field.heightAnchor constraintEqualToConstant:140].active = YES;
        }
#if !TARGET_OS_IPHONE
        [field.widthAnchor constraintEqualToConstant:440].active = YES;
#endif
    }
    [column addArrangedSubview:[[NeonNumericStepper alloc] initWithLabel:@"Text size"
                                                                 minimum:16
                                                                 maximum:32
                                                                   value:20]];
#if !TARGET_OS_IPHONE
    NSView* clearance = [NSView new];
    [clearance.heightAnchor constraintGreaterThanOrEqualToConstant:NeonScrollBottomClearance]
        .active = YES;
    [column addArrangedSubview:clearance];
#endif
    return scroll;
}
