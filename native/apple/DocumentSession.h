#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
// Main-thread, single-window prototype bridge. No C++ or UI types escape this API.
@interface NeonDocumentSession : NSObject
@property(nonatomic, readonly) NSString* text;
@property(nonatomic, readonly) BOOL dirty;
@property(nonatomic, readonly) NSString* title;
@property(nonatomic, readonly) NSString* sectionTitle;
@property(nonatomic, readonly) NSString* selectedSectionID;
@property(nonatomic, readonly) NSArray<NSDictionary<NSString*, NSString*>*>* sections;
- (BOOL)selectSection:(NSString*)identifier error:(NSError**)error;
- (BOOL)renameProject:(NSString*)title error:(NSError**)error;
- (BOOL)addSection:(NSString*)title error:(NSError**)error;
@property(nonatomic, readonly) NSArray<NSDictionary<NSString*, NSString*>*>* trashedSections;
- (BOOL)renameSection:(NSString*)identifier title:(NSString*)title error:(NSError**)error;
- (BOOL)setSection:(NSString*)identifier trashed:(BOOL)trashed error:(NSError**)error;
- (BOOL)moveSection:(NSString*)identifier direction:(NSInteger)direction error:(NSError**)error;
- (BOOL)duplicateSection:(NSString*)identifier error:(NSError**)error;
- (BOOL)duplicateToURL:(NSURL*)url error:(NSError**)error;
- (nullable instancetype)initWithURL:(NSURL*)url actor:(NSString*)actor error:(NSError**)error;
- (BOOL)replaceText:(NSString*)text error:(NSError**)error;
- (BOOL)save:(NSError**)error;
@end
NS_ASSUME_NONNULL_END
