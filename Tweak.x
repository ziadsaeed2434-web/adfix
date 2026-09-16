#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <objc/runtime.h>

// إعلان مسبق شامل لدوال الإعلانات
@interface ActivatorAdService : NSObject
- (void)loadAd;
- (BOOL)isReady;
- (BOOL)isAdReady;
- (BOOL)canShowAd;
- (BOOL)hasAdLoaded;
- (void)showRewardAd;
- (void)presentAdFromViewController:(UIViewController *)viewController;
- (void)grantReward;
- (void)triggerAggressiveAdLoop;
@end

// ==========================================
// نظام توليد الـ IPs (النطاقين المطلوبين حصرياً: 82.92 و 80.152)
// ==========================================

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

static NSString *randomSpecificEuropeanIP() {
    NSArray *allowedSubnets = @[
        @[@82, @92],
        @[@80, @152]
    ];
    
    int selectedIndex = arc4random_uniform((uint32_t)[allowedSubnets count]);
    NSArray *subnet = allowedSubnets[selectedIndex];
    
    int p1 = [subnet[0] intValue];
    int p2 = [subnet[1] intValue];
    int p3 = arc4random_uniform(240) + 1;
    int p4 = arc4random_uniform(250) + 1;
    
    return [NSString stringWithFormat:@"%d.%d.%d.%d", p1, p2, p3, p4];
}

static NSString *randomEuropeanUserAgent() {
    NSArray *agents = @[
        @"Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
        @"Mozilla/5.0 (iPhone; CPU iPhone OS 16_7_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1",
        @"Mozilla/5.0 (iPad; CPU OS 17_4_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/125.0.6422.80 Mobile/15E148 Safari/604.1"
    ];
    return agents[arc4random_uniform((uint32_t)[agents count])];
}

static double randomInactivitySeconds() {
    return (double)(3500000 + arc4random_uniform(6000000));
}

static NSString *generateFreshTimestamp() {
    NSDate *now = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'+0100'"];
    return [formatter stringFromDate:now];
}

// محاكاة التثبيت النظيف من الجذور مع كل إقلاع
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
                    if (![item isEqualToString:@"Caches"] && ![item isEqualToString:@"Preferences"]) {
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
        
        [defaults setInteger:2 forKey:@"ATT_Tracking_Status"];
        [defaults setInteger:0 forKey:@"ump_status"];
        
        [defaults setInteger:1 forKey:@"AppsFlyerRealLaunchCounter"];
        [defaults setObject:freshDate forKey:@"AppsFlyerInstallDate"];
        
        [defaults setDouble:dynamicInactivityTime forKey:@"AppsFlyerTimePassedSincePrevLaunch"];
        [defaults synchronize];
        
        NSLog(@">>> [Strict-IP-Engine] Sandbox wiped & Target IPs active.");
    }
}

// ==========================================
// شبكة الحماية الشاملة واعتراض كل الطلبات بلا استثناء
// ==========================================

// 1. اعتراض الطلبات القابلة للتعديل
%hook NSMutableURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    NSString *targetIP = randomSpecificEuropeanIP();
    
    if ([field caseInsensitiveCompare:@"X-Forwarded-For"] == NSOrderedSame ||
        [field caseInsensitiveCompare:@"Client-IP"] == NSOrderedSame ||
        [field caseInsensitiveCompare:@"True-Client-IP"] == NSOrderedSame ||
        [field caseInsensitiveCompare:@"X-Real-IP"] == NSOrderedSame ||
        [field caseInsensitiveCompare:@"Via"] == NSOrderedSame) {
        value = targetIP;
    }
    
    if ([field caseInsensitiveCompare:@"User-Agent"] == NSOrderedSame) {
        value = randomEuropeanUserAgent();
    }
    
    %orig(value, field);
}

- (void)setAllHTTPHeaderFields:(NSDictionary<NSString *,NSString *> *)headerFields {
    NSMutableDictionary *mutableFields = [headerFields mutableCopy];
    if (!mutableFields) {
        mutableFields = [NSMutableDictionary dictionary];
    }
    
    NSString *targetIP = randomSpecificEuropeanIP();
    mutableFields[@"X-Forwarded-For"] = targetIP;
    mutableFields[@"X-Real-IP"] = targetIP;
    mutableFields[@"Client-IP"] = targetIP;
    mutableFields[@"True-Client-IP"] = targetIP;
    mutableFields[@"User-Agent"] = randomEuropeanUserAgent();
    
    %orig(mutableFields);
}

%end

// 2. اعتراض الطلبات الثابتة
%hook NSURLRequest

- (NSDictionary<NSString *,NSString *> *)allHTTPHeaderFields {
    NSDictionary *originalFields = %orig;
    NSMutableDictionary *mutableFields = originalFields ? [originalFields mutableCopy] : [NSMutableDictionary dictionary];
    
    NSString *targetIP = randomSpecificEuropeanIP();
    mutableFields[@"X-Forwarded-For"] = targetIP;
    mutableFields[@"X-Real-IP"] = targetIP;
    mutableFields[@"Client-IP"] = targetIP;
    mutableFields[@"User-Agent"] = randomEuropeanUserAgent();
    
    return [mutableFields copy];
}

%end

// 3. اعتراض جلسات الشبكة وصياغتها بالشكل السليم للـ Theos
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    if (!mutableReq) {
        mutableReq = [[NSMutableURLRequest alloc] initWithURL:request.URL];
    }
    NSString *targetIP = randomSpecificEuropeanIP();
    [mutableReq setValue:targetIP forHTTPHeaderField:@"X-Forwarded-For"];
    [mutableReq setValue:targetIP forHTTPHeaderField:@"X-Real-IP"];
    [mutableReq setValue:targetIP forHTTPHeaderField:@"Client-IP"];
    [mutableReq setValue:randomEuropeanUserAgent() forHTTPHeaderField:@"User-Agent"];
    
    return %orig(mutableReq, completionHandler);
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    if (!mutableReq) {
        mutableReq = [[NSMutableURLRequest alloc] initWithURL:request.URL];
    }
    NSString *targetIP = randomSpecificEuropeanIP();
    [mutableReq setValue:targetIP forHTTPHeaderField:@"X-Forwarded-For"];
    [mutableReq setValue:targetIP forHTTPHeaderField:@"X-Real-IP"];
    [mutableReq setValue:targetIP forHTTPHeaderField:@"Client-IP"];
    [mutableReq setValue:randomEuropeanUserAgent() forHTTPHeaderField:@"User-Agent"];
    
    return %orig(mutableReq);
}

%end

// تجاوز حالة التتبع قسرياً
%hook ATTrackingManager
+ (NSUInteger)trackingAuthorizationStatus {
    return 2; // Denied
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

// ==========================================
// محرك الإعلانات الذاتي والطلب اللانهائي المستمر
// ==========================================
%hook ActivatorAdService

- (BOOL)isReady { return YES; }
- (BOOL)isAdReady { return YES; }
- (BOOL)canShowAd { return YES; }
- (BOOL)hasAdLoaded { return YES; }

- (void)triggerAggressiveAdLoop {
    id targetSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (targetSelf) {
            if ([targetSelf respondsToSelector:@selector(loadAd)]) {
                [targetSelf loadAd];
            }
            if ([targetSelf respondsToSelector:@selector(showRewardAd)]) {
                [targetSelf showRewardAd];
            } else if ([targetSelf respondsToSelector:@selector(presentAdFromViewController:)]) {
                UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
                UIViewController *rootVC = keyWindow.rootViewController;
                if (rootVC) {
                    [targetSelf presentAdFromViewController:rootVC];
                }
            }
            if ([targetSelf respondsToSelector:@selector(grantReward)]) {
                [targetSelf grantReward];
            }
            // حلقة استدعاء متجددة لا تتوقف أبداً
            [targetSelf performSelector:@selector(triggerAggressiveAdLoop) withObject:nil afterDelay:2.0];
        }
    });
}

- (void)loadAd {
    %orig;
    [self triggerAggressiveAdLoop];
}

- (void)showRewardAd {
    @try {
        %orig;
        if ([self respondsToSelector:@selector(grantReward)]) {
            [self grantReward];
        }
    } @catch (NSException *exception) {}
}

- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    %orig;
    if ([self respondsToSelector:@selector(grantReward)]) {
        [self grantReward];
    }
    if ([self respondsToSelector:@selector(loadAd)]) {
        [self loadAd];
    }
    [self triggerAggressiveAdLoop];
}

%end
