// Tweak.x

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonCrypto.h>

// MARK: - Helper Functions

static NSString *generateRandomDutchIP() {
    uint32_t randomPart1 = arc4random_uniform(256);
    uint32_t randomPart2 = arc4random_uniform(256);
    return [NSString stringWithFormat:@"84.241.%u.%u", randomPart1, randomPart2];
}

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
        if ([item isEqualToString:@"Preferences"]) {
            continue;
        }
        NSString *fullPath = [libraryPath stringByAppendingPathComponent:item];
        [fileManager removeItemAtPath:fullPath error:&error];
        if (error) {
            NSLog(@"[Tweak] Failed to remove item at %@: %@", fullPath, error);
        }
    }

    NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cachePath = [cachePaths firstObject];
    NSArray *cacheContents = [fileManager contentsOfDirectoryAtPath:cachePath error:&error];
    for (NSString *item in cacheContents) {
        NSString *fullPath = [cachePath stringByAppendingPathComponent:item];
        [fileManager removeItemAtPath:fullPath error:&error];
    }

    // 3. Targeted Keychain Cleanup
    NSMutableDictionary *allQuery = [@{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecReturnAttributes: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitAll
    } mutableCopy];
    
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

@interface DutchIPProtocol : NSURLProtocol <NSURLSessionDataDelegate>
@end

@implementation DutchIPProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
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
    
    if (sessionIP) {
        [newRequest setValue:sessionIP forHTTPHeaderField:@"X-Forwarded-For"];
        [newRequest setValue:sessionIP forHTTPHeaderField:@"X-Real-IP"];
    }
    
    [NSURLProtocol setProperty:@YES forKey:@"DutchIPHandled" inRequest:newRequest];
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:newRequest];
    [task resume];
}

- (void)stopLoading {
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
    
    NSString *currentDateString = [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]];
    [defaults setObject:currentDateString forKey:@"AppsFlyerInstallDate"];
    [defaults setObject:currentDateString forKey:@"AppsFlyerInitDate"];
    [defaults setObject:currentDateString forKey:@"AppsFlyerFirstLaunchDate"];
    [defaults setObject:currentDateString forKey:@"AppsFlyerDate3"];
    [defaults setObject:@(1) forKey:@"AppsFlyerCounter"];
    [defaults setObject:@(0) forKey:@"AppsFlyerReinstallCounter"];
    [defaults setObject:@(1) forKey:@"AppsFlyerLaunchKey"];
    [defaults setObject:@(1) forKey:@"AppsFlyerReadyToSendEvents"];
    
    [defaults setObject:@"1" forKey:@"IABTCF_gdprApplies"];
    [defaults setObject:@"11111111111" forKey:@"IABTCF_PurposeConsents"];
    [defaults setObject:@"01000011111" forKey:@"IABTCF_PurposeLegitimateInterests"];
    [defaults setObject:@"10000000011110110000100000000000000000000000000001" forKey:@"IABTCF_VendorConsents"];
    [defaults setObject:@"10000000011110110000100000000000000000000000000001" forKey:@"IABTCF_VendorLegitimateInterests"];
    [defaults setObject:@"1" forKey:@"IABTCF_SpecialFeaturesOptIns"];
    [defaults setObject:@"CY" forKey:@"IABTCF_PublisherCC"];
    [defaults setObject:@"0" forKey:@"IABTCF_PurposeOneTreatment"];
    [defaults setObject:@"0" forKey:@"IABTCF_UseNonStandardStacks"];
    [defaults setObject:@"300" forKey:@"IABTCF_CmpSdkID"];
    [defaults setObject:@"2" forKey:@"IABTCF_CmpSdkVersion"];
    [defaults setObject:@"5" forKey:@"IABTCF_PolicyVersion"];
    [defaults setObject:@"3" forKey:@"ump_status"];
    [defaults setObject:@"2" forKey:@"ump_rq_st"];
    [defaults setObject:@"1" forKey:@"ump_pors"];
    [defaults setObject:@"4444" forKey:@"UMP_consentModeValues"];
    
    [defaults setBool:NO forKey:@"em_lockdownModeEnabled"];
    [defaults setBool:NO forKey:@"hk_hfeModeEnabled"];
    
    [defaults synchronize];
    NSLog(@"[Tweak] Ideal environment configured in NSUserDefaults.");
}

@end

// MARK: - Ad-State Override Module

static void hookAdService() {
    Class adServiceClass = NSClassFromString(@"Activator.AdService");
    if (!adServiceClass) {
        adServiceClass = NSClassFromString(@"AdService");
    }
    if (!adServiceClass) {
        NSLog(@"[Tweak] Could not find AdService class to hook.");
        return;
    }
    
    SEL isReadySelector = NSSelectorFromString(@"isReady");
    SEL hasActiveSubscriptionSelector = NSSelectorFromString(@"hasActiveSubscription");
    
    if ([adServiceClass instancesRespondToSelector:isReadySelector]) {
        Method originalMethod = class_getInstanceMethod(adServiceClass, isReadySelector);
        IMP newIMP = imp_implementationWithBlock(^BOOL(id _self) {
            return YES;
        });
        method_setImplementation(originalMethod, newIMP);
        NSLog(@"[Tweak] Hooked -[AdService isReady] to always return YES.");
    }
    
    if ([adServiceClass instancesRespondToSelector:hasActiveSubscriptionSelector]) {
        Method originalMethod = class_getInstanceMethod(adServiceClass, hasActiveSubscriptionSelector);
        IMP newIMP = imp_implementationWithBlock(^BOOL(id _self) {
            return NO;
        });
        method_setImplementation(originalMethod, newIMP);
        NSLog(@"[Tweak] Hooked -[AdService hasActiveSubscription] to always return NO.");
    }
    
    SEL loadAppOpenAdSelector = NSSelectorFromString(@"loadAppOpenAd");
    SEL loadInterstitialAdSelector = NSSelectorFromString(@"loadInterstitialAd");
    SEL loadRewardAdSelector = NSSelectorFromString(@"loadRewardAd");
    
    NSArray *loadSelectors = @[NSStringFromSelector(loadAppOpenAdSelector),
                               NSStringFromSelector(loadInterstitialAdSelector),
                               NSStringFromSelector(loadRewardAdSelector)];
    
    for (NSString *selName in loadSelectors) {
        SEL selector = NSSelectorFromString(selName);
        if ([adServiceClass instancesRespondToSelector:selector]) {
            NSLog(@"[Tweak] Found loading method: %@", selName);
        }
    }
}

static void hookGADAdLoader() {
    Class gadLoaderClass = NSClassFromString(@"GADAdLoader");
    if (gadLoaderClass) {
        SEL isLoadingSelector = NSSelectorFromString(@"isLoading");
        if ([gadLoaderClass instancesRespondToSelector:isLoadingSelector]) {
            Method originalMethod = class_getInstanceMethod(gadLoaderClass, isLoadingSelector);
            IMP newIMP = imp_implementationWithBlock(^BOOL(id _self) {
                return NO;
            });
            method_setImplementation(originalMethod, newIMP);
            NSLog(@"[Tweak] Hooked -[GADAdLoader isLoading] to always return NO.");
        }
    }
}

// MARK: - Tweak Constructor

%ctor {
    NSLog(@"[Tweak] Initializing getsmscode tweak...");
    
    sessionIP = generateRandomDutchIP();
    NSLog(@"[Tweak] Session IP set to: %@", sessionIP);
    
    [NSURLProtocol registerClass:[DutchIPProtocol class]];
    
    [Cleaner performDeepClean];
    [ConfigManager setupIdealEnvironment];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        hookAdService();
        hookGADAdLoader();
        NSLog(@"[Tweak] Ad hooking completed.");
    });
}
