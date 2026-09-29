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
    return tone(0.978, 0.965, 0.937, 0.125, 0.128, 0.120);
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
    return [UIFont fontWithName:@"Literata-Regular" size:size]
               ?: [UIFont fontWithName:@"Georgia" size:size];
#else
    return [NSFont fontWithName:@"Literata-Regular" size:size]
               ?: [NSFont fontWithName:@"Georgia" size:size];
#endif
}
NeonFont* NeonUI(CGFloat size) {
#if TARGET_OS_IPHONE
    return [UIFont fontWithName:@"SourceSans3-Roman" size:size] ?: [UIFont systemFontOfSize:size];
#else
    return [NSFont fontWithName:@"SourceSans3-Roman" size:size] ?: [NSFont systemFontOfSize:size];
#endif
}
CGFloat NeonTextSize() {
    double size = [NSUserDefaults.standardUserDefaults doubleForKey:@"manuscriptSize"];
    return size >= 16 && size <= 32 ? size : 22;
}
CGFloat NeonLineSpacing() {
    double spacing = [NSUserDefaults.standardUserDefaults doubleForKey:@"manuscriptSpacing"];
    return spacing >= 2 && spacing <= 16 ? spacing : 8;
}
NSInteger NeonAppearance() {
    return [NSUserDefaults.standardUserDefaults integerForKey:@"appearance"];
}
