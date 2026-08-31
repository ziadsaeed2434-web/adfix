// Tweak.x
// مكتبة ديناميكية محسّنة – تعمل مع Theos

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <WebKit/WebKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AdSupport/AdSupport.h>

// ============================================================
// MARK: - ثوابت ومتغيرات عامة
// ============================================================

#define ATLANTA_LAT_MIN 33.7000
#define ATLANTA_LAT_MAX 33.8000
#define ATLANTA_LON_MIN -84.4500
#define ATLANTA_LON_MAX -84.3000

static NSString *cachedFakeIP = nil;
static CLLocation *cachedFakeLocation = nil;
static NSUUID *cachedVendorID = nil;
static NSUUID *cachedAdvertisingID = nil;

// ============================================================
// MARK: - تعريف المولدات (IP, Location) قبل استخدامها في Injector
// ============================================================

@interface IPGenerator : NSObject
+ (NSString *)generateAmericanIP;
@end

@implementation IPGenerator
+ (NSString *)generateAmericanIP {
    NSArray *prefixes = @[@12, @13, @23, @44, @52, @54, @63, @64, @65, @66, @67, @68, @69, @70, @71, @72, @73, @74, @75, @76,
                          @96, @97, @98, @99, @104, @107, @108, @131, @132, @133, @134, @135, @136, @137, @138, @139,
                          @140, @141, @142, @143, @144, @145, @146, @147, @148, @149, @150, @151, @152, @153, @154,
                          @155, @156, @157, @158, @159, @160, @161, @162, @163, @164, @165, @166, @167, @170, @171,
                          @173, @174, @175, @176, @177, @178, @179, @180, @181, @182, @183, @184, @185, @186, @187,
                          @188, @189, @190, @191, @193, @194, @195, @196, @197, @198, @199, @204, @205, @206, @207,
                          @208, @209, @210, @211, @212, @213, @214, @215, @216, @217, @218, @219, @220, @221, @222, @223];
    int prefix = [prefixes[arc4random_uniform((uint32_t)prefixes.count)] intValue];
    int oct2 = arc4random_uniform(256);
    int oct3 = arc4random_uniform(256);
    int oct4 = arc4random_uniform(256);
    return [NSString stringWithFormat:@"%d.%d.%d.%d", prefix, oct2, oct3, oct4];
}
@end

@interface LocationGenerator : NSObject
+ (CLLocation *)generateLocationInAtlanta;
@end

@implementation LocationGenerator
+ (CLLocation *)generateLocationInAtlanta {
    double lat = ATLANTA_LAT_MIN + (double)arc4random() / UINT32_MAX * (ATLANTA_LAT_MAX - ATLANTA_LAT_MIN);
    double lon = ATLANTA_LON_MIN + (double)arc4random() / UINT32_MAX * (ATLANTA_LON_MAX - ATLANTA_LON_MIN);
    double alt = 200 + (double)arc4random() / UINT32_MAX * 100;
    double hAcc = 10 + (double)arc4random() / UINT32_MAX * 50;
    double vAcc = 10 + (double)arc4random() / UINT32_MAX * 50;
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(lat, lon);
    return [[CLLocation alloc] initWithCoordinate:coord
                                         altitude:alt
                               horizontalAccuracy:hAcc
                                 verticalAccuracy:vAcc
                                        timestamp:[NSDate date]];
}
@end

// ============================================================
// MARK: - تعريف CustomURLProtocol مع التزام بالبروتوكولات
// ============================================================

@interface CustomURLProtocol : NSURLProtocol <NSURLSessionDelegate, NSURLSessionTaskDelegate>
@end

@implementation CustomURLProtocol

static NSString *const CustomURLProtocolHandledKey = @"CustomURLProtocolHandled";

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if ([NSURLProtocol propertyForKey:CustomURLProtocolHandledKey inRequest:request]) {
        return NO;
    }
    return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    NSMutableURLRequest *mutableRequest = [[self request] mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:CustomURLProtocolHandledKey inRequest:mutableRequest];

    // حقن الترويسات باستخدام Injector (سيتم تعريفه لاحقاً، لكن يمكن استدعاء الدالة مباشرة)
    // نستخدم معرف خارجي، سنقوم بتمرير الطلب إلى Injector عبر دالة ثابتة
    NSMutableURLRequest *modifiedRequest = [self injectHeadersIntoRequest:mutableRequest];

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config
                                                          delegate:self
                                                     delegateQueue:nil];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:modifiedRequest
                                            completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            [self.client URLProtocol:self didFailWithError:error];
        } else {
            [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
            [self.client URLProtocol:self didLoadData:data];
            [self.client URLProtocolDidFinishLoading:self];
        }
        [session finishTasksAndInvalidate];
    }];
    [task resume];
}

- (void)stopLoading {
    // لا حاجة
}

// دالة مساعدة لحقن الترويسات (مكررة هنا لعدم الاعتماد على Injector)
- (NSMutableURLRequest *)injectHeadersIntoRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    if (!cachedFakeIP) {
        cachedFakeIP = [IPGenerator generateAmericanIP];
    }
    [mutableReq setValue:cachedFakeIP forHTTPHeaderField:@"X-Forwarded-For"];
    [mutableReq setValue:cachedFakeIP forHTTPHeaderField:@"X-Real-IP"];
    [mutableReq setValue:cachedFakeIP forHTTPHeaderField:@"Client-IP"];
    [mutableReq setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1" forHTTPHeaderField:@"User-Agent"];
    [mutableReq setValue:@"en-US,en;q=0.9" forHTTPHeaderField:@"Accept-Language"];
    [mutableReq setValue:@"gzip, deflate, br" forHTTPHeaderField:@"Accept-Encoding"];
    return mutableReq;
}

#pragma mark - NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {
    NSMutableURLRequest *redirectRequest = [self injectHeadersIntoRequest:request];
    completionHandler(redirectRequest);
}

@end

// ============================================================
// MARK: - الكلاس الرئيسي Injector (يُعرَّف بعد استخداماته)
// ============================================================

@interface Injector : NSObject
+ (instancetype)sharedInstance;
- (void)performFullReset;
- (NSMutableURLRequest *)injectHeadersIntoRequest:(NSURLRequest *)request;
@end

@implementation Injector {
    BOOL _isResetting;
}

+ (instancetype)sharedInstance {
    static Injector *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isResetting = NO;
        [self generateFreshIP];
        [self generateFreshLocation];
        [self generateFreshIdentifiers];
        [self setupAllHooks];
        [self setupLifecycleNotifications];
        [NSURLProtocol registerClass:[CustomURLProtocol class]];
        [self performFullReset];
    }
    return self;
}

- (void)generateFreshIP {
    cachedFakeIP = [IPGenerator generateAmericanIP];
    NSLog(@"[Injector] 🌐 IP: %@", cachedFakeIP);
}

- (void)generateFreshLocation {
    cachedFakeLocation = [LocationGenerator generateLocationInAtlanta];
    NSLog(@"[Injector] 📍 موقع: (%.6f, %.6f)",
          cachedFakeLocation.coordinate.latitude,
          cachedFakeLocation.coordinate.longitude);
}

- (void)generateFreshIdentifiers {
    cachedVendorID = [NSUUID UUID];
    cachedAdvertisingID = [NSUUID UUID];
}

- (void)setupAllHooks {
    [self hookNetworkClasses];
    [self hookLocationClasses];
    [self hookDeviceIdentifiers];
}

#pragma mark - Network Hooks

- (void)hookNetworkClasses {
    Class sessionClass = NSClassFromString(@"NSURLSession");
    SEL origSel1 = @selector(dataTaskWithRequest:completionHandler:);
    SEL swizzSel1 = @selector(swizzled_dataTaskWithRequest:completionHandler:);
    [self swizzleInstanceMethod:sessionClass from:origSel1 to:swizzSel1];

    Class connectionClass = NSClassFromString(@"NSURLConnection");
    SEL origSel2 = @selector(sendAsynchronousRequest:queue:completionHandler:);
    SEL swizzSel2 = @selector(swizzled_sendAsynchronousRequest:queue:completionHandler:);
    [self swizzleClassMethod:connectionClass from:origSel2 to:swizzSel2];
}

- (void)swizzleInstanceMethod:(Class)class from:(SEL)orig to:(SEL)new {
    Method origMethod = class_getInstanceMethod(class, orig);
    Method newMethod = class_getInstanceMethod(class, new);
    if (origMethod && newMethod) {
        method_exchangeImplementations(origMethod, newMethod);
    }
}

- (void)swizzleClassMethod:(Class)class from:(SEL)orig to:(SEL)new {
    Method origMethod = class_getClassMethod(class, orig);
    Method newMethod = class_getClassMethod(class, new);
    if (origMethod && newMethod) {
        method_exchangeImplementations(origMethod, newMethod);
    }
}

- (NSURLSessionDataTask *)swizzled_dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSMutableURLRequest *modifiedRequest = [self injectHeadersIntoRequest:request];
    return [self swizzled_dataTaskWithRequest:modifiedRequest completionHandler:completionHandler];
}

+ (void)swizzled_sendAsynchronousRequest:(NSURLRequest *)request queue:(NSOperationQueue *)queue completionHandler:(void (^)(NSURLResponse *response, NSData *data, NSError *error))handler {
    NSMutableURLRequest *modifiedRequest = [[Injector sharedInstance] injectHeadersIntoRequest:request];
    [self swizzled_sendAsynchronousRequest:modifiedRequest queue:queue completionHandler:handler];
}

- (NSMutableURLRequest *)injectHeadersIntoRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    if (!cachedFakeIP) [self generateFreshIP];
    [mutableReq setValue:cachedFakeIP forHTTPHeaderField:@"X-Forwarded-For"];
    [mutableReq setValue:cachedFakeIP forHTTPHeaderField:@"X-Real-IP"];
    [mutableReq setValue:cachedFakeIP forHTTPHeaderField:@"Client-IP"];
    [mutableReq setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1" forHTTPHeaderField:@"User-Agent"];
    [mutableReq setValue:@"en-US,en;q=0.9" forHTTPHeaderField:@"Accept-Language"];
    [mutableReq setValue:@"gzip, deflate, br" forHTTPHeaderField:@"Accept-Encoding"];
    return mutableReq;
}

#pragma mark - Location Hooks

- (void)hookLocationClasses {
    Class managerClass = NSClassFromString(@"CLLocationManager");
    SEL setDelSel = @selector(setDelegate:);
    SEL swizzSetDelSel = @selector(swizzled_setDelegate:);
    [self swizzleInstanceMethod:managerClass from:setDelSel to:swizzSetDelSel];

    SEL locSel = @selector(location);
    SEL swizzLocSel = @selector(swizzled_location);
    [self swizzleInstanceMethod:managerClass from:locSel to:swizzLocSel];

    SEL startSel = @selector(startUpdatingLocation);
    SEL swizzStartSel = @selector(swizzled_startUpdatingLocation);
    [self swizzleInstanceMethod:managerClass from:startSel to:swizzStartSel];
}

- (void)swizzled_setDelegate:(id<CLLocationManagerDelegate>)delegate {
    [self swizzled_setDelegate:delegate];
    if (delegate) {
        SEL didUpdateSel = @selector(locationManager:didUpdateLocations:);
        SEL swizzDidUpdateSel = @selector(swizzled_locationManager:didUpdateLocations:);
        Class delegateClass = [delegate class];
        if (!class_getInstanceMethod(delegateClass, didUpdateSel)) {
            class_addMethod(delegateClass, didUpdateSel, imp_implementationWithBlock(^(id self, CLLocationManager *mgr, NSArray *locs){}), "v@:@");
        }
        [self swizzleInstanceMethod:delegateClass from:didUpdateSel to:swizzDidUpdateSel];
    }
}

- (void)swizzled_locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    if (cachedFakeLocation) {
        [self swizzled_locationManager:manager didUpdateLocations:@[cachedFakeLocation]];
    } else {
        [self swizzled_locationManager:manager didUpdateLocations:locations];
    }
}

- (CLLocation *)swizzled_location {
    return cachedFakeLocation ?: [self swizzled_location];
}

- (void)swizzled_startUpdatingLocation {
    [self swizzled_startUpdatingLocation];
}

#pragma mark - Device Identifiers Hooks

- (void)hookDeviceIdentifiers {
    Class deviceClass = [UIDevice class];
    SEL vendorSel = @selector(identifierForVendor);
    SEL swizzVendorSel = @selector(swizzled_identifierForVendor);
    [self swizzleInstanceMethod:deviceClass from:vendorSel to:swizzVendorSel];

    Class asManagerClass = NSClassFromString(@"ASIdentifierManager");
    if (asManagerClass) {
        SEL advSel = @selector(advertisingIdentifier);
        SEL swizzAdvSel = @selector(swizzled_advertisingIdentifier);
        [self swizzleInstanceMethod:asManagerClass from:advSel to:swizzAdvSel];
    }
}

- (NSUUID *)swizzled_identifierForVendor {
    return cachedVendorID ?: [NSUUID UUID];
}

- (NSUUID *)swizzled_advertisingIdentifier {
    return cachedAdvertisingID ?: [NSUUID UUID];
}

#pragma mark - Lifecycle & Reset

- (void)setupLifecycleNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {}

- (void)applicationWillEnterForeground:(NSNotification *)notification {
    if (!_isResetting) {
        _isResetting = YES;
        [self performFullReset];
        _isResetting = NO;
    }
}

- (void)performFullReset {
    NSLog(@"[Injector] 🔄 إعادة ضبط...");
    [self clearCachesAndCookies];
    [self clearUserDefaults];
    [self clearLocalStorage];
    [self clearWebKitData];
    [self generateFreshIP];
    [self generateFreshLocation];
    [self generateFreshIdentifiers];
    NSLog(@"[Injector] ✅ اكتمل.");
}

- (void)clearCachesAndCookies {
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
        [cookieStorage deleteCookie:cookie];
    }
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

- (void)clearUserDefaults {
    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)clearLocalStorage {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docPath = [paths firstObject];
    if (docPath) {
        for (NSString *item in [fm contentsOfDirectoryAtPath:docPath error:nil]) {
            [fm removeItemAtPath:[docPath stringByAppendingPathComponent:item] error:nil];
        }
    }
    paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libPath = [paths firstObject];
    if (libPath) {
        for (NSString *item in [fm contentsOfDirectoryAtPath:libPath error:nil]) {
            if (![item isEqualToString:@"Preferences"] && ![item isEqualToString:@"Caches"]) {
                [fm removeItemAtPath:[libPath stringByAppendingPathComponent:item] error:nil];
            }
        }
        NSString *cachePath = [libPath stringByAppendingPathComponent:@"Caches"];
        for (NSString *item in [fm contentsOfDirectoryAtPath:cachePath error:nil]) {
            [fm removeItemAtPath:[cachePath stringByAppendingPathComponent:item] error:nil];
        }
    }
}

- (void)clearWebKitData {
    NSSet *dataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:dataTypes
                                               modifiedSince:[NSDate distantPast]
                                           completionHandler:^{
        NSLog(@"[Injector] 🧹 WebKit مسح.");
    }];
}

@end

// ============================================================
// MARK: - دالة البدء (constructor)
// ============================================================

__attribute__((constructor))
static void initializeInjector(void) {
    NSLog(@"[Injector] ✅ تحميل المكتبة");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [Injector sharedInstance];
    });
}
