#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>
#import <WebKit/WebKit.h>
#import <Security/Security.h>
#import <sys/utsname.h>

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
static NSString *fakeDeviceName = nil;

// ============================================================
// MARK: - دوال التوليد والمساعدة
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

void updateAtlantaLocation() {
    currentLat = randomInRange(33.7000, 33.8000);
    currentLon = randomInRange(-84.4500, -84.3500);
}

NSArray *generate10IPs() {
    NSMutableArray *tempList = [NSMutableArray arrayWithCapacity:10];
    int allowedSecondOctets[] = {56, 57, 59};
    for (int i = 0; i < 10; i++) {
        int second = allowedSecondOctets[arc4random_uniform(3)];
        int third = arc4random_uniform(256);
        int fourth = arc4random_uniform(256);
        NSString *ip = [NSString stringWithFormat:@"172.%d.%d.%d", second, third, fourth];
        [tempList addObject:ip];
    }
    return [tempList copy];
}

BOOL verifyIPQuality(NSString *ip) {
    if (!ip || ip.length == 0) return NO;
    
    NSString *urlString = [NSString stringWithFormat:@"http://ip-api.com/json/%@?fields=status,isp,org,as", ip];
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setTimeoutInterval:2.0];
    
    __block NSData *responseData = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        responseData = data;
        dispatch_semaphore_signal(semaphore);
    }];
    [task resume];
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)));
    
    if (!responseData) return YES;
    
    NSError *jsonError = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&jsonError];
    if (jsonError || !json) return YES;
    if (![json[@"status"] isEqualToString:@"success"]) return YES;
    
    NSString *combined = [NSString stringWithFormat:@"%@ %@ %@", json[@"org"], json[@"isp"], json[@"as"]];
    NSArray *badKeywords = @[@"Hosting", @"Datacenter", @"Cloud", @"Server", @"Dedicated", @"VPS", @"CDN", @"Akamai", @"Amazon", @"AWS", @"DigitalOcean"];
    for (NSString *keyword in badKeywords) {
        if ([combined rangeOfString:keyword options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return NO;
        }
    }
    return YES;
}

void generateSessionIP() {
    NSArray *candidates = generate10IPs();
    NSString *selectedIP = nil;
    for (NSString *ip in candidates) {
        if (verifyIPQuality(ip)) {
            selectedIP = ip;
            break;
        }
    }
    sessionFakeIP = selectedIP ?: candidates.lastObject;
}

void fetchRealIP() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURL *url = [NSURL URLWithString:@"https://api.ipify.org"];
        NSString *ip = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
        currentRealIP = (ip && ip.length > 0) ? ip : @"غير قادر على الجلب";
    });
}

// ============================================================
// MARK: - دالة تطبيق قيم الـ Capping المحددة على NSUserDefaults
// ============================================================

static void overrideDefaults(NSUserDefaults *defaults) {
    if (!defaults) return;
    
    [defaults setBool:NO  forKey:@"IS_CappingManager.IS_CAPPING_ENABLED_DefaultInterstitial"];
    [defaults setBool:YES forKey:@"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial"];
    [defaults setBool:NO  forKey:@"BN_CappingManager.IS_CAPPING_ENABLED_DefaultBanner"];
    [defaults setBool:NO  forKey:@"BN_CappingManager.IS_PACING_ENABLED_DefaultBanner"];
    [defaults setBool:YES forKey:@"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"];
    [defaults setInteger:0 forKey:@"com.inobi_defaultStore_sessionCount"];
}

// ============================================================
// MARK: - مسح الـ Keychain مع الحفاظ على الحساب
// ============================================================

void clearKeychainKeepingAccount() {
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

// ============================================================
// MARK: - التنظيف العميق للذاكرة المؤقتة والـ RAM Cache
// ============================================================

void clearRAMAndCachesDeeply() {
    @autoreleasepool {
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
            [cookieStorage deleteCookie:cookie];
        }
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        [[NSURLCache sharedURLCache] setDiskCapacity:0];
        [[NSURLCache sharedURLCache] setMemoryCapacity:0];

        if (@available(iOS 9.0, *)) {
            [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:[WKWebsiteDataStore allWebsiteDataTypes]
                                                   modifiedSince:[NSDate distantPast]
                                               completionHandler:^{}];
        }

        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *libraryDir = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
        NSString *cachesDir = [libraryDir stringByAppendingPathComponent:@"Caches"];
        NSString *tmpDir = NSTemporaryDirectory();
        
        NSArray *dirsToClean = @[cachesDir, tmpDir];
        for (NSString *dir in dirsToClean) {
            if (dir && [fm fileExistsAtPath:dir]) {
                for (NSString *item in [fm contentsOfDirectoryAtPath:dir error:nil]) {
                    NSString *fullPath = [dir stringByAppendingPathComponent:item];
                    [fm removeItemAtPath:fullPath error:nil];
                }
            }
        }
    }
}

void performFullReset() {
    clearKeychainKeepingAccount();
    clearRAMAndCachesDeeply();
    
    overrideDefaults([NSUserDefaults standardUserDefaults]);
    
    fakeAdvertisingIDString = generateRandomUUIDString();
    fakeUDIDString = generateRandomUDID();
    
    NSString *uuidPrefix = generateRandomUUIDString();
    if (uuidPrefix.length >= 6) {
        fakeDeviceName = [NSString stringWithFormat:@"iPhone-%@", [uuidPrefix substringToIndex:6]];
    } else {
        fakeDeviceName = @"iPhone-15Pro";
    }
    
    updateAtlantaLocation();
    generateSessionIP();
    fetchRealIP();
    
    @synchronized(networkLogs) {
        if (networkLogs) [networkLogs removeAllObjects];
    }
}

// ============================================================
// MARK: - الأزرار العائمة وتنسيق الشاشة
// ============================================================

@interface AtlantaWindow : UIWindow
@end
@implementation AtlantaWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return YES;
}
@end

@interface AtlantaInfoManager : NSObject
@property (strong, nonatomic) AtlantaWindow *window;
+ (instancetype)shared;
@end
@implementation AtlantaInfoManager
+ (instancetype)shared {
    static AtlantaInfoManager *s;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [self new]; });
    return s;
}
-init {
    self = [super init];
    if (self) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.window = [[AtlantaWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            self.window.windowLevel = UIWindowLevelAlert + 1000;
            self.window.hidden = NO;
            self.window.backgroundColor = [UIColor clearColor];
            
            UIViewController *vc = [UIViewController new];
            vc.view.backgroundColor = [UIColor clearColor];
            self.window.rootViewController = vc;
            
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
            btn.frame = CGRectMake(20, 120, 50, 50);
            btn.backgroundColor = [UIColor systemBlueColor];
            [btn setTitle:@"🔄" forState:UIControlStateNormal];
            btn.layer.cornerRadius = 25;
            [btn addTarget:self action:@selector(resetAction) forControlEvents:UIControlEventTouchUpInside];
            [vc.view addSubview:btn];
        });
    }
    return self;
}
-resetAction { performFullReset(); }
@end

// ============================================================
// MARK: - التنفيذ التلقائي الجذري عند فتح التطبيق
// ============================================================

%ctor {
    @autoreleasepool {
        performFullReset();
        [AtlantaInfoManager shared];
        NSLog(@"[AdForceGlobal] RAM and Caches purged successfully, ad constraints enforced!");
    }
}

// ============================================================
// MARK: - الـ Hooks لمنع التتبع وحظر الـ SDKs وضبط الـ Capping
// ============================================================

%hook ASIdentifierManager
- (NSUUID *)advertisingIdentifier {
    return fakeAdvertisingIDString ? [[NSUUID alloc] initWithUUIDString:fakeAdvertisingIDString] : %orig;
}
%end

%hook UIDevice
- (NSString *)name {
    return fakeDeviceName ?: %orig;
}
- (NSUUID *)identifierForVendor {
    return fakeUDIDString ? [[NSUUID alloc] initWithUUIDString:fakeUDIDString] : %orig;
}
%end

%hook NSUserDefaults

- (void)setBool:(BOOL)value forKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"IS_CappingManager.IS_CAPPING_ENABLED_DefaultInterstitial"]) {
        value = NO;
    } else if ([defaultName isEqualToString:@"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial"]) {
        value = YES;
    } else if ([defaultName isEqualToString:@"BN_CappingManager.IS_CAPPING_ENABLED_DefaultBanner"]) {
        value = NO;
    } else if ([defaultName isEqualToString:@"BN_CappingManager.IS_PACING_ENABLED_DefaultBanner"]) {
        value = NO;
    } else if ([defaultName isEqualToString:@"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"]) {
        value = YES;
    }
    %orig(value, defaultName);
}

- (void)setInteger:(NSInteger)value forKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"com.inobi_defaultStore_sessionCount"]) {
        value = 0;
    }
    %orig(value, defaultName);
}

- (BOOL)boolForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"IS_CappingManager.IS_CAPPING_ENABLED_DefaultInterstitial"]) return NO;
    if ([defaultName isEqualToString:@"IS_CappingManager.IS_DELIVERY_ENABLED_DefaultInterstitial"]) return YES;
    if ([defaultName isEqualToString:@"BN_CappingManager.IS_CAPPING_ENABLED_DefaultBanner"]) return NO;
    if ([defaultName isEqualToString:@"BN_CappingManager.IS_PACING_ENABLED_DefaultBanner"]) return NO;
    if ([defaultName isEqualToString:@"RV_CappingManager.IS_DELIVERY_ENABLED_DefaultRewardedVideo"]) return YES;
    return %orig;
}

- (NSInteger)integerForKey:(NSString *)defaultName {
    if ([defaultName isEqualToString:@"com.inobi_defaultStore_sessionCount"]) return 0;
    return %orig;
}

%end

%hook CLLocationManager
- (void)startUpdatingLocation {
    updateAtlantaLocation();
    CLLocation *loc = [[CLLocation alloc] initWithLatitude:currentLat longitude:currentLon];
    if ([self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        [self.delegate locationManager:self didUpdateLocations:@[loc]];
    }
}
- (CLLocation *)location {
    updateAtlantaLocation();
    return [[CLLocation alloc] initWithLatitude:currentLat longitude:currentLon];
}
%end

%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    NSMutableURLRequest *req = [request mutableCopy];
    if (sessionFakeIP) {
        [req setValue:sessionFakeIP forHTTPHeaderField:@"X-Forwarded-For"];
        [req setValue:sessionFakeIP forHTTPHeaderField:@"Client-IP"];
        [req setValue:sessionFakeIP forHTTPHeaderField:@"X-Real-IP"];
    }
    return %orig(req, handler);
}
%end
