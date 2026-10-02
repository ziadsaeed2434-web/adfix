#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <WebKit/WebKit.h>
#import <Security/Security.h>

// الثوابت المطابقة لتنسيق الـ Keychain
static NSString * const kKeychainAccount = @"com.tempnum.virtual-number.deviceUUID";
static NSString * const kKeychainGroup   = @"3J96GNXKKU.*";
static NSString * const kAccount1_UUID   = @"5A82BF9F-3EA4-4CA5-AD39-593553C1E15C"; // الحساب الأول
static NSString * const kAccount2_UUID   = @"2BEE80E4-E20A-432B-879D-A98E2B8BC10D"; // الحساب الثاني

static BOOL isSwitchAlertShown = NO;

// علم أمني للتحكم المسموح به في الـ Keychain من قِبل التويك حصراً
static BOOL isPerformingAuthorizedKeychainOperation = NO;

// مسار حفظ مؤشر التبديل وحالة النقاط لضمان الذكاء وعدم التكرار
NSString *getStatePlistPath(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libraryDirectory = [paths firstObject];
    return [libraryDirectory stringByAppendingPathComponent:@"AccountSwitchState.plist"];
}

// قراءة وتحديد الحساب التالي بدقة تامة (تناوبي)
NSString *getNextAccountUUID(void) {
    NSString *path = getStatePlistPath();
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    
    NSInteger lastAccountIndex = 1; 
    if (dict && dict[@"LastIndex"] != nil) {
        lastAccountIndex = [dict[@"LastIndex"] integerValue];
    }
    
    NSString *nextUUID = nil;
    NSInteger newIndex = 1;
    
    if (lastAccountIndex == 1) {
        nextUUID = kAccount2_UUID;
        newIndex = 2;
    } else {
        nextUUID = kAccount1_UUID;
        newIndex = 1;
    }
    
    NSMutableDictionary *newDict = dict ? [dict mutableCopy] : [NSMutableDictionary dictionary];
    newDict[@"LastIndex"] = @(newIndex);
    newDict[@"WaitingForPointsChange"] = @YES; 
    [newDict writeToFile:path atomically:YES];
    
    return nextUUID;
}

// التحقق هل يجب تفعيل المراقبة
BOOL shouldProcessPoints(NSInteger currentPoints) {
    NSString *path = getStatePlistPath();
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
    
    if (dict && dict[@"WaitingForPointsChange"] != nil) {
        BOOL waiting = [dict[@"WaitingForPointsChange"] boolValue];
        if (waiting) {
            if (currentPoints == 10) {
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

// جلب الـ UUID الحالي من الـ Keychain
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

// حذف محتويات الـ Keychain بالكامل (مع تفعيل إذن التويك المؤقت)
void clearEntireKeychain(void) {
    isPerformingAuthorizedKeychainOperation = YES;
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
    isPerformingAuthorizedKeychainOperation = NO;
}

// حفظ الـ UUID الجديد في الـ Keychain (مع تفعيل إذن التويك المؤقت)
void saveUUIDToKeychain(NSString *uuidString) {
    isPerformingAuthorizedKeychainOperation = YES;
    NSData *data = [uuidString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *addQuery = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount: kKeychainAccount,
        (__bridge id)kSecAttrAccessGroup: kKeychainGroup,
        (__bridge id)kSecValueData: data
    };
    SecItemAdd((__bridge CFDictionaryRef)addQuery, NULL);
    isPerformingAuthorizedKeychainOperation = NO;
}

// مسح جميع بيانات التطبيق جذرياً واستثناء ملف الحالة
void clearAllAppDataCompletely(void) {
    NSString *bundleDomain = [[NSBundle mainBundle] bundleIdentifier];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleDomain];
    
    for (NSString *key in [[[NSUserDefaults standardUserDefaults] dictionaryRepresentation] allKeys]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];

    NSString *homeDir = NSHomeDirectory();
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSArray *foldersToClean = @[
        [homeDir stringByAppendingPathComponent:@"Documents"],
        [homeDir stringByAppendingPathComponent:@"Library"],
        [homeDir stringByAppendingPathComponent:@"tmp"],
        [homeDir stringByAppendingPathComponent:@"Caches"]
    ];
    
    NSString *statePath = getStatePlistPath();
    
    for (NSString *folderPath in foldersToClean) {
        if ([fm fileExistsAtPath:folderPath]) {
            NSArray *contents = [fm contentsOfDirectoryAtPath:folderPath error:nil];
            for (NSString *file in contents) {
                NSString *fullPath = [folderPath stringByAppendingPathComponent:file];
                if (![fullPath isEqualToString:statePath]) {
                    [fm removeItemAtPath:fullPath error:nil];
                }
            }
        }
    }
    
    NSString *webkitDir = [homeDir stringByAppendingPathComponent:@"Library/WebKit"];
    if ([fm fileExistsAtPath:webkitDir]) {
        [fm removeItemAtPath:webkitDir error:nil];
    }
}

// تنفيذ التبديل وإظهار النافذة للمستخدم
void performAccountSwitchAndAlert(void) {
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
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🔄 تبديل الحساب تلقائياً"
                                                                   message:@"تم الوصول إلى 10 نقاط!\nتم مسح البيانات والتبديل للحساب الآخر.\nيرجى إغلاق التطبيق وفتحه الآن."
                                                            preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *closeAction = [UIAlertAction actionWithTitle:@"إغلاق التطبيق الآن" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            NSString *nextUUID = getNextAccountUUID();
            clearAllAppDataCompletely();
            clearEntireKeychain();
            saveUUIDToKeychain(nextUUID);
            exit(0);
        }];
        
        [alert addAction:closeAction];
        
        if (rootVC) {
            [rootVC presentViewController:alert animated:YES completion:nil];
        } else {
            NSString *nextUUID = getNextAccountUUID();
            clearAllAppDataCompletely();
            clearEntireKeychain();
            saveUUIDToKeychain(nextUUID);
            exit(0);
        }
    });
}

// التدقيق الأمني للحساب عند التشغيل
void checkAndEnforceValidAccount(void) {
    NSString *currentUUID = getAppCurrentUUIDFromKeychain();
    if (![currentUUID isEqualToString:kAccount1_UUID] && ![currentUUID isEqualToString:kAccount2_UUID]) {
        clearEntireKeychain();
        saveUUIDToKeychain(kAccount1_UUID);
        
        NSString *path = getStatePlistPath();
        NSDictionary *dict = @{ @"LastIndex": @(1), @"WaitingForPointsChange": @NO };
        [dict writeToFile:path atomically:YES];
        
        clearAllAppDataCompletely();
    }
}

// تحليل طلبات الشبكة ورصد الوصول لـ 10 نقاط
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
                
                if (!shouldProcessPoints(currentPoints)) {
                    return;
                }
                
                if (currentPoints >= 10) {
                    performAccountSwitchAndAlert();
                }
            }
        }
    }
}

// -----------------------------------------------------------------
// حماية الـ Keychain ومنع أي إضافة أو تعديل خارجي
// -----------------------------------------------------------------

OSStatus hooked_SecItemAdd(CFDictionaryRef attributes, CFTypeRef *result) {
    // إذا لم تكن العملية صادرة عن التويك نفسه، نقوم برفضها أمنياً
    if (!isPerformingAuthorizedKeychainOperation) {
        // إرجاع خطأ يمنع الإضافة (errSecAuthFailed أو errSecDuplicateItem أو errSecParam حسب الحاجة)
        return errSecAuthFailed;
    }
    return SecItemAdd(attributes, result);
}

OSStatus hooked_SecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributesToUpdate) {
    // إذا لم تكن العملية صادرة عن التويك نفسه، نقوم برفض التعديل
    if (!isPerformingAuthorizedKeychainOperation) {
        return errSecAuthFailed;
    }
    return SecItemUpdate(query, attributesToUpdate);
}

// استخدام Logos Hooks لاعتراض دوال الأمن في C (Functions Interception)
// ملاحظة: بما أن SecItemAdd و SecItemUpdate دوال C وليست Objective-C methods، يتم استخدام تقنية MSHookFunction أو إعادة توجيه الرموز، 
// أو إن كان بيئة العمل تدعم Logos للـ C functions عبر %hook مع مساحات الأسماء أو Substrate:

// إذا كانت بيئة الإنشاء تدعم الـ Function Hook المباشر عبر Logos:
%group KeychainProtection
// سيتم تفعيل الحماية لمنع أي تعديل خارجي
%end

// 1. بروتوكول الاعتراض للشبكة
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

// 2. رصد طلبات NSURLSession
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    return %orig(request, ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
        logGodModeEvent(@"NSURLSession", request.HTTPMethod, request.URL.absoluteString, httpResp.statusCode, data, error);
        if (completionHandler) completionHandler(data, response, error);
    });
}

%end

// 3. فرض البروتوكول
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

%ctor {
    // تفعيل Hook لدوال C الخاصة بالـ Keychain لمنع أي تلاعب خارجي من التطبيق
    MSHookFunction((void *)SecItemAdd, (void *)hooked_SecItemAdd, (void **)&SecItemAdd);
    MSHookFunction((void *)SecItemUpdate, (void *)hooked_SecItemUpdate, (void **)&SecItemUpdate);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [NSURLProtocol registerClass:[GodModeNetworkProtocol class]];
        
        checkAndEnforceValidAccount();
        
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            checkAndEnforceValidAccount();
        }];
    });
}
