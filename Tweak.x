#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>
#import <WebKit/WebKit.h>
#import <Security/Security.h>

// ============================================================
// MARK: - المتغيرات العامة للبصمة المتغيرة
// ============================================================

static double currentLat = 0.0;
static double currentLon = 0.0;
static NSString *sessionFakeIP = nil;
static NSString *currentRealIP = @"جاري الجلب...";
static NSMutableArray *networkLogs = nil;

// المعرفات المزيفة
static NSString *fakeAdvertisingIDString = nil;
static NSString *fakeUDIDString = nil;
static NSString *fakeIDFVString = nil;
static NSString *currentFakeUserAgent = nil;
static NSString *currentFakeModel = nil;
static NSString *currentFakeSystemVersion = nil;

// ============================================================
// MARK: - دوال توليد بصمات وأجهزة وهمية مختلفة
// ============================================================

NSString *generateRandomUUIDString() {
    return [[NSUUID UUID] UUIDString];
}

NSString *generateRandomUDID() {
    NSString *letters = @"0123456789abcdef";
    NSMutableString *randomHex1 = [NSMutableString stringWithCapacity:8];
    NSMutableString *randomHex2 = [NSMutableString stringWithCapacity:12];
    
    for (int i = 0; i < 8; i++) {
        [randomHex1 appendFormat:@"%C", [letters characterAtIndex:arc4random_uniform((uint32_t)[letters length])]];
    }
    for (int i = 0; i < 12; i++) {
        [randomHex2 appendFormat:@"%C", [letters characterAtIndex:arc4random_uniform((uint32_t)[letters length])]];
    }
    
    return [NSString stringWithFormat:@"00008130-%@-%@", randomHex1, randomHex2];
}

void generateRandomDeviceProfile() {
    NSArray *models = @[@"iPhone15,2", @"iPhone14,3", @"iPhone15,4", @"iPhone16,1", @"iPhone14,5", @"iPhone13,2"];
    NSArray *versions = @[@"17.2", @"17.4", @"17.5", @"18.0", @"18.1", @"17.1"];
    NSArray *iosVersions = @[@"17_2", @"17_4", @"17_5", @"18_0", @"18_1"];
    
    currentFakeModel = models[arc4random_uniform((uint32_t)models.count)];
    currentFakeSystemVersion = versions[arc4random_uniform((uint32_t)versions.count)];
    NSString *randomIOSVerForUA = iosVersions[arc4random_uniform((uint32_t)iosVersions.count)];
    
    currentFakeUserAgent = [NSString stringWithFormat:@"Mozilla/5.0 (iPhone; CPU iPhone OS %@ like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", randomIOSVerForUA];
}

double randomInRange(double min, double max) {
    return min + (arc4random_uniform(UINT32_MAX) / (double)UINT32_MAX) * (max - min);
}

// ✅ الموقع الجديد: أتلانتا - أمريكا
void updateAtlantaLocation() {
    // إحداثيات مدينة أتلانتا، جورجيا - الولايات المتحدة
    // Latitude: 33.7490 / Longitude: -84.3880
    currentLat = randomInRange(33.7000, 33.8000);   // خط العرض
    currentLon = randomInRange(-84.4500, -84.3000); // خط الطول (سالب لأنها غرب)
}

// ✅ توليد IP ببادئات 172.56 / 172.58 / 172.59
NSArray *generate10IPs() {
    NSMutableArray *tempList = [NSMutableArray arrayWithCapacity:10];
    // البادئات المطلوبة (أول أوكتين ثابت = 172)
    NSArray *secondOctets = @[@56, @58, @59];
    
    for (int i = 0; i < 10; i++) {
        int first  = 172;
        int second = [secondOctets[arc4random_uniform((uint32_t)secondOctets.count)] intValue];
        // نستخدم 1-254 لتجنب عناوين الشبكة والبث
        int third  = 1 + arc4random_uniform(254);
        int fourth = 1 + arc4random_uniform(254);
        NSString *ip = [NSString stringWithFormat:@"%d.%d.%d.%d", first, second, third, fourth];
        [tempList addObject:ip];
    }
    return [tempList copy];
}

// ✅ اختيار IP مباشرة بدون أي فحص
void generateSessionIP() {
    NSArray *candidates = generate10IPs();
    sessionFakeIP = candidates[arc4random_uniform((uint32_t)candidates.count)];
}

void fetchRealIP() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURL *url = [NSURL URLWithString:@"https://api.ipify.org"];
        NSString *ip = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
        currentRealIP = (ip && ip.length > 0) ? ip : @"غير قادر على الجلب";
    });
}

void logNetworkRequest(NSString *urlStr, NSString *ip, double lat, double lon) {
    if (!networkLogs) networkLogs = [[NSMutableArray alloc] init];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSString *path = url.path ? url.path : urlStr;
    if (path.length > 30) path = [[path substringToIndex:30] stringByAppendingString:@"..."];
    NSString *logEntry = [NSString stringWithFormat:@"🔗 الرابط: %@\n🌐 IP: %@\n📱 الجهاز: %@ (iOS %@)", path, ip, currentFakeModel, currentFakeSystemVersion];
    @synchronized(networkLogs) {
        [networkLogs insertObject:logEntry atIndex:0];
        if (networkLogs.count > 15) [networkLogs removeLastObject];
    }
}

// ============================================================
// MARK: - التنظيف العميق وتوليد بصمة جديدة بالكامل
// ============================================================

void clearKeychainKeepingAccount() {
    NSData *savedValueData = nil;
    NSString *savedService = nil;
    
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount: @"tokenKey",
        (__bridge id)kSecReturnAttributes: @YES,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
    };
    
    CFDictionaryRef result = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result) == errSecSuccess && result != NULL) {
        NSDictionary *item = (__bridge NSDictionary *)result;
        savedValueData = item[(__bridge id)kSecValueData];
        savedService = item[(__bridge id)kSecAttrService];
    }

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

    if (savedValueData && savedService) {
        NSDictionary *addQuery = @{
            (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecAttrService: savedService,
            (__bridge id)kSecAttrAccount: @"tokenKey",
            (__bridge id)kSecValueData: savedValueData
        };
        SecItemAdd((__bridge CFDictionaryRef)addQuery, NULL);
    }
    
    if (result != NULL) {
        CFRelease(result);
    }
}

void performFullReset() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        clearKeychainKeepingAccount();
        
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (NSHTTPCookie *cookie in [cookieStorage cookies]) { [cookieStorage deleteCookie:cookie]; }
        
        NSSet *dataTypes = [WKWebsiteDataStore allWebsiteDataTypes];
        [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:dataTypes modifiedSince:[NSDate distantPast] completionHandler:^{}];
        
        NSString *domainName = [[NSBundle mainBundle] bundleIdentifier];
        if (domainName) {
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:domainName];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        
        // توليد بيانات جهاز جديد كلياً
        fakeAdvertisingIDString = generateRandomUUIDString();
        fakeIDFVString = generateRandomUUIDString();
        fakeUDIDString = generateRandomUDID();
        generateRandomDeviceProfile();
        updateAtlantaLocation();     // ✅ موقع أتلانتا
        generateSessionIP();         // ✅ IP ببادئات 172.56/58/59
        fetchRealIP();
        
        @synchronized(networkLogs) { [networkLogs removeAllObjects]; }
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            exit(0);
        });
    });
}

// ============================================================
// MARK: - الواجهة والزر العائم الوحيد
// ============================================================

@interface AtlantaWindow : UIWindow
@end

@implementation AtlantaWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *btn1 = [self viewWithTag:999888];
    return (btn1 && CGRectContainsPoint(btn1.frame, point));
}
@end

@interface AtlantaInfoManager : NSObject
@property (strong, nonatomic) AtlantaWindow *floatingWindow;
@property (strong, nonatomic) UIButton *resetBtn;
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
    CGFloat newX = MAX(30, MIN([UIScreen mainScreen].bounds.size.width - 30, btn.center.x + translation.x));
    CGFloat newY = MAX(40, MIN([UIScreen mainScreen].bounds.size.height - 40, btn.center.y + translation.y));
    btn.center = CGPointMake(newX, newY);
    [gesture setTranslation:CGPointZero inView:btn.superview];
}

- (void)handleReset { performFullReset(); }

@end

// ============================================================
// MARK: - الـ Hooks لتزوير الهوية ونظام الجهاز والـ Headers بالكامل
// ============================================================

%ctor {
    generateRandomDeviceProfile();
    updateAtlantaLocation();      // ✅ موقع أتلانتا
    generateSessionIP();          // ✅ IP ببادئات 172.56/58/59
    fakeAdvertisingIDString = generateRandomUUIDString();
    fakeIDFVString = generateRandomUUIDString();
    fakeUDIDString = generateRandomUDID();
    fetchRealIP();
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[AtlantaInfoManager sharedInstance] setupFloatingButton];
    });
}

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return fakeAdvertisingIDString ? [[NSUUID alloc] initWithUUIDString:fakeAdvertisingIDString] : %orig;
}
%end

%hook UIDevice
- (NSUUID *)identifierForVendor {
    return fakeIDFVString ? [[NSUUID alloc] initWithUUIDString:fakeIDFVString] : %orig;
}
- (NSString *)model {
    return currentFakeModel ?: %orig;
}
- (NSString *)systemVersion {
    return currentFakeSystemVersion ?: %orig;
}
%end

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
    if (currentFakeUserAgent) {
        [mutableReq setValue:currentFakeUserAgent forHTTPHeaderField:@"User-Agent"];
    }
    if (request.URL.absoluteString) {
        logNetworkRequest(request.URL.absoluteString, sessionFakeIP ?: @"غير محدد", currentLat, currentLon);
    }
    return %orig(mutableReq, completionHandler);
}
%end
