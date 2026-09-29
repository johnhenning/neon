#include "platform.h"
#import <AppKit/AppKit.h>
#import <Security/Security.h>
namespace {
NSString* ns(const QString& s) {
    return [NSString stringWithUTF8String:s.toUtf8().constData()];
}
QString qs(NSString* s) {
    return s ? QString::fromUtf8([s UTF8String]) : QString();
}
NSDictionary* query(const QString& name) {
    return @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService : @"com.johnhenning.neon",
        (__bridge id)kSecAttrAccount : ns(name)
    };
}
} // namespace
namespace platform {
QStringList misspellings(const QString& text, const QString& language) {
    @autoreleasepool {
        QStringList out;
        NSString* s = ns(text);
        NSSpellChecker* checker = [NSSpellChecker sharedSpellChecker];
        NSInteger pos = 0;
        while (pos < s.length && out.size() < 1000) {
            NSRange r = [checker checkSpellingOfString:s
                                            startingAt:pos
                                              language:ns(language)
                                                  wrap:NO
                                inSpellDocumentWithTag:0
                                             wordCount:nullptr];
            if (r.location == NSNotFound || !r.length)
                break;
            auto word = qs([s substringWithRange:r]);
            if (!out.contains(word))
                out << word;
            pos = r.location + r.length;
        }
        return out;
    }
}
QStringList suggestions(const QString& word, const QString& language) {
    @autoreleasepool {
        QStringList out;
        NSString* s = ns(word);
        for (NSString* v in
             [[NSSpellChecker sharedSpellChecker] guessesForWordRange:NSMakeRange(0, s.length)
                                                             inString:s
                                                             language:ns(language)
                                               inSpellDocumentWithTag:0])
            out << qs(v);
        return out;
    }
}
void learnWord(const QString& word) {
    [[NSSpellChecker sharedSpellChecker] learnWord:ns(word)];
}
bool storeSecret(const QString& name, const QString& value) {
    @autoreleasepool {
        auto q = query(name);
        NSData* data = [ns(value) dataUsingEncoding:NSUTF8StringEncoding];
        OSStatus result =
            SecItemUpdate((__bridge CFDictionaryRef)q,
                          (__bridge CFDictionaryRef) @{(__bridge id)kSecValueData : data});
        if (result == errSecItemNotFound) {
            NSMutableDictionary* entry = [q mutableCopy];
            entry[(__bridge id)kSecValueData] = data;
            result = SecItemAdd((__bridge CFDictionaryRef)entry, nullptr);
            [entry release];
        }
        return result == errSecSuccess;
    }
}
QString secret(const QString& name) {
    @autoreleasepool {
        NSMutableDictionary* q = [query(name) mutableCopy];
        q[(__bridge id)kSecReturnData] = @YES;
        CFTypeRef result = nullptr;
        OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)q, &result);
        [q release];
        if (status != errSecSuccess)
            return {};
        NSData* d = (__bridge NSData*)result;
        QString s = QString::fromUtf8((const char*)d.bytes, d.length);
        CFRelease(result);
        return s;
    }
}
bool shareFile(const QString& path, const QString& subject, const QString& body) {
    @autoreleasepool {
        NSSharingService* service =
            [NSSharingService sharingServiceNamed:NSSharingServiceNameComposeEmail];
        if (!service)
            return false;
        service.subject = ns(subject);
        NSArray* items = @[ ns(body), [NSURL fileURLWithPath:ns(path)] ];
        if (![service canPerformWithItems:items])
            return false;
        [service performWithItems:items];
        return true;
    }
}
} // namespace platform
