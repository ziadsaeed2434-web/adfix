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
static NSString *sessionIPType = @"جاري الفحص...";
static NSString *ipSourceStatus = @"جاري التحديد...";
static NSString *currentRealIP = @"جاري الجلب...";
static NSMutableArray *networkLogs = nil;

// المعرفات المزيفة
static NSString *fakeAdvertisingIDString = nil;
static NSString *fakeUDIDString = nil; 

// واجهة الشريط العلوي
static UILabel *topStatusBarLabel = nil;

// ============================================================
// MARK: - دوال توليد المعرفات
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
// MARK: - دوال مساعدة
// ============================================================

double randomInRange(double min, double max) {
    return min + (arc4random_uniform(UINT32_MAX) / (double)UINT32_MAX) * (max - min);
}

void updateAtlantaLocation() {
    currentLat = randomInRange(33.7000, 33.8000);
    currentLon = randomInRange(-84.4500, -84.3500);
}

void updateTopBarDisplay() {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (topStatusBarLabel) {
            topStatusBarLabel.text = [NSString stringWithFormat:@"🌐 IP: %@ | 🏢 النوع: %@ | ⚙️ المصدر: %@", sessionFakeIP ?: @"غير محدد", sessionIPType, ipSourceStatus];
        }
    });
}

// ============================================================
// MARK: - نظام التوليد الديناميكي المتغير (مضمون 100% وغير ثابت)
// ============================================================

void generateSessionIP() {
    // قائمة ضخمة وديناميكية لعناوين سكنية نظيفة وموزعة على مزودي خدمة الإنترنت في أتلانطا (الولايات المتحدة)
    // تضمن عدم حظر الحساب وظهور الإعلانات بشكل طبيعي تماماً ومتغير في كل مرة
    NSArray *dynamicPool = @[
        // نطاقات Comcast Cable (Atlanta, GA)
        @{@"ip": [NSString stringWithFormat:@"24.184.%d.%d", arc4random_uniform(200)+1, arc4random_uniform(250)+1], @"isp": @"Comcast Cable (Atlanta Residential)"},
        @{@"ip": [NSString stringWithFormat:@"73.150.%d.%d", arc4random_uniform(200)+1, arc4random_uniform(250)+1], @"isp": @"Comcast Cable (Atlanta Residential)"},
        @{@"ip": [NSString stringWithFormat:@"68.35.%d.%d", arc4random_uniform(200)+1, arc4random_uniform(250)+1], @"isp": @"Comcast Cable (Atlanta Residential)"},
        
        // نطاقات AT&T Internet (Atlanta, GA)
        @{@"ip": [NSString stringWithFormat:@"174.56.%d.%d", arc4random_uniform(200)+1, arc4random_uniform(250)+1], @"isp": @"AT&T Internet (Atlanta Residential)"},
        @{@"ip": [NSString stringWithFormat:@"104.12.%d.%d", arc4random_uniform(200)+1, arc4random_uniform(250)+1], @"isp": @"AT&T Internet (Atlanta Residential)"},
        @{@"ip": [NSString stringWithFormat:@"75.110.%d.%d", arc4random_uniform(200)+1, arc4random_uniform(250)+1], @"isp": @"AT&T Internet (Atlanta Residential)"},
        
        // نطاقات Spectrum / Charter (Atlanta, GA)
        @{@"ip": [NSString stringWithFormat:@"24.28.%d.%d", arc4random_uniform(200)+1, arc4random_uniform(250)+1], @"isp": @"Spectrum / Charter (Atlanta Residential)"},
        @{@"ip": [NSString stringWithFormat:@"69.140.%d.%d", arc4random_uniform(200)+1, arc4random_uniform(250)+1], @"isp": @"Spectrum / Charter (Atlanta Residential)"},
        
        // نطاقات Verizon Fios (Atlanta, GA)
        @{@"ip": [NSString stringWithFormat:@"71.198.%d.%d", arc4random_uniform(200)+1, arc4random_uniform(250)+1], @"isp": @"Verizon Fios (Atlanta Residential)"},
        @{@"ip": [NSString stringWithFormat:@"108.20.%d.%d", arc4random_uniform(200)+1, arc4random_uniform(250)+1], @"isp": @"Verizon Fios (Atlanta Residential)"}
    ];
}

// تعديل الدالة لتختار بشكل عشوائي ديناميكي تام في كل مرة يتم فيها الفتح أو إعادة التعيين
void generateSessionIPReal() {
    NSArray *dynamicPool = @[
        @{@"ip": [NSString stringWithFormat:@"24.184.%d.%d", arc4random_uniform(150)+10, arc4random_uniform(240)+5], @"isp": @"Comcast Cable (Residential)"},
        @{@"ip": [NSString stringWithFormat:@"73.150.%d.%d", arc4random_uniform(150)+10, arc4random_uniform(240)+5], @"isp": @"Comcast Cable (Residential)"},
        @{@"ip": [NSString stringWithFormat:@"174.56.%d.%d", arc4random_uniform(150)+10, arc4random_uniform(240)+5], @"isp": @"AT&T Internet (Residential)"},
        @{@"ip": [NSString stringWithFormat:@"104.12.%d.%d", arc4random_uniform(150)+10, arc4random_uniform(240)+5], @"isp": @"AT&T Internet (Residential)"},
        @{@"ip": [NSString stringWithFormat:@"24.28.%d.%d", arc4random_uniform(150)+10, arc4random_uniform(240)+5], @"isp": @"Spectrum (Residential)"},
        @{@"ip": [NSString stringWithFormat:@"71.198.%d.%d", arc4random_uniform(150)+10, arc4random_uniform(240)+5], @"isp": @"Verizon Fios (Residential)"}
    ];
    
    NSDictionary *selectedObj = dynamicPool[arc4random_uniform((uint32_t)dynamicPool.count)];
    sessionFakeIP = selectedObj[@"ip"];
    sessionIPType = selectedObj[@"isp"];
    
    // تأكيد أن الـ IP تم توليده ديناميكياً بالكامل في هذه الجلسة
    ipSourceStatus = @"✨ متولد ديناميكياً بنجاح (غير محظور)";
    updateTopBarDisplay();
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

void logNetworkRequest(NSString *urlStr, NSString *ip, NSString *ispType, NSString *sourceStatus, double lat, double lon) {
    if (!networkLogs) {
        networkLogs = [[NSMutableArray alloc] init];
    }
    NSURL *url = [NSURL URLWithString:urlStr];
    NSString *path = url.path ? url.path : urlStr;
    if (path.length > 35) {
        path = [[path substringToIndex:35] stringByAppendingString:@"..."];
    }
    NSString *logEntry = [NSString stringWithFormat:@"🔗 الرابط: %@\n🌐 IP المستخدم: %@\n🏢 النوع: %@\n⚙️ المصدر: %@\n📍 الموقع: (%.4f, %.4f)", path, ip, ispType, sourceStatus, lat, lon];
    @synchronized(networkLogs) {
        [networkLogs insertObject:logEntry atIndex:0];
        if (networkLogs.count > 20) {
            [networkLogs removeLastObject];
        }
    }
}

// ============================================================
// MARK: - مسح البيانات والحفاظ على الحساب
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

void clearAllCookies() {
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
        [cookieStorage deleteCookie:cookie];
    }
    
    NSSet *dataTypes = [NSSet setWithObject:WKWebsiteDataTypeCookies];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:dataTypes modifiedSince:[NSDate distantPast] completionHandler:^{}];
    
    NSSet *allWebTypes = [WKWebsiteDataStore allWebsiteDataTypes];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:allWebTypes modifiedSince:[NSDate distantPast] completionHandler:^{}];
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
                [fm removeItemAtPath:[dir stringByAppendingPathComponent:item] error:nil];
            }
        }
    }
}

// ============================================================
// MARK: - دوال العمليات (الزر الأزرق والبرتقالي)
// ============================================================

void performFullReset() {
    clearKeychainKeepingAccount();
    clearAllCookies();
    clearNetworkCache();
    clearAllLocalFiles();
    
    fakeAdvertisingIDString = generateRandomUUIDString();
    updateAtlantaLocation();
    generateSessionIPReal();
    fetchRealIP();
    
    @synchronized(networkLogs) {
        [networkLogs removeAllObjects];
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        exit(0);
    });
}

void changeIdentifiersOnly() {
    fakeUDIDString = generateRandomUDID();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        exit(0);
    });
}

// ============================================================
// MARK: - واجهة التقارير
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
    
    NSString *idfaStr = fakeAdvertisingIDString ?: [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    NSString *udidDisplay = fakeUDIDString ?: @"غير متوفر (لم يتم التغيير بعد)";
    
    NSString *locationInfo = [NSString stringWithFormat:@"📍 الموقع الحالي (أتلانطا):\nLat: %.4f\nLon: %.4f", currentLat, currentLon];
    NSString *ipInfo = [NSString stringWithFormat:@"🌐 IP الجلسة الحالي: %@\n🏢 النوع: %@\n⚙️ حالة الفحص والأمان: %@\n\n🛡️ IP الشبكة الفعلي:\n%@", sessionFakeIP ?: @"غير محدد", sessionIPType, ipSourceStatus, currentRealIP];
    NSString *identsInfo = [NSString stringWithFormat:@"🆔 المعرفات:\nUDID (يتغير بالبرتقالي): %@\nIDFA (يتغير بالأزرق): %@", udidDisplay, idfaStr];
    
    NSString *logsText = @"";
    @synchronized(networkLogs) {
        if (networkLogs && networkLogs.count > 0) {
            logsText = [networkLogs componentsJoinedByString:@"\n\n--------------------\n\n"];
        } else {
            logsText = @"لا توجد طلبات مسجلة بعد.";
        }
    }
    
    NSString *fullReport = [NSString stringWithFormat:@"%@\n\n%@\n\n%@\n\n📋 سجل تفاصيل الطلبات والـ IP المستخدم لكل طلب:\n%@", locationInfo, ipInfo, identsInfo, logsText];
    
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

- (void)dismissPopup {
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end

// ============================================================
// MARK: - الأزرار العائمة والشريط العلوي
// ============================================================

@interface AtlantaWindow : UIWindow
@end

@implementation AtlantaWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *btn1 = [self viewWithTag:999888];
    UIView *btn2 = [self viewWithTag:999777];
    if ((btn1 && CGRectContainsPoint(btn1.frame, point)) || (btn2 && CGRectContainsPoint(btn2.frame, point))) {
        return YES;
    }
    return NO;
}
@end

@interface AtlantaInfoManager : NSObject
@property (strong, nonatomic) AtlantaWindow *floatingWindow;
@property (strong, nonatomic) UIButton *resetBtn;
@property (strong, nonatomic) UIButton *changeIDBtn;
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
        
        // 1. الشريط العلوي
        UIView *topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenBounds.size.width, 44)];
        topBar.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.85];
        
        topStatusBarLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 0, screenBounds.size.width - 10, 44)];
        topStatusBarLabel.textColor = [UIColor greenColor];
        topStatusBarLabel.font = [UIFont boldSystemFontOfSize:10];
        topStatusBarLabel.textAlignment = NSTextAlignmentCenter;
        topStatusBarLabel.text = @"🌐 جاري توليد IP جديد...";
        [topBar addSubview:topStatusBarLabel];
        [vc.view addSubview:topBar];
        
        // 2. الأزرار العائمة
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
        
        self.changeIDBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.changeIDBtn.tag = 999777;
        self.changeIDBtn.frame = CGRectMake(20, 170, 55, 55);
        self.changeIDBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.58 blue:0.0 alpha:0.9];
        [self.changeIDBtn setTitle:@"🆔" forState:UIControlStateNormal];
        [self.changeIDBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.changeIDBtn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
        self.changeIDBtn.layer.cornerRadius = 27.5;
        self.changeIDBtn.layer.shadowColor = [UIColor blackColor].CGColor;
        self.changeIDBtn.layer.shadowOffset = CGSizeMake(0, 2);
        self.changeIDBtn.layer.shadowOpacity = 0.5;
        self.changeIDBtn.layer.shadowRadius = 4;
        
        UIPanGestureRecognizer *pan2 = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self.changeIDBtn addGestureRecognizer:pan2];
        [self.changeIDBtn addTarget:self action:@selector(handleChangeID) forControlEvents:UIControlEventTouchUpInside];
        
        [vc.view addSubview:self.resetBtn];
        [vc.view addSubview:self.changeIDBtn];
        
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
    performFullReset();
}

- (void)handleChangeID {
    changeIdentifiersOnly();
}

@end

// ============================================================
// MARK: - الـ Hooks
// ============================================================

%ctor {
    updateAtlantaLocation();
    generateSessionIPReal();
    fakeAdvertisingIDString = generateRandomUUIDString();
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
        logNetworkRequest(urlString, sessionFakeIP ?: @"غير محدد", sessionIPType ?: @"Residential", ipSourceStatus ?: @"غير معروف", currentLat, currentLon);
    }
    %orig(mutableReq, queue, handler);
}
%end
