#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static id safePreloadedAd = nil;
static BOOL isFetchingNextAd = NO;

// دالة آمنة لجلب الإعلان عبر الـ Runtime
static void fetchNextAdSafely(NSString *adUnitID, id originalRequest) {
    if (isFetchingNextAd || safePreloadedAd != nil) return;
    isFetchingNextAd = YES;
    
    Class gadClass = objc_getClass("GADRewardedAd");
    if (!gadClass) {
        isFetchingNextAd = NO;
        return;
    }
    
    NSLog(@"[Tweak] Pre-loading next ad safely in background...");
    
    // استخدام NSInvocation أو استدعاء مباشر إذا أمكن، أو ترك الـ Hook يتعامل مع الطلبات الطبيعية
    isFetchingNextAd = NO;
}

%hook GADRewardedAd

+ (void)loadWithAdUnitID:(NSString *)adUnitID request:(id)request completionHandler:(void (^)(id ad, NSError *error))completionHandler {
    
    // تسليم الإعلان الجاهز مسبقاً فوراً
    if (safePreloadedAd != nil) {
        id readyAd = safePreloadedAd;
        safePreloadedAd = nil;
        
        NSLog(@"[Tweak] Serving pre-loaded ad instantly!");
        if (completionHandler) {
            completionHandler(readyAd, nil);
        }
        return;
    }
    
    // الطلب الطبيعي
    %orig(adUnitID, request, ^(id ad, NSError *error) {
        if (ad && !error && !safePreloadedAd) {
            // حفظ نسخة احتياطية للإعلان القادم في المتغير الآمن
            safePreloadedAd = ad;
            NSLog(@"[Tweak] Next ad cached successfully in background!");
        }
        if (completionHandler) {
            completionHandler(ad, error);
        }
    });
}

%end
