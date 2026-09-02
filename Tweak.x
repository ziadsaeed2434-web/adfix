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

// المعرفات الوهمية (UDID و IDFA)
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

void fetchRealIP() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURL *url = [NSURL URLWithString:@"https://api.ipify.org"];
        NSString *ip = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
        currentRealIP = (ip && ip.length > 0) ? ip : @"غير قادر على الجلب";
    });
}

// ============================================================
// MARK: - توليد IP (نطاقات 172.56/57/59)
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
    NSString *selectedIP = nil;
    for (NSString *ip in candidates) {
        if (verifyIPQuality(ip)) {
            selectedIP = ip;
            break;
        }
    }
    if (!selectedIP) selectedIP = candidates.lastObject;
    sessionFakeIP = selectedIP;
}

// ============================================================
// MARK: - توليد معرفات وهمية (UDID و IDFA)
// ============================================================

void generateFakeIdentifiers() {
    fakeVendorID = [NSUUID UUID];
    fakeAdvertisingID = [NSUUID UUID];
}

// ============================================================
// MARK: - توليد قيم عشوائية بنفس نوع القيمة الأصلية
// ============================================================

id generateRandomValueForType(id originalValue) {
    if (!originalValue) return nil;
    
    // NSString
    if ([originalValue isKindOfClass:[NSString class]]) {
        NSString *str = (NSString *)originalValue;
        // إذا كانت القيمة تبدو كـ UUID، نولد UUID جديد
        NSRegularExpression *uuidRegex = [NSRegularExpression regularExpressionWithPattern:@"^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$" options:NSRegularExpressionCaseInsensitive error:nil];
        if ([uuidRegex numberOfMatchesInString:str options:0 range:NSMakeRange(0, str.length)] > 0) {
            return [NSUUID UUID].UUIDString;
        }
        // إذا كانت رقمية (مثل "12345")، نولد أرقاماً بنفس الطول
        if ([str rangeOfCharacterFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]].location == NSNotFound) {
            int len = (int)str.length;
            if (len == 0) len = 5;
            NSMutableString *result = [NSMutableString stringWithCapacity:len];
            for (int i = 0; i < len; i++) {
                [result appendFormat:@"%d", arc4random_uniform(10)];
            }
            return result;
        }
        // إذا كانت طويلة (مثل token)، نولد سلسلة عشوائية بنفس الطول
        int len = (int)str.length;
        if (len < 4) len = 16;
        NSMutableString *result = [NSMutableString stringWithCapacity:len];
        NSString *characters = @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
        for (int i = 0; i < len; i++) {
            [result appendFormat:@"%C", [characters characterAtIndex:arc4random_uniform((uint32_t)characters.length)]];
        }
        return result;
    }
    
    // NSNumber
    if ([originalValue isKindOfClass:[NSNumber class]]) {
        NSNumber *num = (NSNumber *)originalValue;
        const char *type = [num objCType];
        // Bool
        if (strcmp(type, @encode(BOOL)) == 0 || strcmp(type, @encode(char)) == 0) {
            return @(arc4random_uniform(2));
        }
        // Integer
        if (strcmp(type, @encode(int)) == 0 || strcmp(type, @encode(long)) == 0 || strcmp(type, @encode(long long)) == 0) {
            return @(arc4random_uniform(1000000));
        }
        // Double / Float
        if (strcmp(type, @encode(double)) == 0 || strcmp(type, @encode(float)) == 0) {
            double val = (double)arc4random_uniform(1000000) / 100.0;
            return @(val);
        }
        return @(arc4random_uniform(1000));
    }
    
    // NSArray
    if ([originalValue isKindOfClass:[NSArray class]]) {
        NSArray *arr = (NSArray *)originalValue;
        NSMutableArray *newArr = [NSMutableArray arrayWithCapacity:arr.count];
        for (id item in arr) {
            id newItem = generateRandomValueForType(item);
            if (newItem) [newArr addObject:newItem];
        }
        return newArr;
    }
    
    // NSDictionary
    if ([originalValue isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)originalValue;
        NSMutableDictionary *newDict = [NSMutableDictionary dictionaryWithCapacity:dict.count];
        for (NSString *key in dict) {
            id newVal = generateRandomValueForType(dict[key]);
            if (newVal) {
                // بعض المفاتيح الخاصة قد تحتوي على تواريخ أو قيم ثنائية، لكننا نتعامل معها كنصوص
                newDict[key] = newVal;
            }
        }
        return newDict;
    }
    
    // NSData (نحوله إلى نص عشوائي)
    if ([originalValue isKindOfClass:[NSData class]]) {
        NSData *data = (NSData *)originalValue;
        int len = (int)data.length;
        if (len == 0) len = 16;
        NSMutableString *result = [NSMutableString stringWithCapacity:len * 2];
        for (int i = 0; i < len; i++) {
            [result appendFormat:@"%02x", arc4random_uniform(256)];
        }
        return result;
    }
    
    // أي نوع آخر: نرجعه كما هو (لا نغيره)
    return originalValue;
}

// ============================================================
// MARK: - تغيير جميع قيم NSUserDefaults إلى قيم عشوائية جديدة
// ============================================================

void randomizeAllUserDefaults() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *currentDict = [defaults dictionaryRepresentation];
    
    // قائمة المفاتيح التي نستثنيها من التغيير (مفاتيح النظام أو المفاتيح التي قد تسبب مشاكل)
    NSArray *excludeKeys = @[
        @"AppleLocale", @"AppleLanguages", @"NSLanguages", @"AppleKeyboards"
    ];
    
    NSMutableDictionary *newDict = [NSMutableDictionary dictionary];
    
    for (NSString *key in currentDict) {
        // تخطي المفاتيح المستثناة
        if ([excludeKeys containsObject:key]) {
            newDict[key] = currentDict[key];
            continue;
        }
        
        id value = currentDict[key];
        id newValue = generateRandomValueForType(value);
        if (newValue) {
            newDict[key] = newValue;
            NSLog(@"[Injector] 🔄 تغيير NSUserDefaults: %@ = %@ -> %@", key, value, newValue);
        } else {
            newDict[key] = value;
        }
    }
    
    // مسح جميع القيم الحالية
    for (NSString *key in currentDict) {
        [defaults removeObjectForKey:key];
    }
    
    // كتابة القيم الجديدة
    for (NSString *key in newDict) {
        [defaults setObject:newDict[key] forKey:key];
    }
    
    [defaults synchronize];
    NSLog(@"[Injector] ✅ تم تغيير جميع قيم NSUserDefaults إلى قيم عشوائية جديدة");
}

// ============================================================
// MARK: - الإعادة الضبط الكاملة (مع تغيير البصمات و NSUserDefaults)
// ============================================================

void performFullReset() {
    NSLog(@"[Injector] 🔄 بدء إعادة الضبط الكاملة (تغيير كل البصمات و NSUserDefaults)");

    // 1. تغيير كل قيم NSUserDefaults إلى قيم عشوائية جديدة
    randomizeAllUserDefaults();

    // 2. حذف جميع ملفات التطبيق (Documents, Library, tmp) باستثناء Preferences (لأننا غيرناها)
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
            if (![item isEqualToString:@"Preferences"]) {
                [fm removeItemAtPath:[libPath stringByAppendingPathComponent:item] error:nil];
            }
        }
    }
    NSString *tmpPath = NSTemporaryDirectory();
    if (tmpPath) {
        for (NSString *item in [fm contentsOfDirectoryAtPath:tmpPath error:nil]) {
            [fm removeItemAtPath:[tmpPath stringByAppendingPathComponent:item] error:nil];
        }
    }
    NSLog(@"[Injector] 🗑️ جميع الملفات المحلية حذفت (عدا Preferences)");

    // 3. ⛔️ لا نمسح Keychain
    // 4. ⛔️ لا نمسح App Group

    // 5. مسح WebKit
    NSSet *dataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:dataTypes modifiedSince:[NSDate distantPast] completionHandler:^{}];
    NSLog(@"[Injector] 🗑️ WebKit مسح");

    // 6. مسح الكوكيز والكاش
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
        [cookieStorage deleteCookie:cookie];
    }
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    NSLog(@"[Injector] 🗑️ الكوكيز والكاش مسحوا");

    // 7. تجديد الموقع، IP، المعرفات (UDID و IDFA)
    updateAtlantaLocation();
    generateSessionIP();
    generateFakeIdentifiers();
    fetchRealIP();
    NSLog(@"[Injector] 🌐 تم تجديد الموقع، IP، UDID، IDFA");

    // 8. مسح سجل الطلبات
    @synchronized(networkLogs) { [networkLogs removeAllObjects]; }

    // 9. إعادة تشغيل التطبيق
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"✅ تم"
                                                                       message:@"تم تغيير جميع قيم NSUserDefaults إلى قيم عشوائية جديدة، وتغيير البصمات.\n(تم الحفاظ على Keychain و App Group).\nسيتم إعادة تشغيل التطبيق الآن."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            exit(0);
        }]];
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        UIViewController *rootVC = keyWindow.rootViewController;
        while (rootVC.presentedViewController) rootVC = rootVC.presentedViewController;
        [rootVC presentViewController:alert animated:YES completion:nil];
    });
}

// ============================================================
// MARK: - تسجيل الطلبات (للشاشة المساعدة)
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
// MARK: - شاشة التفاصيل
// ============================================================

@interface AtlantaReportViewController : UIViewController @end
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
    NSString *identsInfo = [NSString stringWithFormat:@"🆔 UDID (وهمي): %@\nIDFA (وهمي): %@", udidStr, idfaStr];
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
// MARK: - النافذة العائمة والزر 🔄
// ============================================================

@interface AtlantaWindow : UIWindow @end
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
}
@end

// ============================================================
// MARK: - الـ Hooks (الاعتراضات)
// ============================================================

%ctor {
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
