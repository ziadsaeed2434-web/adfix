#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>
#import <objc/runtime.h>

static double currentLat = 0.0;
static double currentLon = 0.0;
static NSString *currentRealIP = @"جاري الجلب...";
static NSMutableArray *networkLogs = nil;
static NSString *sessionAtlantaIP = nil;

double randomInRange(double min, double max) {
    return min + (arc4random_uniform(UINT32_MAX) / (double)UINT32_MAX) * (max - min);
}

void updateAtlantaLocation() {
    currentLat = randomInRange(33.7000, 33.8000);
    currentLon = randomInRange(-84.4500, -84.3500);
}

// دالة توليد IP جديد يتغير في كل مرة يتم فيها فتح التطبيق (جلسة جديدة)
NSString *getSessionAtlantaIP() {
    if (!sessionAtlantaIP) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        // توليد IP جديد فقط عند فتح التطبيق لأول مرة أو بعد إعادة تشغيله
        NSArray *atlantaPrefixes = @[@"50.200", @"24.98", @"68.192", @"73.140", @"104.156", @"172.56", @"198.54", @"23.128"];
        NSString *prefix = atlantaPrefixes[arc4random_uniform((uint32_t)atlantaPrefixes.count)];
        int third = arc4random_uniform(254) + 1;
        int fourth = arc4random_uniform(254) + 1;
        sessionAtlantaIP = [NSString stringWithFormat:@"%@.%d.%d", prefix, third, fourth];
        
        // حفظه مؤقتاً لهذه الجلسة
        [defaults setObject:sessionAtlantaIP forKey:@"AtlantaActiveSessionIP"];
        [defaults synchronize];
    }
    return sessionAtlantaIP;
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
    
    NSString *logEntry = [NSString stringWithFormat:@"🔗 الرابط: %@\n🌐 خرج عبر IP الجلسة: %@\n📍 الموقع: (%.4f, %.4f)", path, ip, lat, lon];
    
    @synchronized(networkLogs) {
        [networkLogs insertObject:logEntry atIndex:0];
        if (networkLogs.count > 15) {
            [networkLogs removeLastObject];
        }
    }
}

// واجهة التقارير مع زر لتغيير الـ IP يدوياً إذا رغبت دون الحاجة لإغلاق التطبيق
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
    NSString *ipInfo = [NSString stringWithFormat:@"🌐 نظام الـ IP (يتغير مع كل فتحة تطبيق):\nIP أتلانطا الحالي: %@\n\n🛡️ ايبى الشبكة الفعلي:\n%@", getSessionAtlantaIP(), currentRealIP];
    NSString *identsInfo = [NSString stringWithFormat:@"🆔 المعرفات:\nUDID: %@\nIDFA: %@", udidStr, idfaStr];
    
    NSString *logsText = @"";
    @synchronized(networkLogs) {
        if (networkLogs && networkLogs.count > 0) {
            logsText = [networkLogs componentsJoinedByString:@"\n\n--------------------\n\n"];
        } else {
            logsText = @"لا توجد طلبات مسجلة بعد.";
        }
    }
    
    NSString *fullReport = [NSString stringWithFormat:@"%@\n\n%@\n\n%@\n\n📋 سجل الطلبات والآيبات:\n%@", locationInfo, ipInfo, identsInfo, logsText];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 80, self.view.bounds.size.width - 40, 0)];
    label.text = fullReport;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:13];
    label.numberOfLines = 0;
    [label sizeToFit];
    
    scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, label.frame.size.height + 140);
    [scrollView addSubview:label];
    
    // زر إغلاق اللوحة
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(20, 25, 80, 35);
    closeBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:1.0];
    [closeBtn setTitle:@"إغلاق" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.layer.cornerRadius = 8;
    [closeBtn addTarget:self action:@selector(dismissPopup) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeBtn];
    
    // زر إضافي لتغيير الـ IP فوراً دون الحاجة لإغلاق التطبيق (اختياري لك)
    UIButton *changeIpBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    changeIpBtn.frame = CGRectMake(110, 25, 140, 35);
    changeIpBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.47 blue:1.0 alpha:1.0];
    [changeIpBtn setTitle:@"تغيير IP الجلسة" forState:UIControlStateNormal];
    [changeIpBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    changeIpBtn.layer.cornerRadius = 8;
    [changeIpBtn addTarget:self action:@selector(forceNewIP) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:changeIpBtn];
}

- (void)forceNewIP {
    sessionAtlantaIP = nil; // مسح الجلسة الحالية
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AtlantaActiveSessionIP"];
    NSString *newIP = getSessionAtlantaIP(); // توليد جديد
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"تم التغيير" message:[NSString stringWithFormat:@"تم توليد IP جديد لأتلانطا:\n%@", newIP] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithActionTitle:@"حسناً" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)dismissPopup {
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end

@interface AtlantaWindow : UIWindow
@end

@implementation AtlantaWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent)event {
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

// --- تشغيل الـ Hook ---
@interface CustomNetworkHook : NSObject
@end

@implementation CustomNetworkHook

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        updateAtlantaLocation();
        fetchRealIP();
        
        // مسح الجلسة السابقة عند كل فتحة جديدة للتطبيق لضمان توليد IP جديد تماماً
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:@"AtlantaActiveSessionIP"];
        sessionAtlantaIP = nil;
        
        // جلب وتثبيت IP جديد لهذه الجلسة
        getSessionAtlantaIP();
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[AtlantaInfoManager sharedInstance] setupFloatingButton];
        });
        
        Class urlSessionClass = objc_getClass("NSURLSession");
        SEL originalSel = @selector(dataTaskWithRequest:completionHandler:);
        Method originalMethod = class_getInstanceMethod(urlSessionClass, originalSel);
        
        if (originalMethod) {
            IMP originalIMP = method_getImplementation(originalMethod);
            
            NSURLSessionDataTask* (^swizzledBlock)(id, NSURLRequest *, void (^)(NSData *, NSURLResponse *, NSError *)) = ^NSURLSessionDataTask*(id slf, NSURLRequest *request, void (^completionHandler)(NSData *, NSURLResponse *, NSError *)) {
                NSMutableURLRequest *mutableReq = [request mutableCopy];
                
                NSString *sessionIP = getSessionAtlantaIP();
                [mutableReq setValue:sessionIP forHTTPHeaderField:@"X-Forwarded-For"];
                [mutableReq setValue:sessionIP forHTTPHeaderField:@"Client-IP"];
                [mutableReq setValue:sessionIP forHTTPHeaderField:@"X-Real-IP"];
                
                NSString *urlString = request.URL.absoluteString;
                if (urlString) {
                    logNetworkRequest(urlString, sessionIP, currentLat, currentLon);
                }
                
                typedef NSURLSessionDataTask* (*OriginalFunc)(id, SEL, NSURLRequest *, void *);
                return ((OriginalFunc)originalIMP)(slf, originalSel, mutableReq, completionHandler);
            };
            
            method_setImplementation(originalMethod, imp_implementationWithBlock(swizzledBlock));
        }
    });
}

@end
