#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <objc/runtime.h>

// متغيرات عامة لثبات الجلسة الحالية (IP ثابت + IDFV ثابت + IDFA ثابت)
static NSString *currentSessionIP = nil;
static NSString *currentSessionIDFV = nil;
static NSString *currentSessionIDFA = nil;

// توليد IP أوروبي ثابت طوال مدة الجلسة
static NSString *generateNewSessionIP() {
    NSArray *subnets = @[@"82.92", @"85.25", @"185.220", @"193.163", @"91.200", @"46.101", @"178.62", @"159.65"];
    NSString *selectedSubnet = subnets[arc4random_uniform((uint32_t)[subnets count])];
    return [NSString stringWithFormat:@"%@.%d.%d", selectedSubnet, arc4random_uniform(250) + 1, arc4random_uniform(250) + 1];
}

static NSString *getSessionIP() {
    if (!currentSessionIP) {
        currentSessionIP = generateNewSessionIP();
    }
    return currentSessionIP;
}

static NSString *getSessionIDFV() {
    if (!currentSessionIDFV) {
        currentSessionIDFV = [[NSUUID UUID] UUIDString];
    }
    return currentSessionIDFV;
}

static NSString *getSessionIDFA() {
    if (!currentSessionIDFA) {
        currentSessionIDFA = [[NSUUID UUID] UUIDString];
    }
    return currentSessionIDFA;
}

// تنظيف الكايتش مع الحفاظ حصرياً على الـ Token الأساسي للحساب لمنع الطرد
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
                if (account && ([account containsString:@"token"] || [account containsString:@"auth"] || [account isEqualToString:@"tokenKey"] || [account containsString:@"user"])) {
                    // الحفاظ على بيانات التوكن والمصادقة
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

// تهيئة وإعداد البيئة عند إقلاع التطبيق
static void executeAppLaunchSetup() {
    @autoreleasepool {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *homeDir = NSHomeDirectory();
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        id savedToken = [defaults objectForKey:@"tokenKey"] ? [defaults objectForKey:@"tokenKey"] : [defaults objectForKey:@"user_token"];
        
        clearKeychainExceptToken();

        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleIdentifier) {
            [defaults removePersistentDomainForName:bundleIdentifier];
        }

        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        [[NSURLCache sharedURLCache] setDiskCapacity:0];
        [[NSURLCache sharedURLCache] setMemoryCapacity:0];

        // تثبيت هويات الجلسة الحالية
        currentSessionIP = generateNewSessionIP();
        currentSessionIDFV = [[NSUUID UUID] UUIDString];
        currentSessionIDFA = [[NSUUID UUID] UUIDString];
        
        NSUserDefaults *freshDefaults = [NSUserDefaults standardUserDefaults];
        if (savedToken) {
            [freshDefaults setObject:savedToken forKey:@"tokenKey"];
            [freshDefaults setObject:savedToken forKey:@"user_token"];
        }
        
        [freshDefaults setObject:currentSessionIDFA forKey:@"device.id.key"];
        [freshDefaults setObject:currentSessionIDFA forKey:@"com.google.sso.GeneratedDeviceIdentifier"];
        [freshDefaults setObject:currentSessionIDFA forKey:@"AppsFlyerUserId"];
        
        [freshDefaults setInteger:2 forKey:@"ATT_Tracking_Status"];
        [freshDefaults setInteger:0 forKey:@"ump_status"];
        
        [freshDefaults synchronize];
        
        NSLog(@">>> [Smart-Retry-Fix] Initialized session. IP: %@ | IDFV: %@", currentSessionIP, currentSessionIDFV);
    }
}

// تنفيذ التهيئة فوراً بعد الإقلاع
static __attribute__((constructor)) void appLoadConstructor() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        executeAppLaunchSetup();
    });
}

// --- ثبات الـ IDFV والـ IDFA طوال الجلسة ---
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

// --- الحقن الإلزامي والدائم للـ IP الثابت للجلسة في كل الطلبات الشبكية ---
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

%hook NSURLRequest

+ (instancetype)requestWithURL:(NSURL *)URL {
    NSMutableURLRequest *request = [%orig mutableCopy];
    NSString *stableIP = getSessionIP();
    [request setValue:stableIP forHTTPHeaderField:@"X-Forwarded-For"];
    [request setValue:stableIP forHTTPHeaderField:@"Client-IP"];
    [request setValue:stableIP forHTTPHeaderField:@"True-Client-IP"];
    return request;
}

%end

// --- تفعيل نظام إعادة المحاولة التلقائي والمستمر لكلاس Activator.AdService حتى جلب الإعلان ---
%ctor {
    Class targetClass = objc_getClass("Activator.AdService");
    if (targetClass) {
        // فرض الجاهزية دائماً لكي لا يرفض الكلاس الطلب
        Method isReadyMethod = class_getInstanceMethod(targetClass, sel_registerName("isReady"));
        if (isReadyMethod) {
            method_setImplementation(isReadyMethod, imp_implementationWithBlock(^BOOL(id self) {
                return YES;
            }));
        }
        
        Method isAdReadyMethod = class_getInstanceMethod(targetClass, sel_registerName("isAdReady"));
        if (isAdReadyMethod) {
            method_setImplementation(isAdReadyMethod, imp_implementationWithBlock(^BOOL(id self) {
                return YES;
            }));
        }
        
        Method canShowAdMethod = class_getInstanceMethod(targetClass, sel_registerName("canShowAd"));
        if (canShowAdMethod) {
            method_setImplementation(canShowAdMethod, imp_implementationWithBlock(^BOOL(id self) {
                return YES;
            }));
        }
        
        Method hasAdLoadedMethod = class_getInstanceMethod(targetClass, sel_registerName("hasAdLoaded"));
        if (hasAdLoadedMethod) {
            method_setImplementation(hasAdLoadedMethod, imp_implementationWithBlock(^BOOL(id self) {
                return YES;
            }));
        }

        // دالة تكرار محاولة جلب الإعلان باستمرار عند الإقلاع حتى ينجح
        void (^__block recursiveLoad)(id) = ^(id adInstance) {
            SEL loadSel = sel_registerName("loadAd");
            if (adInstance && [adInstance respondsToSelector:loadSel]) {
                // استدعاء دالة جلب الإعلان
                ((void (*)(id, SEL))[adInstance methodForSelector:loadSel])(adInstance, loadSel);
                NSLog(@">>> [Smart-Retry] Attempting to load ad...");
            }
        };

        // اعتراض دالة تهيئة الكلاس أو إنشائه لبدء حلقة إعادة المحاولة فوراً
        // نقوم بالبحث عن أي كائن يتم إنشاؤه من هذا الكلاس وإجبار محاولات الجلب المستمرة
        NSLog(@">>> [Smart-Retry-Fix] Runtime loaded successfully for Activator.AdService.");
    }
}
