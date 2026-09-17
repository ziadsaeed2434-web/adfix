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
- (void)grantReward;
@end

static void clearKeychainExceptToken() {
    @try {
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
    } @catch (NSException *exception) {}
}

static NSString *randomNewIDFA() {
    return [[NSUUID UUID] UUIDString];
}

static NSString *randomEuropeanIP() {
    return [NSString stringWithFormat:@"82.92.%d.%d", arc4random_uniform(250) + 1, arc4random_uniform(250) + 1];
}

static double randomInactivitySeconds() {
    return (double)(864000 + arc4random_uniform(4320000));
}

static NSString *generateFreshTimestamp() {
    NSDate *now = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'+0300'"];
    return [formatter stringFromDate:now];
}

static __attribute__((constructor)) void simulateFreshAppReinstallation() {
    @autoreleasepool {
        @try {
            clearKeychainExceptToken();

            NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
            if (bundleIdentifier) {
                [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleIdentifier];
            }

            NSString *homeDir = NSHomeDirectory();
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSArray *subfoldersToWipe = @[@"Documents", @"Library", @"tmp", @"SystemData"];
            
            for (NSString *folder in subfoldersToWipe) {
                NSString *folderPath = [homeDir stringByAppendingPathComponent:folder];
                if ([fileManager fileExistsAtPath:folderPath]) {
                    NSError *error = nil;
                    NSArray *contents = [fileManager contentsOfDirectoryAtPath:folderPath error:&error];
                    if (!error && contents) {
                        for (NSString *item in contents) {
                            @try {
                                NSString *finalPath = [folderPath stringByAppendingPathComponent:item];
                                [fileManager removeItemAtPath:finalPath error:nil];
                            } @catch (NSException *innerEx) {}
                        }
                    }
                }
            }
            
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSString *freshID = randomNewIDFA();
            NSString *freshDate = generateFreshTimestamp();
            double dynamicInactivityTime = randomInactivitySeconds();
            
            [defaults setObject:freshID forKey:@"device.id.key"];
            [defaults setObject:freshID forKey:@"com.google.sso.GeneratedDeviceIdentifier"];
            [defaults setObject:freshID forKey:@"AppsFlyerUserId"];
            [defaults setObject:freshID forKey:@"com.firebase.installations.app_id_to_fiid_enforcement"];
            
            [defaults setInteger:2 forKey:@"ATT_Tracking_Status"];
            [defaults setInteger:0 forKey:@"ump_status"];
            [defaults setInteger:0 forKey:@"IABTCF_gdprApplies"];
            
            [defaults setInteger:1 forKey:@"AppsFlyerRealLaunchCounter"];
            [defaults setInteger:0 forKey:@"AppsFlyerReinstallCounter"];
            [defaults setInteger:1 forKey:@"AppsFlyerLaunchKey"];
            [defaults setInteger:0 forKey:@"AppsFlyerCounter"];
            
            [defaults setObject:freshDate forKey:@"AppsFlyerInstallDate"];
            [defaults setObject:freshDate forKey:@"AppsFlyerFirstLaunchDate"];
            [defaults setObject:freshDate forKey:@"AppsFlyerInstallTimestamp"];
            
            [defaults setDouble:0.0 forKey:@"AppsFlyerLastSessionDuration"];
            [defaults setDouble:dynamicInactivityTime forKey:@"AppsFlyerTimePassedSincePrevLaunch"];
            [defaults setDouble:dynamicInactivityTime forKey:@"time_passed_since_last_session"];
            [defaults setDouble:dynamicInactivityTime forKey:@"last_activity_interval"];
            
            [defaults synchronize];
        } @catch (NSException *exception) {}
    }
}

%hook ATTrackingManager
+ (NSUInteger)trackingAuthorizationStatus {
    return 2;
}
%end

%hook UIDevice
- (NSUUID *)identifierForVendor {
    return [NSUUID UUID];
}
%end

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return [NSUUID UUID];
}
- (BOOL)isAdvertisingTrackingEnabled {
    return NO;
}
%end

%hook NSURLRequest
+ (instancetype)requestWithURL:(NSURL *)URL {
    NSString *urlString = [URL absoluteString];
    if ([urlString containsString:@"googleads.g.doubleclick.net/mads/gma"]) {
        if (![urlString containsString:@"custom_retry="]) {
            NSString *separator = [urlString containsString:@"?"] ? @"&" : @"?";
            NSString *modifiedString = [NSString stringWithFormat:@"%@%@custom_retry=%d", urlString, separator, arc4random_uniform(999999)];
            URL = [NSURL URLWithString:modifiedString];
        }
    } else if ([urlString containsString:@"app-analytics-services.com/config/app"]) {
        if (![urlString containsString:@"rnd="]) {
            NSString *separator = [urlString containsString:@"?"] ? @"&" : @"?";
            NSString *modifiedString = [NSString stringWithFormat:@"%@%@rnd=%d", urlString, separator, arc4random_uniform(999999)];
            URL = [NSURL URLWithString:modifiedString];
        }
    }
    return %orig(URL);
}
%end

%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field isEqualToString:@"X-Forwarded-For"] || [field isEqualToString:@"Client-IP"] || [field isEqualToString:@"True-Client-IP"]) {
        value = randomEuropeanIP();
    }
    %orig(value, field);
}
%end

%hook ActivatorAdService

- (BOOL)isReady {
    return YES;
}

- (BOOL)isAdReady {
    return YES;
}

- (BOOL)canShowAd {
    return YES;
}

- (BOOL)hasAdLoaded {
    return YES;
}

- (void)loadAd {
    @try {
        %orig;
    } @catch (NSException *exception) {}
}

- (void)showRewardAd {
    @try {
        %orig;
    } @catch (NSException *exception) {
        @try {
            if ([self respondsToSelector:@selector(grantReward)]) {
                [self grantReward];
            }
        } @catch (NSException *ex) {}
    }
}

- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    @try {
        if ([self respondsToSelector:@selector(grantReward)]) {
            [self grantReward];
        }
    } @catch (NSException *exception) {}
}

- (instancetype)init {
    id targetSelf = %orig;
    @try {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @try {
                if ([targetSelf respondsToSelector:@selector(loadAd)]) {
                    [targetSelf loadAd];
                }
            } @catch (NSException *e) {}
        });
    } @catch (NSException *e) {}
    return targetSelf;
}

%end
