#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <objc/runtime.h>

@interface ActivatorAdService : NSObject
- (void)loadAd;
- (BOOL)isReady;
- (BOOL)isAdReady;
- (BOOL)canShowAd;
- (BOOL)hasAdLoaded;
- (void)showRewardAd;
- (void)presentAdFromViewController:(UIViewController *)viewController;
@end

// 1. تنظيف الـ Keychain تماماً مع الحفاظ حصرياً على الـ tokenKey
static void clearKeychainExceptToken() {
    NSArray *secClasses = @[
        (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecClassInternetPassword,
        (__bridge id)kSecClassCertificate,
        (__bridge id)kSecClassKey,
        (__bridge id)kSecClassIdentity
    ];
    
    for (id secClass in secClasses) {
        NSDictionary *spec = @{(__bridge id)kSecClass: secClass};
        CFArrayRef result = NULL;
        if (SecItemCopyMatching((__bridge CFDictionaryRef)spec, (CFTypeRef *)&result) == errSecSuccess) {
            NSArray *items = (__bridge NSArray *)result;
            for (NSDictionary *item in items) {
                NSString *account = item[(__bridge id)kSecAttrAccount];
                if (![account isEqualToString:@"tokenKey"]) {
                    NSMutableDictionary *delQuery = [NSMutableDictionary dictionaryWithDictionary:item];
                    delQuery[(__bridge id)kSecClass] = secClass;
                    SecItemDelete((__bridge CFDictionaryRef)delQuery);
                }
            }
            if (result) CFRelease(result);
        }
    }
}

static NSString *randomNewIDFA() {
    return [[NSUUID UUID] UUIDString];
}

static NSString *randomEuropeanIP() {
    return [NSString stringWithFormat:@"82.92.%d.%d", arc4random_uniform(250) + 1, arc4random_uniform(250) + 1];
}

static double randomInactivitySeconds() {
    return (double)(864000 + arc4random_uniform(4320000));
}

static NSString *generateFreshTimestamp() {
    NSDate *now = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'+0300'"];
    return [formatter stringFromDate:now];
}

// 2. دالة الحذف والتنظيف الشاملة والعميقة (كما طلبت تماماً بدون حذف ما يسبب الكرش عند البداية المطلقة)
static void executeFullEnvironmentRefresh() {
    @autoreleasepool {
        clearKeychainExceptToken();

        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleIdentifier) {
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleIdentifier];
        }

        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        [[NSURLCache sharedURLCache] setDiskCapacity:0];
        [[NSURLCache sharedURLCache] setMemoryCapacity:0];

        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *homeDir = NSHomeDirectory();
        NSError *error = nil;
        
        // مسح محتويات مجلدات مؤقتة داخل الساندبوكس بأمان لضمان عدم الكرش
        NSArray *subDirsToClean = @[@"Library/Caches", @"tmp", @"Library/Application Support"];
        for (NSString *subDir in subDirsToClean) {
            NSString *fullSubPath = [homeDir stringByAppendingPathComponent:subDir];
            if ([fileManager fileExistsAtPath:fullSubPath]) {
                NSArray *contents = [fileManager contentsOfDirectoryAtPath:fullSubPath error:&error];
                for (NSString *item in contents) {
                    // حماية بعض ملفات الإعدادات الأساسية لكي لا يحدث Crash
                    if (![item isEqualToString:@"Preferences"]) {
                        NSString *itemPath = [fullSubPath stringByAppendingPathComponent:item];
                        [fileManager removeItemAtPath:itemPath error:&error];
                    }
                }
            }
        }
        
        // مسح الـ Group Containers المرتبطة تماماً
        NSString *groupDirBase = [[[homeDir stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Group Containers"];
        if ([fileManager fileExistsAtPath:groupDirBase]) {
            NSArray *groupFolders = [fileManager contentsOfDirectoryAtPath:groupDirBase error:nil];
            for (NSString *groupFolder in groupFolders) {
                NSString *groupPath = [groupDirBase stringByAppendingPathComponent:groupFolder];
                [fileManager removeItemAtPath:groupPath error:nil];
            }
        }

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *freshID = randomNewIDFA();
        NSString *freshDate = generateFreshTimestamp();
        double dynamicInactivityTime = randomInactivitySeconds();
        
        [defaults setObject:freshID forKey:@"device.id.key"];
        [defaults setObject:freshID forKey:@"com.google.sso.GeneratedDeviceIdentifier"];
        [defaults setObject:freshID forKey:@"AppsFlyerUserId"];
        [defaults setObject:freshID forKey:@"com.firebase.installations.app_id_to_fiid_enforcement"];
        
        [defaults setInteger:3 forKey:@"ATT_Tracking_Status"]; // Authorized
        [defaults setInteger:1 forKey:@"ump_status"];
        [defaults setInteger:1 forKey:@"IABTCF_gdprApplies"];
        [defaults setObject:@"1" forKey:@"gad_has_consent_for_cookies"];
        [defaults setObject:@"1" forKey:@"personalized_ad_status"];
        [defaults setObject:@"0" forKey:@"gad_rdp"];
        
        [defaults setInteger:1 forKey:@"AppsFlyerRealLaunchCounter"];
        [defaults setObject:freshDate forKey:@"AppsFlyerInstallTimestamp"];
        [defaults setDouble:dynamicInactivityTime forKey:@"AppsFlyerTimePassedSincePrevLaunch"];
        
        [defaults synchronize];
        
        NSLog(@">>> [Dynamic-Refresh] Environment wiped successfully without crash.");
    }
}

// تنفيذ التنظيف بعد إقلاع التطبيق بثانية لضمان الاستقرار وعدم الانهيار
static __attribute__((constructor)) void initialAppLaunchSetup() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        executeFullEnvironmentRefresh();
    });
}

// 3. فرض الهوية والتتبع على مستوى النظام
%hook ATTrackingManager
+ (NSUInteger)trackingAuthorizationStatus {
    return 3;
}
%end

%hook UIDevice
- (NSUUID *)identifierForVendor {
    return [NSUUID UUID];
}
%end

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return [NSUUID UUID];
}
- (BOOL)isAdvertisingTrackingEnabled {
    return YES;
}
%end

%hook NSMutableURLRequest
- (void)setValue:(NSString * _Nullable)value forHTTPHeaderField:(NSString *)field {
    if ([field isEqualToString:@"X-Forwarded-For"] || [field isEqualToString:@"Client-IP"] || [field isEqualToString:@"True-Client-IP"]) {
        value = randomEuropeanIP();
    }
    %orig(value, field);
}
%end

// 4. تدمير نصوص "No ad yet" وتحويل الأزرار إجبارياً للعمل
%hook UILabel
- (void)setText:(NSString *)text {
    if (text && ([text rangeOfString:@"no ad" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                  [text rangeOfString:@"soon" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                  [text rangeOfString:@"unavailable" options:NSCaseInsensitiveSearch].location != NSNotFound)) {
        text = @"Ad Ready - Tap to Claim";
    }
    %orig(text);
}
%end

%hook UIButton
- (void)setTitle:(NSString *)title forState:(UIControlState)state {
    if (title && ([title rangeOfString:@"no ad" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                  [title rangeOfString:@"soon" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                  [title rangeOfString:@"wait" options:NSCaseInsensitiveSearch].location != NSNotFound)) {
        title = @"Watch Ad & Get Reward";
        self.userInteractionEnabled = YES;
        self.enabled = YES;
    }
    %orig(title, state);
}
%end

// 5. قاتل المؤقتات والأوقات (NSTimer Killer) لإلغاء الانتظار نهائياً
%hook NSTimer
+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)interval target:(id)target selector:(SEL)aSelector userInfo:(id)userInfo repeats:(BOOL)repeats {
    if (interval > 5.0) {
        interval = 0.1;
    }
    return %orig(interval, target, aSelector, userInfo, repeats);
}
%end

// 6. التحصين المطلق لمدير الإعلانات والدعم التلقائي
%hook ActivatorAdService

- (BOOL)isReady { return YES; }
- (BOOL)isAdReady { return YES; }
- (BOOL)canShowAd { return YES; }
- (BOOL)hasAdLoaded { return YES; }

- (void)loadAd {
    %orig;
    id targetSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([targetSelf respondsToSelector:@selector(loadAd)]) {
            [targetSelf loadAd];
        }
    });
}

- (void)showRewardAd {
    @try {
        %orig;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            executeFullEnvironmentRefresh();
            if ([self respondsToSelector:@selector(loadAd)]) {
                [self loadAd];
            }
        });
    } @catch (NSException *exception) {}
}

- (void)presentAdFromViewController:(UIViewController *)viewController {
    @try {
        %orig;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            executeFullEnvironmentRefresh();
            if ([self respondsToSelector:@selector(loadAd)]) {
                [self loadAd];
            }
        });
    } @catch (NSException *exception) {}
}

- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    executeFullEnvironmentRefresh();
    id targetSelf = self;
    if ([targetSelf respondsToSelector:@selector(loadAd)]) {
        [targetSelf loadAd];
    }
}

%end
