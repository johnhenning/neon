#import "TextFormatting.h"
#import <CoreText/CoreText.h>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <string>

namespace {
void check(BOOL value, const char* message) {
    if (!value) {
        fprintf(stderr, "Formatting failure: %s\n", message);
        exit(1);
    }
}
} // namespace
int main() {
    @autoreleasepool {
        [NSApplication sharedApplication];
        for (NSString* name in
             @[ @"literata", @"sourcesans3", @"literata-italic", @"sourcesans3-italic" ]) {
            NSString* path = [NSString stringWithFormat:@"%s/%@.ttf", NEON_FORMAT_FONT_DIR, name];
            if ([NSFileManager.defaultManager fileExistsAtPath:path])
                CTFontManagerRegisterFontsForURL((__bridge CFURLRef)[NSURL fileURLWithPath:path],
                                                 kCTFontManagerScopeProcess, nullptr);
        }
        NeonFont* font = NeonSerif(19);
        check([font.familyName isEqual:@"Literata"], "test bundled manuscript font");
        NSAttributedString* original = [[NSAttributedString alloc]
            initWithString:@"First paragraph\nSecond paragraph\nThird paragraph"
                attributes:@{NSFontAttributeName : font}];
        NSRange first = NSMakeRange(0, 5);
        auto bold = NeonFormatText(original, first, @"bold", font);
        check(NeonFormatActive(bold.text, first, @"bold"), "bold applies to selection");
        check(!NeonFormatActive(bold.text, NSMakeRange(16, 6), @"bold"), "other text unchanged");
        auto italic = NeonFormatText(bold.text, first, @"italic", font);
        check(NeonFormatActive(italic.text, first, @"bold") &&
                  NeonFormatActive(italic.text, first, @"italic"),
              "inline traits combine");
        auto plain = NeonFormatText(italic.text, first, @"bold", font);
        check(!NeonFormatActive(plain.text, first, @"bold") &&
                  NeonFormatActive(plain.text, first, @"italic"),
              "bold toggles independently");
        auto list = NeonFormatText(original, NSMakeRange(0, 32), @"numbered", font);
        check([list.text.string hasPrefix:@"1.\tFirst paragraph\n2.\tSecond paragraph"],
              "numbered markers are visible and ordered");
        auto caretList = NeonFormatText(original, NSMakeRange(3, 0), @"bullet", font);
        check(caretList.selection.length == 0 && caretList.selection.location == 5,
              "list command keeps caret instead of selecting entire paragraph");
        NSError* listError = nil;
        NSData* listRTF =
            [list.text dataFromRange:NSMakeRange(0, list.text.length)
                  documentAttributes:@{NSDocumentTypeDocumentAttribute : NSRTFTextDocumentType}
                               error:&listError];
        NSAttributedString* listRestored = [[NSAttributedString alloc]
                  initWithData:listRTF
                       options:@{NSDocumentTypeDocumentOption : NSRTFTextDocumentType}
            documentAttributes:nil
                         error:&listError];
        check([listRestored.string isEqual:list.text.string] &&
                  NeonFormatActive(listRestored, list.selection, @"numbered"),
              "RTF retains visible list and native list metadata");
        auto unlist = NeonFormatText(list.text, list.selection, @"numbered", font);
        check([unlist.text.string isEqual:original.string], "list toggle restores prose exactly");
        auto regularHeading = NeonFormatText(original, first, @"heading1", font);
        auto bodyAgain = NeonFormatText(regularHeading.text, first, @"body", font);
        NeonFont* bodyFont = [bodyAgain.text attribute:NSFontAttributeName
                                               atIndex:0
                                        effectiveRange:nil];
        check(!NeonFormatActive(bodyAgain.text, first, @"bold") &&
                  fabs(bodyFont.pointSize - font.pointSize) < 0.1,
              "heading to body restores size without adding implicit bold");
        auto heading = NeonFormatText(italic.text, first, @"heading1", font);
        NSMutableAttributedString* restyled = [heading.text mutableCopy];
        NSMutableParagraphStyle* paragraph = [NSMutableParagraphStyle new];
        paragraph.lineSpacing = 4;
        NeonRestyleText(restyled, [font fontWithSize:22], paragraph);
        check(NeonFormatActive(restyled, first, @"heading1") &&
                  NeonFormatActive(restyled, first, @"italic"),
              "restyle retains heading and italic");
        NSDictionary* typing = NeonFormatTyping(@{NSFontAttributeName : font}, @"underline", font);
        check([typing[NSUnderlineStyleAttributeName] integerValue] != 0, "caret underline");
        auto quoted = NeonFormatText(original, first, @"quote", font);
        check(NeonFormatActive(quoted.text, first, @"quote"), "quote indentation applied");
        NSError* error = nil;
        NSData* rtf =
            [restyled dataFromRange:NSMakeRange(0, restyled.length)
                 documentAttributes:@{NSDocumentTypeDocumentAttribute : NSRTFTextDocumentType}
                              error:&error];
        NSAttributedString* restored = [[NSAttributedString alloc]
                  initWithData:rtf
                       options:@{NSDocumentTypeDocumentOption : NSRTFTextDocumentType}
            documentAttributes:nil
                         error:&error];
        check(restored && NeonFormatActive(restored, first, @"heading1") &&
                  NeonFormatActive(restored, first, @"italic"),
              "RTF preserves heading and traits");
        auto outOfBounds = NeonFormatText(original, NSMakeRange(NSNotFound, 99), @"bold", font);
        check([outOfBounds.text.string isEqual:original.string],
              "invalid selection preserves prose");
        NSAttributedString* oneItem =
            [[NSAttributedString alloc] initWithString:@"Item"
                                            attributes:@{NSFontAttributeName : font}];
        auto numberedItem = NeonFormatText(oneItem, NSMakeRange(4, 0), @"numbered", font);
        auto continued =
            NeonContinueList(numberedItem.text, numberedItem.selection,
                             [numberedItem.text attributesAtIndex:0 effectiveRange:nil], font);
        check(continued && [continued.text.string isEqual:@"1.\tItem\n2.\t"] &&
                  continued.selection.location == continued.text.length &&
                  continued.selection.length == 0,
              "Return continues numbered list");
        auto exited =
            NeonContinueList(continued.text, continued.selection, continued.typingAttributes, font);
        check(exited && [exited.text.string isEqual:@"1.\tItem\n"] &&
                  ![(NSParagraphStyle*)exited.typingAttributes[NSParagraphStyleAttributeName]
                       textLists]
                       .count,
              "Return on empty item exits list without deleting prior prose");
        auto restartList = NeonFormatText(exited.text, exited.selection, @"numbered", font);
        check([restartList.text.string isEqual:@"1.\tItem\n1.\t"] && restartList.typingAttributes,
              "list restarts on empty paragraph after exit");
        auto bulletItem = NeonFormatText(oneItem, NSMakeRange(2, 0), @"bullet", font);
        auto splitItem =
            NeonContinueList(bulletItem.text, bulletItem.selection,
                             [bulletItem.text attributesAtIndex:0 effectiveRange:nil], font);
        check([splitItem.text.string isEqual:@"•\tIt\n•\tem"],
              "Return splits bullet item at caret");
        auto middle = NeonContinueList(list.text, NSMakeRange(8, 0),
                                       [list.text attributesAtIndex:0 effectiveRange:nil], font);
        check([middle.text.string containsString:@"3.\tSecond paragraph"],
              "splitting numbered item renumbers following items");
        auto replaced =
            NeonContinueList(bulletItem.text, NSMakeRange(3, 2),
                             [bulletItem.text attributesAtIndex:0 effectiveRange:nil], font);
        check([replaced.text.string isEqual:@"•\tI\n•\tm"],
              "Return replaces selected content within item without losing other prose");
        NSAttributedString* trailing =
            [[NSAttributedString alloc] initWithString:@"First\n"
                                            attributes:@{NSFontAttributeName : font}];
        auto trailingList =
            NeonFormatText(trailing, NSMakeRange(trailing.length, 0), @"bullet", font);
        check([trailingList.text.string isEqual:@"First\n•\t"] &&
                  trailingList.selection.location == trailingList.text.length,
              "list at trailing empty paragraph inserts marker at end");
        check(!NeonContinueList(original, NSMakeRange(3, 0), @{}, font),
              "plain Return delegates to editor");
        auto sansItalic = NeonFormatText([[NSAttributedString alloc]
                                             initWithString:@"Interface"
                                                 attributes:@{NSFontAttributeName : NeonUI(17)}],
                                         NSMakeRange(0, 9), @"italic", NeonUI(17));
        check(NeonFormatActive(sansItalic.text, NSMakeRange(0, 9), @"italic"),
              "Source Sans italic companion");
        printf("Text formatting transformations and RTF roundtrip passed\n");
    }
}
