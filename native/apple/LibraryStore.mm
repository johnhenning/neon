#include "LibraryStore.h"

@implementation NeonLibraryStore
- (instancetype)initWithDirectory:(NSURL*)directory {
    self = [super init];
    if (self) {
        _directory = directory;
        NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
        _actor = [defaults stringForKey:@"localActor"];
        if (!_actor) {
            _actor = NSUUID.UUID.UUIDString;
            [defaults setObject:_actor forKey:@"localActor"];
        }
    }
    return self;
}
- (NSArray<NSDictionary*>*)projects:(NSError**)error {
    if (![[NSFileManager defaultManager] createDirectoryAtURL:self.directory
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:error])
        return nil;
    NSArray<NSURL*>* files = [[NSFileManager defaultManager]
          contentsOfDirectoryAtURL:self.directory
        includingPropertiesForKeys:@[ NSURLContentModificationDateKey ]
                           options:NSDirectoryEnumerationSkipsHiddenFiles
                             error:error];
    if (!files)
        return nil;
    NSMutableArray* projects = [NSMutableArray array];
    for (NSURL* file in files) {
        if (![file.pathExtension isEqualToString:@"json"])
            continue;
        NSError* problem = nil;
        NeonDocumentSession* session = [self openURL:file error:&problem];
        NSDate* modified = nil;
        [file getResourceValue:&modified forKey:NSURLContentModificationDateKey error:nil];
        [projects addObject:@{
            @"url" : file,
            @"title" : session.title ?: file.lastPathComponent,
            @"sections" : @(session.sections.count),
            @"modified" : modified ?: NSDate.distantPast,
            @"error" : problem.localizedDescription ?: @""
        }];
    }
    [projects sortUsingDescriptors:@[
        [NSSortDescriptor sortDescriptorWithKey:@"modified" ascending:NO],
        [NSSortDescriptor sortDescriptorWithKey:@"title" ascending:YES]
    ]];
    return projects;
}
- (NeonDocumentSession*)openURL:(NSURL*)url error:(NSError**)error {
    if (![[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
        if (error)
            *error = [NSError
                errorWithDomain:@"NeonLibrary"
                           code:1
                       userInfo:@{
                           NSLocalizedDescriptionKey : @"This project file is missing. Its library "
                                                       @"entry has not been replaced."
                       }];
        return nil;
    }
    return [[NeonDocumentSession alloc] initWithURL:url actor:self.actor error:error];
}
- (NSURL*)createProject:(NSString*)title error:(NSError**)error {
    NSString* clean =
        [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSURL* file =
        [self.directory URLByAppendingPathComponent:[NSUUID.UUID.UUIDString
                                                        stringByAppendingPathExtension:@"json"]];
    NeonDocumentSession* session = [[NeonDocumentSession alloc] initWithURL:file
                                                                      actor:self.actor
                                                                      error:error];
    if (!session || ![session renameProject:clean error:error] || ![session save:error])
        return nil;
    return file;
}
- (BOOL)seedPreview:(NSError**)error {
    NSArray* existing = [self projects:error];
    if (!existing)
        return NO;
    if (existing.count)
        return YES;
    NSURL* sea = [self createProject:@"The Quiet Sea" error:error];
    if (!sea)
        return NO;
    NeonDocumentSession* session = [self openURL:sea error:error];
    if (![session
            replaceText:@"The sea was quiet that morning. Mara stood at the end of the pier, "
                        @"holding a letter she had promised never to open.\n\nBeyond the harbor, a "
                        @"single light moved through the fog. It had been there yesterday, too, "
                        @"and the day before.\n\nShe tucked the envelope into her coat and began "
                        @"to walk.\n\nThe boards were still damp with night, and each step brought "
                        @"her closer to a question she wasn’t sure she wanted answered."
                  error:error] ||
        ![session addSection:@"Beyond the harbor" error:error] ||
        ![session replaceText:@"By noon the water had drawn back from the old stone steps."
                        error:error] ||
        ![session save:error])
        return NO;
    return [self createProject:@"The Longer Road" error:error] != nil &&
           [self createProject:@"North of Here" error:error] != nil;
}
@end
