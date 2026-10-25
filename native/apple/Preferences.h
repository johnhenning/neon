#pragma once
#import <Foundation/Foundation.h>

// A separate, process-unique suite protects the real preferences, including writes
// from Settings. The driver supplies a reproducible profile; production uses its
// existing domain without migration or reset.
static inline NSUserDefaults* NeonPreferences() {
    if (![NSProcessInfo.processInfo.arguments containsObject:@"--ui-testing"])
        return NSUserDefaults.standardUserDefaults;
    static NSUserDefaults* isolated;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
      NSString* run = NSProcessInfo.processInfo.environment[@"NEON_UI_RUN_ID"];
      if (![[NSUUID alloc] initWithUUIDString:run])
          [NSException raise:NSInvalidArgumentException
                      format:@"UI testing requires a UUID run ID"];
      NSString* suite = [@"com.johnhenning.neon.uitest." stringByAppendingString:run];
      isolated = [[NSUserDefaults alloc] initWithSuiteName:suite];
      NSString* json = NSProcessInfo.processInfo.environment[@"NEON_UI_PREFERENCES_JSON"];
      id profile = json ? [NSJSONSerialization
                              JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                         options:0
                                           error:nil]
                        : nil;
      if (![profile isKindOfClass:NSDictionary.class])
          [NSException raise:NSInvalidArgumentException
                      format:@"UI preference profile must be a JSON dictionary"];
      // This function is inline in multiple adapters. Initialize the run domain
      // once, so a late first access in another adapter cannot reset Settings.
      if (![isolated persistentDomainForName:suite][@"NeonUITestProfileInitialized"]) {
          NSMutableDictionary* values = [profile mutableCopy];
          values[@"NeonUITestProfileInitialized"] = @YES;
          [isolated setPersistentDomain:values forName:suite];
      }
    });
    return isolated;
}
