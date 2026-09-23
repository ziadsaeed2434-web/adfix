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

// 1. حماية الـ Keychain بحذر شديد
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
                
                if (account && ([account containsString:@"token"] || [account containsString:@"auth"] || [account isEqualToString:@"tokenKey"])) {
                    // الحفاظ على التوكن وعدم مسحه لكي لا ينطرد الحساب
                } else {
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

// توليد تأخير زمني عشوائي (Jitter) لتجنب الرصد الآلي من السيرفر
static double randomJitterDelay() {
    return 2.0 + ((double)(arc4random_uniform(300)) / 100.0); // ما بين 2.0 إلى 5.0 ثوانٍ بشكل عشوائي تماماً كالبشر
}

// 2. دالة تنظيف الـ Sandbox مع حماية الـ Token وملفات الحساب الأساسية
static void executeStealthEnvironmentRefresh() {
    @autoreleasepool {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *homeDir = NSHomeDirectory();
        
        // استخراج التوكن الحالي من الـ NSUserDefaults لحفظه وإعادته فوراً
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        id savedToken = [defaults objectForKey:@"tokenKey"] ? [defaults objectForKey:@"tokenKey"] : [defaults objectForKey:@"user_token"];
        
        // أ) تنظيف الـ Keychain مع استثناء التوكن
        clearKeychainExceptToken();

        // ب) مسح نطاق الـ NSUserDefaults بالكامل
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleIdentifier) {
            [defaults removePersistentDomainForName:bundleIdentifier];
        }

        // ج) تفريغ كاش الشبكة بالكامل
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        [[NSURLCache sharedURLCache] setDiskCapacity:0];
        [[NSURLCache sharedURLCache] setMemoryCapacity:0];

        // د) مسح الـ Sandbox الرئيسي (مع الحفاظ على مسارات التوكن وتفضيلات الجلسة لكي لا يكتشف السيرفر أي خلل برمجي)
        NSError *error = nil;
        NSArray *homeContents = [fileManager contentsOfDirectoryAtPath:homeDir error:&error];
        for (NSString *item in homeContents) {
            if (![item isEqualToString:@"Documents"] && ![item isEqualToString:@"Library"]) {
                NSString *fullPath = [homeDir stringByAppendingPathComponent:item];
                [fileManager removeItemAtPath:fullPath error:&error];
            } else {
                NSString *libPath = [homeDir stringByAppendingPathComponent:@"Library"];
                NSArray *libContents = [fileManager contentsOfDirectoryAtPath:libPath error:nil];
                for (NSString *libItem in libContents) {
                    if (![libItem isEqualToString:@"Preferences"] && ![libItem isEqualToString:@"Caches"]) {
                        [fileManager removeItemAtPath:[libPath stringByAppendingPathComponent:libItem] error:nil];
                    }
                }
            }
        }
        
        // هـ) مسح الـ App Groups المرتبطة بإعلانات التطبيق
        NSString *groupDirBase = [[[homeDir stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Group Containers"];
        if ([fileManager fileExistsAtPath:groupDirBase]) {
            NSArray *groupFolders = [fileManager contentsOfDirectoryAtPath:groupDirBase error:nil];
            for (NSString *groupFolder in groupFolders) {
                // استثناء مجلدات النظام الحساسة وحذف الباقي لتوليد بيئة نظيفة للإعلانات
                NSString *groupPath = [groupDirBase stringByAppendingPathComponent:groupFolder];
                [fileManager removeItemAtPath:groupPath error:nil];
            }
        }

        // و) حقن هويات وبصمات جديدة بالكامل وإعادة وضع التوكن الخاص بك
        NSString *freshID = randomNewIDFA();
        NSUserDefaults *freshDefaults = [NSUserDefaults standardUserDefaults];
        
        if (savedToken) {
            [freshDefaults setObject:savedToken forKey:@"tokenKey"];
        }
        
        [freshDefaults setObject:freshID forKey:@"device.id.key"];
        [freshDefaults setObject:freshID forKey:@"com.google.sso.GeneratedDeviceIdentifier"];
        [freshDefaults setObject:freshID forKey:@"AppsFlyerUserId"];
        
        [freshDefaults setInteger:2 forKey:@"ATT_Tracking_Status"];
        [freshDefaults setInteger:0 forKey:@"ump_status"];
        
        [freshDefaults synchronize];
        
        NSLog(@">>> [Stealth-Refresh] Environment wiped cleanly with ID: %@", freshID);
    }
}

// تشغيل التطهير عند الإقلاع بمهلة عشوائية آمنة
static __attribute__((constructor)) void initialAppLaunchSetup() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        executeStealthEnvironmentRefresh();
    });
}

// 3. طريقة حقن آمنة وصامتة لـ ATTrackingManager و UIDevice لتجنب رصد السيرفر
%hook ATTrackingManager
+ (NSUInteger)trackingAuthorizationStatus {
    return 2; // رفض التتبع المدمج
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

%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field isEqualToString:@"X-Forwarded-For"] || [field isEqualToString:@"Client-IP"] || [field isEqualToString:@"True-Client-IP"]) {
        value = randomEuropeanIP();
    }
    %orig(value, field);
}
%end

// --- التحصين الخفي لمدير الإعلانات (Stealth Ad Service Hooks) ---
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (targetSelf && [targetSelf respondsToSelector:@selector(loadAd)]) {
            [targetSelf loadAd];
        }
    });
}

- (void)showRewardAd {
    @try {
        %orig;
        NSLog(@">>> [Stealth-Refresh] showRewardAd executed. Scheduling stealth environment wipe.");
        
        // استخدام تأخير زمني عشوائي (Jitter) لتجنب الكشف الآلي من السيرفر عند تكرار جلب الإعلانات
        double dynamicDelay = randomJitterDelay();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(dynamicDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            executeStealthEnvironmentRefresh();
            
            if (self && [self respondsToSelector:@selector(loadAd)]) {
                [self loadAd];
            }
        });
        
    } @catch (NSException *exception) {
        NSLog(@">>> [Stealth-Refresh] Exception in showRewardAd: %@", exception.reason);
    }
}

- (void)presentAdFromViewController:(UIViewController *)viewController {
    @try {
        %orig;
        double dynamicDelay = randomJitterDelay();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(dynamicDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            executeStealthEnvironmentRefresh();
            
            if (self && [self respondsToSelector:@selector(loadAd)]) {
                [self loadAd];
            }
        });
    } @catch (NSException *exception) {
        NSLog(@">>> [Stealth-Refresh] Exception caught in presentAdFromViewController: %@", exception.reason);
    }
}

- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    %orig;
    NSLog(@">>> [Stealth-Refresh] Ad error intercepted, executing stealth refresh and retrying.");
    executeStealthEnvironmentRefresh();
    id targetSelf = self;
    if (targetSelf && [targetSelf respondsToSelector:@selector(loadAd)]) {
        [targetSelf loadAd];
    }
}

%end
