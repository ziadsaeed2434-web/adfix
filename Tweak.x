#import <Foundation/Foundation.h>

%ctor {
    @autoreleasepool {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        // 1. مفاتيح حصص الإعلانات (Capping) الكاملة كما ظهرت في صور الـ NSUserDefaults
        [defaults setInteger:0 forKey:@"RV_CappingManager.IS_CAPPED_ENABLED_DefaultRewardedVideo"];
        [defaults setInteger:0 forKey:@"IS_CappingManager.IS_DELETABLE_ENABLED_DefaultInterstitial"];
        [defaults setInteger:0 forKey:@"BN_CappingManager.IS_DELETABLE_DELAY_ENABLED_DefaultBanner"];
        
        // 2. حذف معرفات الجلسة والجهاز المخزنة محلياً
        [defaults removeObjectForKey:@"uuidStringFromStore"];
        [defaults removeObjectForKey:@"User.id"];
        [defaults removeObjectForKey:@"unityads-idfi"];
        
        // 3. مزامنة التغييرات فوراً لتطبيقها في التطبيق
        [defaults synchronize];
        
        NSLog(@"[Tweak] Fully cleaned NSUserDefaults and reset ad caps successfully!");
    }
}
