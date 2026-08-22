#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ProAdManager : NSObject
+ (instancetype)sharedInstance;
- (NSString *)getCleanIDFA;
- (NSString *)getCleanIDFV;
- (NSString *)getCleanUDID;
- (void)showDashboard;
- (void)createPersistentButton;
- (void)rotateAllIDs;
@end

static UIWindow *floatingWindow = nil;

@implementation ProAdManager

+ (instancetype)sharedInstance {
    static ProAdManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ shared = [[ProAdManager alloc] init]; });
    return shared;
}

- (NSString *)getCleanIDFA {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *val = [defaults stringForKey:@"pro_fake_idfa"];
    if (!val) {
        val = [[NSUUID UUID] UUIDString];
        [defaults setObject:val forKey:@"pro_fake_idfa"];
        [defaults synchronize];
    }
    return val;
}

- (NSString *)getCleanIDFV {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *val = [defaults stringForKey:@"pro_fake_idfv"];
    if (!val) {
        val = [[NSUUID UUID] UUIDString];
        [defaults setObject:val forKey:@"pro_fake_idfv"];
        [defaults synchronize];
    }
    return val;
}

- (NSString *)getCleanUDID {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *val = [defaults stringForKey:@"pro_fake_udid"];
    if (!val) {
        val = [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
        [defaults setObject:val forKey:@"pro_fake_udid"];
        [defaults synchronize];
    }
    return val;
}

- (void)rotateAllIDs {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[[NSUUID UUID] UUIDString] forKey:@"pro_fake_idfa"];
    [defaults setObject:[[NSUUID UUID] UUIDString] forKey:@"pro_fake_idfv"];
    [defaults setObject:[[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""] forKey:@"pro_fake_udid"];
    [defaults synchronize];
}

- (void)showDashboard {
    UIWindow *window = [UIApplication sharedApplication].windows.firstObject;
    UIViewController *rootVC = window.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }

    NSString *msg = [NSString stringWithFormat:
                     @"🔥 حماية الهوية والـ SDKs نشطة:\n\n"
                     @"🆔 IDFA:\n%@\n\n"
                     @"📱 IDFV:\n%@\n\n"
                     @"🔑 UDID الوهمي:\n%@", 
                     [self getCleanIDFA], [self getCleanIDFV], [self getCleanUDID]];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🛡️ لوحة التحكم الشاملة" 
                                                                   message:msg 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"🔄 تدوير المعرفات ومسح الداتا" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self rotateAllIDs];
        [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:[[NSBundle mainBundle] bundleIdentifier]];
        exit(0);
    }]];
    
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

// --- 1. خداع الـ IDFA ---
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return [[NSUUID alloc] initWithUUIDString:[[ProAdManager sharedInstance] getCleanIDFA]];
}
- (BOOL)isAdvertisingTrackingEnabled {
    return YES;
}
%end

// --- 2. خداع الـ IDFV والـ UDID ---
%hook UIDevice
- (NSUUID *)identifierForVendor {
    return [[NSUUID alloc] initWithUUIDString:[[ProAdManager sharedInstance] getCleanIDFV]];
}
- (NSString *)uniqueIdentifier {
    return [[ProAdManager sharedInstance] getCleanUDID];
}
%end

// --- 3. منع كشف الـ VPN والـ Proxy ---
%hook NSURLSessionConfiguration
- (NSDictionary *)connectionProxyDictionary {
    return nil;
}
%end

// --- 4. تجاوز حماية مكتبات الإعلانات (AppLovin & InMobi) ---
%hook ALSdk
- (BOOL)isInitialized {
    return YES;
}
%end

%hook InMobiSdk
+ (BOOL)isInitialized {
    return YES;
}
%end

// --- 5. منع إخفاء الإعلانات أو إلغائها برمجياً ---
%hook UIView
- (void)setAlpha:(CGFloat)alpha {
    if (alpha == 0.0) {
        %orig(1.0);
    } else {
        %orig;
    }
}
- (void)setHidden:(BOOL)hidden {
    %orig(NO);
}
%end

// تشغيل الزر الثابت
%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[ProAdManager sharedInstance] createPersistentButton];
    });
}
