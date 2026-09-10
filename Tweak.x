#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>
#import <WebKit/WebKit.h>
#import <Security/Security.h>
#import <objc/runtime.h>
#import <sys/stat.h>

// ============================================================
// MARK: - المتغيرات العامة (التويك الأول)
// ============================================================

static double currentLat = 0.0;
static double currentLon = 0.0;
static NSString *sessionFakeIP = nil;
static NSString *currentRealIP = @"جاري الجلب...";
static NSMutableArray *networkLogs = nil;

static NSString *fakeAdvertisingIDString = nil;
static NSString *fakeUDIDString = nil;

// ============================================================
// MARK: - متغيرات التمويه (التويك الثاني)
// ============================================================

static NSString *g_spoofedName = nil;
static NSString *g_spoofedSystemVersion = nil;
static NSUUID *g_spoofedVendorID = nil;
static float g_spoofedBatteryLevel = 0.0;
static UIDeviceBatteryState g_spoofedBatteryState = UIDeviceBatteryStateUnknown;
static float g_spoofedBacklightLevel = 0.0;
static BOOL g_spoofedSupportsPencil = NO;
static BOOL g_spoofedIsDeveloperMode = NO;
static NSString *g_spoofedProductType = nil;
static NSString *g_spoofedUserAgent = nil;
static BOOL g_hasSpoofed = NO;

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
// MARK: - دوال التمويه
// ============================================================

static float randomFloatBetween(float min, float max) {
    return ((float)arc4random() / (float)UINT32_MAX) * (max - min) + min;
}

static NSString *randomDeviceName(void) {
    NSArray *names = @[@"iPhone", @"iPhone Pro", @"iPhone Max"];
    NSString *base = names[arc4random_uniform((uint32_t)names.count)];
    int model = arc4random_uniform(20) + 1;
    return [NSString stringWithFormat:@"%@ %d", base, model];
}

static NSString *randomSystemVersion(void) {
    int major = 24 + arc4random_uniform(4);
    int minor = arc4random_uniform(10);
    int patch = arc4random_uniform(10);
    return [NSString stringWithFormat:@"%d.%d.%d", major, minor, patch];
}

static NSString *randomProductType(void) {
    NSArray *products = @[@"iPhone14,2", @"iPhone15,3", @"iPhone16,1", @"iPhone17,2"];
    return products[arc4random_uniform((uint32_t)products.count)];
}

static NSString *randomUserAgent(NSString *systemVersion) {
    if (!systemVersion) systemVersion = @"26.0.0";
    NSArray *components = [systemVersion componentsSeparatedByString:@"."];
    if (components.count < 2) {
        components = @[@"26", @"0"];
    }
    NSString *major = components[0];
    NSString *minor = components.count > 1 ? components[1] : @"0";
    
    int buildNumber = arc4random_uniform(900) + 100;
    NSString *build = [NSString stringWithFormat:@"%d", buildNumber];
    
    int webKitMajor = 600 + arc4random_uniform(10);
    int webKitMinor = arc4random_uniform(20);
    int webKitPatch = arc4random_uniform(10);
    
    int safariMajor = 10 + arc4random_uniform(10);
    int safariMinor = arc4random_uniform(10);
    
    return [NSString stringWithFormat:
            @"Mozilla/5.0 (iPhone; CPU iPhone OS %@_%@ like Mac OS X) AppleWebKit/%d.%d.%d (KHTML, like Gecko) Version/%d.%d Mobile/15E%@ Safari/%d.%d.%d",
            major, minor, webKitMajor, webKitMinor, webKitPatch, safariMajor, safariMinor, build, webKitMajor, webKitMinor, webKitPatch];
}

// ============================================================
// MARK: - دوال مساعدة (التويك الأول)
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
    if (!url) return YES;
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setTimeoutInterval:2.0];
    
    __block NSData *responseData = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        responseData = data;
        dispatch_semaphore_signal(semaphore);
    }];
    [task resume];
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)));
    
    if (!responseData) return YES;
    
    NSError *jsonError = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&jsonError];
    if (jsonError || !json || ![json isKindOfClass:[NSDictionary class]]) return YES;
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
            break;
        }
    }
    
    if (!selectedIP) {
        selectedIP = candidates.lastObject;
    }
    
    sessionFakeIP = selectedIP;
}

void fetchRealIP() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            NSURL *url = [NSURL URLWithString:@"https://api.ipify.org"];
            if (!url) return;
            NSString *ip = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
            if (ip && ip.length > 0) {
                currentRealIP = ip;
            } else {
                currentRealIP = @"غير قادر على الجلب";
            }
        } @catch (NSException *e) {
            currentRealIP = @"غير قادر على الجلب";
        }
    });
}

void logNetworkRequest(NSString *urlStr, NSString *ip, double lat, double lon) {
    @try {
        if (!urlStr) return;
        if (!networkLogs) {
            networkLogs = [[NSMutableArray alloc] init];
        }
        NSURL *url = [NSURL URLWithString:urlStr];
        NSString *path = (url && url.path) ? url.path : urlStr;
        if (path.length > 30) {
            path = [[path substringToIndex:30] stringByAppendingString:@"..."];
        }
        NSString *logEntry = [NSString stringWithFormat:@"🔗 الرابط: %@\n🌐 خرج عبر IP: %@\n📍 الموقع: (%.4f, %.4f)", path, ip ?: @"-", lat, lon];
        @synchronized(networkLogs) {
            [networkLogs insertObject:logEntry atIndex:0];
            if (networkLogs.count > 15) {
                [networkLogs removeLastObject];
            }
        }
    } @catch (NSException *e) {}
}

// ============================================================
// MARK: - مسح Keychain مع الحفاظ على الحساب
// ============================================================

void clearKeychainKeepingAccount() {
    @try {
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
    } @catch (NSException *e) {}
}

void clearAllCookies() {
    @try {
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
            [cookieStorage deleteCookie:cookie];
        }
        
        NSSet *dataTypes = [NSSet setWithObject:WKWebsiteDataTypeCookies];
        [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:dataTypes modifiedSince:[NSDate distantPast] completionHandler:^{}];
        
        NSSet *allWebTypes = [WKWebsiteDataStore allWebsiteDataTypes];
        [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:allWebTypes modifiedSince:[NSDate distantPast] completionHandler:^{}];
    } @catch (NSException *e) {}
}

void clearNetworkCache() {
    @try {
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        [[NSURLCache sharedURLCache] setDiskCapacity:0];
        [[NSURLCache sharedURLCache] setMemoryCapacity:0];
    } @catch (NSException *e) {}
}

void clearAllLocalFiles() {
    @try {
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
    } @catch (NSException *e) {}
}

// ============================================================
// MARK: - دالة موحدة (الزر الأزرق)
// ============================================================

void performBlueButtonAction() {
    @try {
        // 1) تغيير UDID
        fakeUDIDString = generateRandomUDID();

        // 2) توليد بيانات التمويه
        g_spoofedName = randomDeviceName();
        g_spoofedSystemVersion = randomSystemVersion();
        g_spoofedVendorID = [NSUUID UUID];
        g_spoofedBatteryLevel = randomFloatBetween(0.15, 0.95);
        g_spoofedBatteryState = (arc4random_uniform(2) == 0) ? UIDeviceBatteryStateCharging : UIDeviceBatteryStateUnplugged;
        g_spoofedBacklightLevel = randomFloatBetween(0.1, 1.0);
        g_spoofedSupportsPencil = (arc4random_uniform(2) == 0);
        g_spoofedIsDeveloperMode = (arc4random_uniform(2) == 0);
        g_spoofedProductType = randomProductType();
        g_spoofedUserAgent = randomUserAgent(g_spoofedSystemVersion);
        g_hasSpoofed = YES;

        // 3) تنظيف Keychain / Cookies / Cache / Files
        clearKeychainKeepingAccount();
        clearAllCookies();
        clearNetworkCache();
        clearAllLocalFiles();

        // 4) توليد IDFA + الموقع + IP
        fakeAdvertisingIDString = generateRandomUUIDString();
        updateAtlantaLocation();
        generateSessionIP();
        fetchRealIP();

        // 5) مسح NSUserDefaults
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleID) {
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleID];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }

        // 6) مسح سجلات الشبكة
        @synchronized(networkLogs) {
            [networkLogs removeAllObjects];
        }
    } @catch (NSException *exception) {
        // تجاهل
    }
    
    // ✅ الخروج فوراً
    exit(0);
}

// ============================================================
// MARK: - واجهة عرض التقارير
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
    
    NSString *idfaStr = fakeAdvertisingIDString ?: [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString] ?: @"-";
    NSString *udidDisplay = fakeUDIDString ?: @"غير متوفر";
    
    NSString *locationInfo = [NSString stringWithFormat:@"📍 الموقع الحالي (أتلانطا):\nLat: %.4f\nLon: %.4f", currentLat, currentLon];
    NSString *ipInfo = [NSString stringWithFormat:@"🌐 IP الجلسة الوهمي:\n%@\n\n🛡️ IP الشبكة الفعلي:\n%@", sessionFakeIP ?: @"غير محدد", currentRealIP ?: @"-"];
    NSString *identsInfo = [NSString stringWithFormat:@"🆔 المعرفات:\nUDID: %@\nIDFA: %@\n\n📱 الجهاز المزيف:\nName: %@\nSystem: %@\nProduct: %@", udidDisplay, idfaStr, g_spoofedName ?: @"-", g_spoofedSystemVersion ?: @"-", g_spoofedProductType ?: @"-"];
    
    NSString *logsText = @"";
    @synchronized(networkLogs) {
        if (networkLogs && networkLogs.count > 0) {
            logsText = [networkLogs componentsJoinedByString:@"\n\n--------------------\n\n"];
        } else {
            logsText = @"لا توجد طلبات مسجلة بعد.";
        }
    }
    
    NSString *fullReport = [NSString stringWithFormat:@"%@\n\n%@\n\n%@\n\n📋 تفاصيل الطلبات:\n%@", locationInfo, ipInfo, identsInfo, logsText];
    
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
// MARK: - النافذة العائمة
// ============================================================

@interface AtlantaWindow : UIWindow
@end

@implementation AtlantaWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    @try {
        UIView *btn1 = [self viewWithTag:999888];
        if (btn1 && !btn1.hidden && CGRectContainsPoint(btn1.frame, point)) {
            return YES;
        }
    } @catch (NSException *e) {}
    return NO;
}
@end

@interface AtlantaInfoManager : NSObject
@property (strong, nonatomic) AtlantaWindow *floatingWindow;
@property (strong, nonatomic) UIButton *resetBtn;
+ (instancetype)sharedInstance;
- (void)setupFloatingButtons;
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

- (void)setupFloatingButtons {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (self.floatingWindow) return;
            
            CGRect screenBounds = [UIScreen mainScreen].bounds;
            self.floatingWindow = [[AtlantaWindow alloc] initWithFrame:screenBounds];
            self.floatingWindow.windowLevel = UIWindowLevelAlert + 1000;
            self.floatingWindow.hidden = NO;
            self.floatingWindow.backgroundColor = [UIColor clearColor];
            self.floatingWindow.rootViewController = nil;
            
            UIViewController *vc = [[UIViewController alloc] init];
            vc.view.backgroundColor = [UIColor clearColor];
            self.floatingWindow.rootViewController = vc;
            
            self.resetBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            self.resetBtn.tag = 999888;
            self.resetBtn.frame = CGRectMake(20, 120, 55, 55);
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
        } @catch (NSException *e) {}
    });
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    @try {
        UIView *btn = gesture.view;
        if (!btn || !btn.superview) return;
        CGPoint translation = [gesture translationInView:btn.superview];
        CGFloat newX = btn.center.x + translation.x;
        CGFloat newY = btn.center.y + translation.y;
        CGSize screenSize = [UIScreen mainScreen].bounds.size;
        newX = MAX(30, MIN(screenSize.width - 30, newX));
        newY = MAX(40, MIN(screenSize.height - 40, newY));
        btn.center = CGPointMake(newX, newY);
        [gesture setTranslation:CGPointZero inView:btn.superview];
    } @catch (NSException *e) {}
}

- (void)handleReset {
    // تشغيل العملية في الخلفية حتى لا يتجمد الـ UI
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        performBlueButtonAction();
    });
}

@end

// ============================================================
// MARK: - Private Method Swizzling
// ============================================================

static float (*orig_backlightLevel)(id self, SEL _cmd) = NULL;
static BOOL (*orig_supportsPencil)(id self, SEL _cmd) = NULL;
static BOOL (*orig_developerModeEnabled)(id self, SEL _cmd) = NULL;
static NSString * (*orig_productType)(id self, SEL _cmd) = NULL;

static float replaced_backlightLevel(id self, SEL _cmd) {
    if (g_hasSpoofed) return g_spoofedBacklightLevel;
    return orig_backlightLevel ? orig_backlightLevel(self, _cmd) : 0.5f;
}

static BOOL replaced_supportsPencil(id self, SEL _cmd) {
    if (g_hasSpoofed) return g_spoofedSupportsPencil;
    return orig_supportsPencil ? orig_supportsPencil(self, _cmd) : NO;
}

static BOOL replaced_developerModeEnabled(id self, SEL _cmd) {
    if (g_hasSpoofed) return g_spoofedIsDeveloperMode;
    return orig_developerModeEnabled ? orig_developerModeEnabled(self, _cmd) : NO;
}

static NSString * replaced_productType(id self, SEL _cmd) {
    if (g_hasSpoofed && g_spoofedProductType) return g_spoofedProductType;
    return orig_productType ? orig_productType(self, _cmd) : nil;
}

// ============================================================
// MARK: - Constructor
// ============================================================

%ctor {
    @autoreleasepool {
        // 🛡️ لا ننفذ أي عمليات حجب للـ Main Thread هنا
        // كل توليد البيانات الثقيلة يحدث في الخلفية
        
        updateAtlantaLocation();
        fakeAdvertisingIDString = generateRandomUUIDString();
        
        // توليد IP في الخلفية لتجنب تعليق الإقلاع
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            @try {
                generateSessionIP();
            } @catch (NSException *e) {}
        });
        
        fetchRealIP();
        
        // تسجيل Private Methods Swizzling
        @try {
            Class uidClass = NSClassFromString(@"UIDevice");
            if (uidClass) {
                SEL selBacklight = NSSelectorFromString(@"_backlightLevel");
                if ([uidClass instancesRespondToSelector:selBacklight]) {
                    Method method = class_getInstanceMethod(uidClass, selBacklight);
                    if (method) {
                        orig_backlightLevel = (float (*)(id, SEL))method_getImplementation(method);
                        method_setImplementation(method, (IMP)replaced_backlightLevel);
                    }
                }

                SEL selPencil = NSSelectorFromString(@"_supportsPencil");
                if ([uidClass instancesRespondToSelector:selPencil]) {
                    Method method = class_getInstanceMethod(uidClass, selPencil);
                    if (method) {
                        orig_supportsPencil = (BOOL (*)(id, SEL))method_getImplementation(method);
                        method_setImplementation(method, (IMP)replaced_supportsPencil);
                    }
                }

                SEL selDevMode = NSSelectorFromString(@"sf_isDeveloperModeEnabled");
                if ([uidClass instancesRespondToSelector:selDevMode]) {
                    Method method = class_getInstanceMethod(uidClass, selDevMode);
                    if (method) {
                        orig_developerModeEnabled = (BOOL (*)(id, SEL))method_getImplementation(method);
                        method_setImplementation(method, (IMP)replaced_developerModeEnabled);
                    }
                }

                SEL selProductType = NSSelectorFromString(@"sf_productType");
                if ([uidClass instancesRespondToSelector:selProductType]) {
                    Method method = class_getInstanceMethod(uidClass, selProductType);
                    if (method) {
                        orig_productType = (NSString * (*)(id, SEL))method_getImplementation(method);
                        method_setImplementation(method, (IMP)replaced_productType);
                    }
                }
            }
        } @catch (NSException *e) {}
        
        // إضافة الزر العائم بعد 2 ثانية
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            @try {
                [[AtlantaInfoManager sharedInstance] setupFloatingButtons];
            } @catch (NSException *e) {}
        });
    }
}

// ============================================================
// MARK: - Hooks
// ============================================================

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    @try {
        if (fakeAdvertisingIDString) {
            NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:fakeAdvertisingIDString];
            if (uuid) return uuid;
        }
    } @catch (NSException *e) {}
    return %orig;
}
%end

%hook UIDevice

- (NSString *)name {
    @try {
        if (g_hasSpoofed && g_spoofedName) return g_spoofedName;
    } @catch (NSException *e) {}
    return %orig;
}

- (NSString *)systemVersion {
    @try {
        if (g_hasSpoofed && g_spoofedSystemVersion) return g_spoofedSystemVersion;
    } @catch (NSException *e) {}
    return %orig;
}

- (NSUUID *)identifierForVendor {
    @try {
        if (g_hasSpoofed && g_spoofedVendorID && [g_spoofedVendorID isKindOfClass:[NSUUID class]]) {
            return g_spoofedVendorID;
        }
    } @catch (id e) {}
    return %orig;
}

- (float)batteryLevel {
    @try {
        if (g_hasSpoofed) return g_spoofedBatteryLevel;
    } @catch (NSException *e) {}
    return %orig;
}

- (UIDeviceBatteryState)batteryState {
    @try {
        if (g_hasSpoofed) return g_spoofedBatteryState;
    } @catch (NSException *e) {}
    return %orig;
}

%end

%hook CLLocationManager
- (void)startUpdatingLocation {
    @try {
        updateAtlantaLocation();
        CLLocation *fakeLocation = [[CLLocation alloc] initWithLatitude:currentLat longitude:currentLon];
        if (fakeLocation && self.delegate && [self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
            [self.delegate locationManager:self didUpdateLocations:@[fakeLocation]];
        }
    } @catch (NSException *e) {}
}
- (CLLocation *)location {
    @try {
        updateAtlantaLocation();
        return [[CLLocation alloc] initWithLatitude:currentLat longitude:currentLon];
    } @catch (NSException *e) {
        return %orig;
    }
}
%end

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    @try {
        if (!request) return %orig;
        NSMutableURLRequest *mutableRequest = [request mutableCopy];
        if (!mutableRequest) return %orig;

        if (sessionFakeIP) {
            [mutableRequest setValue:sessionFakeIP forHTTPHeaderField:@"X-Forwarded-For"];
            [mutableRequest setValue:sessionFakeIP forHTTPHeaderField:@"Client-IP"];
            [mutableRequest setValue:sessionFakeIP forHTTPHeaderField:@"X-Real-IP"];
        }
        
        if (g_hasSpoofed && g_spoofedUserAgent) {
            [mutableRequest setValue:g_spoofedUserAgent forHTTPHeaderField:@"User-Agent"];
        }
        [mutableRequest setValue:nil forHTTPHeaderField:@"Cookie"];
        
        NSString *urlString = request.URL.absoluteString;
        if (urlString) {
            logNetworkRequest(urlString, sessionFakeIP ?: @"غير محدد", currentLat, currentLon);
        }
        
        return %orig(mutableRequest);
    } @catch (NSException *e) {
        return %orig;
    }
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    @try {
        if (!request) return %orig;
        NSMutableURLRequest *mutableRequest = [request mutableCopy];
        if (!mutableRequest) return %orig(mutableRequest, completionHandler);
        
        if (sessionFakeIP) {
            [mutableRequest setValue:sessionFakeIP forHTTPHeaderField:@"X-Forwarded-For"];
            [mutableRequest setValue:sessionFakeIP forHTTPHeaderField:@"Client-IP"];
            [mutableRequest setValue:sessionFakeIP forHTTPHeaderField:@"X-Real-IP"];
        }
        
        if (g_hasSpoofed && g_spoofedUserAgent) {
            [mutableRequest setValue:g_spoofedUserAgent forHTTPHeaderField:@"User-Agent"];
        }
        [mutableRequest setValue:nil forHTTPHeaderField:@"Cookie"];
        
        NSString *urlString = request.URL.absoluteString;
        if (urlString) {
            logNetworkRequest(urlString, sessionFakeIP ?: @"غير محدد", currentLat, currentLon);
        }
        
        return %orig(mutableRequest, completionHandler);
    } @catch (NSException *e) {
        return %orig(request, completionHandler);
    }
}

%end

%hook NSURLConnection
+ (void)sendAsynchronousRequest:(NSURLRequest *)request queue:(NSOperationQueue *)queue completionHandler:(void (^)(NSURLResponse *response, NSData *data, NSError *error))handler {
    @try {
        if (!request) {
            %orig;
            return;
        }
        NSMutableURLRequest *mutableReq = [request mutableCopy];
        if (sessionFakeIP) {
            [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Forwarded-For"];
            [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"Client-IP"];
            [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Real-IP"];
        }
        if (g_hasSpoofed && g_spoofedUserAgent) {
            [mutableReq setValue:g_spoofedUserAgent forHTTPHeaderField:@"User-Agent"];
        }
        NSString *urlString = request.URL.absoluteString;
        if (urlString) {
            logNetworkRequest(urlString, sessionFakeIP ?: @"غير محدد", currentLat, currentLon);
        }
        %orig(mutableReq, queue, handler);
    } @catch (NSException *e) {
        %orig;
    }
}
%end
