#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>

// توليد معرفات جديدة كلياً
static NSString *randomNewIDFA() {
    return [[NSUUID UUID] UUIDString];
}

// توليد IP أوروبي سكني متغير بالكامل عشوائياً لكل رقم
static NSString *randomEuropeanIP() {

    return [NSString stringWithFormat:@"172.59.%d.%d", arc4random_uniform(250) + 1, arc4random_uniform(250) + 1];
}

// توليد مدة غياب عشوائية ومتغيرة في كل فتحة تطبيق (مثلاً بين 10 أيام إلى 60 يوماً بالثواني)
static double randomInactivitySeconds() {
    // تتراوح بين 864,000 ثانية (10 أيام) إلى 5,184,000 ثانية (60 يوماً) بشكل عشوائي تماماً
    return (double)(864000 + arc4random_uniform(4320000));
}

// توليد تاريخ تثبيت حديث ومختلف لكل إقلاع
static NSString *generateFreshTimestamp() {
    NSDate *now = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'+0300'"];
    return [formatter stringFromDate:now];
}

%ctor {
    @autoreleasepool {
        // تنظيف شامل ومسح كامل لذاكرة التخزين المؤقت للـ NSUserDefaults لضمان عدم بقاء أي أثر قديم
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleIdentifier) {
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleIdentifier];
        }
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *freshID = randomNewIDFA();
        NSString *freshDate = generateFreshTimestamp();
        double dynamicInactivityTime = randomInactivitySeconds(); // قيمة متغيرة في كل مرة
        
        // 1. حقن هويات أجهزة وتثبيت طازجة كلياً ومتغيرة
        [defaults setObject:freshID forKey:@"device.id.key"];
        [defaults setObject:freshID forKey:@"com.google.sso.GeneratedDeviceIdentifier"];
        [defaults setObject:freshID forKey:@"AppsFlyerUserId"];
        [defaults setObject:freshID forKey:@"com.firebase.installations.app_id_to_fiid_enforcement"];
        
        // 2. تصفير العدادات
        [defaults setInteger:1 forKey:@"AppsFlyerRealLaunchCounter"];
        [defaults setInteger:0 forKey:@"AppsFlyerReinstallCounter"];
        [defaults setInteger:1 forKey:@"AppsFlyerLaunchKey"];
        [defaults setInteger:3 forKey:@"ump_status"];
        [defaults setInteger:1 forKey:@"IABTCF_gdprApplies"];
        
        // 3. تواريخ التثبيت المتغيرة
        [defaults setObject:freshDate forKey:@"AppsFlyerInstallDate"];
        [defaults setObject:freshDate forKey:@"AppsFlyerFirstLaunchDate"];
        [defaults setObject:freshDate forKey:@"AppsFlyerInstallTimestamp"];
        
        // 4. أوقات الجلسات
        [defaults setDouble:0.0 forKey:@"AppsFlyerLastSessionDuration"];
        
        // --- 5. حقن مدة الغياب العشوائية والمتغيرة في كل دخول للتطبيق ---
        [defaults setDouble:dynamicInactivityTime forKey:@"AppsFlyerTimePassedSincePrevLaunch"];
        [defaults setDouble:dynamicInactivityTime forKey:@"time_passed_since_last_session"];
        [defaults setDouble:dynamicInactivityTime forKey:@"last_activity_interval"];
        
        [defaults synchronize];
        
        // مسح ملفات الـ Caches المؤقتة برمجياً عند الإقلاع
        NSArray *cacPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *cacheDirectory = [cacPaths objectAtIndex:0];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error = nil;
        NSArray *cacheFiles = [fileManager contentsOfDirectoryAtPath:cacheDirectory error:&error];
        for (NSString *file in cacheFiles) {
            if ([file containsString:@"firebase"] || [file containsString:@"appmetrica"] || [file containsString:@"ads"]) {
                [fileManager removeItemAtPath:[cacheDirectory stringByAppendingPathComponent:file] error:nil];
            }
        }
        
        NSLog(@"[Dynamic-Master] Generated random ID: %@ with random inactivity: %f seconds", freshID, dynamicInactivityTime);
    }
}

// UIDevice متجدد كلياً
%hook UIDevice
- (NSUUID *)identifierForVendor {
    return [NSUUID UUID];
}
%end

// IDFA جديد ونشط
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return [NSUUID UUID];
}
- (BOOL)isAdvertisingTrackingEnabled {
    return YES;
}
%end

// حقن IP أوروبي متغير كلياً وعشوائياً مع كل طلب شبكة
%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field isEqualToString:@"X-Forwarded-For"] || [field isEqualToString:@"Client-IP"] || [field isEqualToString:@"True-Client-IP"]) {
        value = randomEuropeanIP(); // سيولد IP مختلف تماماً في كل طلب
    }
    %orig(value, field);
}
%end

// ضمان عمل الإعلانات ومنح النقاط بلا توقف
%hook ActivatorAdService

- (BOOL)isReady {
    return YES;
}

- (BOOL)isAdReady {
    return YES;
}

- (void)showRewardAd {
    %orig;
    NSLog(@"[Dynamic-Master] Ad triggered successfully with dynamic values.");
}

- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    NSLog(@"[Dynamic-Master] Ad failed, bypassing to award points.");
}
%end
