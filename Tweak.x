#import <Foundation/Foundation.h>

%ctor {
    @autoreleasepool {
        // تنفيذ التعديلات فور فتح التطبيق بالكامل في الذاكرة
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        // تعطيل حظر الإعلانات البينية وتفعيل تسليمها
        [defaults setBool:NO  forKey:@"IS_CappingManager.IS_CAPPING_ENABLED_DefaultInterstitial"];
        [defaults setBool:YES forKey:@"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial"];
        
        // تعطيل حظر والفاصل الزمني لإعلانات البانر
        [defaults setBool:NO  forKey:@"BN_CappingManager.IS_CAPPING_ENABLED_DefaultBanner"];
        [defaults setBool:NO  forKey:@"BN_CappingManager.IS_PACING_ENABLED_DefaultBanner"];
        
        // تفعيل تسليم إعلانات المكافأة
        [defaults setBool:YES forKey:@"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"];
        
        // تصفير عداد الجلسات لتتجدد المحاولة فورياً مع كل فتحة تطبيق
        [defaults setInteger:0 forKey:@"com.inobi_defaultStore_sessionCount"];
        
        // حفظ التغييرات فوراً
        [defaults synchronize];
        
        NSLog(@"[AdForceGlobal] All ad constraints cleared and forced right on app launch!");
    }
}
