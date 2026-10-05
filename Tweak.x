#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// تخزين مؤقت للإعلانات الجاهزة لكل AdUnitID لضمان التكرار في أي وقت
static NSMutableDictionary *globalAdCache = nil;
static NSMutableDictionary *activeLoadersMap = nil;

__attribute__((constructor)) static void initializeTweakPools() {
    globalAdCache = [[NSMutableDictionary alloc] init];
    activeLoadersMap = [[NSMutableDictionary alloc] init];
}

%hook GADAdLoader

- (void)loadRequest:(id)request {
    NSString *adUnitID = [self valueForKey:@"adUnitID"];
    if (adUnitID) {
        activeLoadersMap[adUnitID] = self;
        NSLog(@"[Tweak Pro] GADAdLoader registered for ID: %@", adUnitID);
    }
    %orig;
}

- (void)receivePublicAd:(id)ad {
    NSString *adUnitID = [self valueForKey:@"adUnitID"];
    if (ad && adUnitID) {
        globalAdCache[adUnitID] = ad;
        NSLog(@"[Tweak Pro] Ad successfully cached via GADAdLoader for ID: %@", adUnitID);
    }
    %orig;
}

- (void)failedToReceiveAdWithError:(NSError *)error {
    NSString *adUnitID = [self valueForKey:@"adUnitID"];
    NSLog(@"[Tweak Pro] GADAdLoader failed for ID: %@ - Error: %@", adUnitID, error.localizedDescription);
    %orig;
}

%end

%hook GADRewardedAd

+ (void)loadWithAdUnitID:(NSString *)adUnitID request:(id)request completionHandler:(void (^)(id ad, NSError *error))completionHandler {
    
    // التحقق الفوري من وجود إعلان مخزن مسبقاً وتسليمه بدون تأخير
    if (adUnitID && globalAdCache[adUnitID]) {
        id cachedAd = globalAdCache[adUnitID];
        [globalAdCache removeObjectForKey:adUnitID];
        
        NSLog(@"[Tweak Pro] Serving cached rewarded ad instantly for ID: %@", adUnitID);
        if (completionHandler) {
            completionHandler(cachedAd, nil);
        }
        
        // إعادة تعبئة الكاش في الخلفية تلقائياً ليكون الإعلان التالي جاهزاً دائماً في أي وقت
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            id loader = activeLoadersMap[adUnitID];
            if (loader && [loader respondsToSelector:@selector(loadRequest:)]) {
                [loader loadRequest:request];
                NSLog(@"[Tweak Pro] Background re-fetch triggered successfully.");
            } else {
                %orig(adUnitID, request, ^(id newAd, NSError *newError) {
                    if (newAd && !newError) {
                        globalAdCache[adUnitID] = newAd;
                    }
                });
            }
        });
        return;
    }
    
    // المسار الافتراضي مع حفظ النتيجة تلقائياً للاستخدامات القادمة
    %orig(adUnitID, request, ^(id ad, NSError *error) {
        if (ad && !error && adUnitID) {
            globalAdCache[adUnitID] = ad;
            NSLog(@"[Tweak Pro] Initial rewarded ad cached for ID: %@", adUnitID);
        }
        if (completionHandler) {
            completionHandler(ad, error);
        }
    });
}

%end
