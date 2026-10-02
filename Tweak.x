#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <WebKit/WebKit.h>
#import <Security/Security.h>
#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <netdb.h>
#import <arpa/inet.h>

// --- الثوابت وإعدادات الحسابات ---
static NSString * const kKeychainAccount = @"com.tempnum.virtualnumber.deviceUUID";
static NSString * const kKeychainGroup   = @"3J96GNXKKU.*";
static NSString * const kAccount1_UUID   = @"5A82BF9F-3EA4-4CA5-AD39-593553C1E15C"; // الحساب الأول
static NSString * const kAccount2_UUID   = @"2BEE80E4-E20A-432B-879D-A98E2B8BC10D"; // الحساب الثاني

static BOOL isSwitchAlertShown = NO;

// --- واجهة خدمة الإعلانات ---
@interface ActivatorAdService : NSObject
- (void)loadAd;
- (BOOL)isReady;
- (BOOL)isAdReady;
- (BOOL)canShowAd;
- (BOOL)hasAdLoaded;
- (void)showRewardAd;
- (void)presentAdFromViewController:(UIViewController *)viewController;
@end

// --- دوال مساعدة لإنشاء هويات عشوائية ---
static NSString *randomUUID() {
    return [[NSUUID UUID] UUIDString];
}

static NSString *randomIMEI() {
    int r1 = 10 + arc4random_uniform(89);
    long long r2 = 10000000000LL + (long long)(arc4random_uniform(900000000));
    return [NSString stringWithFormat:@"%d%lld", r1, r2];
}

static NSString *randomSpectrumDNS() {
    NSArray *dnsList = @[@"71.252.0.12", @"71.243.0.12", @"209.18.47.61", @"209.18.47.62", @"68.237.161.12"];
    return dnsList[arc4random_uniform((uint32_t)[dnsList count])];
}

static NSString *randomSpectrumIP() {
    NSArray *subnets = @[@"24.24", @"24.160", @"65.24", @"66.192", @"67.240", @"68.172", @"71.64", @"75.128", @"97.100", @"173.16"];
    NSString *subnet = subnets[arc4random_uniform((uint32_t)[subnets count])];
    return [NSString stringWithFormat:@"%@.%d.%d", subnet, arc4random_uniform(250) + 1, arc4random_uniform(250) + 1];
}

static NSString *randomOSVersion() {
    NSArray *versions = @[@"16.1", @"16.5", @"17.0", @"17.2", @"17.4", @"17.5.1", @"18.0"];
    return versions[arc4random_uniform((uint32_t)[versions count])];
}

static NSString *randomDeviceModel() {
    NSArray *models = @[@"iPhone14,2", @"iPhone14,3", @"iPhone15,2", @"iPhone15,3", @"iPhone16,1", @"iPhone16,2"];
    return models[arc4random_uniform((uint32_t)[models count])];
}

static NSString *randomLocaleIdentifier() {
    NSArray *locales = @[@"en_US", @"en_GB", @"en_CA", @"es_US", @"fr_FR"];
    return locales[arc4random_uniform((uint32_t)[locales count])];
}

static NSString *generateTimestamp() {
    NSDate *now = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
    return [formatter stringFromDate:now];
}

// --- مسار حالة التبديل ---
NSString *getStatePlistPath(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libraryDirectory = [paths firstObject];
    return [libraryDirectory stringByAppendingPathComponent:@"AccountSwitchState.plist"];
}

// --- إدارة الـ Keychain المدمجة ---
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

// --- منطق تبديل الحسابات والنقاط ---
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
    
    NSMutableDictionary *newDict = [NSMutableDictionary dictionary];
    newDict[@"LastIndex"] = @(newIndex);
    newDict[@"WaitingForPointsChange"] = @YES; 
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

// --- مسح بيانات التطبيق كلياً مع استثناء ملفات الحالة الضرورية ---
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
                    continue; // استثناء ملف حالة التبديل
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

// --- تنفيذ التبديل والتنبيه ---
void performAccountSwitchAndAlert(void) {
    if (isSwitchAlertShown) return;
    isSwitchAlertShown = YES;
    
    NSString *nextUUID = getNextAccountUUID();
    clearAllAppDataCompletely();
    clearEntireKeychain();
    saveUUIDToKeychain(nextUUID);
    
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
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🔄 تم تبديل الحساب تلقائياً"
                                                                   message:@"تم الوصول إلى 395 نقطة وحذف الحساب السابق.\nتم تفعيل الحساب الآخر بنجاح.\n\nيرجى إغلاق التطبيق من الخلفية وفتحه مجدداً."
                                                            preferredStyle:UIAlertControllerStyleAlert];
        
        if (rootVC) {
            [rootVC presentViewController:alert animated:YES completion:nil];
        }
    });
}

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

// --- بروتوكول شبكة اعتراض النقاط ---
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

// --- الخطافات (Hooks) لتزوير البيانات والهويات وتوجيه الشبكة ---
%hook UIDevice
- (NSUUID *)identifierForVendor {
    return [[NSUUID alloc] initWithUUIDString:randomUUID()];
}
- (NSString *)systemVersion {
    return randomOSVersion();
}
- (NSString *)model {
    return @"iPhone";
}
- (NSString *)localizedModel {
    return @"iPhone";
}
- (NSString *)uniqueIdentifier {
    return randomIMEI();
}
%end

%hook NSLocale
+ (NSLocale *)currentLocale {
    return [[NSLocale alloc] initWithLocaleIdentifier:randomLocaleIdentifier()];
}
%end

%hook ATTrackingManager
+ (NSUInteger)trackingAuthorizationStatus {
    return 2;
}
%end

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return [[NSUUID alloc] initWithUUIDString:randomUUID()];
}
- (BOOL)isAdvertisingTrackingEnabled {
    return NO;
}
%end

%hook NSMutableURLRequest
- (void)setURL:(NSURL *)url {
    NSString *dynamicIP = randomSpectrumIP();
    NSString *urlString = [url absoluteString];
    
    if ([urlString containsString:@"ip="]) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"ip=([0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+)" options:0 error:nil];
        urlString = [regex stringByReplacingMatchesInString:urlString options:0 range:NSMakeRange(0, [urlString length]) withTemplate:[NSString stringWithFormat:@"ip=%@", dynamicIP]];
    }
    
    url = [NSURL URLWithString:urlString] ?: url;
    %orig(url);
}

- (void)setValue:(NSString * _Nullable)value forHTTPHeaderField:(NSString *)field {
    NSString *dynIP = randomSpectrumIP();
    NSString *dynDNS = randomSpectrumDNS();
    NSString *dynIMEI = randomIMEI();
    NSString *dynIDFA = randomUUID();
    NSString *dynIDFV = randomUUID();
    NSString *dynOS = randomOSVersion();
    NSString *dynModel = randomDeviceModel();
    
    if ([field isEqualToString:@"X-Forwarded-For"] || [field isEqualToString:@"Client-IP"] || [field isEqualToString:@"True-Client-IP"] || [field isEqualToString:@"X-Client-IP"] || [field isEqualToString:@"Remote-IP"]) {
        value = dynIP;
    } else if ([field isEqualToString:@"X-Custom-DNS"] || [field isEqualToString:@"X-DNS-Server"]) {
        value = dynDNS;
    } else if ([field isEqualToString:@"X-Device-IMEI"] || [field isEqualToString:@"X-IMEI"] || [field isEqualToString:@"Device-Id"] || [field isEqualToString:@"IMEI"]) {
        value = dynIMEI;
    } else if ([field isEqualToString:@"X-Advertising-ID"] || [field isEqualToString:@"IDFA"] || [field isEqualToString:@"Advertising-Identifier"]) {
        value = dynIDFA;
    } else if ([field isEqualToString:@"X-Vendor-ID"] || [field isEqualToString:@"IDFV"]) {
        value = dynIDFV;
    } else if ([field isEqualToString:@"User-Agent"]) {
        value = [NSString stringWithFormat:@"Mozilla/5.0 (iPhone; CPU iPhone OS %@ like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Safari/604.1 AppModel/%@", dynOS, dynModel];
    } else if ([field isEqualToString:@"X-OS-Version"] || [field isEqualToString:@"OS-Version"]) {
        value = dynOS;
    } else if ([field isEqualToString:@"X-Device-Model"]) {
        value = dynModel;
    } else if ([field isEqualToString:@"X-ISP"] || [field isEqualToString:@"X-Carrier"]) {
        value = @"Charter Communications";
    }

    %orig(value, field);
}
%end

%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    
    NSString *dynIP = randomSpectrumIP();
    NSString *dynDNS = randomSpectrumDNS();
    NSString *dynIMEI = randomIMEI();
    NSString *dynIDFA = randomUUID();
    NSString *dynIDFV = randomUUID();
    NSString *dynOS = randomOSVersion();
    NSString *dynModel = randomDeviceModel();
    NSString *timestamp = generateTimestamp();
    
    [mutableReq setValue:dynIP forHTTPHeaderField:@"X-Forwarded-For"];
    [mutableReq setValue:dynIP forHTTPHeaderField:@"Client-IP"];
    [mutableReq setValue:dynDNS forHTTPHeaderField:@"X-DNS-Server"];
    [mutableReq setValue:dynIMEI forHTTPHeaderField:@"X-Device-IMEI"];
    [mutableReq setValue:dynIDFA forHTTPHeaderField:@"X-Advertising-ID"];
    [mutableReq setValue:dynIDFV forHTTPHeaderField:@"X-Vendor-ID"];
    [mutableReq setValue:timestamp forHTTPHeaderField:@"X-Request-Timestamp"];
    [mutableReq setValue:@"Charter Communications" forHTTPHeaderField:@"X-ISP"];
    [mutableReq setValue:dynOS forHTTPHeaderField:@"X-OS-Version"];
    [mutableReq setValue:dynModel forHTTPHeaderField:@"X-Device-Model"];
    [mutableReq setValue:[NSString stringWithFormat:@"Mozilla/5.0 (iPhone; CPU iPhone OS %@ like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148", dynOS] forHTTPHeaderField:@"User-Agent"];
    
    // رصد طلبات النقاط للـ NSURLSession العادية أيضاً
    void (^wrappedHandler)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable) = ^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
        logGodModeEvent(@"NSURLSession", request.HTTPMethod, request.URL.absoluteString, httpResp.statusCode, data, error);
        if (completionHandler) completionHandler(data, response, error);
    };
    
    return %orig(mutableReq, wrappedHandler);
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    NSString *dynIP = randomSpectrumIP();
    NSString *urlString = [url absoluteString];
    
    if ([urlString containsString:@"ip="]) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"ip=([0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+)" options:0 error:nil];
        urlString = [regex stringByReplacingMatchesInString:urlString options:0 range:NSMakeRange(0, [urlString length]) withTemplate:[NSString stringWithFormat:@"ip=%@", dynamicIP]];
        url = [NSURL URLWithString:urlString] ?: url;
    }
    
    return %orig(url, completionHandler);
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

// --- تحصين وتفعيل الإعلانات تلقائياً ---
%hook ActivatorAdService
- (BOOL)isReady { return YES; }
- (BOOL)isAdReady { return YES; }
- (BOOL)canShowAd { return YES; }
- (BOOL)hasAdLoaded { return YES; }

- (void)loadAd {
    %orig;
    id targetSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([targetSelf respondsToSelector:@selector(loadAd)]) {
            [targetSelf loadAd];
        }
    });
}

- (void)showRewardAd {
    @try {
        %orig;
        id targetSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([targetSelf respondsToSelector:@selector(loadAd)]) {
                [targetSelf loadAd];
            }
        });
    } @catch (NSException *exception) {}
}

- (void)presentAdFromViewController:(UIViewController *)viewController {
    @try { %orig; } @catch (NSException *exception) {}
}

- (void)ad:(id)arg1 didFailToPresentFullScreenContentWithError:(id)arg2 {
    @try {
        id targetSelf = self;
        if ([targetSelf respondsToSelector:@selector(loadAd)]) {
            [targetSelf loadAd];
        }
    } @catch (NSException *exception) {}
}
%end

// --- نقطة البداية وتشغيل المراقب ---
%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [NSURLProtocol registerClass:[GodModeNetworkProtocol class]];
        
        checkAndEnforceValidAccount();
        
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
            checkAndEnforceValidAccount();
        }];
    });
}
