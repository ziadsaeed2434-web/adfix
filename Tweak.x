#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static id safePreloadedAd = nil;
static BOOL isFetchingNextAd = MSNO ? NO : NO;

// دالة آمنة لجلب الإعلان عبر الـ Runtime دون الحاجة لربط الكلاس مسبقاً في ملف الـ Makefile
static void fetchNextAdSafely(NSString *adUnitID, id originalRequest) {
    if (isFetchingNextAd || safePreloadedAd != nil) return;
    isFetchingNextAd = YES;
    
    Class gadClass = objc_getClass("GADRewardedAd");
    if (!gadClass) {
        isFetchingNextAd = NO;
        return;
    }
    
    NSLog(@"[Tweak] Pre-loading next ad safely in background...");
    
    // استدعاء الميثود ديناميكياً لتجنب أي مشاكل في التجميع
    if ([gadClass respondsToSelector:@selector(loadWithAdUnitID:request:completionHandler:)]) {
        [gadClass performSelector:@selector(loadWithAdUnitID:request:completionHandler:) withObject:adUnitID withObject:originalRequest];
    }
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
        
        fetchNextAdSafely(adUnitID, request);
        return;
    }
    
    // الطلب الطبيعي
    %orig(adUnitID, request, ^(id ad, NSError *error) {
        if (completionHandler) {
            completionHandler(ad, error);
        }
        fetchNextAdSafely(adUnitID, request);
    });
}

%end
