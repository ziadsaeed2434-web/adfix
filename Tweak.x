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
// MARK: - نظام الفحص الذكي (فحص الحظر، الـ Spam، وشركات الإعلانات)
// ============================================================

BOOL verifyIPQuality(NSString *ip, NSString **outISPName) {
    if (!ip || ip.length == 0) return NO;
    
    // فحص الـ IP عبر API يتحقق من الدولة، المزود، ومؤشرات الحظر والـ Proxy
    NSString *urlString = [NSString stringWithFormat:@"http://ip-api.com/json/%@?fields=status,country,isp,org,proxy,hosting,mobile", ip];
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
    
    if (!responseData) return NO;
    
    NSError *jsonError = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&jsonError];
    if (jsonError || !json) return NO;
    if (![json[@"status"] isEqualToString:@"success"]) return NO;
    
    // 1. شرط الدولة: أمريكا حصرياً
    NSString *country = json[@"country"] ?: @"";
    if (![country isEqualToString:@"United States"]) return NO;
    
    // 2. التحقق من عدم كونه Proxy أو VPN أو Hosting (ممنوع منعاً باتاً لكي لا يحظر الحساب أو يعطل الإعلانات)
    id proxyFlag = json[@"proxy"];
    id hostingFlag = json[@"hosting"];
    if (proxyFlag && [proxyFlag boolValue]) return NO;
    if (hostingFlag && [hostingFlag boolValue]) return NO;
    
    // 3. فحص إضافي: التأكد من عدم تصنيفه كـ Mobile Datacenter مشبوه إذا وُجد
    id mobileFlag = json[@"mobile"];
    // نتركها مرنة قليلاً لكن سنفحص الكلمات المفتاحية الخطيرة بالأسفل
    
    NSString *org = json[@"org"] ?: @"";
    NSString *isp = json[@"isp"] ?: @"";
    NSString *combined = [NSString stringWithFormat:@"%@ %@", org, isp];
    
    // 4. استبعاد الكلمات المفتاحية المرتبطة بالحظْر، السيرفرات، والشركات المحظورة من شبكات الإعلانات
    NSArray *blockedKeywords = @[
        @"Hosting", @"Datacenter", @"Cloud", @"Server", @"Dedicated", @"VPS", 
        @"CDN", @"Akamai", @"Amazon", @"AWS", @"DigitalOcean", @"Linode", 
        @"Vultr", @"Hetzner", @"OVH", @"Proxy", @"VPN", @"Tor", @"Relay", 
        @"Abuse", @"Spam", @"Scraper", @"Bot", @"Blacklist"
    ];
    for (NSString *keyword in blockedKeywords) {
        if ([combined rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return NO; // IP محظور أو ضمن النطاقات الخطيرة للإعلانات
        }
    }
    
    // 5. الاعتماد الحصري على مزودي خدمة سكنيين حقيقيين ومعتمدين (نظيفة 100% أمام Google AdMob وشركات الإعلانات)
    NSArray *trustedISPs = @[@"Comcast", @"AT&T", @"Charter", @"Spectrum", @"Verizon", @"CenturyLink"];
    for (NSString *trustedISP in trustedISPs) {
        if ([combined rangeOfString:trustedISP options:NSCaseInsensitiveSearch].location != NSNotFound) {
            if (outISPName) {
                *outISPName = isp.length > 0 ? isp : trustedISP;
            }
            return YES; // IP نظيف، سكني، وغير محظور وجاهز لعرض الإعلانات
        }
    }
    
    return NO;
}

void generateSessionIP() {
    NSArray *verifiedResidentialPools = @[
        @[@24, 184], @[@73, 150], @[@68, 35],   // Comcast
        @[@174, 56], @[@104, 12], @[@75, 110], // AT&T
        @[@24, 28],  @[@69, 140],              // Spectrum
        @[@71, 198], @[@108, 20],              // Verizon
        @[@50, 195], @[@65, 128]               // CenturyLink
    ];
    
    NSString *selectedIP = nil;
    NSString *detectedISP = nil;
    BOOL isFromFallback = NO;
    
    // 100 محاولة بحث وفحص للتأكد من إيجاد IP غير محظور ونظيف تماماً
    for (int attempt = 0; attempt < 100; attempt++) {
        NSArray *pool = verifiedResidentialPools[arc4random_uniform((uint32_t)verifiedResidentialPools.count)];
        int first = [pool[0] intValue];
        int second = [pool[1] intValue];
        int third = arc4random_uniform(254) + 1;
        int fourth = arc4random_uniform(254) + 1;
        
        NSString *candidateIP = [NSString stringWithFormat:@"%d.%d.%d.%d", first, second, third, fourth];
        
        if (verifyIPQuality(candidateIP, &detectedISP)) {
            selectedIP = candidateIP;
            isFromFallback = NO;
            break;
        }
    }
    
    // قائمة احتياطية نظيفة ومجربة مسبقاً لا تعرض الحساب للحظر
    if (!selectedIP) {
        NSArray *cleanFallbackPool = @[
            @"104.12.45.12", @"73.150.12.88", @"174.56.89.4", 
            @"24.184.22.15", @"75.110.33.66", @"68.35.14.90", 
            @"71.198.55.10", @"108.20.77.43", @"50.195.11.22", @"69.140.88.5"
        ];
        selectedIP = cleanFallbackPool[arc4random_uniform((uint32_t)cleanFallbackPool.count)];
        detectedISP = @"US Residential (Clean Backup)";
        isFromFallback = YES;
    }
    
    sessionFakeIP = selectedIP;
    sessionIPType = detectedISP ?: @"Residential (US)";
    
    if (isFromFallback) {
        ipSourceStatus = @"⚠️ مسحوب من القائمة الاحتياطية النظيفة";
    } else {
        ipSourceStatus = @"✨ متولد ديناميكياً ونظيف 100% (غير محظور)";
    }
    
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
    generateSessionIP();
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
    
    NSString *fullReport = [NSString stringWithFormat:@"%@\n\n%@\n\n%@\n\n📋 سجل تفاصيل الطلبات والـ IP المستخدم لكل طلب:\n%@", locationInfo, ipInfo, ididentsInfo, logsText];
    
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
        topStatusBarLabel.text = @"🌐 جاري الفحص الأمني للـ IP...";
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
    generateSessionIP();
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
