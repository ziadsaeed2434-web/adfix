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
        
        NSLog(@">>> [Every-Launch-Wipe] Sandbox, App Groups & Caches wiped successfully. Fresh environment spawned with ID: %@", freshID);
    }
}

// 3. فرض حالة رفض التتبع على مستوى النظام برمجياً
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

// 4. حقن الـ IP المولد في كافة الطلبات الخارجة والداخلة (Network Hooking)
%hook NSMutableURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    // استبدال أي هيدر خاص بالـ IP بالـ IP المولد عشوائياً
    if ([field rangeOfString:@"IP" options:NSCaseInsensitiveSearch].location != NSNotFound ||
        [field rangeOfString:@"Forwarded" options:NSCaseInsensitiveSearch].location != NSNotFound ||
        [field rangeOfString:@"Client" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        value = randomEuropeanIP();
    }
    %orig(value, field);
}

- (void)setAllHTTPHeaderFields:(NSDictionary<NSString *,NSString *> *)headers {
    NSMutableDictionary *modifiedHeaders = [headers mutableCopy];
    NSString *fakeIP = randomEuropeanIP();
    
    // حقن وتحديث الهيدرز الشائعة للـ IP
    modifiedHeaders[@"X-Forwarded-For"] = fakeIP;
    modifiedHeaders[@"Client-IP"] = fakeIP;
    modifiedHeaders[@"True-Client-IP"] = fakeIP;
    modifiedHeaders[@"X-Real-IP"] = fakeIP;
    
    %orig(modifiedHeaders);
}

%end

// اعتراض إنشء الطلبات عبر NSURLSession لضمان حقن الهيدرز إجبارياً
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    NSMutableDictionary *mutableHeaders = [[request allHTTPHeaderFields] mutableCopy] ?: [NSMutableDictionary dictionary];
    NSString *fakeIP = randomEuropeanIP();
    
    mutableHeaders[@"X-Forwarded-For"] = fakeIP;
    mutableHeaders[@"Client-IP"] = fakeIP;
    mutableHeaders[@"True-Client-IP"] = fakeIP;
    
    // إعادة بناء الطلب بالـ Headers المحقونة
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    [mutableReq setAllHTTPHeaderFields:mutableHeaders];
    
    return %orig(mutableReq, completionHandler);
}

%end


// --- 5. نظام جلب الإعلانات الذكي اللانهائي (Anti No-Ads Loop) ---
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
    
    // حلقة تكرارية ذكية تفحص حالة الجلب وتستمر بالمحاولة حتى يتم الحصول على إعلان ناجح تماماً
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block BOOL adLoadedSuccess = NO;
        
        while (!adLoadedSuccess) {
            // محاولة جلب الإعلان
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([targetSelf respondsToSelector:@selector(loadAd)]) {
                    // استدعاء الـ orig أو إعادة الطلب
                    ((void (*)(id, SEL))[targetSelf methodForSelector:@selector(loadAd)])(targetSelf, @selector(loadAd));
                }
            });
            
            // فحص هل تم تحميل الإعلان (بافتراض أن الدوال ترجع جاهزية أو ننتظر فترة قصيرة للمحاولة التالية)
            [NSThread sleepForTimeInterval:0.5];
            
            if ([targetSelf respondsToSelector:@selector(isReady)] && [targetSelf isReady]) {
                adLoadedSuccess = YES;
                NSLog(@">>> [Anti-No-Ads] Successful ad fetched and ready!");
            } else {
                // إذا لم ينجح، يستمر في المحاولة الفورية بدون توقف
                adLoadedSuccess = NO;
            }
        }
    });
}

- (void)showRewardAd {
    @try {
        %orig;
        NSLog(@">>> [Every-Launch-Ads] showRewardAd executed. Pre-fetching next ad instantly.");
        
        id targetSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
        NSLog(@">>> [Every-Launch-Ads] Exception caught in presentAdFromViewController: %@", exception.reason);
    }
}

- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    NSLog(@">>> [Every-Launch-Ads] Ad error intercepted, forcing instant re-load loop.");
    id targetSelf = self;
    if ([targetSelf respondsToSelector:@selector(loadAd)]) {
        [targetSelf loadAd];
    }
}

%end
