#import <Foundation/Foundation.h>

// تعريف كلاس GADRewardedAd والميثود صراحةً لكي يتعرف عليه المترجم
@interface GADRewardedAd : NSObject
+ (void)loadWithAdUnitID:(NSString *)adUnitID request:(id)request completionHandler:(void (^)(GADRewardedAd *ad, NSError *error))completionHandler;
@end

// متغير لحفظ الإعلان المحمل مسبقاً في الخلفية
static id safePreloadedAd = nil;
static BOOL isFetchingNextAd = NO;

// دالة لجلب الإعلان التالي بهدوء بمجرد انتهاء الإعلان الحالي
static void fetchNextAdSafely(NSString *adUnitID, id originalRequest) {
    if (isFetchingNextAd || safePreloadedAd != nil) return;
    isFetchingNextAd = YES;
    
    NSLog(@"[Tweak] Pre-load next ad safely in background...");
    
    // استخدام الكلاس المعرف مباشرة بدلاً من NSClassFromString لتجنب خطأ الـ Compilation
    [GADRewardedAd loadWithAdUnitID:adUnitID request:originalRequest completionHandler:^(GADRewardedAd *ad, NSError *error) {
        isFetchingNextAd = NO;
        if (ad && !error) {
            safePreloadedAd = ad;
            NSLog(@"[Tweak] Next ad successfully pre-loaded and ready!");
        } else {
            NSLog(@"[Tweak] Failed to pre-load next ad: %@", error.localizedDescription);
        }
    }];
}

%hook GADRewardedAd

+ (void)loadWithAdUnitID:(NSString *)adUnitID request:(id)request completionHandler:(void (^)(GADRewardedAd *ad, NSError *error))completionHandler {
    
    // إذا كان لدينا إعلان جاهز مسبقاً، نسلمه فوراً للتطبيق بدون انتظار
    if (safePreloadedAd != nil) {
        id readyAd = safePreloadedAd;
        safePreloadedAd = nil;
        
        NSLog(@"[Tweak] Serving pre-loaded ad instantly!");
        if (completionHandler) {
            completionHandler(readyAd, nil);
        }
        
        // البدء فوراً بتحميل الإعلان الذي يليه في الخلفية
        fetchNextAdSafely(adUnitID, request);
        return;
    }
    
    // إذا لم يكن جاهزاً، نسمح للطلب الطبيعي بالمرور
    %orig(adUnitID, request, ^(GADRewardedAd *ad, NSError *error) {
        if (completionHandler) {
            completionHandler(ad, error);
        }
        // بعد انتهاء الطلب الطبيعي، نبدأ بتجهيز الإعلان التالي
        fetchNextAdSafely(adUnitID, request);
    });
}

%end
