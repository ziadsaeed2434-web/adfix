#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <objc/runtime.h>

// إعلان مسبق للكلاسات
@interface ActivatorAdService : NSObject
- (void)loadAd;
- (BOOL)isReady;
- (BOOL)isAdReady;
- (void)showRewardAd;
@end

// 1. تنظيف الـ Keychain مع الحفاظ التام على الـ tokenKey
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
                    NSLog(@">>> [Pre-Main] tokenKey preserved securely: %@", service);
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

    return [NSString stringWithFormat:@"172.59.%d.%d", arc4random_uniform(250) + 1, arc4random_uniform(250) + 1];
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

// دالة الحقن الفوري والسبق المطلق قبل أي شيء
static __attribute__((constructor)) void preMainInitialization() {
    @autoreleasepool {
        // الخطوة 1: تنظيف الكيين تشين بالكامل ما عدا التوكن قبل قراءة أي بيانات
        clearKeychainExceptToken();

        // الخطوة 2: مسح نطاق الـ NSUserDefaults للملفات القديمة
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleIdentifier) {
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleIdentifier];
        }
        
        // الخطوة 3: توليد الحقن والهويات الجديدة كلياً
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *freshID = randomNewIDFA();
        NSString *freshDate = generateFreshTimestamp();
        double dynamicInactivityTime = randomInactivitySeconds();
        
        // الخطوة 4: كتابة البصمة الجديدة قبل تشغيل خيوط التطبيق
        [defaults setObject:freshID forKey:@"device.id.key"];
        [defaults setObject:freshID forKey:@"com.google.sso.GeneratedDeviceIdentifier"];
        [defaults setObject:freshID forKey:@"AppsFlyerUserId"];
        [defaults setObject:freshID forKey:@"com.firebase.installations.app_id_to_fiid_enforcement"];
        
        [defaults setInteger:1 forKey:@"AppsFlyerRealLaunchCounter"];
        [defaults setInteger:0 forKey:@"AppsFlyerReinstallCounter"];
        [defaults setInteger:1 forKey:@"AppsFlyerLaunchKey"];
        [defaults setInteger:3 forKey:@"ump_status"];
        [defaults setInteger:1 forKey:@"IABTCF_gdprApplies"];
        
        [defaults setObject:freshDate forKey:@"AppsFlyerInstallDate"];
        [defaults setObject:freshDate forKey:@"AppsFlyerFirstLaunchDate"];
        [defaults setObject:freshDate forKey:@"AppsFlyerInstallTimestamp"];
        
        [defaults setDouble:0.0 forKey:@"AppsFlyerLastSessionDuration"];
        [defaults setDouble:dynamicInactivityTime forKey:@"AppsFlyerTimePassedSincePrevLaunch"];
        [defaults setDouble:dynamicInactivityTime forKey:@"time_passed_since_last_session"];
        [defaults setDouble:dynamicInactivityTime forKey:@"last_activity_interval"];
        
        [defaults synchronize];
        
        // الخطوة 5: تدمير أي كاش مؤقت للإعلانات أو التحليلات
        NSArray *cacPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *cacheDirectory = [cacPaths objectAtIndex:0];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSArray *cacheFiles = [fileManager contentsOfDirectoryAtPath:cacheDirectory error:nil];
        for (NSString *file in cacheFiles) {
            if ([file containsString:@"firebase"] || [file containsString:@"appmetrica"] || [file containsString:@"ads"] || [file containsString:@"cache"]) {
                [fileManager removeItemAtPath:[cacheDirectory stringByAppendingPathComponent:file] error:nil];
            }
        }
        
        NSLog(@">>> [Pre-Main] Absolute early injection completed successfully with ID: %@", freshID);
    }
}

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
    return YES;
}
%end

// حقن الـ IP الأوروبي المتغير مع طلبات الشبكة
%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field isEqualToString:@"X-Forwarded-For"] || [field isEqualToString:@"Client-IP"] || [field isEqualToString:@"True-Client-IP"]) {
        value = randomEuropeanIP();
    }
    %orig(value, field);
}
%end

// إدارة الإعلانات ومنع رسالة No ad yet نهائياً
%hook ActivatorAdService

- (BOOL)isReady {
    return YES;
}

- (BOOL)isAdReady {
    return YES;
}

- (void)loadAd {
    %orig;
    id targetSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([targetSelf respondsToSelector:@selector(loadAd)]) {
            [targetSelf loadAd];
        }
    });
}

- (void)showRewardAd {
    %orig;
    NSLog(@">>> [Pre-Main] showRewardAd forced successfully.");
}

- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    NSLog(@">>> [Pre-Main] Ad error bypassed, granting reward instantly.");
}

%end
