#include "LibraryPresentation.h"
#import "Preferences.h"

@implementation NeonLibraryQuery
- (instancetype)init {
    self = [super init];
    if (self) {
        NSInteger view = [NeonPreferences() integerForKey:@"library.view"];
        NSInteger sort = [NeonPreferences() integerForKey:@"library.sort"];
        _view = view == NeonLibraryList ? NeonLibraryList : NeonLibraryGrid;
        _sort = sort >= NeonLibraryModified && sort <= NeonLibraryLastOpened
                    ? static_cast<NeonLibrarySort>(sort)
                    : NeonLibraryModified;
    }
    return self;
}
- (void)savePreferences {
    [NeonPreferences() setInteger:self.view forKey:@"library.view"];
    [NeonPreferences() setInteger:self.sort forKey:@"library.sort"];
}
@end
@implementation NeonLibraryPresentation
- (instancetype)initWithRecords:(NSArray<NSDictionary*>*)records
                          error:(NSError*)error
                          query:(NeonLibraryQuery*)query
              selectedProjectID:(NSString*)selectedProjectID
                            now:(NSDate*)now {
    self = [super init];
    if (self) {
        _error = error;
        if (!records && !error)
            _error = [NSError
                errorWithDomain:@"NeonLibrary"
                           code:3
                       userInfo:@{NSLocalizedDescriptionKey : @"The library could not be read."}];
        NSMutableArray* visible = [NSMutableArray array];
        // Recent means successfully opened within the last 30 days, including today.
        NSDate* cutoff = [now dateByAddingTimeInterval:-30 * 24 * 60 * 60];
        for (NSDictionary* record in records) {
            BOOL trash = [record[@"trashed"] boolValue];
            if (trash != (query.filter == NeonLibraryTrash))
                continue;
            if (query.filter == NeonLibraryFavorites && ![record[@"favorite"] boolValue])
                continue;
            NSDate* opened = record[@"lastOpened"] ?: NSDate.distantPast;
            if (query.filter == NeonLibraryRecent &&
                ([opened compare:cutoff] == NSOrderedAscending ||
                 [opened compare:now] == NSOrderedDescending))
                continue;
            [visible addObject:record];
        }
        BOOL titleSort = query.sort == NeonLibraryTitle && query.filter != NeonLibraryRecent;
        NSString* key = query.filter == NeonLibraryRecent || query.sort == NeonLibraryLastOpened
                            ? @"lastOpened"
                        : titleSort ? @"title"
                                    : @"modified";
        [visible sortUsingDescriptors:@[
            [NSSortDescriptor sortDescriptorWithKey:key ascending:titleSort],
            [NSSortDescriptor sortDescriptorWithKey:@"projectID" ascending:YES]
        ]];
        _records = [[NSArray alloc] initWithArray:visible copyItems:YES];
        for (NSDictionary* record in _records)
            if ([record[@"projectID"] isEqual:selectedProjectID])
                _selectedProjectID = [selectedProjectID copy];
    }
    return self;
}
+ (NSString*)artworkForFixtureID:(NSString*)fixtureID {
    return @{
        @"neon.fixture.quiet-sea" : @"quiet-sea-hires",
        @"neon.fixture.stone-paths" : @"stone-paths-hires",
        @"neon.fixture.glass-field" : @"glass-field-hires"
    }[fixtureID];
}
@end
