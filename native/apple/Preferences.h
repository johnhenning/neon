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
      isolated = [[NSUserDefaults alloc]
          initWithSuiteName:[@"com.johnhenning.neon.uitest."
                                stringByAppendingString:(NSProcessInfo.processInfo
                                                                 .environment[@"NEON_UI_RUN_ID"]
                                                             ?: @(NSProcessInfo.processInfo
                                                                      .processIdentifier)
                                                                    .stringValue)]];
      NSString* json = NSProcessInfo.processInfo.environment[@"NEON_UI_PREFERENCES_JSON"];
      NSDictionary* profile =
          json ? [NSJSONSerialization
                     JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                options:0
                                  error:nil]
               : @{};
      [isolated registerDefaults:profile];
    });
    return isolated;
}
