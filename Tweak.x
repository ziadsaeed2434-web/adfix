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

void generateSessionIP() {
    // قائمة الأبيات المطلوبة حصرياً (من .1 إلى .255)
    NSArray *fixedIPList = @[
        @"76.195.72.1", @"76.195.72.2", @"76.195.72.3", @"76.195.72.4", @"76.195.72.5", 
        @"76.195.72.6", @"76.195.72.7", @"76.195.72.8", @"76.195.72.9", @"76.195.72.10", 
        @"76.195.72.11", @"76.195.72.12", @"76.195.72.13", @"76.195.72.14", @"76.195.72.15", 
        @"76.195.72.16", @"76.195.72.17", @"76.195.72.18", @"76.195.72.19", @"76.195.72.20", 
        @"76.195.72.21", @"76.195.72.22", @"76.195.72.23", @"76.195.72.24", @"76.195.72.25", 
        @"76.195.72.26", @"76.195.72.27", @"76.195.72.28", @"76.195.72.29", @"76.195.72.30", 
        @"76.195.72.31", @"76.195.72.32", @"76.195.72.33", @"76.195.72.34", @"76.195.72.35", 
        @"76.195.72.36", @"76.195.72.37", @"76.195.72.38", @"76.195.72.39", @"76.195.72.40", 
        @"76.195.72.41", @"76.195.72.42", @"76.195.72.43", @"76.195.72.44", @"76.195.72.45", 
        @"76.195.72.46", @"76.195.72.47", @"76.195.72.48", @"76.195.72.49", @"76.195.72.50", 
        @"76.195.72.51", @"76.195.72.52", @"76.195.72.53", @"76.195.72.54", @"76.195.72.55", 
        @"76.195.72.56", @"76.195.72.57", @"76.195.72.58", @"76.195.72.59", @"76.195.72.60", 
        @"76.195.72.61", @"76.195.72.62", @"76.195.72.63", @"76.195.72.64", @"76.195.72.65", 
        @"76.195.72.66", @"76.195.72.67", @"76.195.72.68", @"76.195.72.69", @"76.195.72.70", 
        @"76.195.72.71", @"76.195.72.72", @"76.195.72.73", @"76.195.72.74", @"76.195.72.75", 
        @"76.195.72.76", @"76.195.72.77", @"76.195.72.78", @"76.195.72.79", @"76.195.72.80", 
        @"76.195.72.81", @"76.195.72.82", @"76.195.72.83", @"76.195.72.84", @"76.195.72.85", 
        @"76.195.72.86", @"76.195.72.87", @"76.195.72.88", @"76.195.72.89", @"76.195.72.90", 
        @"76.195.72.91", @"76.195.72.92", @"76.195.72.93", @"76.195.72.94", @"76.195.72.95", 
        @"76.195.72.96", @"76.195.72.97", @"76.195.72.98", @"76.195.72.99", @"76.195.72.100", 
        @"76.195.72.101", @"76.195.72.102", @"76.195.72.103", @"76.195.72.104", @"76.195.72.105", 
        @"76.195.72.106", @"76.195.72.107", @"76.195.72.108", @"76.195.72.109", @"76.195.72.110", 
        @"76.195.72.111", @"76.195.72.112", @"76.195.72.113", @"76.195.72.114", @"76.195.72.115", 
        @"76.195.72.116", @"76.195.72.117", @"76.195.72.118", @"76.195.72.119", @"76.195.72.120", 
        @"76.195.72.121", @"76.195.72.122", @"76.195.72.123", @"76.195.72.124", @"76.195.72.125", 
        @"76.195.72.126", @"76.195.72.127", @"76.195.72.128", @"76.195.72.129", @"76.195.72.130", 
        @"76.195.72.131", @"76.195.72.132", @"76.195.72.133", @"76.195.72.134", @"76.195.72.135", 
        @"76.195.72.136", @"76.195.72.137", @"76.195.72.138", @"76.195.72.139", @"76.195.72.140", 
        @"76.195.72.141", @"76.195.72.142", @"76.195.72.143", @"76.195.72.144", @"76.195.72.145", 
        @"76.195.72.146", @"76.195.72.147", @"76.195.72.148", @"76.195.72.149", @"76.195.72.150", 
        @"76.195.72.151", @"76.195.72.152", @"76.195.72.153", @"76.195.72.154", @"76.195.72.155", 
        @"76.195.72.156", @"76.195.72.157", @"76.195.72.158", @"76.195.72.159", @"76.195.72.160", 
        @"76.195.72.161", @"76.195.72.162", @"76.195.72.163", @"76.195.72.164", @"76.195.72.165", 
        @"76.195.72.166", @"76.195.72.167", @"76.195.72.168", @"76.195.72.169", @"76.195.72.170", 
        @"76.195.72.171", @"76.195.72.172", @"76.195.72.173", @"76.195.72.174", @"76.195.72.175", 
        @"76.195.72.176", @"76.195.72.177", @"76.195.72.178", @"76.195.72.179", @"76.195.72.180", 
        @"76.195.72.181", @"76.195.72.182", @"76.195.72.183", @"76.195.72.184", @"76.195.72.185", 
        @"76.195.72.186", @"76.195.72.187", @"76.195.72.188", @"76.195.72.189", @"76.195.72.190", 
        @"76.195.72.191", @"76.195.72.192", @"76.195.72.193", @"76.195.72.194", @"76.195.72.195", 
        @"76.195.72.196", @"76.195.72.197", @"76.195.72.198", @"76.195.72.199", @"76.195.72.200", 
        @"76.195.72.201", @"76.195.72.202", @"76.195.72.203", @"76.195.72.204", @"76.195.72.205", 
        @"76.195.72.206", @"76.195.72.207", @"76.195.72.208", @"76.195.72.209", @"76.195.72.210", 
        @"76.195.72.211", @"76.195.72.212", @"76.195.72.213", @"76.195.72.214", @"76.195.72.215", 
        @"76.195.72.216", @"76.195.72.217", @"76.195.72.218", @"76.195.72.219", @"76.195.72.220", 
        @"76.195.72.221", @"76.195.72.222", @"76.195.72.223", @"76.195.72.224", @"76.195.72.225", 
        @"76.195.72.226", @"76.195.72.227", @"76.195.72.228", @"76.195.72.229", @"76.195.72.230", 
        @"76.195.72.231", @"76.195.72.232", @"76.195.72.233", @"76.195.72.234", @"76.195.72.235", 
        @"76.195.72.236", @"76.195.72.237", @"76.195.72.238", @"76.195.72.239", @"76.195.72.240", 
        @"76.195.72.241", @"76.195.72.242", @"76.195.72.243", @"76.195.72.244", @"76.195.72.245", 
        @"76.195.72.246", @"76.195.72.247", @"76.195.72.248", @"76.195.72.249", @"76.195.72.250", 
        @"76.195.72.251", @"76.195.72.252", @"76.195.72.253", @"76.195.72.254", @"76.195.72.255"
    ];
    
    int randomIndex = arc4random_uniform((uint32_t)[fixedIPList count]);
    sessionFakeIP = fixedIPList[randomIndex];
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
// MARK: - مسح Keychain مع الحفاظ على الحساب
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
// MARK: - دوال العمليات (إلغاء التأخير تماماً وتنفيذ الخروج الفوري)
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
    
    // خروج فوري بدون أي تأخير
    exit(0);
}

void changeIdentifiersOnly() {
    fakeUDIDString = generateRandomUDID();
    
    // خروج فوري بدون أي تأخير
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
    
    NSString *idfaStr = fakeAdvertisingIDString ?: [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    NSString *udidDisplay = fakeUDIDString ?: @"غير متوفر (لم يتم التغيير بعد)";
    
    NSString *locationInfo = [NSString stringWithFormat:@"📍 الموقع الحالي (أتلانطا):\nLat: %.4f\nLon: %.4f", currentLat, currentLon];
    NSString *ipInfo = [NSString stringWithFormat:@"🌐 IP الجلسة الوهمي:\n%@\n\n🛡️ IP الشبكة الفعلي:\n%@", sessionFakeIP ?: @"غير محدد", currentRealIP];
    NSString *identsInfo = [NSString stringWithFormat:@"🆔 المعرفات:\nUDID (يتغير بالبرتقالي): %@\nIDFA (يتغير بالأزرق): %@", udidDisplay, idfaStr];
    
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
// MARK: - الأزرار العائمة وإدارتها
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
        
        self.changeIDBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.changeIDBtn.tag = 999777;
        self.changeIDBtn.frame = CGRectMake(20, 190, 55, 55);
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

- (void)handleChangeID {
    changeIdentifiersOnly();
}

@end

// ============================================================
// MARK: - الـ Hooks الآمنة
// ============================================================

%ctor {
    updateAtlantaLocation();
    generateSessionIP();
    fakeAdvertisingIDString = generateRandomUUIDString();
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
