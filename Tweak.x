#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>
#import <WebKit/WebKit.h>
#import <Security/Security.h>
#import <Foundation/Foundation.h>

// ============================================================
// MARK: - المتغيرات العامة
// ============================================================

static double currentLat = 0.0;
static double currentLon = 0.0;
static NSString *sessionFakeIP = @"172.56.0.1";
static NSString *currentRealIP = @"جاري الجلب...";
static NSMutableArray *networkLogs = nil;

static NSString *fakeAdvertisingIDString = nil;
static NSString *fakeUDIDString = nil; 

// ============================================================
// MARK: - دالة توليد معرفات عشوائية آمنة
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

// ============================================================
// MARK: - فرض إعدادات الإعلانات بأمان لكل نسخة
// ============================================================

void forceAdConstraints() {
    @autoreleasepool {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if (!defaults) return;
        
        [defaults setBool:NO  forKey:@"IS_CappingManager.IS_CAPPING_ENABLED_DefaultInterstitial"];
        [defaults setBool:YES forKey:@"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial"];
        
        [defaults setBool:NO  forKey:@"BN_CappingManager.IS_CAPPING_ENABLED_DefaultBanner"];
        [defaults setBool:NO  forKey:@"BN_CappingManager.IS_PACING_ENABLED_DefaultBanner"];
        
        [defaults setBool:YES forKey:@"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"];
        [defaults setInteger:0 forKey:@"com.inobi_defaultStore_sessionCount"];
        
        [defaults synchronize];
    }
}

// ============================================================
// MARK: - دوال الموقع والشبكة (آمنة في الخلفية)
// ============================================================

double randomInRange(double min, double max) {
    return min + (arc4random_uniform(UINT32_MAX) / (double)UINT32_MAX) * (max - min);
}

void updateAtlantaLocation() {
    currentLat = randomInRange(33.7000, 33.8000);
    currentLon = randomInRange(-84.4500, -84.3500);
}

void generateSessionIPAsync() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int allowedSecondOctets[] = {56, 57, 59};
        int second = allowedSecondOctets[arc4random_uniform(3)];
        int third = arc4random_uniform(256);
        int fourth = arc4random_uniform(256);
        NSString *ip = [NSString stringWithFormat:@"172.%d.%d.%d", second, third, fourth];
        sessionFakeIP = ip;
    });
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

// ============================================================
// MARK: - مسح الـ Keychain والملفات المؤقتة بأمان
// ============================================================

void clearKeychainKeepingAccount() {
    @autoreleasepool {
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
    }
}

void clearAllCookies() {
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
        [cookieStorage deleteCookie:cookie];
    }
    NSSet *allWebTypes = [WKWebsiteDataStore allWebsiteDataTypes];
    [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:allWebTypes modifiedSince:[NSDate distantPast] completionHandler:^{}];
}

void clearNetworkCache() {
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

void clearAllLocalFiles() {
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
}

void performFullReset() {
    forceAdConstraints();
    clearKeychainKeepingAccount();
    clearAllCookies();
    clearNetworkCache();
    clearAllLocalFiles();
    
    fakeAdvertisingIDString = generateRandomUUIDString();
    updateAtlantaLocation();
    generateSessionIPAsync();
    fetchRealIP();
    
    @synchronized(networkLogs) {
        [networkLogs removeAllObjects];
    }
}

void changeIdentifiersOnly() {
    fakeUDIDString = generateRandomUDID();
}

// ============================================================
// MARK: - واجهة عرض التقارير
// ============================================================

@interface AtlantaReportViewController : UIViewController
@end

@implementation AtlantaReportViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
    
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scrollView];
    
    NSString *idfaDisplay = fakeAdvertisingIDString ?: [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    NSString *udidDisplay = fakeUDIDString ?: @"غير متوفر";
    
    NSString *fullReport = [NSString stringWithFormat:@"📍 الموقع: (%.4f, %.4f)\n🌐 IP وهمي: %@\n🆔 UDID: %@\n🆔 IDFA: %@", currentLat, currentLon, sessionFakeIP, udidDisplay, idfaDisplay];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, 80, self.view.bounds.size.width - 40, 0)];
    label.text = fullReport;
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:13];
    label.numberOfLines = 0;
    [label sizeToFit];
    
    scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, label.frame.size.height + 160);
    [scrollView addSubview:label];
    
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(20, 30, 80, 35);
    [closeBtn setTitle:@"إغلاق" forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(dismissPopup) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeBtn];
}
- (void)dismissPopup {
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end

// ============================================================
// MARK: - الأزرار العائمة الآمنة
// ============================================================

@interface AtlantaWindow : UIWindow
@end

@implementation AtlantaWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *btn1 = [self viewWithTag:999888];
    UIView *btn2 = [self viewWithTag:999777];
    if ((btn1 && CGRectContainsPoint(btn1.frame, point)) || (btn2 && CGRectContainsPoint(btn2.frame, point))) {
        return YES;
    }
    return NO;
}
@end

@interface AtlantaInfoManager : NSObject
@property (strong, nonatomic) AtlantaWindow *floatingWindow;
+ (instancetype)sharedInstance;
- (void)setupFloatingButtons;
@end

@implementation AtlantaInfoManager
+ (instancetype)sharedInstance {
    static AtlantaInfoManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ sharedInstance = [[self alloc] init]; });
    return sharedInstance;
}
- (void)setupFloatingButtons {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.floatingWindow) return;
        self.floatingWindow = [[AtlantaWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        self.floatingWindow.windowLevel = UIWindowLevelAlert + 1000;
        self.floatingWindow.hidden = NO;
        self.floatingWindow.backgroundColor = [UIColor clearColor];
        
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        self.floatingWindow.rootViewController = vc;
        
        UIButton *resetBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        resetBtn.tag = 999888;
        resetBtn.frame = CGRectMake(20, 120, 50, 50);
        resetBtn.backgroundColor = [UIColor blueColor];
        [resetBtn setTitle:@"🔄" forState:UIControlStateNormal];
        [resetBtn addTarget:self action:@selector(handleReset) forControlEvents:UIControlEventTouchUpInside];
        
        UIButton *changeIDBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        changeIDBtn.tag = 999777;
        changeIDBtn.frame = CGRectMake(20, 180, 50, 50);
        changeIDBtn.backgroundColor = [UIColor orangeColor];
        [changeIDBtn setTitle:@"🆔" forState:UIControlStateNormal];
        [changeIDBtn addTarget:self action:@selector(handleChangeID) forControlEvents:UIControlEventTouchUpInside];
        
        [vc.view addSubview:resetBtn];
        [vc.view addSubview:changeIDBtn];
    });
}
- (void)handleReset { performFullReset(); }
- (void)handleChangeID { changeIdentifiersOnly(); }
@end

// ============================================================
// MARK: - نقطة الإطلاق (%ctor) الآمنة
// ============================================================

%ctor {
    @autoreleasepool {
        forceAdConstraints();
        
        updateAtlantaLocation();
        generateSessionIPAsync();
        fakeAdvertisingIDString = generateRandomUUIDString();
        fakeUDIDString = generateRandomUDID();
        fetchRealIP();
        
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            forceAdConstraints();
        }];
        
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            performFullReset();
            changeIdentifiersOnly();
        }];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[AtlantaInfoManager sharedInstance] setupFloatingButtons];
        });
    }
}

// ============================================================
// MARK: - الـ Hooks
// ============================================================

%hook NSBundle
- (NSString *)bundleIdentifier {
    NSString *originalBundleID = @"com.codebysms"; 
    
    NSArray *callStack = [NSThread callStackSymbols];
    if (callStack.count > 1) {
        NSString *caller = callStack[1];
        if ([caller rangeOfString:@"IronSource" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [caller rangeOfString:@"UnityAds" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [caller rangeOfString:@"AdMob" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [caller rangeOfString:@"IS" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [caller rangeOfString:@"Ads" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return originalBundleID;
        }
    }
    
    return %orig;
}
%end

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    if (fakeAdvertisingIDString) {
        return [[NSUUID alloc] initWithUUIDString:fakeAdvertisingIDString];
    }
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
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    if (sessionFakeIP) {
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Forwarded-For"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"Client-IP"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Real-IP"];
    }
    if (request.URL.absoluteString) {
        logNetworkRequest(request.URL.absoluteString, sessionFakeIP, currentLat, currentLon);
    }
    return %orig(mutableReq, completionHandler);
}
%end
