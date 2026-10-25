#include "Preferences.h"
#import <TargetConditionals.h>

NSUserDefaults* NeonPreferences() {
    NSArray<NSString*>* arguments = NSProcessInfo.processInfo.arguments;
    BOOL uiTesting = [arguments containsObject:@"--ui-testing"];
    BOOL smoke = NO;
    for (NSString* argument in arguments)
        smoke = smoke || [argument hasPrefix:@"--smoke-"];
    if (!uiTesting && !smoke)
        return NSUserDefaults.standardUserDefaults;
    static NSUserDefaults* isolated;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
      NSString* run = NSUUID.UUID.UUIDString;
      NSDictionary* profile = @{
          @"appearance" : @1,
          @"manuscriptFont" : @"Literata",
          @"manuscriptSize" : @(TARGET_OS_IPHONE ? 18 : 20),
          @"manuscriptSpacing" : @8,
          @"textMeasure" : @640
      };
      if (uiTesting) {
          run = NSProcessInfo.processInfo.environment[@"NEON_UI_RUN_ID"];
          if (![[NSUUID alloc] initWithUUIDString:run])
              [NSException raise:NSInvalidArgumentException
                          format:@"UI testing requires a UUID run ID"];
          NSString* json = NSProcessInfo.processInfo.environment[@"NEON_UI_PREFERENCES_JSON"];
          id decoded = json ? [NSJSONSerialization
                                  JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding]
                                             options:0
                                               error:nil]
                            : nil;
          if (![decoded isKindOfClass:NSDictionary.class])
              [NSException raise:NSInvalidArgumentException
                          format:@"UI preference profile must be a JSON dictionary"];
          profile = decoded;
      }
      NSString* suite = [@"com.johnhenning.neon.test." stringByAppendingString:run];
      isolated = [[NSUserDefaults alloc] initWithSuiteName:suite];
      [isolated setPersistentDomain:profile forName:suite];
    });
    return isolated;
}
