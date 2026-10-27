#pragma once
#import "EditorialTheme.h"

#if TARGET_OS_IPHONE
@interface NeonSettingsController
    : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating>
@property(nonatomic, strong) UITableView* tableView;
#else
@interface NeonSettingsController : NSViewController <NSSearchFieldDelegate>
#endif
@property(nonatomic, copy) void (^preferencesChanged)(void);
@property(nonatomic, copy) void (^showHistory)(void);
@property(nonatomic, copy) void (^closeSettings)(void);
- (void)filterSettings:(NSString*)query;
@property(nonatomic, readonly) NSUInteger visibleSettingCount;
@end
