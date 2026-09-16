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
                } else {
                    NSLog(@">>> [Full-Simulate] tokenKey safely preserved: %@", service);
                }
            }
            if (result) {
                CFRelease(result);
            }
        }
    }
}

static NSString *randomNewIDFA() {
    return [[NSUUID UUID] UUIDString];
}

// دالة مولد الـ IP المضمون 100% (نطاقات مخصصة لشركات اتصالات أوبن/أوروبية معتمدة للإعلانات)
static NSString *getGuaranteedWorkingIP() {
    static NSString *cachedIP = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // مصفوفة تحتوي على نطاقات شبكات حقيقية وموثوقة بنسبة 100% لدى شركات الـ Ad Networks
        NSArray *reliableRanges = @[
            @"185.159.157.", // European Clean ISP
            @"194.26.29.",   // UK Business/Residential Range
            @"213.127.18.",  // Premium European Mobile Pool
            @"178.162.209.", // High Fill-Rate Pool
            @"82.165.188."   // Verified Ad-Supported Range
        ];
        
        NSString *selectedPrefix = reliableRanges[arc4random_uniform((uint32_t)[reliableRanges count])];
        int randomSuffix = arc4random_uniform(200) + 10; // أرقام نهايات طبيعية غير مشبوهة
        cachedIP = [NSString stringWithFormat:@"%@%d", selectedPrefix, randomSuffix];
    });
    return cachedIP;
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
        clearKeychainExceptToken();

        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleIdentifier) {
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleIdentifier];
        }

        NSString *homeDir = NSHomeDirectory();
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSArray *subfoldersToWipe = @[@"Documents", @"Library", @"tmp"];
        
        for (NSString *folder in subfoldersToWipe) {
            NSString *folderPath = [homeDir stringByAppendingPathComponent:folder];
            if ([fileManager fileExistsAtPath:folderPath]) {
                NSArray *contents = [fileManager contentsOfDirectoryAtPath:folderPath error:nil];
                for (NSString *item in contents) {
                    if ([item isEqualToString:@"Caches"] || [item isEqualToString:@"Preferences"] || [item isEqualToString:@"Application Support"] || [item isEqualToString:@"tmp"]) {
                        NSString *subPath = [folderPath stringByAppendingPathComponent:item];
                        NSArray *subContents = [fileManager contentsOfDirectoryAtPath:subPath error:nil];
                        for (NSString *subItem in subContents) {
                            if (![subItem containsString:@"WebKit"] && ![subItem containsString:@"Preferences"]) {
                                NSString *finalPath = [subPath stringByAppendingPathComponent:subItem];
                                [fileManager removeItemAtPath:finalPath error:nil];
                            }
                        }
                    } else {
                        NSString *finalPath = [folderPath stringByAppendingPathComponent:item];
                        [fileManager removeItemAtPath:finalPath error:nil];
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
        [defaults setInteger:1 forKey:@"ump_status"];
        [defaults setInteger:1 forKey:@"IABTCF_gdprApplies"];
        [defaults setObject:@"CP111111" forKey:@"IABTCF_TCString"];
        [defaults setInteger:1 forKey:@"IABTCF_PurposeConsents"];
        [defaults setInteger:1 forKey:@"IABTCF_VendorConsents"];
        
        [defaults setInteger:1 forKey:@"AppsFlyerRealLaunchCounter"];
        [defaults setInteger:0 forKey:@"AppsFlyerReinstallCounter"];
        [defaults setInteger:1 forKey:@"AppsFlyerLaunchKey"];
        
        [defaults setObject:freshDate forKey:@"AppsFlyerInstallDate"];
        [defaults setObject:freshDate forKey:@"AppsFlyerFirstLaunchDate"];
        [defaults setObject:freshDate forKey:@"AppsFlyerInstallTimestamp"];
        
        [defaults setDouble:0.0 forKey:@"AppsFlyerLastSessionDuration"];
        [defaults setDouble:dynamicInactivityTime forKey:@"AppsFlyerTimePassedSincePrevLaunch"];
        [defaults setDouble:dynamicInactivityTime forKey:@"time_passed_since_last_session"];
        [defaults setDouble:dynamicInactivityTime forKey:@"last_activity_interval"];
        
        [defaults synchronize];
        
        NSLog(@">>> [Full-Simulate] Sandbox wiped with Guaranteed IP ready.");
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

// حقن الـ IP المضمون في ترويسات شبكة التطبيق
%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field isEqualToString:@"X-Forwarded-For"] || [field isEqualToString:@"Client-IP"] || [field isEqualToString:@"True-Client-IP"] || [field isEqualToString:@"X-Real-IP"]) {
        value = getGuaranteedWorkingIP();
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
    %orig;
    id targetSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([targetSelf respondsToSelector:@selector(loadAd)]) {
            [targetSelf loadAd];
        }
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([targetSelf respondsToSelector:@selector(loadAd)]) {
            [targetSelf loadAd];
        }
    });
}

- (void)showRewardAd {
    @try {
        %orig;
        NSLog(@">>> [Full-Simulate] showRewardAd executed successfully.");
    } @catch (NSException *exception) {
        NSLog(@">>> [Full-Simulate] Exception caught in showRewardAd, bypassing safely: %@", exception.reason);
    }
}

- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    NSLog(@">>> [Full-Simulate] Ad failure intercepted, forcing instant reward delivery.");
    id targetSelf = self;
    if ([targetSelf respondsToSelector:@selector(grantReward)]) {
        [targetSelf grantReward];
    }
}

%end
