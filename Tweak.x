#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>

static double currentLat = 0.0;
static double currentLon = 0.0;
static NSString *sessionFakeIP = @"";
static NSString *currentRealIP = @"جاري الجلب...";
static NSMutableArray *networkLogs = nil;

double randomInRange(double min, double max) {
    return min + (arc4random_uniform(UINT32_MAX) / (double)UINT32_MAX) * (max - min);
}

void updateAtlantaLocation() {
    currentLat = randomInRange(33.7000, 33.8000);
    currentLon = randomInRange(-84.4500, -84.3500);
}

// اختيار IP عشوائي من قائمة ثابتة تحتوي على 200 IP ضمن نطاقي 172.57 و 172.59
void initializeSessionIP() {
    NSArray *ipPool = @[
        // نطاق 172.57.x.x (100 IP)
        @"172.57.12.15", @"172.57.18.99", @"172.57.25.40", @"172.57.31.88", @"172.57.44.12",
        @"172.57.50.105", @"172.57.63.22", @"172.57.70.190", @"172.57.81.45", @"172.57.95.200",
        @"172.57.102.7", @"172.57.115.64", @"172.57.120.33", @"172.57.135.150", @"172.57.142.85",
        @"172.57.155.19", @"172.57.160.77", @"172.57.172.90", @"172.57.185.11", @"172.57.199.240",
        @"172.57.4.50", @"172.57.15.80", @"172.57.29.110", @"172.57.38.130", @"172.57.48.160",
        @"172.57.55.190", @"172.57.68.210", @"172.57.75.240", @"172.57.88.15", @"172.57.92.45",
        @"172.57.108.75", @"172.57.112.105", @"172.57.125.135", @"172.57.130.165", @"172.57.148.195",
        @"172.57.152.225", @"172.57.165.20", @"172.57.178.50", @"172.57.182.80", @"172.57.195.110",
        @"172.57.10.140", @"172.57.22.170", @"172.57.35.200", @"172.57.42.230", @"172.57.58.10",
        @"172.57.62.40", @"172.57.78.70", @"172.57.82.100", @"172.57.98.130", @"172.57.105.160",
        @"172.57.118.190", @"172.57.122.220", @"172.57.138.25", @"172.57.145.55", @"172.57.158.85",
        @"172.57.162.115", @"172.57.175.145", @"172.57.188.175", @"172.57.192.205", @"172.57.1.235",
        @"172.57.8.20", @"172.57.20.50", @"172.57.33.80", @"172.57.40.110", @"172.57.53.140",
        @"172.57.60.170", @"172.57.73.200", @"172.57.80.230", @"172.57.93.15", @"172.57.100.45",
        @"172.57.113.75", @"172.57.128.105", @"172.57.133.135", @"172.57.146.165", @"172.57.150.195",
        @"172.57.163.225", @"172.57.170.20", @"172.57.183.50", @"172.57.190.80", @"172.57.5.110",
        @"172.57.16.140", @"172.57.28.170", @"172.57.36.200", @"172.57.45.230", @"172.57.52.10",
        @"172.57.65.40", @"172.57.72.70", @"172.57.85.100", @"172.57.90.130", @"172.57.103.160",
        @"172.57.110.190", @"172.57.123.220", @"172.57.137.25", @"172.57.140.55", @"172.57.153.85",
        @"172.57.168.115", @"172.57.173.145", @"172.57.186.175", @"172.57.198.205", @"172.57.9.235",

        // نطاق 172.59.x.x (100 IP)
        @"172.59.14.22", @"172.59.21.55", @"172.59.35.88", @"172.59.41.11", @"172.59.55.144",
        @"172.59.60.177", @"172.59.74.210", @"172.59.83.243", @"172.59.91.10", @"172.59.104.44",
        @"172.59.111.77", @"172.59.125.110", @"172.59.130.143", @"172.59.144.176", @"172.59.151.209",
        @"172.59.165.242", @"172.59.172.15", @"172.59.185.48", @"172.59.190.81", @"172.59.199.114",
        @"172.59.3.30", @"172.59.11.60", @"172.59.24.90", @"172.59.32.120", @"172.59.45.150",
        @"172.59.52.180", @"172.59.65.210", @"172.59.70.240", @"172.59.84.20", @"172.59.90.50",
        @"172.59.103.80", @"172.59.110.110", @"172.59.123.140", @"172.59.132.170", @"172.59.145.200",
        @"172.59.150.230", @"172.59.163.10", @"172.59.170.40", @"172.59.183.70", @"172.59.192.100",
        @"172.59.6.130", @"172.59.15.160", @"172.59.22.190", @"172.59.38.220", @"172.59.42.25",
        @"172.59.58.55", @"172.59.62.85", @"172.59.75.115", @"172.59.80.145", @"172.59.95.175",
        @"172.59.100.205", @"172.59.113.235", @"172.59.120.10", @"172.59.135.40", @"172.59.140.70",
        @"172.59.155.100", @"172.59.160.130", @"172.59.175.160", @"172.59.180.190", @"172.59.195.220",
        @"172.59.2.25", @"172.59.18.55", @"172.59.25.85", @"172.59.39.115", @"172.59.48.145",
        @"172.59.59.175", @"172.59.68.205", @"172.59.78.235", @"172.59.88.10", @"172.59.98.40",
        @"172.59.108.70", @"172.59.118.100", @"172.59.128.130", @"172.59.138.160", @"172.59.148.190",
        @"172.59.158.220", @"172.59.168.25", @"172.59.178.55", @"172.59.188.85", @"172.59.198.115",
        @"172.59.7.145", @"172.59.16.175", @"172.59.29.205", @"172.59.36.235", @"172.59.49.20",
        @"172.59.53.50", @"172.59.66.80", @"172.59.73.110", @"172.59.86.140", @"172.59.93.170",
        @"172.59.106.200", @"172.59.115.230", @"172.59.126.10", @"172.59.133.40", @"172.59.146.70",
        @"172.59.153.100", @"172.59.166.130", @"172.59.173.160", @"172.59.186.190", @"172.59.193.220"
    ];
    
    int randomIndex = arc4random_uniform((uint32_t)ipPool.count);
    sessionFakeIP = ipPool[randomIndex];
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

// واجهة منبثقة مخصصة
@interface AtlantaReportViewController : UIViewController
@end

@implementation AtlantaReportViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scrollView];
    
    NSString *udidStr = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    NSUUID *idfaUUID = [[ASIdentifierManager sharedManager] advertisingIdentifier];
    NSString *idfaStr = [idfaUUID UUIDString];
    
    NSString *locationInfo = [NSString stringWithFormat:@"📍 الموقع الحالي (أتلانطا):\nLat: %.4f\nLon: %.4f", currentLat, currentLon];
    NSString *ipInfo = [NSString stringWithFormat:@"🌐 IP الجلسة الوهمي الحالي (من القائمة الثابتة):\n%@\n\n🛡️ ايبى الشبكة الفعلي (VPN):\n%@", sessionFakeIP, currentRealIP];
    NSString *identsInfo = [NSString stringWithFormat:@"🆔 المعرفات:\nUDID: %@\nIDFA: %@", udidStr, idfaStr];
    
    NSString *logsText = @"";
    @synchronized(networkLogs) {
        if (networkLogs && networkLogs.count > 0) {
            logsText = [networkLogs componentsJoinedByString:@"\n\n--------------------\n\n"];
        } else {
            logsText = @"لا توجد طلبات مسجلة بعد.";
        }
    }
    
    NSString *fullReport = [NSString stringWithFormat:@"%@\n\n%@\n\n%@\n\n📋 تفاصيل الطلبات والآيبات:\n%@", locationInfo, ipInfo, identsInfo, logsText];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 60, self.view.bounds.size.width - 40, 0)];
    label.text = fullReport;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:13];
    label.numberOfLines = 0;
    [label sizeToFit];
    
    scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, label.frame.size.height + 120);
    [scrollView addSubview:label];
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(20, 20, 80, 35);
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
        [self.floatingBtn setTitle:@"ATL" forState:UIControlStateNormal];
        [self.floatingBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.floatingBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        self.floatingBtn.layer.cornerRadius = 30;
        self.floatingBtn.layer.shadowColor = [UIColor blackColor].CGColor;
        self.floatingBtn.layer.shadowOffset = CGSizeMake(0, 2);
        self.floatingBtn.layer.shadowOpacity = 0.5;
        self.floatingBtn.layer.shadowRadius = 5;
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self.floatingBtn addGestureRecognizer:pan];
        
        [self.floatingBtn addTarget:self action:@selector(showFullDetailsPopup) forControlEvents:UIControlEventTouchUpInside];
        
        [vc.view addSubview:self.floatingBtn];
    });
}

- (void)handlePan:(UIPanGestureRecognizer * _Nonnull)gesture {
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

- (void)showFullDetailsPopup {
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIViewController *rootVC = keyWindow.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    
    AtlantaReportViewController *reportVC = [[AtlantaReportViewController alloc] init];
    reportVC.modalPresentationStyle = UIModalPresentationFullScreen;
    [rootVC presentViewController:reportVC animated:YES completion:nil];
}

@end

// إعداد الجلسة فور تشغيل التطبيق
%ctor {
    updateAtlantaLocation();
    initializeSessionIP(); // اختيار آبي عشوائي من قائمة الـ 200 آبي طوال الجلسة
    fetchRealIP();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
    
    [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Forwarded-For"];
    [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"Client-IP"];
    [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Real-IP"];
    
    NSString *urlString = request.URL.absoluteString;
    if (urlString) {
        logNetworkRequest(urlString, sessionFakeIP, currentLat, currentLon);
    }
    
    return %orig(mutableReq, completionHandler);
}
%end
