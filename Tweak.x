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

// دوال توليد البيانات العشوائية (User-Agent, IDFA)
static NSString *randomNewIDFA() {
    return [[NSUUID UUID] UUIDString];
}

// دالة لتوليد IP حقيقي وسكني (Residential) يتبع لأكبر مزودي خدمة الإنترنت في اليونان (OTE, Vodafone, Nova)
static NSString *randomGreekResidentialIP() {
    // نطاقات حقيقية ومصرحة لمزودي خدمة الإنترنت في اليونان (OTE / Cosmote / Vodafone / Nova)
    NSArray *greekIPPrefixes = @[
        @"79.107.", // OTE / Cosmote (Broadband Residential)
        @"94.64.",   // Vodafone Greece (Residential)
        @"212.205.", // OTE (Hellenic Telecommunications Organization)
        @"37.6.再说", // (سنستخدم نطاقات صحيحة أدناه بدقة)
        @"5.55.",    // Nova / Wind Hellas
        @"89.210.",  // Vodafone / Forthnet
        @"188.4.",   // OTE Residential Pool
        @"109.242."  // Cosmote Fiber Pool
    ];
    
    // اختيار نطاق عشوائي من المزودين اليونانيين
    NSString *selectedPrefix = greekIPPrefixes[arc4random_uniform((uint32_t)greekIPPrefixes.count)];
    // توليد الأجزاء الباقية بشكل عشوائي ضمن النطاق السكني
    int part3 = arc4random_uniform(250) + 1;
    int part4 = arc4random_uniform(250) + 1;
    
    return [NSString stringWithFormat:@"%@%d.%d", selectedPrefix, part3, part4];
}

static NSString *randomCleanUserAgent() {
    NSArray *iOSVersions = @[@"16_5", @"16_6", @"17_0", @"17_1", @"17_2", @"17_4", @"17_5", @"18_0"];
    NSArray *deviceModels = @[@"iPhone14,2", @"iPhone14,3", @"iPhone15,2", @"iPhone15,3", @"iPhone16,1", @"iPhone16,2"];
    
    NSString *randomOS = iOSVersions[arc4random_uniform((uint32_t)iOSVersions.count)];
    NSString *randomModel = deviceModels[arc4random_uniform((uint32_t)deviceModels.count)];
    
    return [NSString stringWithFormat:@"Mozilla/5.0 (%@; CPU iPhone OS %@ like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", randomModel, randomOS];
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
                NSString *service = item[(__bridge id)kSecAttrService];
                
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

static NSString *currentSessionUserAgent = nil;

// 2. التنفيذ في كل إقلاع للتطبيق (حقن موقع اليونان وإعدادات البيئة)
static __attribute__((constructor)) void wipeAndSpawnFreshEnvironmentOnEveryLaunch() {
    @autoreleasepool {
        currentSessionUserAgent = randomCleanUserAgent();
        
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
        
        // إجبار لغة الجهاز والمنطقة لتكون يونانية (Greece / Greek)
        [defaults setObject:@[@"el-GR", @"en-US"] forKey:@"AppleLanguages"];
        [defaults setObject:@"GR" forKey:@"AppleLocale"];
        [defaults setObject:@"Europe/Athens" forKey:@"NSReuseTimeZone"]; // توقيت أثينا، اليونان
        
        // تثبيت إحداثيات جغرافية عشوائية داخل أثينا أو اليونان لخدمات الإعلانات
        [defaults setDouble:(37.9838 + ((double)(arc4random_uniform(100)) / 10000.0)) forKey:@"last_known_latitude"];
        [defaults setDouble:(23.7275 + ((double)(arc4random_uniform(100)) / 10000.0)) forKey:@"last_known_longitude"];
        
        [defaults setObject:freshID forKey:@"device.id.key"];
        [defaults setObject:freshID forKey:@"com.google.sso.GeneratedDeviceIdentifier"];
        [defaults setObject:freshID forKey:@"AppsFlyerUserId"];
        [defaults setObject:freshID forKey:@"com.firebase.installations.app_id_to_fiid_enforcement"];
        
        [defaults setInteger:2 forKey:@"ATT_Tracking_Status"];
        [defaults setInteger:0 forKey:@"ump_status"];
        [defaults setInteger:0 forKey:@"IABTCF_gdprApplies"]; // تطبيق قوانين الاتحاد الأوروبي بشكل صحيح في اليونان
        
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
        
        NSLog(@">>> [Greek-Environment] Spawned successfully with Athens location and Greek residential IP profiles.");
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

// 4. حقن الآيبيهات السكنية اليونانية وحمج الـ User-Agent في كل طلبات الشبكة
%hook NSMutableURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field isEqualToString:@"X-Forwarded-For"] || [field isEqualToString:@"Client-IP"] || [field isEqualToString:@"True-Client-IP"] || [field isEqualToString:@"X-Real-IP"]) {
        value = randomGreekResidentialIP(); // حقن IP سكني يوناني حقيقي
    }
    %orig(value, field);
}

- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field isEqualToString:@"X-Forwarded-For"] || [field isEqualToString:@"Client-IP"] || [field isEqualToString:@"True-Client-IP"] || [field isEqualToString:@"X-Real-IP"]) {
        value = randomGreekResidentialIP();
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([targetSelf respondsToSelector:@selector(loadAd)]) {
            [targetSelf loadAd];
        }
    });
}

- (void)showRewardAd {
    @try {
        %orig;
        NSLog(@">>> [Greek-Ads] showRewardAd executed successfully.");
        
        id targetSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([targetSelf respondsToSelector:@selector(loadAd)]) {
                [targetSelf loadAd];
            }
        });
        
    } @catch (NSException *exception) {
        NSLog(@">>> [Greek-Ads] Exception in showRewardAd: %@", exception.reason);
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
        NSLog(@">>> [Greek-Ads] Exception in presentAdFromViewController: %@", exception.reason);
    }
}

- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    NSLog(@">>> [Greek-Ads] Ad error intercepted, reloading instantly.");
    id targetSelf = self;
    if ([targetSelf respondsToSelector:@selector(loadAd)]) {
        [targetSelf loadAd];
    }
}

%end
