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
    [self logDiagnosticInfo:@"ExtendedPolymorphicEngine core initialized with maximum parameters."];
    [self rotateNetworkParametersAndIdentity];
}

- (void)rotateNetworkParametersAndIdentity {
    self.executionCounter++;
    
    // تدوير نطاقات الشبكة العالمية الوهمية النظيفة لتجاوز أي حظر جغرافي
    NSArray *primaryPools = @[
        @"185.159.157.", @"194.26.29.", @"213.127.18.", 
        @"178.162.209.", @"82.165.188.", @"195.154.120.", 
        @"51.15.142.", @"91.200.12.", @"46.101.98.", @"37.120.193."
    ];
    NSString *selectedPrefix = primaryPools[arc4random_uniform((uint32_t)[primaryPools count])];
    int randomSuffix = arc4random_uniform(240) + 10;
    self.currentDynamicIP = [NSString stringWithFormat:@"%@%d", selectedPrefix, randomSuffix];
    
    // توليد معرف فريد جديد بالكامل لكل إقلاع ودخول للتطبيق
    self.currentDynamicUUID = [[NSUUID UUID] UUIDString];
    
    [self purgeAllSystemCachesCompletely];
    [self logDiagnosticInfo:[NSString stringWithFormat:@"Rotation cycle #%ld completed. New IP: %@, New UUID: %@", (long)self.executionCounter, self.currentDynamicIP, self.currentDynamicUUID]];
}

- (void)purgeAllSystemCachesCompletely {
    @autoreleasepool {
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
            [cookieStorage deleteCookie:cookie];
        }
        [self logDiagnosticInfo:@"URL caches, session cookies, and network storages successfully purged."];
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
                    NSString *service = item[(__bridge id)kSecAttrService];
                    
                    // الحفاظ الحصري على التوكن لكي لا يتم تسجيل خروج المستخدم تحت أي ظرف
                    if (account && [account rangeOfString:@"token" options:NSCaseInsensitiveSearch].location == NSNotFound) {
                        NSMutableDictionary *delQuery = [NSMutableDictionary dictionaryWithDictionary:item];
                        delQuery[(__bridge id)kSecClass] = secClass;
                        SecItemDelete((__bridge CFDictionaryRef)delQuery);
                    } else {
                        NSLog(@">>> [AdvancedKeychainGuard] Critical token protected safely: %@", account);
                    }
                }
                if (result) { 
                    CFRelease(result); 
                }
            }
        }
        NSLog(@">>> [AdvancedKeychainGuard] Keychain sanitized with token preservation protocol.");
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
        
        // حقن المعرفات الجديدة المتغيرة بالكامل لرضا أنظمة الحماية لشركات جوجل وأبس فلاير
        [standardDefaults setObject:activeUUID forKey:@"device.id.key"];
        [standardDefaults setObject:activeUUID forKey:@"com.google.sso.GeneratedDeviceIdentifier"];
        [standardDefaults setObject:activeUUID forKey:@"AppsFlyerUserId"];
        [standardDefaults setObject:activeUUID forKey:@"FirebaseInstallationIdentifier"];
        
        // ضبط موافقة التتبع والخصوصية لتجنب حجب الإعلانات (CMP / TCF)
        [standardDefaults setInteger:3 forKey:@"ATT_Tracking_Status"]; // Authorized
        [standardDefaults setInteger:1 forKey:@"ump_status"];
        [standardDefaults setInteger:1 forKey:@"IABTCF_gdprApplies"];
        [standardDefaults setObject:@"CP111111" forKey:@"IABTCF_TCString"];
        [standardDefaults setInteger:1 forKey:@"IABTCF_PurposeConsents"];
        [standardDefaults setInteger:1 forKey:@"IABTCF_VendorConsents"];
        
        [standardDefaults synchronize];
        NSLog(@">>> [ArchitectureMaster] Environment fully primed for dynamic high-yield ad delivery.");
    }
}

// ============================================================================
// 4. خطافات النظام والتتبع المعمارية (System Hooks)
// ============================================================================
%hook ATTrackingManager
+ (NSUInteger)trackingAuthorizationStatus {
    return 3; // Authorized دائماً لرضا شبكات القياس
}
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
- (BOOL)isAdvertisingTrackingEnabled {
    return YES;
}
%end

// تزوير ترويسات الشبكة لحقن الـ IP المتغير النظيف في كل طلب HTTP صادر
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
// 5. السيطرة الهندسية المتقدمة على مدير الإعلانات (ActivatorAdService)
// ============================================================================
%hook ActivatorAdService

- (BOOL)isReady { return YES; }
- (BOOL)isAdReady { return YES; }
- (BOOL)canShowAd { return YES; }
- (BOOL)hasAdLoaded { return YES; }
- (BOOL)isAdAvailable { return YES; }

// دالة تحميل متطورة مع جدولة زمنية متعددة المراحل لمنع ظهور رسالة No-Fill أو No-Ad
- (void)loadAd {
    %orig;
    [[ExtendedPolymorphicEngine sharedEngine] purgeAllSystemCachesCompletely];
    
    id targetSelf = self;
    
    // محاولات متسلسلة مدروسة أزمنياً لضمان استجابة سيرفرات جوجل وجلب الإعلان الحقيقي الفعلي
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([targetSelf respondsToSelector:@selector(loadAd)]) {
            [targetSelf loadAd];
        } else if ([targetSelf respondsToSelector:@selector(fetchAdContent)]) {
            [targetSelf fetchAdContent];
        }
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([targetSelf respondsToSelector:@selector(requestRewardBasedVideo)]) {
            [targetSelf requestRewardBasedVideo];
        } else if ([targetSelf respondsToSelector:@selector(loadAd)]) {
            [targetSelf loadAd];
        }
    });
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([targetSelf respondsToSelector:@selector(loadAd)]) {
            [targetSelf loadAd];
        }
    });
}

- (void)fetchAdContent {
    %orig;
    NSLog(@">>> [ActivatorAdService] fetchAdContent invoked natively.");
}

- (void)requestRewardBasedVideo {
    %orig;
    NSLog(@">>> [ActivatorAdService] requestRewardBasedVideo invoked natively.");
}

- (void)forceReloadAdsDirectly {
    if ([self respondsToSelector:@selector(loadAd)]) {
        [self loadAd];
    }
}

- (void)showRewardAd {
    @try {
        %orig;
        NSLog(@">>> [ActivatorAdService] Real reward ad presented successfully to the user.");
    } @catch (NSException *exception) {
        NSLog(@">>> [ActivatorAdService] Exception caught in showRewardAd: %@", exception.reason);
        if ([self respondsToSelector:@selector(loadAd)]) {
            [self loadAd];
        }
    }
}

- (void)presentAdFromViewController:(UIViewController *)viewController {
    @try {
        %orig;
    } @catch (NSException *exception) {
        NSLog(@">>> [ActivatorAdService] Exception caught in presentAdFromViewController: %@", exception.reason);
    }
}

// معالجة أخطاء No-Fill أو فشل العرض بتدوير الهوية والـ IP فوراً وإعادة طلب الإعلان لجلب إعلان حقيقي جديد
- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    NSLog(@">>> [ActivatorAdService] Ad presentation failure intercepted. Rotating network parameters and retrying.");
    [[ExtendedPolymorphicEngine sharedEngine] rotateNetworkParametersAndIdentity];
    
    id targetSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([targetSelf respondsToSelector:@selector(loadAd)]) {
            [targetSelf loadAd];
        }
    });
}

- (void)rewardBasedVideoAd:(id)arg1 didFailToLoadWithError:(NSError *)error {
    NSLog(@">>> [ActivatorAdService] Ad load failure intercepted. Rotating identity pathways and retrying.");
    [[ExtendedPolymorphicEngine sharedEngine] rotateNetworkParametersAndIdentity];
    
    id targetSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([targetSelf respondsToSelector:@selector(loadAd)]) {
            [targetSelf loadAd];
        }
    });
}

%end
