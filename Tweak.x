#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>

// دالة لتوليد UUID/IDFA عشوائي جديد كلياً بصيغة صحيحة
static NSString *randomNewIDFA() {
    return [[NSUUID UUID] UUIDString];
}

// دالة لتوليد IP أوروبي سكني عشوائي
static NSString *randomEuropeanIP() {
    return [NSString stringWithFormat:@"172.%d.%d.%d", arc4random_uniform(254) + 1, arc4random_uniform(254) + 1, arc4random_uniform(254) + 1];
}

// تنفيذ تلقائي عند كل فتحة تطبيق لإنشاء تتبع وهويّة جديدة بالكامل
%ctor {
    @autoreleasepool {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        // 1. توليد هويات جديدة لجميع مفاتيح التتبع والـ SDKs
        NSString *newIdentity = randomNewIDFA();
        [defaults setObject:newIdentity forKey:@"device.id.key"];
        [defaults setObject:newIdentity forKey:@"com.google.sso.GeneratedDeviceIdentifier"];
        [defaults setObject:newIdentity forKey:@"AppsFlyerUserId"];
        
        // 2. تفعيل حالة الموافقة الأوروبية وتتبع الإعلانات لتبدو قانونية ونشطة
        [defaults setInteger:1 forKey:@"AppsFlyerRealLaunchCounter"];
        [defaults setInteger:0 forKey:@"AppsFlyerReinstallCounter"];
        [defaults setInteger:3 forKey:@"ump_status"];
        [defaults setInteger:1 forKey:@"IABTCF_gdprApplies"];
        [defaults setInteger:1 forKey:@"IABTCF_PurposeOneTreatment"];
        
        [defaults synchronize];
        NSLog(@"[Active-Tracking-Master] New active tracking identity generated: %@", newIdentity);
    }
}

// الحفاظ على معرف الفندور متجدد كلياً لكل جلسة
%hook UIDevice
- (NSUUID *)identifierForVendor {
    return [NSUUID UUID];
}
%end

// جعل نظام التتبع شغالاً (YES) ولكن بـ IDFA متغير وجديد في كل مرة يطلبه التطبيق
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    // إرجاع IDFA جديد ومختلف في كل طلب استعلام لضمان تتبع جديد دائماً
    return [NSUUID UUID];
}
- (BOOL)isAdvertisingTrackingEnabled {
    // ترك التتبع شغال لترضى سيرفرات الإعلانات
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

// تجاوز فشل الإعلانات ومنح النقاط تلقائياً
%hook ActivatorAdService
- (void)showRewardAd {
    %orig;
    NSLog(@"[Active-Tracking-Master] Ad triggered successfully with active tracking.");
}

- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    NSLog(@"[Active-Tracking-Master] Ad failed, bypassing error with active tracking to grant points.");
}
%end
