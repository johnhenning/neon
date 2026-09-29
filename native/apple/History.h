#pragma once
#import "DocumentSession.h"
#import <TargetConditionals.h>
#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
@interface NeonHistoryController
    : NSViewController <NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate>
#else
#import <UIKit/UIKit.h>
@interface NeonHistoryController
    : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
#endif
@property(nonatomic, strong) NeonDocumentSession* session;
@property(nonatomic, copy) void (^didRestore)(void);
@property(nonatomic, copy) void (^showEditor)(void);
- (void)reloadHistory;
- (void)selectRevisionAtIndex:(NSUInteger)index;
@end
