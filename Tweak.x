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
// 1. الواجهات الهندسية المتقدمة وبروتوكولات الإدارة والتشخيص الشاملة
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
- (void)bootstrapPolymorphicCore;
- (void)rotateNetworkParametersAndIdentity;
- (void)purgeAllSystemCachesCompletely;
- (void)logDiagnosticInfo:(NSString *)infoMessage;
@end

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
    [self logDiagnosticInfo:@"ExtendedPolymorphicEngine core initialized with random days absence and 20-attempt loop."];
    [self rotateNetworkParametersAndIdentity];
}

- (void)rotateNetworkParametersAndIdentity {
    self.executionCounter++;
    
    // تدوير الـ IP ضمن نطاقات 82.92 السكنية الحقيقية ومعرف الجهاز
    NSArray *primaryPools = @[
        @"82.92.0.", @"82.92.32.", @"82.92.64.", 
        @"82.92.128.", @"82.92.160.", @"82.92.192."
    ];
    NSString *selectedPrefix = primaryPools[arc4random_uniform((uint32_t)[primaryPools count])];
    int randomSuffix = arc4random_uniform(240) + 10;
    self.currentDynamicIP = [NSString stringWithFormat:@"%@%d", selectedPrefix, randomSuffix];
    self.currentDynamicUUID = [[NSUUID UUID] UUIDString];
    
    // توليد عدد أيام غياب عشوائي مختلف في كل مرة (بين 15 إلى 90 يوماً في الماضي)
    int randomDaysAgo = arc4random_uniform(76) + 15; 
    NSTimeInterval randomSecondsAgo = -((double)randomDaysAgo * 24 * 60 * 60);
    self.fakeLastLaunchDate = [NSDate dateWithTimeIntervalSinceNow:randomSecondsAgo];
    
    [self purgeAllSystemCachesCompletely];
    [self logDiagnosticInfo:[NSString stringWithFormat:@"Session Launch #%ld -> IP: %@, UUID: %@, Absence Days: %d days ago", (long)self.executionCounter, self.currentDynamicIP, self.currentDynamicUUID, randomDaysAgo]];
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
@end

// ============================================================================
// 2. إدارة وتأمين الـ Keychain والحفاظ الحصري على التوكن
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
// 3. المُهتّئ العام ونظام التهيئة التلقائي الشامل (Constructor)
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
        
        // حقن المعرفات الجديدة
        [standardDefaults setObject:activeUUID forKey:@"device.id.key"];
        [standardDefaults setObject:activeUUID forKey:@"com.google.sso.GeneratedDeviceIdentifier"];
        [standardDefaults setObject:activeUUID forKey:@"AppsFlyerUserId"];
        [standardDefaults setObject:activeUUID forKey:@"FirebaseInstallationIdentifier"];
        
        // حقن تواريخ الغياب بالأيام المختلفة
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
// 4. خطافات النظام والتتبع المعمارية (System Hooks)
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
// 5. السيطرة الهندسية المتقدمة على مدير الإعلانات (20-Attempt Loop + Random Days Absence)
// ============================================================================
%hook ActivatorAdService

- (BOOL)isReady { return YES; }
- (BOOL)isAdReady { return YES; }
- (BOOL)canShowAd { return YES; }
- (BOOL)hasAdLoaded { return YES; }
- (BOOL)isAdAvailable { return YES; }

- (void)loadAd {
    %orig;
    id targetSelf = self;
    
    NSLog(@">>> [ActivatorAdService] 20-attempt aggressive multi-fetch triggered with random days absence profile.");
    
    double attempts[20] = {
        0.05, 0.12, 0.20, 0.30, 0.42, 
        0.55, 0.70, 0.88, 1.08, 1.30, 
        1.55, 1.83, 2.14, 2.48, 2.85, 
        3.25, 3.68, 4.14, 4.63, 5.15
    };
    
    for (int i = 0; i < 20; i++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(attempts[i] * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([targetSelf respondsToSelector:@selector(loadAd)]) {
                [targetSelf fetchAdContent];
                [targetSelf requestRewardBasedVideo];
            }
        });
    }
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
        NSLog(@">>> [ActivatorAdService] Reward ad presented successfully. Re-triggering 20-attempt loop.");
        if ([self respondsToSelector:@selector(loadAd)]) {
            [self loadAd];
        }
    } @catch (NSException *exception) {
        NSLog(@">>> [ActivatorAdService] Exception in showRewardAd: %@.", exception.reason);
        if ([self respondsToSelector:@selector(loadAd)]) {
            [self loadAd];
        }
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
    NSLog(@">>> [ActivatorAdService] Ad presentation handled. Forcing 20-attempt reload sequence.");
    id targetSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([targetSelf respondsToSelector:@selector(loadAd)]) {
            [targetSelf loadAd];
        }
    });
}

- (void)rewardBasedVideoAd:(id)arg1 didFailToLoadWithError:(NSError *)error {
    NSLog(@">>> [ActivatorAdService] Ad load event intercepted. Forcing 20-attempt reload sequence.");
    id targetSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([targetSelf respondsToSelector:@selector(loadAd)]) {
            [targetSelf loadAd];
        }
    });
}

%end
