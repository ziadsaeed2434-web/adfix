#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface AdBypasserOverlay : NSObject
@property (nonatomic, strong) UIWindow *debugWindow;
@property (nonatomic, strong) UITextView *logTextView;
+ (instancetype)sharedInstance;
- (void)logMessage:(NSString *)message;
@end

@implementation AdBypasserOverlay

+ (instancetype)sharedInstance {
    static AdBypasserOverlay *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[AdBypasserOverlay alloc] init];
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
    
    self.debugWindow.frame = CGRectMake(0, 30, [UIScreen mainScreen].bounds.size.width, 180);
    self.debugWindow.windowLevel = UIWindowLevelAlert + 99999;
    self.debugWindow.hidden = NO;
    self.debugWindow.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.95];
    
    UIViewController *rootVC = [[UIViewController alloc] init];
    rootVC.view.backgroundColor = [UIColor clearColor];
    
    self.logTextView = [[UITextView alloc] initWithFrame:rootVC.view.bounds];
    self.logTextView.editable = NO;
    self.logTextView.scrollEnabled = YES;
    self.logTextView.userInteractionEnabled = YES;
    self.logTextView.textColor = [UIColor greenColor];
    self.logTextView.backgroundColor = [UIColor clearColor];
    self.logTextView.font = [UIFont fontWithName:@"Courier-Bold" size:10];
    self.logTextView.text = @"[AD BYPASSER] Active - Forcing Ad Consents & Bypassing Restrictions...\n";
    
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
// خداع التخزين المحلي وإجبار قيم الموافقة والتتبع على النجاح
// -----------------------------------------------------------------
@implementation NSUserDefaults (AdBypasser)

- (id)bypass_objectForKey:(NSString *)defaultName {
    if (defaultName) {
        // إجبار الموافقة على ملفات تعريف الارتباط للإعلانات
        if ([defaultName isEqualToString:@"gad_has_consent_for_cookies"]) {
            return @(YES);
        }
        // إجبار حالة الإعلانات المخصصة على النجاح
        if ([defaultName isEqualToString:@"personalized_ad_status"]) {
            return @(1);
        }
        // إجبار عدم تقييد الإعلانات
        if ([defaultName isEqualToString:@"gad_rdp"]) {
            return @(0);
        }
    }
    return [self bypass_objectForKey:defaultName];
}

- (BOOL)bypass_boolForKey:(NSString *)defaultName {
    if (defaultName) {
        if ([defaultName isEqualToString:@"gad_has_consent_for_cookies"] ||
            [defaultName isEqualToString:@"gad_rdp"]) {
            return YES;
        }
    }
    return [self bypass_boolForKey:defaultName];
}

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        
        // تبديل دالة objectForKey
        Method originalObj = class_getInstanceMethod(class, @selector(objectForKey:));
        Method swizzledObj = class_getInstanceMethod(class, @selector(bypass_objectForKey:));
        if (originalObj && swizzledObj) {
            method_exchangeImplementations(originalObj, swizzledObj);
        }
        
        // تبديل دالة boolForKey
        Method originalBool = class_getInstanceMethod(class, @selector(boolForKey:));
        Method swizzledBool = class_getInstanceMethod(class, @selector(bypass_boolForKey:));
        if (originalBool && swizzledBool) {
            method_exchangeImplementations(originalBool, swizzledBool);
        }
    });
}

@end

%ctor {
    [[AdBypasserOverlay sharedInstance] logMessage:@"[SUCCESS] Consent Bypasser Hooked Successfully!"];
}
