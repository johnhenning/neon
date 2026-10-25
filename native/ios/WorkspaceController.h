#pragma once
#import <UIKit/UIKit.h>

#import "WorkspaceRoute.h"

// Multiline chapter-only input. Toolbar and list titles remain single-line.
@interface NeonChapterHeading : UITextView <UITextViewDelegate>
@property(nonatomic, copy) BOOL (^commitTitle)(NSString*);
@property(nonatomic, copy) void (^activateTitle)(void);
@property(nonatomic, copy) void (^heightChanged)(void);
- (void)beginRenaming;
- (BOOL)finishRenaming:(BOOL)commit;
@end

@interface NeonWorkspaceController : UIViewController
@property(nonatomic, strong, readonly) UIView* sessionSlot;
@property(nonatomic, copy) BOOL (^routeDestination)(NeonWorkspaceDestination, NSString*);
- (void)showDestination:(NeonWorkspaceDestination)destination sectionID:(NSString*)sectionID;
@end

BOOL NeonWorkspaceSmoke(NeonChapterHeading* heading, UITextView* manuscript);

void NeonWorkspaceCompositionSmoke(UITextView* (^manuscript)(void),
                                   void (^requestTypography)(BOOL wide),
                                   BOOL (^hasPendingTypography)(void), void (^completion)(BOOL));
