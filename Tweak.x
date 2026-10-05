#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <Security/Security.h>
#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>

// --- الثوابت وإعدادات الحسابات الثلاثة الثابتة ---
static NSString * const kKeychainAccount = @"com.tempnum.virtualnumber.deviceUUID";
static NSString * const kKeychainGroup   = @"3J96GNXKKU.*";
static NSString * const kAccount1_UUID   = @"5A82BF9F-3EA4-4CA5-AD39-593553C1E15C"; // الحساب الأول
static NSString * const kAccount2_UUID   = @"2BEE80E4-E20A-432B-879D-A98E2B8BC10A"; // الحساب الثاني
static NSString * const kAccount3_UUID   = @"7F4D0094-0107-44B6-9D43-63FBCE2A5956"; // الحساب الثالث

static BOOL isSwitchAlertShown = NO;

// --- توليد معرف عشوائي فريد ---
static NSString *randomUUID() {
    return [[NSUUID UUID] UUIDString];
}

// --- مسار حالة التبديل (محمي في مكتبة التطبيق) ---
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

// --- مسح بيانات التطبيق كلياً وبشكل مضمون ---
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

// --- منطق التبديل التسلسلي المضمون (أقدم حساب غير مستخدم) ---
NSString *getNextAccountUUID(void) {
    NSString *path = getStatePlistPath();
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    
    NSInteger lastAccountIndex = 1; 
    if (dict && dict[@"LastIndex"] != nil) {
        lastAccountIndex = [dict[@"LastIndex"] integerValue];
    }
    
    NSString *currentKeychainUUID = getAppCurrentUUIDFromKeychain();
    NSString *nextUUID = nil;
    NSInteger newIndex = 1;
    
    if (lastAccountIndex == 1) {
        nextUUID = kAccount2_UUID;
        newIndex = 2;
    } else if (lastAccountIndex == 2) {
        nextUUID = kAccount3_UUID;
        newIndex = 3;
    } else {
        nextUUID = kAccount1_UUID;
        newIndex = 1;
    }
    
    if (currentKeychainUUID && [nextUUID isEqualToString:currentKeychainUUID]) {
        if ([currentKeychainUUID isEqualToString:kAccount1_UUID]) {
            nextUUID = kAccount2_UUID; newIndex = 2;
        } else if ([currentKeychainUUID isEqualToString:kAccount2_UUID]) {
            nextUUID = kAccount3_UUID; newIndex = 3;
        } else {
            nextUUID = kAccount1_UUID; newIndex = 1;
        }
    }
    
    NSMutableDictionary *newDict = [NSMutableDictionary dictionary];
    newDict[@"LastIndex"] = @(newIndex);
    newDict[@"WaitingForPointsChange"] = @YES;
    newDict[@"TargetUUID"] = nextUUID;
    [newDict writeToFile:path atomically:YES];
    
    return nextUUID;
}

BOOL shouldProcessPoints(NSInteger currentPoints) {
    NSString *path = getStatePlistPath();
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    
    if (dict && dict[@"WaitingForPointsChange"] != nil) {
        BOOL waiting = [dict[@"WaitingForPointsChange"] boolValue];
        if (waiting) {
            if (currentPoints == 395) {
                return NO;
            } else {
                NSMutableDictionary *mutableDict = [dict mutableCopy];
                mutableDict[@"WaitingForPointsChange"] = @NO;
                [mutableDict writeToFile:path atomically:YES];
            }
        }
    }
    return YES;
}

// --- تنفيذ روتين التبديل والتنظيف كاملاً ---
void performCompleteSwitchRoutineForUUID(NSString *targetUUID) {
    clearAllAppDataCompletely();
    clearEntireKeychain();
    saveUUIDToKeychain(targetUUID);
    
    NSString *path = getStatePlistPath();
    NSInteger index = 1;
    if ([targetUUID isEqualToString:kAccount2_UUID]) index = 2;
    else if ([targetUUID isEqualToString:kAccount3_UUID]) index = 3;
    
    NSDictionary *dict = @{
        @"LastIndex": @(index),
        @"WaitingForPointsChange": @NO,
        @"TargetUUID": targetUUID
    };
    [dict writeToFile:path atomically:YES];
}

// --- إظهار شعار التنبيه والخروج من التطبيق ---
void showSwitchAlertAndExitWithMessage(NSString *title, NSString *message) {
    if (isSwitchAlertShown) return;
    isSwitchAlertShown = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *windowScene = (UIWindowScene *)scene;
                    for (UIWindow *w in windowScene.windows) {
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
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
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

// --- التحقق الصارم والذاتي عند فتح التطبيق مع التصحيح التنبيهي ---
void checkAndEnforceValidAccount(void) {
    NSString *path = getStatePlistPath();
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *currentKeychainUUID = getAppCurrentUUIDFromKeychain();
    
    if (![fm fileExistsAtPath:path]) {
        if (!currentKeychainUUID || (![currentKeychainUUID isEqualToString:kAccount1_UUID] && 
                                     ![currentKeychainUUID isEqualToString:kAccount2_UUID] && 
                                     ![currentKeychainUUID isEqualToString:kAccount3_UUID])) {
            performCompleteSwitchRoutineForUUID(kAccount1_UUID);
            showSwitchAlertAndExitWithMessage(@"🔄 تم تصحيح الحساب بنجاح", 
                                              @"تم اكتشاف عدم مطابقة، وتم تطبيق روتين التبديل والتنظيف والانتقال للحساب الصحيح.\n\nسيتم إغلاق التطبيق الآن...");
        } else {
            NSDictionary *initialDict = @{
                @"LastIndex": @(1),
                @"WaitingForPointsChange": @NO,
                @"TargetUUID": currentKeychainUUID ?: kAccount1_UUID
            };
            [initialDict writeToFile:path atomically:YES];
        }
        return;
    }
    
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    NSString *targetUUID = dict[@"TargetUUID"];
    
    // اكتشاف أي خطأ في الحساب -> تنفيذ الروتين الكامل + إظهار التنبيه والخروج
    if (targetUUID && currentKeychainUUID && ![currentKeychainUUID isEqualToString:targetUUID]) {
        performCompleteSwitchRoutineForUUID(targetUUID);
        showSwitchAlertAndExitWithMessage(@"🔄 تم تصحيح الحساب بنجاح", 
                                          @"تم اكتشاف خطأ في الحساب وتم تصحيحه والانتقال للحساب الصحيح بنجاح تام.\n\nسيتم إغلاق التطبيق الآن...");
    } else if (!currentKeychainUUID && targetUUID) {
        performCompleteSwitchRoutineForUUID(targetUUID);
        showSwitchAlertAndExitWithMessage(@"🔄 تم تصحيح الحساب بنجاح", 
                                          @"تم اكتشاف خطأ في الـ Keychain وتم تصحيحه والانتقال للحساب الصحيح بنجاح تام.\n\nسيتم إغلاق التطبيق الآن...");
    } else if (!currentKeychainUUID) {
        performCompleteSwitchRoutineForUUID(kAccount1_UUID);
        showSwitchAlertAndExitWithMessage(@"🔄 تم تصحيح الحساب بنجاح", 
                                          @"تم ضبط الحساب الافتراضي الأول بنجاح تام.\n\nسيتم إغلاق التطبيق الآن...");
    }
}

void checkAndWipeOnFreshLaunchIfNeeded(void) {
    checkAndEnforceValidAccount();
    
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

// --- عملية التبديل العادية عند الوصول إلى 395 نقطة ---
void performAccountSwitchAndAlert(void) {
    NSString *nextUUID = getNextAccountUUID();
    performCompleteSwitchRoutineForUUID(nextUUID);
    
    showSwitchAlertAndExitWithMessage(@"🔄 تم التبديل والحذف بنجاح", 
                                      @"تم الوصول إلى 395 نقطة، حذف البيانات السابقة، والانتقال للحساب التالي بنجاح تام.\n\nسيتم إغلاق التطبيق الآن...");
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
    [NSURLProtocol setProperty:@YES forKey:@"GodModeHandled" inRequest:newReq];
    
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

// --- تخطي الشاشات الترحيبية تلقائياً ---
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

// --- دورة الحياة والتحقق المبكر ---
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
