#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <objc/runtime.h>
#import <Security/Security.h>
#import <CommonCrypto/CommonDigest.h>

// ============================================================================
// [SECTION 01: MASTER CONFIGURATION & GLOBAL CONSTANTS DEFINITION]
// ============================================================================

static NSString * const kUltimateEngineVersion = @"9.8.4-Enterprise";
static NSString * const kDefaultCountryCode = @"DE"; // ألمانيا (أوروبا)

// ============================================================================
// [SECTION 02: ADVANCED DYNAMIC IDENTITY & GEO-SPOOFING ENGINE]
// ============================================================================

static NSString *master_dyn_IP = nil;
static NSString *master_dyn_IDFV = nil;
static NSString *master_dyn_IDFA = nil;
static NSString *master_dyn_UUID = nil;
static NSString *master_dyn_UA = nil;

static NSArray *getExtendedEuropeanSubnetsList() {
    return @[
        @"82.92", @"85.25", @"185.220", @"193.163", @"91.200", 
        @"46.101", @"178.62", @"159.65", @"51.15", @"163.172", 
        @"80.150", @"217.237", @"194.25", @"84.115", @"62.157",
        @"195.20", @"213.144", @"89.144", @"62.24", @"194.12"
    ];
}

static NSString *generateExtendedRandomEuropeanIP() {
    NSArray *subnets = getExtendedEuropeanSubnetsList();
    NSString *subnet = subnets[arc4random_uniform((uint32_t)[subnets count])];
    int p3 = arc4random_uniform(240) + 10;
    int p4 = arc4random_uniform(240) + 10;
    return [NSString stringWithFormat:@"%@.%d.%d", subnet, p3, p4];
}

static void rotateAllSessionIdentitiesCompletely() {
    master_dyn_IP = generateExtendedRandomEuropeanIP();
    master_dyn_IDFV = [[NSUUID UUID] UUIDString];
    master_dyn_IDFA = [[NSUUID UUID] UUIDString];
    master_dyn_UUID = [[NSUUID UUID] UUIDString];
    
    int safariVersion = arc4random_uniform(5) + 14;
    int buildVersion = arc4random_uniform(500) + 100;
    master_dyn_UA = [NSString stringWithFormat:@"Mozilla/5.0 (iPhone; CPU iPhone OS 17_%d like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 AdEngineCore/%d", safariVersion, buildVersion];
}

static NSString *getActiveSessionIP() {
    if (!master_dyn_IP) { rotateAllSessionIdentitiesCompletely(); }
    return master_dyn_IP;
}

static NSString *getActiveSessionIDFV() {
    if (!master_dyn_IDFV) { rotateAllSessionIdentitiesCompletely(); }
    return master_dyn_IDFV;
}

static NSString *getActiveSessionIDFA() {
    if (!master_dyn_IDFA) { rotateAllSessionIdentitiesCompletely(); }
    return master_dyn_IDFA;
}

static NSString *getActiveSessionUUID() {
    if (!master_dyn_UUID) { rotateAllSessionIdentitiesCompletely(); }
    return master_dyn_UUID;
}

static NSString *getActiveUserAgent() {
    if (!master_dyn_UA) { rotateAllSessionIdentitiesCompletely(); }
    return master_dyn_UA;
}

// ============================================================================
// [SECTION 03: AGGRESSIVE LOCAL PURGE & FRESH RE-INIT ENGINE (1000-LINE DEPTH)]
// ============================================================================

static void performDeepAggressivePurgeAndReinit() {
    @autoreleasepool {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        // 1. الاحتفاظ حصرياً وآمناً بمفاتيح التوكن والمصادقة الخاصة بالحساب فقط
        NSMutableDictionary *preservedAuthTokens = [NSMutableDictionary dictionary];
        NSArray *possibleTokenKeys = @[
            @"tokenKey", @"user_token", @"access_token", @"auth_token", 
            @"session_token", @"userSession", @"jwt", @"account_token", 
            @"userId", @"account_id", @"user_session_id", @"authKey",
            @"user_profile", @"auth_session", @"oauth_token"
        ];
        
        for (NSString *key in possibleTokenKeys) {
            id val = [defaults objectForKey:key];
            if (val) {
                preservedAuthTokens[key] = val;
            }
        }
        
        // 2. تدمير وحذف كافة الإعدادات المحلية والمفاتيح التي قد تسجل "رفض الإعلان" أو "الحد اليومي"
        NSDictionary *dictKeys = [defaults dictionaryRepresentation];
        for (NSString *key in [dictKeys allKeys]) {
            BOOL isToken = NO;
            for (NSString *tKey in possibleTokenKeys) {
                if ([key isEqualToString:tKey]) {
                    isToken = YES;
                    break;
                }
            }
            if (!isToken) {
                [defaults removeObjectForKey:key];
            }
        }
        
        // 3. مسح كاش الشبكة والذاكرة بالكامل وتفريغ الذاكرة المؤقتة
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        [[NSURLCache sharedURLCache] setDiskCapacity:0];
        [[NSURLCache sharedURLCache] setMemoryCapacity:0];
        
        // 4. حذف جميع الملفات المحلية في مجلد Caches و Application Support المرتبطة بسجلات الإعلانات أو الأخطاء
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *cachesDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
        if (cachesDir) {
            NSArray *cachesContents = [fm contentsOfDirectoryAtPath:cachesDir error:nil];
            for (NSString *file in cachesContents) {
                if (![file containsString:@"WebKit"]) {
                    [fm removeItemAtPath:[cachesDir stringByAppendingPathComponent:file] error:nil];
                }
            }
        }
        
        NSString *appSupportDir = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
        if (appSupportDir) {
            NSArray *appSupportContents = [fm contentsOfDirectoryAtPath:appSupportDir error:nil];
            for (NSString *file in appSupportContents) {
                if ([file containsString:@"ad"] || [file containsString:@"cache"] || [file containsString:@"sdk"] || [file containsString:@"stats"] || [file containsString:@"track"] || [file containsString:@"realm"] || [file containsString:@".sqlite"] || [file containsString:@"log"] || [file containsString:@"temp"]) {
                    [fm removeItemAtPath:[appSupportDir stringByAppendingPathComponent:file] error:nil];
                }
            }
        }
        
        NSString *tmpDir = NSTemporaryDirectory();
        if (tmpDir) {
            NSArray *tmpContents = [fm contentsOfDirectoryAtPath:tmpDir error:nil];
            for (NSString *file in tmpContents) {
                [fm removeItemAtPath:[tmpDir stringByAppendingPathComponent:file] error:nil];
            }
        }
        
        // 5. مسح الـ Keychain ما عدا التوكنات الأساسية
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
                    if (account && ([account containsString:@"token"] || [account containsString:@"auth"] || [account containsString:@"session"] || [account containsString:@"user"] || [account containsString:@"key"])) {
                        // الحفاظ الآمن على بيانات الحساب
                    } else {
                        NSMutableDictionary *delQuery = [NSMutableDictionary dictionaryWithDictionary:item];
                        delQuery[(__bridge id)kSecClass] = secClass;
                        SecItemDelete((__bridge CFDictionaryRef)delQuery);
                    }
                }
                if (result) CFRelease(result);
            }
        }
        
        // 6. تدوير وتوليد هويات جديدة بالكامل
        rotateAllSessionIdentitiesCompletely();
        
        // 7. استعادة التوكنات المحفوظة ليبقى الحساب مسجلاً ودون أي انقطاع
        for (NSString *key in [preservedAuthTokens allKeys]) {
            [defaults setObject:preservedAuthTokens[key] forKey:key];
        }
        
        // 8. حقن الهويات الوهمية الجديدة لمنع أي تتبع أو ربط بالحظر القديم
        [defaults setObject:getActiveSessionIDFA() forKey:@"device.id.key"];
        [defaults setObject:getActiveSessionIDFA() forKey:@"com.google.sso.GeneratedDeviceIdentifier"];
        [defaults setObject:getActiveSessionIDFA() forKey:@"AppsFlyerUserId"];
        [defaults setObject:getActiveSessionUUID() forKey:@"install_identifier"];
        [defaults setObject:getActiveSessionUUID() forKey:@"first_launch_uuid"];
        [defaults setObject:kDefaultCountryCode forKey:@"AppleLocale"];
        [defaults setObject:kDefaultCountryCode forKey:@"AppleLanguages"];
        [defaults setInteger:2 forKey:@"ATT_Tracking_Status"];
        [defaults setInteger:0 forKey:@"ump_status"];
        
        [defaults setBool:YES forKey:@"is_first_launch_today"];
        [defaults setDouble:[[NSDate date] timeIntervalSince1970] forKey:@"last_active_timestamp"];
        
        [defaults synchronize];
        
        NSLog(@">>> [Enterprise-1000L-Engine] Full aggressive local purge executed. Fresh environment initialized.");
    }
}

static __attribute__((constructor)) void initEnterpriseEngineConstructor() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        performDeepAggressivePurgeAndReinit();
    });
}

// ============================================================================
// [SECTION 04: SYSTEM SPOOFING HOOKS (ATT, UIDevice, ASIdentifierManager)]
// ============================================================================

%hook ATTrackingManager
+ (NSUInteger)trackingAuthorizationStatus {
    return 2; // Authorized
}
%end

%hook UIDevice
- (NSUUID *)identifierForVendor {
    return [[NSUUID alloc] initWithUUIDString:getActiveSessionIDFV()];
}
- (NSString *)systemVersion {
    return @"17.4.1";
}
- (NSString *)model {
    return @"iPhone";
}
- (NSString *)localizedModel {
    return @"iPhone";
}
%end

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return [[NSUUID alloc] initWithUUIDString:getActiveSessionIDFA()];
}
- (BOOL)isAdvertisingTrackingEnabled {
    return NO;
}
%end

%hook NSLocale
- (NSString *)countryCode {
    return kDefaultCountryCode;
}
- (NSString *)objectForKey:(NSLocaleKey)key {
    if ([key isEqualToString:NSLocaleCountryCode]) {
        return kDefaultCountryCode;
    }
    return %orig(key);
}
%end

// ============================================================================
// [SECTION 05: ADVANCED NETWORK INTERCEPTION & HEADER INJECTION]
// ============================================================================

static void injectEnterprisePayloadHeaders(NSMutableURLRequest *request) {
    if (![request isKindOfClass:[NSMutableURLRequest class]]) return;
    NSString *ip = getActiveSessionIP();
    NSString *ua = getActiveUserAgent();
    
    [request setValue:ip forHTTPHeaderField:@"X-Forwarded-For"];
    [request setValue:ip forHTTPHeaderField:@"Client-IP"];
    [request setValue:ip forHTTPHeaderField:@"True-Client-IP"];
    [request setValue:ip forHTTPHeaderField:@"X-Real-IP"];
    [request setValue:kDefaultCountryCode forHTTPHeaderField:@"CF-IPCountry"];
    [request setValue:kDefaultCountryCode forHTTPHeaderField:@"X-Country-Code"];
    [request setValue:ua forHTTPHeaderField:@"User-Agent"];
}

%hook NSMutableURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame ||
        [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame ||
        [field caseInsensitiveCompare:@"True-Client-IP"] == NSOrderedSame ||
        [field caseInsensitiveCompare:@"X-Real-IP"] == NSOrderedSame) {
        value = getActiveSessionIP();
    }
    if ([field caseInsensitiveCompare:@"User-Agent"] == NSOrderedSame) {
        value = getActiveUserAgent();
    }
    %orig(value, field);
}

- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame ||
        [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame ||
        [field caseInsensitiveCompare:@"True-Client-IP"] == NSOrderedSame ||
        [field caseInsensitiveCompare:@"X-Real-IP"] == NSOrderedSame) {
        value = getActiveSessionIP();
    }
    %orig(value, field);
}

- (void)setAllHTTPHeaderFields:(NSDictionary<NSString *,NSString *> *)headers {
    NSMutableDictionary *mod = [headers mutableCopy];
    if (!mod) mod = [NSMutableDictionary dictionary];
    NSString *ip = getActiveSessionIP();
    mod[@"X-Forwarded-For"] = ip;
    mod[@"Client-IP"] = ip;
    mod[@"True-Client-IP"] = ip;
    mod[@"X-Real-IP"] = ip;
    mod[@"User-Agent"] = getActiveUserAgent();
    %orig(mod);
}

%end

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    injectEnterprisePayloadHeaders(mutableReq);
    return %orig(mutableReq, completionHandler);
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    injectEnterprisePayloadHeaders(mutableReq);
    return %orig(mutableReq);
}

%end

// ============================================================================
// [SECTION 06: COMPREHENSIVE AD-SERVICE & SDK OVERRIDE ENGINE]
// ============================================================================

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // مصفوفة شاملة تغطي كل كلاسات الإعلانات العالمية والمحلية المحتملة
        NSArray *targetAdClasses = @[
            @"Activator.AdService",
            @"AdManager",
            @"RewardAdManager",
            @"AdsController",
            @"GoogleMobileAds",
            @"GADRewardedAd",
            @"GADInterstitialAd",
            @"IronSource",
            @"AppLovinSdk",
            @"UnityAds",
            @"Vungle",
            @"AdMobManager",
            @"AdViewController",
            @"OfferWallManager",
            @"RewardController",
            @"AdsEngine",
            @"AdServiceCenter",
            @"AdNetworkManager",
            @"RewardedInterstitialAd",
            @"FullscreenAdManager"
        ];
        
        for (NSString *className in targetAdClasses) {
            Class targetClass = objc_getClass([className UTF8String]);
            if (targetClass) {
                // فرض الجاهزية المطلقة وإرجاع YES دائماً لكل دوال الفحص والتحقق
                NSArray *selectors = @[
                    @"isReady", @"isAdReady", @"canShowAd", 
                    @"hasAdLoaded", @"isAvailable", @"checkAdStatus", 
                    @"isRewarded", @"isLoaded", @"isAdAvailable",
                    @"isLoadedSuccessfully", @"isEligibleForReward"
                ];
                
                for (NSString *selName in selectors) {
                    SEL sel = sel_registerName([selName UTF8String]);
                    Method method = class_getInstanceMethod(targetClass, sel);
                    if (method) {
                        method_setImplementation(method, imp_implementationWithBlock(^BOOL(id self) {
                            return YES;
                        }));
                    }
                }
                
                NSLog(@TYPE_LOG(@">>> [Enterprise-1000L-Engine] Overrode selectors for ad class: %@"), className);
            }
        }
        
        NSLog(@">>> [Enterprise-1000L-Engine] Architecture fully loaded. Ready for endless ad streaming.");
    });
}
