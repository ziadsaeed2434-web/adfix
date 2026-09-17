#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import <sys/sysctl.h>

@interface ActivatorAdService : NSObject
- (void)loadAd;
- (BOOL)isReady;
- (BOOL)isAdReady;
- (BOOL)canShowAd;
- (BOOL)hasAdLoaded;
- (void)showRewardAd;
- (void)presentAdFromViewController:(UIViewController *)viewController;
@end

// قائمة واسعة ومتنوعة لضمان تغيير طراز الجهاز بشكل حقيقي ومختلف كلياً في كل إقلاع
static NSArray *getSpoofableModels() {
    return @[
        @"iPhone13,1", @"iPhone13,2", @"iPhone13,3", @"iPhone13,4",
        @"iPhone14,2", @"iPhone14,3", @"iPhone14,4", @"iPhone14,5",
        @"iPhone15,2", @"iPhone15,3", @"iPhone15,4", @"iPhone15,5",
        @"iPhone16,1", @"iPhone16,2", @"iPhone16,3", @"iPhone16,4"
    ];
}

static NSArray *getSpoofableSystems() {
    return @[@"17.1.2", @"17.2.1", @"17.4.1", @"17.5.1", @"18.0", @"18.1.1", @"18.2"];
}

static NSString *currentRandomModel = @"iPhone16,1";
static NSString *currentRandomSystem = @"18.1.1";

static void randomizeDeviceSpoofing() {
    NSArray *models = getSpoofableModels();
    NSArray *systems = getSpoofableSystems();
    currentRandomModel = models[arc4random_uniform((uint32_t)[models count])];
    currentRandomSystem = systems[arc4random_uniform((uint32_t)[systems count])];
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

// التنفيذ الشامل والعميق لكل شيء فور إقلاع التطبيق
static void executeFullEnvironmentRefresh() {
    @autoreleasepool {
        // 1. توليد بصمة جهاز ونظام جديدة كلياً
        randomizeDeviceSpoofing();
        
        // 2. تنظيف الـ Keychain بالكامل مع الحفاظ على التوكن فقط
        clearKeychainExceptToken();

        // 3. مسح جميع إعدادات الـ NSUserDefaults الخاصة بالتطبيق
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleIdentifier) {
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleIdentifier];
        }

        // 4. مسح بيانات الـ WebKit وجميع ملفات الارتباط (Cookies & LocalStorage)
        if (@available(iOS 9.0, *)) {
            NSSet *websiteDataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
            [[WKWebsiteDataStore defaultDataStore] fetchDataRecordsOfTypes:websiteDataTypes completionHandler:^(NSArray<WKWebsiteDataRecord *> * _Nonnull records) {
                [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes forDataRecords:records completionHandler:^{}];
            }];
        }

        // 5. تصفير كاش الشبكة والطلبات السابقة
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        [[NSURLCache sharedURLCache] setDiskCapacity:0];
        [[NSURLCache sharedURLCache] setMemoryCapacity:0];

        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        // 6. مسح مجلد الـ Sandbox بالكامل (المجلد الرئيسي للتطبيق)
        NSString *homeDir = NSHomeDirectory();
        NSError *error = nil;
        NSArray *homeContents = [fileManager contentsOfDirectoryAtPath:homeDir error:&error];
        for (NSString *item in homeContents) {
            NSString *fullPath = [homeDir stringByAppendingPathComponent:item];
            [fileManager removeItemAtPath:fullPath error:&error];
        }
        
        // 7. مسح بيانات الـ Group Containers المشتركة إن وجدت
        NSString *groupDirBase = [[[homeDir stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Group Containers"];
        if ([fileManager fileExistsAtPath:groupDirBase]) {
            NSArray *groupFolders = [fileManager contentsOfDirectoryAtPath:groupDirBase error:nil];
            for (NSString *groupFolder in groupFolders) {
                NSString *groupPath = [groupDirBase stringByAppendingPathComponent:groupFolder];
                [fileManager removeItemAtPath:groupPath error:nil];
            }
        }

        // 8. حقن بيانات وهويات جديدة تماماً لتبدو كأنها أول تثبيت نظيف للجهاز
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
        
        NSLog(@">>> [Dynamic-Refresh] FULL WIPE & NEW DEVICE SPAWNED -> Model: %@, System: %@, IDFA: %@", currentRandomModel, currentRandomSystem, freshID);
    }
}

// تنفيذ كامل للعملية فور تشغيل وبدء إقلاع التطبيق حصرياً
static __attribute__((constructor)) void initialAppLaunchSetup() {
    executeFullEnvironmentRefresh();
}

// خداع دوال النظام ومعلومات الهاردوير بناءً على البصمة الجديدة للإقلاع
%hook UIDevice

- (NSString *)model { return @"iPhone"; }
- (NSString *)systemName { return @"iOS"; }
- (NSString *)systemVersion { return currentRandomSystem; }
- (NSUUID *)identifierForVendor { return [NSUUID UUID]; }

%end

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier { return [NSUUID UUID]; }
- (BOOL)isAdvertisingTrackingEnabled { return NO; }
%end

%exthook sysctlbyname
int hooked_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t *newlenp) {
    int result = sysctlbyname(name, oldp, oldlenp, newp, newlenp);
    if (result == 0 && name && oldp) {
        if (strcmp(name, "hw.machine") == 0 || strcmp(name, "hw.model") == 0) {
            const char *spoofedModel = [currentRandomModel UTF8String];
            strlcpy(oldp, spoofedModel, *oldlenp);
        }
    }
    return result;
}
%end

// إعادة دمج توليد وحقن الـ IP الوهمي في طلبات الشبكة لتفادي الحظر من جهة السيرفر
%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field isEqualToString:@"X-Forwarded-For"] || [field isEqualToString:@"Client-IP"] || [field isEqualToString:@"True-Client-IP"]) {
        value = randomEuropeanIP();
    }
    %orig(value, field);
}
%end

// إدارة الإعلانات لضمان عدم توقفها
%hook ActivatorAdService

- (BOOL)isReady { return YES; }
- (BOOL)isAdReady { return YES; }
- (BOOL)canShowAd { return YES; }
- (BOOL)hasAdLoaded { return YES; }

- (void)loadAd { %orig; }

- (void)showRewardAd {
    @try {
        %orig;
    } @catch (NSException *exception) {}
}

- (void)presentAdFromViewController:(UIViewController *)viewController {
    @try {
        %orig;
    } @catch (NSException *exception) {}
}

- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    id targetSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([targetSelf respondsToSelector:@selector(loadAd)]) { [targetSelf loadAd]; }
    });
}

%end
