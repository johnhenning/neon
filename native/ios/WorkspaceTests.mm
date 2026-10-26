// UIKit smoke assertions run only against the isolated preview library.
#import "Controls.h"
#import "EditorialTheme.h"
#import "LibraryController.h"
#import "Preferences.h"
#include "WorkspaceController.h"
#include <cmath>
#include <initializer_list>

BOOL NeonWorkspaceSmoke(NeonChapterHeading* heading, UITextView* manuscript) {
    NSString* title = heading.text;
    NSString* text = manuscript.text;
    NSRange selection = manuscript.selectedRange;
    BOOL valid = [manuscript.accessibilityIdentifier isEqual:@"manuscript"] &&
                 manuscript.isScrollEnabled && heading.superview.superview == manuscript;
    CGFloat width = MAX(1, manuscript.bounds.size.width - manuscript.textContainerInset.left -
                               manuscript.textContainerInset.right);
    CGFloat originalHeight = [heading sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height;
    [heading beginRenaming];
    heading.text = [@"A long chapter heading which wraps naturally across the manuscript measure. "
        stringByPaddingToLength:500
                     withString:@"Long chapter heading. "
                startingAtIndex:0];
    CGFloat wrappedHeight = [heading sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)].height;
    valid = valid && wrappedHeight > originalHeight;
    [heading finishRenaming:NO];
    valid = valid && [heading.text isEqual:title] && [manuscript.text isEqual:text] &&
            NSEqualRanges(selection, manuscript.selectedRange);
    // A native marked range must survive typography notifications until composition ends.
    [manuscript setMarkedText:@"日本語" selectedRange:NSMakeRange(3, 0)];
    valid = valid && manuscript.markedTextRange != nil;
    [manuscript unmarkText];
    manuscript.text = text;
    manuscript.selectedRange = selection;
    return valid;
}

namespace {
void compositionTransition(UITextView* (^current)(void), void (^request)(CGFloat),
                           CGFloat (^lineHeightRatio)(void), BOOL (^pending)(void),
                           CGFloat pointSize, BOOL priorValid, void (^completion)(BOOL)) {
    UITextView* manuscript = current();
    UIFont* before = manuscript.font;
    [manuscript setMarkedText:@"日本語" selectedRange:NSMakeRange(3, 0)];
    NSRange composingSelection = manuscript.selectedRange;
    request(pointSize);
    // Exercise the same notification path used for a Dynamic Type category change.
    [NSNotificationCenter.defaultCenter
        postNotificationName:UIContentSizeCategoryDidChangeNotification
                      object:nil];
    NSString* mode = pointSize > 18 ? @"size20" : @"size18";
    NeonTypographySmokeRecord(
        [mode stringByAppendingString:@"-marked"], manuscript.markedTextRange != nil,
        [NSString stringWithFormat:
                      @"pending=%d beforeFont=%.2f currentFont=%.2f selection=%@ expected=%@",
                      pending(), before.pointSize, manuscript.font.pointSize,
                      NSStringFromRange(manuscript.selectedRange),
                      NSStringFromRange(composingSelection)]);
    BOOL valid = priorValid && pending() && current() == manuscript &&
                 manuscript.markedTextRange != nil &&
                 manuscript.font.pointSize == before.pointSize &&
                 NSEqualRanges(composingSelection, manuscript.selectedRange);
    [manuscript unmarkText];
    NSRange committedSelection = manuscript.selectedRange;
    // unmarkText's retry is queued first; this assertion observes the settled event boundary.
    dispatch_async(dispatch_get_main_queue(), ^{
      UIFont* font = manuscript.font;
      NSParagraphStyle* style = manuscript.typingAttributes[NSParagraphStyleAttributeName];
      UIFont* expected = [[UIFontMetrics metricsForTextStyle:UIFontTextStyleBody]
          scaledFontForFont:NeonSerif(pointSize)];
      CGFloat leading = font.pointSize * lineHeightRatio();
      BOOL settled = valid && !pending() && current() == manuscript &&
                     !manuscript.markedTextRange &&
                     std::abs(font.pointSize - expected.pointSize) < 0.01 &&
                     std::abs(style.minimumLineHeight - leading) < 0.01 &&
                     NSEqualRanges(committedSelection, manuscript.selectedRange);
      NeonTypographySmokeRecord(
          [mode stringByAppendingString:@"-settled"], settled,
          [NSString stringWithFormat:
                        @"prior=%d pending=%d identity=%d marked=%d font=%.2f expected=%.2f "
                        @"leading=%.2f expectedLeading=%.2f selection=%@ expectedSelection=%@",
                        valid, pending(), current() == manuscript,
                        manuscript.markedTextRange != nil, font.pointSize, expected.pointSize,
                        style.minimumLineHeight, leading,
                        NSStringFromRange(manuscript.selectedRange),
                        NSStringFromRange(committedSelection)]);
      completion(settled);
    });
}
} // namespace

void NeonWorkspaceCompositionSmoke(UITextView* (^current)(void), void (^request)(CGFloat),
                                   CGFloat (^lineHeightRatio)(void), BOOL (^pending)(void),
                                   void (^completion)(BOOL)) {
    NeonTypographySmokeRecord(@"begin", YES, @"Native marked-text typography");
    UITextView* manuscript = current();
    NSString* text = manuscript.text;
    NSRange selection = manuscript.selectedRange;
    NSMutableDictionary* originals = [NSMutableDictionary dictionary];
    for (NSString* key in @[ @"manuscriptSize", @"manuscriptSpacing", @"manuscriptFont" ]) {
        originals[key] = [NeonPreferences() objectForKey:key] ?: NSNull.null;
        [NeonPreferences() removeObjectForKey:key];
    }
    request(18);
    compositionTransition(current, request, lineHeightRatio, pending, 20, YES, ^(BOOL largerValid) {
      compositionTransition(current, request, lineHeightRatio, pending, 18, largerValid,
                            ^(BOOL valid) {
                              for (NSString* key in originals) {
                                  id value = originals[key];
                                  if (value == NSNull.null)
                                      [NeonPreferences() removeObjectForKey:key];
                                  else
                                      [NeonPreferences() setObject:value forKey:key];
                              }
                              manuscript.text = text;
                              manuscript.selectedRange = selection;
                              completion(valid && current() == manuscript &&
                                         NSEqualRanges(selection, manuscript.selectedRange));
                            });
    });
}

namespace {
void smokeRecord(NSString* fileName, NSString* assertion, BOOL pass, NSString* detail) {
    NSURL* support = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                            inDomains:NSUserDomainMask]
                         .firstObject;
    NSURL* path = [support URLByAppendingPathComponent:fileName];
    NSString* line = [NSString
        stringWithFormat:@"%@ %@: %@\n", pass ? @"PASS" : @"FAIL", assertion, detail ?: @""];
    if ([assertion isEqual:@"begin"])
        [line writeToURL:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    else {
        NSFileHandle* file = [NSFileHandle fileHandleForWritingAtPath:path.path];
        [file seekToEndOfFile];
        [file writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [file closeFile];
    }
    NSLog(@"%@", line);
}
} // namespace
void NeonLibrarySmokeRecord(NSString* assertion, BOOL pass, NSString* detail) {
    smokeRecord(@"smoke-library-details.txt", assertion, pass, detail);
}
void NeonTypographySmokeRecord(NSString* assertion, BOOL pass, NSString* detail) {
    smokeRecord(@"smoke-typography-details.txt", assertion, pass, detail);
}

namespace {
UIButton* libraryTitle(UIView* view) {
    if ([view isKindOfClass:UIButton.class] &&
        [view.accessibilityIdentifier hasPrefix:@"library-title-"])
        return (UIButton*)view;
    for (UIView* child in view.subviews) {
        UIButton* found = libraryTitle(child);
        if (found)
            return found;
    }
    return nil;
}
BOOL libraryCommandsFit(UIView* view) {
    BOOL valid = YES;
    if ([view isKindOfClass:UIButton.class]) {
        UIButton* button = (UIButton*)view;
        NSString* title = [button titleForState:UIControlStateNormal];
        if ([title isEqual:@"Recent"] || [title isEqual:@"New project"] || [title isEqual:@"•••"]) {
            [button setNeedsLayout];
            [button layoutIfNeeded];
            CGSize full = [button.titleLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
            BOOL fits = button.titleLabel.numberOfLines == 1 &&
                        full.width <= button.titleLabel.bounds.size.width + 1;
            NeonLibrarySmokeRecord(
                [@"command-fit-" stringByAppendingString:title], fits,
                [NSString
                    stringWithFormat:@"textWidth=%.2f labelWidth=%.2f font=%.1f lines=%ld frame=%@",
                                     full.width, button.titleLabel.bounds.size.width,
                                     button.titleLabel.font.pointSize,
                                     static_cast<long>(button.titleLabel.numberOfLines),
                                     NSStringFromCGRect(button.frame)]);
            valid = fits;
        }
    }
    for (UIView* child in view.subviews)
        valid = libraryCommandsFit(child) && valid;
    return valid;
}
BOOL titleConfiguration(UIButton* title, UIFont* expected, NSString* stage) {
    [title setNeedsLayout];
    [title layoutIfNeeded];
    UIButtonConfiguration* config = title.configuration;
    UIFont* storedFont = config.attributedTitle.length
                             ? [config.attributedTitle attribute:NSFontAttributeName
                                                         atIndex:0
                                                  effectiveRange:nil]
                             : nil;
    UIFont* font = title.titleLabel.font;
    UIColor* expectedColor = [title.enabled ? NeonInk() : NeonMuted()
        resolvedColorWithTraitCollection:title.traitCollection];
    UIColor* renderedColor =
        [title.titleLabel.textColor resolvedColorWithTraitCollection:title.traitCollection];
    NSDirectionalEdgeInsets inset = config.contentInsets;
    BOOL valid = [font.fontName isEqual:expected.fontName] &&
                 font.pointSize == expected.pointSize && inset.top == 0 && inset.leading == 0 &&
                 inset.bottom == 0 && inset.trailing == 0 &&
                 [config.background.backgroundColor isEqual:UIColor.clearColor] &&
                 [renderedColor isEqual:expectedColor];
    NeonLibrarySmokeRecord(
        stage, valid,
        [NSString stringWithFormat:
                      @"font=%@ %.2f expected=%@ %.2f insets=%.1f/%.1f/%.1f/%.1f "
                      @"background=%@ foreground=%@ labelColor=%@ storedFont=%@ %.2f title=%@",
                      font.fontName, font.pointSize, expected.fontName, expected.pointSize,
                      inset.top, inset.leading, inset.bottom, inset.trailing,
                      config.background.backgroundColor, config.baseForegroundColor,
                      title.titleLabel.textColor, storedFont.fontName, storedFont.pointSize,
                      config.title]);
    return valid;
}
} // namespace
BOOL NeonLibraryTitleStyleSmoke(NeonLibraryController* library) {
    NeonLibraryView original = library.query.view;
    BOOL valid = YES;
    for (NeonLibraryView view : {NeonLibraryGrid, NeonLibraryList}) {
        [library setLibraryView:view];
        valid = libraryCommandsFit(library.view) && valid;
        NeonButton* title = (NeonButton*)libraryTitle(library.view);
        UIFont* font = view == NeonLibraryList
                           ? NeonSerif(24)
                           : NeonSerif(library.view.bounds.size.width <= 600 ? 15 : 17);
        NSString* accessibility = title.accessibilityLabel;
        NSString* mode = view == NeonLibraryList ? @"list" : @"grid";
        valid = titleConfiguration(title, font, [mode stringByAppendingString:@"-normal"]) && valid;
        title.chosen = YES;
        valid = titleConfiguration(title, font, [mode stringByAppendingString:@"-chosen"]) && valid;
        title.enabled = NO;
        valid =
            titleConfiguration(title, font, [mode stringByAppendingString:@"-disabled"]) && valid;
        title.enabled = YES;
        title.highlighted = YES;
        valid = titleConfiguration(title, font, [mode stringByAppendingString:@"-highlighted"]) &&
                valid;
        title.highlighted = NO;
        // The shared control supplies this outline on keyboard/Focus Engine focus.
        UIButtonConfiguration* focused = UIButtonConfiguration.filledButtonConfiguration;
        focused.background.strokeColor = NeonInk();
        focused.background.strokeWidth = 3;
        title.configuration = focused;
        BOOL focusedStyle =
            titleConfiguration(title, font, [mode stringByAppendingString:@"-focus"]);
        BOOL focusAX = title.configuration.background.strokeWidth == 3 &&
                       [title.accessibilityLabel isEqual:accessibility] &&
                       (title.accessibilityTraits & UIAccessibilityTraitButton);
        NeonLibrarySmokeRecord(
            [mode stringByAppendingString:@"-focus-AX"], focusAX,
            [NSString stringWithFormat:@"stroke=%.1f label=%@ traits=%llu",
                                       title.configuration.background.strokeWidth,
                                       title.accessibilityLabel,
                                       static_cast<unsigned long long>(title.accessibilityTraits)]);
        valid = focusedStyle && focusAX && valid;
        title.chosen = NO;
        void (^originalAction)(NSString*, NSDictionary*) = library.onAction;
        NSString* selected = library.selectedProjectID;
        __block BOOL activated = NO;
        NSString* projectID =
            [title.accessibilityIdentifier substringFromIndex:@"library-title-".length];
        library.onAction = ^(NSString* action, NSDictionary* record) {
          activated = [action isEqual:@"open"] && [record[@"projectID"] isEqual:projectID];
        };
        [title sendActionsForControlEvents:UIControlEventTouchUpInside];
        library.onAction = originalAction;
        library.selectedProjectID = selected;
        NeonLibrarySmokeRecord([mode stringByAppendingString:@"-native-activation"], activated,
                               projectID);
        valid = activated && valid;
    }
    [library setLibraryView:original];
    return valid;
}
