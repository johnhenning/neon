#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, NeonLibraryFilter) {
    NeonLibraryAll,
    NeonLibraryRecent,
    NeonLibraryFavorites,
    NeonLibraryDevice,
    NeonLibraryTrash
};
typedef NS_ENUM(NSInteger, NeonLibraryView) { NeonLibraryGrid, NeonLibraryList };
typedef NS_ENUM(NSInteger, NeonLibrarySort) {
    NeonLibraryModified,
    NeonLibraryTitle,
    NeonLibraryLastOpened
};
@interface NeonLibraryQuery : NSObject
@property(nonatomic) NeonLibraryFilter filter;
@property(nonatomic) NeonLibraryView view;
@property(nonatomic) NeonLibrarySort sort;
- (void)savePreferences;
@end
// Immutable projection; a failed enumeration has an error and never means empty.
@interface NeonLibraryPresentation : NSObject
@property(nonatomic, readonly) NSArray<NSDictionary*>* records;
@property(nonatomic, readonly, nullable) NSError* error;
@property(nonatomic, readonly, nullable) NSString* selectedProjectID;
- (instancetype)initWithRecords:(nullable NSArray<NSDictionary*>*)records
                          error:(nullable NSError*)error
                          query:(NeonLibraryQuery*)query
              selectedProjectID:(nullable NSString*)selectedProjectID
                            now:(NSDate*)now;
// Explicit fixture identity -> manifest artwork key, never title or row position.
+ (nullable NSString*)artworkForFixtureID:(NSString*)fixtureID;
@end
NS_ASSUME_NONNULL_END
