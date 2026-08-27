#import <UIKit/UIKit.h>
#import <AdSupport/AdSupport.h>
#import <objc/runtime.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#import <net/if.h>

static UIWindow *overlayWindow = nil;
static UIViewController *panelViewController = nil;
static UITextView *logTextView = nil;
static NSMutableArray *networkLogs = nil;
static UILabel *ipInfoLabel = nil;

// جلب الـ IP المحلي بطريقة آمنة وسريعة جداً بدون تعليق
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

// تسجيل أحداث الشبكة بشكل آمن ومنع امتلاء الذاكرة
void addNetworkLog(NSString *log) {
    @synchronized(networkLogs) {
        if (!networkLogs) networkLogs = [NSMutableArray array];
        [networkLogs addObject:log];
        if (networkLogs.count > 50) { // تقليل العدد لضمان خفة الأداء
            [networkLogs removeObjectAtIndex:0];
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (logTextView) {
            logTextView.text = [networkLogs componentsJoinedByString:@"\n--------------------\n"];
            [logTextView scrollRangeToVisible:NSMakeRange(logTextView.text.length, 0)];
        }
    });
}

// اعتراض طلبات الشبكة بدون إحداث تعليق
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    @try {
        NSString *urlStr = request.URL.absoluteString;
        NSString *method = request.HTTPMethod;
        NSString *host = request.URL.host;
        
        NSString *log = [NSString stringWithFormat:@"[%@] Host: %@\nURL: %@", method, host ? host : @"Unknown", urlStr ? urlStr : @""];
        addNetworkLog(log);
    } @catch (NSException *exception) {}
    
    return %orig;
}

%end

// واجهة اللوحة العائمة
@interface PanelViewController : UIViewController
@end

@implementation PanelViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.95];
    
    // عنوان اللوحة
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 40, self.view.frame.size.width - 40, 30)];
    titleLabel.text = @"معلومات الجهاز والشبكة";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:titleLabel];
    
    // جلب IDFA و IDFV
    NSString *idfa = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    NSString *idfv = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    
    // عرض الـ IP المحلي فوراً بدون انتظار شبكة خارجية
    ipInfoLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 75, self.view.frame.size.width - 40, 35)];
    ipInfoLabel.textColor = [UIColor cyanColor];
    ipInfoLabel.font = [UIFont systemFontOfSize:12];
    ipInfoLabel.text = [NSString stringWithFormat:@"Local IP: %@", getLocalIPAddress()];
    [self.view addSubview:ipInfoLabel];
    
    // عرض المعرفات
    UILabel *idsLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 115, self.view.frame.size.width - 40, 45)];
    idsLabel.numberOfLines = 2;
    idsLabel.textColor = [UIColor greenColor];
    idsLabel.font = [UIFont systemFontOfSize:10];
    idsLabel.text = [NSString stringWithFormat:@"IDFA: %@\nIDFV: %@", idfa, idfv];
    [self.view addSubview:idsLabel];
    
    // صندوق السجلات
    logTextView = [[UITextView alloc] initWithFrame:CGRectMake(20, 170, self.view.frame.size.width - 40, self.view.frame.size.height - 240)];
    logTextView.backgroundColor = [UIColor darkGrayColor];
    logTextView.textColor = [UIColor whiteColor];
    logTextView.editable = NO;
    logTextView.font = [UIFont fontWithName:@"Courier" size:10];
    if (networkLogs) {
        logTextView.text = [networkLogs componentsJoinedByString:@"\n--------------------\n"];
    }
    [self.view addSubview:logTextView];
    
    // زر الإغلاق
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake((self.view.frame.size.width - 120) / 2, self.view.frame.size.height - 60, 120, 35);
    [closeBtn setTitle:@"إغلاق الصفحة" forState:UIControlStateNormal];
    [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    closeBtn.backgroundColor = [UIColor redColor];
    closeBtn.layer.cornerRadius = 8;
    [closeBtn addTarget:self action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeBtn];
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

// مدير الزر المخفي للفتح الآمن
@interface SafeTriggerManager : NSObject
@end

@implementation SafeTriggerManager

+ (void)openPanel {
    @try {
        if (!overlayWindow) {
            overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            overlayWindow.windowLevel = UIWindowLevelAlert + 9999;
            panelViewController = [[PanelViewController alloc] init];
            overlayWindow.rootViewController = panelViewController;
            [overlayWindow makeKeyAndVisible];
        }
    } @catch (NSException *e) {}
}

+ (void)setupTrigger {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) return;
        
        // زر شفاف في أعلى يسار الشاشة لفتح الصفحة فوراً وبدون كراش
        UIButton *hiddenBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        hiddenBtn.frame = CGRectMake(0, 40, 60, 60);
        hiddenBtn.backgroundColor = [UIColor clearColor];
        [hiddenBtn addTarget:self action:@selector(openPanel) forControlEvents:UIControlEventTouchUpInside];
        
        [window addSubview:hiddenBtn];
        [window bringSubviewToFront:hiddenBtn];
    });
}

@end

%ctor {
    [SafeTriggerManager setupTrigger];
}
