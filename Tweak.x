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
@end

static NSString *currentFakeIDFV = nil;
static NSString *currentFakeUserID = nil;

static NSString *randomRealUUIDString() {
    return [[NSUUID UUID] UUIDString];
}

static NSString *randomRealUserID() {
    return [NSString stringWithFormat:@"%d", 600000 + arc4random_uniform(3900000)];
}

// 🎯 مولد الأيب الأوروبي الشامل لكل الطلبات والطبقات
static NSString *randomEuropeanIP() {
    return [NSString stringWithFormat:@"82.92.%d.%d", arc4random_uniform(250) + 1, arc4random_uniform(250) + 1];
}

// 🎯 حقن الأيب في رؤوس الطلبات (Headers)
static void injectIPToRequestHeaders(NSMutableURLRequest *request) {
    if (!request) return;
    NSString *fakeIP = randomEuropeanIP();
    NSArray *ipHeaders = @[@"X-Forwarded-For", @"Client-IP", @"True-Client-IP", @"X-Real-IP", @"X-Cluster-Client-IP", @"Fastly-Client-IP", @"CF-Connecting-IP", @"Via"];
    for (NSString *header in ipHeaders) {
        [request setValue:fakeIP forHTTPHeaderField:header];
    }
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
                if (![account isEqualToString:@"tokenKey"]) {
                    NSMutableDictionary *delQuery = [NSMutableDictionary dictionaryWithDictionary:item];
                    delQuery[(__bridge id)kSecClass] = secClass;
                    SecItemDelete((__bridge CFDictionaryRef)delQuery);
                }
            }
            if (result) CFRelease(result);
        }
    }
}

// 🎯 تدمير وتفريغ الـ Sandbox بالكامل والـ App Groups
static void destroySandboxAndAppGroupsData() {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *home = NSHomeDirectory();
    
    // مسارات الـ Sandbox الرئيسية المراد تفريغها بالكامل
    NSArray *sandboxFolders = @[
        [home stringByAppendingPathComponent:@"Documents"],
        [home stringByAppendingPathComponent:@"Library/Caches"],
        [home stringByAppendingPathComponent:@"Library/Application Support"],
        [home stringByAppendingPathComponent:@"Library/Preferences"],
        [home stringByAppendingPathComponent:@"tmp"]
    ];
    
    for (NSString *folder in sandboxFolders) {
        if ([fm fileExistsAtPath:folder]) {
            NSArray *contents = [fm contentsOfDirectoryAtPath:folder error:nil];
            for (NSString *item in contents) {
                NSString *fullPath = [folder stringByAppendingPathComponent:item];
                [fm removeItemAtPath:fullPath error:nil];
            }
        }
    }
    
    // استخراج مسارات الـ App Groups ديناميكياً من الـ Info.plist وتفريغها
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSArray *appGroups = infoDict[@"com.apple.security.application-groups"];
    if ([appGroups isKindOfClass:[NSArray class]]) {
        for (NSString *groupIdentifier in appGroups) {
            NSURL *groupURL = [fm containerURLForSecurityApplicationGroupIdentifier:groupIdentifier];
            if (groupURL) {
                NSString *groupPath = [groupURL path];
                NSArray *groupContents = [fm contentsOfDirectoryAtPath:groupPath error:nil];
                for (NSString *item in groupContents) {
                    // حماية بعض ملفات التوكن المشتركة إن وجدت، أو مسح الكل حسب الطلب
                    if (![item containsString:@"token"]) {
                        NSString *fullItemPath = [groupPath stringByAppendingPathComponent:item];
                        [fm removeItemAtPath:fullItemPath error:nil];
                    }
                }
            }
        }
    }
}

// التطهير الشامل للبيئة (Sandbox + App Groups + Keychain + UserDefaults)
static void executeUltimateDestructionRefresh() {
    @autoreleasepool {
        clearKeychainExceptToken();
        destroySandboxAndAppGroupsData();
        
        currentFakeIDFV = randomRealUUIDString();
        currentFakeUserID = randomRealUserID();

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        NSString *realUUID1 = randomRealUUIDString();
        NSString *realUUID2 = randomRealUUIDString();
        
        [defaults setObject:realUUID1 forKey:@"device.id.key"];
        [defaults setObject:realUUID1 forKey:@"com.google.sso.GeneratedDeviceIdentifier"];
        [defaults setObject:realUUID2 forKey:@"AppsFlyerUserId"];
        [defaults setObject:realUUID2 forKey:@"com.amplitude.bundleId.id"];
        [defaults setObject:realUUID2 forKey:@"amplitude_device_id"];
        [defaults setObject:realUUID1 forKey:@"com.firebase.installations.app_id_to_fiid_enforcement"];
        
        NSDate *realNow = [NSDate date];
        [defaults setObject:realNow forKey:@"AppsFlyerInstallDate"];
        [defaults setObject:realNow forKey:@"AppsFlyerFirstLaunchDate"];
        [defaults setObject:realNow forKey:@"AppsFlyerInstallTimestamp"];
        [defaults setInteger:1 forKey:@"AppsFlyerRealLaunchCounter"];
        [defaults setInteger:0 forKey:@"AppsFlyerReinstallCounter"];
        [defaults setInteger:1 forKey:@"AppsFlyerCounter"];
        [defaults setInteger:1 forKey:@"AppsFlyerLaunchKey"];
        
        [defaults setObject:currentFakeUserID forKey:@"user_id"];
        [defaults setObject:currentFakeUserID forKey:@"amplitude_user_id"];
        
        [defaults removeObjectForKey:@"NoAds"];
        [defaults removeObjectForKey:@"isAdRemoved"];
        [defaults removeObjectForKey:@"ads_disabled"];
        
        [defaults synchronize];
        NSLog(@">>> [Ultimate-Destruction] Sandbox, App Groups, and UserDefaults completely wiped and refreshed.");
    }
}

static __attribute__((constructor)) void initialAppLaunchSetup() {
    executeUltimateDestructionRefresh();
}

%hook UIDevice
- (NSUUID *)identifierForVendor {
    if (!currentFakeIDFV) {
        currentFakeIDFV = randomRealUUIDString();
    }
    return [[NSUUID alloc] initWithUUIDString:currentFakeIDFV];
}
%end

%hook ATTrackingManager
+ (NSUInteger)trackingAuthorizationStatus {
    return 2;
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
    NSArray *ipHeaders = @[@"X-Forwarded-For", @"Client-IP", @"True-Client-IP", @"X-Real-IP", @"X-Cluster-Client-IP", @"Fastly-Client-IP", @"CF-Connecting-IP", @"Via"];
    if ([ipHeaders containsObject:field]) {
        value = randomEuropeanIP();
    }
    %orig(value, field);
}
%end

%hook NSURLSession

- (NSURLSessionTask *)taskWithRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    injectIPToRequestHeaders(mutableReq);
    NSURLSessionTask *task = %orig(mutableReq);
    if (task) [task resume];
    return task;
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    injectIPToRequestHeaders(mutableReq);
    NSURLSessionDataTask *task = %orig(mutableReq);
    if (task) [task resume];
    return task;
}

- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    injectIPToRequestHeaders(mutableReq);
    NSURLSessionDownloadTask *task = %orig(mutableReq);
    if (task) [task resume];
    return task;
}

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    injectIPToRequestHeaders(mutableReq);
    NSURLSessionUploadTask *task = %orig(mutableReq, bodyData);
    if (task) [task resume];
    return task;
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url {
    NSMutableURLRequest *mutableReq = [NSMutableURLRequest requestWithURL:url];
    injectIPToRequestHeaders(mutableReq);
    NSURLSessionDataTask *task = %orig(mutableReq.copy);
    if (task) [task resume];
    return task;
}

%end

%hook ActivatorAdService

- (BOOL)isReady { return YES; }
- (BOOL)isAdReady { return YES; }
- (BOOL)canShowAd { return YES; }
- (BOOL)hasAdLoaded { return YES; }

- (void)loadAd {
    %orig;
    id targetSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([targetSelf respondsToSelector:@selector(loadAd)]) {
            [targetSelf loadAd];
        }
    });
}

- (void)showRewardAd {
    @try {
        %orig;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            executeUltimateDestructionRefresh();
            if ([self respondsToSelector:@selector(loadAd)]) {
                [self loadAd];
            }
        });
    } @catch (NSException *exception) {}
}

- (void)presentAdFromViewController:(UIViewController *)viewController {
    @try {
        %orig;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            executeUltimateDestructionRefresh();
            if ([self respondsToSelector:@selector(loadAd)]) {
                [self loadAd];
            }
        });
    } @catch (NSException *exception) {}
}

- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    executeUltimateDestructionRefresh();
    id targetSelf = self;
    if ([targetSelf respondsToSelector:@selector(loadAd)]) {
        [targetSelf loadAd];
    }
}

%end

%ctor {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        executeUltimateDestructionRefresh();
    }];
}
