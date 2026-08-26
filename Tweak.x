#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>

static double currentLat = 0.0;
static double currentLon = 0.0;
static NSString *sessionFakeIP = @"";
static NSString *currentRandomUDID = nil;
static NSUUID *currentRandomIDFA = nil;
static NSString *currentRandomUserAgent = @"";

double randomInRange(double min, double max) {
    return min + (arc4random_uniform(UINT32_MAX) / (double)UINT32_MAX) * (max - min);
}

// تنويع عشوائي للإحداثيات الجغرافية الأمريكية
void updateRandomUSLocation() {
    int cityChoice = arc4random_uniform(6);
    switch (cityChoice) {
        case 0: // نيويورك
            currentLat = randomInRange(40.7128, 40.7828);
            currentLon = randomInRange(-74.0060, -73.9350);
            break;
        case 1: // لوس أنجلوس
            currentLat = randomInRange(34.0522, 34.1522);
            currentLon = randomInRange(-118.2437, -118.3537);
            break;
        case 2: // شيكاغو
            currentLat = randomInRange(41.8781, 41.9581);
            currentLon = randomInRange(-87.6298, -87.7298);
            break;
        case 3: // هيوستن
            currentLat = randomInRange(29.7604, 29.8604);
            currentLon = randomInRange(-95.3698, -95.4698);
            break;
        case 4: // دالاس
            currentLat = randomInRange(32.7767, 32.8767);
            currentLon = randomInRange(-96.7970, -96.8970);
            break;
        default: // ميامي
            currentLat = randomInRange(25.7617, 25.8617);
            currentLon = randomInRange(-80.1918, -80.2918);
            break;
    }
}

// توليد IP فريد وقوي مع توزيع البادئات
void initializeUniqueIP() {
    NSArray *verifiedSuccessfulPrefixes = @[@"98.207", @"75.142", @"67.180", @"24.16", @"71.198", @"104.28", @"172.56", @"50.201", @"173.239"];
    NSString *selectedPrefix = verifiedSuccessfulPrefixes[arc4random_uniform((uint32_t)verifiedSuccessfulPrefixes.count)];
    
    NSTimeInterval timeSeed = [[NSDate date] timeIntervalSince1970] * 1000;
    unsigned long long uniqueSeed = (unsigned long long)timeSeed + arc4random_uniform(9999999);
    
    int third = (int)(uniqueSeed % 245) + 5;
    int fourth = (int)((uniqueSeed / 245) % 245) + 5;
    
    sessionFakeIP = [NSString stringWithFormat:@"%@.%d.%d", selectedPrefix, third, fourth];
}

// User-Agents حديثة ومتنوعة لنظام iOS
void initializeRandomUserAgent() {
    NSArray *agents = @[
        @"Mozilla/5.0 (iPhone; CPU iPhone OS 18_1_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Mobile/15E148",
        @"Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
        @"Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148",
        @"Mozilla/5.0 (iPhone; CPU iPhone OS 17_6_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148",
        @"Mozilla/5.0 (iPhone; CPU iPhone OS 17_5_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
    ];
    currentRandomUserAgent = agents[arc4random_uniform((uint32_t)agents.count)];
}

// تهيئة الهوية والشبكة والموقع
void initializeDeviceIdentity() {
    currentRandomUDID = [[NSUUID UUID] UUIDString];
    currentRandomIDFA = [NSUUID UUID];
    initializeRandomUserAgent();
    initializeUniqueIP();
    updateRandomUSLocation();
}

// التنفيذ الفوري والمسح الشامل مع الخروج
void executeInstantMasterReset() {
    NSString *homeDirectory = NSHomeDirectory();
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSArray *foldersToClean = @[
        [homeDirectory stringByAppendingPathComponent:@"Library/Caches"],
        [homeDirectory stringByAppendingPathComponent:@"Documents"],
        [homeDirectory stringByAppendingPathComponent:@"Library/Application Support"],
        [homeDirectory stringByAppendingPathComponent:@"Library/Preferences"],
        [homeDirectory stringByAppendingPathComponent:@"tmp"],
        [homeDirectory stringByAppendingPathComponent:@"Library/Cookies"]
    ];
    
    for (NSString *folderPath in foldersToClean) {
        if ([fileManager fileExistsAtPath:folderPath]) {
            NSArray *contents = [fileManager contentsOfDirectoryAtPath:folderPath error:nil];
            for (NSString *file in contents) {
                NSString *fullPath = [folderPath stringByAppendingPathComponent:file];
                [fileManager removeItemAtPath:fullPath error:nil];
            }
        }
    }
    
    exit(0);
}

@interface MasterWindow : UIWindow
@end

@implementation MasterWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *btn = [self viewWithTag:777888];
    if (btn && CGRectContainsPoint(btn.frame, point)) {
        return YES;
    }
    return NO;
}
@end

@interface MasterManager : NSObject
@property (strong, nonatomic) MasterWindow *floatingWindow;
@property (strong, nonatomic) UIButton *resetBtn;
+ (instancetype)sharedInstance;
- (void)setupFloatingButton;
@end

@implementation MasterManager

+ (instancetype)sharedInstance {
    static MasterManager *sharedInstance = nil;
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
        self.floatingWindow = [[MasterWindow alloc] initWithFrame:screenBounds];
        self.floatingWindow.windowLevel = UIWindowLevelAlert + 3000;
        self.floatingWindow.hidden = NO;
        self.floatingWindow.backgroundColor = [UIColor clearColor];
        
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        self.floatingWindow.rootViewController = vc;
        
        self.resetBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.resetBtn.tag = 777888;
        self.resetBtn.frame = CGRectMake(20, 180, 65, 65);
        self.resetBtn.backgroundColor = [UIColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:0.9];
        [self.resetBtn setTitle:@"RESET" forState:UIControlStateNormal];
        [self.resetBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.resetBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
        self.resetBtn.layer.cornerRadius = 32.5;
        self.resetBtn.layer.shadowColor = [UIColor blackColor].CGColor;
        self.resetBtn.layer.shadowOffset = CGSizeMake(0, 3);
        self.resetBtn.layer.shadowOpacity = 0.6;
        self.resetBtn.layer.shadowRadius = 5;
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self.resetBtn addGestureRecognizer:pan];
        
        [self.resetBtn addTarget:self action:@selector(executeInstantMasterReset) forControlEvents:UIControlEventTouchUpInside];
        
        [vc.view addSubview:self.resetBtn];
    });
}

- (void)handlePan:(UIPanGestureRecognizer * _Nonnull)gesture {
    UIView *btn = gesture.view;
    CGPoint translation = [gesture translationInView:btn.superview];
    
    CGFloat newX = btn.center.x + translation.x;
    CGFloat newY = btn.center.y + translation.y;
    
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    newX = MAX(35, MIN(screenSize.width - 35, newX));
    newY = MAX(45, MIN(screenSize.height - 45, newY));
    
    btn.center = CGPointMake(newX, newY);
    [gesture setTranslation:CGPointZero inView:btn.superview];
}

@end

%ctor {
    initializeDeviceIdentity();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[MasterManager sharedInstance] setupFloatingButton];
    });
}

// خطاف الموقع الجغرافي الوهمي
%hook CLLocationManager
- (void)startUpdatingLocation {
    CLLocation *fakeLocation = [[CLLocation alloc] initWithLatitude:currentLat longitude:currentLon];
    if ([self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        [self.delegate locationManager:self didUpdateLocations:@[fakeLocation]];
    }
}
- (CLLocation *)location {
    return [[CLLocation alloc] initWithLatitude:currentLat longitude:currentLon];
}
%end

// خطاف تهيئة الاتصالات لإجبار التطبيق على توجيه الطلبات عبر الـ IP والبروكسي الوهمي
%hook NSURLSessionConfiguration
- (void)setConnectionProxyDictionary:(NSDictionary *)connectionProxyDictionary {
    NSDictionary *proxySettings = @{
        (__bridge NSString *)kCFNetworkProxiesHTTPEnable : @YES,
        (__bridge NSString *)kCFNetworkProxiesHTTPProxy : sessionFakeIP,
        (__bridge NSString *)kCFNetworkProxiesHTTPPort : @80,
        (__bridge NSString *)kCFNetworkProxiesHTTPSEnable : @YES,
        (__bridge NSString *)kCFNetworkProxiesHTTPSProxy : sessionFakeIP,
        (__bridge NSString *)kCFNetworkProxiesHTTPSPort : @443
    };
    %orig(proxySettings);
}
- (NSDictionary *)connectionProxyDictionary {
    return @{
        (__bridge NSString *)kCFNetworkProxiesHTTPEnable : @YES,
        (__bridge NSString *)kCFNetworkProxiesHTTPProxy : sessionFakeIP,
        (__bridge NSString *)kCFNetworkProxiesHTTPPort : @80,
        (__bridge NSString *)kCFNetworkProxiesHTTPSEnable : @YES,
        (__bridge NSString *)kCFNetworkProxiesHTTPSProxy : sessionFakeIP,
        (__bridge NSString *)kCFNetworkProxiesHTTPSPort : @443
    };
}
%end

// خطاف طلبات الشبكة لحقن ترويسات الـ IP الوهمي والمتصفح الحديث
%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    
    [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Forwarded-For"];
    [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"Client-IP"];
    [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Real-IP"];
    
    [mutableReq setValue:@"en-US,en;q=0.9" forHTTPHeaderField:@"Accept-Language"];
    [mutableReq setValue:currentRandomUserAgent forHTTPHeaderField:@"User-Agent"];
    
    return %orig(mutableReq, completionHandler);
}
%end

// تغيير الـ UDID
%hook UIDevice
- (NSUUID *)identifierForVendor {
    return [[NSUUID alloc] initWithUUIDString:currentRandomUDID];
}
%end

// تغيير الـ IDFA
%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return currentRandomIDFA;
}
%end
