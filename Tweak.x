#import <CoreLocation/CoreLocation.h>
#import <UIKit/UIKit.h>
#import <AdSupport/ASIdentifierManager.h>
#import <WebKit/WebKit.h>
#import <Security/Security.h>

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
static NSString *fakeIDFVString = nil;
static NSString *currentFakeUserAgent = nil;
static NSString *currentFakeModel = nil;
static NSString *currentFakeSystemVersion = nil;

// ============================================================
// MARK: - دوال توليد البصمات
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
    NSString *ua = iosVersions[arc4random_uniform((uint32_t)iosVersions.count)];
    currentFakeUserAgent = [NSString stringWithFormat:@"Mozilla/5.0 (iPhone; CPU iPhone OS %@ like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148", ua];
}

double randomInRange(double min, double max) {
    return min + (arc4random_uniform(UINT32_MAX) / (double)UINT32_MAX) * (max - min);
}

void updateAtlantaLocation() {
    currentLat = randomInRange(33.7000, 33.8000);
    currentLon = randomInRange(-84.4500, -84.3000);
}

NSArray *generate10IPs() {
    NSMutableArray *tempList = [NSMutableArray arrayWithCapacity:10];
    NSArray *secondOctets = @[@56, @58, @59];
    for (int i = 0; i < 10; i++) {
        int first  = 172;
        int second = [secondOctets[arc4random_uniform((uint32_t)secondOctets.count)] intValue];
        int third  = 1 + arc4random_uniform(254);
        int fourth = 1 + arc4random_uniform(254);
        [tempList addObject:[NSString stringWithFormat:@"%d.%d.%d.%d", first, second, third, fourth]];
    }
    return [tempList copy];
}

void generateSessionIP() {
    NSArray *candidates = generate10IPs();
    sessionFakeIP = candidates[arc4random_uniform((uint32_t)candidates.count)];
}

void fetchRealIP() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @autoreleasepool {
            NSURL *url = [NSURL URLWithString:@"https://api.ipify.org"];
            NSString *ip = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
            currentRealIP = (ip && ip.length > 0) ? ip : @"غير قادر على الجلب";
        }
    });
}

void logNetworkRequest(NSString *urlStr, NSString *ip, double lat, double lon) {
    if (!networkLogs) networkLogs = [[NSMutableArray alloc] init];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSString *path = url.path ? url.path : urlStr;
    if (path.length > 30) path = [[path substringToIndex:30] stringByAppendingString:@"..."];
    NSString *logEntry = [NSString stringWithFormat:@"🔗 %@\n🌐 IP: %@\n📱 %@ (iOS %@)", path, ip, currentFakeModel, currentFakeSystemVersion];
    @synchronized(networkLogs) {
        [networkLogs insertObject:logEntry atIndex:0];
        if (networkLogs.count > 15) [networkLogs removeLastObject];
    }
}

// ============================================================
// MARK: - اعتراض استجابات خدمات كشف IP
// ============================================================

static NSArray *ipServiceHosts = nil;

BOOL isIPServiceURL(NSURL *url) {
    if (!url || !url.host) return NO;
    if (!ipServiceHosts) {
        ipServiceHosts = @[
            @"ipify.org", @"ipinfo.io", @"ifconfig.me", @"icanhazip.com",
            @"checkip.amazonaws.com", @"myip.com", @"whatismyip.com",
            @"ip-api.com", @"ipapi.co", @"ipwho.is", @"ipecho.net",
            @"ident.me", @"seeip.org", @"my-ip.io", @"ipapi.com",
            @"ip.sb", @"ipwhois.app", @"ipstack.com", @"ipgeolocation.io",
            @"freegeoip.app", @"getipintel.net", @"whatismyipaddress.com",
            @"iplocation.net", @"ip4.seeip.org", @"bigdatacloud.net",
            @"ipapi.is", @"ipwhois.io", @"ipdata.co", @"ipqualityscore.com",
            @"ipapi.ipip.net", @"ip.cn", @"api.ipify.org", @"ip.42.pl",
            @"checkip.dyndns.org", @"geoip.nekudo.com", @"api.ipstack.com",
            @"extreme-ip-lookup.com", @"jsonip.com", @"api.myip.com"
        ];
    }
    NSString *host = url.host.lowercaseString;
    for (NSString *service in ipServiceHosts) {
        if ([host rangeOfString:service].location != NSNotFound) return YES;
    }
    return NO;
}

NSData *spoofIPsInData(NSData *data, NSString *fakeIP) {
    if (!data || data.length == 0 || !fakeIP || fakeIP.length == 0) return data;
    if (data.length > 256 * 1024) return data; // تجاهل الردود الكبيرة
    NSString *body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!body || body.length == 0) return data;

    static NSRegularExpression *ipRegex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ipRegex = [NSRegularExpression regularExpressionWithPattern:@"\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b"
                                                            options:0 error:nil];
    });
    NSString *newBody = [ipRegex stringByReplacingMatchesInString:body
                                                          options:0
                                                            range:NSMakeRange(0, body.length)
                                                     withTemplate:fakeIP];
    NSData *newData = [newBody dataUsingEncoding:NSUTF8StringEncoding];
    return newData ?: data;
}

// ============================================================
// MARK: - بناء CLLocation صحيح (بدون هذا التطبيق يعلق)
// ============================================================

CLLocation *buildFakeLocation(void) {
    updateAtlantaLocation();
    return [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(currentLat, currentLon)
                                         altitude:10.0
                               horizontalAccuracy:5.0
                                 verticalAccuracy:5.0
                                        timestamp:[NSDate date]];
}

// ============================================================
// MARK: - التنظيف العميق
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
        (__bridge id)kSecClassGenericPassword, (__bridge id)kSecClassInternetPassword,
        (__bridge id)kSecClassCertificate, (__bridge id)kSecClassKey, (__bridge id)kSecClassIdentity
    ];
    for (id secClass in secClasses) {
        NSDictionary *delQ = @{ (__bridge id)kSecClass: secClass };
        SecItemDelete((__bridge CFDictionaryRef)delQ);
    }
    if (savedValueData && savedService) {
        NSDictionary *addQ = @{
            (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecAttrService: savedService,
            (__bridge id)kSecAttrAccount: @"tokenKey",
            (__bridge id)kSecValueData: savedValueData
        };
        SecItemAdd((__bridge CFDictionaryRef)addQ, NULL);
    }
    if (result != NULL) CFRelease(result);
}

void performFullReset() {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        @autoreleasepool {
            clearKeychainKeepingAccount();
            NSHTTPCookieStorage *cs = [NSHTTPCookieStorage sharedHTTPCookieStorage];
            for (NSHTTPCookie *c in [cs cookies]) [cs deleteCookie:c];
            [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:[WKWebsiteDataStore allWebsiteDataTypes]
                                                      modifiedSince:[NSDate distantPast] completionHandler:^{}];
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
            if (bundleID) {
                [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleID];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
            [[NSURLCache sharedURLCache] removeAllCachedResponses];

            fakeAdvertisingIDString = generateRandomUUIDString();
            fakeIDFVString = generateRandomUUIDString();
            fakeUDIDString = generateRandomUDID();
            generateRandomDeviceProfile();
            updateAtlantaLocation();
            generateSessionIP();
            fetchRealIP();
            @synchronized(networkLogs) { [networkLogs removeAllObjects]; }

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                exit(0);
            });
        }
    });
}

// ============================================================
// MARK: - الواجهة والزر العائم
// ============================================================

@interface AtlantaWindow : UIWindow
@end

@implementation AtlantaWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *btn = [self viewWithTag:999888];
    return (btn && CGRectContainsPoint(btn.frame, point));
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
    static AtlantaInfoManager *s = nil;
    static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [[self alloc] init]; });
    return s;
}

- (void)setupFloatingButton {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.floatingWindow) return;
        self.floatingWindow = [[AtlantaWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
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

- (void)handlePan:(UIPanGestureRecognizer *)g {
    UIView *btn = g.view;
    CGPoint t = [g translationInView:btn.superview];
    CGFloat x = MAX(30, MIN([UIScreen mainScreen].bounds.size.width - 30, btn.center.x + t.x));
    CGFloat y = MAX(40, MIN([UIScreen mainScreen].bounds.size.height - 40, btn.center.y + t.y));
    btn.center = CGPointMake(x, y);
    [g setTranslation:CGPointZero inView:btn.superview];
}

- (void)handleReset {
    performFullReset();
}

@end

// ============================================================
// MARK: - الـ Hooks
// ============================================================

%ctor {
    @autoreleasepool {
        generateRandomDeviceProfile();
        updateAtlantaLocation();
        generateSessionIP();
        fakeAdvertisingIDString = generateRandomUUIDString();
        fakeIDFVString = generateRandomUUIDString();
        fakeUDIDString = generateRandomUDID();
        fetchRealIP();
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[AtlantaInfoManager sharedInstance] setupFloatingButton];
    });
}

#pragma mark - بصمات الجهاز

%hook ASIdentifierManager

- (NSUUID *)advertisingIdentifier {
    if (fakeAdvertisingIDString) {
        return [[NSUUID alloc] initWithUUIDString:fakeAdvertisingIDString];
    }
    return %orig;
}

%end

%hook UIDevice

- (NSUUID *)identifierForVendor {
    if (fakeIDFVString) {
        return [[NSUUID alloc] initWithUUIDString:fakeIDFVString];
    }
    return %orig;
}

%end

#pragma mark - الموقع

%hook CLLocationManager

- (void)startUpdatingLocation {
    CLLocation *loc = buildFakeLocation();
    id<CLLocationManagerDelegate> d = self.delegate;
    if (d && [d respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [d locationManager:self didUpdateLocations:@[loc]];
        });
    }
}

- (CLLocation *)location {
    return buildFakeLocation();
}

- (void)requestLocation {
    CLLocation *loc = buildFakeLocation();
    id<CLLocationManagerDelegate> d = self.delegate;
    if (d && [d respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [d locationManager:self didUpdateLocations:@[loc]];
        });
    }
}

%end

#pragma mark - اعتراض NSURLSession

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    if (sessionFakeIP) {
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Forwarded-For"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"Client-IP"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Real-IP"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Client-IP"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"Forwarded"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Originating-IP"];
    }
    if (currentFakeUserAgent) {
        [mutableReq setValue:currentFakeUserAgent forHTTPHeaderField:@"User-Agent"];
    }

    if (isIPServiceURL(request.URL) && sessionFakeIP && completionHandler) {
        NSString *fakeIP = [sessionFakeIP copy];
        void (^wrapped)(NSData *, NSURLResponse *, NSError *) = ^(NSData *data, NSURLResponse *response, NSError *error) {
            NSData *spoofed = spoofIPsInData(data, fakeIP);
            completionHandler(spoofed, response, error);
        };
        return %orig(mutableReq, wrapped);
    }

    return %orig(mutableReq, completionHandler);
}

%end

#pragma mark - اعتراض NSURLConnection

%hook NSURLConnection

+ (void)sendAsynchronousRequest:(NSURLRequest *)request
                          queue:(NSOperationQueue *)queue
              completionHandler:(void (^)(NSURLResponse *, NSData *, NSError *))handler {
    NSMutableURLRequest *mutableReq = [request mutableCopy];
    if (sessionFakeIP) {
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Forwarded-For"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"Client-IP"];
        [mutableReq setValue:sessionFakeIP forHTTPHeaderField:@"X-Real-IP"];
    }
    if (currentFakeUserAgent) {
        [mutableReq setValue:currentFakeUserAgent forHTTPHeaderField:@"User-Agent"];
    }
    if (isIPServiceURL(request.URL) && sessionFakeIP && handler) {
        NSString *fakeIP = [sessionFakeIP copy];
        void (^wrapped)(NSURLResponse *, NSData *, NSError *) = ^(NSURLResponse *response, NSData *data, NSError *error) {
            handler(response, spoofIPsInData(data, fakeIP), error);
        };
        %orig(mutableReq, queue, wrapped);
        return;
    }
    %orig(mutableReq, queue, handler);
}

%end

#pragma mark - حقن JavaScript في WKWebView

static NSString *AtlantaJSInjection(NSString *fakeIP) {
    return [NSString stringWithFormat:
        @"(function(){"
         "if(window.__atlantaHooked)return;window.__atlantaHooked=true;"
         "var FAKE='%@';"
         "var R=/\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b/g;"
         "var S=/ipify|ipinfo|ifconfig|icanhazip|myip|ipecho|ident\\.me|checkip|ip-api|ipapi|ipwho|ipstack|jsonip/i;"
         "var of=window.fetch;"
         "window.fetch=function(){"
           "var a=arguments;var u=(typeof a[0]==='string')?a[0]:(a[0]&&a[0].url)||'';"
           "return of.apply(this,a).then(function(r){"
             "if(S.test(u)){return r.text().then(function(t){"
               "var nt=t.replace(R,FAKE);"
               "return new Response(nt,{status:r.status,statusText:r.statusText,headers:r.headers});"
             "});}"
             "return r;"
           "});"
         "};"
         "var oo=XMLHttpRequest.prototype.open;"
         "XMLHttpRequest.prototype.open=function(m,u){this.__ip=S.test(u||'');return oo.apply(this,arguments);};"
         "var os=XMLHttpRequest.prototype.send;"
         "XMLHttpRequest.prototype.send=function(){"
           "var self=this;"
           "if(self.__ip){"
             "self.addEventListener('readystatechange',function(){"
               "if(self.readyState===4){"
                 "try{"
                   "var nt=(self.responseText||'').replace(R,FAKE);"
                   "Object.defineProperty(self,'responseText',{value:nt,configurable:true});"
                   "Object.defineProperty(self,'response',{value:nt,configurable:true});"
                 "}catch(e){}"
               "}"
             "});"
           "}"
           "return os.apply(this,arguments);"
         "};"
        "})();", fakeIP];
}

%hook WKWebView

- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    if (configuration && sessionFakeIP) {
        WKUserContentController *ucc = configuration.userContentController;
        if (!ucc) {
            ucc = [[WKUserContentController alloc] init];
            configuration.userContentController = ucc;
        }
        WKUserScript *script = [[WKUserScript alloc] initWithSource:AtlantaJSInjection(sessionFakeIP)
                                                        injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                     forMainFrameOnly:NO];
        [ucc addUserScript:script];
    }
    return %orig;
}

%end
