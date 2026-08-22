#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import <SystemConfiguration/SystemConfiguration.h>

@interface ProAdManager : NSObject
+ (instancetype)sharedInstance;
- (NSString *)getCleanIDFA;
- (NSString *)getCleanIDFV;
- (void)showDashboard;
- (void)wipeDataKeepKeychain;
- (void)createPersistentButton;
@end

@implementation ProAdManager {
    UIWindow *floatingWindow;
}

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

- (void)rotateIDs {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[[NSUUID UUID] UUIDString] forKey:@"pro_fake_idfa"];
    [defaults setObject:[[NSUUID UUID] UUIDString] forKey:@"pro_fake_idfv"];
    [defaults synchronize];
}

- (void)showDashboard {
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    UIViewController *rootVC = window.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }

    NSString *msg = [NSString stringWithFormat:
                     @"🔥 أداة الحماية والإعلانات نشطة\n\n"
                     @"🆔 IDFA الحالي:\n%@\n\n"
                     @"📱 IDFV الحالي:\n%@", 
                     [self getCleanIDFA], [self getCleanIDFV]];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🛡️ لوحة تحكم الإعلانات" 
                                                                   message:msg 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"🔄 مسح الداتا (مع الحفاظ على الـ Keychain)" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self wipeDataKeepKeychain];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"إغلاق" style:UIAlertActionStyleCancel handler:nil]];
    
    [rootVC presentViewController:alert animated:YES completion:nil];
}

- (void)wipeDataKeepKeychain {
    // 1. تدوير معرفات الإعلانات ليعتبرك الإعلان مستخدما جديدا
    [self rotateIDs];
    
    // 2. مسح ملفات التفضيلات و UserDefaults (الداتا العادية)
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleID];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *home = NSHomeDirectory();
    NSString *prefsPath = [home stringByAppendingPathComponent:@"Library/Preferences"];
    for (NSString *file in [fm contentsOfDirectoryAtPath:prefsPath error:nil]) {
        if ([file containsString:bundleID]) {
            [fm removeItemAtPath:[prefsPath stringByAppendingPathComponent:file] error:nil];
        }
    }
    
    // ملاحظة: الـ Keychain يبقى سليماً لحفظ النقاط والجلسات
    
    // 3. إعادة تشغيل التطبيق
    exit(0);
}

- (void)createPersistentButton {
    if (floatingWindow) return;

    if (@available(iOS 13.0, *)) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                floatingWindow = [[UIWindow alloc] initWithWindowScene:scene];
                break;
            }
        }
    }
    
    if (!floatingWindow) {
        floatingWindow = [[UIWindow alloc] initWithFrame:CGRectMake(15, 110, 140, 42)];
    }

    floatingWindow.windowLevel = UIWindowLevelAlert + 1;
    floatingWindow.hidden = NO;
    floatingWindow.backgroundColor = [UIColor clearColor];

    UIViewController *vc = [[UIViewController alloc] init];
    floatingWindow.rootViewController = vc;

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    [btn setFrame:CGRectMake(0, 0, 140, 42)];
    [btn setTitle:@"🛡️ أدوات الإعلانات" forState:UIControlStateNormal];
    [btn setBackgroundColor:[UIColor colorWithRed:0.05 green:0.05 blue:0.05 alpha:0.9]];
    [btn setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
    btn.layer.cornerRadius = 12;
    btn.layer.borderWidth = 1.2;
    btn.layer.borderColor = [UIColor greenColor].CGColor;

    [btn addTarget:self action:@selector(showDashboard) forControlEvents:UIControlEventTouchUpInside];
    [vc.view addSubview:btn];
    
    floatingWindow.frame = CGRectMake(15, 110, 140, 42);
}

@end

// --- 1. خداع نظام الإعلانات (IDFA) ---
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return [[NSUUID alloc] initWithUUIDString:[[ProAdManager sharedInstance] getCleanIDFA]];
}
- (BOOL)isAdvertisingTrackingEnabled {
    return YES;
}
%end

// --- 2. خداع معرف البائع (IDFV) ---
%hook UIDevice
- (NSUUID *)identifierForVendor {
    return [[NSUUID alloc] initWithUUIDString:[[ProAdManager sharedInstance] getCleanIDFV]];
}
%end

// --- 3. منع كشف الـ VPN والبروكسي ---
%hook NSURLSessionConfiguration
- (NSDictionary *)connectionProxyDictionary {
    return nil;
}
%end

%hook NSDictionary
- (id)objectForKey:(id)aKey {
    if ([aKey isKindOfClass:[NSString class]]) {
        if ([(NSString *)aKey isEqualToString:@"HTTPEnable"] || [(NSString *)aKey isEqualToString:@"HTTPProxy"]) {
            return nil;
        }
    }
    return %orig;
}
%end

// --- 4. تشغيل الزر بشكل دائم لا يختفي أبداً ---
%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[ProAdManager sharedInstance] createPersistentButton];
    });
}
