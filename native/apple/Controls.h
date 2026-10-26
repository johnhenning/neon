#pragma once
#import "DesignMetrics.h"
#import "EditorialTheme.h"

typedef NS_ENUM(NSInteger, NeonButtonKind) {
    NeonButtonPrimary,
    NeonButtonSecondary,
    NeonButtonQuiet,
    NeonButtonSelection
};
#if TARGET_OS_IPHONE
@interface NeonButton : UIButton
#else
@interface NeonButton : NSButton
#endif
@property(nonatomic) NeonButtonKind kind;
// Compact desktop actions retain the standard 44pt target on touch platforms.
@property(nonatomic) BOOL compact;
@property(nonatomic) BOOL loading;
@property(nonatomic, copy) NSString* errorMessage;
@property(nonatomic) BOOL chosen;
@end

// Native editors are public so callers retain delegates, selection and undo/IME APIs.
#if TARGET_OS_IPHONE
@interface NeonField : UIStackView
@property(nonatomic, readonly) UITextField* singleLine;
@property(nonatomic, readonly) UITextView* multiline;
#else
@interface NeonField : NSStackView
@property(nonatomic, readonly) NSTextField* singleLine;
@property(nonatomic, readonly) NSTextView* multiline;
#endif
- (instancetype)initWithMultiline:(BOOL)multiline label:(NSString*)label;
@property(nonatomic) BOOL enabled;
@property(nonatomic, copy) NSString* errorMessage;
@end
#if TARGET_OS_IPHONE
@interface NeonNumericStepper : UIStackView
@property(nonatomic, readonly) UIStepper* stepper;
#else
@interface NeonNumericStepper : NSStackView
@property(nonatomic, readonly) NSStepper* stepper;
#endif
- (instancetype)initWithLabel:(NSString*)label
                      minimum:(double)minimum
                      maximum:(double)maximum
                        value:(double)value;
@property(nonatomic) double value;
@property(nonatomic) BOOL enabled;
@property(nonatomic, copy) void (^valueChanged)(double);
@end

// Isolated, non-persistent component catalog; launch with --control-states.
#if TARGET_OS_IPHONE
UIView* NeonControlStateFixture();
#else
NSView* NeonControlStateFixture();
// Shared full-width sidebar selection and divider treatment.
void NeonDrawSidebarRow(NSView* view, BOOL selected);
#endif
