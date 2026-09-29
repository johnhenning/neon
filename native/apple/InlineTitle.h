#pragma once
#import "EditorialTheme.h"
#if TARGET_OS_IPHONE
@interface NeonInlineTitle : UITextField <UITextFieldDelegate>
#else
@interface NeonInlineTitle : NSTextField <NSTextFieldDelegate>
@property(nonatomic, copy) void (^contextAction)(NSView*, NSRect);
#endif
@property(nonatomic, copy) BOOL (^commitTitle)(NSString*);
@property(nonatomic, copy) void (^activateTitle)(void);
- (void)beginRenaming;
- (BOOL)finishRenaming:(BOOL)commit;
@end
