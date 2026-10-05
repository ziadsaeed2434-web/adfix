#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <Security/Security.h>
#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>

// --- إعدادات الـ Keychain والثوابت الأساسية ---
static NSString * const kKeychainAccount = @"com.tempnum.virtualnumber.deviceUUID";
static NSString * const kKeychainGroup   = @"3J96GNXKKU.*";
static NSTimeInterval const kAccountCooldownInterval = 600.0; // 10 دقائق بالثواني

static BOOL isSwitchAlertShown = NO;

// --- توليد معرف عشوائي فريد ---
static NSString *randomUUID() {
    return [[NSUUID UUID] UUIDString];
}

// --- مسار ملف الـ Plist لحفظ الحالة والتسلسل والأوقات ---
NSString *getStatePlistPath(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libraryDirectory = [paths firstObject];
    return [libraryDirectory stringByAppendingPathComponent:@"AccountSwitchState.plist"];
}

// --- مسار علامة الجلسة ---
NSString *getTerminationMarkerPath(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return [[paths firstObject] stringByAppendingPathComponent:@"AppWasTerminated.flag"];
}

// --- إدارة الـ Keychain ---
NSString *getAppCurrentUUIDFromKeychain(void) {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount: kKeychainAccount,
        (__bridge id)kSecAttrAccessGroup: kKeychainGroup,
        (__bridge id)kSecReturnData: (__bridge id)kCFBooleanTrue,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
    };
    CFTypeRef result = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &result) == noErr) {
        NSData *data = (__bridge_transfer NSData *)result;
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return nil;
}

void clearEntireKeychain(void) {
    NSArray *secClasses = @[
        (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecClassInternetPassword,
        (__bridge id)kSecClassCertificate,
        (__bridge id)kSecClassKey,
        (__bridge id)kSecClassIdentity
    ];
    
    for (id secClass in secClasses) {
        NSDictionary *spec = @{
            (__bridge id)kSecClass: secClass,
            (__bridge id)kSecAttrAccessGroup: kKeychainGroup
        };
        SecItemDelete((__bridge CFDictionaryRef)spec);
    }
}

void saveUUIDToKeychain(NSString *uuidString) {
    NSData *data = [uuidString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *addQuery = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount: kKeychainAccount,
        (__bridge id)kSecAttrAccessGroup: kKeychainGroup,
        (__bridge id)kSecValueData: data
    };
    SecItemAdd((__bridge CFDictionaryRef)addQuery, NULL);
}

// --- مسح بيانات التطبيق كلياً ---
void clearAllAppDataCompletely(void) {
    NSString *bundleDomain = [[NSBundle mainBundle] bundleIdentifier];
    if (bundleDomain) {
        [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleDomain];
    }
    
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    [[NSURLCache sharedURLCache] setDiskCapacity:0];
    [[NSURLCache sharedURLCache] setMemoryCapacity:0];

    NSString *homeDir = NSHomeDirectory();
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *error = nil;
    
    NSString *libraryDir = [homeDir stringByAppendingPathComponent:@"Library"];
    NSString *statePath = getStatePlistPath();
    
    NSArray *homeContents = [fm contentsOfDirectoryAtPath:homeDir error:&error];
    for (NSString *item in homeContents) {
        NSString *fullPath = [homeDir stringByAppendingPathComponent:item];
        if ([item isEqualToString:@"Library"]) {
            NSArray *libraryContents = [fm contentsOfDirectoryAtPath:libraryDir error:&error];
            for (NSString *libItem in libraryContents) {
                NSString *libItemPath = [libraryDir stringByAppendingPathComponent:libItem];
                if ([libItemPath isEqualToString:statePath]) {
                    continue; 
                }
                [fm removeItemAtPath:libItemPath error:&error];
            }
        } else {
            [fm removeItemAtPath:fullPath error:&error];
        }
    }
    
    NSString *groupDirBase = [[[homeDir stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Group Containers"];
    if ([fm fileExistsAtPath:groupDirBase]) {
        NSArray *groupFolders = [fm contentsOfDirectoryAtPath:groupDirBase error:nil];
        for (NSString *groupFolder in groupFolders) {
            NSString *groupPath = [groupDirBase stringByAppendingPathComponent:groupFolder];
            [fm removeItemAtPath:groupPath error:&error];
        }
    }
}

// --- تهيئة ملف الـ Plist للتسلسل وأوقات الاستخدام ---
NSMutableDictionary *getOrCreateAccountStateDictionary(void) {
    NSString *path = getStatePlistPath();
    
    NSArray *defaultAccounts = @[
        @"5A82BF9F-3EA4-4CA5-AD39-593553C1E15C", // الحساب الأول
        @"2BEE80E4-E20A-432B-879D-A98E2B8BC10A", // الحساب الثاني
        @"7F4D0094-0107-44B6-9D43-63FBCE2A5956"  // الحساب الثالث
    ];
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    if (!dict || !dict[@"Accounts"] || ![dict[@"Accounts"] isKindOfClass:[NSArray class]] || [dict[@"Accounts"] count] < 3) {
        dict = [NSMutableDictionary dictionary];
        dict[@"Accounts"] = defaultAccounts;
        dict[@"LastIndex"] = @(0);
        dict[@"BlockedUUID"] = @"";
        dict[@"TargetUUID"] = defaultAccounts[0];
        dict[@"AccountTimestamps"] = [NSMutableDictionary dictionary];
        [dict writeToFile:path atomically:YES];
    }
    return dict;
}

// --- التحقق مما إذا مر على الحساب 10 دقائق أو أكثر منذ اخر استخدام ---
BOOL isAccountCooledDown(NSString *uuid) {
    NSMutableDictionary *dict = getOrCreateAccountStateDictionary();
    NSDictionary *timestamps = dict[@"AccountTimestamps"];
    if (!timestamps || !timestamps[uuid]) return YES; 
    
    NSTimeInterval lastUsed = [timestamps[uuid] doubleValue];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    
    return (now - lastUsed) >= kAccountCooldownInterval;
}

// --- جلب الحساب التالي بالتسلسل مع الالتزام بشرط الـ 10 دقائق ---
NSString *getNextAccountUUIDFromPlist(void) {
    NSMutableDictionary *dict = getOrCreateAccountStateDictionary();
    NSArray *accounts = dict[@"Accounts"];
    NSInteger lastIndex = dict[@"LastIndex"] ? [dict[@"LastIndex"] integerValue] : 0;
    
    NSInteger count = [accounts count];
    NSInteger candidateIndex = lastIndex;
    NSString *nextUUID = nil;
    
    for (NSInteger i = 1; i <= count; i++) {
        candidateIndex = (lastIndex + i) % count;
        NSString *uuid = accounts[candidateIndex];
        if (isAccountCooledDown(uuid)) {
            nextUUID = uuid;
            lastIndex = candidateIndex;
            break;
        }
    }
    
    if (!nextUUID) {
        lastIndex = (lastIndex + 1) % count;
        nextUUID = accounts[lastIndex];
    }
    
    dict[@"LastIndex"] = @(lastIndex);
    dict[@"TargetUUID"] = nextUUID;
    dict[@"BlockedUUID"] = nextUUID;
    
    NSMutableDictionary *timestamps = [NSMutableDictionary dictionaryWithDictionary:dict[@"AccountTimestamps"]];
    timestamps[nextUUID] = @([[NSDate date] timeIntervalSince1970]);
    dict[@"AccountTimestamps"] = timestamps;
    
    [dict writeToFile:getStatePlistPath() atomically:YES];
    return nextUUID;
}

// --- منع الحلقة المفرغة عند بلوغ 395 نقطة ---
BOOL shouldProcessPoints(NSInteger currentPoints) {
    NSMutableDictionary *dict = getOrCreateAccountStateDictionary();
    NSString *currentUUID = getAppCurrentUUIDFromKeychain();
    NSString *blockedUUID = dict[@"BlockedUUID"];
    
    if (blockedUUID && [currentUUID isEqualToString:blockedUUID] && currentPoints >= 395) {
        return NO; 
    }
    
    if (currentPoints < 395) {
        dict[@"BlockedUUID"] = @"";
        [dict writeToFile:getStatePlistPath() atomically:YES];
    }
    
    return YES;
}

// --- تنفيذ روتين التبديل والتنظيف الشامل ---
void performCompleteSwitchRoutineForUUID(NSString *targetUUID) {
    clearAllAppDataCompletely();
    clearEntireKeychain();
    saveUUIDToKeychain(targetUUID);
    
    NSMutableDictionary *dict = getOrCreateAccountStateDictionary();
    NSArray *accounts = dict[@"Accounts"];
    
    NSInteger index = [accounts indexOfObject:targetUUID];
    if (index == NSNotFound) index = 0;
    
    dict[@"LastIndex"] = @(index);
    dict[@"BlockedUUID"] = targetUUID;
    dict[@"TargetUUID"] = targetUUID;
    
    NSMutableDictionary *timestamps = [NSMutableDictionary dictionaryWithDictionary:dict[@"AccountTimestamps"]];
    timestamps[targetUUID] = @([[NSDate date] timeIntervalSince1970]);
    dict[@"AccountTimestamps"] = timestamps;
    
    [dict writeToFile:getStatePlistPath() atomically:YES];
}

// --- إظهار تنبيه مانع (بدون أزرار للخروج) ويغلق تلقائياً عند انتهاء الـ 10 دقائق ---
void showCooldownBlockingAlertAndExitAfterTime(NSTimeInterval remainingSeconds) {
    if (isSwitchAlertShown) return;
    isSwitchAlertShown = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                    UIScene *windowScene = (UIScene *)scene;
                    for (UIScene *w in windowScene.windows) {
                        if (w.isKeyWindow) {
                            keyWindow = w;
                            break;
                        }
                    }
                }
            }
        }
        if (!keyWindow) keyWindow = [UIApplication sharedApplication].keyWindow;
        
        UIViewController *rootVC = keyWindow.rootViewController;
        while (rootVC.presentedViewController) {
            rootVC = rootVC.presentedViewController;
        }
        
        int minutesLeft = (int)(remainingSeconds / 60) + 1;
        NSString *message = [NSString stringWithFormat:@"⏳ لم تنقضِ فترة الـ 10 دقائق بعد لهذا الحساب.\n\nمتبقي تقريباً: %d دقيقة.\n\nسيتم إغلاق التطبيق تلقائياً فور اكتمال الوقت المخصص...", minutesLeft];
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"حماية التسلسل (Cooldown)"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
        // ملاحظة: لا توجد أزرار إطلاقاً هنا، مما يمنع المستخدم من إغلاق التنبيه يدوياً.
        
        if (rootVC) {
            [rootVC presentViewController:alert animated:YES completion:nil];
        }
    });
    
    // الانتظار للمدة المتبقية بالتمام، ثم إغلاق التطبيق تلقائياً
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(remainingSeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        exit(0);
    });
}

// --- التحقق من فترة الـ 10 دقائق لكل حساب عند التشغيل ---
void checkAccountCooldownOnLaunch(void) {
    NSMutableDictionary *dict = getOrCreateAccountStateDictionary();
    NSDictionary *timestamps = dict[@"AccountTimestamps"];
    NSString *currentUUID = getAppCurrentUUIDFromKeychain();
    
    if (!currentUUID || !timestamps || !timestamps[currentUUID]) {
        // أول استخدام لهذا الحساب، نسجل وقته ونسمح بالمرور
        NSMutableDictionary *mutableTimestamps = timestamps ? [NSMutableDictionary dictionaryWithDictionary:timestamps] : [NSMutableDictionary dictionary];
        mutableTimestamps[currentUUID ?: @"default"] = @([[NSDate date] timeIntervalSince1970]);
        dict[@"AccountTimestamps"] = mutableTimestamps;
        [dict writeToFile:getStatePlistPath() atomically:YES];
        return;
    }
    
    NSTimeInterval lastUsed = [timestamps[currentUUID] doubleValue];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval elapsed = now - lastUsed;
    
    // إذا لم تمر 10 دقائق (600 ثانية)، نظهر التنبيه المانع وننتظر حتى انتهاء الوقت المتبقي للإغلاق التلقائي
    if (elapsed < kAccountCooldownInterval) {
        NSTimeInterval remaining = kAccountCooldownInterval - elapsed;
        showCooldownBlockingAlertAndExitAfterTime(remaining);
    }
}

// --- التحقق ومطابقة التسلسل الدائري ---
void checkAndEnforceValidAccount(void) {
    NSMutableDictionary *dict = getOrCreateAccountStateDictionary();
    NSArray *accounts = dict[@"Accounts"];
    NSString *currentKeychainUUID = getAppCurrentUUIDFromKeychain();
    
    NSInteger lastIndex = dict[@"LastIndex"] ? [dict[@"LastIndex"] integerValue] : 0;
    if (lastIndex >= [accounts count]) lastIndex = 0;
    
    NSString *expectedUUID = accounts[lastIndex];
    
    if (!currentKeychainUUID || ![accounts containsObject:currentKeychainUUID] || ![currentKeychainUUID isEqualToString:expectedUUID]) {
        NSString *nextUUID = getNextAccountUUIDFromPlist();
        performCompleteSwitchRoutineForUUID(nextUUID);
    }
}

void checkAndWipeOnFreshLaunchIfNeeded(void) {
    checkAndEnforceValidAccount();
    
    // فحص شرط الـ 10 دقائق للحساب الحالي
    checkAccountCooldownOnLaunch();
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *markerPath = getTerminationMarkerPath();
    
    if (![fm fileExistsAtPath:markerPath]) {
        NSString *currentUUID = getAppCurrentUUIDFromKeychain();
        clearAllAppDataCompletely();
        if (currentUUID) {
            clearEntireKeychain();
            saveUUIDToKeychain(currentUUID);
        }
    }
    
    [@"active" writeToFile:markerPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

// --- التبديل عند بلوغ 395 نقطة ---
void performAccountSwitchAndAlert(void) {
    NSString *nextUUID = getNextAccountUUIDFromPlist();
    performCompleteSwitchRoutineForUUID(nextUUID);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (isSwitchAlertShown) return;
        isSwitchAlertShown = YES;
        
        UIWindow *keyWindow = nil;
        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                    UIScene *windowScene = (UIScene *)scene;
                    for (UIScene *w in windowScene.windows) {
                        if (w.isKeyWindow) {
                            keyWindow = w;
                            break;
                        }
                    }
                }
            }
        }
        if (!keyWindow) keyWindow = [UIApplication sharedApplication].keyWindow;
        
        UIViewController *rootVC = keyWindow.rootViewController;
        while (rootVC.presentedViewController) {
            rootVC = rootVC.presentedViewController;
        }
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🔄 تم التبديل التسلسلي بنجاح"
                                                                   message:@"تم الوصول إلى 395 نقطة، والانتقال للحساب التالي بالتسلسل المحفوظ.\n\nسيتم إغلاق التطبيق الآن..."
                                                            preferredStyle:UIAlertControllerStyleAlert];
        
        if (rootVC) {
            [rootVC presentViewController:alert animated:YES completion:^{
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    exit(0);
                });
            }];
        } else {
            exit(0);
        }
    });
}

void logGodModeEvent(NSString *engine, NSString *method, NSString *url, NSInteger statusCode, NSData *data, NSError *error) {
    checkAndEnforceValidAccount();

    if (!url || ![url containsString:@"tn.maildisposable.com/api/v1/users/additional/points/data"]) {
        return;
    }

    if (data) {
        NSError *jsonError = nil;
        NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (!jsonError && [jsonDict isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dataObj = jsonDict[@"data"];
            NSDictionary *pointsData = dataObj[@"pointsData"];
            NSNumber *pointsVal = pointsData[@"points"];
            
            if (pointsVal) {
                NSInteger currentPoints = [pointsVal integerValue];
                if (!shouldProcessPoints(currentPoints)) return; 
                if (currentPoints >= 395) {
                    performAccountSwitchAndAlert();
                }
            }
        }
    }
}

// --- بروتوكول الشبكة المعترض للطلبات ---
@interface GodModeNetworkProtocol : NSURLProtocol
@end

@implementation GodModeNetworkProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    NSString *url = request.URL.absoluteString;
    if (url && [url containsString:@"tn.maildisposable.com/api/v1/users/additional/points/data"]) {
        if ([NSURLProtocol propertyForKey:@"GodModeHandled" inRequest:request] == nil) {
            return YES;
        }
    }
    return NO;
}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:@"GodModeHandled" inRequest:mutableReq];
    return mutableReq;
}
- (void)startLoading {
    NSMutableURLRequest *newReq = [self.request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:@"GodModeHandled" inNewReq];
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:newReq completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
        logGodModeEvent(@"Protocol", newReq.HTTPMethod, newReq.URL.absoluteString, httpResp.statusCode, data, error);
        
        if (data) [self.client URLProtocol:self didLoadData:data];
        if (response) [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
        if (error) [self.client URLProtocol:self didFailWithError:error];
        else [self.client URLProtocolDidFinishLoading:self];
    }];
    [task resume];
}
- (void)stopLoading {}
@end

// --- تخطي شاشات الترحيب تلقائياً ---
%hook NSUserDefaults
- (BOOL)boolForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"onboarding_completed"] ||
        [defaultName rangeOfString:@"onboard" options:NSCaseInsensitiveSearch].location != NSNotFound ||
        [defaultName rangeOfString:@"term" options:NSCaseInsensitiveSearch].location != NSNotFound ||
        [defaultName rangeOfString:@"agree" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        return YES;
    }
    return %orig;
}
- (id)objectForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"onboarding_completed"] ||
        [defaultName rangeOfString:@"onboard" options:NSCaseInsensitiveSearch].location != NSNotFound) {
        return @YES;
    }
    return %orig;
}
- (NSInteger)integerForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"onboarding_completed"]) {
        return 1;
    }
    return %orig;
}
%end

// --- تغيير معرفات الجهاز عشوائياً ---
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return [[NSUUID alloc] initWithUUIDString:randomUUID()];
}
%end

%hook UIDevice
- (NSUUID *)identifierForVendor {
    return [[NSUUID alloc] initWithUUIDString:randomUUID()];
}
%end

%hook NSURLSessionConfiguration
+ (NSURLSessionConfiguration *)defaultSessionConfiguration {
    NSURLSessionConfiguration *config = %orig;
    NSMutableArray *protocols = [config.protocolClasses mutableCopy];
    if (!protocols) protocols = [NSMutableArray array];
    if (![protocols containsObject:[GodModeNetworkProtocol class]]) {
        [protocols insertObject:[GodModeNetworkProtocol class] atIndex:0];
        config.protocolClasses = protocols;
    }
    return config;
}
%end

// --- التحقق المبكر ودورة الحياة ---
%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [NSURLProtocol registerClass:[GodModeNetworkProtocol class]];
        
        checkAndWipeOnFreshLaunchIfNeeded();
        
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillTerminateNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            NSFileManager *fm = [NSFileManager defaultManager];
            [fm removeItemAtPath:getTerminationMarkerPath() error:nil];
        }];
    });
}
