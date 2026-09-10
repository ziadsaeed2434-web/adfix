#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>
#import <WebKit/WebKit.h>
#import <Security/Security.h>
#import <objc/runtime.h>
#import <sys/stat.h>

// ============================================================
// MARK: - المتغيرات العامة
// ============================================================

static double currentLat = 0.0;
static double currentLon = 0.0;
static NSString *sessionFakeIP = nil;
static NSString *currentRealIP = @"جاري الجلب...";
static NSMutableArray *networkLogs = nil;

static NSString *fakeAdvertisingIDString = nil;
static NSString *fakeUDIDString = nil; 

static NSString *g_spoofedName = nil;
static NSString *g_spoofedSystemVersion = nil;
static NSUUID *g_spoofedVendorID = nil;
static float g_spoofedBatteryLevel = 0.0;
static UIDeviceBatteryState g_spoofedBatteryState = UIDeviceBatteryStateUnknown;
static NSString *g_spoofedUserAgent = nil;
static BOOL g_hasSpoofed = NO;

// ============================================================
// MARK: - دوال التوليد العشوائي المساعدة (آمنة وخالية من الكراش)
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

double randomInRange(double min, double max) {
    return min + (arc4random_uniform(UINT32_MAX) / (double)UINT32_MAX) * (max - min);
}

static float randomFloatBetween(float min, float max) {
    return ((float)arc4random() / (float)UINT32_MAX) * (max - min) + min;
}

static NSString *randomDeviceName(void) {
    NSArray *names = @[@"iPhone", @"iPhone Pro", @"iPhone Max"];
    NSString *base = names[arc4random_uniform((uint32_t)names.count)];
    int model = arc4random_uniform(20) + 1;
    return [NSString stringWithFormat:@"%@ %d", base, model];
}

static NSString *randomSystemVersion(void) {
    int major = 24 + arc4random_uniform(4);
    int minor = arc4random_uniform(10);
    int patch = arc4random_uniform(10);
    return [NSString stringWithFormat:@"%d.%d.%d", major, minor, patch];
}

static NSString *randomUserAgent(NSString *systemVersion) {
    NSArray *components = [systemVersion componentsSeparatedByString:@"."];
    if (components.count < 2) {
        components = @[@"26", @"0"];
    }
    NSString *major = components[0];
    NSString *minor = components.count > 1 ? components[1] : @"0";
    
    int buildNumber = arc4random_uniform(900) + 100;
    NSString *build = [NSString stringWithFormat:@"%d", buildNumber];
    
    int webKitMajor = 600 + arc4random_uniform(10);
    int webKitMinor = arc4random_uniform(20);
    int webKitPatch = arc4random_uniform(10);
    
    int safariMajor = 10 + arc4random_uniform(10);
    int safariMinor = arc4random_uniform(10);
    
    return [NSString stringWithFormat:
            @"Mozilla/5.0 (iPhone; CPU iPhone OS %@_%@ like Mac OS X) AppleWebKit/%d.%d.%d (KHTML, like Gecko) Version/%d.%d Mobile/15E%@ Safari/%d.%d.%d",
            major, minor, webKitMajor, webKitMinor, webKitPatch, safariMajor, safariMinor, build, webKitMajor, webKitMinor, webKitPatch];
}

void updateAtlantaLocation() {
    currentLat = randomInRange(33.7000, 33.8000);
    currentLon = randomInRange(-84.4500, -84.3500);
}

// توليد IP جديد ونظيف بشكل فوري وآمن (بدون طلبات شبكية بطيئة)
void generateSessionIP() {
    int allowedSecondOctets[] = {56, 57, 59};
    int second = allowedSecondOctets[arc4random_uniform(3)];
    int third = arc4random_uniform(256);
    int fourth = arc4random_uniform(256);
    sessionFakeIP = [NSString stringWithFormat:@"172.%d.%d.%d", second, third, fourth];
}

void fetchRealIP() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURL *url = [NSURL URLWithString:@"https://api.ipify.org"];
        NSError *error = nil;
        NSString *ip = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
        if (!error && ip && ip.length > 0) {
            currentRealIP = [ip stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        } else {
            currentRealIP = @"غير قادر على الجلب";
        }
    });
}

void logNetworkRequest(NSString *urlStr, NSString *ip, double lat, double lon) {
    @try {
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
    } @catch (NSException *e) {}
}

// ============================================================
// MARK: - مسح البيانات والكاش وإعدادات الإعلانات
// ============================================================

void applyAdConstraintsDefaults() {
    @try {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setBool:NO  forKey:@"IS_CappingManager.IS_CAPPING_ENABLED_DefaultInterstitial"];
        [defaults setBool:YES forKey:@"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial"];
        [defaults setBool:NO  forKey:@"BN_CappingManager.IS_CAPPING_ENABLED_DefaultBanner"];
        [defaults setBool:NO  forKey:@"BN_CappingManager.IS_PACING_ENABLED_DefaultBanner"];
        [defaults setBool:YES forKey:@"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"];
        [defaults setInteger:0 forKey:@"com.inobi_defaultStore_sessionCount"];
        [defaults synchronize];
    } @catch (NSException *e) {}
}

void clearKeychainKeepingAccount() {
    @try {
        NSString *savedUserID = nil;
        NSString *savedAccessToken = nil;
        NSDictionary *query = @{
            (id)kSecClass: (id)kSecClassGenericPassword,
            (id)kSecMatchLimit: (id)kSecMatchLimitAll,
            (id)kSecReturnAttributes: @YES,
            (id)kSecReturnData: @YES
        };
        CFArrayRef result = NULL;
        OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&result);
        if (status == errSecSuccess && result != NULL) {
            NSArray *items = (__bridge NSArray *)result;
            for (NSDictionary *item in items) {
                NSString *service = item[(id)kSecAttrService];
                NSString *account = item[(id)kSecAttrAccount];
                NSData *valueData = item[(id)kSecValueData];
                NSString *value = valueData ? [[NSString alloc] initWithData:valueData encoding:NSUTF8StringEncoding] : @"";
                if ([service isEqualToString:@"com.codebysms"] && [account isEqualToString:@"userIDKey"]) {
                    savedUserID = value;
                } else if ([service isEqualToString:@"com.codebysms"] && [account isEqualToString:@"accessTokenKey"]) {
                    savedAccessToken = value;
                }
            }
            CFRelease(result);
        }

        NSArray *secClasses = @[(id)kSecClassGenericPassword, (id)kSecClassInternetPassword, (id)kSecClassCertificate, (id)kSecClassKey, (id)kSecClassIdentity];
        for (id secClass in secClasses) {
            NSDictionary *deleteQuery = @{(id)kSecClass: secClass, (id)kSecMatchLimit: (id)kSecMatchLimitAll};
            SecItemDelete((CFDictionaryRef)deleteQuery);
        }

        if (savedUserID) {
            NSDictionary *addQuery = @{
                (id)kSecClass: (id)kSecClassGenericPassword,
                (id)kSecAttrService: @"com.codebysms",
                (id)kSecAttrAccount: @"userIDKey",
                (id)kSecValueData: [savedUserID dataUsingEncoding:NSUTF8StringEncoding]
            };
            SecItemAdd((CFDictionaryRef)addQuery, NULL);
        }
        if (savedAccessToken) {
            NSDictionary *addQuery = @{
                (id)kSecClass: (id)kSecClassGenericPassword,
                (id)kSecAttrService: @"com.codebysms",
                (id)kSecAttrAccount: @"accessTokenKey",
                (id)kSecValueData: [savedAccessToken dataUsingEncoding:NSUTF8StringEncoding]
            };
            SecItemAdd((CFDictionaryRef)addQuery, NULL);
        }
    } @catch (NSException *e) {}
}

void clearAllCookies() {
    @try {
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
            [cookieStorage deleteCookie:cookie];
        }
        
        NSSet *dataTypes = [NSSet setWithObject:WKWebsiteDataTypeCookies];
        [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:dataTypes modifiedSince:[NSDate distantPast] completionHandler:^{}];
    } @catch (NSException *e) {}
}

void clearNetworkCache() {
    @try {
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
    } @catch (NSException *e) {}
}

void clearAllLocalFiles() {
    @try {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSArray *dirs = @[
            NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject,
            NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject,
            NSTemporaryDirectory()
        ];
        
        for (NSString *dir in dirs) {
            if (dir) {
                NSArray *items = [fm contentsOfDirectoryAtPath:dir error:nil];
                for (NSString *item in items) {
                    [fm removeItemAtPath:[dir stringByAppendingPathComponent:item] error:nil];
                }
            }
        }
    } @catch (NSException *e) {}
}

// ============================================================
// MARK: - دالة العمليات الشاملة (الزر الأزرق)
// ============================================================

void performFullReset() {
    @try {
        applyAdConstraintsDefaults();

        g_spoofedName = randomDeviceName();
        g_spoofedSystemVersion = randomSystemVersion();
        g_spoofedVendorID = [NSUUID UUID];
        g_spoofedBatteryLevel = randomFloatBetween(0.15, 0.95);
        g_spoofedBatteryState = (arc4random_uniform(2) == 0) ? UIDeviceBatteryStateCharging : UIDeviceBatteryStateUnplugged;
        g_spoofedUserAgent = randomUserAgent(g_spoofedSystemVersion);
        g_hasSpoofed = YES;

        clearKeychainKeepingAccount();
        clearAllCookies();
        clearNetworkCache();
        clearAllLocalFiles();
        
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleID) {
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleID];
            [[NSUserDefaults standardUserDefaults] synchronize];
            applyAdConstraintsDefaults();
        }

        fakeAdvertisingIDString = generateRandomUUIDString();
        fakeUDIDString = generateRandomUDID();
        
        updateAtlantaLocation();
        generateSessionIP();
        
        @synchronized(networkLogs) {
            [networkLogs removeAllObjects];
        }
    } @catch (NSException *exception) {}
    
    exit(0);
}

// ============================================================
// MARK: - الزر العائم وإدارته
// ============================================================

@interface AtlantaWindow : UIWindow
@end

@implementation AtlantaWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *btn1 = [self viewWithTag:999888];
    if (btn1 && CGRectContainsPoint(btn1.frame, point)) {
        return YES;
    }
    return NO;
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
        
        self.resetBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.resetBtn.tag = 999888;
        self.resetBtn.frame = CGRectMake(20, 120, 55, 55);
        self.resetBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.47 blue:1.0 alpha:0.9];
        [self.resetBtn setTitle:@"🔄" forState:UIControlStateNormal];
        [self.resetBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.resetBtn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
        self.resetBtn.layer.cornerRadius = 27.5;
        self.resetBtn.layer.shadowColor = [UIColor blackColor].CGColor;
        self.resetBtn.layer.shadowOffset = CGSizeMake(0, 2);
        self.resetBtn.layer.shadowOpacity = 0.5;
        self.resetBtn.layer.shadowRadius = 4;
        
        UIPanGestureRecognizer *pan1 = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self.resetBtn addGestureRecognizer:pan1];
        [self.resetBtn addTarget:self action:@selector(handleReset) forControlEvents:UIControlEventTouchUpInside];
        
        [vc.view addSubview:self.resetBtn];
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

- (void)handleReset {
    performFullReset();
}

@end

// ============================================================
// MARK: - الـ Hooks والتنفيذ الأولي
// ============================================================

%ctor {
    @autoreleasepool {
        applyAdConstraintsDefaults();
        
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            updateAtlantaLocation();
            generateSessionIP();
            fakeAdvertisingIDString = generateRandomUUIDString();
            fakeUDIDString = generateRandomUDID();
            fetchRealIP();
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [[AtlantaInfoManager sharedInstance] setupFloatingButton];
            });
        }
    }
}

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    if (fakeAdvertisingIDString) {
        return [[NSUUID alloc] initWithUUIDString:fakeAdvertisingIDString];
    }
    return %orig;
}
%end

%hook UIDevice
- (NSString *)name {
    if (g_hasSpoofed && g_spoofedName) return g_spoofedName;
    return %orig;
}

- (NSString *)systemVersion {
    if (g_hasSpoofed && g_spoofedSystemVersion) return g_spoofedSystemVersion;
    return %orig;
}

- (NSUUID *)identifierForVendor {
    @try {
        if (g_hasSpoofed && g_spoofedVendorID && [g_spoofedVendorID isKindOfClass:[NSUUID class]]) {
            return g_spoofedVendorID;
        }
    } @catch (id e) {}
    return %orig;
}

- (float)batteryLevel {
    if (g_hasSpoofed) return g_spoofedBatteryLevel;
    return %orig;
}

- (UIDeviceBatteryState)batteryState {
    if (g_hasSpoofed) return g_spoofedBatteryState;
    return %orig;
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
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    if (sessionFakeIP) {
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Forwarded-For"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"Client-IP"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Real-IP"];
    }
    if (g_hasSpoofed && g_spoofedUserAgent) {
        [mutableReq setValue:g_spoofedUserAgent forHTTPHeaderField:@"User-Agent"];
    }
    
    NSString *urlString = request.URL.absoluteString;
    if (urlString) {
        logNetworkRequest(urlString, sessionFakeIP ?: @"غير محدد", currentLat, currentLon);
    }
    return %orig(mutableReq);
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    if (sessionFakeIP) {
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Forwarded-For"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"Client-IP"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Real-IP"];
    }
    if (g_hasSpoofed && g_spoofedUserAgent) {
        [mutableReq setValue:g_spoofedUserAgent forHTTPHeaderField:@"User-Agent"];
    }
    
    NSString *urlString = request.URL.absoluteString;
    if (urlString) {
        logNetworkRequest(urlString, sessionFakeIP ?: @"غير محدد", currentLat, currentLon);
    }
    return %orig(mutableReq, completionHandler);
}
%end

%hook NSURLConnection
+ (void)sendAsynchronousRequest:(NSURLRequest *)request queue:(NSOperationQueue *)queue completionHandler:(void (^)(NSURLResponse *response, NSData *data, NSError *error))handler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    if (sessionFakeIP) {
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Forwarded-For"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"Client-IP"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Real-IP"];
    }
    if (g_hasSpoofed && g_spoofedUserAgent) {
        [mutableReq setValue:g_spoofedUserAgent forHTTPHeaderField:@"User-Agent"];
    }
    
    NSString *urlString = request.URL.absoluteString;
    if (urlString) {
        logNetworkRequest(urlString, sessionFakeIP ?: @"غير محدد", currentLat, currentLon);
    }
    %orig(mutableReq, queue, handler);
}
%end
