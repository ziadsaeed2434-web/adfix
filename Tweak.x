// Tweak.xm
// Target: iOS tweak that adds a floating button which applies
// IP / IDFA / Location spoofing + safe cache & defaults cleanup.

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AdSupport/ASIdentifierManager.h>
#import <CoreLocation/CoreLocation.h>
#import <Security/Security.h>
#import <objc/runtime.h>

#pragma mark - Global Spoofing State

static NSString *gSpoofedIP          = nil;
static NSUUID   *gSpoofedIDFA        = nil;
static double    gSpoofedLatitude    = 0.0;
static double    gSpoofedLongitude   = 0.0;
static BOOL      gLocationSpoofActive = NO;

// Protect state mutation from concurrent access
static dispatch_queue_t gStateQueue;

#pragma mark - Helpers

static NSString *generateRandomIP(void) {
    NSArray<NSString *> *subnets = @[@"172.56", @"172.57", @"172.59"];
    NSString *subnet = subnets[arc4random_uniform((uint32_t)subnets.count)];
    uint32_t third  = arc4random_uniform(256);
    uint32_t fourth = arc4random_uniform(256);
    return [NSString stringWithFormat:@"%@.%u.%u", subnet, third, fourth];
}

static NSUUID *generateRandomIDFA(void) {
    return [NSUUID UUID];
}

static void generateAtlantaCoordinate(double *outLat, double *outLon) {
    // Latitude:  33.7480 → 33.7900
    // Longitude: -84.3880 → -84.4300
    double lat = 33.7480 + ((double)arc4random_uniform(4200) / 10000.0);
    double lon = -84.3880 - ((double)arc4random_uniform(4200) / 10000.0);
    if (outLat) *outLat = lat;
    if (outLon) *outLon = lon;
}

static NSMutableURLRequest *injectIPIntoRequest(NSURLRequest *request) {
    if (!request) return nil;
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    NSString *ip = nil;
    @synchronized (gStateQueue) {
        ip = [gSpoofedIP copy];
    }
    if (ip) {
        [mutableRequest setValue:ip forHTTPHeaderField:@"X-Forwarded-For"];
        [mutableRequest setValue:ip forHTTPHeaderField:@"X-Real-IP"];
        [mutableRequest setValue:ip forHTTPHeaderField:@"Client-IP"];
    }
    return mutableRequest;
}

#pragma mark - NSURLProtocol (catches NSURLSession / NSURLConnection / WebView traffic)

@interface SpoofedIPProtocol : NSURLProtocol
@end

@implementation SpoofedIPProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if (!request || !request.URL) return NO;
    NSString *scheme = request.URL.scheme.lowercaseString;
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) return NO;
    // Prevent infinite recursion
    if ([NSURLProtocol propertyForKey:@"SpoofedIPHandled" inRequest:request]) return NO;
    return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    NSMutableURLRequest *newRequest = [self.request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:@"SpoofedIPHandled" inRequest:newRequest];

    NSString *ip = nil;
    @synchronized (gStateQueue) {
        ip = [gSpoofedIP copy];
    }
    if (ip) {
        [newRequest setValue:ip forHTTPHeaderField:@"X-Forwarded-For"];
        [newRequest setValue:ip forHTTPHeaderField:@"X-Real-IP"];
        [newRequest setValue:ip forHTTPHeaderField:@"Client-IP"];
    }

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    // Disable our protocol inside the internal session so we don't loop
    config.protocolClasses = @[];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config
                                                          delegate:self
                                                     delegateQueue:nil];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:newRequest];
    objc_setAssociatedObject(task, @selector(startLoading), session, OBJC_ASSOCIATION_RETAIN);
    [task resume];
}

- (void)stopLoading {
    // No-op; session will finish naturally
}

#pragma mark - NSURLSessionDelegate (forwarding)

- (void)URLSession:(NSURLSession *)session
              dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveResponse:(NSURLResponse *)response
     completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    [self.client URLProtocol:self
          didReceiveResponse:response
          cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    if (completionHandler) completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session
              dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    [self.client URLProtocol:self didLoadData:data];
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error {
    if (error) {
        [self.client URLProtocol:self didFailWithError:error];
    } else {
        [self.client URLProtocolDidFinishLoading:self];
    }
}

@end

#pragma mark - NSURLSession request-level hooks (extra coverage)

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    return %orig(injectIPIntoRequest(request));
}
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    return %orig(injectIPIntoRequest(request), handler);
}
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url {
    NSURLRequest *req = url ? [NSURLRequest requestWithURL:url] : nil;
    return %orig(injectIPIntoRequest(req));
}
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url
                        completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    NSURLRequest *req = url ? [NSURLRequest requestWithURL:url] : nil;
    return %orig(injectIPIntoRequest(req), handler);
}
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)body {
    return %orig(injectIPIntoRequest(request), body);
}
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request
                                         fromFile:(NSURL *)fileURL {
    return %orig(injectIPIntoRequest(request), fileURL);
}
- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request {
    return %orig(injectIPIntoRequest(request));
}
- (NSURLSessionDownloadTask *)downloadTaskWithRequest:(NSURLRequest *)request
                                    completionHandler:(void (^)(NSURL *, NSURLResponse *, NSError *))handler {
    return %orig(injectIPIntoRequest(request), handler);
}

%end

#pragma mark - IDFA spoofing

%hook ASIdentifierManager

- (NSUUID *)advertisingIdentifier {
    NSUUID *idfa = nil;
    @synchronized (gStateQueue) {
        idfa = [gSpoofedIDFA copy];
    }
    if (idfa) return idfa;
    return %orig;
}

- (BOOL)isAdvertisingTrackingEnabled {
    // Force-enable so SDKs pick up our spoofed IDFA
    return YES;
}

%end

#pragma mark - Location spoofing

%hook CLLocationManager

- (CLLocation *)location {
    if (gLocationSpoofActive) {
        return [[CLLocation alloc] initWithLatitude:gSpoofedLatitude
                                          longitude:gSpoofedLongitude];
    }
    return %orig;
}

- (void)startUpdatingLocation {
    %orig;
    if (gLocationSpoofActive) {
        CLLocation *fake = [[CLLocation alloc] initWithLatitude:gSpoofedLatitude
                                                     longitude:gSpoofedLongitude];
        // Deliver asynchronously to mimic real behavior and avoid re-entrancy
        dispatch_async(dispatch_get_main_queue(), ^{
            id<CLLocationManagerDelegate> delegate = self.delegate;
            if (delegate && [delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
                [delegate locationManager:self didUpdateLocations:@[fake]];
            }
        });
    }
}

- (void)requestLocation {
    %orig;
    if (gLocationSpoofActive) {
        CLLocation *fake = [[CLLocation alloc] initWithLatitude:gSpoofedLatitude
                                                     longitude:gSpoofedLongitude];
        dispatch_async(dispatch_get_main_queue(), ^{
            id<CLLocationManagerDelegate> delegate = self.delegate;
            if (delegate && [delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
                [delegate locationManager:self didUpdateLocations:@[fake]];
            }
        });
    }
}

%end

// Also patch the CLLocation object itself for apps that read coordinate directly.
%hook CLLocation

- (CLLocationCoordinate2D)coordinate {
    if (gLocationSpoofActive) {
        return CLLocationCoordinate2DMake(gSpoofedLatitude, gSpoofedLongitude);
    }
    return %orig;
}

%end

#pragma mark - UI: floating button

@interface SpoofFloatingButton : UIButton
@end

@implementation SpoofFloatingButton

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:0.15 green:0.55 blue:1.0 alpha:0.9];
        self.layer.cornerRadius = frame.size.width / 2.0;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOffset = CGSizeMake(0, 2);
        self.layer.shadowOpacity = 0.4;
        self.layer.shadowRadius = 4.0;
        self.titleLabel.font = [UIFont systemFontOfSize:26 weight:UIFontWeightBold];
        [self setTitle:@"⚡" forState:UIControlStateNormal];
        [self addTarget:self action:@selector(onTap) forControlEvents:UIControlEventTouchUpInside];
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPan:)];
        [self addGestureRecognizer:pan];
    }
    return self;
}

- (void)onPan:(UIPanGestureRecognizer *)g {
    UIView *superview = self.superview;
    if (!superview) return;
    CGPoint t = [g translationInView:superview];
    CGPoint c = self.center;
    c.x += t.x;
    c.y += t.y;
    // Clamp inside superview bounds
    CGFloat half = self.bounds.size.width / 2.0;
    c.x = MAX(half, MIN(superview.bounds.size.width  - half, c.x));
    c.y = MAX(half, MIN(superview.bounds.size.height - half, c.y));
    self.center = c;
    [g setTranslation:CGPointZero inView:superview];
}

- (void)onTap {
    // Run the heavy work on a background queue, UI updates on main.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        // 1. New IP
        NSString *newIP = generateRandomIP();
        // 2. New IDFA
        NSUUID *newIDFA = generateRandomIDFA();
        // 3. New Atlanta coordinate
        double lat = 0, lon = 0;
        generateAtlantaCoordinate(&lat, &lon);

        @synchronized (gStateQueue) {
            gSpoofedIP          = newIP;
            gSpoofedIDFA        = newIDFA;
            gSpoofedLatitude    = lat;
            gSpoofedLongitude   = lon;
            gLocationSpoofActive = YES;
        }

        NSLog(@"[SpoofTweak] IP=%@ IDFA=%@ Loc=(%.4f, %.4f)", newIP, newIDFA.UUIDString, lat, lon);

        // 4. Clear Caches / tmp / Documents
        [SpoofFloatingButton clearSafeDirectories];

        // 5. Clear NSUserDefaults
        [SpoofFloatingButton clearAppDefaults];

        // 6. Selective Keychain cleanup
        [SpoofFloatingButton clearKeychainExceptToken];

        // UI confirmation
        dispatch_async(dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = nil;
            for (UIWindow *w in UIApplication.sharedApplication.windows) {
                if (w.isKeyWindow) { keyWindow = w; break; }
            }
            if (!keyWindow) return;
            UIViewController *rootVC = keyWindow.rootViewController;
            if (!rootVC) return;

            NSString *message = [NSString stringWithFormat:
                                 @"IP: %@\nIDFA: %@\nLocation: (%.4f, %.4f)\n\nCaches & defaults cleared.",
                                 newIP, newIDFA.UUIDString, lat, lon];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"✅ Spoof Applied"
                                                                           message:message
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];

            // Avoid "already presenting" crash
            UIViewController *presenter = rootVC;
            while (presenter.presentedViewController) presenter = presenter.presentedViewController;
            [presenter presentViewController:alert animated:YES completion:nil];
        });
    });
}

#pragma mark - Cleanup routines

+ (void)clearSafeDirectories {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray<NSString *> *paths = [NSMutableArray array];

    NSArray *caches = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    if (caches.firstObject) [paths addObject:caches.firstObject];

    NSString *tmp = NSTemporaryDirectory();
    if (tmp) [paths addObject:tmp];

    NSArray *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (docs.firstObject) [paths addObject:docs.firstObject];

    for (NSString *dir in paths) {
        NSError *listError = nil;
        NSArray<NSString *> *contents = [fm contentsOfDirectoryAtPath:dir error:&listError];
        if (listError) {
            NSLog(@"[SpoofTweak] list error %@: %@", dir, listError.localizedDescription);
            continue;
        }
        for (NSString *name in contents) {
            // Skip hidden dot files (often used by the OS)
            if ([name hasPrefix:@"."]) continue;

            NSString *full = [dir stringByAppendingPathComponent:name];
            NSError *rmError = nil;
            if (![fm removeItemAtPath:full error:&rmError]) {
                NSLog(@"[SpoofTweak] rm failed %@: %@", full, rmError.localizedDescription);
            }
        }
    }
}

+ (void)clearAppDefaults {
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
    if (!bundleID) return;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removePersistentDomainForName:bundleID];
    [defaults synchronize];
    NSLog(@"[SpoofTweak] NSUserDefaults domain cleared: %@", bundleID);
}

+ (void)clearKeychainExceptToken {
    NSMutableDictionary *query = [NSMutableDictionary dictionary];
    query[(__bridge id)kSecClass]       = (__bridge id)kSecClassGenericPassword;
    query[(__bridge id)kSecMatchLimit]  = (__bridge id)kSecMatchLimitAll;
    query[(__bridge id)kSecReturnAttributes] = @YES;

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess || !result) {
        if (status != errSecItemNotFound) {
            NSLog(@"[SpoofTweak] keychain query status=%d", (int)status);
        }
        return;
    }

    NSArray *items = (__bridge_transfer NSArray *)result;
    for (NSDictionary *item in items) {
        if (![item isKindOfClass:[NSDictionary class]]) continue;

        NSString *service = item[(__bridge id)kSecAttrService];
        NSString *account = item[(__bridge id)kSecAttrAccount];

        // ----- PRESERVE THIS ITEM -----
        if ([service isEqualToString:@"app.getsmscode"] &&
            [account isEqualToString:@"tokenKey"]) {
            NSLog(@"[SpoofTweak] preserved keychain item %@/%@", service, account);
            continue;
        }
        // ------------------------------

        NSMutableDictionary *del = [NSMutableDictionary dictionary];
        del[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
        if (service) del[(__bridge id)kSecAttrService] = service;
        if (account) del[(__bridge id)kSecAttrAccount] = account;

        OSStatus delStatus = SecItemDelete((__bridge CFDictionaryRef)del);
        if (delStatus == errSecSuccess) {
            NSLog(@"[SpoofTweak] deleted keychain item %@/%@", service, account);
        } else if (delStatus != errSecItemNotFound) {
            NSLog(@"[SpoofTweak] delete failed (%d) for %@/%@", (int)delStatus, service, account);
        }
    }
}

@end

#pragma mark - Hook UIWindow to install the button

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    // Ensure UI work on main thread
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self installFloatingButtonIfNeeded]; });
    } else {
        [self installFloatingButtonIfNeeded];
    }
}

- (void)installFloatingButtonIfNeeded {
    if (!self.rootViewController) return;
    if ([self viewWithTag:0xF10A7]) return; // already installed

    CGFloat size = 58.0;
    CGFloat margin = 20.0;
    CGRect frame = CGRectMake(self.bounds.size.width - size - margin,
                              margin + 60.0,
                              size, size);

    SpoofFloatingButton *btn = [[SpoofFloatingButton alloc] initWithFrame:frame];
    btn.tag = 0xF10A7;
    btn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self addSubview:btn];
    [self bringSubviewToFront:btn];
}

%end

#pragma mark - Constructor

%ctor {
    gStateQueue = dispatch_queue_create("com.spooftweak.state", DISPATCH_QUEUE_SERIAL);
    @try {
        [NSURLProtocol registerClass:[SpoofedIPProtocol class]];
        NSLog(@"[SpoofTweak] loaded, SpoofedIPProtocol registered");
    } @catch (NSException *e) {
        NSLog(@"[SpoofTweak] register protocol failed: %@", e);
    }
}
