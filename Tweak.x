// AdPurgeTweak.x
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import <CaptainHook/CaptainHook.h>
#import <substrate.h>

// ----------------------------------------------------------------------------
// Configuration
// ----------------------------------------------------------------------------
static NSString *const kTargetKeychainService = @"app.getsmscode";
static NSString *const kTargetKeychainAccount = @"tokenKey";

// ----------------------------------------------------------------------------
// 1. Dynamic IP Generation & Session Persistence
// ----------------------------------------------------------------------------
static NSString *gGeneratedIP = nil;

static NSString *generateDutchIP(void) {
    uint32_t octet3 = arc4random_uniform(256);
    uint32_t octet4 = arc4random_uniform(256);
    return [NSString stringWithFormat:@"84.241.%u.%u", octet3, octet4];
}

static void persistSessionIP(void) {
    if (!gGeneratedIP) {
        gGeneratedIP = generateDutchIP();
        NSLog(@"[AdPurge] Generated Dutch IP for session: %@", gGeneratedIP);
        [[NSUserDefaults standardUserDefaults] setObject:gGeneratedIP forKey:@"__adhoc_session_ip"];
    }
}

// ----------------------------------------------------------------------------
// 2. Comprehensive Environment Purge (Sandbox & Keychain)
// ----------------------------------------------------------------------------
static void purgeSandbox(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDir = paths.firstObject;
    NSString *libraryDir = [documentsDir stringByDeletingLastPathComponent];
    NSString *cachesDir = [libraryDir stringByAppendingPathComponent:@"Caches"];
    NSString *tmpDir = NSTemporaryDirectory();

    NSArray *directoriesToPurge = @[documentsDir, libraryDir, cachesDir, tmpDir];

    for (NSString *dir in directoriesToPurge) {
        NSError *error = nil;
        NSArray *contents = [fm contentsOfDirectoryAtPath:dir error:&error];
        if (error) continue;
        for (NSString *item in contents) {
            NSString *fullPath = [dir stringByAppendingPathComponent:item];
            [fm removeItemAtPath:fullPath error:nil];
        }
    }
    NSLog(@"[AdPurge] Sandbox purge complete.");
}

static void purgeKeychainExceptToken(void) {
    NSMutableDictionary *query = [@{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecReturnAttributes: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll
    } mutableCopy];

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);

    if (status != errSecSuccess) return;

    NSArray *items = (__bridge_transfer NSArray *)result;
    for (NSDictionary *item in items) {
        NSString *service = item[(__bridge id)kSecAttrService];
        NSString *account = item[(__bridge id)kSecAttrAccount];

        // استثناء التوكن لمنع تسجيل الخروج
        if ([service isEqualToString:kTargetKeychainService] &&
            [account isEqualToString:kTargetKeychainAccount]) {
            NSLog(@"[AdPurge] Preserved keychain item: %@", service);
            continue;
        }

        NSDictionary *deleteQuery = @{
            (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecAttrService: service,
            (__bridge id)kSecAttrAccount: account
        };
        SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
    }
    NSLog(@"[AdPurge] Keychain purge complete (excluding token).");
}

// ----------------------------------------------------------------------------
// 3. NSUserDefaults & Consent Management
// ----------------------------------------------------------------------------
static void resetAndConfigureDefaults(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    NSDictionary *allDefaults = [defaults dictionaryRepresentation];
    for (NSString *key in allDefaults) {
        [defaults removeObjectForKey:key];
    }

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd_HHmmssZ";
    NSString *nowString = [formatter stringFromDate:[NSDate date]];

    [defaults setObject:nowString forKey:@"AppsFlyerInstallDate"];
    [defaults setObject:nowString forKey:@"AppsFlyerFirstLaunchDate"];
    [defaults setObject:@(0) forKey:@"AppsFlyerCounter"];
    [defaults setObject:@(1) forKey:@"AppsFlyerLaunchKey"];

    // إجبار الموافقات الأوروبية
    [defaults setObject:@(1) forKey:@"IABTCF_gdprApplies"];
    [defaults setObject:@"1111111111" forKey:@"IABTCF_PurposeConsents"];
    [defaults setObject:@"1111111111" forKey:@"IABTCF_PurposeLegitimateInterests"];
    [defaults setObject:@"1111111111" forKey:@"IABTCF_VendorConsents"];
    [defaults setObject:@"1111111111" forKey:@"IABTCF_VendorLegitimateInterests"];
    [defaults setObject:@"3" forKey:@"ump_status"];
    [defaults setObject:@"4444" forKey:@"UMP_consentModeValues"];
    [defaults setObject:@"1" forKey:@"IABTCF_SpecialFeaturesOptIns"];
    [defaults setObject:@"5" forKey:@"IABTCF_PolicyVersion"];

    // إجبار اللغة والتوقيت
    [defaults setObject:@"nl_NL" forKey:@"AppleLocale"];
    [defaults setObject:@"Europe/Amsterdam" forKey:@"AppleICUForce24HourTime"];
    [defaults setObject:@"nl_NL" forKey:@"AppleLanguages"];

    [defaults synchronize];
    NSLog(@"[AdPurge] NSUserDefaults reset for European environment.");
}

// ----------------------------------------------------------------------------
// 4. Network Layer Hooking (IP Injection)
// ----------------------------------------------------------------------------
CHDeclareClass(NSURLSessionConfiguration);

// الصيغة الصحيحة: CHOptimizedMethod0(optimization, return_type, class_type, name)
CHOptimizedMethod0(0, NSDictionary *, NSURLSessionConfiguration, HTTPAdditionalHeaders) {
    NSMutableDictionary *headers = [CHSuper0(NSURLSessionConfiguration, HTTPAdditionalHeaders) mutableCopy];
    if (!headers) headers = [NSMutableDictionary new];

    NSString *ip = [[NSUserDefaults standardUserDefaults] stringForKey:@"__adhoc_session_ip"];
    if (ip) {
        headers[@"X-Forwarded-For"] = ip;
        headers[@"Client-IP"] = ip;
        headers[@"True-Client-IP"] = ip;
        headers[@"X-Real-IP"] = ip;
    }
    return headers;
}

CHDeclareClass(NSMutableURLRequest);

// الصيغة الصحيحة: CHOptimizedMethod2(optimization, return_type, class_type, name1, type1, arg1, name2, type2, arg2)
CHOptimizedMethod2(0, void, NSMutableURLRequest, setValue, NSString *, value, forHTTPHeaderField, NSString *, field) {
    if ([field isEqualToString:@"X-Forwarded-For"] ||
        [field isEqualToString:@"Client-IP"] ||
        [field isEqualToString:@"True-Client-IP"] ||
        [field isEqualToString:@"X-Real-IP"]) {

        NSString *ip = [[NSUserDefaults standardUserDefaults] stringForKey:@"__adhoc_session_ip"];
        if (ip) {
            value = ip;
        }
    }
    CHSuper2(NSMutableURLRequest, setValue, value, forHTTPHeaderField, field);
}

// ----------------------------------------------------------------------------
// 5. SDK & Ad Controller Bypass
// ----------------------------------------------------------------------------
CHDeclareClass(GADAdLoader);

CHOptimizedMethod0(0, BOOL, GADAdLoader, isLoading) {
    return NO;
}

CHOptimizedMethod1(0, void, GADAdLoader, loadRequest, id, request) {
    NSLog(@"[AdPurge] Forcing GADAdLoader to load request: %@", request);
    CHSuper1(GADAdLoader, loadRequest, request);
}

CHDeclareClass(GADAdRequest);

CHOptimizedMethod4(0, id, GADAdRequest, initWithAdUnitID, id, adUnitID, rootViewController, id, rootViewController, adTypes, id, adTypes, options, id, options) {
    NSMutableDictionary *newOptions = [(NSDictionary *)options mutableCopy];
    if (!newOptions) newOptions = [NSMutableDictionary new];
    newOptions[@"_npa"] = @(0); 
    newOptions[@"rdp"] = @(1);  
    return CHSuper4(GADAdRequest, initWithAdUnitID, adUnitID, rootViewController, rootViewController, adTypes, adTypes, options, newOptions);
}

CHDeclareClass(Activator.AdService);

CHOptimizedMethod0(0, BOOL, Activator.AdService, hasRewardedAd) {
    return YES;
}

CHOptimizedMethod0(0, BOOL, Activator.AdService, isReady) {
    return YES;
}

CHOptimizedMethod0(0, void, Activator.AdService, loadRewardAd) {
    CHSuper0(Activator.AdService, loadRewardAd);
    NSLog(@"[AdPurge] Intercepted loadRewardAd. Forcing success state.");
}

CHDeclareClass(AMAAdController);

CHOptimizedMethod0(0, BOOL, AMAAdController, isAdvertisingTrackingEnabled) {
    return YES;
}

CHDeclareClass(AMAJailbreakCheck);

CHOptimizedClassMethod0(0, int, AMAJailbreakCheck, jailbroken) { return 0; }
CHOptimizedClassMethod0(0, int, AMAJailbreakCheck, urlCheck) { return 0; }
CHOptimizedClassMethod0(0, int, AMAJailbreakCheck, cydiaCheck) { return 0; }

// ----------------------------------------------------------------------------
// 6. Initialization & Hook Setup
// ----------------------------------------------------------------------------
CHConstructor {
    @autoreleasepool {
        NSLog(@"[AdPurge] Tweak loaded. Starting environment purge...");

        persistSessionIP();
        purgeSandbox();
        purgeKeychainExceptToken();
        resetAndConfigureDefaults();

        CHLoadClass(NSURLSessionConfiguration);
        CHLoadClass(NSMutableURLRequest);
        CHLoadClass(GADAdLoader);
        CHLoadClass(GADAdRequest);
        CHLoadClass(Activator.AdService);
        CHLoadClass(AMAAdController);
        CHLoadClass(AMAJailbreakCheck);

        NSLog(@"[AdPurge] Initialization complete. Dutch IP: %@", gGeneratedIP);
    }
}
