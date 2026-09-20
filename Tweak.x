// Tweak.x

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonCrypto.h>

// MARK: - Helper Functions

// Generates a random IP address in the 84.241.x.x range.
static NSString *generateRandomDutchIP() {
    uint32_t randomPart1 = arc4random_uniform(256);
    uint32_t randomPart2 = arc4random_uniform(256);
    return [NSString stringWithFormat:@"84.241.%u.%u", randomPart1, randomPart2];
}

// The pinned IP for the current session.
static NSString *sessionIP = nil;

// MARK: - Deep Clean & Purge Module

@interface Cleaner : NSObject
+ (void)performDeepClean;
@end

@implementation Cleaner

+ (void)performDeepClean {
    // 1. Clear Network Caches
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
        [cookieStorage deleteCookie:cookie];
    }

    // 2. Clear Sandbox
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libraryPath = [paths firstObject];
    
    NSError *error;
    NSArray *libraryContents = [fileManager contentsOfDirectoryAtPath:libraryPath error:&error];
    if (error) {
        NSLog(@"[Tweak] Error listing library contents: %@", error);
    }

    for (NSString *item in libraryContents) {
        // Preserve the Preferences directory, as NSUserDefaults is stored here.
        if ([item isEqualToString:@"Preferences"]) {
            continue;
        }
        NSString *fullPath = [libraryPath stringByAppendingPathComponent:item];
        [fileManager removeItemAtPath:fullPath error:&error];
        if (error) {
            NSLog(@"[Tweak] Failed to remove item at %@: %@", fullPath, error);
        }
    }

    // Also clear the Caches directory specifically.
    NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachePath = [cachePaths firstObject];
    NSArray *cacheContents = [fileManager contentsOfDirectoryAtPath:cachePath error:&error];
    for (NSString *item in cacheContents) {
        NSString *fullPath = [cachePath stringByAppendingPathComponent:item];
        [fileManager removeItemAtPath:fullPath error:&error];
    }

    // 3. Targeted Keychain Cleanup
    // This query deletes all keychain items for the app EXCEPT the one with the specific service and account.
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: @"app.getsmscode",
        (__bridge id)kSecAttrAccount: @"tokenKey"
    };
    
    // First, delete the specific token we want to preserve, to ensure it's not accidentally removed later.
    // Actually, we will delete everything EXCEPT this. We'll use a different approach:
    // We fetch all items, and delete the ones that don't match.
    
    // Simpler approach: Delete all generic passwords, then re-add the token? No, we don't have the token value.
    // Best approach: Query for all generic passwords, and delete those not matching our criteria.
    
    NSMutableDictionary *allQuery = [@{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                                        (__bridge id)kSecReturnAttributes: @YES,
                                        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll} mutableCopy];
    
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)allQuery, &result);
    if (status == errSecSuccess && result) {
        NSArray *items = (__bridge_transfer NSArray *)result;
        for (NSDictionary *item in items) {
            NSString *service = item[(__bridge id)kSecAttrService];
            NSString *account = item[(__bridge id)kSecAttrAccount];
            
            if ([service isEqualToString:@"app.getsmscode"] && [account isEqualToString:@"tokenKey"]) {
                NSLog(@"[Tweak] Preserving keychain item for service: %@, account: %@", service, account);
                continue;
            }
            
            NSMutableDictionary *deleteQuery = [@{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword} mutableCopy];
            deleteQuery[(__bridge id)kSecAttrService] = service;
            deleteQuery[(__bridge id)kSecAttrAccount] = account;
            
            OSStatus deleteStatus = SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
            if (deleteStatus != errSecSuccess) {
                NSLog(@"[Tweak] Failed to delete keychain item: %@", deleteQuery);
            }
        }
    }
    
    NSLog(@"[Tweak] Deep clean completed.");
}

@end

// MARK: - Network Spoofing Module

@interface DutchIPProtocol : NSURLProtocol
@end

@implementation DutchIPProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    // Only intercept HTTP/HTTPS requests.
    if ([NSURLProtocol propertyForKey:@"DutchIPHandled" inRequest:request]) {
        return NO;
    }
    return [request.URL.scheme isEqualToString:@"http"] || [request.URL.scheme isEqualToString:@"https"];
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    NSMutableURLRequest *newRequest = [self.request mutableCopy];
    
    // Inject the pinned IP into the X-Forwarded-For header.
    if (sessionIP) {
        [newRequest setValue:sessionIP forHTTPHeaderField:@"X-Forwarded-For"];
        [newRequest setValue:sessionIP forHTTPHeaderField:@"X-Real-IP"];
    }
    
    // Mark the request as handled to prevent infinite loops.
    [NSURLProtocol setProperty:@YES forKey:@"DutchIPHandled" inRequest:newRequest];
    
    // Use a new session for this request to avoid caching issues.
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:newRequest];
    [task resume];
}

- (void)stopLoading {
    // No-op for this implementation.
}

// MARK: NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [self.client URLProtocol:self didLoadData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        [self.client URLProtocol:self didFailWithError:error];
    } else {
        [self.client URLProtocolDidFinishLoading:self];
    }
}

@end

// MARK: - Configuration & State Module

@interface ConfigManager : NSObject
+ (void)setupIdealEnvironment;
@end

@implementation ConfigManager

+ (void)setupIdealEnvironment {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // 1. Reset Installation and Launch Data
    NSString *currentDateString = [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]];
    [defaults setObject:currentDateString forKey:@"AppsFlyerInstallDate"];
    [defaults setObject:currentDateString forKey:@"AppsFlyerInitDate"];
    [defaults setObject:currentDateString forKey:@"AppsFlyerFirstLaunchDate"];
    [defaults setObject:currentDateString forKey:@"AppsFlyerDate3"];
    [defaults setObject:@(1) forKey:@"AppsFlyerCounter"];
    [defaults setObject:@(0) forKey:@"AppsFlyerReinstallCounter"];
    [defaults setObject:@(1) forKey:@"AppsFlyerLaunchKey"];
    [defaults setObject:@(1) forKey:@"AppsFlyerReadyToSendEvents"];
    
    // 2. Set Ideal European Consent (IAB TCF & UMP)
    // This simulates a user who has granted full consent for all purposes.
    [defaults setObject:@"1" forKey:@"IABTCF_gdprApplies"]; // GDPR applies
    [defaults setObject:@"11111111111" forKey:@"IABTCF_PurposeConsents"]; // All purposes consented
    [defaults setObject:@"01000011111" forKey:@"IABTCF_PurposeLegitimateInterests"];
    [defaults setObject:@"10000000011110110000100000000000000000000000000001" forKey:@"IABTCF_VendorConsents"];
    [defaults setObject:@"10000000011110110000100000000000000000000000000001" forKey:@"IABTCF_VendorLegitimateInterests"];
    [defaults setObject:@"1" forKey:@"IABTCF_SpecialFeaturesOptIns"]; // Opt-in to special features
    [defaults setObject:@"CY" forKey:@"IABTCF_PublisherCC"]; // Set a European country code (e.g., Cyprus)
    [defaults setObject:@"0" forKey:@"IABTCF_PurposeOneTreatment"];
    [defaults setObject:@"0" forKey:@"IABTCF_UseNonStandardStacks"];
    [defaults setObject:@"300" forKey:@"IABTCF_CmpSdkID"];
    [defaults setObject:@"2" forKey:@"IABTCF_CmpSdkVersion"];
    [defaults setObject:@"5" forKey:@"IABTCF_PolicyVersion"];
    [defaults setObject:@"3" forKey:@"ump_status"];
    [defaults setObject:@"2" forKey:@"ump_rq_st"];
    [defaults setObject:@"1" forKey:@"ump_pors"];
    [defaults setObject:@"4444" forKey:@"UMP_consentModeValues"];
    
    // 3. Disable Security/Diagnostic Flags (if necessary)
    [defaults setBool:NO forKey:@"em_lockdownModeEnabled"];
    [defaults setBool:NO forKey:@"hk_hfeModeEnabled"];
    
    [defaults synchronize];
    NSLog(@"[Tweak] Ideal environment configured in NSUserDefaults.");
}

@end

// MARK: - Ad-State Override Module

// Hooking the custom AdService class. The actual class name might be Swift, e.g., "Activator.AdService".
// We'll hook by name to be safe.
static void hookAdService() {
    Class adServiceClass = NSClassFromString(@"Activator.AdService");
    if (!adServiceClass) {
        // Try another common name pattern.
        adServiceClass = NSClassFromString(@"AdService");
    }
    if (!adServiceClass) {
        NSLog(@"[Tweak] Could not find AdService class to hook.");
        return;
    }
    
    // Hook the methods that check for ad availability.
    // The exact method names are inferred from the provided file content.
    // We'll hook common patterns like "isReady", "hasAd", "canShowAd".
    
    SEL isReadySelector = NSSelectorFromString(@"isReady");
    SEL hasActiveSubscriptionSelector = NSSelectorFromString(@"hasActiveSubscription");
    
    if ([adServiceClass instancesRespondToSelector:isReadySelector]) {
        Method originalMethod = class_getInstanceMethod(adServiceClass, isReadySelector);
        IMP originalIMP = method_getImplementation(originalMethod);
        IMP newIMP = imp_implementationWithBlock(^BOOL(id _self) {
            // Force isReady to always return YES.
            return YES;
        });
        method_setImplementation(originalMethod, newIMP);
        NSLog(@"[Tweak] Hooked -[AdService isReady] to always return YES.");
    }
    
    if ([adServiceClass instancesRespondToSelector:hasActiveSubscriptionSelector]) {
        Method originalMethod = class_getInstanceMethod(adServiceClass, hasActiveSubscriptionSelector);
        IMP originalIMP = method_getImplementation(originalMethod);
        IMP newIMP = imp_implementationWithBlock(^BOOL(id _self) {
            // Force hasActiveSubscription to always return NO, ensuring the app doesn't think the user is a premium subscriber.
            return NO;
        });
        method_setImplementation(originalMethod, newIMP);
        NSLog(@"[Tweak] Hooked -[AdService hasActiveSubscription] to always return NO.");
    }
    
    // Hook the loading methods to force a successful load.
    SEL loadAppOpenAdSelector = NSSelectorFromString(@"loadAppOpenAd");
    SEL loadInterstitialAdSelector = NSSelectorFromString(@"loadInterstitialAd");
    SEL loadRewardAdSelector = NSSelectorFromString(@"loadRewardAd");
    
    NSArray *loadSelectors = @[NSStringFromSelector(loadAppOpenAdSelector),
                               NSStringFromSelector(loadInterstitialAdSelector),
                               NSStringFromSelector(loadRewardAdSelector)];
    
    for (NSString *selName in loadSelectors) {
        SEL selector = NSSelectorFromString(selName);
        if ([adServiceClass instancesRespondToSelector:selector]) {
            Method originalMethod = class_getInstanceMethod(adServiceClass, selector);
            IMP originalIMP = method_getImplementation(originalMethod);
            // We can't easily change the return type or arguments, so we just let it run.
            // The key is that the `isReady` check will now pass, so the app will attempt to show the ad.
            // We could also call the original IMP and then force a callback, but that's more complex.
            // For simplicity, we ensure the readiness check passes.
            NSLog(@"[Tweak] Found loading method: %@", selName);
        }
    }
}

// Hook Google Mobile Ads (GADAdLoader) as a fallback.
static void hookGADAdLoader() {
    Class gadLoaderClass = NSClassFromString(@"GADAdLoader");
    if (gadLoaderClass) {
        SEL isLoadingSelector = NSSelectorFromString(@"isLoading");
        if ([gadLoaderClass instancesRespondToSelector:isLoadingSelector]) {
            Method originalMethod = class_getInstanceMethod(gadLoaderClass, isLoadingSelector);
            IMP newIMP = imp_implementationWithBlock(^BOOL(id _self) {
                return NO; // Force loading to appear finished.
            });
            method_setImplementation(originalMethod, newIMP);
            NSLog(@"[Tweak] Hooked -[GADAdLoader isLoading] to always return NO.");
        }
    }
}

// MARK: - Tweak Constructor

%ctor {
    NSLog(@"[Tweak] Initializing getsmscode tweak...");
    
    // 1. Generate and pin the Dutch IP for this session.
    sessionIP = generateRandomDutchIP();
    NSLog(@"[Tweak] Session IP set to: %@", sessionIP);
    
    // 2. Register the custom NSURLProtocol to inject the IP into all requests.
    [NSURLProtocol registerClass:[DutchIPProtocol class]];
    
    // 3. Perform the deep clean and setup the ideal environment.
    [Cleaner performDeepClean];
    [ConfigManager setupIdealEnvironment];
    
    // 4. Hook the ad service and ad loader classes.
    // We perform this after a short delay to ensure all classes are loaded.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        hookAdService();
        hookGADAdLoader();
        NSLog(@"[Tweak] Ad hooking completed.");
    });
}
