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
static NSString *currentRealIP = @"جاري الجلب...";
static NSMutableArray *networkLogs = nil;

// المعرفات المزيفة
static NSString *fakeAdvertisingIDString = nil;
static NSString *fakeUDIDString = nil;

// ============================================================
// MARK: - دالة توليد معرف عشوائي آمن (UUID String)
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
// MARK: - مسح Keychain مع الحفاظ على الحساب (بدون أي تعديل)
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

// ============================================================
// MARK: - دوال مسح الملفات المتقدمة (Fresh Install Wipe)
// ============================================================

void clearDirectoryContents(NSString *path) {
    if (!path || path.length == 0) return;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:path isDirectory:&isDir] || !isDir) return;
    
    NSError *listError = nil;
    NSArray *items = [fm contentsOfDirectoryAtPath:path error:&listError];
    if (listError) {
        NSLog(@"[Reset] فشل سرد محتويات %@ : %@", path, listError.localizedDescription);
        return;
    }
    
    for (NSString *item in items) {
        NSString *full = [path stringByAppendingPathComponent:item];
        NSError *removeError = nil;
        if (![fm removeItemAtPath:full error:&removeError]) {
            NSLog(@"[Reset] فشل حذف %@ : %@", full, removeError.localizedDescription);
        }
    }
}

NSArray<NSString *> *discoverGroupContainerPaths() {
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    
    NSString *homeGroupDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Group Containers"];
    BOOL isDir = NO;
    if ([fm fileExistsAtPath:homeGroupDir isDirectory:&isDir] && isDir) {
        [paths addObject:homeGroupDir];
    }
    
    NSString *sharedRoot = @"/private/var/mobile/Containers/Shared/AppGroup";
    if ([fm fileExistsAtPath:sharedRoot]) {
        NSString *teamPrefix = nil;
        if (bundleID.length > 0) {
            NSArray *parts = [bundleID componentsSeparatedByString:@"."];
            if (parts.count > 0) teamPrefix = parts.firstObject;
        }
        
        NSArray *uuids = [fm contentsOfDirectoryAtPath:sharedRoot error:nil];
        for (NSString *uuid in uuids) {
            NSString *containerPath = [sharedRoot stringByAppendingPathComponent:uuid];
            NSString *metaPath = [containerPath stringByAppendingPathComponent:
                                  @".com.apple.mobile_container_manager.metadata.plist"];
            NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:metaPath];
            NSString *groupID = meta[@"MCMMetadataIdentifier"];
            if (![groupID isKindOfClass:[NSString class]]) continue;
            
            BOOL matches = NO;
            if (bundleID.length > 0 && [groupID containsString:bundleID]) matches = YES;
            if (!matches && teamPrefix.length > 1 && [groupID containsString:teamPrefix]) matches = YES;
            
            if (matches) [paths addObject:containerPath];
        }
    }
    
    return paths;
}

void clearGroupContainers() {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *containers = discoverGroupContainerPaths();
    
    for (NSString *containerPath in containers) {
        BOOL isDir = NO;
        if (![fm fileExistsAtPath:containerPath isDirectory:&isDir] || !isDir) continue;
        
        if ([containerPath.lastPathComponent isEqualToString:@"Group Containers"]) {
            NSArray *children = [fm contentsOfDirectoryAtPath:containerPath error:nil];
            for (NSString *child in children) {
                NSString *childPath = [containerPath stringByAppendingPathComponent:child];
                clearDirectoryContents(childPath);
                [fm removeItemAtPath:childPath error:nil];
            }
        } else {
            clearDirectoryContents(containerPath);
        }
    }
}

// ============================================================
// MARK: - مسح الكوكيز وبيانات الويب (نسخة متوافقة مع iOS 9+)
// ============================================================

void clearAllCookies() {
    // (1) كوكيز التطبيق التقليدية
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
        [cookieStorage deleteCookie:cookie];
    }
    [[NSHTTPCookieStorage sharedHTTPCookieStorage] removeCookiesSinceDate:[NSDate distantPast]];
    
    // (2) كوكيز WebKit + كل بيانات الويب (LocalStorage / SessionStorage / IndexedDB / Cache ...)
    NSSet *allWebTypes = [WKWebsiteDataStore allWebsiteDataTypes];
    WKWebsiteDataStore *store = [WKWebsiteDataStore defaultDataStore];
    [store removeDataOfTypes:allWebTypes
               modifiedSince:[NSDate distantPast]
           completionHandler:^{
               NSLog(@"[Reset] تم مسح WKWebsiteDataStore بالكامل");
           }];
    
    // (3) بيانات WebViews المعزولة — متاحة فقط من iOS 17+
    //     نستخدم Runtime Check لأن الـ deployment target هو iOS 9.0
    Class wkStoreClass = NSClassFromString(@"WKWebsiteDataStore");
    SEL fetchAllSel = NSSelectorFromString(@"fetchAllDataStoreIdentifiers:");
    SEL storeForID  = NSSelectorFromString(@"dataStoreForIdentifier:");
    
    if (wkStoreClass &&
        [wkStoreClass respondsToSelector:fetchAllSel] &&
        [wkStoreClass respondsToSelector:storeForID]) {
        
        // استدعاء ديناميكي لتجاوز فحص التوفر وقت التصريف
        typedef void (*FetchAllFn)(id, SEL, void (^)(NSArray<NSUUID *> *));
        FetchAllFn fetchImpl = (FetchAllFn)[wkStoreClass methodForSelector:fetchAllSel];
        
        typedef id (*StoreForIDFn)(id, SEL, NSUUID *);
        StoreForIDFn storeImpl = (StoreForIDFn)[wkStoreClass methodForSelector:storeForID];
        
        if (fetchImpl && storeImpl) {
            fetchImpl(wkStoreClass, fetchAllSel, ^(NSArray<NSUUID *> *identifiers) {
                for (NSUUID *uuid in identifiers) {
                    id s = storeImpl(wkStoreClass, storeForID, uuid);
                    if (s && [s respondsToSelector:@selector(removeDataOfTypes:modifiedSince:completionHandler:)]) {
                        [s removeDataOfTypes:allWebTypes
                               modifiedSince:[NSDate distantPast]
                           completionHandler:^{}];
                    }
                }
            });
        }
    }
}

// ============================================================
// MARK: - مسح كاش الشبكة
// ============================================================

void clearNetworkCache() {
    NSURLCache *cache = [NSURLCache sharedURLCache];
    [cache removeAllCachedResponses];
    [cache removeCachedResponseForRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"about:blank"]]];
    [cache setDiskCapacity:0];
    [cache setMemoryCapacity:0];
    [NSURLCache setSharedURLCache:[[NSURLCache alloc] initWithMemoryCapacity:0
                                                                diskCapacity:0
                                                                    diskPath:nil]];
}

// ============================================================
// MARK: - مسح الملفات المحلية بشكل شامل
// ============================================================

void clearAllLocalFiles() {
    NSString *home = NSHomeDirectory();
    
    clearDirectoryContents([home stringByAppendingPathComponent:@"Documents"]);
    clearDirectoryContents([home stringByAppendingPathComponent:@"Library"]);
    clearDirectoryContents(NSTemporaryDirectory());
    
    NSArray<NSString *> *extraPaths = @[
        @"Documents/Inbox",
        @"Library/Caches",
        @"Library/Preferences",
        @"Library/Application Support",
        @"Library/Saved Application State",
        @"Library/WebKit",
        @"Library/Cookies",
        @"Library/HTTPStorages",
        @"Library/WebKit/WebsiteData",
        @"Library/WebKit/WebsiteData/LocalStorage",
        @"Library/WebKit/WebsiteData/IndexedDB",
        @"Library/WebKit/WebsiteData/SessionStorage",
        @"Library/WebKit/WebsiteData/Cookies"
    ];
    for (NSString *rel in extraPaths) {
        clearDirectoryContents([home stringByAppendingPathComponent:rel]);
    }
}

// ============================================================
// MARK: - دالة إعادة التعيين الكاملة (الزر الأزرق الموحّد)
// ============================================================

void performFullReset() {
    NSLog(@"[Reset] بدء إعادة التعيين الكاملة ...");
    
    // (1) Keychain — الحفاظ على الحساب (بدون أي تعديل على الدالة الأصلية)
    clearKeychainKeepingAccount();
    
    // (2) الكوكيز وبيانات الويب (WKWebView + WebKit dataStore)
    clearAllCookies();
    
    // (3) كاش الشبكة (Memory + Disk)
    clearNetworkCache();
    
    // (4) مسح كامل لملفات الحاوية الأساسية (Documents / Library / tmp)
    clearAllLocalFiles();
    
    // (5) مسح حاويات المجموعة (Group Containers / AppGroup) وما بها من SDKs إعلانية
    clearGroupContainers();
    
    // (6) تنظيف متغيرات الذاكرة
    @synchronized(networkLogs) {
        [networkLogs removeAllObjects];
    }
    sessionFakeIP = nil;
    currentRealIP = @"جاري الجلب...";
    
    // (7) توليد هويات ومحددات جديدة تماماً (IDFA + UDID)
    fakeAdvertisingIDString = generateRandomUUIDString();
    fakeUDIDString          = generateRandomUDID();
    updateAtlantaLocation();
    generateSessionIP();
    fetchRealIP();
    
    NSLog(@"[Reset] اكتمل التنظيف، سيتم إغلاق التطبيق بعد 5 ثوان ...");
    
    // (8) مهلة كافية لاستكمال عمليات الحذف غير المتزامنة على القرص، ثم الإنهاء
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
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
    
    NSString *idfaStr = fakeAdvertisingIDString ?: [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    NSString *udidDisplay = fakeUDIDString ?: @"غير متوفر";
    
    NSString *locationInfo = [NSString stringWithFormat:@"📍 الموقع الحالي (أتلانطا):\nLat: %.4f\nLon: %.4f", currentLat, currentLon];
    NSString *ipInfo = [NSString stringWithFormat:@"🌐 IP الجلسة الوهمي:\n%@\n\n🛡️ IP الشبكة الفعلي:\n%@", sessionFakeIP ?: @"غير محدد", currentRealIP];
    NSString *identsInfo = [NSString stringWithFormat:@"🆔 المعرفات:\nUDID: %@\nIDFA: %@", udidDisplay, idfaStr];
    
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
// MARK: - الزر العائم الأزرق وإدارته
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
        if (self.floatingWindow) return;
        
        CGRect screenBounds = [UIScreen mainScreen].bounds;
        self.floatingWindow = [[AtlantaWindow alloc] initWithFrame:screenBounds];
        self.floatingWindow.windowLevel = UIWindowLevelAlert + 1000;
        self.floatingWindow.hidden = NO;
        self.floatingWindow.backgroundColor = [UIColor clearColor];
        
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        self.floatingWindow.rootViewController = vc;
        
        // الزر الأزرق الوحيد (🔄) — ينفذ إعادة تعيين كاملة + UDID + IDFA جديد
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
// MARK: - الـ Hooks الآمنة
// ============================================================

%ctor {
    updateAtlantaLocation();
    generateSessionIP();
    fakeAdvertisingIDString = generateRandomUUIDString();
    fakeUDIDString          = generateRandomUDID();
    fetchRealIP();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[AtlantaInfoManager sharedInstance] setupFloatingButtons];
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
