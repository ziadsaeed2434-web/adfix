#import <Foundation/Foundation.h>

// دالة موحدة لتطبيق القيم المطلوبة على أي كائن NSUserDefaults
static void overrideDefaults(NSUserDefaults *defaults) {
    if (!defaults) return;
    
    [defaults setBool:NO  forKey:@"IS_CappingManager.IS_CAPPING_ENABLED_DefaultInterstitial"];
    [defaults setBool:YES forKey:@"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial"];
    [defaults setBool:NO  forKey:@"BN_CappingManager.IS_CAPPING_ENABLED_DefaultBanner"];
    [defaults setBool:NO  forKey:@"BN_CappingManager.IS_PACING_ENABLED_DefaultBanner"];
    [defaults setBool:YES forKey:@"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"];
    [defaults setInteger:0 forKey:@"com.inobi_defaultStore_sessionCount"];
}

%hook NSUserDefaults

// اعتراض دالة حفظ القيم (setBool) لمنع التطبيق من عكس القيم المطلوبة
- (void)setBool:(BOOL)value forKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"IS_CappingManager.IS_CAPPING_ENABLED_DefaultInterstitial"]) {
        value = NO;
    } else if ([defaultName isEqualToString:@"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial"]) {
        value = YES;
    } else if ([defaultName isEqualToString:@"BN_CappingManager.IS_CAPPING_ENABLED_DefaultBanner"]) {
        value = NO;
    } else if ([defaultName isEqualToString:@"BN_CappingManager.IS_PACING_ENABLED_DefaultBanner"]) {
        value = NO;
    } else if ([defaultName isEqualToString:@"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"]) {
        value = YES;
    }
    %orig(value, defaultName);
}

// اعتراض دالة حفظ الأعداد الصحيحة (setInteger) لتصفير عداد الجلسات دوماً
- (void)setInteger:(NSInteger)value forKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"com.inobi_defaultStore_sessionCount"]) {
        value = 0;
    }
    %orig(value, defaultName);
}

// اعتراض دالة جلب القيم (boolForKey) لضمان إرجاع القيمة المطلوبة حتى لو حاول التطبيق قراءتها
- (BOOL)boolForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"IS_CappingManager.IS_CAPPING_ENABLED_DefaultInterstitial"]) return NO;
    if ([defaultName isEqualToString:@"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial"]) return YES;
    if ([defaultName isEqualToString:@"BN_CappingManager.IS_CAPPING_ENABLED_DefaultBanner"]) return NO;
    if ([defaultName isEqualToString:@"BN_CappingManager.IS_PACING_ENABLED_DefaultBanner"]) return NO;
    if ([defaultName isEqualToString:@"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"]) return YES;
    return %orig;
}

// اعتراض دالة جلب الأعداد (integerForKey) لضمان إرجاع الصفر لعداد الجلسات
- (NSInteger)integerForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"com.inobi_defaultStore_sessionCount"]) return 0;
    return %orig;
}

%end

%ctor {
    @autoreleasepool {
        // التطبيق الفوري عند التشغيل
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        overrideDefaults(defaults);
        [defaults synchronize];
        
        NSLog(@"[AdForceGlobal] Hooked NSUserDefaults successfully and enforced ad constraints persistently!");
    }
}
