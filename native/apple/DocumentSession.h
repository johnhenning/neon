#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
// Main-thread, single-window prototype bridge. No C++ or UI types escape this API.
@interface NeonDocumentSession : NSObject
@property(nonatomic, readonly) NSString* text;
@property(nonatomic, readonly) BOOL dirty;
- (nullable instancetype)initWithURL:(NSURL*)url actor:(NSString*)actor error:(NSError**)error;
- (BOOL)replaceText:(NSString*)text error:(NSError**)error;
- (BOOL)save:(NSError**)error;
@end
NS_ASSUME_NONNULL_END
