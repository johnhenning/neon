#import "LibraryStore.h"
#import "WorkspaceController.h"
#include <cstdio>
#include <cstdlib>
#include <string>

namespace {
void require(bool condition, const char* message) {
    if (!condition) {
        fprintf(stderr, "%s\n", message);
        exit(1);
    }
}
} // namespace
int main() {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NeonRegisterFonts();
        NSTextView* editor = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 640, 300)];
        editor.verticallyResizable = YES;
        editor.textContainer.widthTracksTextView = YES;
        editor.string = @"A native manuscript.\nSecond paragraph.";
        editor.selectedRange = NSMakeRange(2, 5);
        NeonWorkspaceController* workspace =
            [[NeonWorkspaceController alloc] initWithEditor:editor];
        workspace.view.frame = NSMakeRect(0, 0, 936, 792);
        workspace.heading.stringValue = @"A map of silence";
        [workspace refreshLayout];
        require(workspace.editor == editor, "Workspace must retain the supplied native editor");
        require(editor.enclosingScrollView == workspace.scrollView,
                "Heading/body share native scroll view");
        require(editor.selectedRange.location == 2, "Layout preserves selection");
        require(editor.frame.size.width == 760, "Default manuscript measure is 760");
        require(editor.frame.origin.x == 48, "Expanded manuscript starts 48 points from pane edge");
        workspace.contentInset = 32;
        require(editor.frame.origin.x == 32,
                "Collapsed manuscript starts 32 points from pane edge");
        workspace.contentInset = 48;
        require(workspace.heading.frame.origin.y < editor.frame.origin.y,
                "Heading precedes manuscript");
        CGFloat shortHeight = workspace.heading.frame.size.height;
        workspace.heading.stringValue =
            [@"A very long chapter heading that wraps naturally without clipping "
                stringByPaddingToLength:300
                             withString:@"into multiple lines "
                        startingAtIndex:0];
        workspace.view.frame = NSMakeRect(0, 0, 420, 600);
        [workspace refreshLayout];
        require(workspace.heading.frame.size.height > shortHeight,
                "Long chapter title wraps on resize");
        require(editor.frame.size.width <= 372, "Narrow shell retains horizontal insets");
        require(editor.selectedRange.length == 5, "Resize preserves selection");
        require(workspace.sessionSlot.hidden && workspace.scrollView.frame.size.height ==
                                                    workspace.view.bounds.size.height - 36.5,
                "Inactive writing session leaves only the compact footer");
        NSView* sessionControls = [NSView new];
        [workspace.sessionSlot addSubview:sessionControls];
        [workspace refreshLayout];
        require(!workspace.sessionSlot.hidden && workspace.sessionSlot.frame.size.height == 44,
                "Active writing session receives its own space");
        [sessionControls removeFromSuperview];
        [workspace refreshLayout];
        require(workspace.sessionSlot.clipsToBounds,
                "Session panel drawing cannot cover manuscript siblings");
        require(NSMaxY(workspace.scrollView.frame) <= workspace.sessionSlot.frame.origin.y,
                "Session slot remains outside editor scroll");
        require([workspace.heading.accessibilityCustomActions.firstObject.name isEqual:@"Rename"],
                "Heading exposes native Rename action");
        workspace.heading.stringValue = @"";
        editor.string = @"";
        [workspace refreshLayout];
        require(editor.frame.size.height >= 300, "Empty native manuscript remains editable");
        NSURL* directory =
            [NSURL fileURLWithPath:[NSTemporaryDirectory()
                                       stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
        NeonLibraryStore* library = [[NeonLibraryStore alloc] initWithDirectory:directory];
        NSError* error = nil;
        NSURL* url = [library createProject:@"Count fixture" preset:@"book" error:&error];
        NeonDocumentSession* session = [library openURL:url error:&error];
        NSString* firstID = session.selectedSectionID;
        require([session replaceText:@"one two" error:&error], "Set first chapter text");
        require([session addSection:@"Second" error:&error], "Add second chapter");
        require([session replaceText:@"three" error:&error], "Set second chapter text");
        NSString* selectedID = session.selectedSectionID;
        require(session.projectWordCount == 3, "Project total spans all active chapters");
        require([session.selectedSectionID isEqual:selectedID],
                "Word total does not mutate selection");
        require([session setSection:firstID trashed:YES error:&error], "Trash first chapter");
        require(session.projectWordCount == 1, "Project total excludes trash");
        require([session save:&error], "Save count fixture");
        require([[library projects:&error][0][@"wordCount"] unsignedIntegerValue] == 1,
                "Library exposes truthful active word total");
        [NSFileManager.defaultManager removeItemAtURL:directory error:nil];
        puts("Mac workspace layout, native editor identity and project counts passed");
    }
}
