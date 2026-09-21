#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <objc/runtime.h>

// تعريف واجهات Google Mobile Ads SDK المطلوبة للحقن
@interface GADMobileAds : NSObject
+ (instancetype)sharedInstance;
- (void)startWithCompletionHandler:(void(^)(id))completionHandler;
@end

@interface GADRewardedAd : NSObject
+ (void)loadWithAdUnitID:(NSString *)adUnitID
                 request:(id)request
       completionHandler:(void(^)(GADRewardedAd *rewardedAd, NSError *error))completionHandler;
- (void)presentFromRootViewController:(UIViewController *)rootViewController
             userDidEarnRewardHandler:(void(^)(void))rewardHandler;
@end

// متغيرات عامة لتخزين الإعلان الجاهز
static GADRewardedAd *sharedRewardedAd = nil;
static BOOL isLoadingAd = NO;
static NSString *const kMyAdUnitID = @"ca-app-pub-3940256099942544/1712485313";

// دالة لتحميل إعلان AdMob حقيقي في الخلفية
static void preloadGoogleRewardedAd() {
    if (sharedRewardedAd || isLoadingAd) return;
    isLoadingAd = YES;
    
    Class gadClass = NSClassFromString(@"GADRewardedAd");
    Class reqClass = NSClassFromString(@"GADRequest");
    
    if (gadClass && reqClass) {
        id request = [[reqClass alloc] init];
        [gadClass loadWithAdUnitID:kMyAdUnitID request:request completionHandler:^(GADRewardedAd *rewardedAd, NSError *error) {
            isLoadingAd = NO;
            if (!error && rewardedAd) {
                sharedRewardedAd = rewardedAd;
                NSLog(@">>> [AdMob-Injection] Rewarded Ad loaded successfully!");
            } else {
                NSLog(@">>> [AdMob-Injection] Failed to load AdMob ad: %@", error.localizedDescription);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    preloadGoogleRewardedAd();
                });
            }
        }];
    }
}

// 1. حقن وتفعيل AdMob عند الإقلاع وتثبيت البيئة الألمانية
static __attribute__((constructor)) void setupAdMobAndGermanEnvironment() {
    @autoreleasepool {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:@[@"de-DE", @"en-US"] forKey:@"AppleLanguages"];
        [defaults setObject:@"DE" forKey:@"AppleLocale"];
        [defaults setObject:@"Europe/Berlin" forKey:@"NSReuseTimeZone"];
        [defaults setInteger:3 forKey:@"ATT_Tracking_Status"];
        [defaults setInteger:1 forKey:@"IABTCF_gdprApplies"];
        [defaults synchronize];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            Class mobileAdsClass = NSClassFromString(@"GADMobileAds");
            if (mobileAdsClass && [mobileAdsClass respondsToSelector:@selector(sharedInstance)]) {
                id adsInstance = [mobileAdsClass sharedInstance];
                if ([adsInstance respondsToSelector:@selector(startWithCompletionHandler:)]) {
                    [adsInstance startWithCompletionHandler:^(id status) {
                        NSLog(@">>> [AdMob-Injection] GADMobileAds started successfully.");
                        preloadGoogleRewardedAd();
                    }];
                }
            }
        });
    }
}

// 2. تجاوز قيود النظام والتتبع
%hook ATTrackingManager
+ (NSUInteger)trackingAuthorizationStatus { return 3; }
%end

%hook UIDevice
- (NSUUID *)identifierForVendor { return [NSUUID UUID]; }
%end

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier { return [NSUUID UUID]; }
- (BOOL)isAdvertisingTrackingEnabled { return YES; }
%end

// تعريف الكلاس لتجنب خطأ Forward Declaration
@interface ActivatorAdService : NSObject
- (void)loadAd;
- (BOOL)isReady;
- (BOOL)isAdReady;
- (BOOL)canShowAd;
- (BOOL)hasAdLoaded;
- (void)showRewardAd;
- (void)presentAdFromViewController:(UIViewController *)viewController;
@end

// 3. حقن زر التطبيق وربطه مباشرة بإعلان AdMob الحقيقي
%hook ActivatorAdService

- (BOOL)isReady { return YES; }
- (BOOL)isAdReady { return YES; }
- (BOOL)canShowAd { return YES; }
- (BOOL)hasAdLoaded { return (sharedRewardedAd != nil); }

- (void)loadAd {
    %orig;
    preloadGoogleRewardedAd();
}

- (void)showRewardAd {
    @try {
        UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (rootVC.presentedViewController) {
            rootVC = rootVC.presentedViewController;
        }
        
        if (sharedRewardedAd && rootVC) {
            NSLog(@">>> [AdMob-Injection] Presenting Google AdMob Rewarded Ad!");
            [sharedRewardedAd presentFromRootViewController:rootVC userDidEarnRewardHandler:^{
                NSLog(@">>> [AdMob-Injection] User earned reward!");
            }];
            sharedRewardedAd = nil;
            preloadGoogleRewardedAd();
        } else {
            NSLog(@">>> [AdMob-Injection] Ad not ready yet, forcing reload...");
            preloadGoogleRewardedAd();
            %orig;
        }
    } @catch (NSException *e) {
        NSLog(@">>> [AdMob-Injection] Exception in showRewardAd: %@", e.reason);
        %orig;
    }
}

- (void)presentAdFromViewController:(UIViewController *)viewController {
    [self showRewardAd];
}

%end
