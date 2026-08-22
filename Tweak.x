#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ProAdManager : NSObject
+ (instancetype)sharedInstance;
- (NSString *)getCurrentIDFA;
- (void)showDashboard;
- (void)createPersistentButton;
@end

static UIWindow *floatingWindow = nil;

@implementation ProAdManager

+ (instancetype)sharedInstance {
    static ProAdManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[ProAdManager alloc] init]; });
    return shared;
}

// توليد IDFA جديد كلياً في كل مرة يُطلب فيها أو يتم فتح التطبيق
- (NSString *)getCurrentIDFA {
    return [[NSUUID UUID] UUIDString];
}

- (void)showDashboard {
    UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
    UIViewController *rootVC = window.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }

    NSString *msg = [NSString stringWithFormat:
                     @"🔥 معرف الإعلانات (IDFA) يتجدد تلقائياً:\n\n"
                     @"🆔 IDFA الحالي لهذه الجلسة:\n%@", 
                     [self getCurrentIDFA]];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🛡️ لوحة تحكم الإعلانات" 
                                                                   message:msg 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"إغلاق" style:UIAlertActionStyleCancel handler:nil]];
    
    [rootVC presentViewController:alert animated:YES completion:nil];
}

- (void)createPersistentButton {
    if (floatingWindow) return;

    floatingWindow = [[UIWindow alloc] initWithFrame:CGRectMake(20, 100, 130, 40)];
    floatingWindow.windowLevel = UIWindowLevelStatusBar + 100;
    floatingWindow.hidden = NO;
    floatingWindow.backgroundColor = [UIColor clearColor];

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = floatingWindow.bounds;
    [btn setTitle:@"🛡️ أدوات" forState:UIControlStateNormal];
    [btn setBackgroundColor:[UIColor blackColor]];
    [btn setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
    btn.layer.cornerRadius = 10;
    btn.layer.borderWidth = 1.0;
    btn.layer.borderColor = [UIColor greenColor].CGColor;
    
    [btn addTarget:self action:@selector(showDashboard) forControlEvents:UIControlEventTouchUpInside];
    
    UIViewController *btnVC = [[UIViewController alloc] init];
    [btnVC.view addSubview:btn];
    floatingWindow.rootViewController = btnVC;
}
@end

// --- خداع الـ IDFA وجعله يتغير باستمرار ---
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    // يعطي التطبيق معرف إعلانات جديد كلياً في كل مرة يستعلم عنه
    return [[NSUUID alloc] initWithUUIDString:[[ProAdManager sharedInstance] getCurrentIDFA]];
}
- (BOOL)isAdvertisingTrackingEnabled {
    return YES;
}
%end

// تشغيل الزر الثابت عند فتح التطبيق
%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[ProAdManager sharedInstance] createPersistentButton];
    });
}
