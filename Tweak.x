#import <Foundation/Foundation.h>

// دالة لتصفير وتحديث القيم بشكل متكرر
void resetAdPreferences() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // إعادة تعيين جميع مفاتيح الإعلانات والحظر والجلوس
    [defaults setBool:NO  forKey:@"IS_CappingManager.IS_CAPPING_ENABLED_DefaultInterstitial"];
    [defaults setBool:YES forKey:@"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial"];
    
    [defaults setBool:NO  forKey:@"BN_CappingManager.IS_CAPPING_ENABLED_DefaultBanner"];
    [defaults setBool:NO  forKey:@"BN_CappingManager.IS_PACING_ENABLED_DefaultBanner"];
    
    [defaults setBool:YES forKey:@"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"];
    
    [defaults setInteger:0 forKey:@"com.inobi_defaultStore_sessionCount"];
    
    // مفاتيح إضافية محتملة قد يستخدمها التطبيق لتخزين وقت آخر إعلان
    [defaults setObject:[NSDate distantPast] forKey:@"com.ironsource.lastInterstitialTime"];
    [defaults setObject:[NSDate distantPast] forKey:@"lastInterstitialTime"];
    [defaults setInteger:0 forKey:@"adShowCount"];
    [defaults setInteger:0 forKey:@"interstitialShowCount"];
    
    [defaults synchronize];
}

%ctor {
    @autoreleasepool {
        // تنفيذ التصفير فور فتح التطبيق
        resetAdPreferences();
        
        // استخدام المؤقت (Timer) لتكرار التصفير كل 5 ثوانٍ في الخلفية/الامام
        // هذا يضمن أنه حتى لو حاول التطبيق حظر الإعلان بعد مشاهدته، سيقوم التويك بتصفير الحظر فوراً
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSTimer scheduledTimerWithTimeInterval:5.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
                resetAdPreferences();
            }];
        });
        
        NSLog(@"[AdForceGlobal] Dynamic auto-reset timer started successfully!");
    }
}
