#pragma once
#import "LibraryStore.h"
#import "Preferences.h"

// Only the external XCTest driver supplies these inputs. Production never seeds data.
static inline NSDictionary* NeonUITestFixtureConfiguration() {
    NSString* json = NSProcessInfo.processInfo.environment[@"NEON_UI_FIXTURE_JSON"];
    if (!json)
        return nil;
    return [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                           options:0
                                             error:nil];
}
// Mapping lives only in the isolated --ui-testing preference suite.
static inline NSDictionary<NSString*, NSString*>* NeonUITestFixtureIDs() {
    if (![NSProcessInfo.processInfo.arguments containsObject:@"--ui-testing"])
        return @{};
    return [NeonPreferences() dictionaryForKey:@"uiFixtureArtworkIDs"] ?: @{};
}
static inline BOOL NeonSeedUITestLibrary(NeonLibraryStore* library, NSError** error) {
    NSDictionary* configuration = NeonUITestFixtureConfiguration();
    if (![configuration[@"projects"] isKindOfClass:NSArray.class]) {
        if (error)
            *error = [NSError
                errorWithDomain:@"NeonUITestFixture"
                           code:1
                       userInfo:@{NSLocalizedDescriptionKey : @"Missing fixture projects"}];
        return NO;
    }
    NSMutableDictionary* artworkIDs = [NSMutableDictionary new];
    // Create in reverse so real modification times preserve the canonical shelf order.
    for (NSDictionary* project in [configuration[@"projects"] reverseObjectEnumerator]) {
        NSURL* url = [library createProject:project[@"title"]
                                     preset:project[@"preset"]
                                      error:error];
        NeonDocumentSession* session = url ? [library openURL:url error:error] : nil;
        if (!session)
            return NO;
        NSString* fixtureID = project[@"fixtureID"];
        if ([fixtureID isKindOfClass:NSString.class])
            artworkIDs[session.projectID] = fixtureID;
        NSUInteger index = 0;
        for (NSDictionary* section in project[@"sections"]) {
            if (index++ == 0) {
                if (![session renameSection:session.selectedSectionID
                                      title:section[@"title"]
                                      error:error])
                    return NO;
            } else if (![session addSection:section[@"title"] error:error]) {
                return NO;
            }
            if (![session replaceText:section[@"text"] error:error])
                return NO;
        }
        if (![session selectSection:session.sections.firstObject[@"id"] error:error] ||
            ![session save:error])
            return NO;
    }
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--ui-testing"])
        [NeonPreferences() setObject:artworkIDs forKey:@"uiFixtureArtworkIDs"];
    return YES;
}
