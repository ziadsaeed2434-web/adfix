#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

// ============================================================
// MARK: - المتغيرات العامة
// ============================================================

static double currentLat = 0.0;
static double currentLon = 0.0;
static NSString *sessionFakeIP = nil;
static NSString *currentRealIP = @"جاري الجلب...";
static NSMutableArray *networkLogs = nil;

static NSUUID *fakeAdvertisingID = nil;
static NSString *fakeUDID = nil; // معرف UDID وهمي جديد لكل جلسة

// ============================================================
// MARK: - دوال مساعدة وتوليد البيانات المتجددة
// ============================================================

double randomInRange(double min, double max) {
    return min + (arc4random_uniform(UINT32_MAX) / (double)UINT32_MAX) * (max - min);
}

void updateAtlantaLocation() {
    currentLat = randomInRange(33.7000, 33.8000);
    currentLon = randomInRange(-84.4500, -84.3500);
}

void generateSessionIP() {
    int allowedSecondOctets[] = {56, 57, 59};
    int index = arc4random_uniform(3);
    int second = allowedSecondOctets[index];
    int third = arc4random_uniform(256);
    int fourth = arc4random_uniform(256);
    
    sessionFakeIP = [NSString stringWithFormat:@"172.%d.%d.%d", second, third, fourth];
}

void generateFakeIdentifiers() {
    fakeAdvertisingID = [NSUUID UUID];
    fakeUDID = [[NSUUID UUID] UUIDString]; // توليد UDID وهمي جديد كلياً
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
// MARK: - مسح الكاش وتوليد هوية جديدة بالكامل (IP, الموقع, UDID, IDFA)
// ============================================================

void clearAppCacheOnly() {
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
        [cookieStorage deleteCookie:cookie];
    }
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libPath = [paths firstObject];
    if (libPath) {
        NSString *cachePath = [libPath stringByAppendingPathComponent:@"Caches"];
        for (NSString *item in [fm contentsOfDirectoryAtPath:cachePath error:nil]) {
            [fm removeItemAtPath:[cachePath stringByAppendingPathComponent:item] error:nil];
        }
    }
    
    NSSet *dataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:dataTypes
                                               modifiedSince:[NSDate distantPast]
                                           completionHandler:^{}];
    
    // تجديد كافة بيانات الهوية والشبكة
    updateAtlantaLocation();
    generateSessionIP();
    generateFakeIdentifiers();
    fetchRealIP();
    
    @synchronized(networkLogs) {
        [networkLogs removeAllObjects];
    }
}

// ============================================================
// MARK: - واجهة عرض التفاصيل (الزر العائم)
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
    
    NSString *udidStr = fakeUDID ?: [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    NSString *idfaStr = fakeAdvertisingID ? [fakeAdvertisingID UUIDString] : [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    
    NSString *locationInfo = [NSString stringWithFormat:@"📍 الموقع الحالي (أتلانطا):\nLat: %.4f\nLon: %.4f", currentLat, currentLon];
    NSString *ipInfo = [NSString stringWithFormat:@"🌐 IP الجلسة الوهمي (نطاق 172.56/57/59):\n%@\n\n🛡️ IP الشبكة الفعلي:\n%@", sessionFakeIP ?: @"غير محدد", currentRealIP];
    NSString *identsInfo = [NSString stringWithFormat:@"🆔 المعرفات الوهمية:\nUDID (وهمي جديد): %@\nIDFA (وهمي جديد): %@", udidStr, idfaStr];
    
    NSString *logsText = @"";
    @synchronized(networkLogs) {
        if (networkLogs && networkLogs.count > 0) {
            logsText = [networkLogs componentsJoinedByString:@"\n\n--------------------\n\n"];
        } else {
            logsText = @"لا توجد طلبات مسجلة بعد.";
        }
    }
    
    NSString *fullReport = [NSString stringWithFormat:@"%@\n\n%@\n\n%@\n\n📋 سجل الطلبات الشبكية:\n%@", locationInfo, ipInfo, identsInfo, logsText];
    
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

@interface AtlantaWindow : UIWindow
@end

@implementation AtlantaWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *btn = [self viewWithTag:999888];
    if (btn && CGRectContainsPoint(btn.frame, point)) {
        return YES;
    }
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
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
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
        
        [self.floatingBtn addTarget:self action:@selector(handleCacheReset) forControlEvents:UIControlEventTouchUpInside];
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

- (void)handleCacheReset {
    clearAppCacheOnly();
    
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIViewController *rootVC = keyWindow.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    
    UIAlertController *done = [UIAlertController alertControllerWithTitle:@"تم التجديد بنجاح"
                                                                  message:[NSString stringWithFormat:@"تم تغيير الهوية (UDID و IDFA) وتوليد IP جديد:\n%@", sessionFakeIP]
                                                           preferredStyle:UIAlertControllerStyleAlert];
    
    [done addAction:[UIAlertAction actionWithTitle:@"عرض التفاصيل" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        AtlantaReportViewController *reportVC = [[AtlantaReportViewController alloc] init];
        reportVC.modalPresentationStyle = UIModalPresentationPageSheet;
        [rootVC presentViewController:reportVC animated:YES completion:nil];
    }]];
    
    [done addAction:[UIAlertAction actionWithTitle:@"حسناً" style:UIAlertActionStyleCancel handler:nil]];
    [rootVC presentViewController:done animated:YES completion:nil];
}

@end

// ============================================================
// MARK: - Method Swizzling البديل (بدون جلبريك) وتزوير المعرفات
// ============================================================

@interface FakeSwizzler : NSObject
@end

@implementation FakeSwizzler

- (void)swizzled_startUpdatingLocation {
    updateAtlantaLocation();
    CLLocation *fakeLocation = [[CLLocation alloc] initWithLatitude:currentLat longitude:currentLon];
    id delegate = [self valueForKey:@"delegate"];
    if (delegate && [delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        [delegate locationManager:delegate didUpdateLocations:@[fakeLocation]];
    }
}

- (CLLocation *)swizzled_location {
    updateAtlantaLocation();
    return [[CLLocation alloc] initWithLatitude:currentLat longitude:currentLon];
}

- (NSURLSessionDataTask *)swizzled_dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    if (sessionFakeIP) {
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Forwarded-For"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"Client-IP"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Real-IP"];
    }
    NSString *urlString = request.URL.absoluteString;
    if (urlString) {
        // تم تصحيح القوس هنا لتجنب خطأ التجميع
        logNetworkRequest(urlString, sessionFakeIP ?: @"غير محدد", currentLat, currentLon);
    }
    return [self swizzled_dataTaskWithRequest:mutableReq completionHandler:completionHandler];
}

- (NSUUID *)swizzled_advertisingIdentifier {
    if (fakeAdvertisingID) {
        return fakeAdvertisingID;
    }
    return [self swizzled_advertisingIdentifier];
}

// تزوير الـ UDID (معرف الجهاز للمورد identifierForVendor) ليتغير في كل مرة
- (NSUUID *)swizzled_identifierForVendor {
    if (fakeUDID) {
        return [[NSUUID alloc] initWithUUIDString:fakeUDID];
    }
    return [self swizzled_identifierForVendor];
}

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        updateAtlantaLocation();
        generateSessionIP();
        generateFakeIdentifiers();
        fetchRealIP();
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[AtlantaInfoManager sharedInstance] setupFloatingButton];
        });
        
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                            object:nil
                                                             queue:[NSOperationQueue mainQueue]
                                                        usingBlock:^(NSNotification *note) {
            clearAppCacheOnly();
        }];
        
        // Swizzling CLLocationManager
        Class locClass = NSClassFromString(@"CLLocationManager");
        if (locClass) {
            Method originalStart = class_getInstanceMethod(locClass, @selector(startUpdatingLocation));
            Method swizzledStart = class_getInstanceMethod([FakeSwizzler class], @selector(swizzled_startUpdatingLocation));
            method_exchangeImplementations(originalStart, swizzledStart);
            
            Method originalLoc = class_getInstanceMethod(locClass, @selector(location));
            Method swizzledLoc = class_getInstanceMethod([FakeSwizzler class], @selector(swizzled_location));
            method_exchangeImplementations(originalLoc, swizzledLoc);
        }
        
        // Swizzling NSURLSession
        Class sessionClass = NSClassFromString(@"NSURLSession");
        if (sessionClass) {
            Method originalTask = class_getInstanceMethod(sessionClass, @selector(dataTaskWithRequest:completionHandler:));
            Method swizzledTask = class_getInstanceMethod([FakeSwizzler class], @selector(swizzled_dataTaskWithRequest:completionHandler:));
            method_exchangeImplementations(originalTask, swizzledTask);
        }
        
        // Swizzling ASIdentifierManager (IDFA)
        Class adClass = NSClassFromString(@"ASIdentifierManager");
        if (adClass) {
            Method originalAd = class_getInstanceMethod(adClass, @selector(advertisingIdentifier));
            Method swizzledAd = class_getInstanceMethod([FakeSwizzler class], @selector(swizzled_advertisingIdentifier));
            method_exchangeImplementations(originalAd, swizzledAd);
        }

        // Swizzling UIDevice لجعل الـ UDID (identifierForVendor) يتغير باستمرار
        Class deviceClass = NSClassFromString(@"UIDevice");
        if (deviceClass) {
            Method originalVendor = class_getInstanceMethod(deviceClass, @selector(identifierForVendor));
            Method swizzledVendor = class_getInstanceMethod([FakeSwizzler class], @selector(swizzled_identifierForVendor));
            method_exchangeImplementations(originalVendor, swizzledVendor);
        }
    });
}

@end

