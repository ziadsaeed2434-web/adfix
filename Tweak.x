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

// المعرفات الوهمية (تتغير مع كل ضغطة زر)
static NSUUID *fakeVendorID = nil;
static NSUUID *fakeAdvertisingID = nil;

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

// ============================================================
// MARK: - توليد 10 IPs واختيار الأفضل
// ============================================================

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
    NSLog(@"[Injector] 🔍 جاري التحقق من 10 IPs...");
    NSString *selectedIP = nil;
    for (int i = 0; i < candidates.count; i++) {
        NSString *ip = candidates[i];
        if (verifyIPQuality(ip)) {
            selectedIP = ip;
            NSLog(@"[Injector] ✅ تم اختيار IP جيد: %@", ip);
            break;
        }
    }
    if (!selectedIP) {
        selectedIP = candidates.lastObject;
        NSLog(@"[Injector] ⚠️ نستخدم IP افتراضي: %@", selectedIP);
    }
    sessionFakeIP = selectedIP;
}

// ============================================================
// MARK: - توليد معرفات وهمية جديدة
// ============================================================

void generateFakeIdentifiers() {
    fakeVendorID = [NSUUID UUID];
    fakeAdvertisingID = [NSUUID UUID];
    NSLog(@"[Injector] 🆔 معرفات جديدة: Vendor=%@, IDFA=%@", [fakeVendorID UUIDString], [fakeAdvertisingID UUIDString]);
}

// ============================================================
// MARK: - مسح Keychain بالكامل مع إعادة كتابة بيانات الحساب (محاكاة تثبيت جديد)
// ============================================================

void clearKeychainKeepingAccount() {
    NSLog(@"[Injector] 🔑 حفظ بيانات الحساب ثم مسح كل Keychain...");
    
    // 1. قراءة قيم userIDKey و accessTokenKey
    NSString *userID = nil;
    NSString *accessToken = nil;
    NSArray *keysToKeep = @[@"userIDKey", @"accessTokenKey"];
    
    for (NSString *account in keysToKeep) {
        NSDictionary *query = @{
            (id)kSecClass: (id)kSecClassGenericPassword,
            (id)kSecAttrService: @"com.codebysms",
            (id)kSecAttrAccount: account,
            (id)kSecReturnData: @YES,
            (id)kSecMatchLimit: (id)kSecMatchLimitOne
        };
        CFDataRef dataRef = NULL;
        OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&dataRef);
        if (status == errSecSuccess && dataRef != NULL) {
            NSData *data = (__bridge NSData *)dataRef;
            NSString *value = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if ([account isEqualToString:@"userIDKey"]) {
                userID = value;
            } else if ([account isEqualToString:@"accessTokenKey"]) {
                accessToken = value;
            }
            CFRelease(dataRef);
        }
    }
    
    // 2. مسح كل Keychain الخاص بالتطبيق (جميع العناصر)
    NSDictionary *deleteQuery = @{
        (id)kSecClass: (id)kSecClassGenericPassword,
        (id)kSecMatchLimit: (id)kSecMatchLimitAll
    };
    SecItemDelete((CFDictionaryRef)deleteQuery);
    NSLog(@"[Injector] 🗑️ تم مسح كل Keychain.");
    
    // 3. إعادة كتابة بيانات الحساب
    if (userID) {
        NSDictionary *addQuery = @{
            (id)kSecClass: (id)kSecClassGenericPassword,
            (id)kSecAttrService: @"com.codebysms",
            (id)kSecAttrAccount: @"userIDKey",
            (id)kSecValueData: [userID dataUsingEncoding:NSUTF8StringEncoding]
        };
        SecItemAdd((CFDictionaryRef)addQuery, NULL);
        NSLog(@"[Injector] ✅ إعادة كتابة userIDKey");
    }
    if (accessToken) {
        NSDictionary *addQuery = @{
            (id)kSecClass: (id)kSecClassGenericPassword,
            (id)kSecAttrService: @"com.codebysms",
            (id)kSecAttrAccount: @"accessTokenKey",
            (id)kSecValueData: [accessToken dataUsingEncoding:NSUTF8StringEncoding]
        };
        SecItemAdd((CFDictionaryRef)addQuery, NULL);
        NSLog(@"[Injector] ✅ إعادة كتابة accessTokenKey");
    }
    NSLog(@"[Injector] ✅ تم مسح Keychain مع بقاء بيانات الحساب.");
}

// ============================================================
// MARK: - جلب IP الحقيقي (للعلم)
// ============================================================

void fetchRealIP() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURL *url = [NSURL URLWithString:@"https://api.ipify.org"];
        NSString *ip = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
        currentRealIP = (ip && ip.length > 0) ? ip : @"غير قادر على الجلب";
    });
}

// ============================================================
// MARK: - تسجيل الطلبات (للشاشة الثانية)
// ============================================================

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
// MARK: - إعادة الضبط الكاملة (محاكاة تثبيت جديد مع الحساب نفسه)
// ============================================================

void performFullReset() {
    NSLog(@"[Injector] 🔄 بدء إعادة الضبط (محاكاة تثبيت جديد مع الحساب نفسه)...");
    
    // 1. مسح الكوكيز
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
        [cookieStorage deleteCookie:cookie];
    }
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    // 2. مسح NSUserDefaults
    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 3. مسح الملفات (Documents & Library)
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docPath = paths.firstObject;
    if (docPath) {
        for (NSString *item in [fm contentsOfDirectoryAtPath:docPath error:nil]) {
            [fm removeItemAtPath:[docPath stringByAppendingPathComponent:item] error:nil];
        }
    }
    paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libPath = paths.firstObject;
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
    
    // 4. مسح WebKit
    NSSet *dataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:dataTypes
                                               modifiedSince:[NSDate distantPast]
                                           completionHandler:^{
        NSLog(@"[Injector] 🧹 WebKit مسح.");
    }];
    
    // 5. مسح Keychain مع حفظ الحساب (طريقة محاكاة التثبيت الجديد)
    clearKeychainKeepingAccount();
    
    // 6. مسح سجل الطلبات
    @synchronized(networkLogs) { [networkLogs removeAllObjects]; }
    
    // 7. تجديد كل شيء: الموقع، IP، المعرفات
    updateAtlantaLocation();
    generateSessionIP();
    generateFakeIdentifiers();
    fetchRealIP();
    
    NSLog(@"[Injector] ✅ اكتملت إعادة الضبط. IP: %@", sessionFakeIP);
}

// ============================================================
// MARK: - شاشة التفاصيل (للاطلاع على البيانات الحالية)
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
    
    NSString *udidStr = fakeVendorID ? [fakeVendorID UUIDString] : [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    NSString *idfaStr = fakeAdvertisingID ? [fakeAdvertisingID UUIDString] : [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    
    NSString *locationInfo = [NSString stringWithFormat:@"📍 أتلانتا:\nLat: %.4f\nLon: %.4f", currentLat, currentLon];
    NSString *ipInfo = [NSString stringWithFormat:@"🌐 IP وهمي: %@\n🛡️ IP حقيقي: %@", sessionFakeIP ?: @"غير محدد", currentRealIP];
    NSString *identsInfo = [NSString stringWithFormat:@"🆔 Vendor: %@\nIDFA: %@", udidStr, idfaStr];
    
    NSString *logsText = @"";
    @synchronized(networkLogs) {
        if (networkLogs.count) logsText = [networkLogs componentsJoinedByString:@"\n\n---\n\n"];
        else logsText = @"لا توجد طلبات بعد.";
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
// MARK: - النافذة العائمة والزر الرئيسي
// ============================================================

@interface AtlantaWindow : UIWindow
@end
@implementation AtlantaWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *btn = [self viewWithTag:999888];
    if (btn && CGRectContainsPoint(btn.frame, point)) return YES;
    return NO;
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
    UIAlertController *done = [UIAlertController alertControllerWithTitle:@"✅ تم"
                                                                  message:@"تمت إعادة الضبط (محاكاة تثبيت جديد) مع بقاء حسابك.\nستظهر الإعلانات الجديدة فوراً."
                                                           preferredStyle:UIAlertControllerStyleAlert];
    [done addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:nil]];
    [rootVC presentViewController:done animated:YES completion:nil];
}
@end

// ============================================================
// MARK: - الـ Hooks
// ============================================================

%ctor {
    generateSessionIP();
    generateFakeIdentifiers();
    fetchRealIP();
    updateAtlantaLocation();
    
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

%hook UIDevice
- (NSUUID *)identifierForVendor {
    return fakeVendorID ?: %orig;
}
%end

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return fakeAdvertisingID ?: %orig;
}
%end
