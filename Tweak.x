#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>

static double currentLat = 0.0;
static double currentLon = 0.0;
static NSString *sessionFiberIP = @"";
static NSString *currentRealIP = @"جاري الجلب...";
static NSMutableArray *networkLogs = nil;

double randomInRange(double min, double max) {
    return min + (arc4random_uniform(UINT32_MAX) / (double)UINT32_MAX) * (max - min);
}

void updateAtlantaLocation() {
    currentLat = randomInRange(33.7000, 33.8000);
    currentLon = randomInRange(-84.4500, -84.3500);
}

void initializeFiberSessionIP() {
    NSArray *fiberPool = @[
        [NSString stringWithFormat:@"104.172.%d.%d", arc4random_uniform(200) + 1, arc4random_uniform(200) + 1],
        [NSString stringWithFormat:@"107.135.%d.%d", arc4random_uniform(200) + 1, arc4random_uniform(200) + 1],
        [NSString stringWithFormat:@"70.132.%d.%d", arc4random_uniform(200) + 1, arc4random_uniform(200) + 1],
        [NSString stringWithFormat:@"172.56.%d.%d", arc4random_uniform(200) + 1, arc4random_uniform(200) + 1],
        [NSString stringWithFormat:@"69.168.%d.%d", arc4random_uniform(200) + 1, arc4random_uniform(200) + 1],
        [NSString stringWithFormat:@"209.85.220.%d", arc4random_uniform(200) + 1],
        [NSString stringWithFormat:@"192.178.6.%d", arc4random_uniform(200) + 1]
    ];
    
    int randomIndex = arc4random_uniform((uint32_t)fiberPool.count);
    sessionFiberIP = fiberPool[randomIndex];
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

void logNetworkRequest(NSString *urlString, NSString *ip, double lat, double lon) {
    if (!networkLogs) {
        networkLogs = [[NSMutableArray alloc] init];
    }
    
    NSURL *url = [NSURL URLWithString:urlString];
    NSString *path = url.path ? url.path : urlString;
    if (path.length > 30) {
        path = [[path substringToIndex:30] stringByAppendingString:@"..."];
    }
    
    NSString *logEntry = [NSString stringWithFormat:@"🔗 الرابط: %@\n⚡️ آيبي فايبر: %@\n📍 الموقع: (%.4f, %.4f)", path, ip, lat, lon];
    
    @synchronized(networkLogs) {
        [networkLogs insertObject:logEntry atIndex:0];
        if (networkLogs.count > 15) {
            [networkLogs removeLastObject];
        }
    }
}

// واجهة التقارير مع إصلاح مشكلة الإغلاق نهائياً
@interface AtlantaReportViewController : UIViewController
@end

@implementation AtlantaReportViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.98];
    
    // زر إغلاق تم وضعه في الأعلى وبمساحة ضغط واسعة لضمان الاستجابة الفورية
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(20, 50, 90, 40);
    closeBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:1.0];
    [closeBtn setTitle:@"إغلاق ✕" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    closeBtn.layer.cornerRadius = 10;
    [closeBtn addTarget:self action:@selector(dismissPopup) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeBtn];
    
    // شاشة التمرير تبدأ أسفل زر الإغلاق لتجنب التداخل
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 100, self.view.bounds.size.width, self.view.bounds.size.height - 100)];
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scrollView];
    
    NSString *udidStr = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    NSUUID *idfaUUID = [[ASIdentifierManager sharedManager] advertisingIdentifier];
    NSString *idfaStr = [idfaUUID UUIDString];
    
    NSString *locationInfo = [NSString stringWithFormat:@"📍 الموقع الحالي (أتلانطا):\nLat: %.4f\nLon: %.4f", currentLat, currentLon];
    NSString *ipInfo = [NSString stringWithFormat:@"⚡️ آيبي الفايبر الثابت للجلسة:\n%@\n\n🛡️ آيبى الشبكة الفعلي:\n%@", sessionFiberIP, currentRealIP];
    NSString *identsInfo = [NSString stringWithFormat:@"🆔 المعرفات:\nUDID: %@\nIDFA: %@", udidStr, idfaStr];
    
    NSString *logsText = @"";
    @synchronized(networkLogs) {
        if (networkLogs && networkLogs.count > 0) {
            logsText = [networkLogs componentsJoinedByString:@"\n\n--------------------\n\n"];
        } else {
            logsText = @"لا توجد طلبات مسجلة بعد.";
        }
    }
    
    NSString *fullReport = [NSString stringWithFormat:@"%@\n\n%@\n\n%@\n\n📋 تفاصيل طلبات الفايبر:\n%@", locationInfo, ipInfo, identsInfo, logsText];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, self.view.bounds.size.width - 40, 0)];
    label.text = fullReport;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:13];
    label.numberOfLines = 0;
    [label sizeToFit];
    
    scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, label.frame.size.height + 60);
    [scrollView addSubview:label];
}

- (void)dismissPopup {
    // طريقة آمنة بالكامل لإغلاق النافذة المنبثقة من جذورها دون كراش
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
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
    // طريقة آمنة جداً لجلب الـ RootViewController دون التسبب في كراش التطبيق
    UIViewController *rootVC = self.floatingWindow.rootViewController;
    if (rootVC.presentedViewController) {
        return; // منع فتح أكثر من نافذة في نفس الوقت
    }
    
    AtlantaReportViewController *reportVC = [[AtlantaReportViewController alloc] init];
    reportVC.modalPresentationStyle = UIModalPresentationFullScreen;
    [rootVC presentViewController:reportVC animated:YES completion:nil];
}

@end

%ctor {
    updateAtlantaLocation();
    initializeFiberSessionIP();
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
    
    [mutableReq setValue:sessionFiberIP forHTTPHeaderField:@"X-Forwarded-For"];
    [mutableReq setValue:sessionFiberIP forHTTPHeaderField:@"Client-IP"];
    [mutableReq setValue:sessionFiberIP forHTTPHeaderField:@"X-Real-IP"];
    
    NSString *urlString = request.URL.absoluteString;
    if (urlString) {
        logNetworkRequest(urlString, sessionFiberIP, currentLat, currentLon);
    }
    
    return %orig(mutableReq, completionHandler);
}
%end
