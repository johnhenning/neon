#import "DocumentSession.h"
#import <UIKit/UIKit.h>

@interface NeonEditor : UIViewController <UITextViewDelegate>
@property(nonatomic, strong) UITextView* editor;
@property(nonatomic, strong) UILabel* status;
@property(nonatomic, strong) NeonDocumentSession* session;
@property(nonatomic, strong) NSTimer* saveTimer;
@property(nonatomic, strong) NSURL* fileURL;
- (void)flush;
@end
@implementation NeonEditor
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"My writing";
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.status = [[UILabel alloc] init];
    self.status.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    self.status.adjustsFontForContentSizeCategory = YES;
    self.status.numberOfLines = 0;
    self.status.accessibilityIdentifier = @"saveStatus";
    self.editor = [[UITextView alloc] init];
    self.editor.delegate = self;
    self.editor.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.editor.adjustsFontForContentSizeCategory = YES;
    self.editor.accessibilityLabel = @"Manuscript";
    self.editor.accessibilityIdentifier = @"manuscript";
    self.editor.textContainerInset = UIEdgeInsetsMake(20, 16, 20, 16);
    self.editor.backgroundColor =
        [UIColor colorWithDynamicProvider:^UIColor*(UITraitCollection* t) {
          return t.userInterfaceStyle == UIUserInterfaceStyleDark
                     ? [UIColor colorWithRed:0.12 green:0.11 blue:0.10 alpha:1]
                     : [UIColor colorWithRed:0.98 green:0.96 blue:0.91 alpha:1];
        }];
    for (UIView* view in @[ self.editor, self.status ]) {
        view.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addSubview:view];
    }
    UILayoutGuide* safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [self.status.topAnchor constraintEqualToAnchor:safe.topAnchor constant:8],
        [self.status.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [self.status.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16],
        [self.editor.topAnchor constraintEqualToAnchor:self.status.bottomAnchor constant:8],
        [self.editor.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
        [self.editor.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
        [self.editor.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor]
    ]];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Save"
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(flush)];
    NSUserDefaults* defaults = NSUserDefaults.standardUserDefaults;
    NSString* actor = [defaults stringForKey:@"localActor"];
    if (!actor) {
        actor = NSUUID.UUID.UUIDString;
        [defaults setObject:actor forKey:@"localActor"];
    }
    NSURL* directory =
        [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                               inDomains:NSUserDomainMask]
            .firstObject;
    BOOL smoke = [NSProcessInfo.processInfo.arguments containsObject:@"--smoke-test"];
    BOOL reopenSmoke = [NSProcessInfo.processInfo.arguments containsObject:@"--smoke-reopen"];
    self.fileURL = [[directory
        URLByAppendingPathComponent:(smoke || reopenSmoke) ? @"Smoke" : @"Neon Apple Preview"]
        URLByAppendingPathComponent:@"project-v1.json"];
    if (smoke)
        [[NSFileManager defaultManager] removeItemAtURL:self.fileURL error:nil];
    NSError* error = nil;
    self.session = [[NeonDocumentSession alloc] initWithURL:self.fileURL actor:actor error:&error];
    self.editor.editable = self.session != nil;
    self.editor.text = self.session.text ?: @"";
    self.status.text =
        self.session ? @"Local draft · no account required" : error.localizedDescription;
    if (reopenSmoke) {
        NSString* marker =
            self.session && [self.editor.text
                                isEqualToString:
                                    @"A native Apple draft.\nCafé 👩🏽‍💻 العربية"]
                ? @"PASS"
                : @"FAIL";
        [marker writeToURL:[directory URLByAppendingPathComponent:@"smoke-reopen.txt"]
                atomically:YES
                  encoding:NSUTF8StringEncoding
                     error:nil];
    }
    if (smoke && self.session) {
        dispatch_async(dispatch_get_main_queue(), ^{
          [self.editor insertText:@"A native Apple draft.\nCafé 👩🏽‍💻 العربية"];
          [self textViewDidChange:self.editor];
          [self flush];
          NSError* reopenError = nil;
          NeonDocumentSession* reopened = [[NeonDocumentSession alloc] initWithURL:self.fileURL
                                                                             actor:actor
                                                                             error:&reopenError];
          BOOL passed =
              reopened && !self.session.dirty && [reopened.text isEqualToString:self.editor.text];
          NSString* marker = passed ? @"PASS" : @"FAIL";
          [marker writeToURL:[directory URLByAppendingPathComponent:@"smoke-result.txt"]
                  atomically:YES
                    encoding:NSUTF8StringEncoding
                       error:nil];
        });
    }
}
- (void)textViewDidChange:(UITextView*)textView {
    if (textView.markedTextRange)
        return;
    NSError* error = nil;
    if (![self.session replaceText:textView.text error:&error]) {
        self.status.text = error.localizedDescription;
        return;
    }
    self.status.text = @"Unsaved changes";
    [self.saveTimer invalidate];
    __weak NeonEditor* weakSelf = self;
    self.saveTimer = [NSTimer scheduledTimerWithTimeInterval:0.6
                                                     repeats:NO
                                                       block:^(NSTimer* timer) {
                                                         (void)timer;
                                                         [weakSelf flush];
                                                       }];
}
- (void)flush {
    [self.saveTimer invalidate];
    if (!self.session || self.editor.markedTextRange)
        return;
    NSError* error = nil;
    BOOL saved =
        [self.session replaceText:self.editor.text error:&error] && [self.session save:&error];
    self.status.text = saved ? @"Saved on this device" : error.localizedDescription;
}
@end

@interface NeonSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property(nonatomic, strong) UIWindow* window;
@property(nonatomic, strong) NeonEditor* editor;
@end
@implementation NeonSceneDelegate
- (void)scene:(UIScene*)scene
    willConnectToSession:(UISceneSession*)session
                 options:(UISceneConnectionOptions*)connectionOptions {
    (void)session;
    (void)connectionOptions;
    if (![scene isKindOfClass:UIWindowScene.class])
        return;
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene*)scene];
    self.editor = [[NeonEditor alloc] init];
    self.window.rootViewController =
        [[UINavigationController alloc] initWithRootViewController:self.editor];
    [self.window makeKeyAndVisible];
}
- (void)sceneDidEnterBackground:(UIScene*)scene {
    (void)scene;
    [self.editor.view endEditing:YES];
    [self.editor flush];
}
@end
@interface NeonAppDelegate : UIResponder <UIApplicationDelegate>
@end
@implementation NeonAppDelegate
- (UISceneConfiguration*)application:(UIApplication*)application
    configurationForConnectingSceneSession:(UISceneSession*)session
                                   options:(UISceneConnectionOptions*)options {
    (void)application;
    (void)options;
    UISceneConfiguration* config = [[UISceneConfiguration alloc] initWithName:@"Writing"
                                                                  sessionRole:session.role];
    config.delegateClass = NeonSceneDelegate.class;
    return config;
}
@end
int main(int argc, char* argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(NeonAppDelegate.class));
    }
}
