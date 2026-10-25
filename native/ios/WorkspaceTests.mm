// UIKit smoke assertions run only against the isolated preview library.
#import "EditorialTheme.h"
#include "WorkspaceController.h"

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
