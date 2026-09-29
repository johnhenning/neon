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
NeonFont* NeonSerif(CGFloat size);
NeonFont* NeonUI(CGFloat size);
CGFloat NeonTextSize();
CGFloat NeonLineSpacing();
NSInteger NeonAppearance();

NeonFont* NeonManuscriptFont(CGFloat size);
NSString* NeonFontChoice();
