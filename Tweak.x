// Tweak.x
// مكتبة ديناميكية آمنة – حقن IP، موقع، معرفات وهمية، مع زر حذف يدوي

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
// MARK: - مولد IP
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

// ============================================================
// MARK: - مولد الموقع (أتلانتا)
// ============================================================

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
// MARK: - NSURLProtocol لاعتراض كل الطلبات (آمن)
// ============================================================

@interface CustomURLProtocol : NSURLProtocol <NSURLSessionDelegate, NSURLSessionTaskDelegate>
@end

@implementation CustomURLProtocol

static NSString *const CustomURLProtocolHandledKey = @"CustomURLProtocolHandled";

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    @try {
        if ([NSURLProtocol propertyForKey:CustomURLProtocolHandledKey inRequest:request]) {
            return NO;
        }
        return YES;
    } @catch (NSException *exception) {
        return NO;
    }
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    @try {
        NSMutableURLRequest *mutableRequest = [[self request] mutableCopy];
        [NSURLProtocol setProperty:@YES forKey:CustomURLProtocolHandledKey inRequest:mutableRequest];

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
    } @catch (NSException *exception) {
        NSLog(@"[Injector] ❌ خطأ في startLoading: %@", exception);
    }
}

- (void)stopLoading {}

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

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {
    NSMutableURLRequest *redirectRequest = [self injectHeadersIntoRequest:request];
    completionHandler(redirectRequest);
}

@end

// ============================================================
// MARK: - الكلاس الرئيسي Injector (آمن تماماً)
// ============================================================

@interface Injector : NSObject
+ (instancetype)sharedInstance;
- (void)performFullReset;
- (NSMutableURLRequest *)injectHeadersIntoRequest:(NSURLRequest *)request;
@end

@implementation Injector {
    BOOL _isResetting;
    UIButton *_resetButton;
    BOOL _initialized;
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
        _initialized = NO;
        
        // توليد القيم الأولية
        [self generateFreshIP];
        [self generateFreshLocation];
        [self generateFreshIdentifiers];
        
        // إعداد الـ Hooks (بأمان)
        [self setupAllHooks];
        
        // تأجيل كل العمليات التي قد تسبب كراش
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self performSafeInitialization];
        });
        
        NSLog(@"[Injector] ✅ تم تهيئة المكتبة (سيتم تفعيلها بعد 3 ثوان)");
    }
    return self;
}

- (void)performSafeInitialization {
    @try {
        // تسجيل NSURLProtocol
        [NSURLProtocol registerClass:[CustomURLProtocol class]];
        NSLog(@"[Injector] ✅ تم تسجيل CustomURLProtocol");
        
        // إضافة الزر
        [self addResetButtonSafely];
        
        _initialized = YES;
    } @catch (NSException *exception) {
        NSLog(@"[Injector] ❌ خطأ في التهيئة: %@", exception);
    }
}

// ============================================================
// MARK: - توليد القيم الجديدة
// ============================================================

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

// ============================================================
// MARK: - زر الحذف (إضافة آمنة)
// ============================================================

- (void)addResetButtonSafely {
    @try {
        // الحصول على النافذة المناسبة
        UIWindow *targetWindow = nil;
        NSArray *windows = [UIApplication sharedApplication].windows;
        for (UIWindow *win in windows) {
            if (win.isKeyWindow || win.windowLevel == UIWindowLevelNormal) {
                targetWindow = win;
                break;
            }
        }
        if (!targetWindow && windows.count > 0) {
            targetWindow = windows.firstObject;
        }
        
        if (!targetWindow) {
            // إذا لم توجد نافذة، نعيد المحاولة بعد ثانية
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self addResetButtonSafely];
            });
            return;
        }
        
        // إنشاء الزر
        self->_resetButton = [UIButton buttonWithType:UIButtonTypeSystem];
        self->_resetButton.frame = CGRectMake(0, 0, 60, 60);
        self->_resetButton.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.85];
        self->_resetButton.layer.cornerRadius = 30;
        self->_resetButton.layer.shadowColor = [UIColor blackColor].CGColor;
        self->_resetButton.layer.shadowOffset = CGSizeMake(0, 2);
        self->_resetButton.layer.shadowRadius = 4;
        self->_resetButton.layer.shadowOpacity = 0.5;
        [self->_resetButton setTitle:@"🗑" forState:UIControlStateNormal];
        self->_resetButton.titleLabel.font = [UIFont systemFontOfSize:24];
        [self->_resetButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self->_resetButton addTarget:self action:@selector(handleResetButtonTap) forControlEvents:UIControlEventTouchUpInside];
        
        // إضافة الزر إلى النافذة
        [targetWindow addSubview:self->_resetButton];
        
        // تحديد الموضع في أعلى اليمين مع مراعاة الـ safe area
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        CGFloat topInset = 40;
        if (@available(iOS 11.0, *)) {
            topInset = targetWindow.safeAreaInsets.top + 10;
        }
        self->_resetButton.frame = CGRectMake(screenWidth - 80, topInset, 60, 60);
        
        [targetWindow bringSubviewToFront:self->_resetButton];
        
        NSLog(@"[Injector] ✅ تم إضافة زر الحذف بنجاح");
    } @catch (NSException *exception) {
        NSLog(@"[Injector] ❌ فشل إضافة الزر: %@", exception);
    }
}

- (void)handleResetButtonTap {
    @try {
        UIWindow *mainWindow = [UIApplication sharedApplication].keyWindow;
        if (!mainWindow) {
            mainWindow = [[UIApplication sharedApplication].windows firstObject];
        }
        UIViewController *rootVC = mainWindow.rootViewController;
        if (!rootVC) {
            NSLog(@"[Injector] ❌ لا يوجد rootViewController لعرض التنبيه");
            return;
        }
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"إعادة ضبط"
                                                                       message:@"هل تريد مسح جميع البيانات وتجديد IP والموقع؟"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"حذف" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            [self performFullReset];
            UIAlertController *doneAlert = [UIAlertController alertControllerWithTitle:@"تم"
                                                                               message:@"تمت إعادة الضبط بنجاح"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
            [doneAlert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
            [rootVC presentViewController:doneAlert animated:YES completion:nil];
        }]];
        
        [rootVC presentViewController:alert animated:YES completion:nil];
    } @catch (NSException *exception) {
        NSLog(@"[Injector] ❌ خطأ في زر الحذف: %@", exception);
    }
}

// ============================================================
// MARK: - إعداد الـ Hooks (مع التحقق من وجود الفئات)
// ============================================================

- (void)setupAllHooks {
    [self hookNetworkClasses];
    [self hookLocationClasses];
    [self hookDeviceIdentifiers];
}

#pragma mark - Network Hooks

- (void)hookNetworkClasses {
    @try {
        Class sessionClass = NSClassFromString(@"NSURLSession");
        if (sessionClass) {
            SEL origSel1 = @selector(dataTaskWithRequest:completionHandler:);
            SEL swizzSel1 = @selector(swizzled_dataTaskWithRequest:completionHandler:);
            [self swizzleInstanceMethod:sessionClass from:origSel1 to:swizzSel1];
        }
        
        Class connectionClass = NSClassFromString(@"NSURLConnection");
        if (connectionClass) {
            SEL origSel2 = @selector(sendAsynchronousRequest:queue:completionHandler:);
            SEL swizzSel2 = @selector(swizzled_sendAsynchronousRequest:queue:completionHandler:);
            [self swizzleClassMethod:connectionClass from:origSel2 to:swizzSel2];
        }
    } @catch (NSException *exception) {
        NSLog(@"[Injector] ❌ خطأ في Hook الشبكة: %@", exception);
    }
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
    @try {
        Class managerClass = NSClassFromString(@"CLLocationManager");
        if (!managerClass) return;
        
        SEL setDelSel = @selector(setDelegate:);
        SEL swizzSetDelSel = @selector(swizzled_setDelegate:);
        [self swizzleInstanceMethod:managerClass from:setDelSel to:swizzSetDelSel];

        SEL locSel = @selector(location);
        SEL swizzLocSel = @selector(swizzled_location);
        [self swizzleInstanceMethod:managerClass from:locSel to:swizzLocSel];

        SEL startSel = @selector(startUpdatingLocation);
        SEL swizzStartSel = @selector(swizzled_startUpdatingLocation);
        [self swizzleInstanceMethod:managerClass from:startSel to:swizzStartSel];
    } @catch (NSException *exception) {
        NSLog(@"[Injector] ❌ خطأ في Hook الموقع: %@", exception);
    }
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
    @try {
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
    } @catch (NSException *exception) {
        NSLog(@"[Injector] ❌ خطأ في Hook المعرفات: %@", exception);
    }
}

- (NSUUID *)swizzled_identifierForVendor {
    return cachedVendorID ?: [NSUUID UUID];
}

- (NSUUID *)swizzled_advertisingIdentifier {
    return cachedAdvertisingID ?: [NSUUID UUID];
}

// ============================================================
// MARK: - دالة الحذف الكامل
// ============================================================

- (void)performFullReset {
    if (_isResetting) return;
    _isResetting = YES;
    
    @try {
        NSLog(@"[Injector] 🔄 بدء إعادة الضبط (يدوي)");
        [self clearCachesAndCookies];
        [self clearUserDefaults];
        [self clearLocalStorage];
        [self clearWebKitData];
        [self generateFreshIP];
        [self generateFreshLocation];
        [self generateFreshIdentifiers];
        NSLog(@"[Injector] ✅ اكتملت إعادة الضبط");
    } @catch (NSException *exception) {
        NSLog(@"[Injector] ❌ خطأ في إعادة الضبط: %@", exception);
    }
    
    _isResetting = NO;
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
    NSLog(@"[Injector] ✅ تم تحميل المكتبة، سيتم التهيئة بعد 3 ثوان");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [Injector sharedInstance];
    });
}
