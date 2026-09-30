#pragma once
#import "DocumentSession.h"
NS_ASSUME_NONNULL_BEGIN
// The filesystem adapter owns filenames. Titles never become filesystem paths.
@interface NeonLibraryStore : NSObject
@property(nonatomic, readonly) NSURL* directory;
@property(nonatomic, readonly) NSString* actor;
- (instancetype)initWithDirectory:(NSURL*)directory;
- (nullable NSArray<NSDictionary*>*)projects:(NSError**)error;
- (nullable NeonDocumentSession*)openURL:(NSURL*)url error:(NSError**)error;
- (nullable NSURL*)createProject:(NSString*)title error:(NSError**)error;
- (nullable NSURL*)createProject:(NSString*)title preset:(NSString*)preset error:(NSError**)error;
- (nullable NSArray<NSDictionary*>*)trashedProjects:(NSError**)error;
- (BOOL)setProject:(NSURL*)url trashed:(BOOL)trashed error:(NSError**)error;
- (nullable NSURL*)duplicateProject:(NSURL*)url error:(NSError**)error;
- (BOOL)deleteTrashedProject:(NSURL*)url error:(NSError**)error;
- (BOOL)seedPreview:(NSError**)error;
@end
NS_ASSUME_NONNULL_END
