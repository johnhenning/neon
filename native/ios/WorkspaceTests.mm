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
void compositionTransition(UITextView* (^current)(void), void (^request)(BOOL),
                           BOOL (^pending)(void), BOOL wide, BOOL priorValid,
                           void (^completion)(BOOL)) {
    UITextView* manuscript = current();
    UIFont* before = manuscript.font;
    [manuscript setMarkedText:@"日本語" selectedRange:NSMakeRange(3, 0)];
    NSRange composingSelection = manuscript.selectedRange;
    request(wide);
    // Exercise the same notification path used for a Dynamic Type category change.
    [NSNotificationCenter.defaultCenter
        postNotificationName:UIContentSizeCategoryDidChangeNotification
                      object:nil];
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
          scaledFontForFont:NeonSerif(wide ? 20 : 18)];
      CGFloat leading = font.pointSize * (wide ? 34.0 / 20 : 30.0 / 18);
      BOOL settled = valid && !pending() && current() == manuscript &&
                     !manuscript.markedTextRange &&
                     std::abs(font.pointSize - expected.pointSize) < 0.01 &&
                     std::abs(style.minimumLineHeight - leading) < 0.01 &&
                     NSEqualRanges(committedSelection, manuscript.selectedRange);
      completion(settled);
    });
}
} // namespace

void NeonWorkspaceCompositionSmoke(UITextView* (^current)(void), void (^request)(BOOL),
                                   BOOL (^pending)(void), void (^completion)(BOOL)) {
    UITextView* manuscript = current();
    NSString* text = manuscript.text;
    NSRange selection = manuscript.selectedRange;
    NSMutableDictionary* originals = [NSMutableDictionary dictionary];
    for (NSString* key in @[ @"manuscriptSize", @"manuscriptSpacing", @"manuscriptFont" ]) {
        originals[key] = [NeonPreferences() objectForKey:key] ?: NSNull.null;
        [NeonPreferences() removeObjectForKey:key];
    }
    request(NO);
    compositionTransition(current, request, pending, YES, YES, ^(BOOL wideValid) {
      compositionTransition(current, request, pending, NO, wideValid, ^(BOOL valid) {
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
BOOL titleConfiguration(UIButton* title, UIFont* expected) {
    UIButtonConfiguration* config = title.configuration;
    UIFont* font = config.attributedTitle.length
                       ? [config.attributedTitle attribute:NSFontAttributeName
                                                   atIndex:0
                                            effectiveRange:nil]
                       : nil;
    NSDirectionalEdgeInsets inset = config.contentInsets;
    return [font.fontName isEqual:expected.fontName] && font.pointSize == expected.pointSize &&
           inset.top == 0 && inset.leading == 0 && inset.bottom == 0 && inset.trailing == 0 &&
           [config.background.backgroundColor isEqual:UIColor.clearColor];
}
} // namespace
BOOL NeonLibraryTitleStyleSmoke(NeonLibraryController* library) {
    NeonLibraryView original = library.query.view;
    BOOL valid = YES;
    for (NeonLibraryView view : {NeonLibraryGrid, NeonLibraryList}) {
        [library setLibraryView:view];
        NeonButton* title = (NeonButton*)libraryTitle(library.view);
        UIFont* font = view == NeonLibraryList ? NeonSerif(24) : NeonUI(16);
        NSString* accessibility = title.accessibilityLabel;
        valid = valid && title && titleConfiguration(title, font);
        title.chosen = YES;
        valid = valid && titleConfiguration(title, font);
        title.enabled = NO;
        valid = valid && titleConfiguration(title, font);
        title.enabled = YES;
        title.highlighted = YES;
        valid = valid && titleConfiguration(title, font);
        title.highlighted = NO;
        // The shared control supplies this outline on keyboard/Focus Engine focus.
        UIButtonConfiguration* focused = UIButtonConfiguration.filledButtonConfiguration;
        focused.background.strokeColor = NeonInk();
        focused.background.strokeWidth = 3;
        title.configuration = focused;
        valid = valid && titleConfiguration(title, font) &&
                title.configuration.background.strokeWidth == 3 &&
                [title.accessibilityLabel isEqual:accessibility] &&
                (title.accessibilityTraits & UIAccessibilityTraitButton);
        title.chosen = NO;
    }
    [library setLibraryView:original];
    return valid;
}
