#pragma once
#import "EditorialTheme.h"

#if TARGET_OS_IPHONE
@interface NeonSettingsController : UITableViewController <UISearchResultsUpdating>
#else
@interface NeonSettingsController : NSViewController <NSSearchFieldDelegate>
#endif
@property(nonatomic, copy) void (^preferencesChanged)(void);
- (void)filterSettings:(NSString*)query;
@property(nonatomic, readonly) NSUInteger visibleSettingCount;
@end
