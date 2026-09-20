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
@end

static NSString *randomNewIDFA() {
    return [[NSUUID UUID] UUIDString];
}

static NSString *currentSessionIP = nil;
static NSString *currentSessionUserAgent = nil;

static NSString *getOrCreateGermanSessionIP() {
    if (currentSessionIP) return currentSessionIP;
    NSArray *prefixes = @[@"79.200.", @"84.112.", @"217.224.", @"91.64.", @"46.5."];
    currentSessionIP = [NSString stringWithFormat:@"%@%d.%d", prefixes[arc4random_uniform((uint32_t)prefixes.count)], arc4random_uniform(250) + 1, arc4random_uniform(250) + 1];
    return currentSessionIP;
}

static NSString *randomCleanUserAgent() {
    if (currentSessionUserAgent) return currentSessionUserAgent;
    NSArray *iOSVersions = @[@"17_4", @"17_5", @"18_0"];
    NSArray *deviceModels = @[@"iPhone15,2", @"iPhone16,1", @"iPhone16,2"];
    currentSessionUserAgent = [NSString stringWithFormat:@"Mozilla/5.0 (%@; CPU iPhone OS %@ like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", deviceModels[arc4random_uniform((uint32_t)deviceModels.count)], iOSVersions[arc4random_uniform((uint32_t)iOSVersions.count)]];
    return currentSessionUserAgent;
}

static void clearKeychainExceptToken() {
    NSArray *secClasses = @[(__bridge id)kSecClassGenericPassword, (__bridge id)kSecClassInternetPassword, (__bridge id)kSecClassCertificate, (__bridge id)kSecClassKey, (__bridge id)kSecClassIdentity];
    for (id secClass in secClasses) {
        NSDictionary *spec = @{(__bridge id)kSecClass: secClass};
        CFArrayRef result = NULL;
        if (SecItemCopyMatching((__bridge CFDictionaryRef)spec, (CFTypeRef *)&result) == errSecSuccess) {
            NSArray *items = (__bridge NSArray *)result;
            for (NSDictionary *item in items) {
                if (![item[(__bridge id)kSecAttrAccount] isEqualToString:@"tokenKey"]) {
                    NSMutableDictionary *delQuery = [NSMutableDictionary dictionaryWithDictionary:item];
                    delQuery[(__bridge id)kSecClass] = secClass;
                    SecItemDelete((__bridge CFDictionaryRef)delQuery);
                }
            }
            if (result) CFRelease(result);
        }
    }
}

// 1. التطهير الشامل وتجهيز البيئة الألمانية عند كل إقلاع
static __attribute__((constructor)) void wipeAndSpawnFreshEnvironmentOnEveryLaunch() {
    @autoreleasepool {
        getOrCreateGermanSessionIP();
        randomCleanUserAgent();
        clearKeychainExceptToken();

        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleIdentifier) {
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleIdentifier];
        }

        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        [[NSURLCache sharedURLCache] setDiskCapacity:0];
        [[NSURLCache sharedURLCache] setMemoryCapacity:0];

        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *homeDir = NSHomeDirectory();
        NSError *error = nil;
        for (NSString *item in [fileManager contentsOfDirectoryAtPath:homeDir error:&error]) {
            [fileManager removeItemAtPath:[homeDir stringByAppendingPathComponent:item] error:&error];
        }

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *freshID = randomNewIDFA();
        
        [defaults setObject:@[@"de-DE", @"en-US"] forKey:@"AppleLanguages"];
        [defaults setObject:@"DE" forKey:@"AppleLocale"];
        [defaults setObject:@"Europe/Berlin" forKey:@"NSReuseTimeZone"];
        
        [defaults setObject:freshID forKey:@"device.id.key"];
        [defaults setObject:freshID forKey:@"com.google.sso.GeneratedDeviceIdentifier"];
        [defaults setObject:freshID forKey:@"AppsFlyerUserId"];
        
        [defaults setInteger:3 forKey:@"ATT_Tracking_Status"]; // Authorized لضمان قبول السيرفر للإعلانات الحقيقية
        [defaults setInteger:1 forKey:@"IABTCF_gdprApplies"];
        [defaults synchronize];
        
        NSLog(@">>> [All-Features-Restored] German IP: %@ | Ready for real ads.", currentSessionIP);
    }
}

// 2. تجاوز قيود التتبع
%hook ATTrackingManager
+ (NSUInteger)trackingAuthorizationStatus { return 3; } // Authorized
%end

%hook UIDevice
- (NSUUID *)identifierForVendor { return [NSUUID UUID]; }
%end

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier { return [NSUUID UUID]; }
- (BOOL)isAdvertisingTrackingEnabled { return YES; }
%end

// 3. حقن الـ IP والثبات في طلبات الشبكة
%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field isEqualToString:@"X-Forwarded-For"] || [field isEqualToString:@"Client-IP"] || [field isEqualToString:@"True-Client-IP"] || [field isEqualToString:@"X-Real-IP"]) {
        value = getOrCreateGermanSessionIP();
    }
    %orig(value, field);
}
- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field isEqualToString:@"X-Forwarded-For"] || [field isEqualToString:@"Client-IP"] || [field isEqualToString:@"True-Client-IP"] || [field isEqualToString:@"X-Real-IP"]) {
        value = getOrCreateGermanSessionIP();
    }
    %orig(value, field);
}
- (void)setHTTPUserAgent:(NSString *)userAgent {
    if (currentSessionUserAgent) {
        %orig(currentSessionUserAgent);
        return;
    }
    %orig;
}
%end

// 4. المحصن الشامل لدوال الإعلانات لضمان سلاسة العرض
%hook ActivatorAdService

- (BOOL)isReady { return YES; }
- (BOOL)isAdReady { return YES; }
- (BOOL)canShowAd { return YES; }
- (BOOL)hasAdLoaded { return YES; }
- (BOOL)isLoaded { return YES; }
- (BOOL)isRewarded { return YES; }
- (BOOL)isRewardedAdReady { return YES; }
- (BOOL)hasAds { return YES; }
- (BOOL)isAvailable { return YES; }

- (void)loadAd {
    %orig;
}

- (void)showRewardAd {
    @try {
        %orig;
        NSLog(@">>> [Ads-Engine] showRewardAd executed.");
    } @catch (NSException *e) {}
}

- (void)presentAdFromViewController:(UIViewController *)viewController {
    @try {
        if (!viewController) {
            viewController = [UIApplication sharedApplication].keyWindow.rootViewController;
        }
        %orig(viewController);
    } @catch (NSException *e) {}
}

- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    id targetSelf = self;
    if ([targetSelf respondsToSelector:@selector(loadAd)]) {
        [targetSelf loadAd];
    }
}

%end
