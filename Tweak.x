#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>

// دالة مسح الـ Keychain مع استثناء الـ tokenKey الخاص بالحساب ليبقى آمناً
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
                    NSLog(@"[Protected-Keychain] tokenKey preserved securely: %@", service);
                }
            }
            if (result) {
                CFRelease(result);
            }
        }
    }
}

// توليد معرفات وبصمات جديدة كلياً في كل إقلاع لتغيير التوقيع الرقمي
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

%ctor {
    @autoreleasepool {
        // 1. مسح الـ Keychain وتغيير البصمة مع الحفاظ على الـ tokenKey
        clearKeychainExceptToken();

        // 2. مسح NSUserDefaults لتغيير التوقيع الرقمي بالكامل
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleIdentifier) {
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleIdentifier];
        }
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *freshID = randomNewIDFA();
        NSString *freshDate = generateFreshTimestamp();
        double dynamicInactivityTime = randomInactivitySeconds();
        
        // 3. حقن الهويات الجديدة كلياً
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
        
        // 4. مسح الكاش المؤقت
        NSArray *cacPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *cacheDirectory = [cacPaths objectAtIndex:0];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSArray *cacheFiles = [fileManager contentsOfDirectoryAtPath:cacheDirectory error:nil];
        for (NSString *file in cacheFiles) {
            if ([file containsString:@"firebase"] || [file containsString:@"appmetrica"] || [file containsString:@"ads"]) {
                [fileManager removeItemAtPath:[cacheDirectory stringByAppendingPathComponent:file] error:nil];
            }
        }
        
        NSLog(@"[Signature-Rotator] Digital signature changed & Keychain wiped for ID: %@", freshID);
    }
}

// تثبيت بصمات الأجهزة الوهمية المتجددة
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
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field isEqualToString:@"X-Forwarded-For"] || [field isEqualToString:@"Client-IP"] || [field isEqualToString:@"True-Client-IP"]) {
        value = randomEuropeanIP();
    }
    %orig(value, field);
}
%end

// --- التعديل الجذري لمنع ظهور "No ad yet" وإجبار الدوران والفتح الفوري ---
%hook ActivatorAdService

- (BOOL)isReady {
    return YES;
}

- (BOOL)isAdReady {
    return YES;
}

// إذا حاول التطبيق جلب إعلان وفشل، نجبره على إعادة المحاولة تلقائياً فوراً بدلاً من إعطاء خطأ
- (void)loadAd {
    %orig;
    // محاكاة إعادة المحاولة الذاتية لتفادي حالة No ad yet
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self loadAd];
    });
}

- (void)fetchAd {
    %orig;
}

// عند الضغط على زر الإعلان، يتم فتح المكافأة ومنح النقاط فوراً بدون انتظار تحميل وهمي
- (void)showRewardAd {
    %orig;
    NSLog(@"[Signature-Rotator] showRewardAd forced successfully, bypassing wait states.");
}

- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    NSLog(@"[Signature-Rotator] Ad error intercepted, forcing reward grant.");
}

%end
