#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>
#import <WebKit/WebKit.h>
#import <Security/Security.h>

// ============================================================
// MARK: - كلاس AgreeManager (محسَّن لمنع الكراش)
// ============================================================

@interface AgreeManager : NSObject
+ (instancetype)sharedInstance;
- (void)startLookingForAgreeButton;
@end

@implementation AgreeManager {
    BOOL _agreed;
    int _retryCount;
}

+ (instancetype)sharedInstance {
    static AgreeManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _agreed = NO;
        _retryCount = 0;
    }
    return self;
}

- (void)startLookingForAgreeButton {
    // تأخير 3 ثوانٍ لضمان ظهور النافذة
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self findAndTapAgree];
    });
}

- (void)findAndTapAgree {
    if (_agreed) return;
    if (_retryCount > 5) {
        NSLog(@"[AgreeManager] ⚠️ تمت المحاولة %d مرات دون العثور على الزر", _retryCount);
        return;
    }
    _retryCount++;
    
    @try {
        // التأكد من أن التطبيق نشط
        if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
            [self retryWithDelay:2.0];
            return;
        }
        
        // البحث في جميع النوافذ
        NSArray *windows = [UIApplication sharedApplication].windows;
        for (UIWindow *window in windows) {
            if (window.isHidden || window.windowLevel < UIWindowLevelNormal) continue;
            UIViewController *rootVC = window.rootViewController;
            if (!rootVC) continue;
            
            // البحث في الـ rootViewController وجميع الـ presentedViewControllers
            if ([self searchForAgreeInViewController:rootVC]) {
                return;
            }
        }
        
        // إذا لم نجد، نعيد المحاولة بتأخير
        [self retryWithDelay:1.0];
        
    } @catch (NSException *exception) {
        NSLog(@"[AgreeManager] ❌ استثناء: %@", exception);
        [self retryWithDelay:2.0];
    }
}

- (BOOL)searchForAgreeInViewController:(UIViewController *)vc {
    if (!vc) return NO;
    if (_agreed) return YES;
    
    // البحث في الـ view الحالي
    if ([self searchForAgreeInView:vc.view]) {
        return YES;
    }
    
    // البحث في الـ presentedViewController (مثل UIAlertController)
    if (vc.presentedViewController) {
        if ([self searchForAgreeInViewController:vc.presentedViewController]) {
            return YES;
        }
    }
    
    // البحث في أبناء الـ childViewControllers
    for (UIViewController *child in vc.childViewControllers) {
        if ([self searchForAgreeInViewController:child]) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)searchForAgreeInView:(UIView *)view {
    if (!view) return NO;
    if (_agreed) return YES;
    
    @try {
        if ([view isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)view;
            NSString *title = [btn titleForState:UIControlStateNormal];
            if (title) {
                NSString *lowerTitle = [title lowercaseString];
                // الكلمات المفتاحية للبحث (غير حساسة لحالة الأحرف)
                if ([lowerTitle containsString:@"agree"] ||
                    [lowerTitle containsString:@"موافق"] ||
                    [lowerTitle containsString:@"accept"] ||
                    [lowerTitle containsString:@"allow"]) {
                    
                    // التأكد من أن الزر مرئي وقابل للتفاعل
                    if (!btn.hidden && btn.enabled) {
                        [btn sendActionsForControlEvents:UIControlEventTouchUpInside];
                        _agreed = YES;
                        NSLog(@"[AgreeManager] ✅ تم الضغط على زر '%@'", title);
                        return YES;
                    }
                }
            }
        }
        
        for (UIView *subview in view.subviews) {
            if ([self searchForAgreeInView:subview]) {
                return YES;
            }
        }
        
    } @catch (NSException *exception) {
        NSLog(@"[AgreeManager] ❌ خطأ في البحث في view: %@", exception);
    }
    
    return NO;
}

- (void)retryWithDelay:(NSTimeInterval)delay {
    if (_agreed) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self findAndTapAgree];
    });
}

@end

// ============================================================
// MARK: - المتغيرات العامة (كما هي)
// ============================================================

static double currentLat = 0.0;
static double currentLon = 0.0;
static NSString *sessionFakeIP = nil;
static NSString *currentRealIP = @"جاري الجلب...";
static NSMutableArray *networkLogs = nil;
static NSUUID *fakeAdvertisingID = nil;

// ============================================================
// MARK: - دوال مساعدة (IP، موقع، Keychain، ...) - نفس الكود السابق
// ============================================================

double randomInRange(double min, double max) {
    return min + (arc4random_uniform(UINT32_MAX) / (double)UINT32_MAX) * (max - min);
}

void updateAtlantaLocation() {
    currentLat = randomInRange(33.7000, 33.8000);
    currentLon = randomInRange(-84.4500, -84.3500);
}

NSArray *generate10IPs() {
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

BOOL verifyIPQuality(NSString *ip) {
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

void generateSessionIP() {
    NSArray *candidates = generate10IPs();
    NSString *selectedIP = nil;
    for (NSString *ip in candidates) {
        if (verifyIPQuality(ip)) {
            selectedIP = ip;
            NSLog(@"[Injector] ✅ IP سكني: %@", ip);
            break;
        }
    }
    if (!selectedIP) selectedIP = candidates.lastObject;
    sessionFakeIP = selectedIP;
}

void generateFakeAdvertisingID() {
    fakeAdvertisingID = [NSUUID UUID];
}

void fetchRealIP() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURL *url = [NSURL URLWithString:@"https://api.ipify.org"];
        NSString *ip = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
        if (ip && ip.length > 0) {
            currentRealIP = ip;
        } else {
            currentRealIP = @"غير قادر على الجلب";
        }
    });
}

void logNetworkRequest(NSString *urlStr, NSString *ip, double lat, double lon) {
    if (!networkLogs) {
        networkLogs = [[NSMutableArray alloc] init];
    }
    NSURL *url = [NSURL URLWithString:urlStr];
    NSString *path = url.path ? url.path : urlStr;
    if (path.length > 30) {
        path = [[path substringToIndex:30] stringByAppendingString:@"..."];
    }
    NSString *logEntry = [NSString stringWithFormat:@"🔗 الرابط: %@\n🌐 خرج عبر IP: %@\n📍 الموقع: (%.4f, %.4f)", path, ip, lat, lon];
    @synchronized(networkLogs) {
        [networkLogs insertObject:logEntry atIndex:0];
        if (networkLogs.count > 15) {
            [networkLogs removeLastObject];
        }
    }
}

// ============================================================
// MARK: - دوال المسح (Keychain، كوكيز، كاش، ملفات) - كما هي
// ============================================================

void clearKeychainKeepingAccount() {
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
    NSLog(@"[Injector] ✅ Keychain مسح مع بقاء الحساب");
}

void clearAllCookies() {
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
        [cookieStorage deleteCookie:cookie];
    }
    NSSet *dataTypes = [NSSet setWithObject:WKWebsiteDataTypeCookies];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:dataTypes modifiedSince:[NSDate distantPast] completionHandler:^{}];
    NSSet *allWebTypes = [WKWebsiteDataStore allWebsiteDataTypes];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:allWebTypes modifiedSince:[NSDate distantPast] completionHandler:^{}];
    NSLog(@"[Injector] 🗑️ الكوكيز و WebKit مسحوا");
}

void clearNetworkCache() {
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    [[NSURLCache sharedURLCache] setDiskCapacity:0];
    [[NSURLCache sharedURLCache] setMemoryCapacity:0];
}

void clearAllLocalFiles() {
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
    NSLog(@"[Injector] 🗑️ الملفات المحلية مسحت (عدا Preferences)");
}

// ============================================================
// MARK: - إعادة الضبط الكاملة
// ============================================================

void performFullReset() {
    NSLog(@"[Injector] 🔄 بدء إعادة الضبط...");
    clearKeychainKeepingAccount();
    clearAllCookies();
    clearNetworkCache();
    clearAllLocalFiles();
    updateAtlantaLocation();
    generateSessionIP();
    generateFakeAdvertisingID();
    fetchRealIP();
    @synchronized(networkLogs) { [networkLogs removeAllObjects]; }
    NSLog(@"[Injector] ✅ اكتملت إعادة الضبط. IP: %@", sessionFakeIP);
}

// ============================================================
// MARK: - واجهة عرض التفاصيل (كما هي)
// ============================================================

@interface AtlantaReportViewController : UIViewController
@end

@implementation AtlantaReportViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scrollView];
    NSString *udidStr = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    NSString *idfaStr = fakeAdvertisingID ? [fakeAdvertisingID UUIDString] : [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    NSString *locationInfo = [NSString stringWithFormat:@"📍 أتلانتا:\nLat: %.4f\nLon: %.4f", currentLat, currentLon];
    NSString *ipInfo = [NSString stringWithFormat:@"🌐 IP وهمي: %@\n🛡️ IP حقيقي: %@", sessionFakeIP ?: @"غير محدد", currentRealIP];
    NSString *identsInfo = [NSString stringWithFormat:@"🆔 UDID (حقيقي): %@\nIDFA (وهمي): %@", udidStr, idfaStr];
    NSString *logsText = @"";
    @synchronized(networkLogs) {
        logsText = networkLogs.count ? [networkLogs componentsJoinedByString:@"\n\n---\n\n"] : @"لا توجد طلبات بعد.";
    }
    NSString *fullReport = [NSString stringWithFormat:@"%@\n\n%@\n\n%@\n\n📋 الطلبات:\n%@", locationInfo, ipInfo, identsInfo, logsText];
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 80, self.view.bounds.size.width - 40, 0)];
    label.text = fullReport;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:13];
    label.numberOfLines = 0;
    [label sizeToFit];
    scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, label.frame.size.height + 160);
    [scrollView addSubview:label];
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(20, 30, 80, 35);
    closeBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:1.0];
    [closeBtn setTitle:@"إغلاق" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.layer.cornerRadius = 8;
    [closeBtn addTarget:self action:@selector(dismissPopup) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeBtn];
}
- (void)dismissPopup { [self dismissViewControllerAnimated:YES completion:nil]; }
@end

// ============================================================
// MARK: - النافذة العائمة والزر
// ============================================================

@interface AtlantaWindow : UIWindow
@end
@implementation AtlantaWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *btn = [self viewWithTag:999888];
    return (btn && CGRectContainsPoint(btn.frame, point));
}
@end

@interface AtlantaInfoManager : NSObject
@property (strong, nonatomic) AtlantaWindow *floatingWindow;
@property (strong, nonatomic) UIButton *floatingBtn;
+ (instancetype)sharedInstance;
- (void)setupFloatingButton;
@end

@implementation AtlantaInfoManager
+ (instancetype)sharedInstance {
    static AtlantaInfoManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ sharedInstance = [[self alloc] init]; });
    return sharedInstance;
}
- (void)setupFloatingButton {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.floatingWindow) return;
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        self.floatingWindow = [[AtlantaWindow alloc] initWithFrame:screenBounds];
        self.floatingWindow.windowLevel = UIWindowLevelAlert + 1000;
        self.floatingWindow.hidden = NO;
        self.floatingWindow.backgroundColor = [UIColor clearColor];
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        self.floatingWindow.rootViewController = vc;
        self.floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.floatingBtn.tag = 999888;
        self.floatingBtn.frame = CGRectMake(20, 120, 60, 60);
        self.floatingBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.47 blue:1.0 alpha:0.9];
        [self.floatingBtn setTitle:@"🔄" forState:UIControlStateNormal];
        [self.floatingBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.floatingBtn.titleLabel.font = [UIFont boldSystemFontOfSize:24];
        self.floatingBtn.layer.cornerRadius = 30;
        self.floatingBtn.layer.shadowColor = [UIColor blackColor].CGColor;
        self.floatingBtn.layer.shadowOffset = CGSizeMake(0, 2);
        self.floatingBtn.layer.shadowOpacity = 0.5;
        self.floatingBtn.layer.shadowRadius = 5;
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self.floatingBtn addGestureRecognizer:pan];
        [self.floatingBtn addTarget:self action:@selector(handleReset) forControlEvents:UIControlEventTouchUpInside];
        [vc.view addSubview:self.floatingBtn];
    });
}
- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIView *btn = gesture.view;
    CGPoint translation = [gesture translationInView:btn.superview];
    CGFloat newX = btn.center.x + translation.x;
    CGFloat newY = btn.center.y + translation.y;
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    newX = MAX(30, MIN(screenSize.width - 30, newX));
    newY = MAX(40, MIN(screenSize.height - 40, newY));
    btn.center = CGPointMake(newX, newY);
    [gesture setTranslation:CGPointZero inView:btn.superview];
}
- (void)handleReset {
    performFullReset();
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIViewController *rootVC = keyWindow.rootViewController;
    while (rootVC.presentedViewController) rootVC = rootVC.presentedViewController;
    UIAlertController *done = [UIAlertController alertControllerWithTitle:@"تم"
                                                                  message:@"تم مسح البيانات وتجديد الهوية."
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [done addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
    [rootVC presentViewController:done animated:YES completion:nil];
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
        // بعد 1 ثانية من ظهور أول واجهة: مسح البيانات
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            performFullReset();
            // بعد 3 ثوانٍ من المسح: البحث عن زر الموافقة (تأخير كافٍ لظهور النافذة)
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[AgreeManager sharedInstance] startLookingForAgreeButton];
            });
        });
    });
}
%end

%ctor {
    updateAtlantaLocation();
    generateSessionIP();
    generateFakeAdvertisingID();
    fetchRealIP();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[AtlantaInfoManager sharedInstance] setupFloatingButton];
    });
}

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
