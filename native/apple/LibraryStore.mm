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
            @"sectionLabel" : session.preset[@"sectionsLabel"] ?: @"Sections",
            @"preset" : session.preset[@"title"] ?: @"Project",
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
    return [self createProject:title preset:@"book" error:error];
}
- (NSURL*)createProject:(NSString*)title preset:(NSString*)preset error:(NSError**)error {
    NSString* clean =
        [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSURL* file =
        [self.directory URLByAppendingPathComponent:[NSUUID.UUID.UUIDString
                                                        stringByAppendingPathExtension:@"json"]];
    NeonDocumentSession* session = [[NeonDocumentSession alloc] initWithURL:file
                                                                      actor:self.actor
                                                                      error:error];
    if (!session || ![session initializePreset:preset error:error] ||
        ![session renameProject:clean error:error] || ![session save:error])
        return nil;
    return file;
}
- (NSArray<NSDictionary*>*)trashedProjects:(NSError**)error {
    NeonLibraryStore* trash = [[NeonLibraryStore alloc]
        initWithDirectory:[self.directory URLByAppendingPathComponent:@"Trash" isDirectory:YES]];
    return [trash projects:error];
}
- (BOOL)validURL:(NSURL*)url parent:(NSURL*)parent error:(NSError**)error {
    if (url.isFileURL &&
        [url.URLByDeletingLastPathComponent.URLByStandardizingPath
            isEqual:parent.URLByStandardizingPath] &&
        [url.pathExtension isEqualToString:@"json"])
        return YES;
    if (error)
        *error = [NSError
            errorWithDomain:@"NeonLibrary"
                       code:2
                   userInfo:@{NSLocalizedDescriptionKey : @"The item is outside this library."}];
    return NO;
}
- (BOOL)setProject:(NSURL*)url trashed:(BOOL)trashed error:(NSError**)error {
    NSURL* trash = [self.directory URLByAppendingPathComponent:@"Trash" isDirectory:YES];
    if (![self validURL:url parent:trashed ? self.directory : trash error:error])
        return NO;
    NSURL* destination = trashed ? trash : self.directory;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:destination
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:error])
        return NO;
    NSFileManager* manager = NSFileManager.defaultManager;
    NSURL* target = [destination URLByAppendingPathComponent:url.lastPathComponent];
    NSMutableArray<NSString*>* moved = [NSMutableArray array];
    if (![manager moveItemAtURL:url toURL:target error:error])
        return NO;
    for (NSString* suffix in @[ @"schema1-backup", @"schema2-backup" ]) {
        NSURL* backup = [url URLByAppendingPathExtension:suffix];
        if (![manager fileExistsAtPath:backup.path])
            continue;
        if (![manager moveItemAtURL:backup
                              toURL:[target URLByAppendingPathExtension:suffix]
                              error:error]) {
            for (NSString* previous in moved)
                [manager moveItemAtURL:[target URLByAppendingPathExtension:previous]
                                 toURL:[url URLByAppendingPathExtension:previous]
                                 error:nil];
            [manager moveItemAtURL:target toURL:url error:nil];
            return NO;
        }
        [moved addObject:suffix];
    }
    return YES;
}
- (NSURL*)duplicateProject:(NSURL*)url error:(NSError**)error {
    if (![self validURL:url parent:self.directory error:error])
        return nil;
    NeonDocumentSession* session = [self openURL:url error:error];
    NSURL* destination =
        [self.directory URLByAppendingPathComponent:[NSUUID.UUID.UUIDString
                                                        stringByAppendingPathExtension:@"json"]];
    return session && [session duplicateToURL:destination error:error] ? destination : nil;
}
- (BOOL)deleteTrashedProject:(NSURL*)url error:(NSError**)error {
    NSURL* trash = [self.directory URLByAppendingPathComponent:@"Trash" isDirectory:YES];
    if (![self validURL:url parent:trash error:error])
        return NO;
    for (NSString* suffix in @[ @"schema1-backup", @"schema2-backup" ]) {
        NSURL* backup = [url URLByAppendingPathExtension:suffix];
        if ([[NSFileManager defaultManager] fileExistsAtPath:backup.path] &&
            ![[NSFileManager defaultManager] removeItemAtURL:backup error:error])
            return NO;
    }
    return [[NSFileManager defaultManager] removeItemAtURL:url error:error];
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
