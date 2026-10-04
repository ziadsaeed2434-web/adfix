#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static id safePreloadedAd = nil;

%hook GADRewardedAd

+ (void)loadWithAdUnitID:(NSString *)adUnitID request:(id)request completionHandler:(void (^)(id ad, NSError *error))completionHandler {
    
    // إذا كان لدينا إعلان جاهز مسبقاً، نسلمه فوراً للتطبيق بدون انتظار
    if (safePreloadedAd != nil) {
        id readyAd = safePreloadedAd;
        safePreloadedAd = nil; // تفريغ المؤقت ليتم جلب إعلان جديد بعده
        
        NSLog(@"[Tweak] Serving pre-loaded ad instantly!");
        if (completionHandler) {
            completionHandler(readyAd, nil);
        }
        return;
    }
    
    // الطلب الطبيعي وعمل كاش للإعلان القادم في الخلفية
    %orig(adUnitID, request, ^(id ad, NSError *error) {
        if (ad && !error && safePreloadedAd == nil) {
            safePreloadedAd = ad; // الاحتفاظ بنسخة للإعلان القادم
            NSLog(@"[Tweak] Next ad cached successfully in background!");
        }
        if (completionHandler) {
            completionHandler(ad, error);
        }
    });
}

%end
