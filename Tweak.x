#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>
#import <WebKit/WebKit.h>
#import <Security/Security.h>
#import <objc/runtime.h>

// ============================================================
// MARK: - المتغيرات العامة (تُعرَّف أولاً)
// ============================================================

static double currentLat = 0.0;
static double currentLon = 0.0;
static NSString *sessionFakeIP = nil;
static NSString *currentRealIP = @"جاري الجلب...";
static NSMutableArray *networkLogs = nil;
static NSUUID *fakeAdvertisingID = nil;

// ============================================================
// MARK: - الدوال المساعدة (تُعرَّف قبل استخدامها)
// ============================================================

double randomInRange(double min, double max) {
    return min + (arc4random_uniform(UINT32_MAX) / (double)UINT32_MAX) * (max - min);
}

void updateAtlantaLocation() {
    currentLat = randomInRange(33.7000, 33.8000);
    currentLon = randomInRange(-84.4500, -84.3500);
}

void logNetworkRequest(NSString *urlStr, NSString *ip, double lat, double lon) {
    if (!networkLogs) networkLogs = [[NSMutableArray alloc] init];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSString *path = url.path ? url.path : urlStr;
    if (path.length > 30) path = [[path substringToIndex:30] stringByAppendingString:@"..."];
    NSString *logEntry = [NSString stringWithFormat:@"🔗 %@\n🌐 IP: %@\n📍 (%.4f, %.4f)", path, ip, lat, lon];
    @synchronized(networkLogs) {
        [networkLogs insertObject:logEntry atIndex:0];
        if (networkLogs.count > 15) [networkLogs removeLastObject];
    }
}

// ============================================================
// MARK: - كلاس Injector (يدير كل العمليات)
// ============================================================

@interface Injector : NSObject
+ (instancetype)sharedInstance;
- (void)startAutoAdFlow;
- (void)performFullReset;
- (void)adFinished;
- (void)noAdFound;
@end

@implementation Injector {
    BOOL _isConsentHandled;
    BOOL _isAdStarted;
    BOOL _isAdCompleted;
    BOOL _isAdFound;
    NSTimer *_adWatchTimer;
    NSTimer *_noAdTimer;
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
        _isConsentHandled = NO;
        _isAdStarted = NO;
        _isAdCompleted = NO;
        _isAdFound = NO;
        _adWatchTimer = nil;
        _noAdTimer = nil;
        // تحديث الموقع والـ IP والـ IDFA (بدون مسح)
        [self updateLocationAndIdentifiers];
    }
    return self;
}

// ============================================================
// MARK: - تحديث الموقع، IP، المعرفات (بدون مسح)
// ============================================================

- (void)updateLocationAndIdentifiers {
    [self generateSessionIP];
    [self generateFakeAdvertisingID];
    [self fetchRealIP];
    updateAtlantaLocation();
}

// ============================================================
// MARK: - دوال مساعدة (IP، موقع، IDFA)
// ============================================================

- (NSArray *)generate10IPs {
    NSMutableArray *tempList = [NSMutableArray arrayWithCapacity:10];
    int allowedSecondOctets[] = {56, 57, 59};
    for (int i = 0; i < 10; i++) {
        int second = allowedSecondOctets[arc4random_uniform(3)];
        int third = arc4random_uniform(256);
        int fourth = arc4random_uniform(256);
        NSString *ip = [NSString stringWithFormat:@"172.%d.%d.%d", second, third, fourth];
        [tempList addObject:ip];
    }
    return [tempList copy];
}

- (BOOL)verifyIPQuality:(NSString *)ip {
    if (!ip || ip.length == 0) return NO;
    NSString *urlString = [NSString stringWithFormat:@"http://ip-api.com/json/%@?fields=status,isp,org,as", ip];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setTimeoutInterval:3.0];
    __block NSData *responseData = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        responseData = data;
        dispatch_semaphore_signal(semaphore);
    }];
    [task resume];
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)));
    if (!responseData) return YES;
    NSError *jsonError = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&jsonError];
    if (jsonError || !json) return YES;
    if (![json[@"status"] isEqualToString:@"success"]) return YES;
    NSString *org = json[@"org"] ?: @"";
    NSString *isp = json[@"isp"] ?: @"";
    NSString *as = json[@"as"] ?: @"";
    NSString *combined = [NSString stringWithFormat:@"%@ %@ %@", org, isp, as];
    NSArray *badKeywords = @[@"Hosting", @"Datacenter", @"Cloud", @"Server", @"Dedicated", @"Colocation", @"VPS", @"CDN", @"Akamai", @"Amazon", @"AWS", @"DigitalOcean", @"Linode", @"Vultr", @"Hetzner", @"OVH"];
    for (NSString *keyword in badKeywords) {
        if ([combined rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return NO;
        }
    }
    return YES;
}

- (void)generateSessionIP {
    NSArray *candidates = [self generate10IPs];
    NSString *selectedIP = nil;
    for (NSString *ip in candidates) {
        if ([self verifyIPQuality:ip]) {
            selectedIP = ip;
            NSLog(@"[Injector] ✅ IP سكني: %@", ip);
            break;
        }
    }
    if (!selectedIP) selectedIP = candidates.lastObject;
    sessionFakeIP = selectedIP;
}

- (void)generateFakeAdvertisingID {
    fakeAdvertisingID = [NSUUID UUID];
}

- (void)fetchRealIP {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURL *url = [NSURL URLWithString:@"https://api.ipify.org"];
        NSString *ip = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
        currentRealIP = (ip && ip.length > 0) ? ip : @"غير قادر على الجلب";
    });
}

// ============================================================
// MARK: - مسح Keychain (مع بقاء الحساب)
// ============================================================

- (void)clearKeychainKeepingAccount {
    NSString *savedUserID = nil;
    NSString *savedAccessToken = nil;
    NSDictionary *query = @{
        (id)kSecClass: (id)kSecClassGenericPassword,
        (id)kSecMatchLimit: (id)kSecMatchLimitAll,
        (id)kSecReturnAttributes: @YES,
        (id)kSecReturnData: @YES
    };
    CFArrayRef result = NULL;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&result);
    if (status == errSecSuccess && result != NULL) {
        NSArray *items = (__bridge NSArray *)result;
        for (NSDictionary *item in items) {
            NSString *service = item[(id)kSecAttrService];
            NSString *account = item[(id)kSecAttrAccount];
            NSData *valueData = item[(id)kSecValueData];
            NSString *value = valueData ? [[NSString alloc] initWithData:valueData encoding:NSUTF8StringEncoding] : @"";
            if ([service isEqualToString:@"com.codebysms"] && [account isEqualToString:@"userIDKey"]) {
                savedUserID = value;
            } else if ([service isEqualToString:@"com.codebysms"] && [account isEqualToString:@"accessTokenKey"]) {
                savedAccessToken = value;
            }
        }
        CFRelease(result);
    }

    NSArray *secClasses = @[(id)kSecClassGenericPassword, (id)kSecClassInternetPassword, (id)kSecClassCertificate, (id)kSecClassKey, (id)kSecClassIdentity];
    for (id secClass in secClasses) {
        NSDictionary *deleteQuery = @{(id)kSecClass: secClass, (id)kSecMatchLimit: (id)kSecMatchLimitAll};
        SecItemDelete((CFDictionaryRef)deleteQuery);
    }

    if (savedUserID) {
        NSDictionary *addQuery = @{
            (id)kSecClass: (id)kSecClassGenericPassword,
            (id)kSecAttrService: @"com.codebysms",
            (id)kSecAttrAccount: @"userIDKey",
            (id)kSecValueData: [savedUserID dataUsingEncoding:NSUTF8StringEncoding]
        };
        SecItemAdd((CFDictionaryRef)addQuery, NULL);
    }
    if (savedAccessToken) {
        NSDictionary *addQuery = @{
            (id)kSecClass: (id)kSecClassGenericPassword,
            (id)kSecAttrService: @"com.codebysms",
            (id)kSecAttrAccount: @"accessTokenKey",
            (id)kSecValueData: [savedAccessToken dataUsingEncoding:NSUTF8StringEncoding]
        };
        SecItemAdd((CFDictionaryRef)addQuery, NULL);
    }
}

// ============================================================
// MARK: - مسح الكوكيز، الكاش، الملفات
// ============================================================

- (void)clearAllCookies {
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
        [cookieStorage deleteCookie:cookie];
    }
    NSSet *dataTypes = [NSSet setWithObject:WKWebsiteDataTypeCookies];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:dataTypes modifiedSince:[NSDate distantPast] completionHandler:^{}];
    NSSet *allWebTypes = [WKWebsiteDataStore allWebsiteDataTypes];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:allWebTypes modifiedSince:[NSDate distantPast] completionHandler:^{}];
}

- (void)clearNetworkCache {
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    [[NSURLCache sharedURLCache] setDiskCapacity:0];
    [[NSURLCache sharedURLCache] setMemoryCapacity:0];
}

- (void)clearAllLocalFiles {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *dirs = @[
        NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject,
        NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject,
        NSTemporaryDirectory()
    ];
    for (NSString *dir in dirs) {
        if (dir) {
            NSArray *items = [fm contentsOfDirectoryAtPath:dir error:nil];
            for (NSString *item in items) {
                if ([item isEqualToString:@"Preferences"]) {
                    NSString *prefPath = [dir stringByAppendingPathComponent:item];
                    NSArray *prefItems = [fm contentsOfDirectoryAtPath:prefPath error:nil];
                    for (NSString *prefFile in prefItems) {
                        if ([prefFile containsString:@"com.codebysms"] ||
                            [prefFile containsString:@"codebysms"] ||
                            [prefFile containsString:@"com.supersonic"] ||
                            [prefFile containsString:@"com.inmobi"] ||
                            [prefFile containsString:@"com.applovin"] ||
                            [prefFile containsString:@"com.unity"] ||
                            [prefFile containsString:@"com.google"] ||
                            [prefFile containsString:@"com.firebase"] ||
                            [prefFile containsString:@"com.amplitude"] ||
                            [prefFile containsString:@"io.appmetrica"] ||
                            [prefFile containsString:@"vungle"] ||
                            [prefFile containsString:@"com.crashlytics"] ||
                            [prefFile containsString:@"APM"] ||
                            [prefFile containsString:@"IABTCF"] ||
                            [prefFile containsString:@"GPP"] ||
                            [prefFile containsString:@"Cmp"]) {
                            [fm removeItemAtPath:[prefPath stringByAppendingPathComponent:prefFile] error:nil];
                        }
                    }
                } else {
                    [fm removeItemAtPath:[dir stringByAppendingPathComponent:item] error:nil];
                }
            }
        }
    }
}

// ============================================================
// MARK: - إعادة الضبط الكاملة (تُستدعى عند الخروج)
// ============================================================

- (void)performFullReset {
    NSLog(@"[Injector] 🔄 بدء إعادة الضبط (عند الخروج)...");
    [self clearKeychainKeepingAccount];
    [self clearAllCookies];
    [self clearNetworkCache];
    [self clearAllLocalFiles];
    // تجديد الموقع و IP و IDFA (للتشغيل القادم)
    updateAtlantaLocation();
    [self generateSessionIP];
    [self generateFakeAdvertisingID];
    [self fetchRealIP];
    @synchronized(networkLogs) { [networkLogs removeAllObjects]; }
    NSLog(@"[Injector] ✅ اكتملت إعادة الضبط. IP القادم: %@", sessionFakeIP);
}

// ============================================================
// MARK: - 🔥 تشغيل تدفق الإعلان التلقائي
// ============================================================

- (void)startAutoAdFlow {
    if (_isAdStarted) return;
    _isAdStarted = YES;
    NSLog(@"[Injector] 🚀 بدء تدفق الإعلان التلقائي...");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self autoAgreeToConsent];
    });
}

// ============================================================
// MARK: - الموافقة على الخصوصية
// ============================================================

- (void)autoAgreeToConsent {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) { [self retryConsent]; return; }
    UIViewController *rootVC = keyWindow.rootViewController;
    if (!rootVC) { [self retryConsent]; return; }
    UIViewController *presentedVC = rootVC.presentedViewController;
    while (presentedVC) {
        if ([self findAndTapAgreeButtonInViewController:presentedVC]) return;
        presentedVC = presentedVC.presentedViewController;
    }
    if ([self findAndTapAgreeButtonInViewController:rootVC]) return;
    [self startAdSearch];
}

- (void)retryConsent {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self autoAgreeToConsent];
    });
}

- (BOOL)findAndTapAgreeButtonInViewController:(UIViewController *)vc {
    if (!vc || _isConsentHandled) return NO;
    NSArray *titles = @[@"AGREE", @"موافق", @"Agree", @"Accept", @"allow"];
    for (NSString *title in titles) {
        if ([self findButtonWithTitle:title inView:vc.view]) {
            _isConsentHandled = YES;
            NSLog(@"[Injector] ✅ تم الضغط على زر الموافقة");
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self startAdSearch];
            });
            return YES;
        }
    }
    return NO;
}

- (BOOL)findButtonWithTitle:(NSString *)title inView:(UIView *)view {
    if (_isConsentHandled) return NO;
    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)view;
        NSString *btnTitle = [btn titleForState:UIControlStateNormal];
        if (btnTitle && [btnTitle rangeOfString:title options:NSCaseInsensitiveSearch].location != NSNotFound) {
            [btn sendActionsForControlEvents:UIControlEventTouchUpInside];
            return YES;
        }
    }
    for (UIView *subview in view.subviews) {
        if ([self findButtonWithTitle:title inView:subview]) return YES;
    }
    return NO;
}

// ============================================================
// MARK: - 🔥 البحث عن زر الإعلان
// ============================================================

- (void)startAdSearch {
    if (_isAdCompleted) return;
    if (_noAdTimer) [_noAdTimer invalidate];
    _noAdTimer = [NSTimer scheduledTimerWithTimeInterval:10.0
                                                  target:self
                                                selector:@selector(noAdFound)
                                                userInfo:nil
                                                 repeats:NO];
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) { [self retryAdSearch]; return; }
    UIViewController *rootVC = keyWindow.rootViewController;
    if (!rootVC) { [self retryAdSearch]; return; }
    [self findAndTapAdButtonInView:rootVC.view];
}

- (void)retryAdSearch {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self startAdSearch];
    });
}

- (void)findAndTapAdButtonInView:(UIView *)view {
    if (_isAdCompleted) return;
    NSArray *keywords = @[@"watch ad", @"شاهد الإعلان", @"مشاهدة إعلان", @"watch", @"شاهد", @"مشاهدة", @"reward", @"claim", @"إعلان", @"ad", @"view", @"get"];
    for (NSString *keyword in keywords) {
        if ([self findButtonWithKeyword:keyword inView:view]) {
            if (_noAdTimer) { [_noAdTimer invalidate]; _noAdTimer = nil; }
            _isAdFound = YES;
            if (_adWatchTimer) [_adWatchTimer invalidate];
            _adWatchTimer = [NSTimer scheduledTimerWithTimeInterval:65.0
                                                            target:self
                                                          selector:@selector(adFinished)
                                                          userInfo:nil
                                                           repeats:NO];
            _isAdCompleted = YES;
            return;
        }
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!_isAdCompleted) {
            [self findAndTapAdButtonInView:view];
        }
    });
}

- (BOOL)findButtonWithKeyword:(NSString *)keyword inView:(UIView *)view {
    if (_isAdCompleted) return NO;
    if ([view isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)view;
        NSString *btnTitle = [btn titleForState:UIControlStateNormal];
        if (btnTitle && [btnTitle rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
            [btn sendActionsForControlEvents:UIControlEventTouchUpInside];
            NSLog(@"[Injector] 🎬 تم الضغط على زر الإعلان (يحتوي على: %@)", keyword);
            return YES;
        }
    }
    for (UIView *subview in view.subviews) {
        if ([self findButtonWithKeyword:keyword inView:subview]) return YES;
    }
    return NO;
}

// ============================================================
// MARK: - انتهاء الإعلان أو عدم وجوده
// ============================================================

- (void)adFinished {
    if (_adWatchTimer) { [_adWatchTimer invalidate]; _adWatchTimer = nil; }
    if (_noAdTimer) { [_noAdTimer invalidate]; _noAdTimer = nil; }
    NSLog(@"[Injector] 🏁 انتهى الإعلان، الخروج...");
    [self performFullReset];
    dispatch_async(dispatch_get_main_queue(), ^{
        exit(0);
    });
}

- (void)noAdFound {
    if (_isAdFound) return;
    if (_noAdTimer) { [_noAdTimer invalidate]; _noAdTimer = nil; }
    if (_adWatchTimer) { [_adWatchTimer invalidate]; _adWatchTimer = nil; }
    NSLog(@"[Injector] ⚠️ لم يتم العثور على إعلان، الخروج...");
    [self performFullReset];
    dispatch_async(dispatch_get_main_queue(), ^{
        exit(0);
    });
}

@end

// ============================================================
// MARK: - الـ Hooks
// ============================================================

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[Injector sharedInstance] startAutoAdFlow];
        });
    });
}
%end

%hook CLLocationManager
- (void)startUpdatingLocation {
    updateAtlantaLocation();
    CLLocation *fakeLocation = [[CLLocation alloc] initWithLatitude:currentLat longitude:currentLon];
    if ([self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        [self.delegate locationManager:self didUpdateLocations:@[fakeLocation]];
    }
}
- (CLLocation *)location {
    updateAtlantaLocation();
    return [[CLLocation alloc] initWithLatitude:currentLat longitude:currentLon];
}
%end

%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    if (sessionFakeIP) {
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Forwarded-For"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"Client-IP"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Real-IP"];
    }
    NSString *urlString = request.URL.absoluteString;
    if (urlString) {
        logNetworkRequest(urlString, sessionFakeIP ?: @"غير محدد", currentLat, currentLon);
    }
    return %orig(mutableReq, completionHandler);
}
%end

%hook NSURLConnection
+ (void)sendAsynchronousRequest:(NSURLRequest *)request queue:(NSOperationQueue *)queue completionHandler:(void (^)(NSURLResponse *response, NSData *data, NSError *error))handler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    if (sessionFakeIP) {
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Forwarded-For"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"Client-IP"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Real-IP"];
    }
    NSString *urlString = request.URL.absoluteString;
    if (urlString) {
        logNetworkRequest(urlString, sessionFakeIP ?: @"غير محدد", currentLat, currentLon);
    }
    %orig(mutableReq, queue, handler);
}
%end

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return fakeAdvertisingID ?: %orig;
}
%end

// ============================================================
// MARK: - تهيئة التويك عند التحميل
// ============================================================

%ctor {
    updateAtlantaLocation();
    sessionFakeIP = @"172.56.0.0";
    fakeAdvertisingID = [NSUUID UUID];
    networkLogs = [[NSMutableArray alloc] init];
    NSLog(@"[Injector] 🚀 تم تحميل التويك التلقائي");
}
