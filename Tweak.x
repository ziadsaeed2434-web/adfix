#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface LocalAdChecker : NSObject
@property (nonatomic, strong) UIWindow *debugWindow;
@property (nonatomic, strong) UITextView *logTextView;
+ (instancetype)sharedInstance;
- (void)logMessage:(NSString *)message;
@end

@implementation LocalAdChecker

+ (instancetype)sharedInstance {
    static LocalAdChecker *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[LocalAdChecker alloc] init];
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
    
    // نافذة علوية قابلة للتمرير بيدك لقراءة كل الفحوصات المحلية
    self.debugWindow.frame = CGRectMake(0, 30, [UIScreen mainScreen].bounds.size.width, 260);
    self.debugWindow.windowLevel = UIWindowLevelAlert + 99999;
    self.debugWindow.hidden = NO;
    self.debugWindow.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.97];
    
    UIViewController *rootVC = [[UIViewController alloc] init];
    rootVC.view.backgroundColor = [UIColor clearColor];
    
    self.logTextView = [[UITextView alloc] initWithFrame:rootVC.view.bounds];
    self.logTextView.editable = NO;
    self.logTextView.scrollEnabled = YES;
    self.logTextView.userInteractionEnabled = YES;
    self.logTextView.textColor = [UIColor magentaColor]; // لون مميز للفحص المحلي
    self.logTextView.backgroundColor = [UIColor clearColor];
    self.logTextView.font = [UIFont fontWithName:@"Courier-Bold" size:9];
    self.logTextView.text = @"[LOCAL SCAN] Deep Local Reason Analyzer Started...\n[LOCAL SCAN] Scanning memory for Ad restrictions...\n";
    
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

// فحص محلي للكلاسات المرتبطة بالإعلانات عند الإطلاق
static void performLocalMemoryScan() {
    int numClasses = objc_getClassList(NULL, 0);
    if (numClasses > 0) {
        Class *classes = (__unsafe_unretained Class *)malloc(sizeof(Class) * numClasses);
        numClasses = objc_getClassList(classes, numClasses);
        
        int adClassesCount = 0;
        for (int i = 0; i < numClasses; i++) {
            NSString *className = NSStringFromClass(classes[i]);
            // البحث عن الكلاسات المسؤولة محلياً عن الإعلانات أو المتجر
            if ([className rangeOfString:@"Ad" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [className rangeOfString:@"Reward" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [className rangeOfString:@"Monetiz" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [className rangeOfString:@"Store" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                
                adClassesCount++;
                if (adClassesCount <= 15) { // عرض عينة من الكلاسات المكتشفة محلياً
                    [[LocalAdChecker sharedInstance] logMessage:[NSString stringWithFormat:@"[LOCAL CLASS] Found: %@", className]];
                }
            }
        }
        free(classes);
        [[LocalAdChecker sharedInstance] logMessage:[NSString stringWithFormat:@"[LOCAL SCAN] Total relevant classes found: %d", adClassesCount]];
    }
}

// اعتراض الشروط والتحققات المحلية عبر رصد استدعاءات الـ NSUserDefaults (حيث غالباً ما يتم حفظ حالة الحظر أو التوقيت محلياً)
@interface NSUserDefaults (LocalAdChecker)
@end

@implementation NSUserDefaults (LocalAdChecker)

- (id)debug_objectForKey:(NSString *)defaultName {
    id value = [self debug_objectForKey:defaultName];
    if (defaultName && ([defaultName rangeOfString:@"ad" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                        [defaultName rangeOfString:@"time" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                        [defaultName rangeOfString:@"limit" options:NSCaseInsensitiveSearch].location != NSNotFound)) {
        [[LocalAdChecker sharedInstance] logMessage:[NSString stringWithFormat:@"[LOCAL PREF] Read Key: %@ = %@", defaultName, value]];
    }
    return value;
}

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        Method original = class_getInstanceMethod(class, @selector(objectForKey:));
        Method swizzled = class_getInstanceMethod(class, @selector(debug_objectForKey:));
        if (original && swizzled) {
            method_exchangeImplementations(original, swizzled);
        }
    });
}

@end

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        performLocalMemoryScan();
    });
    [[LocalAdChecker sharedInstance] logMessage:@"[INIT] Local Reason Analyzer Hooked Successfully!"];
}
