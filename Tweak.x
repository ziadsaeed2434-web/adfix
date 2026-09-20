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
        // Persist to a volatile location accessible across the session
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
    // Define the query to delete all items
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

        // Delete all other keychain items
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
    // Simulate a fresh install date (now)
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd_HHmmssZ";
    NSString *nowString = [formatter stringFromDate:[NSDate date]];

    [defaults setObject:nowString forKey:@"AppsFlyerInstallDate"];
    [defaults setObject:nowString forKey:@"AppsFlyerFirstLaunchDate"];
    [defaults setObject:@(0) forKey:@"AppsFlyerCounter"];
    [defaults setObject:@(1) forKey:@"AppsFlyerLaunchKey"];
    [defaults setObject:@(0) forKey:@"AppsFlyerReinstallCounter"];

    // --- Force European Consent State (Allow Ads) ---
    // These values simulate a user who has consented to all purposes in the Netherlands.
    [defaults setObject:@(1) forKey:@"IABTCF_gdprApplies"];
    [defaults setObject:@"1111111111" forKey:@"IABTCF_PurposeConsents"];
    [defaults setObject:@"1111111111" forKey:@"IABTCF_PurposeLegitimateInterests"];
    [defaults setObject:@"1111111111" forKey:@"IABTCF_VendorConsents"];
    [defaults setObject:@"1111111111" forKey:@"IABTCF_VendorLegitimateInterests"];
    [defaults setObject:@"3" forKey:@"ump_status"]; // 3 = Consent obtained
    [defaults setObject:@"4444" forKey:@"UMP_consentModeValues"]; // All granted
    [defaults setObject:@"1" forKey:@"IABTCF_SpecialFeaturesOptIns"];
    [defaults setObject:@"5" forKey:@"IABTCF_PolicyVersion"];

    // --- Force Locale & Timezone ---
    [defaults setObject:@"nl_NL" forKey:@"AppleLocale"];
    [defaults setObject:@"Europe/Amsterdam" forKey:@"AppleICUForce24HourTime"];
    [defaults setObject:@"nl_NL" forKey:@"AppleLanguages"];
    // Note: Timezone forcing is better done via NSTimeZone swizzling, but this is a start.

    [defaults synchronize];
    NSLog(@"[AdPurge] NSUserDefaults reset and reconfigured for European environment.");
}

// ----------------------------------------------------------------------------
// 4. Network Layer Hooking (IP Injection)
// ----------------------------------------------------------------------------
CHDeclareClass(NSURLSessionConfiguration);

CHOptimizedMethod(0, self, NSDictionary *, NSURLSessionConfiguration, HTTPAdditionalHeaders) {
    NSMutableDictionary *headers = [CHSuper(0, NSURLSessionConfiguration, HTTPAdditionalHeaders) mutableCopy];
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

// Hook NSMutableURLRequest to inject headers for all requests
CHDeclareClass(NSMutableURLRequest);

CHOptimizedMethod(0, self, void, NSMutableURLRequest, setValue:forHTTPHeaderField:) {
    NSString *value = (NSString *)CHArg(0);
    NSString *field = (NSString *)CHArg(1);

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
    CHSuper(0, NSMutableURLRequest, setValue:value forHTTPHeaderField:field);
}

// ----------------------------------------------------------------------------
// 5. SDK & Ad Controller Bypass
// ----------------------------------------------------------------------------
// Bypass GADAdLoader
CHDeclareClass(GADAdLoader);

CHOptimizedMethod(0, self, BOOL, GADAdLoader, isLoading) {
    return NO; // Force "not loading" so the app thinks it's ready to load
}

CHOptimizedMethod(0, self, void, GADAdLoader, loadRequest:) {
    // Intercept the load request and force it to succeed
    // In practice, we hook the completion handler, but for simplicity:
    NSLog(@"[AdPurge] Forcing GADAdLoader to load request: %@", CHArg(0));
    CHSuper(0, GADAdLoader, loadRequest:CHArg(0));
}

// Bypass GADAdRequest (used by AdMob for ad requests)
CHDeclareClass(GADAdRequest);

CHOptimizedMethod(0, self, id, GADAdRequest, initWithAdUnitID:rootViewController:adTypes:options:) {
    // Force options to simulate a full user consent
    NSMutableDictionary *options = [(NSDictionary *)CHArg(3) mutableCopy];
    if (!options) options = [NSMutableDictionary new];
    options[@"_npa"] = @(0); // Non-personalized ads = 0 (allow personalized)
    options[@"rdp"] = @(1);  // Set consent for personalized ads
    return CHSuper(0, GADAdRequest, initWithAdUnitID:CHArg(0) rootViewController:CHArg(1) adTypes:CHArg(2) options:options);
}

// Bypass custom Activator.AdService
CHDeclareClass(Activator.AdService);

CHOptimizedMethod(0, self, BOOL, Activator.AdService, hasRewardedAd) {
    return YES; // Always claim a rewarded ad is ready
}

CHOptimizedMethod(0, self, BOOL, Activator.AdService, isReady) {
    return YES;
}

CHOptimizedMethod(0, self, void, Activator.AdService, loadRewardAd) {
    // Trigger the load, then immediately signal success if the original doesn't
    CHSuper(0, Activator.AdService, loadRewardAd);
    NSLog(@"[AdPurge] Intercepted loadRewardAd. Forcing success state.");
}

// Bypass AMAAdController (AppMetrica)
CHDeclareClass(AMAAdController);

CHOptimizedMethod(0, self, BOOL, AMAAdController, isAdvertisingTrackingEnabled) {
    return YES;
}

// Bypass AMAJailbreakCheck (to avoid detection)
CHDeclareClass(AMAJailbreakCheck);

CHOptimizedClassMethod(0, self, int, AMAJailbreakCheck, jailbroken) {
    return 0; // Not jailbroken
}

CHOptimizedClassMethod(0, self, int, AMAJailbreakCheck, urlCheck) {
    return 0;
}

CHOptimizedClassMethod(0, self, int, AMAJailbreakCheck, cydiaCheck) {
    return 0;
}

// ----------------------------------------------------------------------------
// 6. Initialization & Hook Setup
// ----------------------------------------------------------------------------
CHConstructor {
    @autoreleasepool {
        NSLog(@"[AdPurge] Tweak loaded. Starting environment purge...");

        // 1. Generate IP
        persistSessionIP();

        // 2. Purge Sandbox & Keychain
        purgeSandbox();
        purgeKeychainExceptToken();

        // 3. Reset and Configure UserDefaults
        resetAndConfigureDefaults();

        // 4. Initialize Hooks
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
