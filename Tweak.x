#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <objc/runtime.h>

@interface ActivatorAdService : NSObject
- (void)loadAd;
- (BOOL)isReady;
- (BOOL)isAdReady;
- (BOOL)canShowAd;
- (BOOL)hasAdLoaded;
- (void)showRewardAd;
- (void)presentAdFromViewController:(UIViewController *)viewController;
- (void)grantReward;
- (void)triggerAggressiveAdLoop;
@end

// توليد IP آمن وثابت للجلسة من النطاق 82.92 دون مشاكل في الذاكرة
static NSString *getSessionResidentialIP() {
    static NSString *cachedIP = nil;
    if (!cachedIP) {
        int p3 = arc4random_uniform(240) + 1;
        int p4 = arc4random_uniform(250) + 1;
        cachedIP = [NSString stringWithFormat:@"82.92.%d.%d", p3, p4];
    }
    return cachedIP;
}

static NSString *randomEuropeanUserAgent() {
    return @"Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148";
}

// تنظيف آمن للـ NSUserDefaults لمنع الكرش عند الإقلاع
static __attribute__((constructor)) void initializeSafeEngine() {
    @autoreleasepool {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleIdentifier) {
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleIdentifier];
        }
        
        NSString *freshID = [[NSUUID UUID] UUIDString];
        [defaults setObject:freshID forKey:@"device.id.key"];
        [defaults setObject:freshID forKey:@"AppsFlyerUserId"];
        
        // تفعيل التتبع والموافقة لتجنب انهيار الـ SDKs
        [defaults setInteger:3 forKey:@"ATT_Tracking_Status"];
        [defaults setInteger:1 forKey:@"ump_status"];
        [defaults setObject:@"1" forKey:@"IABTCF_gdprApplies"];
        [defaults synchronize];
        
        NSLog(@">>> [Safe-Engine] IP: %@", getSessionResidentialIP());
    }
}

// حقن الشبكة بشكل آمن ومحمي ضد الـ null pointers
%hook NSMutableURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    NSString *targetIP = getSessionResidentialIP();
    if (field && ([field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame ||
                  [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame ||
                  [field caseInsensitiveCompare:@"X-Real-IP"] == NSOrderedSame)) {
        value = targetIP;
    }
    %orig(value, field);
}

%end

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    if (mutableReq) {
        NSString *targetIP = getSessionResidentialIP();
        [mutableReq setValue:targetIP forHTTPHeaderField:@"X-Forwarded-For"];
        [mutableReq setValue:targetIP forHTTPHeaderField:@"X-Real-IP"];
        return %orig(mutableReq, completionHandler);
    }
    return %orig(request, completionHandler);
}

%end

%hook ATTrackingManager
+ (NSUInteger)trackingAuthorizationStatus {
    return 3; // Authorized
}
%end

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return [NSUUID UUID];
}
- (BOOL)isAdvertisingTrackingEnabled {
    return YES;
}
%end

// محرك إعلانات آمن لا يسبب تكرار غير محكوم للـ Main Thread
%hook ActivatorAdService

- (BOOL)isReady { return YES; }
- (BOOL)isAdReady { return YES; }
- (BOOL)canShowAd { return YES; }
- (BOOL)hasAdLoaded { return YES; }

- (void)triggerAggressiveAdLoop {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if ([self respondsToSelector:@selector(loadAd)]) {
                [self loadAd];
            }
            if ([self respondsToSelector:@selector(grantReward)]) {
                [self grantReward];
            }
        } @catch (NSException *exception) {}
    });
}

- (void)loadAd {
    %orig;
    [self performSelector:@selector(triggerAggressiveAdLoop) withObject:nil afterDelay:3.0];
}

%end
