#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>

// دوال توليد الهويات والتواريخ العشوائية
static NSString *randomNewIDFA() {
    return [[NSUUID UUID] UUIDString];
}

static NSString *randomEuropeanIP() {
    return [NSString stringWithFormat:@"172.59.%d.%d", arc4random_uniform(254) + 1, arc4random_uniform(254) + 1];
}

// توليد تواريخ وهمية حديثة جداً أو بعيدة لتحاكي تثبيت جديد كلياً
static NSString *generateRandomInstallDate() {
    // محاكاة تاريخ تثبيت جديد عشوائي في نفس اليوم
    NSDate *now = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd_HHmmss'+0300'"];
    return [formatter stringFromDate:now];
}

%ctor {
    @autoreleasepool {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        // 1. هويات أجهزة جديدة كلياً لكل الـ SDKs
        NSString *newIdentity = randomNewIDFA();
        [defaults setObject:newIdentity forKey:@"device.id.key"];
        [defaults setObject:newIdentity forKey:@"com.google.sso.GeneratedDeviceIdentifier"];
        [defaults setObject:newIdentity forKey:@"AppsFlyerUserId"];
        
        // 2. تدوير عدادات التثبيت والتشغيل ليبدو التطبيق وكأنه مثبت لأول مرة (Fresh Install)
        [defaults setInteger:1 forKey:@"AppsFlyerRealLaunchCounter"]; // العد يبدأ من 1 دائماً
        [defaults setInteger:1 forKey:@"AppsFlyerReinstallCounter"]; // تفعيل عداد إعادة التثبيت
        [defaults setInteger:3 forKey:@"ump_status"];
        [defaults setInteger:1 forKey:@"IABTCF_gdprApplies"];
        [defaults setInteger:1 forKey:@"IABTCF_PurposeOneTreatment"];
        
        // 3. خداع أوقات الجلسات ووقت آخر إطلاق (محاكاة مرور وقت طويل أو تثبيت طازج)
        NSString *freshDate = generateRandomInstallDate();
        [defaults setObject:freshDate forKey:@"AppsFlyerInstallDate"];
        [defaults setObject:freshDate forKey:@"AppsFlyerFirstLaunchDate"];
        
        // تصفير مؤشرات الجلسة السابقة
        [defaults setDouble:0.0 forKey:@"AppsFlyerLastSessionDuration"];
        [defaults setDouble:1789500000.0 forKey:@"AppsFlyerTimePassedSincePrevLaunch"]; // وقت طويل مضى
        
        [defaults synchronize];
        NSLog(@"[Clean-Slate-Master] Fully fresh device session & identity generated: %@", newIdentity);
    }
}

// الحفاظ على معرف الفندور متجدد كلياً لكل جلسة
%hook UIDevice
- (NSUUID *)identifierForVendor {
    return [NSUUID UUID];
}
%end

// تتبع إعلانات مفعل وبصمة IDFA جديدة تماماً في كل فتحة
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return [NSUUID UUID];
}
- (BOOL)isAdvertisingTrackingEnabled {
    return YES;
}
%end

// حقن الـ IP الأوروبي المتجدد في طلبات الشبكة
%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field isEqualToString:@"X-Forwarded-For"] || [field isEqualToString:@"Client-IP"] || [field isEqualToString:@"True-Client-IP"]) {
        value = randomEuropeanIP();
    }
    %orig(value, field);
}
%end

// دعم إظهار الإعلان أو تجاوز الخطأ لمنح المكافأة بضمان تام
%hook ActivatorAdService
- (void)showRewardAd {
    %orig;
    NSLog(@"[Clean-Slate-Master] Ad triggered with fresh session identity.");
}

- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    NSLog(@"[Clean-Slate-Master] Ad failed, bypassing with fresh session to grant points.");
}
%end
