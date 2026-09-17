#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <WebKit/WebKit.h>
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
                    NSLog(@">>> [Dynamic-Refresh] tokenKey safely preserved: %@", service);
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

// 2. دالة مركزية شاملة لتنظيف البيئة بالكامل وتوليد هوية وجهاز جديد
static void executeFullEnvironmentRefresh() {
    @autoreleasepool {
        // أ) حماية التوكن في الكيشين
        clearKeychainExceptToken();

        // ب) مسح نطاق الـ NSUserDefaults بالكامل
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleIdentifier) {
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleIdentifier];
        }

        // ج) تفريغ كاش الشبكة بالكامل
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        [[NSURLCache sharedURLCache] setDiskCapacity:0];
        [[NSURLCache sharedURLCache] setMemoryCapacity:0];

        // د) مسح بيانات WebKit و Local Storage و IndexedDB و Cookies جذرياً
        if ([WKWebsiteDataStore class]) {
            NSSet *websiteDataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
            NSDate *dateFrom = [NSDate distantPast];
            [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes modifiedSince:dateFrom completionHandler:^{
                NSLog(@">>> [Dynamic-Refresh] WKWebsiteDataStore wiped successfully.");
            }];
        }

        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *homeDir = NSHomeDirectory();
        
        // هـ) مسح مسارات WebKit التقليدية يدوياً من الـ Sandbox
        NSArray *webkitSubpaths = @[
            @"Library/Caches/WebKit",
            @"Library/WebKit",
            @"Library/Cookies",
            @"Documents/WebKit"
        ];
        for (NSString *subpath in webkitSubpaths) {
            NSString *fullWebKitPath = [homeDir stringByAppendingPathComponent:subpath];
            if ([fileManager fileExistsAtPath:fullWebKitPath]) {
                [fileManager removeItemAtPath:fullWebKitPath error:nil];
            }
        }
        
        // و) مسح الـ Sandbox الرئيسي بالكامل
        NSError *error = nil;
        NSArray *homeContents = [fileManager contentsOfDirectoryAtPath:homeDir error:&error];
        for (NSString *item in homeContents) {
            NSString *fullPath = [homeDir stringByAppendingPathComponent:item];
            [fileManager removeItemAtPath:fullPath error:&error];
        }
        
        // ز) مسح كل الـ App Groups المرتبطة
        NSString *groupDirBase = [[[homeDir stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Group Containers"];
        if ([fileManager fileExistsAtPath:groupDirBase]) {
            NSArray *groupFolders = [fileManager contentsOfDirectoryAtPath:groupDirBase error:nil];
            for (NSString *groupFolder in groupFolders) {
                NSString *groupPath = [groupDirBase stringByAppendingPathComponent:groupFolder];
                [fileManager removeItemAtPath:groupPath error:nil];
            }
        }

        // ح) حقن هويات وبصمات جديدة بالكامل
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *freshID = randomNewIDFA();
        NSString *freshDate = generateFreshTimestamp();
        double dynamicInactivityTime = randomInactivitySeconds();
        
        [defaults setObject:freshID forKey:@"device.id.key"];
        [defaults setObject:freshID forKey:@"com.google.sso.GeneratedDeviceIdentifier"];
        [defaults setObject:freshID forKey:@"AppsFlyerUserId"];
        [defaults setObject:freshID forKey:@"com.firebase.installations.app_id_to_fiid_enforcement"];
        
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
        
        NSLog(@">>> [Dynamic-Refresh] Full environment wiped & fresh ID spawned: %@", freshID);
    }
}

static __attribute__((constructor)) void initialAppLaunchSetup() {
    executeFullEnvironmentRefresh();
}

// 3. فرض حالة رفض التتبع على مستوى النظام برمجياً
%hook ATTrackingManager
+ (NSUInteger)trackingAuthorizationStatus {
    return 2;
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
    return NO;
}
%end

%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field isEqualToString:@"X-Forwarded-For"] || [field isEqualToString:@"Client-IP"] || [field isEqualToString:@"True-Client-IP"]) {
        value = randomEuropeanIP();
    }
    %orig(value, field);
}
%end

// --- التصحيح هنا: السماح للـ SDK بجلب الإعلان الحقيقي مع تجاوز فحوصات الجاهزية الوهمية ---
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
    // الأهم: استدعاء الدالة الأصلية `%orig` لكي يقوم الـ SDK بطلب الإعلان فعلياً من السيرفر
    %orig;
    NSLog(@">>> [Dynamic-Refresh] loadAd requested from app, fetching real ad from server...");
}

- (void)showRewardAd {
    @try {
        %orig;
        NSLog(@">>> [Dynamic-Refresh] showRewardAd executed. Refreshing environment for the next ad.");
        
        // بعد عرض الإعلان وانتهاءه، نعطي مهلة ثانية ثم ننظف البيئة ونطلب إعلاناً جديداً
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            executeFullEnvironmentRefresh();
            
            if ([self respondsToSelector:@selector(loadAd)]) {
                [self loadAd];
            }
        });
        
    } @catch (NSException *exception) {
        NSLog(@">>> [Dynamic-Refresh] Exception in showRewardAd: %@", exception.reason);
    }
}

- (void)presentAdFromViewController:(UIViewController *)viewController {
    @try {
        %orig;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            executeFullEnvironmentRefresh();
            
            if ([self respondsToSelector:@selector(loadAd)]) {
                [self loadAd];
            }
        });
    } @catch (NSException *exception) {
        NSLog(@">>> [Dynamic-Refresh] Exception caught in presentAdFromViewController: %@", exception.reason);
    }
}

- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    NSLog(@">>> [Dynamic-Refresh] Ad error intercepted: %@, refreshing and re-loading.", arg2);
    executeFullEnvironmentRefresh();
    
    if ([self respondsToSelector:@selector(loadAd)]) {
        [self loadAd];
    }
}

%end
