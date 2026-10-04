#import <Foundation/Foundation.h>

// متغير لحفظ الإعلان المحمل مسبقاً في الخلفية
static id safePreloadedAd = nil;
static BOOL isFetchingNextAd = NO;

// دالة لجلب الإعلان التالي بهدوء بمجرد انتهاء الإعلان الحالي
static void fetchNextAdSafely(NSString *adUnitID, id originalRequest) {
    if (isFetchingNextAd || safePreloadedAd != nil) return;
    isFetchingNextAd = YES;
    
    NSLog(@"[Tweak] Pre-loading next ad safely in background...");
    
    // استدعاء التحميل الأصلي لجوجل أدموب
    [NSClassFromString(@"GADRewardedAd") loadWithAdUnitID:adUnitID request:originalRequest completionHandler:^(id ad, NSError *error) {
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

// مراقبة دالة التحميل الاصلية لحفظ الـ AdUnitID والطلب للاستخدام اللاحق
+ (void)loadWithAdUnitID:(NSString *)adUnitID request:(id)request completionHandler:(void (^)(id ad, NSError *error))completionHandler {
    
    // إذا كان لدينا إعلان جاهز مسبقاً، نقوم بتسليمه فورا للتطبيق بدون انتظار
    if (safePreloadedAd != nil) {
        id readyAd = safePreloadedAd;
        safePreloadedAd = nil; // تفريغ المتغري لكي يبدأ بتحميل الإعلان الذي يليه
        
        NSLog(@"[Tweak] Serving pre-loaded ad instantly!");
        if (completionHandler) {
            completionHandler(readyAd, nil);
        }
        
        // البدء فوراً بتحميل الإعلان الذي يليه في الخلفية
        fetchNextAdSafely(adUnitID, request);
        return;
    }
    
    // إذا لم يكن جاهزاً، نسمح للطلب الطبيعي بالمرور
    %orig(adUnitID, request, ^(id ad, NSError *error) {
        if (completionHandler) {
            completionHandler(ad, error);
        }
        // بعد انتهاء الطلب الطبيعي، نبدأ بتجهيز الإعلان التالي
        fetchNextAdSafely(adUnitID, request);
    });
}

%end
