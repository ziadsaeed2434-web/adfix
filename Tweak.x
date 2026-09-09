#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 1. استهداف كلاس المتجر ومراقبة تحميل الشاشة لإجبار إعادة التهيئة
%hook StoreController
- (void)viewDidLoad {
    %orig;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setInteger:0 forKey:@"com.inobi_defaultStore_sessionCount"];
    [defaults synchronize];
    NSLog(@"[AdForceCombined] StoreController loaded, session count forced to 0.");
}
%end

// 2. استهداف كلاس الـ SDK الخاص بالإعلانات المباشر
%hook InMobiInterstitial
- (BOOL)isReady {
    return YES; // إجبار النظام على اعتبار الإعلان جاهزاً دائماً
}
- (void)showFromViewController:(UIViewController *)viewController {
    %orig;
    NSLog(@"[AdForceCombined] Interstitial ad forced to show!");
}
%end

// 3. قفل وتثبيت القيم المنطقية وعدادات الجلسات والطوابع الزمنية في NSUserDefaults
%hook NSUserDefaults

- (void)setBool:(BOOL)value forKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"IS_CappingManager.IS_CAPPING_ENABLED_DefaultInterstitial"]) {
        value = NO;
    }
    else if ([defaultName isEqualToString:@"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial"]) {
        value = YES;
    }
    else if ([defaultName isEqualToString:@"BN_CappingManager.IS_CAPPING_ENABLED_DefaultBanner"]) {
        value = NO;
    }
    else if ([defaultName isEqualToString:@"BN_CappingManager.IS_PACING_ENABLED_DefaultBanner"]) {
        value = NO;
    }
    else if ([defaultName isEqualToString:@"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"]) {
        value = YES;
    }
    %orig(value, defaultName);
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"com.inobi_defaultStore_sessionCount"]) {
        value = 0; // قفل العداد عند الصفر دائماً
    }
    %orig(value, defaultName);
}

- (void)setDouble:(double)value forKey:(NSString *)defaultName {
    if ([defaultName containsString:@"Time"] || [defaultName containsString:@"Last"] || [defaultName containsString:@"pacing"]) {
        value = 0;
    }
    %orig(value, defaultName);
}

- (void)setObject:(id)value forKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"com.inobi_defaultStore_sessionCount"]) {
        value = @0;
    }
    else if ([defaultName containsString:@"Time"] || [defaultName containsString:@"date"] || [defaultName containsString:@"timestamp"]) {
        value = @0;
    }
    %orig(value, defaultName);
}

%end

// 4. التنظيف الشامل وضبط القيم فور إطلاق التطبيق
%ctor {
    @autoreleasepool {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        [defaults setBool:NO  forKey:@"IS_CappingManager.IS_CAPPING_ENABLED_DefaultInterstitial"];
        [defaults setBool:YES forKey:@"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial"];
        [defaults setBool:NO  forKey:@"BN_CappingManager.IS_CAPPING_ENABLED_DefaultBanner"];
        [defaults setBool:NO  forKey:@"BN_CappingManager.IS_PACING_ENABLED_DefaultBanner"];
        [defaults setBool:YES forKey:@"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"];
        [defaults setInteger:0 forKey:@"com.inobi_defaultStore_sessionCount"];
        
        // مسح الطوابع الزمنية القديمة
        NSDictionary *dict = [defaults dictionaryRepresentation];
        for (NSString *key in dict.allKeys) {
            if ([key containsString:@"Time"] || [key containsString:@"lastShown"] || [key containsString:@"Timestamp"]) {
                [defaults removeObjectForKey:key];
            }
        }
        
        [defaults synchronize];
        NSLog(@"[AdForceCombined] All local and runtime hooks applied successfully!");
    }
}
