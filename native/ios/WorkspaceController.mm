#include "WorkspaceController.h"
#import "EditorialTheme.h"

@implementation NeonWorkspaceController
- (void)viewDidLoad {
    [super viewDidLoad];
    _sessionSlot = [UIView new];
    _sessionSlot.backgroundColor = NeonPanel();
    _sessionSlot.accessibilityIdentifier = @"writing-session-slot";
}
- (void)showDestination:(NeonWorkspaceDestination)destination sectionID:(NSString*)sectionID {
    if (self.routeDestination)
        self.routeDestination(destination, sectionID);
}
@end

@implementation NeonChapterHeading {
    BOOL _renaming;
    BOOL _finishing;
    NSString* _original;
    UITapGestureRecognizer* _renameTap;
    UITapGestureRecognizer* _activateTap;
}
- (instancetype)initWithFrame:(CGRect)frame {
    return [self initWithFrame:frame textContainer:nil];
}
- (instancetype)initWithFrame:(CGRect)frame textContainer:(NSTextContainer*)container {
    self = [super initWithFrame:frame textContainer:container];
    if (!self)
        return nil;
    self.delegate = self;
    self.scrollEnabled = NO;
    self.editable = NO;
    self.selectable = NO;
    self.backgroundColor = UIColor.clearColor;
    self.textColor = NeonInk();
    self.tintColor = NeonAccent();
    self.textContainerInset = UIEdgeInsetsZero;
    self.textContainer.lineFragmentPadding = 0;
    self.returnKeyType = UIReturnKeyDone;
    _renameTap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                         action:@selector(beginRenaming)];
    _renameTap.numberOfTapsRequired = 2;
    [self addGestureRecognizer:_renameTap];
    _activateTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(activate)];
    [_activateTap requireGestureRecognizerToFail:_renameTap];
    [self addGestureRecognizer:_activateTap];
    self.accessibilityHint = @"Double-tap to rename. Editing also available in Actions.";
    self.accessibilityCustomActions =
        @[ [[UIAccessibilityCustomAction alloc] initWithName:@"Rename"
                                                      target:self
                                                    selector:@selector(accessibleRename)] ];
    return self;
}
- (void)activate {
    if (self.activateTitle)
        self.activateTitle();
}
- (BOOL)accessibleRename {
    [self beginRenaming];
    return YES;
}
- (void)beginRenaming {
    if (_renaming || !self.commitTitle)
        return;
    _original = self.text;
    _renaming = YES;
    self.editable = YES;
    self.selectable = YES;
    _renameTap.enabled = NO;
    _activateTap.enabled = NO;
    self.backgroundColor = NeonSelection();
    [self becomeFirstResponder];
    [self selectAll:nil];
}
- (BOOL)finishRenaming:(BOOL)commit {
    if (!_renaming || _finishing)
        return YES;
    if (commit && self.markedTextRange)
        return NO;
    _finishing = YES;
    NSString* clean =
        [self.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (commit && (!clean.length || !self.commitTitle(clean))) {
        _finishing = NO;
        return NO;
    }
    self.text = commit ? clean : _original;
    _renaming = NO;
    _finishing = NO;
    self.editable = NO;
    self.selectable = NO;
    self.backgroundColor = UIColor.clearColor;
    _renameTap.enabled = YES;
    _activateTap.enabled = YES;
    [self resignFirstResponder];
    if (self.heightChanged)
        self.heightChanged();
    return YES;
}
- (BOOL)textViewShouldEndEditing:(UITextView*)view {
    (void)view;
    return [self finishRenaming:YES];
}
- (BOOL)textView:(UITextView*)view
    shouldChangeTextInRange:(NSRange)range
            replacementText:(NSString*)text {
    (void)range;
    if ([text isEqual:@"\n"] && !view.markedTextRange) {
        [self finishRenaming:YES];
        return NO;
    }
    return YES;
}
- (void)textViewDidChange:(UITextView*)view {
    if (!view.markedTextRange && self.heightChanged)
        self.heightChanged();
}
- (NSArray<UIKeyCommand*>*)keyCommands {
    return @[ [UIKeyCommand keyCommandWithInput:UIKeyInputEscape
                                  modifierFlags:0
                                         action:@selector(cancelRename)] ];
}
- (void)cancelRename {
    [self finishRenaming:NO];
}
@end
