#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <WebKit/WebKit.h>
#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <netdb.h>
#import <arpa/inet.h>

// --- الثوابت الخاصة بمدة التايمر والحظر المستقل ---
static const NSTimeInterval kAppBlockDurationSeconds = 660.0; // 11 دقيقة

// --- متغيرات لتخزين الحالة والنقاط بدقة ---
static NSInteger cachedCurrentPoints = 0;
static NSInteger lastTriggeredPoints = -1;

static BOOL shouldBlockMysteryBoxForCurrentAccount(void) {
    return (cachedCurrentPoints >= 350);
}

// --- دوال توليد بيانات شبكية وهويات خارقة ومتغيرة في كل لحظة ---
static NSString *randomUUID() {
    return [[NSUUID UUID] UUIDString];
}

static NSString *randomIMEI() {
    int r1 = 10 + arc4random_uniform(89);
    long long r2 = 10000000000LL + (long long)(arc4random_uniform(900000000));
    return [NSString stringWithFormat:@"%d%lld", r1, r2];
}

static NSString *randomSpectrumDNS() {
    NSArray *dnsList = @[@"8.8.8.8", @"1.1.1.1", @"208.67.222.222", @"4.2.2.2", @"71.252.0.12", @"209.18.47.61"];
    return dnsList[arc4random_uniform((uint32_t)[dnsList count])];
}

static NSString *randomSuperIP() {
    NSArray *subnets = @[@"104.28", @"172.56", @"172.59", @"192.168", @"10.10", @"151.101", @"198.51", @"203.0", @"45.33", @"66.220"];
    NSString *subnet = subnets[arc4random_uniform((uint32_t)[subnets count])];
    return [NSString stringWithFormat:@"%@.%d.%d", subnet, arc4random_uniform(250) + 1, arc4random_uniform(250) + 1];
}

static NSString *randomOSVersion() {
    NSArray *versions = @[@"16.5", @"17.0", @"17.2", @"17.4", @"17.5.1", @"18.0", @"18.1", @"18.2", @"18.3"];
    return versions[arc4random_uniform((uint32_t)[versions count])];
}

static NSString *randomDeviceModel() {
    NSArray *models = @[@"iPhone14,2", @"iPhone14,3", @"iPhone15,2", @"iPhone15,3", @"iPhone16,1", @"iPhone16,2", @"iPhone17,1", @"iPhone17,2"];
    return models[arc4random_uniform((uint32_t)[models count])];
}

static NSString *randomLocaleIdentifier() {
    NSArray *locales = @[@"en_US", @"en_GB", @"en_CA", @"es_US", @"fr_FR", @"de_DE", @"ja_JP"];
    return locales[arc4random_uniform((uint32_t)[locales count])];
}

static NSString *randomCarrierName() {
    NSArray *carriers = @[@"Verizon", @"AT&T", @"T-Mobile", @"Vodafone", @"Orange", @"Sprint", @"EE"];
    return carriers[arc4random_uniform((uint32_t)[carriers count])];
}

static NSString *randomTimeZoneName() {
    NSArray *timeZones = @[@"America/New_York", @"America/Chicago", @"America/Los_Angeles", @"Europe/London", @"Asia/Tokyo"];
    return timeZones[arc4random_uniform((uint32_t)[timeZones count])];
}

static float randomBatteryLevel() {
    return (float)(20 + arc4random_uniform(79)) / 100.0f;
}

static UIDeviceBatteryState randomBatteryState() {
    NSArray *states = @[@(UIDeviceBatteryStateCharging), @(UIDeviceBatteryStateUnplugged), @(UIDeviceBatteryStateFull)];
    return (UIDeviceBatteryState)[states[arc4random_uniform((uint32_t)[states count])] integerValue];
}

// توليد إزاحة زمنية لمقدمة الوقت بين 20 إلى 60 دقيقة في المستقبل
static NSTimeInterval getFutureForwardTimeOffset() {
    int randomMinutes = 20 + (int)arc4random_uniform(41); // بين 20 إلى 60 دقيقة
    return [NSDate date].timeIntervalSince1970 + (NSTimeInterval)(randomMinutes * 60);
}

// وقت الإغلاق الأخير في الماضي (بين 20 إلى 50 دقيقة) كما هو تماماً بالتويك
static NSTimeInterval randomPastTimeOffsetForLastClosed(void) {
    int randomMinutes = 20 + arc4random_uniform(31);
    return [NSDate date].timeIntervalSince1970 - (NSTimeInterval)(randomMinutes * 60);
}

// --- تزوير شامل مع حماية تامة واستثناء لمفتاح auth_token وتعديل التوقيتات المزيفة ---
void spoofAndRefreshAllUserDefaults(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    id savedAuthToken = [defaults objectForKey:@"auth_token"];
    
    [defaults setObject:randomUUID() forKey:@"STASessionUUID"];
    [defaults setObject:randomUUID() forKey:@"igg-userId"];
    [defaults setObject:randomUUID() forKey:@"STAStoredDeveloperUserid"];
    
    [defaults setInteger:2 forKey:@"ATTrackingManagerAuthorizationStatus"];
    [defaults setBool:NO forKey:@"STAIABViewabilityEnabled"];
    [defaults setBool:NO forKey:@"STAAnalyticsImpressionsTrackingEnabled"];
    [defaults setBool:NO forKey:@"STAAlwaysSendTrackingID"];
    
    NSString *dynOS = randomOSVersion();
    NSString *dynModel = randomDeviceModel();
    NSString *uaString = [NSString stringWithFormat:@"Mozilla/5.0 (iPhone; CPU iPhone OS %@ like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Safari/604.1 AppModel/%@", dynOS, dynModel];
    [defaults setObject:uaString forKey:@"STAUserAgent"];
    [defaults setObject:@"https://trackdownload.startapp.com/trackdownload/api/1.0/" forKey:@"STATrackDownloadHost"];
    [defaults setObject:@"https://infoevent.startapps.com/infoevent/api/v1.0/info" forKey:@"STAAnalyticsHostSecured"];
    [defaults setObject:@"https://sdk-exchange.startappservice.com/1.5/" forKey:@"STAAdPlatformHostGeneric"];
    
    // تقديم التوقيتات والأزمنة بين 20 إلى 60 دقيقة قدماً
    [defaults setDouble:getFutureForwardTimeOffset() forKey:@"SKTransactionUpdatesLastChecked"];
    [defaults setDouble:getFutureForwardTimeOffset() forKey:@"SKPurchaseIntentUpdatesLastChecked"];
    [defaults setDouble:getFutureForwardTimeOffset() forKey:@"consent.gdpr.time"];
    [defaults setDouble:getFutureForwardTimeOffset() forKey:@"STACurrentSessionStartTime"];
    
    // GT_LAST_CLOSED_TIME يبقى كما هو تماماً (متأخراً بين 20 إلى 50 دقيقة في الماضي)
    [defaults setDouble:randomPastTimeOffsetForLastClosed() forKey:@"GT_LAST_CLOSED_TIME"];
    
    if (savedAuthToken) {
        [defaults setObject:savedAuthToken forKey:@"auth_token"];
    }
    
    [defaults synchronize];
}

// --- نظام مراقبة النقاط الذكي مع منع الحظر التلقائي عند إعادة الفتح بنفس النقاط ---
static BOOL isAlertActive = NO;

void handlePointsLogic(NSInteger currentPoints) {
    cachedCurrentPoints = currentPoints;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSTimeInterval blockEndTime = [defaults doubleForKey:@"AppBlockEndTime"];
    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    
    if (blockEndTime > 0) {
        if (now < blockEndTime) {
            return;
        } else {
            [defaults setDouble:0 forKey:@"AppBlockEndTime"];
            [defaults synchronize];
            isAlertActive = NO;
        }
    }
    
    if (currentPoints < 395) {
        isAlertActive = NO;
        lastTriggeredPoints = -1;
        return;
    }
    
    if (currentPoints == 395 && lastTriggeredPoints == 395) {
        return;
    }
    
    if (currentPoints >= 395 && !isAlertActive) {
        isAlertActive = YES;
        lastTriggeredPoints = currentPoints;
        
        NSTimeInterval endTime = [NSDate date].timeIntervalSince1970 + kAppBlockDurationSeconds;
        [defaults setDouble:endTime forKey:@"AppBlockEndTime"];
        [defaults synchronize];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = nil;
            if (@available(iOS 13.0, *)) {
                for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                    if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                        UISceneWindowScene *windowScene = (UISceneWindowScene *)scene; // safe casting
                        for (UIWindow *w in windowScene.windows) {
                            if (w.isKeyWindow) { keyWindow = w; break; }
                        }
                    }
                }
            }
            if (!keyWindow) keyWindow = [UIApplication sharedApplication].keyWindow;
            UIViewController *rootVC = keyWindow.rootViewController;
            while (rootVC.presentedViewController) { rootVC = rootVC.presentedViewController; }
            
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚠️ تنبيه حظر النقاط"
                                                                   message:@"تم الوصول إلى 395 نقطة.\nسيتم تعليق التطبيق مؤقتاً."
                                                            preferredStyle:UIAlertControllerStyleAlert];
            if (rootVC) {
                [rootVC presentViewController:alert animated:YES completion:^{
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        exit(0);
                    });
                }];
            } else {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    exit(0);
                });
            }
        });
    }
}

NSData *modifyResponseDataIfNeeded(NSString *url, NSData *data) {
    if (!data || !url) return data;
    
    if ([url containsString:@"tn.maildisposable.com/api/v1/users/additional/points/data"]) {
        NSError *jsonError = nil;
        NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        if (!jsonError && [jsonDict isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dataObj = jsonDict[@"data"] ?: jsonDict;
            NSDictionary *pointsData = dataObj[@"pointsData"] ?: dataObj;
            NSNumber *pointsVal = pointsData[@"points"] ?: pointsData[@"currentPoints"] ?: jsonDict[@"points"];
            
            if (pointsVal) {
                NSInteger currentPoints = [pointsVal integerValue];
                handlePointsLogic(currentPoints);
            }
        }
    }
    return data;
}

// --- حقن الهيدرز الخارقة والشاملة لأي طلب شبكة ---
static void enrichRequestWithGodModeHeaders(NSMutableURLRequest *request) {
    if (!request) return;
    
    NSString *dynIP = randomSuperIP();
    NSString *dynDNS = randomSpectrumDNS();
    NSString *dynIMEI = randomIMEI();
    NSString *dynIDFA = randomUUID();
    NSString *dynIDFV = randomUUID();
    NSString *dynOS = randomOSVersion();
    NSString *dynModel = randomDeviceModel();
    
    [request setValue:dynIP forHTTPHeaderField:@"X-Forwarded-For"];
    [request setValue:dynIP forHTTPHeaderField:@"Client-IP"];
    [request setValue:dynIP forHTTPHeaderField:@"True-Client-IP"];
    [request setValue:dynIP forHTTPHeaderField:@"X-Real-IP"];
    [request setValue:dynDNS forHTTPHeaderField:@"X-DNS-Server"];
    [request setValue:dynIMEI forHTTPHeaderField:@"X-Device-IMEI"];
    [request setValue:dynIDFA forHTTPHeaderField:@"X-Advertising-ID"];
    [request setValue:dynIDFV forHTTPHeaderField:@"X-Vendor-ID"];
    [request setValue:randomCarrierName() forHTTPHeaderField:@"X-ISP"];
    [request setValue:@"0" forHTTPHeaderField:@"X-Tracking-Allowed"];
    [request setValue:@"0" forHTTPHeaderField:@"DNT"];
    [request setValue:dynOS forHTTPHeaderField:@"X-OS-Version"];
    [request setValue:dynModel forHTTPHeaderField:@"X-Device-Model"];
    [request setValue:[NSString stringWithFormat:@"Mozilla/5.0 (iPhone; CPU iPhone OS %@ like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Safari/604.1 AppModel/%@", dynOS, dynModel] forHTTPHeaderField:@"User-Agent"];
}

// --- التنظيف الدوري الشامل كل 20 ثانية ---
void performPeriodicDeepClean(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSTimeInterval blockEndTime = [defaults doubleForKey:@"AppBlockEndTime"];
    if (blockEndTime > 0 && [NSDate date].timeIntervalSince1970 < blockEndTime) {
        return;
    }
    
    NSURLCache *sharedCache = [NSURLCache sharedURLCache];
    [sharedCache removeAllCachedResponses];
    
    if (@available(iOS 9.0, *)) {
        NSSet *websiteDataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
        [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes modifiedSince:[NSDate distantPast] completionHandler:^{}];
    }
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *tmpDir = NSTemporaryDirectory();
    if (tmpDir) {
        for (NSString *file in [fm contentsOfDirectoryAtPath:tmpDir error:nil]) {
            [fm removeItemAtPath:[tmpDir stringByAppendingPathComponent:file] error:nil];
        }
    }
    
    spoofAndRefreshAllUserDefaults();
}

void startPeriodicDeepCleanupTimer(void) {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), 20 * NSEC_PER_SEC, 1 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{
        performPeriodicDeepClean();
    });
    dispatch_resume(timer);
}

// --- 1. بروتوكول الشبكة الأساسي الشامل (NSURLProtocol) ---
@interface GodModeNetworkProtocol : NSURLProtocol
@end

@implementation GodModeNetworkProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    NSString *url = request.URL.absoluteString;
    if (url) {
        if ([url containsString:@"tn.maildisposable.com"]) {
            if ([url containsString:@"api/v1/users/additional/claim/mystery-box"] && shouldBlockMysteryBoxForCurrentAccount()) {
                return YES;
            }
            if ([url containsString:@"api/v1/users/additional/points/data"]) {
                if ([NSURLProtocol propertyForKey:@"GodModeHandled" inRequest:request] == nil) {
                    return YES;
                }
            }
        }
    }
    if ([NSURLProtocol propertyForKey:@"GodModeHandled" inRequest:request] == nil) {
        return YES;
    }
    return NO;
}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:@"GodModeHandled" inRequest:mutableReq];
    return mutableReq;
}
- (void)startLoading {
    NSString *url = self.request.URL.absoluteString;
    if (url && [url containsString:@"api/v1/users/additional/claim/mystery-box"] && shouldBlockMysteryBoxForCurrentAccount()) {
        NSDictionary *fakeResponseDict = @{
            @"success": @YES,
            @"message": @"Blocked locally at 350+ points",
            @"data": @{}
        };
        NSData *fakeData = [NSJSONSerialization dataWithJSONObject:fakeResponseDict options:0 error:nil];
        
        NSHTTPURLResponse *fakeResponse = [[NSHTTPURLResponse alloc] initWithURL:self.request.URL
                                                                      statusCode:200
                                                                     HTTPVersion:@"HTTP/1.1"
                                                                    headerFields:@{@"Content-Type": @"application/json"}];
        
        [self.client URLProtocol:self didReceiveResponse:fakeResponse cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        if (fakeData) {
            [self.client URLProtocol:self didLoadData:fakeData];
        }
        [self.client URLProtocolDidFinishLoading:self];
        return;
    }
    
    spoofAndRefreshAllUserDefaults();
    
    NSMutableURLRequest *newReq = [self.request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:@"GodModeHandled" inRequest:newReq];
    enrichRequestWithGodModeHeaders(newReq);

    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:newReq completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSData *finalData = modifyResponseDataIfNeeded(newReq.URL.absoluteString, data);
        
        if (finalData) [self.client URLProtocol:self didLoadData:finalData];
        if (response) [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
        if (error) [self.client URLProtocol:self didFailWithError:error];
        else [self.client URLProtocolDidFinishLoading:self];
    }];
    [task resume];
}
- (void)stopLoading {}
@end

// --- 2. خطافات شاملة لطبقة NSURLSession لمنع أي تسريب ---
%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    enrichRequestWithGodModeHeaders(mutableReq);
    return %orig(mutableReq, completionHandler);
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler {
    return %orig(url, completionHandler);
}

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData completionHandler:(void (^)(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error))completionHandler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    enrichRequestWithGodModeHeaders(mutableReq);
    return %orig(mutableReq, bodyData, completionHandler);
}
%end

// --- 3. خطافات طلبات NSMutableURLRequest المباشرة ---
%hook NSMutableURLRequest
- (void)setURL:(NSURL *)url {
    NSString *dynamicIP = randomSuperIP();
    NSString *urlString = [url absoluteString];
    
    if ([urlString containsString:@"ip="]) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"ip=([0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+)" options:0 error:nil];
        urlString = [regex stringByReplacingMatchesInString:urlString options:0 range:NSMakeRange(0, [urlString length]) withTemplate:[NSString stringWithFormat:@"ip=%@", dynamicIP]];
    }
    
    url = [NSURL URLWithString:urlString] ?: url;
    %orig(url);
}

- (void)setValue:(NSString * _Nullable)value forHTTPHeaderField:(NSString *)field {
    if ([field isEqualToString:@"X-Forwarded-For"] || [field isEqualToString:@"Client-IP"] || [field isEqualToString:@"True-Client-IP"]) {
        value = randomSuperIP();
    }
    %orig(value, field);
}
%end

// --- 4. فرض البروتوكول على كافة تكوينات جلسات التطبيق والويب في WKWebView ---
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
+ (NSURLSessionConfiguration *)ephemeralSessionConfiguration {
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

// --- تزوير بيئة الجهاز والتتبع صراحة ---
%hook ATTrackingManager
+ (NSUInteger)trackingAuthorizationStatus {
    return 2;
}
%end

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return [[NSUUID alloc] initWithUUIDString:@"00000000-0000-0000-0000-000000000000"];
}
- (BOOL)isAdvertisingTrackingEnabled {
    return NO;
}
%end

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
- (BOOL)isBatteryMonitoringEnabled {
    return YES;
}
- (float)batteryLevel {
    return randomBatteryLevel();
}
- (UIDeviceBatteryState)batteryState {
    return randomBatteryState();
}
%end

%hook NSLocale
+ (NSLocale *)currentLocale {
    return [[NSLocale alloc] initWithLocaleIdentifier:randomLocaleIdentifier()];
}
%end

%hook NSTimeZone
+ (NSTimeZone *)localTimeZone {
    return [NSTimeZone timeZoneWithName:randomTimeZoneName()];
}
+ (NSTimeZone *)systemTimeZone {
    return [NSTimeZone timeZoneWithName:randomTimeZoneName()];
}
%end

%hook CTTelephonyNetworkInfo
- (NSDictionary *)serviceSubscriberCellularProviders {
    return @{};
}
%end

// --- تهيئة التويك ---
%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        spoofAndRefreshAllUserDefaults();
        [NSURLProtocol registerClass:[GodModeNetworkProtocol class]];
        startPeriodicDeepCleanupTimer();
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSTimeInterval blockEndTime = [defaults doubleForKey:@"AppBlockEndTime"];
        if (blockEndTime > 0 && [NSDate date].timeIntervalSince1970 < blockEndTime) {
            handlePointsLogic(395);
        }
    });
}
