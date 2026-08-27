#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <objc/runtime.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>

// نافذة مخصصة للزر تمرر اللمسات للتطبيق خلفها ولا تجمد التطبيق
@interface PassThroughWindow : UIWindow
@end
@implementation PassThroughWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self || hitView == self.rootViewController.view) {
        return nil; // السماح للمسات بالمرور للتطبيق إذا لم يتم الضغط على الزر مباشرة
    }
    return hitView;
}
@end

static UIButton *floatingBtn = nil;
static PassThroughWindow *floatingWindow = nil;
static UIWindow *overlayWindow = nil;
static UIViewController *panelViewController = nil;
static UITextView *logTextView = nil;
static NSMutableArray *networkLogs = nil;
static NSString *currentSessionIP = @"جاري جلب الـ IP...";
static UILabel *ipInfoLabel = nil;

// جلب IP المحلي
NSString *getLocalIPAddress() {
    NSString *address = @"غير متوفر";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = getifaddrs(&interfaces);
    if (success == 0) {
        temp_addr = interfaces;
        while (temp_addr != NULL) {
            if (temp_addr->ifa_addr->sa_family == AF_INET) {
                if ([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"] ||
                    [[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"pdp_ip0"]) {
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    freeifaddrs(interfaces);
    return address;
}

// جلب Public IP
void fetchPublicIP() {
    NSURL *url = [NSURL URLWithString:@"https://api.ipify.org?format=text"];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:[NSURLRequest requestWithURL:url] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data && !error) {
            NSString *ipStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (ipStr.length > 0) {
                currentSessionIP = [NSString stringWithFormat:@"Local: %@ | Public: %@", getLocalIPAddress(), ipStr];
            } else {
                currentSessionIP = [NSString stringWithFormat:@"Local: %@", getLocalIPAddress()];
            }
        } else {
            currentSessionIP = [NSString stringWithFormat:@"Local: %@", getLocalIPAddress()];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (ipInfoLabel) {
                ipInfoLabel.text = [NSString stringWithFormat:@"الجلسة IP: %@", currentSessionIP];
            }
        });
    }];
    [task resume];
}

// تسجيل أحداث الشبكة
void addNetworkLog(NSString *log) {
    @synchronized(networkLogs) {
        if (!networkLogs) networkLogs = [NSMutableArray array];
        [networkLogs addObject:log];
        if (networkLogs.count > 100) {
            [networkLogs removeObjectAtIndex:0];
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (logTextView) {
            logTextView.text = [networkLogs componentsJoinedByString:@"\n\n--------------------\n\n"];
            [logTextView scrollRangeToVisible:NSMakeRange(logTextView.text.length, 0)];
        }
    });
}

// اعتراض الطلبات بأمان
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    @try {
        NSString *urlStr = request.URL.absoluteString;
        NSString *method = request.HTTPMethod;
        NSString *host = request.URL.host;
        
        NSString *log = [NSString stringWithFormat:@"[NET] %@\nHost/IP: %@\nURL: %@", method, host ? host : @"Unknown", urlStr ? urlStr : @""];
        addNetworkLog(log);
    } @catch (NSException *exception) {}
    
    return %orig;
}

%end

// واجهة اللوحة العائمة
@interface FloatingPanelVC : UIViewController
@end

@implementation FloatingPanelVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.9];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 40, self.view.frame.size.width - 40, 30)];
    titleLabel.text = @"معلومات الجهاز والشبكة والـ IP";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:titleLabel];
    
    NSString *idfa = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    NSString *idfv = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    
    ipInfoLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 75, self.view.frame.size.width - 40, 50)];
    ipInfoLabel.numberOfLines = 2;
    ipInfoLabel.textColor = [UIColor cyanColor];
    ipInfoLabel.font = [UIFont systemFontOfSize:11];
    ipInfoLabel.text = [NSString stringWithFormat:@"الجلسة IP: %@", currentSessionIP];
    [self.view addSubview:ipInfoLabel];
    
    UILabel *idsLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 130, self.view.frame.size.width - 40, 45)];
    idsLabel.numberOfLines = 2;
    idsLabel.textColor = [UIColor greenColor];
    idsLabel.font = [UIFont systemFontOfSize:10];
    idsLabel.text = [NSString stringWithFormat:@"IDFA: %@\nIDFV: %@", idfa, idfv];
    [self.view addSubview:idsLabel];
    
    logTextView = [[UITextView alloc] initWithFrame:CGRectMake(20, 185, self.view.frame.size.width - 40, self.view.frame.size.height - 260)];
    logTextView.backgroundColor = [UIColor darkGrayColor];
    logTextView.textColor = [UIColor whiteColor];
    logTextView.editable = NO;
    logTextView.font = [UIFont fontWithName:@"Courier" size:10];
    if (networkLogs) {
        logTextView.text = [networkLogs componentsJoinedByString:@"\n\n--------------------\n\n"];
    }
    [self.view addSubview:logTextView];
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake((self.view.frame.size.width - 100) / 2, self.view.frame.size.height - 65, 100, 35);
    [closeBtn setTitle:@"إغلاق" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.backgroundColor = [UIColor redColor];
    closeBtn.layer.cornerRadius = 8;
    [closeBtn addTarget:self action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeBtn];
    
    fetchPublicIP();
}

- (void)closePanel {
    @try {
        [overlayWindow setHidden:YES];
        overlayWindow.rootViewController = nil;
        overlayWindow = nil;
        panelViewController = nil;
        logTextView = nil;
        ipInfoLabel = nil;
    } @catch (NSException *e) {}
}

@end

// مدير الزر العائم
@interface FloatingButtonManager : NSObject
@end

@implementation FloatingButtonManager

+ (void)openPanelWindow {
    @try {
        if (!overlayWindow) {
            overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            overlayWindow.windowLevel = UIWindowLevelAlert + 1000;
            panelViewController = [[FloatingPanelVC alloc] init];
            overlayWindow.rootViewController = panelViewController;
            [overlayWindow makeKeyAndVisible];
        }
    } @catch (NSException *e) {}
}

+ (void)btnTapped:(UIButton *)sender {
    [self openPanelWindow];
}

+ (void)handlePan:(UIPanGestureRecognizer *)recognizer {
    @try {
        UIWindow *window = recognizer.view.window;
        CGPoint translation = [recognizer translationInView:window];
        CGPoint center = recognizer.view.center;
        
        recognizer.view.center = CGPointMake(center.x + translation.x, center.y + translation.y);
        [recognizer setTranslation:CGPointZero inView:window];
    } @catch (NSException *e) {}
}

+ (void)createFloatingButton {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (floatingWindow) return;
        
        // استخدام PassThroughWindow لمنع حجب اللمسات عن التطبيق
        floatingWindow = [[PassThroughWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        floatingWindow.windowLevel = UIWindowLevelStatusBar + 100;
        floatingWindow.backgroundColor = [UIColor clearColor];
        
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        floatingWindow.rootViewController = vc;
        
        floatingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        floatingBtn.frame = CGRectMake(30, 150, 55, 55);
        [floatingBtn setTitle:@"أدوات" forState:UIControlStateNormal];
        [floatingBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        floatingBtn.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.85];
        floatingBtn.layer.cornerRadius = 27.5;
        floatingBtn.layer.shadowColor = [UIColor blackColor].CGColor;
        floatingBtn.layer.shadowRadius = 4.0;
        floatingBtn.layer.shadowOpacity = 0.5;
        
        [floatingBtn addTarget:[FloatingButtonManager class] action:@selector(btnTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        UIPanGestureRecognizer *panGes = [[UIPanGestureRecognizer, UIPanGestureRecognizer] alloc] initWithTarget:[FloatingButtonManager class] action:@selector(handlePan:)];
        [floatingBtn addGestureRecognizer:panGes];
        
        [vc.view addSubview:floatingBtn];
        [floatingWindow setHidden:NO];
    });
}

@end

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [FloatingButtonManager createFloatingButton];
    });
}
