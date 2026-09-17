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

// 1. IP واقعي وثابت للجلسة
static NSString *getSessionIP() {
    static NSString *sharedIP = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        sharedIP = [NSString stringWithFormat:@"82.92.%d.%d", arc4random_uniform(250) + 1, arc4random_uniform(250) + 1];
    });
    return sharedIP;
}

// 2. معرفات مختلفة وواقعية وثابتة للجلسة
static NSString *getSessionIDFA() {
    static NSString *val = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{ val = [[NSUUID UUID] UUIDString]; });
    return val;
}

static NSString *getSessionIDFV() {
    static NSString *val = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{ val = [[NSUUID UUID] UUIDString]; });
    return val;
}

static NSString *getSessionGoogleID() {
    static NSString *val = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{ val = [[NSUUID UUID] UUIDString]; });
    return val;
}

static NSString *getSessionAppsFlyerID() {
    static NSString *val = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        long long timestampMillis = (long long)([[NSDate date] timeIntervalSince1970] * 1000) - (arc4random_uniform(10000000) + 500000);
        val = [NSString stringWithFormat:@"%lld-%u", timestampMillis, arc4random_uniform(900000000) + 100000000];
    });
    return val;
}

static NSString *getSessionFirebaseID() {
    static NSString *val = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        val = [[[NSUUID UUID] UUIDString] stringByReplacingOccurrencesOfString:@"-" withString:@""];
    });
    return val;
}

// 3. تاريخ تثبيت واقعي (أقدم بيومين إلى 10 أيام من وقت التشغيل الحالي)
static NSString *getSessionInstallDate() {
    static NSString *val = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        NSTimeInterval randomPastTime = (double)(arc4random_uniform(691200) + 172800);
        NSDate *installDate = [NSDate dateWithTimeIntervalSinceNow:-randomPastTime];
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'+0300'"];
        val = [formatter stringFromDate:installDate];
    });
    return val;
}

// 4. أوقات خمول واقعية بين يومين إلى 10 أيام (بالثواني)
static double getSessionInactivitySeconds() {
    static double sharedTime = 0.0;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        sharedTime = (double)(arc4random_uniform(691201) + 172800);
    });
    return sharedTime;
}

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
            
            [defaults setObject:getSessionIDFA() forKey:@"device.id.key"];
            [defaults setObject:getSessionGoogleID() forKey:@"com.google.sso.GeneratedDeviceIdentifier"];
            [defaults setObject:getSessionAppsFlyerID() forKey:@"AppsFlyerUserId"];
            [defaults setObject:getSessionFirebaseID() forKey:@"com.firebase.installations.app_id_to_fiid_enforcement"];
            [defaults setObject:getSessionIDFV() forKey:@"com.apple.uikit.customDeviceIdentifier"];
            
            [defaults setInteger:2 forKey:@"ATT_Tracking_Status"];
            [defaults setInteger:0 forKey:@"ump_status"];
            [defaults setInteger:0 forKey:@"IABTCF_gdprApplies"];
            
            // جعل العدادات أصفاراً تماماً بناءً على طلبك
            [defaults setInteger:0 forKey:@"AppsFlyerRealLaunchCounter"];
            [defaults setInteger:0 forKey:@"AppsFlyerReinstallCounter"];
            [defaults setInteger:0 forKey:@"AppsFlyerLaunchKey"];
            [defaults setInteger:0 forKey:@"AppsFlyerCounter"];
            
            NSString *installDateStr = getSessionInstallDate();
            [defaults setObject:installDateStr forKey:@"AppsFlyerInstallDate"];
            [defaults setObject:installDateStr forKey:@"AppsFlyerFirstLaunchDate"];
            [defaults setObject:installDateStr forKey:@"AppsFlyerInstallTimestamp"];
            
            double dynamicInactivityTime = getSessionInactivitySeconds();
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
    return [[NSUUID alloc] initWithUUIDString:getSessionIDFV()];
}
%end

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return [[NSUUID alloc] initWithUUIDString:getSessionIDFA()];
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
    if ([field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame ||
        [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame ||
        [field caseInsensitiveCompare:@"True-Client-IP"] == NSOrderedSame ||
        [field caseInsensitiveCompare:@"X-Real-IP"] == NSOrderedSame) {
        value = getSessionIP();
    }
    %orig(value, field);
}

- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame ||
        [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame ||
        [field caseInsensitiveCompare:@"True-Client-IP"] == NSOrderedSame ||
        [field caseInsensitiveCompare:@"X-Real-IP"] == NSOrderedSame) {
        value = getSessionIP();
    }
    %orig(value, field);
}
%end

%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    if (mutableReq) {
        [mutableReq setValue:getSessionIP() forHTTPHeaderField:@"X-Forwarded-For"];
        [mutableReq setValue:getSessionIP() forHTTPHeaderField:@"Client-IP"];
        [mutableReq setValue:getSessionIP() forHTTPHeaderField:@"X-Real-IP"];
        request = mutableReq;
    }
    return %orig(request, completionHandler);
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    if (mutableReq) {
        [mutableReq setValue:getSessionIP() forHTTPHeaderField:@"X-Forwarded-For"];
        [mutableReq setValue:getSessionIP() forHTTPHeaderField:@"Client-IP"];
        [mutableReq setValue:getSessionIP() forHTTPHeaderField:@"X-Real-IP"];
        request = mutableReq;
    }
    return %orig(request);
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
