#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>

// توليد معرفات جديدة كلياً
static NSString *randomNewIDFA() {
    return [[NSUUID UUID] UUIDString];
}

static NSString *randomEuropeanIP() {
    return [NSString stringWithFormat:@"172.59.%d.%d", arc4random_uniform(254) + 1, arc4random_uniform(254) + 1];
}

// توليد تاريخ تثبيت يبدو كأنه حدث قبل ثوانٍ معدودة فقط من الفتح الحالي
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
        
        // 1. حقن هويات أجهزة وتثبيت طازجة كلياً
        [defaults setObject:freshID forKey:@"device.id.key"];
        [defaults setObject:freshID forKey:@"com.google.sso.GeneratedDeviceIdentifier"];
        [defaults setObject:freshID forKey:@"AppsFlyerUserId"];
        [defaults setObject:freshID forKey:@"com.firebase.installations.app_id_to_fiid_enforcement"];
        
        // 2. تصفير العدادات لتكون دلالة قاطعة على أنه أول إطلاق (First Launch ever)
        [defaults setInteger:1 forKey:@"AppsFlyerRealLaunchCounter"];
        [defaults setInteger:0 forKey:@"AppsFlyerReinstallCounter"];
        [defaults setInteger:1 forKey:@"AppsFlyerLaunchKey"];
        [defaults setInteger:3 forKey:@"ump_status"];
        [defaults setInteger:1 forKey:@"IABTCF_gdprApplies"];
        
        // 3. خداع تواريخ التثبيت والتشغيل الأول لتكون الآن حصراً
        [defaults setObject:freshDate forKey:@"AppsFlyerInstallDate"];
        [defaults setObject:freshDate forKey:@"AppsFlyerFirstLaunchDate"];
        [defaults setObject:freshDate forKey:@"AppsFlyerInstallTimestamp"];
        
        // 4. تصفير أوقات الجلسات السابقة تماماً
        [defaults setDouble:0.0 forKey:@"AppsFlyerLastSessionDuration"];
        [defaults setDouble:0.0 forKey:@"AppsFlyerTimePassedSincePrevLaunch"];
        
        [defaults synchronize];
        
        // 5. مسح ملفات الـ Caches المؤقتة برمجياً عند الإقلاع لضمان عدم قراءة أي سجل قديم
        NSArray *cacPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *cacheDirectory = [cacPaths objectAtIndex:0];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSError *error = nil;
        NSArray *cacheFiles = [fileManager contentsOfDirectoryAtPath:cacheDirectory error:&error];
        for (NSString *file in cacheFiles) {
            // حذف الملفات المؤقتة الخاصة بالـ SDKs لتجبارها على إعادة التوليد كأنها جديدة
            if ([file containsString:@"firebase"] || [file containsString:@"appmetrica"] || [file containsString:@"ads"]) {
                [fileManager removeItemAtPath:[cacheDirectory stringByAppendingPathComponent:file] error:nil];
            }
        }
        
        NSLog(@"[Absolute-Fresh-Install] Device wiped & generated brand new first-launch fingerprint: %@", freshID);
    }
}

// UIDevice متجدد كلياً
%hook UIDevice
- (NSUUID *)identifierForVendor {
    return [NSUUID UUID];
}
%end

// IDFA جديد ونشط يظهر كأن المستخدم وافق عليه للتو في تثبيت طازج
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return [NSUUID UUID];
}
- (BOOL)isAdvertisingTrackingEnabled {
    return YES;
}
%end

// حقن IP أوروبي سكني متجدد مع كل طلب شبكة
%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field isEqualToString:@"X-Forwarded-For"] || [field isEqualToString:@"Client-IP"] || [field isEqualToString:@"True-Client-IP"]) {
        value = randomEuropeanIP();
    }
    %orig(value, field);
}
%end

// ضمان عمل الإعلانات ومنح النقاط بلا توقف
%hook ActivatorAdService
- (void)showRewardAd {
    %orig;
    NSLog(@"[Absolute-Fresh-Install] Ad triggered successfully under fresh install profile.");
}

- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    NSLog(@"[Absolute-Fresh-Install] Ad failed, bypassing under fresh profile to award points.");
}
%end
