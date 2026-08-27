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

// واجهة اللوحة العائمة لعرض البيانات
@interface FloatingPanelVC : UIViewController
@end

@implementation FloatingPanelVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.92];
    
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
    closeBtn.frame = CGRectMake((self.view.frame.size.width - 120) / 2, self.view.frame.size.height - 65, 120, 38);
    [closeBtn setTitle:@"إغلاق الصفحة" forState:UIControlStateNormal];
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

// مدير إيماءة النقر المزدوج للشاشة
@interface GestureManager : NSObject
@end

@implementation GestureManager

+ (void)handleDoubleTap:(UITapGestureRecognizer *)gesture {
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

+ (void)setupDoubleTapGesture {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) return;
        
        UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:[GestureManager class] action:@selector(handleDoubleTap:)];
        doubleTap.numberOfTapsRequired = 2; // الضغط مرتين
        doubleTap.cancelsTouchesInView = NO; // لكي لا يعيق لمسات التطبيق العادية
        [window addGestureRecognizer:doubleTap];
    });
}

@end

// تفعيل الإيماءة عند تشغيل التطبيق
%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [GestureManager setupDoubleTapGesture];
    });
}
