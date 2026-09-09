#import <Foundation/Foundation.h>

%hook NSUserDefaults

// 1. اعتراض حفظ القيم المنطقية (Boolean) وثبيت مفاتيح الـ Capping و Delivery
- (void)setBool:(BOOL)value forKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"IS_CappingManager.IS_CAPPING_ENABLED_DefaultInterstitial"]) {
        value = NO; // ممنوع تفعيل حظر البينية
    }
    else if ([defaultName isEqualToString:@"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial"]) {
        value = YES; // تثبيت تفعيل تسليم البينية
    }
    else if ([defaultName isEqualToString:@"BN_CappingManager.IS_CAPPING_ENABLED_DefaultBanner"]) {
        value = NO; // ممنوع تفعيل حظر البانر
    }
    else if ([defaultName isEqualToString:@"BN_CappingManager.IS_PACING_ENABLED_DefaultBanner"]) {
        value = NO; // ممنوع تفعيل الفاصل الزمني للبانر
    }
    else if ([defaultName isEqualToString:@"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"]) {
        value = YES; // تثبيت تفعيل تسليم إعلانات المكافأة
    }
    %orig(value, defaultName);
}

// 2. اعتراض حفظ الأرقام وثبيت عداد الجلسات عند الصفر تماماً
- (void)setInteger:(NSInteger)value forKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"com.inobi_defaultStore_sessionCount"]) {
        value = 0; // إجبار العداد أن يظل 0 ولن يرتفع أبدًا
    }
    %orig(value, defaultName);
}

- (void)setObject:(id)value forKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"com.inobi_defaultStore_sessionCount"]) {
        value = @0;
    }
    %orig(value, defaultName);
}

%end

// 3. حقن القيم الأساسية فور فتح التطبيق
%ctor {
    @autoreleasepool {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        [defaults setBool:NO  forKey:@"IS_CappingManager.IS_CAPPING_ENABLED_DefaultInterstitial"];
        [defaults setBool:YES forKey:@"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial"];
        [defaults setBool:NO  forKey:@"BN_CappingManager.IS_CAPPING_ENABLED_DefaultBanner"];
        [defaults setBool:NO  forKey:@"BN_CappingManager.IS_PACING_ENABLED_DefaultBanner"];
        [defaults setBool:YES forKey:@"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"];
        [defaults setInteger:0 forKey:@"com.inobi_defaultStore_sessionCount"];
        
        [defaults synchronize];
        NSLog(@"[AdForceLock] All keys and session counters are permanently locked!");
    }
}
