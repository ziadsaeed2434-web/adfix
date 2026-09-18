#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

@interface ActivatorAdService : NSObject
- (void)loadAd;
- (BOOL)isReady;
- (BOOL)isAdReady;
- (BOOL)canShowAd;
- (BOOL)hasAdLoaded;
- (void)showRewardAd;
- (void)presentAdFromViewController:(UIViewController *)viewController;
@end

// الحفاظ حصرياً على الـ tokenKey لكي لا يتم تسجيل خروجك
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
                    NSLog(@">>> [Sandbox-Destroyer] tokenKey preserved safely.");
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

// نطاقات IPs هولندية سكنية حقيقية (Residential) لتجاوز الحظر تماماً
static NSString *randomDutchResidentialIP() {
    NSArray *dutchSubnets = @[
        @"84.241.", 
        @"213.127.", 
        @"82.161.",  
        @"212.203.", 
        @"94.212.",  
        @"62.194."   
    ];
    NSString *subnet = dutchSubnets[arc4random_uniform((uint32_t)[dutchSubnets count])];
    return [NSString stringWithFormat:@"%@%d.%d", subnet, arc4random_uniform(240) + 1, arc4random_uniform(240) + 1];
}

static NSString *generateFreshTimestamp() {
    NSDate *now = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'+0300'"];
    return [formatter stringFromDate:now];
}

// التدمير الشامل لكل شيء في الـ Sandbox والكوكيز والـ WebKit لجعل التطبيق نظيفاً تماماً
static void executeFullEnvironmentRefresh() {
    @autoreleasepool {
        // 1. حماية التوكن بالكيشين
        clearKeychainExceptToken();

        // 2. مسح NSUserDefaults بالكامل لـ app.getsmscode
        NSString *bundleIdentifier = @"app.getsmscode";
        [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleIdentifier];
        [[NSUserDefaults standardUserDefaults] synchronize];

        // 3. تفريغ كاش الشبكة
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        [[NSURLCache sharedURLCache] setDiskCapacity:0];
        [[NSURLCache sharedURLCache] setMemoryCapacity:0];

        // 4. مسح جميع الكوكيز الخاصة بالنظام
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
            [cookieStorage deleteCookie:cookie];
        }

        // 5. مسح بيانات WebKit والـ LocalStorage جذرياً
        if ([WKWebsiteDataStore class]) {
            NSSet *websiteDataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
            NSDate *dateFrom = [NSDate distantPast];
            [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes modifiedSince:dateFrom completionHandler:^{
                NSLog(@">>> [Sandbox-Destroyer] WKWebsiteDataStore & WebKit Cookies completely wiped.");
            }];
        }

        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *homeDir = NSHomeDirectory();
        
        // 6. مسح كل محتويات الـ Sandbox (Documents, Library, Caches, tmp) بالكامل لتدمير أي ملف حظر أو سجل قديم
        NSError *error = nil;
        NSArray *homeContents = [fileManager contentsOfDirectoryAtPath:homeDir error:&error];
        for (NSString *item in homeContents) {
            NSString *fullPath = [homeDir stringByAppendingPathComponent:item];
            [fileManager removeItemAtPath:fullPath error:&error];
        }

        // 7. حقن هويات وبصمات جديدة بالكامل كأنه جهاز جديد تماماً
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *freshID = randomNewIDFA();
        NSString *freshDate = generateFreshTimestamp();
        
        [defaults setObject:freshID forKey:@"device.id.key"];
        [defaults setObject:freshID forKey:@"com.google.sso.GeneratedDeviceIdentifier"];
        [defaults setObject:freshID forKey:@"AppsFlyerUserId"];
        [defaults setObject:freshID forKey:@"com.firebase.installations.app_id_to_fiid_enforcement"];
        
        [defaults setInteger:2 forKey:@"ATT_Tracking_Status"];
        [defaults setInteger:0 forKey:@"ump_status"];
        [defaults setInteger:0 forKey:@"IABTCF_gdprApplies"];
        [defaults setInteger:1 forKey:@"AppsFlyerRealLaunchCounter"];
        [defaults setObject:freshDate forKey:@"AppsFlyerInstallDate"];
        
        [defaults synchronize];
        
        NSLog(@">>> [Sandbox-Destroyer] Sandbox completely wiped & fresh ID spawned: %@", freshID);
    }
}

// تنفيذ التنظيف المدمر فور فتح التطبيق
static __attribute__((constructor)) void initialAppLaunchSetup() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        executeFullEnvironmentRefresh();
    });
}

// خداع النظام وتغيير معرفات الهاردوير
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

// حقن عناوين IP هولندية سكنية في كل طلب شبكي لتفادي الحظر تماماً
%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field isEqualToString:@"X-Forwarded-For"] || [field isEqualToString:@"Client-IP"] || [field isEqualToString:@"True-Client-IP"] || [field isEqualToString:@"X-Real-IP"]) {
        value = randomDutchResidentialIP();
    }
    %orig(value, field);
}
%end

// السيطرة المطلقة على نظام الإعلانات لضمان جلب إعلانات جديدة بدون توقف
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
    NSLog(@">>> [Sandbox-Destroyer] Forced Ad Load request sent to server.");
}

// إعادة المحاولة تلقائياً لضمان ظهور الإعلان فوراً
- (void)forceReloadWithRetries:(id)target {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([target respondsToSelector:@selector(loadAd)]) {
            [target loadAd];
            NSLog(@">>> [Sandbox-Destroyer] Auto-retry loadAd executed.");
        }
    });
}

- (void)showRewardAd {
    @try {
        %orig;
        NSLog(@">>> [Sandbox-Destroyer] Ad watched. Destroying sandbox & fetching fresh ad.");
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            executeFullEnvironmentRefresh();
            [self forceReloadWithRetries:self];
        });
        
    } @catch (NSException *exception) {
        NSLog(@">>> [Sandbox-Destroyer] Exception in showRewardAd: %@", exception.reason);
    }
}

- (void)presentAdFromViewController:(UIViewController *)viewController {
    @try {
        %orig;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            executeFullEnvironmentRefresh();
            [self forceReloadWithRetries:self];
        });
    } @catch (NSException *exception) {
        NSLog(@">>> [Sandbox-Destroyer] Exception in presentAd: %@", exception.reason);
    }
}

- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    NSLog(@">>> [Sandbox-Destroyer] Ad failed, purging sandbox and re-fetching instantly.");
    executeFullEnvironmentRefresh();
    [self forceReloadWithRetries:self];
}

%end
