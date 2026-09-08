#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>
#import <WebKit/WebKit.h>
#import <Security/Security.h>

// ============================================================
// MARK: - المتغيرات العامة
// ============================================================

static double currentLat = 0.0;
static double currentLon = 0.0;
static NSString *sessionFakeIP = nil;
static NSString *sessionIPType = @"جاهز للبدء...";
static NSString *ipSourceStatus = @"محمي وآمن...";
static NSString *currentRealIP = @"جاري الجلب...";
static NSMutableArray *networkLogs = nil;

// المعرفات المزيفة
static NSString *fakeAdvertisingIDString = nil;
static NSString *fakeUDIDString = nil; 

// واجهة الشريط العلوي
static UILabel *topStatusBarLabel = nil;

// ============================================================
// MARK: - دوال توليد المعرفات (بصيغة متوافقة تماماً مع نظام أبل)
// ============================================================

NSString *generateRandomUUIDString() {
    return [[NSUUID UUID] UUIDString];
}

NSString *generateRandomUDID() {
    NSString *letters = @"0123456789abcdef";
    NSMutableString *randomHex1 = [NSMutableString stringWithCapacity:8];
    NSMutableString *randomHex2 = [NSMutableString stringWithCapacity:12];
    
    for (int i = 0; i < 8; i++) {
        [randomHex1 appendFormat:@"%C", [letters characterAtIndex:arc4random_uniform((uint32_t)[letters length])]];
    }
    for (int i = 0; i < 12; i++) {
        [randomHex2 appendFormat:@"%C", [letters characterAtIndex:arc4random_uniform((uint32_t)[letters length])]];
    }
    
    return [NSString stringWithFormat:@"00008130-%@-%@", randomHex1, randomHex2];
}

// ============================================================
// MARK: - دوال مساعدة طبيعية
// ============================================================

double randomInRange(double min, double max) {
    return min + (arc4random_uniform(UINT32_MAX) / (double)UINT32_MAX) * (max - min);
}

void updateAtlantaLocation() {
    // إحداثيات دقيقة داخل نطاق مدينة أتلانطا (ولاية جورجيا) لتتوافق مع مزود الخدمة
    currentLat = randomInRange(33.7400, 33.7900);
    currentLon = randomInRange(-84.4200, -84.3600);
}

void updateTopBarDisplay() {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (topStatusBarLabel) {
            topStatusBarLabel.text = [NSString stringWithFormat:@"🌐 IP: %@ | 🏢 AT&T | 🛡️ محمي للإعلانات", sessionFakeIP ?: @"اضغط الزر الأزرق للتوليد"];
        }
    });
}

// ============================================================
// MARK: - توليد IP واقعي وغير مكشوف (خاص بنطاقات AT&T)
// ============================================================

void generateSessionIPReal() {
    // تفعيل توزيع عشوائي دقيق للأرقام لتبدو مثل شبكة منزلية حقيقية Residential
    NSArray *prefixPool = @[@"174.56", @"108.200", @"174.58", @"108.202"];
    NSString *selectedPrefix = prefixPool[arc4random_uniform((uint32_t)prefixPool.count)];
    
    int thirdOctet = arc4random_uniform(150) + 20;
    int fourthOctet = arc4random_uniform(200) + 15;
    
    sessionFakeIP = [NSString stringWithFormat:@"%@.%d.%d", selectedPrefix, thirdOctet, fourthOctet];
    sessionIPType = @"AT&T Fiber/DSL (Residential)";
    ipSourceStatus = @"✨ موثوق تماماً لشركات الإعلانات";
    
    updateTopBarDisplay();
}

void fetchRealIP() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURL *url = [NSURL URLWithString:@"https://api.ipify.org"];
        NSString *ip = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
        if (ip && ip.length > 0) {
            currentRealIP = ip;
        }
    });
}

void logNetworkRequest(NSString *urlStr, NSString *ip, NSString *ispType, NSString *sourceStatus, double lat, double lon) {
    if (!networkLogs) {
        networkLogs = [[NSMutableArray alloc] init];
    }
    NSURL *url = [NSURL URLWithString:urlStr];
    NSString *path = url.path ? url.path : urlStr;
    if (path.length > 35) {
        path = [[path substringToIndex:35] stringByAppendingString:@"..."];
    }
    NSString *logEntry = [NSString stringWithFormat:@"🔗 الرابط: %@\n🌐 IP: %@\n🏢 النوع: %@\n📍 الموقع: (%.4f, %.4f)", path, ip, ispType, lat, lon];
    @synchronized(networkLogs) {
        [networkLogs insertObject:logEntry atIndex:0];
        if (networkLogs.count > 20) {
            [networkLogs removeLastObject];
        }
    }
}

// ============================================================
// MARK: - التطهير الآمن (حفظ الحساب + تنظيف الذاكرة المؤقتة لمنع الحظر)
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
}

void clearAllCookiesAndCache() {
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
        [cookieStorage deleteCookie:cookie];
    }
    
    NSSet *dataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:dataTypes modifiedSince:[NSDate distantPast] completionHandler:^{}];
    
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    [[NSURLCache sharedURLCache] setDiskCapacity:0];
    [[NSURLCache sharedURLCache] setMemoryCapacity:0];
}

// ============================================================
// MARK: - التنفيذ المدروس عبر الزر الأزرق
// ============================================================

void performFullResetWithNewIDs() {
    // 1. تنظيف الكوكيز والكاش مع الحفاظ على الحساب
    clearKeychainKeepingAccount();
    clearAllCookiesAndCache();
    
    // 2. توليد هوية وشبكة جديدة بالكامل بشكل غير مكشوف
    generateSessionIPReal();
    fakeAdvertisingIDString = generateRandomUUIDString();
    fakeUDIDString = generateRandomUDID();
    updateAtlantaLocation();
    
    @synchronized(networkLogs) {
        [networkLogs removeAllObjects];
    }
    
    // 3. تأخير زمني آمن (2.5 ثانية) لضمان استقرار البيئة قبل إعادة التشغيل الطبيعية
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        exit(0);
    });
}

// ============================================================
// MARK: - واجهة الزر العائم
// ============================================================

@interface AtlantaWindow : UIWindow
@end

@implementation AtlantaWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *btn1 = [self viewWithTag:999888];
    if (btn1 && CGRectContainsPoint(btn1.frame, point)) {
        return YES;
    }
    return NO;
}
@end

@interface AtlantaInfoManager : NSObject
@property (strong, nonatomic) AtlantaWindow *floatingWindow;
@property (strong, nonatomic) UIButton *resetBtn;
+ (instancetype)sharedInstance;
- (void)setupFloatingUI;
@end

@implementation AtlantaInfoManager

+ (instancetype)sharedInstance {
    static AtlantaInfoManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (void)setupFloatingUI {
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
        
        // الشريط العلوي
        UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenBounds.size.width, 44)];
        topBar.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.85];
        
        topStatusBarLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 0, screenBounds.size.width - 10, 44)];
        topStatusBarLabel.textColor = [UIColor greenColor];
        topStatusBarLabel.font = [UIFont boldSystemFontOfSize:10];
        topStatusBarLabel.textAlignment = NSTextAlignmentCenter;
        [topBar addSubview:topStatusBarLabel];
        [vc.view addSubview:topBar];
        
        // الزر الأزرق الوحيد (🔄)
        self.resetBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.resetBtn.tag = 999888;
        self.resetBtn.frame = CGRectMake(20, 100, 55, 55);
        self.resetBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.47 blue:1.0 alpha:0.9];
        [self.resetBtn setTitle:@"🔄" forState:UIControlStateNormal];
        [self.resetBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.resetBtn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
        self.resetBtn.layer.cornerRadius = 27.5;
        self.resetBtn.layer.shadowColor = [UIColor blackColor].CGColor;
        self.resetBtn.layer.shadowOffset = CGSizeMake(0, 2);
        self.resetBtn.layer.shadowOpacity = 0.5;
        self.resetBtn.layer.shadowRadius = 4;
        
        UIPanGestureRecognizer *pan1 = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self.resetBtn addGestureRecognizer:pan1];
        [self.resetBtn addTarget:self action:@selector(handleReset) forControlEvents:UIControlEventTouchUpInside];
        
        [vc.view addSubview:self.resetBtn];
        
        updateTopBarDisplay();
    });
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIView *targetView = gesture.view;
    CGPoint translation = [gesture translationInView:targetView.superview];
    CGFloat newX = targetView.center.x + translation.x;
    CGFloat newY = targetView.center.y + translation.y;
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    newX = MAX(30, MIN(screenSize.width - 30, newX));
    newY = MAX(60, MIN(screenSize.height - 40, newY));
    targetView.center = CGPointMake(newX, newY);
    [gesture setTranslation:CGPointZero inView:targetView.superview];
}

- (void)handleReset {
    performFullResetWithNewIDs();
}

@end

// ============================================================
// MARK: - الـ Hooks الآمنة
// ============================================================

%ctor {
    updateAtlantaLocation();
    fakeAdvertisingIDString = generateRandomUUIDString();
    fakeUDIDString = generateRandomUDID();
    fetchRealIP();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[AtlantaInfoManager sharedInstance] setupFloatingUI];
    });
}

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    if (fakeAdvertisingIDString) {
        return [[NSUUID alloc] initWithUUIDString:fakeAdvertisingIDString];
    }
    return %orig;
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
        logNetworkRequest(urlString, sessionFakeIP ?: @"غير محدد", sessionIPType ?: @"Residential", ipSourceStatus ?: @"غير معروف", currentLat, currentLon);
    }
    return %orig(mutableReq, completionHandler);
}
%end
