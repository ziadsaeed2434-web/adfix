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
    // Generate a random IP in the 84.241.x.x range
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
        if (error) {
            NSLog(@"[AdPurge] Failed to list %@: %@", dir, error);
            continue;
        }
        for (NSString *item in contents) {
            NSString *fullPath = [dir stringByAppendingPathComponent:item];
            NSError *removeError = nil;
            [fm removeItemAtPath:fullPath error:&removeError];
            if (removeError) {
                NSLog(@"[AdPurge] Failed to remove %@: %@", fullPath, removeError);
            }
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

    if (status != errSecSuccess) {
        NSLog(@"[AdPurge] Keychain query failed with status: %d", (int)status);
        return;
    }

    NSArray *items = (__bridge_transfer NSArray *)result;
    for (NSDictionary *item in items) {
        NSString *service = item[(__bridge id)kSecAttrService];
        NSString *account = item[(__bridge id)kSecAttrAccount];

        // CRITICAL: Skip the specific token to prevent logout
        if ([service isEqualToString:kTargetKeychainService] &&
            [account isEqualToString:kTargetKeychainAccount]) {
            NSLog(@"[AdPurge] Preserved keychain item: Service=%@, Account=%@", service, account);
            continue;
        }

        NSDictionary *deleteQuery = @{
            (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecAttrService: service,
            (__bridge id)kSecAttrAccount: account
        };
        OSStatus delStatus = SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
        if (delStatus == errSecSuccess) {
            NSLog(@"[AdPurge] Deleted keychain item: Service=%@, Account=%@", service, account);
        }
    }
    NSLog(@"[AdPurge] Keychain purge complete (excluding target token).");
}

// ----------------------------------------------------------------------------
// 3. NSUserDefaults & Consent Management
// ----------------------------------------------------------------------------
static void resetAndConfigureDefaults(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // --- Clear volatile data ---
    NSDictionary *allDefaults = [defaults dictionaryRepresentation];
    for (NSString *key in allDefaults) {
        [defaults removeObjectForKey:key];
    }

    // --- Configure Pristine Environment ---
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd_HHmmssZ";
    NSString *nowString = [formatter stringFromDate:[NSDate date]];

    [defaults setObject:nowString forKey:@"AppsFlyerInstallDate"];
    [defaults setObject:nowString forKey:@"AppsFlyerFirstLaunchDate"];
    [defaults setObject:@(0) forKey:@"AppsFlyerCounter"];
    [defaults setObject:@(1) forKey:@"AppsFlyerLaunchKey"];
    [defaults setObject:@(0) forKey:@"AppsFlyerReinstallCounter"];

    // --- Force European Consent State (Allow Ads) ---
    [defaults setObject:@(1) forKey:@"IABTCF_gdprApplies"];
    [defaults setObject:@"1111111111" forKey:@"IABTCF_PurposeConsents"];
    [defaults setObject:@"1111111111" forKey:@"IABTCF_PurposeLegitimateInterests"];
    [defaults setObject:@"1111111111" forKey:@"IABTCF_VendorConsents"];
    [defaults setObject:@"1111111111" forKey:@"IABTCF_VendorLegitimateInterests"];
    [defaults setObject:@"3" forKey:@"ump_status"];
    [defaults setObject:@"4444" forKey:@"UMP_consentModeValues"];
    [defaults setObject:@"1" forKey:@"IABTCF_SpecialFeaturesOptIns"];
    [defaults setObject:@"5" forKey:@"IABTCF_PolicyVersion"];

    // --- Force Locale & Timezone ---
    [defaults setObject:@"nl_NL" forKey:@"AppleLocale"];
    [defaults setObject:@"Europe/Amsterdam" forKey:@"AppleICUForce24HourTime"];
    [defaults setObject:@"nl_NL" forKey:@"AppleLanguages"];

    [defaults synchronize];
    NSLog(@"[AdPurge] NSUserDefaults reset and reconfigured for European environment.");
}

// ----------------------------------------------------------------------------
// 4. Network Layer Hooking (IP Injection)
// ----------------------------------------------------------------------------
CHDeclareClass(NSURLSessionConfiguration);

// 0 Arguments (Getter)
CHOptimizedMethod0(0, self, NSDictionary *, NSURLSessionConfiguration, HTTPAdditionalHeaders) {
    NSMutableDictionary *headers = [CHSuper0(0, NSURLSessionConfiguration, HTTPAdditionalHeaders) mutableCopy];
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

// 2 Arguments
CHOptimizedMethod2(0, self, void, NSMutableURLRequest, setValue, NSString *, value, forHTTPHeaderField, NSString *, field) {
    // Inject the Dutch IP for common geo-spoofing headers
    if ([field isEqualToString:@"X-Forwarded-For"] ||
        [field isEqualToString:@"Client-IP"] ||
        [field isEqualToString:@"True-Client-IP"] ||
        [field isEqualToString:@"X-Real-IP"]) {

        NSString *ip = [[NSUserDefaults standardUserDefaults] stringForKey:@"__adhoc_session_ip"];
        if (ip) {
            value = ip; // Override with our generated IP
        }
    }
    CHSuper2(0, NSMutableURLRequest, setValue, value, forHTTPHeaderField, field);
}

// ----------------------------------------------------------------------------
// 5. SDK & Ad Controller Bypass
// ----------------------------------------------------------------------------
CHDeclareClass(GADAdLoader);

// 0 Arguments (Getter)
CHOptimizedMethod0(0, self, BOOL, GADAdLoader, isLoading) {
    return NO; // Force "not loading" so the app thinks it's ready to load
}

// 1 Argument
CHOptimizedMethod1(0, self, void, GADAdLoader, loadRequest, id, request) {
    NSLog(@"[AdPurge] Forcing GADAdLoader to load request: %@", request);
    CHSuper1(0, GADAdLoader, loadRequest, request);
}

CHDeclareClass(GADAdRequest);

// 4 Arguments
CHOptimizedMethod4(0, self, id, GADAdRequest, initWithAdUnitID, id, adUnitID, rootViewController, id, rootViewController, adTypes, id, adTypes, options, id, options) {
    NSMutableDictionary *newOptions = [(NSDictionary *)options mutableCopy];
    if (!newOptions) newOptions = [NSMutableDictionary new];
    newOptions[@"_npa"] = @(0); // Non-personalized ads = 0 (allow personalized)
    newOptions[@"rdp"] = @(1);  // Set consent for personalized ads
    return CHSuper4(0, GADAdRequest, initWithAdUnitID, adUnitID, rootViewController, rootViewController, adTypes, adTypes, options, newOptions);
}

CHDeclareClass(Activator.AdService);

// 0 Arguments
CHOptimizedMethod0(0, self, BOOL, Activator.AdService, hasRewardedAd) {
    return YES; // Always claim a rewarded ad is ready
}

CHOptimizedMethod0(0, self, BOOL, Activator.AdService, isReady) {
    return YES;
}

CHOptimizedMethod0(0, self, void, Activator.AdService, loadRewardAd) {
    CHSuper0(0, Activator.AdService, loadRewardAd);
    NSLog(@"[AdPurge] Intercepted loadRewardAd. Forcing success state.");
}

CHDeclareClass(AMAAdController);

// 0 Arguments
CHOptimizedMethod0(0, self, BOOL, AMAAdController, isAdvertisingTrackingEnabled) {
    return YES;
}

CHDeclareClass(AMAJailbreakCheck);

// Class Methods (0 Arguments)
CHOptimizedClassMethod0(0, self, int, AMAJailbreakCheck, jailbroken) { return 0; }
CHOptimizedClassMethod0(0, self, int, AMAJailbreakCheck, urlCheck) { return 0; }
CHOptimizedClassMethod0(0, self, int, AMAJailbreakCheck, cydiaCheck) { return 0; }

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
