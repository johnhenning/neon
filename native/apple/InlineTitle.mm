#include "InlineTitle.h"
#if TARGET_OS_IPHONE
@implementation NeonInlineTitle {
    BOOL _renaming;
    BOOL _finishing;
    NSString* _original;
    UITapGestureRecognizer* _doubleTap;
    UITapGestureRecognizer* _singleTap;
}
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (!self)
        return nil;
    self.delegate = self;
    self.borderStyle = UITextBorderStyleNone;
    self.returnKeyType = UIReturnKeyDone;
    self.autocorrectionType = UITextAutocorrectionTypeNo;
    self.textColor = NeonInk();
    self.tintColor = NeonAccent();
    _doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                         action:@selector(beginRenaming)];
    _doubleTap.numberOfTapsRequired = 2;
    [self addGestureRecognizer:_doubleTap];
    _singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(activate)];
    [_singleTap requireGestureRecognizerToFail:_doubleTap];
    [self addGestureRecognizer:_singleTap];
    self.accessibilityHint = @"Double-tap to rename. Editing also available in Actions.";
    self.accessibilityCustomActions =
        @[ [[UIAccessibilityCustomAction alloc] initWithName:@"Rename"
                                                      target:self
                                                    selector:@selector(accessibleRename)] ];
    return self;
}
- (BOOL)accessibleRename {
    [self beginRenaming];
    return YES;
}
- (void)activate {
    if (self.activateTitle)
        self.activateTitle();
}
- (BOOL)textFieldShouldBeginEditing:(UITextField*)field {
    (void)field;
    return _renaming;
}
- (void)beginRenaming {
    if (_renaming || !self.commitTitle)
        return;
    _original = self.text;
    _renaming = YES;
    _doubleTap.enabled = NO;
    _singleTap.enabled = NO;
    self.backgroundColor = [NeonAccent() colorWithAlphaComponent:0.12];
    [self becomeFirstResponder];
    [self selectAll:nil];
}
- (BOOL)finishRenaming:(BOOL)commit {
    if (!_renaming || _finishing)
        return YES;
    _finishing = YES;
    NSString* clean =
        [self.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    BOOL saved = !commit || (clean.length && self.commitTitle(clean));
    if (!saved) {
        _finishing = NO;
        return NO;
    }
    self.text = commit ? clean : _original;
    _renaming = NO;
    _finishing = NO;
    self.backgroundColor = UIColor.clearColor;
    _doubleTap.enabled = YES;
    _singleTap.enabled = YES;
    [self resignFirstResponder];
    return YES;
}
- (BOOL)textFieldShouldReturn:(UITextField*)field {
    (void)field;
    return [self finishRenaming:YES];
}
- (BOOL)textFieldShouldEndEditing:(UITextField*)field {
    (void)field;
    return [self finishRenaming:YES];
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
#else
@implementation NeonInlineTitle {
    BOOL _renaming;
    BOOL _finishing;
    NSString* _original;
}
- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (!self)
        return nil;
    self.delegate = self;
    self.editable = NO;
    self.selectable = NO;
    self.bezeled = NO;
    self.drawsBackground = NO;
    self.textColor = NeonInk();
    self.focusRingType = NSFocusRingTypeNone;
    self.lineBreakMode = NSLineBreakByTruncatingTail;
    self.accessibilityHelp = @"Double-click to rename. Editing also available in Actions.";
    return self;
}
- (void)rightMouseDown:(NSEvent*)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    if (self.contextAction)
        self.contextAction(self, NSMakeRect(point.x, point.y, 1, 1));
}
- (void)mouseDown:(NSEvent*)event {
    if (_renaming) {
        [super mouseDown:event];
        return;
    }
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(activate) object:nil];
    if (event.clickCount == 2)
        [self beginRenaming];
    else if (self.activateTitle)
        [self performSelector:@selector(activate)
                   withObject:nil
                   afterDelay:NSEvent.doubleClickInterval];
}
- (void)activate {
    if (self.activateTitle)
        self.activateTitle();
}
- (void)beginRenaming {
    if (_renaming || !self.commitTitle)
        return;
    _original = self.stringValue;
    _renaming = YES;
    self.editable = YES;
    self.selectable = YES;
    self.drawsBackground = YES;
    self.backgroundColor = [NeonAccent() colorWithAlphaComponent:0.12];
    [self selectText:nil];
}
- (BOOL)finishRenaming:(BOOL)commit {
    if (!_renaming || _finishing)
        return YES;
    _finishing = YES;
    NSString* clean = [self.stringValue
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    BOOL saved = !commit || (clean.length && self.commitTitle(clean));
    if (!saved) {
        _finishing = NO;
        NSBeep();
        return NO;
    }
    self.stringValue = commit ? clean : _original;
    _renaming = NO;
    _finishing = NO;
    self.editable = NO;
    self.selectable = NO;
    self.drawsBackground = NO;
    [self.window makeFirstResponder:nil];
    return YES;
}
- (BOOL)control:(NSControl*)control
               textView:(NSTextView*)textView
    doCommandBySelector:(SEL)command {
    (void)control;
    (void)textView;
    if (command == @selector(insertNewline:)) {
        [self finishRenaming:YES];
        return YES;
    }
    if (command == @selector(cancelOperation:)) {
        [self finishRenaming:NO];
        return YES;
    }
    return NO;
}
- (void)controlTextDidEndEditing:(NSNotification*)notification {
    (void)notification;
    [self finishRenaming:YES];
}
@end
#endif
