#pragma once
#import <TargetConditionals.h>
#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
using NeonColor = UIColor;
using NeonFont = UIFont;
#else
#import <AppKit/AppKit.h>
using NeonColor = NSColor;
using NeonFont = NSFont;
#endif
void NeonRegisterFonts();
NeonColor* NeonPaper();
NeonColor* NeonPanel();
NeonColor* NeonInk();
NeonColor* NeonMuted();
NeonColor* NeonAccent();
NeonColor* NeonSelection();
NeonColor* NeonLine();
NeonColor* NeonDanger();
NeonColor* NeonActionText();
NeonFont* NeonSerif(CGFloat size);
NeonFont* NeonUI(CGFloat size);
NeonFont* NeonUISemibold(CGFloat size);
BOOL NeonReduceMotion();
BOOL NeonReduceTransparency();
BOOL NeonGlassEnabled();
#if TARGET_OS_IPHONE
void NeonApplyGlassBackdrop(UIView* view, CGFloat radius);
#else
void NeonApplyGlassBackdrop(NSView* view, CGFloat radius);
#endif
CGFloat NeonTextSize();
CGFloat NeonLineSpacing();
NSInteger NeonAppearance();

NeonFont* NeonManuscriptFont(CGFloat size);
NSString* NeonFontChoice();

NeonFont* NeonFontNamed(NSString* name, CGFloat size);
CGFloat NeonParagraphSpacing();
CGFloat NeonTextMeasure();
BOOL NeonWritingPreference(NSString* key);

#if TARGET_OS_IPHONE
UIView* NeonPillSelector(NSArray<NSString*>* titles, NSInteger selected, id target, SEL action);
#else
NSView* NeonPillSelector(NSArray<NSString*>* titles, NSInteger selected, id target, SEL action);
#endif
