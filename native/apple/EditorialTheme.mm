#include "EditorialTheme.h"
#import "Controls.h"
#import "Preferences.h"
#import <CoreText/CoreText.h>
#import <objc/runtime.h>

namespace {
NeonColor* tone(CGFloat r, CGFloat g, CGFloat b, CGFloat dr, CGFloat dg, CGFloat db,
                CGFloat alpha = 1, CGFloat darkAlpha = 1) {
#if TARGET_OS_IPHONE
    return [UIColor colorWithDynamicProvider:^UIColor*(UITraitCollection* traits) {
      BOOL dark = traits.userInterfaceStyle == UIUserInterfaceStyleDark;
      return [UIColor colorWithRed:dark ? dr : r
                             green:dark ? dg : g
                              blue:dark ? db : b
                             alpha:dark ? darkAlpha : alpha];
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
                                     alpha:dark ? darkAlpha : alpha];
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
    return tone(249.0 / 255, 246.0 / 255, 239.0 / 255, 32.0 / 255, 34.0 / 255, 31.0 / 255);
}
NeonColor* NeonPanel() {
    return tone(243.0 / 255, 239.0 / 255, 231.0 / 255, 39.0 / 255, 41.0 / 255, 37.0 / 255);
}
NeonColor* NeonInk() {
    return tone(32.0 / 255, 30.0 / 255, 25.0 / 255, 237.0 / 255, 231.0 / 255, 218.0 / 255);
}
NeonColor* NeonMuted() {
    return tone(99.0 / 255, 94.0 / 255, 84.0 / 255, 184.0 / 255, 181.0 / 255, 170.0 / 255);
}
NeonColor* NeonAccent() {
    return tone(117.0 / 255, 82.0 / 255, 38.0 / 255, 199.0 / 255, 163.0 / 255, 103.0 / 255);
}
NeonColor* NeonSelection() {
    return tone(117.0 / 255, 82.0 / 255, 38.0 / 255, 199.0 / 255, 163.0 / 255, 103.0 / 255, .12,
                .12);
}
NeonColor* NeonLine() {
    return tone(32.0 / 255, 30.0 / 255, 25.0 / 255, 237.0 / 255, 231.0 / 255, 218.0 / 255,
                36.0 / 255, 36.0 / 255);
}
NeonColor* NeonDanger() {
    return tone(.630, .200, .160, .950, .530, .460);
}
NeonColor* NeonActionText() {
    return NeonPaper();
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
    return regular([NeonFont fontWithName:@"SourceSans3-Roman" size:size]
                       ?: [NeonFont systemFontOfSize:size],
                   size);
}
NeonFont* NeonUISemibold(CGFloat size) {
    NeonFont* font = NeonUI(size);
    NSDictionary* axes = @{@(0x77676874) : @600};
    return [NeonFont fontWithDescriptor:[font.fontDescriptor fontDescriptorByAddingAttributes:@{
                         (__bridge NSString*)kCTFontVariationAttribute : axes
                     }]
                                   size:size]
               ?: font;
}
NeonFont* NeonUIBold(CGFloat size) {
    NeonFont* font = NeonUI(size);
    NSDictionary* axes = @{@(0x77676874) : @700};
    return [NeonFont fontWithDescriptor:[font.fontDescriptor fontDescriptorByAddingAttributes:@{
                         (__bridge NSString*)kCTFontVariationAttribute : axes
                     }]
                                   size:size]
               ?: font;
}
BOOL NeonReduceMotion() {
#if TARGET_OS_IPHONE
    BOOL system = UIAccessibilityIsReduceMotionEnabled();
#else
    BOOL system = NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion;
#endif
    return system || [NeonPreferences() boolForKey:@"reduceMotion"];
}
BOOL NeonReduceTransparency() {
#if TARGET_OS_IPHONE
    BOOL system = UIAccessibilityIsReduceTransparencyEnabled();
#else
    BOOL system = NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceTransparency;
#endif
    return system || [NeonPreferences() boolForKey:@"reduceTransparency"];
}
BOOL NeonGlassEnabled() {
    NSNumber* enabled = [NeonPreferences() objectForKey:@"liquidGlass"];
    return (!enabled || enabled.boolValue) && !NeonReduceTransparency();
}
CGFloat NeonTextSize() {
    return NeonTextSizeForViewport(0);
}
CGFloat NeonTextSizeForViewport(CGFloat width) {
#if !TARGET_OS_IPHONE
    (void)width;
#endif
    double size = [NeonPreferences() doubleForKey:@"manuscriptSize"];
    return size >= 16 && size <= 32 ? size :
#if TARGET_OS_IPHONE
                                    (width > 600 ? 19 : 17);
#else
                                    19;
#endif
}
CGFloat NeonLineSpacing() {
    double spacing = [NeonPreferences() doubleForKey:@"manuscriptSpacing"];
    return spacing >= 2 && spacing <= 16 ? spacing : 8;
}
NSInteger NeonAppearance() {
    return [NeonPreferences() integerForKey:@"appearance"];
}

NSString* NeonFontChoice() {
    return [NeonPreferences() stringForKey:@"manuscriptFont"] ?: @"Literata";
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
    NSNumber* value = [NeonPreferences() objectForKey:@"paragraphSpacing"];
    return value && value.doubleValue >= 0 && value.doubleValue <= 24 ? value.doubleValue : 4;
}
CGFloat NeonTextMeasure() {
    double value = [NeonPreferences() doubleForKey:@"textMeasure"];
    return value >= 480 && value <= 960 ? value : 760;
}
BOOL NeonWritingPreference(NSString* key) {
    NSNumber* value = [NeonPreferences() objectForKey:key];
    return value ? value.boolValue : YES;
}

#if TARGET_OS_IPHONE
UIView* NeonPillSelector(NSArray<NSString*>* titles, NSInteger selected, id target, SEL action) {
    UIStackView* stack = [UIStackView new];
#else
NSView* NeonPillSelector(NSArray<NSString*>* titles, NSInteger selected, id target, SEL action) {
    NSStackView* stack = [NSStackView new];
#endif
    stack.spacing = NeonBreadcrumbGap;
    for (NSUInteger i = 0; i < titles.count; ++i) {
        NeonButton* button = [NeonButton new];
        button.kind = NeonButtonSelection;
        button.chosen = (NSInteger)i == selected;
        button.tag = i;
#if TARGET_OS_IPHONE
        [button setTitle:titles[i] forState:UIControlStateNormal];
        [button setNeedsUpdateConfiguration];
        [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
#else
        button.title = titles[i];
        button.target = target;
        button.action = action;
        button.state = (NSInteger)i == selected ? NSControlStateValueOn : NSControlStateValueOff;
#endif
        [stack addArrangedSubview:button];
    }
    return stack;
}

#if !TARGET_OS_IPHONE
API_AVAILABLE(macos(26.0))
@interface NeonGlassBackdrop : NSGlassEffectView
@end
@implementation NeonGlassBackdrop
- (NSView*)hitTest:(NSPoint)point {
    (void)point;
    return nil;
}
@end
#endif
static char NeonGlassBackdropKey;
#if TARGET_OS_IPHONE
void NeonApplyGlassBackdrop(UIView* view, CGFloat radius) {
    UIView* previous = objc_getAssociatedObject(view, &NeonGlassBackdropKey);
    if (previous && NeonGlassEnabled()) {
        previous.frame = view.bounds;
        previous.layer.cornerRadius = radius;
        return;
    }
    [previous removeFromSuperview];
    objc_setAssociatedObject(view, &NeonGlassBackdropKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    view.backgroundColor = NeonPanel();
    if (!NeonGlassEnabled())
        return;
    if (@available(iOS 26.0, *)) {
        UIGlassEffect* effect = [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular];
        effect.tintColor = [NeonPanel() colorWithAlphaComponent:.35];
        UIVisualEffectView* glass = [[UIVisualEffectView alloc] initWithEffect:effect];
        glass.frame = view.bounds;
        glass.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        glass.userInteractionEnabled = NO;
        glass.layer.cornerRadius = radius;
        glass.clipsToBounds = YES;
        [view insertSubview:glass atIndex:0];
        objc_setAssociatedObject(view, &NeonGlassBackdropKey, glass,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
#else
void NeonApplyGlassBackdrop(NSView* view, CGFloat radius) {
    NSView* previous = objc_getAssociatedObject(view, &NeonGlassBackdropKey);
    if (previous && NeonGlassEnabled()) {
        previous.frame = view.bounds;
        view.layer.backgroundColor = NeonPanel().CGColor;
        if (@available(macOS 26.0, *)) {
            NeonGlassBackdrop* glass = (NeonGlassBackdrop*)previous;
            glass.cornerRadius = radius;
            glass.tintColor = [NeonPanel() colorWithAlphaComponent:.35];
        }
        return;
    }
    [previous removeFromSuperview];
    objc_setAssociatedObject(view, &NeonGlassBackdropKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    view.wantsLayer = YES;
    view.layer.backgroundColor = NeonPanel().CGColor;
    if (!NeonGlassEnabled())
        return;
    if (@available(macOS 26.0, *)) {
        NeonGlassBackdrop* glass = [[NeonGlassBackdrop alloc] initWithFrame:view.bounds];
        glass.style = NSGlassEffectViewStyleRegular;
        glass.tintColor = [NeonPanel() colorWithAlphaComponent:.35];
        glass.cornerRadius = radius;
        glass.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [view addSubview:glass positioned:NSWindowBelow relativeTo:nil];
        objc_setAssociatedObject(view, &NeonGlassBackdropKey, glass,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}
#endif
