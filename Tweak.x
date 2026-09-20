// Tweak.x
// AdPurgeTweak - Fully working version

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <Security/Security.h>

// ============================================================
// الحالة العامة
// ============================================================
static NSString *gSessionIP = nil;

// ============================================================
// دوال مساعدة
// ============================================================
static NSString *generateDutchIP(void) {
    return [NSString stringWithFormat:@"84.241.%u.%u",
            arc4random_uniform(256), arc4random_uniform(256)];
}

static UIWindow *getKeyWindow(void) {
    UIWindow *keyWindow = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                    if (w.isKeyWindow) { keyWindow = w; break; }
                }
            }
            if (keyWindow) break;
        }
    }
    if (!keyWindow) keyWindow = [UIApplication sharedApplication].keyWindow;
    if (!keyWindow) keyWindow = [[UIApplication sharedApplication].windows firstObject];
    return keyWindow;
}

// ============================================================
// عرض رسالة التنبيه عند فتح التطبيق
// ============================================================
static void showTweakAlert(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@"✅ التويك شغّال"
                             message:[NSString stringWithFormat:
                                      @"Tweak is active!\n\nIP المثبّت:\n%@", gSessionIP]
                      preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"حسنًا"
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];

        UIViewController *root = getKeyWindow().rootViewController;
        while (root.presentedViewController) root = root.presentedViewController;

        if (root) {
            [root presentViewController:alert animated:YES completion:nil];
        } else {
            // إعادة المحاولة بعد ثانية إذا لم يكن الـ root جاهزًا
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                UIViewController *r2 = getKeyWindow().rootViewController;
                if (r2) [r2 presentViewController:alert animated:YES completion:nil];
            });
        }
    });
}

// ============================================================
// الحذف الشامل (Deep Clean)
// ============================================================
static void performDeepClean(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *home = NSHomeDirectory();
    NSLog(@"[Tweak] Home: %@", home);

    NSArray *dirs = @[
        [home stringByAppendingPathComponent:@"Documents"],
        [home stringByAppendingPathComponent:@"Library"],
        [home stringByAppendingPathComponent:@"tmp"],
    ];

    for (NSString *dir in dirs) {
        NSError *err = nil;
        NSArray *contents = [fm contentsOfDirectoryAtPath:dir error:&err];
        if (err) { NSLog(@"[Tweak] Cannot list %@: %@", dir, err); continue; }

        for (NSString *item in contents) {
            NSString *full = [dir stringByAppendingPathComponent:item];
            NSError *e = nil;
            if ([fm removeItemAtPath:full error:&e]) {
                NSLog(@"[Tweak] Removed: %@", full);
            } else {
                NSLog(@"[Tweak] Failed: %@ — %@", full, e.localizedDescription);
            }
        }
    }

    // Network caches + cookies
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    NSHTTPCookieStorage *cs = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *c in [[cs cookies] copy]) [cs deleteCookie:c];

    NSLog(@"[Tweak] Deep clean completed.");
}

// ============================================================
// تنظيف Keychain مع الحفاظ على توكن تسجيل الدخول
// ============================================================
static void cleanKeychainExceptToken(void) {
    NSDictionary *q = @{
        (__bridge id)kSecClass:           (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecReturnAttributes: @YES,
        (__bridge id)kSecMatchLimit:      (__bridge id)kSecMatchLimitAll,
    };

    CFTypeRef result = NULL;
    OSStatus st = SecItemCopyMatching((__bridge CFDictionaryRef)q, &result);
    if (st != errSecSuccess || !result) {
        NSLog(@"[Tweak] Keychain query returned: %d", (int)st);
        return;
    }

    NSArray *items = (__bridge_transfer NSArray *)result;
    for (NSDictionary *item in items) {
        NSString *service = item[(__bridge id)kSecAttrService];
        NSString *account = item[(__bridge id)kSecAttrAccount];

        if ([service isEqualToString:@"app.getsmscode"] &&
            [account isEqualToString:@"tokenKey"]) {
            NSLog(@"[Tweak] ✓ Keeping token: %@ / %@", service, account);
            continue;
        }

        NSDictionary *del = @{
            (__bridge id)kSecClass:       (__bridge id)kSecClassGenericPassword,
            (__bridge id)kSecAttrService: service ?: @"",
            (__bridge id)kSecAttrAccount: account ?: @"",
        };
        SecItemDelete((__bridge CFDictionaryRef)del);
    }
    NSLog(@"[Tweak] Keychain cleanup done.");
}

// ============================================================
// ضبط NSUserDefaults (بيئة أوروبية مثالية)
// ============================================================
static void configureDefaults(void) {
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSString *now = [NSString stringWithFormat:@"%.0f", [[NSDate date] timeIntervalSince1970]];

    [d setObject:now forKey:@"AppsFlyerInstallDate"];
    [d setObject:now forKey:@"AppsFlyerInitDate"];
    [d setObject:now forKey:@"AppsFlyerFirstLaunchDate"];
    [d setObject:@(1) forKey:@"AppsFlyerCounter"];
    [d setObject:@(0) forKey:@"AppsFlyerReinstallCounter"];
    [d setObject:@(1) forKey:@"AppsFlyerLaunchKey"];

    [d setObject:@"1"            forKey:@"IABTCF_gdprApplies"];
    [d setObject:@"11111111111"  forKey:@"IABTCF_PurposeConsents"];
    [d setObject:@"01000011111"  forKey:@"IABTCF_PurposeLegitimateInterests"];
    [d setObject:@"1"            forKey:@"IABTCF_SpecialFeaturesOptIns"];
    [d setObject:@"CY"           forKey:@"IABTCF_PublisherCC"];
    [d setObject:@"3"            forKey:@"ump_status"];
    [d setBool:NO                forKey:@"em_lockdownModeEnabled"];

    [d synchronize];
    NSLog(@"[Tweak] Defaults configured.");
}

// ============================================================
// NSURLProtocol - حقن الـ IP في كل الطلبات
// ============================================================
@interface DutchIPProtocol : NSURLProtocol <NSURLSessionDataDelegate>
@property (nonatomic, strong) NSURLSessionDataTask *task;
@end

@implementation DutchIPProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if (![request.URL.scheme isEqualToString:@"http"] &&
        ![request.URL.scheme isEqualToString:@"https"]) return NO;
    if ([NSURLProtocol propertyForKey:@"DutchHandled" inRequest:request]) return NO;
    return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request { return request; }

- (void)startLoading {
    NSMutableURLRequest *req = [self.request mutableCopy];
    if (gSessionIP) {
        [req setValue:gSessionIP forHTTPHeaderField:@"X-Forwarded-For"];
        [req setValue:gSessionIP forHTTPHeaderField:@"X-Real-IP"];
        [req setValue:gSessionIP forHTTPHeaderField:@"X-Client-IP"];
        [req setValue:gSessionIP forHTTPHeaderField:@"CF-Connecting-IP"];
        [req setValue:gSessionIP forHTTPHeaderField:@"True-Client-IP"];
    }
    [NSURLProtocol setProperty:@YES forKey:@"DutchHandled" inRequest:req];

    NSURLSessionConfiguration *cfg = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:cfg delegate:self delegateQueue:nil];
    self.task = [session dataTaskWithRequest:req];
    [self.task resume];
}

- (void)stopLoading { [self.task cancel]; }

- (void)URLSession:(NSURLSession *)s
              dataTask:(NSURLSessionDataTask *)t
    didReceiveResponse:(NSURLResponse *)r
     completionHandler:(void (^)(NSURLSessionResponseDisposition))ch {
    [self.client URLProtocol:self didReceiveResponse:r cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    ch(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)s dataTask:(NSURLSessionDataTask *)t didReceiveData:(NSData *)data {
    [self.client URLProtocol:self didLoadData:data];
}

- (void)URLSession:(NSURLSession *)s task:(NSURLSessionTask *)t didCompleteWithError:(NSError *)err {
    if (err) [self.client URLProtocol:self didFailWithError:err];
    else     [self.client URLProtocolDidFinishLoading:self];
}

@end

// ============================================================
// Hook NSURLSession مباشرة كخط دفاع ثانٍ (مهم جدًا)
// ============================================================
static NSMutableURLRequest *injectIP(NSURLRequest *req) {
    if (![req isKindOfClass:[NSURLRequest class]]) return nil;
    NSMutableURLRequest *m = [req mutableCopy];
    if (gSessionIP) {
        [m setValue:gSessionIP forHTTPHeaderField:@"X-Forwarded-For"];
        [m setValue:gSessionIP forHTTPHeaderField:@"X-Real-IP"];
        [m setValue:gSessionIP forHTTPHeaderField:@"X-Client-IP"];
    }
    return m;
}

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    NSMutableURLRequest *m = injectIP(request);
    return %orig(m ?: request);
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    NSMutableURLRequest *m = injectIP(request);
    return %orig(m ?: request, completionHandler);
}

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)bodyData {
    NSMutableURLRequest *m = injectIP(request);
    return %orig(m ?: request, bodyData);
}

- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request {
    NSMutableURLRequest *m = injectIP(request);
    return %orig(m ?: request);
}

%end

// ============================================================
// Hook دوال الإعلانات
// ============================================================
static void safeHookBool(Class cls, NSString *selName, BOOL returnValue) {
    if (!cls) return;
    SEL sel = NSSelectorFromString(selName);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;

    unsigned int numArgs = method_getNumberOfArguments(m);
    if (numArgs != 2) {
        NSLog(@"[Tweak] Skip %@ -%@ (args=%u)", NSStringFromClass(cls), selName, numArgs);
        return;
    }
    __block BOOL val = returnValue;
    IMP newImp = imp_implementationWithBlock(^BOOL(id _self){ return val; });
    method_setImplementation(m, newImp);
    NSLog(@"[Tweak] ✓ Hooked %@ -%@ → %@",
          NSStringFromClass(cls), selName, returnValue ? @"YES" : @"NO");
}

static void hookAdClasses(void) {
    // ابحث عن أي كلاس يحتوي على AdService أو AdManager
    NSMutableArray *candidates = [NSMutableArray array];

    int count = objc_getClassList(NULL, 0);
    Class *classes = (Class *)malloc(sizeof(Class) * count);
    objc_getClassList(classes, count);
    for (int i = 0; i < count; i++) {
        NSString *name = NSStringFromClass(classes[i]);
        if ([name containsString:@"AdService"] ||
            [name containsString:@"AdManager"] ||
            [name containsString:@"AdController"]) {
            [candidates addObject:name];
        }
    }
    free(classes);

    if (candidates.count == 0) {
        NSLog(@"[Tweak] No ad classes found. Will retry later.");
        return;
    }

    NSLog(@"[Tweak] Ad class candidates: %@", candidates);

    for (NSString *cn in candidates) {
        Class c = NSClassFromString(cn);
        safeHookBool(c, @"isReady",              YES);
        safeHookBool(c, @"isAdReady",            YES);
        safeHookBool(c, @"hasAd",                YES);
        safeHookBool(c, @"canShowAd",            YES);
        safeHookBool(c, @"hasActiveSubscription", NO);
        safeHookBool(c, @"isPurchased",          NO);
    }
}

// ============================================================
// Constructor - نقطة البداية
// ============================================================
%ctor {
    NSLog(@"[Tweak] ========== LOADING ==========");

    // 1) توليد IP هولندي
    gSessionIP = generateDutchIP();
    NSLog(@"[Tweak] Pinned IP: %@", gSessionIP);

    // 2) تسجيل NSURLProtocol
    [NSURLProtocol registerClass:[DutchIPProtocol class]];

    // 3) الحذف الشامل
    performDeepClean();
    cleanKeychainExceptToken();

    // 4) ضبط NSUserDefaults
    configureDefaults();

    // 5) تسجيل الإشعار لعرض الرسالة
    [[NSNotificationCenter defaultCenter]
        addObserverForName:UIApplicationDidFinishLaunchingNotification
                    object:nil
                     queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification *note) {
        NSLog(@"[Tweak] App launched - showing alert");
        showTweakAlert();
    }];

    // 6) hook الإعلانات بعد ثانيتين (لضمان تحميل الكلاسات)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        hookAdClasses();
    });

    // محاولة ثانية بعد 5 ثوانٍ في حال كانت الكلاسات تأخرت
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        hookAdClasses();
    });
}
