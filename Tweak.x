#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>
#import <Security/Security.h>

// ============================================================
// MARK: - المتغيرات العامة
// ============================================================

static double currentLat = 0.0;
static double currentLon = 0.0;
static NSString *sessionFakeIP = nil;
static NSString *fakeAdvertisingIDString = nil;
static NSString *fakeIDFVString = nil;

// ============================================================
// MARK: - دوال التوليد
// ============================================================

NSString *generateRandomUUIDString() {
    return [[NSUUID UUID] UUIDString];
}

double randomInRange(double min, double max) {
    return min + (arc4random_uniform(UINT32_MAX) / (double)UINT32_MAX) * (max - min);
}

// Atlanta, Georgia, USA
void updateAtlantaLocation() {
    currentLat = randomInRange(33.7480, 33.7900);
    currentLon = randomInRange(-84.4300, -84.3880);
}

// 172.56.x.x / 172.57.x.x / 172.59.x.x
NSString *generateRandomIP() {
    NSArray *subnets = @[@"172.56", @"172.57", @"172.59"];
    NSString *subnet = subnets[arc4random_uniform((uint32_t)subnets.count)];
    int third  = arc4random_uniform(256);
    int fourth = arc4random_uniform(256);
    return [NSString stringWithFormat:@"%@.%d.%d", subnet, third, fourth];
}

// ============================================================
// MARK: - التنظيف الآمن
// ============================================================

void clearKeychainKeepingTokenKey() {
    // 1) احفظ عنصر tokenKey الخاص بـ app.getsmscode
    NSData *savedValueData = nil;
    NSString *savedService  = nil;
    NSString *savedAccount  = nil;

    NSDictionary *query = @{
        (__bridge id)kSecClass:        (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService:  @"app.getsmscode",
        (__bridge id)kSecAttrAccount:  @"tokenKey",
        (__bridge id)kSecReturnAttributes: @YES,
        (__bridge id)kSecReturnData:   @YES,
        (__bridge id)kSecMatchLimit:   (__bridge id)kSecMatchLimitOne
    };

    CFDictionaryRef result = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result) == errSecSuccess && result != NULL) {
        NSDictionary *item = (__bridge NSDictionary *)result;
        savedValueData = item[(__bridge id)kSecValueData];
        savedService   = item[(__bridge id)kSecAttrService];
        savedAccount   = item[(__bridge id)kSecAttrAccount];
    }

    // 2) احذف كل شيء
    NSArray *secClasses = @[
        (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecClassInternetPassword,
        (__bridge id)kSecClassCertificate,
        (__bridge id)kSecClassKey,
        (__bridge id)kSecClassIdentity
    ];

    for (id secClass in secClasses) {
        NSDictionary *deleteQuery = @{ (__bridge id)kSecClass: secClass };
        SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
    }

    // 3) أعد إضافة tokenKey فقط
    if (savedValueData && savedService && savedAccount) {
        NSDictionary *addQuery = @{
            (__bridge id)kSecClass:       (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecAttrService: savedService,
            (__bridge id)kSecAttrAccount: savedAccount,
            (__bridge id)kSecValueData:   savedValueData
        };
        SecItemAdd((__bridge CFDictionaryRef)addQuery, NULL);
    }

    if (result != NULL) CFRelease(result);
}

void clearAppDirectories() {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray *paths = [NSMutableArray array];

    NSArray *caches = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    if (caches.count > 0) [paths addObject:caches[0]];

    NSString *tmp = NSTemporaryDirectory();
    if (tmp) [paths addObject:tmp];

    NSArray *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (docs.count > 0) [paths addObject:docs[0]];

    for (NSString *dir in paths) {
        NSArray *contents = [fm contentsOfDirectoryAtPath:dir error:nil];
        for (NSString *name in contents) {
            if ([name hasPrefix:@"."]) continue; // تجاهل ملفات النظام
            NSString *full = [dir stringByAppendingPathComponent:name];
            [fm removeItemAtPath:full error:nil];
        }
    }
}

// ============================================================
// MARK: - إعادة التهيئة الكاملة
// ============================================================

void performFullReset() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{

        // 1. Keychain (مع الحفاظ على tokenKey)
        clearKeychainKeepingTokenKey();

        // 2. الملفات (Caches / tmp / Documents)
        clearAppDirectories();

        // 3. NSUserDefaults
        NSString *domainName = [[NSBundle mainBundle] bundleIdentifier];
        if (domainName) {
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:domainName];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }

        // 4. URLCache
        [[NSURLCache sharedURLCache] removeAllCachedResponses];

        // 5. توليد بصمة جديدة
        sessionFakeIP           = generateRandomIP();
        fakeAdvertisingIDString = generateRandomUUIDString();
        fakeIDFVString          = generateRandomUUIDString();
        updateAtlantaLocation();

        // 6. إعادة تشغيل التطبيق ليعمل بالقيم الجديدة من %ctor
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            exit(0);
        });
    });
}

// ============================================================
// MARK: - نافذة الزر العائم (نفس نمط الكود الشغّال)
// ============================================================

@interface AtlantaWindow : UIWindow
@end

@implementation AtlantaWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *btn = [self viewWithTag:999888];
    return (btn && CGRectContainsPoint(btn.frame, point));
}
@end

@interface AtlantaManager : NSObject
@property (strong, nonatomic) AtlantaWindow *floatingWindow;
@property (strong, nonatomic) UIButton *resetBtn;
+ (instancetype)sharedInstance;
- (void)setupFloatingButton;
@end

@implementation AtlantaManager

+ (instancetype)sharedInstance {
    static AtlantaManager *sharedInstance = nil;
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

        self.resetBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.resetBtn.tag = 999888;
        self.resetBtn.frame = CGRectMake(20, 120, 55, 55);
        self.resetBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.47 blue:1.0 alpha:0.9];
        [self.resetBtn setTitle:@"🔄" forState:UIControlStateNormal];
        [self.resetBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.resetBtn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
        self.resetBtn.layer.cornerRadius = 27.5;

        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self.resetBtn addGestureRecognizer:pan];
        [self.resetBtn addTarget:self action:@selector(handleReset) forControlEvents:UIControlEventTouchUpInside];

        [vc.view addSubview:self.resetBtn];
    });
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIView *btn = gesture.view;
    CGPoint translation = [gesture translationInView:btn.superview];
    CGFloat newX = MAX(30, MIN([UIScreen mainScreen].bounds.size.width  - 30, btn.center.x + translation.x));
    CGFloat newY = MAX(40, MIN([UIScreen mainScreen].bounds.size.height - 40, btn.center.y + translation.y));
    btn.center = CGPointMake(newX, newY);
    [gesture setTranslation:CGPointZero inView:btn.superview];
}

- (void)handleReset { performFullReset(); }

@end

// ============================================================
// MARK: - Constructor
// ============================================================

%ctor {
    updateAtlantaLocation();
    sessionFakeIP           = generateRandomIP();
    fakeAdvertisingIDString = generateRandomUUIDString();
    fakeIDFVString          = generateRandomUUIDString();

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [[AtlantaManager sharedInstance] setupFloatingButton];
    });
}

// ============================================================
// MARK: - Hooks
// ============================================================

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return fakeAdvertisingIDString
        ? [[NSUUID alloc] initWithUUIDString:fakeAdvertisingIDString]
        : %orig;
}
- (BOOL)isAdvertisingTrackingEnabled {
    return YES;
}
%end

%hook UIDevice
- (NSUUID *)identifierForVendor {
    return fakeIDFVString
        ? [[NSUUID alloc] initWithUUIDString:fakeIDFVString]
        : %orig;
}
%end

%hook CLLocationManager
- (void)startUpdatingLocation {
    CLLocation *fakeLocation = [[CLLocation alloc]
                                initWithLatitude:currentLat
                                longitude:currentLon];
    if ([self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        [self.delegate locationManager:self didUpdateLocations:@[fakeLocation]];
    }
}
- (CLLocation *)location {
    return [[CLLocation alloc] initWithLatitude:currentLat longitude:currentLon];
}
%end

%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    if (sessionFakeIP) {
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Forwarded-For"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"Client-IP"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Real-IP"];
    }
    return %orig(mutableReq, completionHandler);
}
%end
