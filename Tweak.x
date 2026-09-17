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
@end

// متغير عام لتخزين الآيبي الخاص بالجلسة الحالية
static NSString *currentSessionIP = nil;

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

// دالة لتوليد آيبي أوروبي سكني جديد لجلسة واحدة
static NSString *generateNewEuropeanIP() {
    NSArray *europeanResidentialPrefixes = @[
        // Deutsche Telekom (ألمانيا)
        @"217.91", @"87.138", @"79.200", @"91.32", @"84.160",
        // Vodafone / Liberty Global (ألمانيا / إنجلترا)
        @"176.198", @"88.130", @"95.112", @"82.165", @"212.185",
        // Orange / Free (فرنسا)
        @"90.119", @"80.12", @"176.150", @"78.112", @"86.200",
        // Telefonica / Movistar (إسبانيا)
        @"83.32", @"88.19", @"81.32", @"85.155", @"213.94",
        // Telecom Italia / Fastweb (إيطاليا)
        @"151.15", @"93.32", @"2.30", @"79.16", @"82.50",
        // KPN / Ziggo (هولندا)
        @"84.241", @"94.212", @"82.161", @"213.127",
        // BT / Sky (بريطانيا)
        @"86.128", @"90.240", @"2.120", @"79.130", @"151.224"
    ];
    
    NSString *randomPrefix = europeanResidentialPrefixes[arc4random_uniform((uint32_t)[europeanResidentialPrefixes count]);];
    int thirdOctet = arc4random_uniform(254) + 1;
    int fourthOctet = arc4random_uniform(254) + 1;
    
    return [NSString stringWithFormat:@"%@.%d.%d", randomPrefix, thirdOctet, fourthOctet];
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

// 2. دالة مركزية شاملة لتنظيف البيئة بالكامل وتوليد هوية وجهاز جديد + آيبي ثابت جديد للجلسة
static void executeFullEnvironmentRefresh() {
    @autoreleasepool {
        // توليد آيبي ثابت جديد خاص بهذه الجلسة فقط
        currentSessionIP = generateNewEuropeanIP();
        NSLog(@">>> [Dynamic-Refresh] New Session IP Generated: %@", currentSessionIP);

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

        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        // د) مسح الـ Sandbox الرئيسي بالكامل
        NSString *homeDir = NSHomeDirectory();
        NSError *error = nil;
        NSArray *homeContents = [fileManager contentsOfDirectoryAtPath:homeDir error:&error];
        for (NSString *item in homeContents) {
            NSString *fullPath = [homeDir stringByAppendingPathComponent:item];
            [fileManager removeItemAtPath:fullPath error:&error];
        }
        
        // هـ) مسح كل الـ App Groups المرتبطة
        NSString *groupDirBase = [[[homeDir stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Group Containers"];
        if ([fileManager fileExistsAtPath:groupDirBase]) {
            NSArray *groupFolders = [fileManager contentsOfDirectoryAtPath:groupDirBase error:nil];
            for (NSString *groupFolder in groupFolders) {
                NSString *groupPath = [groupDirBase stringByAppendingPathComponent:groupFolder];
                [fileManager removeItemAtPath:groupPath error:nil];
            }
        }

        // و) حقن هويات وبصمات جديدة بالكامل كأنه جهاز جديد تماماً
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

// تشغيل التطهير تلقائياً مع كل إقلاع للتطبيق
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
        // استخدام الآيبي الثابت الخاص بالجلسة الحالية لكل الطلبات الشبكية ضمن هذه الجلسة
        if (currentSessionIP) {
            value = currentSessionIP;
        }
    }
    %orig(value, field);
}
%end

// --- التحصين المطلق: تجديد البيئة وجلب إعلانات جديدة فوراً بعد انتهاء كل إعلان ---
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([targetSelf respondsToSelector:@selector(loadAd)]) {
            [targetSelf loadAd];
        }
    });
}

- (void)showRewardAd {
    @try {
        %orig;
        NSLog(@">>> [Dynamic-Refresh] showRewardAd executed. Refreshing environment and session IP for the next ad.");
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            executeFullEnvironmentRefresh(); // هذا سيقوم بمسح البيئة وتوليد آيبي جلسة جديد كلياً
            
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
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            executeFullEnvironmentRefresh(); // تجديد الجلسة والآيبي هنا أيضاً
            
            if ([self respondsToSelector:@selector(loadAd)]) {
                [self loadAd];
            }
        });
    } @catch (NSException *exception) {
        NSLog(@">>> [Dynamic-Refresh] Exception caught in presentAdFromViewController: %@", exception.reason);
    }
}

- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    NSLog(@">>> [Dynamic-Refresh] Ad error intercepted, refreshing environment and re-loading.");
    executeFullEnvironmentRefresh();
    id targetSelf = self;
    if ([targetSelf respondsToSelector:@selector(loadAd)]) {
        [targetSelf loadAd];
    }
}

%end
