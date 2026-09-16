#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <objc/runtime.h>
#import <Security/Security.h>
#import <SystemConfiguration/SystemConfiguration.h>
#include <arpa/inet.h>
#include <netdb.h>

// ============================================================================
// 1. الواجهات
// ============================================================================
@interface ActivatorAdService : NSObject
- (void)loadAd;
- (void)fetchAdContent;
- (void)requestRewardBasedVideo;
- (BOOL)isReady;
- (BOOL)isAdReady;
- (BOOL)canShowAd;
- (BOOL)hasAdLoaded;
- (BOOL)isAdAvailable;
- (void)showRewardAd;
- (void)presentAdFromViewController:(UIViewController *)viewController;
- (void)forceReloadAdsDirectly;
@end

@interface ExtendedPolymorphicEngine : NSObject
+ (instancetype)sharedEngine;
@property (nonatomic, strong) NSString *currentDynamicIP;
@property (nonatomic, strong) NSString *currentDynamicUUID;
@property (nonatomic, strong) NSDate *fakeLastLaunchDate;
@property (nonatomic, assign) BOOL isEngineActive;
@property (nonatomic, assign) NSInteger executionCounter;
@property (nonatomic, strong) dispatch_source_t infiniteFetchTimer;
- (void)bootstrapPolymorphicCore;
- (void)rotateNetworkParametersAndIdentity;
- (void)purgeAllSystemCachesCompletely;
- (void)logDiagnosticInfo:(NSString *)infoMessage;
- (void)startInfiniteFetchLoopForTarget:(id)target;
- (void)stopInfiniteFetchLoop;
@end

// ============================================================================
// 2. تنفيذ المحرك
// ============================================================================
@implementation ExtendedPolymorphicEngine

+ (instancetype)sharedEngine {
    static ExtendedPolymorphicEngine *sharedEngineInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedEngineInstance = [[ExtendedPolymorphicEngine alloc] init];
    });
    return sharedEngineInstance;
}

- (void)bootstrapPolymorphicCore {
    self.isEngineActive = YES;
    self.executionCounter = 0;
    [self logDiagnosticInfo:@"ExtendedPolymorphicEngine core initialized with infinite 0.2s ad-fetch loop."];
    [self rotateNetworkParametersAndIdentity];
}

- (void)rotateNetworkParametersAndIdentity {
    self.executionCounter++;

    NSArray *primaryPools = @[
        @"185.159.157.", @"194.26.29.", @"213.127.18.",
        @"178.162.209.", @"82.165.188.", @"195.154.120.",
        @"51.15.142.", @"91.200.12.", @"46.101.98.", @"37.120.193."
    ];
    NSString *selectedPrefix = primaryPools[arc4random_uniform((uint32_t)[primaryPools count])];
    int randomSuffix = arc4random_uniform(240) + 10;
    self.currentDynamicIP = [NSString stringWithFormat:@"%@%d", selectedPrefix, randomSuffix];
    self.currentDynamicUUID = [[NSUUID UUID] UUIDString];

    int randomDaysAgo = arc4random_uniform(76) + 15;
    NSTimeInterval randomSecondsAgo = -((double)randomDaysAgo * 24 * 60 * 60);
    self.fakeLastLaunchDate = [NSDate dateWithTimeIntervalSinceNow:randomSecondsAgo];

    [self purgeAllSystemCachesCompletely];
    [self logDiagnosticInfo:[NSString stringWithFormat:@"Session Launch #%ld -> IP: %@, UUID: %@, Absence Days: %d days ago",
                             (long)self.executionCounter, self.currentDynamicIP, self.currentDynamicUUID, randomDaysAgo]];
}

- (void)purgeAllSystemCachesCompletely {
    @autoreleasepool {
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
            [cookieStorage deleteCookie:cookie];
        }
    }
}

- (void)logDiagnosticInfo:(NSString *)infoMessage {
    NSLog(@">>> [ExtendedPolymorphicEngine] %@", infoMessage);
}

- (void)startInfiniteFetchLoopForTarget:(id)target {
    @synchronized (self) {
        if (self.infiniteFetchTimer) return; // الحلقة تعمل مسبقاً

        self.infiniteFetchTimer = dispatch_source_create(
            DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
            dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0));

        uint64_t interval = (uint64_t)(0.2 * NSEC_PER_SEC);
        uint64_t leeway   = (uint64_t)(0.02 * NSEC_PER_SEC);

        dispatch_source_set_timer(self.infiniteFetchTimer,
                                  dispatch_time(DISPATCH_TIME_NOW, 0),
                                  interval, leeway);

        // بديل __weak في MRR: التقاط قوي عادي
        id capturedTarget = target;

        dispatch_source_set_event_handler(self.infiniteFetchTimer, ^{
            @autoreleasepool {
                @try {
                    if (!capturedTarget) return;
                    if ([capturedTarget respondsToSelector:@selector(fetchAdContent)]) {
                        [capturedTarget fetchAdContent];
                    }
                    if ([capturedTarget respondsToSelector:@selector(requestRewardBasedVideo)]) {
                        [capturedTarget requestRewardBasedVideo];
                    }
                } @catch (NSException *e) {
                    NSLog(@">>> [InfiniteLoop] Exception: %@", e.reason);
                }
            }
        });

        dispatch_resume(self.infiniteFetchTimer);
        NSLog(@">>> [InfiniteLoop] Started infinite 0.2s ad-fetch loop.");
    }
}

- (void)stopInfiniteFetchLoop {
    @synchronized (self) {
        if (self.infiniteFetchTimer) {
            dispatch_source_cancel(self.infiniteFetchTimer);
            self.infiniteFetchTimer = nil;
            NSLog(@">>> [InfiniteLoop] Stopped.");
        }
    }
}

@end

// ============================================================================
// 3. حماية الـ Keychain
// ============================================================================
@interface AdvancedKeychainGuard : NSObject
+ (void)executeSecureKeychainSanitization;
@end

@implementation AdvancedKeychainGuard
+ (void)executeSecureKeychainSanitization {
    @autoreleasepool {
        NSArray *secClasses = @[
            (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecClassInternetPassword,
            (__bridge id)kSecClassCertificate,
            (__bridge id)kSecClassKey,
            (__bridge id)kSecClassIdentity
        ];

        for (id secClass in secClasses) {
            NSDictionary *spec = @{(__bridge id)kSecClass: secClass};
            CFArrayRef result = NULL;
            if (SecItemCopyMatching((__bridge CFDictionaryRef)spec, (CFTypeRef *)&result) == errSecSuccess) {
                NSArray *items = (__bridge NSArray *)result;
                for (NSDictionary *item in items) {
                    NSString *account = item[(__bridge id)kSecAttrAccount];
                    if (account && [account rangeOfString:@"token" options:NSCaseInsensitiveSearch].location == NSNotFound) {
                        NSMutableDictionary *delQuery = [NSMutableDictionary dictionaryWithDictionary:item];
                        delQuery[(__bridge id)kSecClass] = secClass;
                        SecItemDelete((__bridge CFDictionaryRef)delQuery);
                    }
                }
                if (result) { CFRelease(result); }
            }
        }
    }
}
@end

// ============================================================================
// 4. المُهتّئ التلقائي
// ============================================================================
static __attribute__((constructor)) void initializeExtendedArchitectureMaster() {
    @autoreleasepool {
        [[ExtendedPolymorphicEngine sharedEngine] bootstrapPolymorphicCore];
        [AdvancedKeychainGuard executeSecureKeychainSanitization];

        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleID) {
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleID];
        }

        NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
        NSString *activeUUID = [ExtendedPolymorphicEngine sharedEngine].currentDynamicUUID;
        NSDate *oldLaunchDate = [ExtendedPolymorphicEngine sharedEngine].fakeLastLaunchDate;

        [standardDefaults setObject:activeUUID forKey:@"device.id.key"];
        [standardDefaults setObject:activeUUID forKey:@"com.google.sso.GeneratedDeviceIdentifier"];
        [standardDefaults setObject:activeUUID forKey:@"AppsFlyerUserId"];
        [standardDefaults setObject:activeUUID forKey:@"FirebaseInstallationIdentifier"];

        [standardDefaults setObject:oldLaunchDate forKey:@"last_launch_date"];
        [standardDefaults setObject:oldLaunchDate forKey:@"com.app.lastOpenDate"];
        [standardDefaults setObject:oldLaunchDate forKey:@"lastActiveTime"];
        [standardDefaults setObject:oldLaunchDate forKey:@"CFBundleDateLastOpened"];
        [standardDefaults setDouble:[oldLaunchDate timeIntervalSince1970] forKey:@"last_session_timestamp"];

        [standardDefaults setInteger:3 forKey:@"ATT_Tracking_Status"];
        [standardDefaults setInteger:1 forKey:@"ump_status"];
        [standardDefaults setInteger:1 forKey:@"IABTCF_gdprApplies"];
        [standardDefaults setObject:@"CP111111" forKey:@"IABTCF_TCString"];
        [standardDefaults setInteger:1 forKey:@"IABTCF_PurposeConsents"];
        [standardDefaults setInteger:1 forKey:@"IABTCF_VendorConsents"];

        [standardDefaults synchronize];
    }
}

// ============================================================================
// 5. خطافات النظام
// ============================================================================

%hook ATTrackingManager
+ (NSUInteger)trackingAuthorizationStatus { return 3; }
%end

%hook UIDevice
- (NSUUID *)identifierForVendor {
    return [[NSUUID alloc] initWithUUIDString:[ExtendedPolymorphicEngine sharedEngine].currentDynamicUUID] ?: [NSUUID UUID];
}
%end

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return [[NSUUID alloc] initWithUUIDString:[ExtendedPolymorphicEngine sharedEngine].currentDynamicUUID] ?: [NSUUID UUID];
}
- (BOOL)isAdvertisingTrackingEnabled { return YES; }
%end

%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field isEqualToString:@"X-Forwarded-For"] ||
        [field isEqualToString:@"Client-IP"] ||
        [field isEqualToString:@"True-Client-IP"] ||
        [field isEqualToString:@"X-Real-IP"] ||
        [field isEqualToString:@"CF-Connecting-IP"]) {
        value = [ExtendedPolymorphicEngine sharedEngine].currentDynamicIP;
    }
    %orig(value, field);
}
%end

// ============================================================================
// 6. خطاف مدير الإعلانات
// ============================================================================

%hook ActivatorAdService

- (BOOL)isReady { return YES; }
- (BOOL)isAdReady { return YES; }
- (BOOL)canShowAd { return YES; }
- (BOOL)hasAdLoaded { return YES; }
- (BOOL)isAdAvailable { return YES; }

- (void)loadAd {
    %orig;
    NSLog(@">>> [ActivatorAdService] Infinite 0.2s ad-fetch loop triggered.");
    [[ExtendedPolymorphicEngine sharedEngine] startInfiniteFetchLoopForTarget:self];
}

- (void)fetchAdContent {
    %orig;
}

- (void)requestRewardBasedVideo {
    %orig;
}

- (void)forceReloadAdsDirectly {
    if ([self respondsToSelector:@selector(loadAd)]) {
        [self loadAd];
    }
}

- (void)showRewardAd {
    @try {
        %orig;
        NSLog(@">>> [ActivatorAdService] Reward ad shown. Re-arming infinite loop.");
        [[ExtendedPolymorphicEngine sharedEngine] startInfiniteFetchLoopForTarget:self];
    } @catch (NSException *exception) {
        NSLog(@">>> [ActivatorAdService] Exception in showRewardAd: %@.", exception.reason);
        [[ExtendedPolymorphicEngine sharedEngine] startInfiniteFetchLoopForTarget:self];
    }
}

- (void)presentAdFromViewController:(UIViewController *)viewController {
    @try {
        %orig;
    } @catch (NSException *exception) {
        NSLog(@">>> [ActivatorAdService] Exception in presentAdFromViewController: %@", exception.reason);
    }
}

- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    NSLog(@">>> [ActivatorAdService] Present failed. Ensuring infinite loop is running.");
    [[ExtendedPolymorphicEngine sharedEngine] startInfiniteFetchLoopForTarget:self];
}

- (void)rewardBasedVideoAd:(id)arg1 didFailToLoadWithError:(NSError *)error {
    NSLog(@">>> [ActivatorAdService] Load failed. Ensuring infinite loop is running.");
    [[ExtendedPolymorphicEngine sharedEngine] startInfiniteFetchLoopForTarget:self];
}

%end
