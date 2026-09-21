#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface TextDebuggerOverlay : NSObject
@property (nonatomic, strong) UIWindow *debugWindow;
@property (nonatomic, strong) UITextView *logTextView;
+ (instancetype)sharedInstance;
- (void)logMessage:(NSString *)message;
@end

@implementation TextDebuggerOverlay

+ (instancetype)sharedInstance {
    static TextDebuggerOverlay *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[TextDebuggerOverlay alloc] init];
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
    
    self.debugWindow.frame = CGRectMake(0, 30, [UIScreen mainScreen].bounds.size.width, 220);
    self.debugWindow.windowLevel = UIWindowLevelAlert + 99999;
    self.debugWindow.hidden = NO;
    self.debugWindow.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.95];
    
    UIViewController *rootVC = [[UIViewController alloc] init];
    rootVC.view.backgroundColor = [UIColor clearColor];
    
    self.logTextView = [[UITextView alloc] initWithFrame:rootVC.view.bounds];
    self.logTextView.editable = NO;
    self.logTextView.textColor = [UIColor cyanColor];
    self.logTextView.backgroundColor = [UIColor clearColor];
    self.logTextView.font = [UIFont fontWithName:@"Courier-Bold" size:9];
    self.logTextView.text = @"[INFO] Text & State Debugger Initialized...\n[INFO] Watching for 'No ad yet' changes...\n";
    
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
// اعتراض تحديث النصوص في العناوين والازرار (UILabel setText:)
// -----------------------------------------------------------------
@implementation UILabel (TextDebugger)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        SEL originalSelector = @selector(setText:);
        SEL swizzledSelector = @selector(debug_setText:);
        
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        
        if (originalMethod && swizzledMethod) {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

- (void)debug_setText:(NSString *)text {
    // استدعاء الدالة الأصلية حتى لا يتأثر شكل التطبيق
    [self debug_setText:text];
    
    // إذا كان النص يحتوي على عبارة تخص الإعلانات أو الحالة
    if (text && (
        [text rangeOfString:@"ad" options:NSCaseInsensitiveSearch].location != NSNotFound ||
        [text rangeOfString:@"reward" options:NSCaseInsensitiveSearch].location != NSNotFound ||
        [text rangeOfString:@"coin" options:NSCaseInsensitiveSearch].location != NSNotFound
    )) {
        NSString *log = [NSString stringWithFormat:@"[UI TEXT] Found Text: '%@'", text];
        [[TextDebuggerOverlay sharedInstance] logMessage:log];
        
        // طباعة جزء من مسار الكود الذي قام بتحديث النص لمعرفة الكلاس المسؤول
        NSArray *stack = [NSThread callStackSymbols];
        if (stack.count > 2) {
            // نأخذ السطر المسؤول عن الاستدعاء
            NSString *caller = stack[2];
            [[TextDebuggerOverlay ISSingletonOrObjC:caller] init]; // صيغة عرض آمنة
            [[TextDebuggerOverlay sharedInstance] logMessage:[NSString stringWithFormat:@"-> Caller: %@", caller]];
        }
    }
}

@end

// طريقة مساعدة لتجنب أخطاء النطاق
@implementation TextDebuggerOverlay (Helper)
+ (id)ISSingletonOrObjC:(NSString *)str {
    return [TextDebuggerOverlay sharedInstance];
}
@end

%ctor {
    [[TextDebuggerOverlay sharedInstance] logMessage:@"[INIT] Hooked UILabel setText successfully!"];
}
