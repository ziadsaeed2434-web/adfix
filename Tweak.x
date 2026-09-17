#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <objc/runtime.h>

// إعلان مسبق شامل لكل الدوال المحتملة لمدير الإعلانات
@interface ActivatorAdService : NSObject
- (void)loadAd;
- (BOOL)isReady;
- (BOOL)isAdReady;
- (BOOL)canShowAd;
- (BOOL)hasAdLoaded;
- (void)showRewardAd;
- (void)presentAdFromViewController:(UIViewController *)viewController;
- (void)grantReward;
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
                NSString *service = item[(__bridge id)kSecAttrService];
                
                if (![account isEqualToString:@"tokenKey"]) {
                    NSMutableDictionary *delQuery = [NSMutableDictionary dictionaryWithDictionary:item];
                    delQuery[(__bridge id)kSecClass] = secClass;
                    SecItemDelete((__bridge CFDictionaryRef)delQuery);
                } else {
                    NSLog(@">>> [Full-Wipe] tokenKey safely preserved: %@", service);
                }
            }
            if (result) {
                CFRelease(result);
            }
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

// 2. محاكاة تثبيت نظيف 100% مع مسح جذري للـ Sandbox، الـ App Groups، وكاش الشبكة
static __attribute__((constructor)) void simulateFreshAppReinstallation() {
    @autoreleasepool {
        // أ) حماية التوكن أولاً في الـ Keychain
        clearKeychainExceptToken();

        // ب) مسح نطاق الـ NSUserDefaults بالكامل
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleIdentifier) {
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleIdentifier];
        }

        // ج) تفريغ ومسح كاش الشبكة بالكامل (URL Cache)
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        [[NSURLCache sharedURLCache] setDiskCapacity:0];
        [[NSURLCache sharedURLCache] setMemoryCapacity:0];

        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        // د) مسح الـ Sandbox الرئيسي بالكامل (كل الملفات والمجلدات بلا استثناء)
        NSString *homeDir = NSHomeDirectory();
        NSError *error = nil;
        NSArray *homeContents = [fileManager contentsOfDirectoryAtPath:homeDir error:&error];
        for (NSString *item in homeContents) {
            NSString *fullPath = [homeDir stringByAppendingPathComponent:item];
            [fileManager removeItemAtPath:fullPath error:&error];
        }
        
        // هـ) مسح كل الـ App Groups وأي ملفات مرتبطة بها جذرياً
        NSString *groupDirBase = [[[homeDir stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Group Containers"];
        if ([fileManager fileExistsAtPath:groupDirBase]) {
            NSArray *groupFolders = [fileManager contentsOfDirectoryAtPath:groupDirBase error:nil];
            for (NSString *groupFolder in groupFolders) {
                NSString *groupPath = [groupDirBase stringByAppendingPathComponent:groupFolder];
                [fileManager removeItemAtPath:groupPath error:nil];
            }
        }

        // و) حقن بصمة جديدة ومعرفات نظيفة كأنه جهاز وتثبيت جديد كلياً
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *freshID = randomNewIDFA();
        NSString *freshDate = generateFreshTimestamp();
        double dynamicInactivityTime = randomInactivitySeconds();
        
        [defaults setObject:freshID forKey:@"device.id.key"];
        [defaults setObject:freshID forKey:@"com.google.sso.GeneratedDeviceIdentifier"];
        [defaults setObject:freshID forKey:@"AppsFlyerUserId"];
        [defaults setObject:freshID forKey:@"com.firebase.installations.app_id_to_fiid_enforcement"];
        
        // فرض حالة رفض التتبع (ATT Denied = 2) لضمان ظهور الإعلانات الفورية
        [defaults setInteger:2 forKey:@"ATT_Tracking_Status"];
        [defaults setInteger:0 forKey:@"ump_status"];
        [defaults setInteger:0 forKey:@"IABTCF_gdprApplies"];
        
        [defaults setInteger:1 forKey:@"AppsFlyerRealLaunchCounter"];
        [defaults setInteger:0 forKey:@"AppsFlyerReinstallCounter"];
        [defaults setInteger:1 forKey:@"AppsFlyerLaunchKey"];
        
        [defaults setObject:freshDate forKey:@"AppsFlyerInstallDate"];
        [defaults setObject:freshDate forKey:@"AppsFlyerFirstLaunchDate"];
        [defaults setObject:freshDate forKey:@"AppsFlyerInstallTimestamp"];
        
        [defaults setDouble:0.0 forKey:@"AppsFlyerLastSessionDuration"];
        [defaults setDouble:dynamicInactivityTime forKey:@"AppsFlyerTimePassedSincePrevLaunch"];
        [defaults setDouble:dynamicInactivityTime forKey:@"time_passed_since_last_session"];
        [defaults setDouble:dynamicInactivityTime forKey:@"last_activity_interval"];
        
        [defaults synchronize];
        
        NSLog(@">>> [Full-Wipe] Sandbox, App Groups, & Network Caches completely destroyed. Fresh environment spawned with ID: %@", freshID);
    }
}

// 3. فرض حالة رفض التتبع على مستوى النظام برمجياً
%hook ATTrackingManager
+ (NSUInteger)trackingAuthorizationStatus {
    return 2; // Denied
}
%end

// تثبيت الهويات الوهمية للأجهزة
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
    return NO;
}
%end

// تزوير الـ IP في كل طلب شبكة
%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field isEqualToString:@"X-Forwarded-For"] || [field isEqualToString:@"Client-IP"] || [field isEqualToString:@"True-Client-IP"]) {
        value = randomEuropeanIP();
    }
    %orig(value, field);
}
%end

// --- التحصين المطلق لمدير الإعلانات ومنع أي فشل نهائياً ---
%hook ActivatorAdService

- (BOOL)isReady {
    return YES;
}

- (BOOL)isAdReady {
    return YES;
}

- (BOOL)canShowAd {
    return YES;
}

- (BOOL)hasAdLoaded {
    return YES;
}

- (void)loadAd {
    %orig;
    id targetSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([targetSelf respondsToSelector:@selector(loadAd)]) {
            [targetSelf loadAd];
        }
    });
}

- (void)showRewardAd {
    @try {
        %orig;
        NSLog(@">>> [Full-Wipe] showRewardAd executed successfully.");
    } @catch (NSException *exception) {
        NSLog(@">>> [Full-Wipe] Exception caught in showRewardAd, bypassing safely: %@", exception.reason);
    }
}

- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    NSLog(@">>> [Full-Wipe] Ad failure intercepted, forcing instant reward delivery.");
    id targetSelf = self;
    if ([targetSelf respondsToSelector:@selector(grantReward)]) {
        [targetSelf grantReward];
    }
}

%end
