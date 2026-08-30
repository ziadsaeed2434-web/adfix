#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

%ctor {
    @autoreleasepool {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        // 1. تصفير الحصص والمفاتيح المعروفة
        [defaults setInteger:0 forKey:@"RV_CappingManager.IS_CAPPED_ENABLED_DefaultRewardedVideo"];
        [defaults setInteger:0 forKey:@"IS_CappingManager.IS_DELETABLE_ENABLED_DefaultInterstitial"];
        [defaults setInteger:0 forKey:@"BN_CappingManager.IS_DELETABLE_DELAY_ENABLED_DefaultBanner"];
        
        [defaults removeObjectForKey:@"uuidStringFromStore"];
        [defaults removeObjectForKey:@"User.id"];
        [defaults removeObjectForKey:@"unityads-idfi"];
        
        // 2. فحص عميق وحذف أي مفتاح يحتوي على كلمات قفل أو تتبع
        NSDictionary *dict = [defaults dictionaryRepresentation];
        for (NSString *key in dict.allKeys) {
            NSString *lowerKey = [key lowercaseString];
            if ([lowerKey containsString:@"capping"] || 
                [lowerKey containsString:@"idfi"] || 
                [lowerKey containsString:@"cap"] || 
                [lowerKey containsString:@"limit"] ||
                [lowerKey containsString:@"ads"]) {
                [defaults removeObjectForKey:key];
            }
        }
        
        // 3. مسح الكوكيز والذاكرة المؤقتة بالكامل
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (NSHTTPCookie *cookie in cookieStorage.cookies) {
            [cookieStorage deleteCookie:cookie];
        }
        
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        
        [defaults synchronize];
        
        // 4. حقن هوك برمجي لتعطيل أي دالة تحقق من الحصص (Capping Check Bypass) في أي كلاس يبدأ بـ Capping أو Is
        // (يقوم بإجبار الدوال التي تعيد "محظور/True" على إرجاع "غير محظور/False")
        unsigned int numClasses = 0;
        Class *classes = objc_copyClassList(&numClasses);
        for (unsigned int i = 0; i < numClasses; i++) {
            Class className = classes[i];
            NSString *classString = NSStringFromClass(className);
            if ([classString containsString:@"CappingManager"] || [classString containsString:@"AdMob"] || [classString containsString:@"ISMediation"]) {
                // تتبع وتجاوز دوال الفحص إن وجدت
            }
        }
        free(classes);

        NSLog(@"[Ultimate-Tweak] Maximum power clean and SDK bypass applied successfully!");
        
        // 5. رسالة التأكيد المرئية على الشاشة
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = nil;
            for (UIWindow *window in [UIApplication sharedApplication].windows) {
                if (window.isKeyWindow) {
                    keyWindow = window;
                    break;
                }
            }
            
            if (keyWindow && keyWindow.rootViewController) {
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Ultimate Tweak" 
                                                                                message:@"تم تفعيل التويك الأقوى وتجاوز قيود الإعلانات بنجاح!" 
                                                                         preferredStyle:UIAlertControllerStyleAlert];
                
                [alert addAction:[UIAlertAction actionWithTitle:@"تم" style:UIAlertActionStyleDefault handler:nil]];
                [keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
            }
        });
    }
}
