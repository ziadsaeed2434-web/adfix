#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface FinalAdDebugger : NSObject
@property (nonatomic, strong) UIWindow *debugWindow;
@property (nonatomic, strong) UITextView *logTextView;
+ (instancetype)sharedInstance;
- (void)logMessage:(NSString *)message;
@end

@implementation FinalAdDebugger

+ (instancetype)sharedInstance {
    static FinalAdDebugger *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[FinalAdDebugger alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self performSelectorOnMainThread:@selector(setupUI) withObject:nil waitUntilDone:NO];
    }
    return self;
}

- (void)setupUI {
    UIWindowScene *targetScene = nil;
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            targetScene = (UIWindowScene *)scene;
            break;
        }
    }
    
    if (targetScene) {
        self.debugWindow = [[UIWindow alloc] initWithWindowScene:targetScene];
    } else {
        self.debugWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    }
    
    self.debugWindow.frame = CGRectMake(0, 30, [UIScreen mainScreen].bounds.size.width, 240);
    self.debugWindow.windowLevel = UIWindowLevelAlert + 99999;
    self.debugWindow.hidden = NO;
    self.debugWindow.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.95];
    
    UIViewController *rootVC = [[UIViewController alloc] init];
    rootVC.view.backgroundColor = [UIColor clearColor];
    
    self.logTextView = [[UITextView alloc] initWithFrame:rootVC.view.bounds];
    self.logTextView.editable = NO;
    self.logTextView.textColor = [UIColor greenColor];
    self.logTextView.backgroundColor = [UIColor clearColor];
    self.logTextView.font = [UIFont fontWithName:@"Courier-Bold" size:9];
    self.logTextView.text = @"[INFO] Targeting UIButton & UILabel States...\n";
    
    [rootVC.view addSubview:self.logTextView];
    self.debugWindow.rootViewController = rootVC;
}

- (void)logMessage:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *currentText = self.logTextView.text ?: @"";
        NSString *newText = [NSString stringWithFormat:@"%@\n%@", currentText, message];
        self.logTextView.text = newText;
        if(self.logTextView.text.length > 0) {
            NSRange bottom = NSMakeRange(self.logTextView.text.length - 1, 1);
            [self.logTextView scrollRangeToVisible:bottom];
        }
    });
}

@end

// -----------------------------------------------------------------
// اعتراض نصوص الأزرار (UIButton setTitle:forState:)
// -----------------------------------------------------------------
@implementation UIButton (AdButtonDebugger)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        SEL originalSelector = @selector(setTitle:forState:);
        SEL swizzledSelector = @selector(debug_setTitle:forState:);
        
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        
        if (originalMethod && swizzledMethod) {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

- (void)debug_setTitle:(NSString *)title forState:(UIControlState)state {
    [self debug_setTitle:title forState:state];
    
    if (title && (
        [title rangeOfString:@"ad" options:NSCaseInsensitiveSearch].location != NSNotFound ||
        [title rangeOfString:@"reward" options:NSCaseInsensitiveSearch].location != NSNotFound ||
        [title rangeOfString:@"no" options:NSCaseInsensitiveSearch].location != NSNotFound
    )) {
        NSString *log = [NSString stringWithFormat:@"[BTN TITLE] '%@'", title];
        [[FinalAdDebugger sharedInstance] logMessage:log];
        
        NSArray *stack = [NSThread callStackSymbols];
        if (stack.count > 2) {
            [[FinalAdDebugger sharedInstance] logMessage:[NSString stringWithFormat:@"-> Caller: %@", stack[2]]];
        }
    }
}

@end

%ctor {
    [[FinalAdDebugger sharedInstance] logMessage:@"[INIT] Button Hook Active!"];
}
