#pragma once
#import "Controls.h"
#import "InlineTitle.h"

// Chapter-only adapter: toolbar and sidebar titles retain single-line behavior.
@interface NeonChapterHeading : NeonInlineTitle
@end

@interface NeonWorkspaceController : NSViewController
@property(nonatomic, readonly) NSScrollView* scrollView;
@property(nonatomic, readonly) NSTextView* editor;
@property(nonatomic, readonly) NeonChapterHeading* heading;
@property(nonatomic, readonly) NSTextField* kicker;
@property(nonatomic, readonly) NSTextField* guidance;
@property(nonatomic, readonly) NSTextField* status;
@property(nonatomic, readonly) NSView* sessionSlot;
@property(nonatomic) CGFloat textMeasure;
@property(nonatomic) CGFloat contentInset;
@property(nonatomic) CGFloat bodyBaselineAdjustment;
- (instancetype)initWithEditor:(NSTextView*)editor;
- (void)refreshLayout;
@end
