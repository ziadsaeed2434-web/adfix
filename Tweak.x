#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <objc/runtime.h>
#import <netdb.h>
#import <arpa/inet.h>

// إعلان مسبق شامل لكل الدوال المحتملة لمدير الإعلانات
@interface ActivatorAdService : NSObject
- (void)loadAd;
- (BOOL)isReady;
- (BOOL)isAdReady;
- (BOOL)canShowAd;
- (BOOL)hasAdLoaded;
- (void)showRewardAd;
- (void)presentAdFromViewController:(UIViewController *)viewController;
@end

// 1. تنظيف الـ Keychain تماماً مع الحفاظ حصرياً على الـ tokenKey
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
                    NSLog(@">>> [Every-Launch-Wipe] tokenKey safely preserved: %@", service);
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

// دالة لتوليد رقم IMEI وهمي جديد
static NSString *randomIMEI() {
    int r1 = 10 + arc4random_uniform(89);
    long long r2 = 10000000000LL + (long long)(arc4random_uniform(900000000));
    return [NSString stringWithFormat:@"%d%lld", r1, r2];
}

// سيرفرات DNS حقيقية تابعة لشركة Spectrum
static NSString *randomSpectrumDNS() {
    NSArray *spectrumDNSList = @[
        @"71.252.0.12",
        @"71.243.0.12",
        @"209.18.47.61",
        @"209.18.47.62"
    ];
    int index = arc4random_uniform((uint32_t)[spectrumDNSList count]);
    return spectrumDNSList[index];
}

// توليد IP أمريكي حقيقي من نطاقات Spectrum
static NSString *randomSpectrumIP() {
    NSArray *spectrumSubnets = @[
        @"24.24",      
        @"24.160",     
        @"65.24",      
        @"66.192",     
        @"67.240",     
        @"68.172",     
        @"71.64",      
        @"75.128",     
        @"97.100"      
    ];
    NSString *subnet = spectrumSubnets[arc4random_uniform((uint32_t)[spectrumSubnets count])];
    return [NSString stringWithFormat:@"%@.%d.%d", subnet, arc4random_uniform(250) + 1, arc4random_uniform(250) + 1];
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

// 2. التنفيذ في كل إقلاع للتطبيق
static __attribute__((constructor)) void wipeAndSpawnFreshEnvironmentOnEveryLaunch() {
    @autoreleasepool {
        clearKeychainExceptToken();

        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleIdentifier) {
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleIdentifier];
        }

        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        [[NSURLCache sharedURLCache] setDiskCapacity:0];
        [[NSURLCache sharedURLCache] setMemoryCapacity:0];

        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        NSString *homeDir = NSHomeDirectory();
        NSError *error = nil;
        NSArray *homeContents = [fileManager contentsOfDirectoryAtPath:homeDir error:&error];
        for (NSString *item in homeContents) {
            NSString *fullPath = [homeDir stringByAppendingPathComponent:item];
            [fileManager removeItemAtPath:fullPath error:&error];
        }
        
        NSString *groupDirBase = [[[homeDir stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Group Containers"];
        if ([fileManager fileExistsAtPath:groupDirBase]) {
            NSArray *groupFolders = [fileManager contentsOfDirectoryAtPath:groupDirBase error:nil];
            for (NSString *groupFolder in groupFolders) {
                NSString *groupPath = [groupDirBase stringByAppendingPathComponent:groupFolder];
                [fileManager removeItemAtPath:groupPath error:nil];
            }
        }

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *freshID = randomNewIDFA();
        NSString *freshIMEI = randomIMEI();
        NSString *selectedDNS = randomSpectrumDNS();
        NSString *selectedIP = randomSpectrumIP();
        NSString *freshDate = generateFreshTimestamp();
        double dynamicInactivityTime = randomInactivitySeconds();
        
        [defaults setObject:freshID forKey:@"device.id.key"];
        [defaults setObject:freshID forKey:@"com.google.sso.GeneratedDeviceIdentifier"];
        [defaults setObject:freshID forKey:@"AppsFlyerUserId"];
        [defaults setObject:freshID forKey:@"com.firebase.installations.app_id_to_fiid_enforcement"];
        
        [defaults setObject:freshIMEI forKey:@"device_imei"];
        [defaults setObject:freshIMEI forKey:@"imei"];
        [defaults setObject:freshIMEI forKey:@"hardware_imei"];
        [defaults setObject:freshIMEI forKey:@"deviceIdentifier"];
        
        [defaults setObject:selectedDNS forKey:@"spectrum_dns_spoof"];
        [defaults setObject:selectedIP forKey:@"spectrum_ip_spoof"];
        
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
        
        NSLog(@">>> [Every-Launch-Wipe] Session Locked. Spectrum DNS: %@ & Static Session IP: %@ spawned with IMEI: %@", selectedDNS, selectedIP, freshIMEI);
    }
}

// 3. منع التتبع وتزوير بيانات الجهاز
%hook ATTrackingManager
+ (NSUInteger)trackingAuthorizationStatus {
    return 2;
}
%end

%hook UIDevice
- (NSUUID *)identifierForVendor {
    return [NSUUID UUID];
}
- (NSString *)uniqueIdentifier {
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"device_imei"];
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

// 4. تعديل الطلبات والروابط
%hook NSMutableURLRequest

- (void)setURL:(NSURL *)url {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *sessionIP = [defaults stringForKey:@"spectrum_ip_spoof"];
    if (!sessionIP) {
        %orig(url);
        return;
    }
    
    NSString *urlString = [url absoluteString];
    if ([urlString containsString:@"ip="]) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"ip=([0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+)" options:0 error:nil];
        NSString *modifiedUrlString = [regex stringByReplacingMatchesInString:urlString options:0 range:NSMakeRange(0, [urlString length]) withTemplate:[NSString stringWithFormat:@"ip=%@", sessionIP]];
        url = [NSURL URLWithString:modifiedUrlString] ?: url;
    }
    
    %orig(url);
}

- (void)setValue:(NSString * _Nullable)value forHTTPHeaderField:(NSString *)field {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *sessionIP = [defaults stringForKey:@"spectrum_ip_spoof"];
    NSString *sessionDNS = [defaults stringForKey:@"spectrum_dns_spoof"];
    if (!sessionIP || !sessionDNS) {
        %orig(value, field);
        return;
    }
    
    if ([field isEqualToString:@"X-Forwarded-For"] || [field isEqualToString:@"Client-IP"] || [field isEqualToString:@"True-Client-IP"] || [field isEqualToString:@"X-Client-IP"]) {
        value = sessionIP;
    } else if ([field isEqualToString:@"X-Custom-DNS"] || [field isEqualToString:@"X-DNS-Server"]) {
        value = sessionDNS;
    } else if ([field isEqualToString:@"X-ISP"] || [field isEqualToString:@"X-Carrier"]) {
        value = @"Charter Communications";
    }

    %orig(value, field);
}
%end

// تغطية جلسات الـ NSURLSession بدون أي متغيرات غير مستخدمة
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *sessionIP = [defaults stringForKey:@"spectrum_ip_spoof"];
    NSString *sessionDNS = [defaults stringForKey:@"spectrum_dns_spoof"];
    
    if (sessionIP && sessionDNS) {
        [mutableReq setValue:sessionIP forHTTPHeaderField:@"X-Forwarded-For"];
        [mutableReq setValue:sessionIP forHTTPHeaderField:@"Client-IP"];
        [mutableReq setValue:sessionDNS forHTTPHeaderField:@"X-DNS-Server"];
        [mutableReq setValue:@"Charter Communications" forHTTPHeaderField:@"X-ISP"];
    }
    
    return %orig(mutableReq, completionHandler);
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *sessionIP = [defaults stringForKey:@"spectrum_ip_spoof"];
    
    if (sessionIP) {
        NSString *urlString = [url absoluteString];
        if ([urlString containsString:@"ip="]) {
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"ip=([0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+)" options:0 error:nil];
            NSString *modifiedUrlString = [regex stringByReplacingMatchesInString:urlString options:0 range:NSMakeRange(0, [urlString length]) withTemplate:[NSString stringWithFormat:@"ip=%@", sessionIP]];
            url = [NSURL URLWithString:modifiedUrlString] ?: url;
        }
    }
    
    return %orig(url, completionHandler);
}

%end

// --- التحصين المطلق لإعلانات مضمونة بدون حظر ---
%hook ActivatorAdService

- (BOOL)isReady { return YES; }
- (BOOL)isAdReady { return YES; }
- (BOOL)canShowAd { return YES; }
- (BOOL)hasAdLoaded { return YES; }

- (void)loadAd {
    %orig;
    id targetSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([targetSelf respondsToSelector:@selector(loadAd)]) {
            [targetSelf loadAd];
        }
    });
}

- (void)showRewardAd {
    @try {
        %orig;
        id targetSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([targetSelf respondsToSelector:@selector(loadAd)]) {
                [targetSelf loadAd];
            }
        });
    } @catch (NSException *exception) {
        NSLog(@">>> [Every-Launch-Ads] Exception in showRewardAd: %@", exception.reason);
    }
}

- (void)presentAdFromViewController:(UIViewController *)viewController {
    @try { 
        %orig; 
    } @catch (NSException *exception) {
        NSLog(@">>> [Every-Launch-Ads] Exception in presentAd: %@", exception.reason);
    }
}

- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    @try {
        NSLog(@">>> [Every-Launch-Ads] Ad error intercepted, forcing instant re-load.");
        id targetSelf = self;
        if ([targetSelf respondsToSelector:@selector(loadAd)]) {
            [targetSelf loadAd];
        }
    } @catch (NSException *exception) {}
}

%end
