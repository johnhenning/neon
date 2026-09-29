#pragma once
#import "EditorialTheme.h"
@interface NeonMenuAction : NSObject
@property(nonatomic, copy) NSString* title;
@property(nonatomic, copy) NSString* symbol;
@property(nonatomic, copy) void (^perform)(void);
@property(nonatomic) BOOL enabled;
@property(nonatomic) BOOL destructive;
@end
NeonMenuAction* NeonAction(NSString* title, NSString* symbol, BOOL enabled, BOOL destructive,
                           void (^perform)(void));
#if TARGET_OS_IPHONE
void NeonShowMenu(UIViewController* host, UIView* anchor, CGRect rect,
                  NSArray<NeonMenuAction*>* actions);
#else
void NeonShowMenu(NSView* anchor, NSRect rect, NSArray<NeonMenuAction*>* actions);
#endif

void NeonDismissMenu();
