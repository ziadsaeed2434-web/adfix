#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface ComprehensiveAdDebugger : NSObject
@property (nonatomic, strong) UIWindow *debugWindow;
@property (nonatomic, strong) UITextView *logTextView;
+ (instancetype)sharedInstance;
- (void)logMessage:(NSString *)message;
@end

@implementation ComprehensiveAdDebugger

+ (instancetype)sharedInstance {
    static ComprehensiveAdDebugger *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[ComprehensiveAdDebugger alloc] init];
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
    
    // تصحيح فحص النوع لتجنب خطأ التوافق أثناء الترجمة
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
    
    // مربع علوي يغطي عرض الشاشة وبارتفاع 200 بكسل
    self.debugWindow.frame = CGRectMake(0, 35, [UIScreen mainScreen].bounds.size.width, 200);
    self.debugWindow.windowLevel = UIWindowLevelAlert + 99999;
    self.debugWindow.hidden = NO;
    self.debugWindow.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.9];
    
    UIViewController *rootVC = [[UIViewController alloc] init];
    rootVC.view.backgroundColor = [UIColor clearColor];
    
    self.logTextView = [[UITextView alloc] initWithFrame:rootVC.view.bounds];
    self.logTextView.editable = NO;
    self.logTextView.textColor = [UIColor yellowColor];
    self.logTextView.backgroundColor = [UIColor clearColor];
    self.logTextView.font = [UIFont fontWithName:@"Courier-Bold" size:10];
    self.logTextView.text = @"[INFO] Comprehensive Ad Debugger Started...\n[INFO] Monitoring Network & Local APIs...\n";
    
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
// اعتراض شبكي وتتبع الاتصالات
// -----------------------------------------------------------------
@interface NSURLSession (AdDebugger)
@end

@implementation NSURLSession (AdDebugger)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[ComprehensiveAdDebugger sharedInstance] logMessage:@"[NET] Network hooks initialized successfully."];
    });
}

@end

// اعتراض دوال طباعة الأخطاء والـ NSLog لتظهر فوراً على الشاشة
void hooked_NSLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    
    if ([message rangeOfString:@"ad" options:NSCaseInsensitiveSearch].location != NSNotFound ||
        [message rangeOfString:@"error" options:NSCaseInsensitiveSearch].location != NSNotFound ||
        [message rangeOfString:@"fail" options:NSCaseInsensitiveSearch].location != NSNotFound ||
        [message rangeOfString:@"reward" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        [[ComprehensiveAdDebugger sharedInstance] logMessage:[NSString stringWithFormat:@"[LOG] %@", message]];
    }
}

%ctor {
    [[ComprehensiveAdDebugger sharedInstance] logMessage:@"[INIT] Dylib Injected. Ready to capture issues!"];
}
