#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <objc/runtime.h>

// إعلان مسبق شامل لكل الدوال المحتملة لمدير الإعلانات
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

// 1. تنظيف الـ Keychain مع الحفاظ التام والآمن حصرياً على الـ tokenKey
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
                    NSLog(@">>> [iPhone15PM-26.6.1] tokenKey safely preserved: %@", service);
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

// 2. محاكاة حذف التطبيق من الجذور وتثبيته من جديد + منع التتبع قسرياً مع كل إقلاع
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
        [defaults setInteger:0 forKey:@"ump_status"];
        [defaults setInteger:0 forKey:@"IABTCF_gdprApplies"];
        
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
        
        NSLog(@">>> [iPhone15PM-26.6.1] Sandbox wiped & simulated successfully.");
    }
}

// 3. خداع الجهاز ليصبح آيفون 15 برو ماكس وإصدار النظام 26.6.1
%hook UIDevice
- (NSString *)systemVersion {
    return @"26.6.1";
}
- (NSString *)model {
    return @"iPhone";
}
- (NSString *)localizedModel {
    return @"iPhone";
}
- (NSString *)systemName {
    return @"iOS";
}
- (NSUUID *)identifierForVendor {
    return [NSUUID UUID];
}
%end

// خداع قيم النظام وطراز الجهاز عبر الـ sysctl إذا طلبتها بعض المكتبات الداخلية
%hook NSObject

- (NSString *)machine {
    return @"iPhone16,2"; // كود طراز آيفون 15 برو ماكس
}

%end

// تزوير الـ User-Agent و الهيدرز في كل طلب شبكة ليمثل آيفون 15 برو ماكس بنظام 26.6.1
%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field isEqualToString:@"X-Forwarded-For"] || [field isEqualToString:@"Client-IP"] || [field isEqualToString:@"True-Client-IP"]) {
        value = randomEuropeanIP();
    }
    if ([field isEqualToString:@"User-Agent"]) {
        value = @"Mozilla/5.0 (iPhone16,2; CPU iPhone OS 26_6_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148";
    }
    %orig(value, field);
}
%end

%hook ATTrackingManager
+ (NSUInteger)trackingAuthorizationStatus {
    return 2; // Denied
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

// --- التحصين المطلق لمدير الإعلانات ومنع أي فشل نهائياً ---
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([targetSelf respondsToSelector:@selector(loadAd)]) {
            [targetSelf loadAd];
        }
    });
}

- (void)showRewardAd {
    @try {
        %orig;
        NSLog(@">>> [iPhone15PM-26.6.1] showRewardAd executed successfully.");
    } @catch (NSException *exception) {
        NSLog(@">>> [iPhone15PM-26.6.1] Exception caught in showRewardAd, bypassing safely: %@", exception.reason);
    }
}

- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    NSLog(@">>> [iPhone15PM-26.6.1] Ad failure intercepted, forcing instant reward delivery.");
    id targetSelf = self;
    if ([targetSelf respondsToSelector:@selector(grantReward)]) {
        [targetSelf grantReward];
    }
}

%end
