#include "TextFormatting.h"
#import <CoreText/CoreText.h>
#include <cmath>
#include <string>

@implementation NeonFormattingResult
@end
namespace {
NSRange bounded(NSRange range, NSUInteger length) {
    if (range.location == NSNotFound)
        return NSMakeRange(length, 0);
    range.location = MIN(range.location, length);
    range.length = MIN(range.length, length - range.location);
    return range;
}
BOOL inlineCommand(NSString* command) {
    return [@[ @"bold", @"italic", @"underline" ] containsObject:command];
}
CTFontSymbolicTraits traits(NeonFont* font) {
    return font ? CTFontGetSymbolicTraits((__bridge CTFontRef)font) : 0;
}
NeonFont* styledFont(NeonFont* font, CGFloat size, CTFontSymbolicTraits desired) {
    CTFontRef resized =
        CTFontCreateCopyWithAttributes((__bridge CTFontRef)font, size, nullptr, nullptr);
    CTFontRef styled = CTFontCreateCopyWithSymbolicTraits(resized, size, nullptr, desired,
                                                          kCTFontBoldTrait | kCTFontItalicTrait);
    if (!styled)
        styled = (CTFontRef)CFRetain(resized);
    CFRelease(resized);
    return CFBridgingRelease(styled);
}
NSInteger headingLevel(NSParagraphStyle* paragraph) {
    if (fabs(paragraph.paragraphSpacingBefore - 18) < 0.1)
        return 1;
    if (fabs(paragraph.paragraphSpacingBefore - 12) < 0.1)
        return 2;
    return 0;
}
BOOL quoteStyle(NSParagraphStyle* paragraph) {
    return paragraph.headIndent >= 24 && paragraph.tailIndent <= -24 && !paragraph.textLists.count;
}
BOOL active(NSDictionary* attributes, NSString* command) {
    CTFontSymbolicTraits flags = traits(attributes[NSFontAttributeName]);
    NSParagraphStyle* paragraph = attributes[NSParagraphStyleAttributeName];
    if ([command isEqual:@"bold"])
        return (flags & kCTFontBoldTrait) != 0;
    if ([command isEqual:@"italic"])
        return (flags & kCTFontItalicTrait) != 0;
    if ([command isEqual:@"underline"])
        return [attributes[NSUnderlineStyleAttributeName] integerValue] != 0;
    if ([command isEqual:@"heading1"] || [command isEqual:@"heading2"])
        return headingLevel(paragraph) == ([command isEqual:@"heading1"] ? 1 : 2);
    if ([command isEqual:@"body"])
        return headingLevel(paragraph) == 0;
    if ([command isEqual:@"quote"])
        return quoteStyle(paragraph);
    NSTextList* list = paragraph.textLists.firstObject;
    if ([command isEqual:@"bullet"])
        return list && [list.markerFormat containsString:@"disc"];
    if ([command isEqual:@"numbered"])
        return list && [list.markerFormat containsString:@"decimal"];
    return NO;
}
NSDictionary* changeInline(NSDictionary* attributes, NSString* command, NeonFont* base,
                           BOOL enabled) {
    NSMutableDictionary* result = [attributes mutableCopy];
    if ([command isEqual:@"underline"]) {
        if (enabled)
            result[NSUnderlineStyleAttributeName] = @(NSUnderlineStyleSingle);
        else
            [result removeObjectForKey:NSUnderlineStyleAttributeName];
    } else {
        NeonFont* font = attributes[NSFontAttributeName] ?: base;
        CTFontSymbolicTraits flag =
            [command isEqual:@"bold"] ? kCTFontBoldTrait : kCTFontItalicTrait;
        CTFontSymbolicTraits desired = enabled ? traits(font) | flag : traits(font) & ~flag;
        result[NSFontAttributeName] = styledFont(font, font.pointSize, desired);
    }
    return result;
}
NSRange paragraphRange(NSString* text, NSRange selection) {
    selection = bounded(selection, text.length);
    if (!text.length)
        return NSMakeRange(0, 0);
    // A selection ending at the next paragraph's start excludes that paragraph.
    return [text paragraphRangeForRange:selection];
}
NSMutableParagraphStyle* changedParagraph(NSParagraphStyle* original, NSString* command,
                                          BOOL enabled) {
    NSMutableParagraphStyle* paragraph =
        original ? [original mutableCopy] : [NSMutableParagraphStyle new];
    if ([command isEqual:@"heading1"] || [command isEqual:@"heading2"] ||
        [command isEqual:@"body"]) {
        paragraph.paragraphSpacingBefore = [command isEqual:@"heading1"]   ? 18
                                           : [command isEqual:@"heading2"] ? 12
                                                                           : 0;
        paragraph.minimumLineHeight = 0;
        paragraph.maximumLineHeight = 0;
    } else if ([command isEqual:@"quote"]) {
        paragraph.textLists = @[];
        paragraph.headIndent = enabled ? 24 : 0;
        paragraph.firstLineHeadIndent = paragraph.headIndent;
        paragraph.tailIndent = enabled ? -24 : 0;
    } else if ([command isEqual:@"bullet"] || [command isEqual:@"numbered"]) {
        paragraph.textLists =
            enabled
                ? @[ [[NSTextList alloc]
                      initWithMarkerFormat:[command isEqual:@"bullet"] ? @"{disc}" : @"{decimal}."
                                   options:0] ]
                : @[];
        paragraph.headIndent = enabled ? 28 : 0;
        paragraph.firstLineHeadIndent = 0;
        paragraph.tailIndent = 0;
        paragraph.tabStops = enabled
                                 ? @[ [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentLeft
                                                                      location:28
                                                                       options:@{}] ]
                                 : @[];
    }
    return paragraph;
}
} // namespace
BOOL NeonFormatActive(NSAttributedString* source, NSRange selection, NSString* command) {
    selection = bounded(selection, source.length);
    if (!source.length)
        return NO;
    if (!selection.length)
        return active([source attributesAtIndex:MIN(selection.location, source.length - 1)
                                 effectiveRange:nil],
                      command);
    __block BOOL all = YES;
    [source enumerateAttributesInRange:selection
                               options:0
                            usingBlock:^(NSDictionary* attrs, NSRange, BOOL* stop) {
                              if (!active(attrs, command)) {
                                  all = NO;
                                  *stop = YES;
                              }
                            }];
    return all;
}
NSDictionary* NeonFormatTyping(NSDictionary* attributes, NSString* command, NeonFont* baseFont) {
    attributes = attributes ?: @{};
    if (inlineCommand(command))
        return changeInline(attributes, command, baseFont, !active(attributes, command));
    NSMutableDictionary* result = [attributes mutableCopy];
    NSParagraphStyle* paragraph = changedParagraph(attributes[NSParagraphStyleAttributeName],
                                                   command, !active(attributes, command));
    result[NSParagraphStyleAttributeName] = paragraph;
    if ([@[ @"heading1", @"heading2", @"body" ] containsObject:command]) {
        NSInteger level = headingLevel(paragraph);
        NeonFont* font = attributes[NSFontAttributeName] ?: baseFont;
        result[NSFontAttributeName] = styledFont(baseFont,
                                                 baseFont.pointSize * (level == 1   ? 1.5
                                                                       : level == 2 ? 1.25
                                                                                    : 1),
                                                 traits(font));
    }
    return result;
}
NeonFormattingResult* NeonFormatText(NSAttributedString* source, NSRange selection,
                                     NSString* command, NeonFont* baseFont) {
    selection = bounded(selection, source.length);
    NSMutableAttributedString* text = [source mutableCopy];
    NeonFormattingResult* result = [NeonFormattingResult new];
    result.selection = selection;
    if (inlineCommand(command)) {
        BOOL enabled = !NeonFormatActive(source, selection, command);
        [source enumerateAttributesInRange:selection
                                   options:0
                                usingBlock:^(NSDictionary* attrs, NSRange range, BOOL*) {
                                  [text
                                      setAttributes:changeInline(attrs, command, baseFont, enabled)
                                              range:range];
                                }];
    } else if ([@[ @"body", @"heading1", @"heading2", @"quote", @"bullet", @"numbered" ]
                   containsObject:command]) {
        NSRange expanded = paragraphRange(source.string, selection);
        BOOL enabled = !expanded.length || !NeonFormatActive(source, expanded, command);
        NSMutableArray<NSValue*>* ranges = [NSMutableArray new];
        NSUInteger cursor = expanded.location;
        while (cursor < NSMaxRange(expanded)) {
            NSRange range = [source.string paragraphRangeForRange:NSMakeRange(cursor, 0)];
            [ranges addObject:[NSValue valueWithRange:range]];
            cursor = NSMaxRange(range);
        }
        if (!ranges.count)
            [ranges addObject:[NSValue valueWithRange:expanded]];
        NSUInteger selectionStart = selection.location;
        NSUInteger selectionEnd = NSMaxRange(selection);
        auto removePrefix = [&](NSUInteger location, NSUInteger length) {
            auto adjusted = [&](NSUInteger point) {
                return point <= location            ? point
                       : point <= location + length ? location
                                                    : point - length;
            };
            selectionStart = adjusted(selectionStart);
            selectionEnd = adjusted(selectionEnd);
        };
        auto insertPrefix = [&](NSUInteger location, NSUInteger length) {
            if (selectionStart >= location)
                selectionStart += length;
            if (selectionEnd >= location)
                selectionEnd += length;
        };
        for (NSInteger index = (NSInteger)ranges.count - 1; index >= 0; --index) {
            NSRange range = ranges[index].rangeValue;
            NSDictionary* attrs = range.length
                                      ? [source attributesAtIndex:range.location effectiveRange:nil]
                                      : @{NSFontAttributeName : baseFont};
            NSParagraphStyle* old = attrs[NSParagraphStyleAttributeName];
            NSMutableParagraphStyle* paragraph = changedParagraph(old, command, enabled);
            BOOL listCommand = [command isEqual:@"bullet"] || [command isEqual:@"numbered"];
            BOOL clearList = listCommand || [command isEqual:@"quote"];
            NSUInteger removed = 0;
            if (clearList && old.textLists.count && range.length) {
                NSString* line = [source.string substringWithRange:range];
                NSRange tab = [line rangeOfString:@"\t"];
                // Only remove a generated marker prefix, never arbitrary prose.
                if (tab.location != NSNotFound && tab.location <= 12) {
                    NSString* prefix = [line substringToIndex:tab.location];
                    NSTextList* list = old.textLists.firstObject;
                    NSCharacterSet* allowed =
                        [NSCharacterSet characterSetWithCharactersInString:@"0123456789.•◦"];
                    if ([prefix rangeOfCharacterFromSet:allowed.invertedSet].location ==
                            NSNotFound &&
                        list) {
                        removed = tab.location + 1;
                        [text deleteCharactersInRange:NSMakeRange(range.location, removed)];
                        range.length -= removed;
                        removePrefix(range.location, removed);
                    }
                }
            }
            if (range.length)
                [text addAttribute:NSParagraphStyleAttributeName value:paragraph range:range];
            if ([@[ @"body", @"heading1", @"heading2" ] containsObject:command]) {
                NSAttributedString* runSource = [text attributedSubstringFromRange:range];
                [runSource
                    enumerateAttribute:NSFontAttributeName
                               inRange:NSMakeRange(0, runSource.length)
                               options:0
                            usingBlock:^(NeonFont* font, NSRange local, BOOL*) {
                              NSInteger level = headingLevel(paragraph);
                              [text
                                  addAttribute:NSFontAttributeName
                                         value:styledFont(baseFont,
                                                          baseFont.pointSize * (level == 1   ? 1.5
                                                                                : level == 2 ? 1.25
                                                                                             : 1),
                                                          traits(font))
                                         range:NSMakeRange(range.location + local.location,
                                                           local.length)];
                            }];
            }
            if (listCommand && enabled) {
                NSString* marker = [command isEqual:@"bullet"]
                                       ? @"•\t"
                                       : [NSString stringWithFormat:@"%ld.\t", (long)index + 1];
                NSMutableDictionary* markerAttributes = [attrs mutableCopy];
                markerAttributes[NSParagraphStyleAttributeName] = paragraph;
                if (index == 0)
                    result.typingAttributes = markerAttributes;
                [text insertAttributedString:[[NSAttributedString alloc]
                                                 initWithString:marker
                                                     attributes:markerAttributes]
                                     atIndex:range.location];
                insertPrefix(range.location, marker.length);
            }
        }
        result.selection = NSMakeRange(selectionStart, selectionEnd - selectionStart);
    }
    result.text = text;
    return result;
}
NSDictionary* NeonRestyleTyping(NSDictionary* attributes, NeonFont* baseFont,
                                NSParagraphStyle* baseParagraph) {
    NSMutableDictionary* result = [attributes mutableCopy] ?: [NSMutableDictionary new];
    NSParagraphStyle* original = attributes[NSParagraphStyleAttributeName];
    NSInteger level = headingLevel(original);
    NSMutableParagraphStyle* paragraph =
        [baseParagraph mutableCopy] ?: [NSMutableParagraphStyle new];
    if (level) {
        paragraph.paragraphSpacingBefore = level == 1 ? 18 : 12;
        paragraph.minimumLineHeight = 0;
        paragraph.maximumLineHeight = 0;
    }
    if (original.textLists.count || quoteStyle(original)) {
        paragraph.textLists = original.textLists;
        paragraph.headIndent = original.headIndent;
        paragraph.firstLineHeadIndent = original.firstLineHeadIndent;
        paragraph.tailIndent = original.tailIndent;
        paragraph.tabStops = original.tabStops;
    }
    result[NSParagraphStyleAttributeName] = paragraph;
    result[NSFontAttributeName] = styledFont(baseFont,
                                             baseFont.pointSize * (level == 1   ? 1.5
                                                                   : level == 2 ? 1.25
                                                                                : 1),
                                             traits(attributes[NSFontAttributeName]));
    result[NSForegroundColorAttributeName] = NeonInk();
    return result;
}
void NeonRestyleText(NSMutableAttributedString* text, NeonFont* baseFont,
                     NSParagraphStyle* baseParagraph) {
    NSAttributedString* original = [text copy];
    [original enumerateAttributesInRange:NSMakeRange(0, original.length)
                                 options:0
                              usingBlock:^(NSDictionary* attrs, NSRange range, BOOL*) {
                                [text
                                    setAttributes:NeonRestyleTyping(attrs, baseFont, baseParagraph)
                                            range:range];
                              }];
}

NeonFormattingResult* NeonContinueList(NSAttributedString* source, NSRange selection,
                                       NSDictionary* typingAttributes, NeonFont* baseFont) {
    if (selection.location == NSNotFound || selection.location > source.length)
        return nil;
    selection = bounded(selection, source.length);
    NSRange paragraphRange =
        [source.string paragraphRangeForRange:NSMakeRange(selection.location, 0)];
    if (NSMaxRange(selection) > NSMaxRange(paragraphRange))
        return nil;
    NSDictionary* attributes = paragraphRange.length
                                   ? [source attributesAtIndex:paragraphRange.location
                                                effectiveRange:nil]
                                   : typingAttributes;
    NSParagraphStyle* paragraph = attributes[NSParagraphStyleAttributeName];
    NSTextList* list = paragraph.textLists.firstObject;
    BOOL numbered = [list.markerFormat containsString:@"decimal"];
    BOOL bullet = [list.markerFormat containsString:@"disc"];
    if (!numbered && !bullet)
        return nil;
    NSString* line = [source.string substringWithRange:paragraphRange];
    NSRange tab = [line rangeOfString:@"\t"];
    NSUInteger prefixLength = tab.location == NSNotFound ? 0 : tab.location + 1;
    NSString* prefix = prefixLength ? [line substringToIndex:tab.location] : @"";
    NSCharacterSet* digits = NSCharacterSet.decimalDigitCharacterSet;
    BOOL validNumber =
        prefix.length > 1 && [prefix hasSuffix:@"."] &&
        [[prefix substringToIndex:prefix.length - 1] rangeOfCharacterFromSet:digits.invertedSet]
                .location == NSNotFound;
    if (line.length && ((!bullet || ![prefix isEqual:@"•"]) && (!numbered || !validNumber)))
        return nil;
    if (selection.location < paragraphRange.location + prefixLength)
        return nil;
    NSString* content = [line substringFromIndex:prefixLength];
    BOOL emptyItem =
        ![content stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]
             .length;
    NSMutableAttributedString* text = [source mutableCopy];
    NSMutableDictionary* typing = [typingAttributes mutableCopy] ?: [attributes mutableCopy] ?: [NSMutableDictionary new];
    if (!typing[NSFontAttributeName])
        typing[NSFontAttributeName] = baseFont;
    NeonFormattingResult* result = [NeonFormattingResult new];
    if (emptyItem) {
        [text deleteCharactersInRange:NSMakeRange(paragraphRange.location, prefixLength)];
        NSMutableParagraphStyle* plain =
            changedParagraph(paragraph, numbered ? @"numbered" : @"bullet", NO);
        typing[NSParagraphStyleAttributeName] = plain;
        NSRange remaining =
            NSMakeRange(paragraphRange.location, paragraphRange.length - prefixLength);
        if (remaining.length)
            [text addAttribute:NSParagraphStyleAttributeName value:plain range:remaining];
        result.selection = NSMakeRange(selection.location - prefixLength, 0);
    } else {
        NSInteger next = numbered ? prefix.integerValue + 1 : 0;
        NSString* marker = numbered ? [NSString stringWithFormat:@"%ld.\t", (long)next] : @"•\t";
        typing[NSParagraphStyleAttributeName] = paragraph;
        NSString* inserted = [@"\n" stringByAppendingString:marker];
        [text replaceCharactersInRange:selection
                  withAttributedString:[[NSAttributedString alloc] initWithString:inserted
                                                                       attributes:typing]];
        result.selection = NSMakeRange(selection.location + inserted.length, 0);
        if (numbered) {
            // Keep subsequent contiguous items ordered when splitting in the middle.
            NSUInteger cursor = NSMaxRange(
                [text.string paragraphRangeForRange:NSMakeRange(selection.location + 1, 0)]);
            NSInteger number = next + 1;
            while (cursor < text.length) {
                NSRange itemRange = [text.string paragraphRangeForRange:NSMakeRange(cursor, 0)];
                NSParagraphStyle* itemStyle = [text attribute:NSParagraphStyleAttributeName
                                                      atIndex:cursor
                                               effectiveRange:nil];
                NSTextList* itemList = itemStyle.textLists.firstObject;
                if (![itemList.markerFormat containsString:@"decimal"])
                    break;
                NSString* item = [text.string substringWithRange:itemRange];
                NSRange itemTab = [item rangeOfString:@"\t"];
                if (itemTab.location == NSNotFound || itemTab.location < 2)
                    break;
                NSString* itemPrefix = [item substringToIndex:itemTab.location];
                if (![itemPrefix hasSuffix:@"."] ||
                    [[itemPrefix substringToIndex:itemPrefix.length - 1]
                        rangeOfCharacterFromSet:digits.invertedSet]
                            .location != NSNotFound)
                    break;
                NSString* replacement = [NSString stringWithFormat:@"%ld.\t", (long)number++];
                NSDictionary* itemAttributes = [text attributesAtIndex:cursor effectiveRange:nil];
                [text replaceCharactersInRange:NSMakeRange(cursor, itemTab.location + 1)
                          withAttributedString:[[NSAttributedString alloc]
                                                   initWithString:replacement
                                                       attributes:itemAttributes]];
                cursor = NSMaxRange([text.string paragraphRangeForRange:NSMakeRange(cursor, 0)]);
            }
        }
    }
    result.text = text;
    result.typingAttributes = typing;
    return result;
}
