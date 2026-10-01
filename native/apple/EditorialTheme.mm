#include "EditorialTheme.h"
#import <CoreText/CoreText.h>

namespace {
NeonColor* tone(CGFloat r, CGFloat g, CGFloat b, CGFloat dr, CGFloat dg, CGFloat db) {
#if TARGET_OS_IPHONE
    return [UIColor colorWithDynamicProvider:^UIColor*(UITraitCollection* traits) {
      BOOL dark = traits.userInterfaceStyle == UIUserInterfaceStyleDark;
      return [UIColor colorWithRed:dark ? dr : r green:dark ? dg : g blue:dark ? db : b alpha:1];
    }];
#else
    return [NSColor
          colorWithName:nil
        dynamicProvider:^NSColor*(NSAppearance* appearance) {
          BOOL dark = [[appearance
              bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]]
              isEqualToString:NSAppearanceNameDarkAqua];
          return [NSColor colorWithSRGBRed:dark ? dr : r
                                     green:dark ? dg : g
                                      blue:dark ? db : b
                                     alpha:1];
        }];
#endif
}
NeonFont* regular(NeonFont* font, CGFloat size) {
    NSDictionary* axes = @{@(0x77676874) : @400, @(0x6f70737a) : @(size)};
    auto descriptor = [font.fontDescriptor
        fontDescriptorByAddingAttributes:@{(__bridge NSString*)kCTFontVariationAttribute : axes}];
    return [NeonFont fontWithDescriptor:descriptor size:size] ?: font;
}
} // namespace
void NeonRegisterFonts() {
    for (NSString* name in @[ @"literata", @"sourcesans3" ]) {
        NSURL* url = [NSBundle.mainBundle URLForResource:name withExtension:@"ttf"];
        if (url)
            CTFontManagerRegisterFontsForURL((__bridge CFURLRef)url, kCTFontManagerScopeProcess,
                                             nullptr);
    }
}
NeonColor* NeonPaper() {
    return tone(249.0 / 255, 246.0 / 255, 239.0 / 255, 0.125, 0.128, 0.120);
}
NeonColor* NeonPanel() {
    return tone(0.953, 0.937, 0.906, 0.155, 0.158, 0.150);
}
NeonColor* NeonInk() {
    return tone(0.125, 0.116, 0.098, 0.94, 0.925, 0.89);
}
NeonColor* NeonMuted() {
    return tone(0.39, 0.37, 0.33, 0.70, 0.69, 0.65);
}
NeonColor* NeonAccent() {
    return tone(0.46, 0.32, 0.15, 0.80, 0.67, 0.45);
}
NeonFont* NeonSerif(CGFloat size) {
#if TARGET_OS_IPHONE
    return regular([UIFont fontWithName:@"Literata-Regular" size:size]
                       ?: [UIFont fontWithName:@"Georgia" size:size],
                   size);
#else
    return regular([NSFont fontWithName:@"Literata-Regular" size:size]
                       ?: [NSFont fontWithName:@"Georgia" size:size],
                   size);
#endif
}
NeonFont* NeonUI(CGFloat size) {
    return [NeonFont systemFontOfSize:size];
}
CGFloat NeonTextSize() {
    double size = [NSUserDefaults.standardUserDefaults doubleForKey:@"manuscriptSize"];
    return size >= 16 && size <= 32 ? size :
#if TARGET_OS_IPHONE
                                    18;
#else
                                    20;
#endif
}
CGFloat NeonLineSpacing() {
    double spacing = [NSUserDefaults.standardUserDefaults doubleForKey:@"manuscriptSpacing"];
    return spacing >= 2 && spacing <= 16 ? spacing : 8;
}
NSInteger NeonAppearance() {
    return [NSUserDefaults.standardUserDefaults integerForKey:@"appearance"];
}

NSString* NeonFontChoice() {
    return [NSUserDefaults.standardUserDefaults stringForKey:@"manuscriptFont"] ?: @"Literata";
}
NeonFont* NeonFontNamed(NSString* choice, CGFloat size) {
    if ([choice isEqualToString:@"Source Sans 3"])
        return regular([NeonFont fontWithName:@"SourceSans3-Roman" size:size] ?: NeonUI(size),
                       size);
    if ([choice isEqualToString:@"System Serif"]) {
#if TARGET_OS_IPHONE
        UIFontDescriptor* descriptor = [[UIFont systemFontOfSize:size].fontDescriptor
            fontDescriptorWithDesign:UIFontDescriptorSystemDesignSerif];
        return [UIFont fontWithDescriptor:descriptor size:size];
#else
        NSFontDescriptor* descriptor = [[NSFont systemFontOfSize:size].fontDescriptor
            fontDescriptorWithDesign:NSFontDescriptorSystemDesignSerif];
        return [NSFont fontWithDescriptor:descriptor size:size];
#endif
    }
    return NeonSerif(size);
}

NeonFont* NeonManuscriptFont(CGFloat size) {
    return NeonFontNamed(NeonFontChoice(), size);
}
CGFloat NeonParagraphSpacing() {
    NSNumber* value = [NSUserDefaults.standardUserDefaults objectForKey:@"paragraphSpacing"];
    return value && value.doubleValue >= 0 && value.doubleValue <= 24 ? value.doubleValue : 4;
}
CGFloat NeonTextMeasure() {
    double value = [NSUserDefaults.standardUserDefaults doubleForKey:@"textMeasure"];
    return value >= 480 && value <= 960 ? value : 640;
}
BOOL NeonWritingPreference(NSString* key) {
    NSNumber* value = [NSUserDefaults.standardUserDefaults objectForKey:key];
    return value ? value.boolValue : YES;
}

#if !TARGET_OS_IPHONE
@interface NeonPillTrack : NSStackView
@end
@implementation NeonPillTrack
- (void)drawRect:(NSRect)rect {
    (void)rect;
    [NeonPanel() setFill];
    [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:18 yRadius:18] fill];
}
- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    self.needsDisplay = YES;
}
@end
@interface NeonPillButton : NSButton
@end
@implementation NeonPillButton
- (void)drawRect:(NSRect)rect {
    (void)rect;
    BOOL selected = self.state == NSControlStateValueOn;
    [(selected ? [NeonAccent() colorWithAlphaComponent:0.22] : NSColor.clearColor) setFill];
    [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds, 1, 1) xRadius:16
                                     yRadius:16] fill];
    NSDictionary* attributes = @{
        NSFontAttributeName : NeonUI(14),
        NSForegroundColorAttributeName : selected ? NeonAccent() : NeonMuted()
    };
    NSSize size = [self.title sizeWithAttributes:attributes];
    [self.title drawAtPoint:NSMakePoint((self.bounds.size.width - size.width) / 2,
                                        (self.bounds.size.height - size.height) / 2)
             withAttributes:attributes];
}
- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    self.needsDisplay = YES;
}
@end
#endif
#if TARGET_OS_IPHONE
UIView* NeonPillSelector(NSArray<NSString*>* titles, NSInteger selected, id target, SEL action) {
    UIStackView* stack = [UIStackView new];
    stack.backgroundColor = NeonPanel();
    stack.layer.cornerRadius = 18;
    stack.layoutMargins = UIEdgeInsetsMake(2, 2, 2, 2);
    stack.layoutMarginsRelativeArrangement = YES;
    stack.spacing = 0;
    for (NSUInteger i = 0; i < titles.count; ++i) {
        UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
        UIButtonConfiguration* config = UIButtonConfiguration.filledButtonConfiguration;
        config.title = titles[i];
        config.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        config.baseBackgroundColor =
            i == selected ? [NeonAccent() colorWithAlphaComponent:0.22] : UIColor.clearColor;
        config.baseForegroundColor = i == selected ? NeonAccent() : NeonMuted();
        config.contentInsets = NSDirectionalEdgeInsetsMake(7, 16, 7, 16);
        button.configuration = config;
        button.tag = i;
        button.accessibilityTraits =
            UIAccessibilityTraitButton | (i == selected ? UIAccessibilityTraitSelected : 0);
        [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:button];
    }
    return stack;
}
#else
NSView* NeonPillSelector(NSArray<NSString*>* titles, NSInteger selected, id target, SEL action) {
    NSStackView* stack = [NeonPillTrack new];
    stack.edgeInsets = NSEdgeInsetsMake(2, 2, 2, 2);
    stack.spacing = 0;
    for (NSUInteger i = 0; i < titles.count; ++i) {
        NeonPillButton* button = [NeonPillButton new];
        button.title = titles[i];
        button.bordered = NO;
        button.target = target;
        button.action = action;
        button.tag = i;
        button.state = i == selected ? NSControlStateValueOn : NSControlStateValueOff;
        button.accessibilityValue = i == selected ? @"Selected" : @"Not selected";
        [button.widthAnchor constraintEqualToConstant:MAX(90, [titles[i] sizeWithAttributes:@{
                                                                  NSFontAttributeName : NeonUI(14)
                                                              }]
                                                                      .width +
                                                                  32)]
            .active = YES;
        [button.heightAnchor constraintEqualToConstant:34].active = YES;
        [stack addArrangedSubview:button];
    }
    return stack;
}
#endif
