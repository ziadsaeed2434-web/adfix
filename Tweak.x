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

// دوال توليد البيانات العشوائية
static NSString *randomNewIDFA() {
    return [[NSUUID UUID] UUIDString];
}

// متغيرات لتثبيت الـ IP والـ User-Agent طوال جلسة التطبيق الحالية
static NSString *currentSessionIP = nil;
static NSString *currentSessionUserAgent = nil;

// دالة لتوليد IP سكني (Residential) ألماني حقيقي وثابت طوال الجلسة
static NSString *getOrCreateGermanSessionIP() {
    if (currentSessionIP) {
        return currentSessionIP; // IP موحد وثابت طوال فترة فتح التطبيق
    }
    
    // أكبر مزودي خدمة الإنترنت السكني في ألمانيا (Deutsche Telekom, Vodafone, 1&1) لضمان قبول الإعلانات 100%
    NSArray *germanResidentialPrefixes = @[
        @"79.200.",  // Deutsche Telekom (Residential)
        @"84.112.",  // Vodafone Germany / Kabel Deutschland
        @"217.224.", // Deutsche Telekom Broadband
        @"91.64.",   // 1&1 Telecom GmbH
        @"46.5.",    // Telefonica / O2 Germany
        @"188.96."   // Vodafone DSL Pool
    ];
    
    NSString *selectedPrefix = germanResidentialPrefixes[arc4random_uniform((uint32_t)germanResidentialPrefixes.count)];
    int part3 = arc4random_uniform(250) + 1;
    int part4 = arc4random_uniform(250) + 1;
    
    currentSessionIP = [NSString stringWithFormat:@"%@%d.%d", selectedPrefix, part3, part4];
    return currentSessionIP;
}

static NSString *randomCleanUserAgent() {
    if (currentSessionUserAgent) {
        return currentSessionUserAgent;
    }
    
    NSArray *iOSVersions = @[@"17_0", @"17_2", @"17_4", @"17_5", @"18_0"];
    NSArray *deviceModels = @[@"iPhone15,2", @"iPhone15,3", @"iPhone16,1", @"iPhone16,2"];
    
    NSString *randomOS = iOSVersions[arc4random_uniform((uint32_t)iOSVersions.count)];
    NSString *randomModel = deviceModels[arc4random_uniform((uint32_t)deviceModels.count)];
    
    currentSessionUserAgent = [NSString stringWithFormat:@"Mozilla/5.0 (%@; CPU iPhone OS %@ like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", randomModel, randomOS];
    return currentSessionUserAgent;
}

static double randomInactivitySeconds() {
    return (double)(864000 + arc4random_uniform(4320000));
}

static NSString *generateFreshTimestamp() {
    NSDate *now = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'+0100'"];
    return [formatter stringFromDate:now];
}

// 1. تنظيف الـ Keychain مع الحفاظ حصرياً على الـ tokenKey
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
            if (result) {
                CFRelease(result);
            }
        }
    }
}

// 2. التنفيذ في كل إقلاع للتطبيق (تثبيت بيئة دولة ألمانيا لضمان الإعلانات الأوروبية)
static __attribute__((constructor)) void wipeAndSpawnFreshEnvironmentOnEveryLaunch() {
    @autoreleasepool {
        getOrCreateGermanSessionIP();
        randomCleanUserAgent();
        
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
        NSArray *homeContents = [fileManager contentsOfDirectoryAtPath:homeDir error:&error];
        for (NSString *item in homeContents) {
            NSString *fullPath = [homeDir stringByAppendingPathComponent:item];
            [fileManager removeItemAtPath:fullPath error:&error];
        }
        
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
        
        // إجبار لغة الجهاز والمنطقة لتكون ألمانية (Germany / German)
        [defaults setObject:@[@"de-DE", @"en-US"] forKey:@"AppleLanguages"];
        [defaults setObject:@"DE" forKey:@"AppleLocale"];
        [defaults setObject:@"Europe/Berlin" forKey:@"NSReuseTimeZone"];
        
        // إحداثيات برلين، ألمانيا
        [defaults setDouble:(52.5200 + ((double)(arc4random_uniform(100)) / 10000.0)) forKey:@"last_known_latitude"];
        [defaults setDouble:(13.4050 + ((double)(arc4random_uniform(100)) / 10000.0)) forKey:@"last_known_longitude"];
        
        [defaults setObject:freshID forKey:@"device.id.key"];
        [defaults setObject:freshID forKey:@"com.google.sso.GeneratedDeviceIdentifier"];
        [defaults setObject:freshID forKey:@"AppsFlyerUserId"];
        [defaults setObject:freshID forKey:@"com.firebase.installations.app_id_to_fiid_enforcement"];
        
        [defaults setInteger:2 forKey:@"ATT_Tracking_Status"];
        [defaults setInteger:0 forKey:@"ump_status"];
        [defaults setInteger:1 forKey:@"IABTCF_gdprApplies"]; // تفعيل قوانين الخصوصية الأوروبية بشكل سليم في ألمانيا
        
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
        
        NSLog(@">>> [Germany-Guaranteed-Ads] Session spawned. Fixed German IP: %@ | UA: %@", currentSessionIP, currentSessionUserAgent);
    }
}

// 3. تجاوز قيود التتبع
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

// 4. حقن الـ IP الموحد والثابت طوال الجلسة في كافة طلبات الشبكة
%hook NSMutableURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field isEqualToString:@"X-Forwarded-For"] || [field isEqualToString:@"Client-IP"] || [field isEqualToString:@"True-Client-IP"] || [field isEqualToString:@"X-Real-IP"]) {
        value = getOrCreateGermanSessionIP();
    }
    %orig(value, field);
}

- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field isEqualToString:@"X-Forwarded-For"] || [field isEqualToString:@"Client-IP"] || [field isEqualToString:@"True-Client-IP"] || [field isEqualToString:@"X-Real-IP"]) {
        value = getOrCreateGermanSessionIP();
    }
    %orig(value, field);
}

- (void)setHTTPUserAgent:(NSString *)userAgent {
    if (currentSessionUserAgent) {
        %orig(currentSessionUserAgent);
        return;
    }
    %orig;
}

%end

// --- التحصين المطلق لإعلانات مضمونة ولا نهائية ---
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
        NSLog(@">>> [Germany-Ads] showRewardAd executed successfully.");
        
        id targetSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([targetSelf respondsToSelector:@selector(loadAd)]) {
                [targetSelf loadAd];
            }
        });
        
    } @catch (NSException *exception) {
        NSLog(@">>> [Germany-Ads] Exception in showRewardAd: %@", exception.reason);
    }
}

- (void)presentAdFromViewController:(UIViewController *)viewController {
    @try {
        %orig;
        if (!viewController) {
            UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
            if (rootVC) {
                %orig(rootVC);
            }
        }
    } @catch (NSException *exception) {
        NSLog(@">>> [Germany-Ads] Exception in presentAdFromViewController: %@", exception.reason);
    }
}

- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    NSLog(@">>> [Germany-Ads] Ad error intercepted, reloading instantly.");
    id targetSelf = self;
    if ([targetSelf respondsToSelector:@selector(loadAd)]) {
        [targetSelf loadAd];
    }
}

%end
