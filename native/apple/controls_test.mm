#import "Controls.h"
#import <AppKit/AppKit.h>
#include <cstdio>
#include <cstdlib>
#include <string>
static void require(BOOL value, const char* message) {
    if (!value) {
        fprintf(stderr, "%s\n", message);
        exit(1);
    }
}
@interface Counter : NSObject
@property(nonatomic) NSInteger count;
- (void)activate:(id)sender;
@end
@implementation Counter
- (void)activate:(id)sender {
    (void)sender;
    self.count++;
}
@end
int main(int argc, const char* argv[]) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        Counter* counter = [Counter new];
        NSWindow* window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1000, 840)
                                                       styleMask:NSWindowStyleMaskTitled
                                                         backing:NSBackingStoreBuffered
                                                           defer:NO];
        NSStackView* column = [NSStackView new];
        column.orientation = NSUserInterfaceLayoutOrientationVertical;
        column.spacing = 12;
        column.frame = NSMakeRect(20, 20, 960, 800);
        [window.contentView addSubview:column];
        for (NSString* appearance in @[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]) {
            NSStackView* states = [NSStackView new];
            states.spacing = 8;
            states.appearance = [NSAppearance appearanceNamed:appearance];
            for (NSString* state in @[
                     @"Default", @"Secondary", @"Selected", @"Loading", @"Disabled", @"Retry save"
                 ]) {
                NeonButton* button = [NeonButton new];
                button.title = state;
                button.target = counter;
                button.action = @selector(activate:);
                button.kind = [state isEqual:@"Selected"]    ? NeonButtonSelection
                              : [state isEqual:@"Secondary"] ? NeonButtonSecondary
                                                             : NeonButtonPrimary;
                button.chosen = button.kind == NeonButtonSelection;
                button.loading = [state isEqual:@"Loading"];
                button.enabled = ![state isEqual:@"Disabled"];
                if ([state isEqual:@"Retry save"])
                    button.errorMessage = @"Retry save";
                NSInteger before = counter.count;
                [button performClick:nil];
                require(counter.count == before + (button.enabled && !button.loading ? 1 : 0),
                        "activation suppression");
                if (button.chosen)
                    require([button.accessibilityValue isEqual:@"Selected"],
                            "selection accessibility");
                [states addArrangedSubview:button];
            }
            [column addArrangedSubview:states];
            NeonField* single = [[NeonField alloc] initWithMultiline:NO label:@"Project title"];
            [single.widthAnchor constraintEqualToConstant:400].active = YES;
            single.appearance = [NSAppearance appearanceNamed:appearance];
            single.singleLine.stringValue = @"Project title";
            single.errorMessage = @"Title required";
            [column addArrangedSubview:single];
            NeonField* multi = [[NeonField alloc] initWithMultiline:YES label:@"Description"];
            [multi.widthAnchor constraintEqualToConstant:400].active = YES;
            [column addArrangedSubview:multi];
            multi.appearance = [NSAppearance appearanceNamed:appearance];
            multi.multiline.string = @"Native editable description";
            require(multi.multiline.allowsUndo, "native undo enabled");
            [multi.multiline setSelectedRange:NSMakeRange(0, 6)];
            multi.errorMessage = @"Description required";
            multi.enabled = NO;
            multi.enabled = YES;
            require(NSEqualRanges(multi.multiline.selectedRange, NSMakeRange(0, 6)),
                    "state changes preserve selection");
            require([multi.multiline.string isEqual:@"Native editable description"],
                    "state changes preserve input");
            NeonNumericStepper* step = [[NeonNumericStepper alloc] initWithLabel:@"Text size"
                                                                         minimum:16
                                                                         maximum:32
                                                                           value:20];
            step.value = 99;
            require(step.value == 32, "maximum clamp");
            step.value = -1;
            require(step.value == 16, "minimum clamp");
            __block NSInteger changes = 0;
            step.valueChanged = ^(double value) {
              (void)value;
              changes++;
            };
            step.enabled = NO;
            [step.stepper sendAction:step.stepper.action to:step.stepper.target];
            require(changes == 0, "disabled stepper callback");
            step.enabled = YES;
            step.stepper.doubleValue = 17;
            [step.stepper sendAction:step.stepper.action to:step.stepper.target];
            require(changes == 1 && step.value == 17, "stepper callback/value");
            [column addArrangedSubview:step];
        }
        [window.contentView layoutSubtreeIfNeeded];
        for (NSView* row in column.arrangedSubviews) {
            if (![row isKindOfClass:NSStackView.class] || [row isKindOfClass:NeonField.class] ||
                [row isKindOfClass:NeonNumericStepper.class])
                continue;
            for (NSView* control in ((NSStackView*)row).arrangedSubviews)
                require(control.bounds.size.height >= 44 && control.bounds.size.width >= 44,
                        "minimum target bounds");
        }
        // Reproduce a dark host: the isolated catalog must start light, then switch.
        window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        window.contentView = NeonControlStateFixture();
        require([window.effectiveAppearance.name isEqual:NSAppearanceNameAqua],
                "catalog starts light on dark host");
        NSStackView* catalog = (NSStackView*)((NSScrollView*)window.contentView).documentView;
        NeonButton* themeButton = nil;
        for (NSView* control in catalog.arrangedSubviews) {
            if ([control isKindOfClass:NeonButton.class] &&
                [((NeonButton*)control).title isEqual:@"Change theme"])
                themeButton = (NeonButton*)control;
        }
        require(themeButton != nil, "catalog theme switch reachable");
        [themeButton performClick:nil];
        require([window.effectiveAppearance.name isEqual:NSAppearanceNameDarkAqua],
                "first catalog switch is dark");
        [themeButton performClick:nil];
        require([window.effectiveAppearance.name isEqual:NSAppearanceNameAqua],
                "second catalog switch returns light");
        if (argc > 1) {
            [window setContentSize:NSMakeSize(560, 940)];
            window.contentView = NeonControlStateFixture();
            window.appearance = [NSAppearance
                appearanceNamed:argc > 2 ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua];
            [window makeKeyAndOrderFront:nil];
            [window.contentView displayIfNeeded];
            NSBitmapImageRep* bitmap = [window.contentView
                bitmapImageRepForCachingDisplayInRect:window.contentView.bounds];
            [window.contentView cacheDisplayInRect:window.contentView.bounds
                                  toBitmapImageRep:bitmap];
            [[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}]
                writeToFile:[NSString stringWithUTF8String:argv[1]]
                 atomically:YES];
        }
        puts("control behavior, bounds, native input, theme fixture: PASS");
    }
}
