#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define MAX_PRELOADED_ADS_PER_ID 20

static NSMutableDictionary *globalAdPool = nil;

__attribute__((constructor)) static void initGlobalPool() {
    globalAdPool = [[NSMutableDictionary alloc] init];
}

%hook GADRewardedAd

// إجبار النظام على اعتبار أن الإعلان جاهز دائماً لتظهر لك الحالة فوراً بدون "Loading ad..."
- (BOOL)isReady {
    return YES;
}

+ (BOOL)isReady {
    return YES;
}

// اعتراض عملية التحميل لتزويد التطبيق بالإعلان المخزناً مسبقاً في أجزاء من الثانية
+ (void)loadWithAdUnitID:(NSString *)adUnitID request:(id)request completionHandler:(void (^)(id, NSError *))completionHandler {
    
    void (^localHandler)(id, NSError *) = [completionHandler copy];
    
    if (adUnitID) {
        NSMutableArray *pool = globalAdPool[adUnitID];
        if (!pool) {
            pool = [[NSMutableArray alloc] init];
            globalAdPool[adUnitID] = pool;
        }
        
        // إذا كان هناك إعلان جاهز في الذاكرة، نسلمه فوراً في كل ضغطة
        if (pool.count > 0) {
            id readyAd = [pool firstObject];
            [pool removeObjectAtIndex:0];
            
            if (localHandler) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    localHandler(readyAd, nil);
                });
            }
            
            // تعبئة المخزون في الخلفية بهدوء
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                %orig(adUnitID, request, ^(id ad, NSError *error) {
                    if (ad && !error) {
                        [pool addObject:ad];
                    }
                });
            });
            return;
        }
    }
    
    // التحميل العادي وتخزينه للاستخدامات التالية
    %orig(adUnitID, request, ^(id ad, NSError *error) {
        if (ad && !error && adUnitID) {
            NSMutableArray *pool = globalAdPool[adUnitID];
            if (!pool) {
                pool = [[NSMutableArray alloc] init];
                globalAdPool[adUnitID] = pool;
            }
            [pool addObject:ad];
        }
        if (localHandler) {
            localHandler(ad, error);
        }
    });
}

%end
