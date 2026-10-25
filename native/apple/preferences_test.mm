#import "LibraryStore.h"
#import "Preferences.h"
#import <TargetConditionals.h>

int main(int argc, const char** argv) {
    (void)argc;
    (void)argv;
    @autoreleasepool {
        NSUserDefaults* standard = NSUserDefaults.standardUserDefaults;
        NSDictionary* before = [standard dictionaryRepresentation];
        NSUserDefaults* isolated = NeonPreferences();
        if (NSProcessInfo.processInfo.arguments.count == 1)
            return isolated == standard ? 0 : 4;
        BOOL uiTesting = [NSProcessInfo.processInfo.arguments containsObject:@"--ui-testing"];
        NSInteger expectedAppearance = TARGET_OS_IPHONE && !uiTesting ? 0 : 1;
        NSInteger expectedSize = TARGET_OS_IPHONE && !uiTesting ? 18 : 20;
        if (isolated == standard || [isolated integerForKey:@"appearance"] != expectedAppearance ||
            [isolated integerForKey:@"manuscriptSize"] != expectedSize)
            return 1;
        [isolated setInteger:2 forKey:@"appearance"];
        [isolated setInteger:27 forKey:@"manuscriptSize"];
        NSString* actor = NSUUID.UUID.UUIDString;
        [isolated setObject:actor forKey:@"localActor"];
        NSURL* root =
            [NSURL fileURLWithPath:[NSTemporaryDirectory()
                                       stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
        // LibraryStore is a separate translation unit using the same provider.
        NeonLibraryStore* first = [[NeonLibraryStore alloc] initWithDirectory:root];
        NeonLibraryStore* second = [[NeonLibraryStore alloc] initWithDirectory:root];
        if (![first.actor isEqual:actor] || ![second.actor isEqual:actor] ||
            [NeonPreferences() integerForKey:@"manuscriptSize"] != 27 ||
            [NeonPreferences() integerForKey:@"appearance"] != 2)
            return 2;
        if (![[standard dictionaryRepresentation] isEqual:before])
            return 3;
    }
    return 0;
}
