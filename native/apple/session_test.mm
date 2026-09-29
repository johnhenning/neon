#import "DocumentSession.h"
#include <cstdlib>
#include <iostream>

void check(bool value, const char* message) {
    if (!value) {
        std::cerr << message << '\n';
        std::exit(1);
    }
}
int main() {
    @autoreleasepool {
        NSURL* directory =
            [NSURL fileURLWithPath:[NSTemporaryDirectory()
                                       stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
        NSURL* file = [directory URLByAppendingPathComponent:@"project.json"];
        NSError* error = nil;
        NeonDocumentSession* session = [[NeonDocumentSession alloc] initWithURL:file
                                                                          actor:@"author"
                                                                          error:&error];
        check(session && session.dirty, "new local document");
        NSString* text = @"Café 👩🏽‍💻 العربية\nA second paragraph.";
        check([session replaceText:text error:&error] && [session save:&error], "save Unicode");
        NeonDocumentSession* reopened = [[NeonDocumentSession alloc] initWithURL:file
                                                                           actor:@"editor"
                                                                           error:&error];
        check(reopened && [reopened.text isEqualToString:text] && !reopened.dirty, "reopen");
        check([reopened replaceText:@"Another editor" error:&error] && [reopened save:&error],
              "second edit");
        check([session replaceText:@"Retained draft" error:&error] && ![session save:&error] &&
                  session.dirty && [session.text isEqualToString:@"Retained draft"],
              "conflict retains draft");
        NSData* data = [NSData dataWithContentsOfURL:file];
        NSMutableDictionary* future = [[NSJSONSerialization JSONObjectWithData:data
                                                                       options:0
                                                                         error:&error] mutableCopy];
        future[@"schema"] = @2;
        NSData* unknown = [NSJSONSerialization dataWithJSONObject:future options:0 error:&error];
        check([unknown writeToURL:file atomically:YES], "write future schema fixture");
        check(![[NeonDocumentSession alloc] initWithURL:file actor:@"author" error:&error],
              "refuse future schema");
        check([[NSData dataWithContentsOfURL:file] isEqualToData:unknown], "preserve future file");
        [[NSFileManager defaultManager] removeItemAtURL:directory error:nil];
        std::cout << "Apple semantic save/reopen/conflict scenarios passed\n";
    }
}
