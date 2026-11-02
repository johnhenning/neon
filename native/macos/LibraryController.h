#pragma once
#import "LibraryPresentation.h"
#import <AppKit/AppKit.h>
NS_ASSUME_NONNULL_BEGIN
// Host owns persistence/session coordination. Every action carries the stable record.
@interface NeonLibraryController : NSViewController
@property(nonatomic, readonly) NeonLibraryQuery* query;
@property(nonatomic, readonly) NeonLibraryPresentation* presentation;
@property(nonatomic, copy, nullable) NSString* selectedProjectID;
@property(nonatomic, copy, nullable) void (^onAction)
    (NSString* action, NSDictionary* _Nullable record);
@property(nonatomic, copy, nullable) void (^onFilterChanged)(NeonLibraryFilter filter);
// Explicit testing/preview identity association; never inferred from titles.
@property(nonatomic, copy) NSDictionary<NSString*, NSString*>* fixtureIDs;
@property(nonatomic, readonly) NSView* sidebarView;
- (NSMenu*)navigationMenu;
- (void)updateWithRecords:(nullable NSArray<NSDictionary*>*)records error:(nullable NSError*)error;
- (void)selectFilter:(NeonLibraryFilter)filter;
- (void)setLibraryView:(NeonLibraryView)view;
@end
NS_ASSUME_NONNULL_END
