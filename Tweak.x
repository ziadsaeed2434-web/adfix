#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <objc/runtime.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>

@interface ActivatorAdService : NSObject
- (void)loadAd;
- (BOOL)isReady;
- (BOOL)isAdReady;
- (BOOL)canShowAd;
- (BOOL)hasAdLoaded;
- (void)showRewardAd;
- (void)presentAdFromViewController:(UIViewController *)viewController;
@end

static void eliteLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@">>> [AGGRESSIVE-DUTCH-ENGINE] %@", message);
}

static void clearKeychainExceptToken() {
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
                
                if (![account isEqualToString:@"tokenKey"]) {
                    NSMutableDictionary *delQuery = [NSMutableDictionary dictionaryWithDictionary:item];
                    delQuery[(__bridge id)kSecClass] = secClass;
                    SecItemDelete((__bridge CFDictionaryRef)delQuery);
                }
            }
            if (result) {
                CFRelease(result);
            }
        }
    }
}

static NSString *randomEliteDutchIP() {
    NSArray *dutchSubnets = @[@"213.10.", @"84.241.", @"94.212.", @"145.220.", @"185.189."];
    NSString *subnet = dutchSubnets[arc4random_uniform((uint32_t)[dutchSubnets count])];
    return [NSString stringWithFormat:@"%@%d.%d", subnet, arc4random_uniform(200) + 1, arc4random_uniform(200) + 1];
}

static NSString *randomNewIDFA() {
    return [[NSUUID UUID] UUIDString];
}

static __attribute__((constructor)) void initializeAggressiveEnvironment() {
    @autoreleasepool {
        clearKeychainExceptToken();

        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleId) {
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleId];
        }

        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        [[NSURLCache sharedURLCache] setDiskCapacity:0];
        [[NSURLCache sharedURLCache] setMemoryCapacity:0];

        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *home = NSHomeDirectory();
        NSArray *dirs = @[@"Documents", @"Library/Caches", @"Library/Preferences", @"tmp"];
        for (NSString *dir in dirs) {
            NSString *fullPath = [home stringByAppendingPathComponent:dir];
            NSArray *contents = [fm contentsOfDirectoryAtPath:fullPath error:nil];
            for (NSString *file in contents) {
                if (![file containsString:@"token"] && ![file containsString:@"Auth"]) {
                    [fm removeItemAtPath:[fullPath stringByAppendingPathComponent:file] error:nil];
                }
            }
        }

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *freshID = randomNewIDFA();
        
        [defaults setObject:freshID forKey:@"device.id.key"];
        [defaults setObject:freshID forKey:@"com.google.sso.GeneratedDeviceIdentifier"];
        [defaults setObject:freshID forKey:@"AppsFlyerUserId"];
        [defaults setInteger:3 forKey:@"ATT_Tracking_Status"];
        [defaults setInteger:1 forKey:@"ump_status"];
        [defaults setInteger:1 forKey:@"IABTCF_gdprApplies"];
        [defaults setObject:@"1" forKey:@"IABTCF_ConsentString"];
        [defaults setObject:@[@"nl-NL", @"en-US"] forKey:@"AppleLanguages"];
        [defaults setObject:@"NL" forKey:@"AppleLocale"];
        [defaults synchronize];
        
        eliteLog(@"Aggressive Dutch environment initialized successfully.");
    }
}

%hook ATTrackingManager
+ (NSUInteger)trackingAuthorizationStatus { return 3; }
%end

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier { return [NSUUID UUID]; }
- (BOOL)isAdvertisingTrackingEnabled { return YES; }
%end

%hook NSLocale
- (NSString *)countryCode { return @"NL"; }
- (NSString *)localeIdentifier { return @"nl_NL"; }
%end

%hook NSTimeZone
+ (NSTimeZone *)localTimeZone { return [NSTimeZone timeZoneWithName:@"Europe/Amsterdam"]; }
- (NSString *)name { return @"Europe/Amsterdam"; }
%end

%hook CTCarrier
- (NSString *)mobileCountryCode { return @"204"; }
- (NSString *)mobileNetworkCode { return @"08"; }
- (NSString *)isoCountryCode { return @"nl"; }
%end

%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    NSString *dutchIP = randomEliteDutchIP();
    if ([field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame ||
        [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame ||
        [field caseInsensitiveCompare:@"True-Client-IP"] == NSOrderedSame) {
        value = dutchIP;
    }
    %orig(value, field);
}

- (instancetype)initWithURL:(NSURL *)URL {
    self = %orig;
    if (self) {
        NSString *dutchIP = randomEliteDutchIP();
        [self setValue:dutchIP forHTTPHeaderField:@"X-Forwarded-For"];
        [self setValue:dutchIP forHTTPHeaderField:@"Client-IP"];
        [self setValue:@"nl-NL,nl;q=0.9,en-US;q=0.8" forHTTPHeaderField:@"Accept-Language"];
    }
    return self;
}
%end

%hook ActivatorAdService

- (BOOL)isReady { return YES; }
- (BOOL)isAdReady { return YES; }
- (BOOL)canShowAd { return YES; }
- (BOOL)hasAdLoaded { return YES; }

- (void)loadAd {
    %orig;
    eliteLog(@"loadAd triggered. Starting continuous aggressive fetch loop until ad is ready...");
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        while (weakSelf) {
            BOOL ready = NO;
            if ([weakSelf respondsToSelector:@selector(isReady)]) {
                ready = [weakSelf isReady];
            }
            if (!ready && [weakSelf respondsToSelector:@selector(isAdReady)]) {
                ready = [weakSelf isAdReady];
            }
            if (!ready && [weakSelf respondsToSelector:@selector(hasAdLoaded)]) {
                ready = [weakSelf hasAdLoaded];
            }
            
            if (ready) {
                eliteLog(@"Success! Ad is fully loaded and ready to display.");
                break;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (weakSelf && [weakSelf respondsToSelector:@selector(loadAd)]) {
                    eliteLog(@"Ad not ready yet. Re-issuing loadAd command...");
                    [weakSelf loadAd];
                }
            });
            
            [NSThread sleepForTimeInterval:0.6];
        }
    });
}

- (void)showRewardAd {
    @try {
        %orig;
        eliteLog(@"Reward ad shown. Re-initiating aggressive fetch loop for the next ad.");
        [self loadAd];
    } @catch (NSException *e) {
        eliteLog(@"Error in showRewardAd: %@", e.reason);
    }
}

- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    eliteLog(@"Ad failed to present. Forcing aggressive re-fetch immediately.");
    [self loadAd];
}

%end
