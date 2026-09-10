#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>
#import <WebKit/WebKit.h>
#import <Security/Security.h>
#import <objc/runtime.h>
#import <sys/stat.h>

// ============================================================
// MARK: - المتغيرات العامة
// ============================================================

static double currentLat = 0.0;
static double currentLon = 0.0;
static NSString *sessionFakeIP = nil;
static NSString *currentRealIP = @"جاري الجلب...";
static NSMutableArray *networkLogs = nil;

static NSString *fakeAdvertisingIDString = nil;
static NSString *fakeUDIDString = nil;

// متغيرات Device Spoofing
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

// أعلام لمنع التنفيذ المزدوج
static BOOL g_initialSetupDone = NO;
static BOOL g_buttonShown = NO;

// ============================================================
// MARK: - توليد معرفات
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
// MARK: - Device Spoofing Helpers
// ============================================================

static float randomFloatBetween(float min, float max) {
    if (max <= min) return min;
    return ((float)arc4random() / (float)UINT32_MAX) * (max - min) + min;
}

static NSString *randomDeviceName(void) {
    NSArray *names = @[@"iPhone", @"iPhone Pro", @"iPhone Max"];
    NSString *base = names[arc4random_uniform((uint32_t)names.count)];
    int model = arc4random_uniform(20) + 1;
    return [NSString stringWithFormat:@"%@ %d", base, model];
}

static NSString *randomSystemVersion(void) {
    int major = 17 + arc4random_uniform(4);   // iOS 17-20
    int minor = arc4random_uniform(10);
    int patch = arc4random_uniform(10);
    return [NSString stringWithFormat:@"%d.%d.%d", major, minor, patch];
}

static NSString *randomProductType(void) {
    NSArray *products = @[@"iPhone14,2", @"iPhone15,3", @"iPhone16,1", @"iPhone17,2"];
    return products[arc4random_uniform((uint32_t)products.count)];
}

static NSString *randomUserAgent(NSString *systemVersion) {
    NSArray *components = [systemVersion componentsSeparatedByString:@"."];
    if (components.count < 2) {
        components = @[@"18", @"0"];
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

void applyDeviceSpoofing() {
    @try {
        g_spoofedSystemVersion = randomSystemVersion();
        g_spoofedName = randomDeviceName();
        g_spoofedVendorID = [NSUUID UUID];
        g_spoofedBatteryLevel = randomFloatBetween(0.15, 0.95);
        g_spoofedBatteryState = (arc4random_uniform(2) == 0) ? UIDeviceBatteryStateCharging : UIDeviceBatteryStateUnplugged;
        g_spoofedBacklightLevel = randomFloatBetween(0.1, 1.0);
        g_spoofedSupportsPencil = (arc4random_uniform(2) == 0);
        g_spoofedIsDeveloperMode = (arc4random_uniform(2) == 0);
        g_spoofedProductType = randomProductType();
        g_spoofedUserAgent = randomUserAgent(g_spoofedSystemVersion);
        g_hasSpoofed = YES;
    } @catch (NSException *e) {
        NSLog(@"[AdForceGlobal] Device spoofing error: %@", e);
    }
}

// ============================================================
// MARK: - إعدادات الإعلانات
// ============================================================

void applyAdConstraintsBypass() {
    @autoreleasepool {
        @try {
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            
            [defaults setBool:NO  forKey:@"IS_CappingManager.IS_CAPPING_ENABLED_DefaultInterstitial"];
            [defaults setBool:YES forKey:@"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial"];
            
            [defaults setBool:NO  forKey:@"BN_CappingManager.IS_CAPPING_ENABLED_DefaultBanner"];
            [defaults setBool:NO  forKey:@"BN_CappingManager.IS_PACING_ENABLED_DefaultBanner"];
            
            [defaults setBool:YES forKey:@"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"];
            
            [defaults setInteger:0 forKey:@"com.inobi_defaultStore_sessionCount"];
            
            [defaults synchronize];
            
            NSLog(@"[AdForceGlobal] Ad constraints applied");
        } @catch (NSException *e) {
            NSLog(@"[AdForceGlobal] Ad settings error: %@", e);
        }
    }
}

// ============================================================
// MARK: - دوال الموقع و IP
// ============================================================

double randomInRange(double min, double max) {
    if (max <= min) return min;
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
    
    @try {
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
    } @catch (NSException *e) {
        return YES;
    }
}

void generateSessionIP() {
    @try {
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
    } @catch (NSException *e) {
        sessionFakeIP = @"172.56.0.1";
    }
}

void fetchRealIP() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @try {
            NSURL *url = [NSURL URLWithString:@"https://api.ipify.org"];
            if (!url) { currentRealIP = @"غير قادر على الجلب"; return; }
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
        if (!networkLogs) {
            networkLogs = [[NSMutableArray alloc] init];
        }
        NSURL *url = [NSURL URLWithString:urlStr];
        NSString *path = url.path ? url.path : urlStr;
        if (path.length > 30) {
            path = [[path substringToIndex:30] stringByAppendingString:@"..."];
        }
        NSString *logEntry = [NSString stringWithFormat:@"🔗 %@\n🌐 IP: %@\n📍 (%.4f, %.4f)", path, ip, lat, lon];
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
    } @catch (NSException *e) {
        NSLog(@"[AdForceGlobal] Keychain error: %@", e);
    }
}

// ============================================================
// MARK: - مسح الكوكيز والكاش
// ============================================================

void clearAllCookiesSync() {
    @try {
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
            [cookieStorage deleteCookie:cookie];
        }
        
        // WKWebsiteDataStore غير متزامن - ننتظر أقصى 2 ثواني
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        NSSet *allWebTypes = [WKWebsiteDataStore allWebsiteDataTypes];
        [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:allWebTypes
                                                  modifiedSince:[NSDate distantPast]
                                              completionHandler:^{
            dispatch_semaphore_signal(semaphore);
        }];
        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)));
    } @catch (NSException *e) {
        NSLog(@"[AdForceGlobal] Cookie error: %@", e);
    }
}

void clearNetworkCache() {
    @try {
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
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
                    // لا نحذف Preferences عشان ما نمسح الإعدادات اللي ضفناها
                    if ([item isEqualToString:@"Preferences"]) continue;
                    [fm removeItemAtPath:[dir stringByAppendingPathComponent:item] error:nil];
                }
            }
        }
        
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleID) {
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleID];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    } @catch (NSException *e) {
        NSLog(@"[AdForceGlobal] Files error: %@", e);
    }
}

// ============================================================
// MARK: - دالة العملية الرئيسية
// ============================================================

void performFullReset() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        @try {
            NSLog(@"[AdForceGlobal] Reset started");
            
            clearKeychainKeepingAccount();
            clearAllCookiesSync();
            clearNetworkCache();
            clearAllLocalFiles();
            
            applyAdConstraintsBypass();
            
            fakeAdvertisingIDString = generateRandomUUIDString();
            fakeUDIDString = generateRandomUDID();
            applyDeviceSpoofing();
            
            updateAtlantaLocation();
            generateSessionIP();
            fetchRealIP();
            
            @synchronized(networkLogs) {
                [networkLogs removeAllObjects];
            }
            
            NSLog(@"[AdForceGlobal] Reset complete → exit");
        } @catch (NSException *e) {
            NSLog(@"[AdForceGlobal] Reset error: %@", e);
        }
        
        // خروج فوري
        exit(0);
    });
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
    
    NSString *idfaStr = fakeAdvertisingIDString ?: @"-";
    NSString *udidDisplay = fakeUDIDString ?: @"غير متوفر";
    
    NSString *locationInfo = [NSString stringWithFormat:@"📍 الموقع (أتلانتا):\nLat: %.4f\nLon: %.4f", currentLat, currentLon];
    NSString *ipInfo = [NSString stringWithFormat:@"🌐 IP وهمي:\n%@\n\n🛡️ IP حقيقي:\n%@", sessionFakeIP ?: @"غير محدد", currentRealIP];
    NSString *identsInfo = [NSString stringWithFormat:@"🆔 المعرفات:\nUDID: %@\nIDFA: %@", udidDisplay, idfaStr];
    NSString *deviceInfo = [NSString stringWithFormat:@"📱 الجهاز:\nName: %@\niOS: %@\nProduct: %@", g_spoofedName ?: @"-", g_spoofedSystemVersion ?: @"-", g_spoofedProductType ?: @"-"];
    
    NSString *logsText = @"";
    @synchronized(networkLogs) {
        if (networkLogs && networkLogs.count > 0) {
            logsText = [networkLogs componentsJoinedByString:@"\n\n---\n\n"];
        } else {
            logsText = @"لا توجد طلبات بعد.";
        }
    }
    
    NSString *fullReport = [NSString stringWithFormat:@"%@\n\n%@\n\n%@\n\n%@\n\n📋 الطلبات:\n%@", locationInfo, ipInfo, identsInfo, deviceInfo, logsText];
    
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
// MARK: - الأزرار العائمة
// ============================================================

@interface AtlantaWindow : UIWindow
@end

@implementation AtlantaWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *btn1 = [self viewWithTag:999888];
    if (btn1 && CGRectContainsPoint(btn1.frame, point)) return YES;
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
            g_buttonShown = YES;
            NSLog(@"[AdForceGlobal] Button shown");
        } @catch (NSException *e) {
            NSLog(@"[AdForceGlobal] Button error: %@", e);
        }
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
}

@end

// ============================================================
// MARK: - Private Swizzling Functions
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
    return orig_productType ? orig_productType(self, _cmd) : @"iPhone14,2";
}

// ============================================================
// MARK: - Hooks
// ============================================================

%hook UIDevice

- (NSString *)name {
    if (g_hasSpoofed && g_spoofedName) return g_spoofedName;
    return %orig;
}

- (NSString *)systemVersion {
    if (g_hasSpoofed && g_spoofedSystemVersion) return g_spoofedSystemVersion;
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
    if (g_hasSpoofed) return g_spoofedBatteryLevel;
    return %orig;
}

- (UIDeviceBatteryState)batteryState {
    if (g_hasSpoofed) return g_spoofedBatteryState;
    return %orig;
}

%end

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    @try {
        if (fakeAdvertisingIDString) {
            return [[NSUUID alloc] initWithUUIDString:fakeAdvertisingIDString];
        }
    } @catch (id e) {}
    return %orig;
}
%end

%hook CLLocationManager
- (void)startUpdatingLocation {
    updateAtlantaLocation();
    @try {
        CLLocation *fakeLocation = [[CLLocation alloc] initWithLatitude:currentLat longitude:currentLon];
        if ([self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
            [self.delegate locationManager:self didUpdateLocations:@[fakeLocation]];
        }
    } @catch (id e) {}
}
- (CLLocation *)location {
    updateAtlantaLocation();
    return [[CLLocation alloc] initWithLatitude:currentLat longitude:currentLon];
}
%end

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    @try {
        if (sessionFakeIP) {
            [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Forwarded-For"];
            [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"Client-IP"];
            [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Real-IP"];
        }
        if (g_hasSpoofed && g_spoofedUserAgent) {
            [mutableReq setValue:g_spoofedUserAgent forHTTPHeaderField:@"User-Agent"];
        }
    } @catch (id e) {}
    return %orig(mutableReq);
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    @try {
        if (sessionFakeIP) {
            [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Forwarded-For"];
            [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"Client-IP"];
            [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Real-IP"];
        }
        if (g_hasSpoofed && g_spoofedUserAgent) {
            [mutableReq setValue:g_spoofedUserAgent forHTTPHeaderField:@"User-Agent"];
        }
    } @catch (id e) {}
    return %orig(mutableReq, completionHandler);
}

%end

%hook NSURLConnection
+ (void)sendAsynchronousRequest:(NSURLRequest *)request queue:(NSOperationQueue *)queue completionHandler:(void (^)(NSURLResponse *response, NSData *data, NSError *error))handler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    @try {
        if (sessionFakeIP) {
            [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Forwarded-For"];
            [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"Client-IP"];
            [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Real-IP"];
        }
        if (g_hasSpoofed && g_spoofedUserAgent) {
            [mutableReq setValue:g_spoofedUserAgent forHTTPHeaderField:@"User-Agent"];
        }
    } @catch (id e) {}
    %orig(mutableReq, queue, handler);
}
%end

// ============================================================
// MARK: - Constructor (خفيف جداً - بدون شبكة)
// ============================================================

%ctor {
    %init;   // ← تفعيل الـ hooks
    
    @autoreleasepool {
        NSLog(@"[AdForceGlobal] ==== Tweak loaded ====");
        
        // ===== المرحلة 1: عمليات آمنة فورية (بدون شبكة، بدون UI) =====
        
        // 1) إعدادات الإعلانات (NSUserDefaults فقط)
        applyAdConstraintsBypass();
        
        // 2) Swizzling للدوال الخاصة
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
        } @catch (NSException *e) {
            NSLog(@"[AdForceGlobal] Swizzling error: %@", e);
        }
        
        // 3) توليد بيانات وهمية أولية (بدون شبكة - سريع جداً)
        applyDeviceSpoofing();
        fakeAdvertisingIDString = generateRandomUUIDString();
        fakeUDIDString = generateRandomUDID();
        updateAtlantaLocation();
        
        // ===== المرحلة 2: عمليات الشبكة والواجهة (مؤجلة 3 ثواني على خيط خلفي) =====
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                       dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            if (g_initialSetupDone) return;
            g_initialSetupDone = YES;
            
            NSLog(@"[AdForceGlobal] Deferred init started");
            
            @try {
                // IP وهمي (قد يأخذ عدة ثواني - لكنه على خيط خلفي)
                generateSessionIP();
                NSLog(@"[AdForceGlobal] Session IP ready: %@", sessionFakeIP ?: @"nil");
                
                // IP الحقيقي (async داخلياً)
                fetchRealIP();
            } @catch (NSException *e) {
                NSLog(@"[AdForceGlobal] Network init error: %@", e);
            }
            
            // إظهار الزر على الخيط الرئيسي
            dispatch_async(dispatch_get_main_queue(), ^{
                [[AtlantaInfoManager sharedInstance] setupFloatingButtons];
            });
        });
    }
}
