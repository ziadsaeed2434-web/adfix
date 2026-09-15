// Tweak.xm  — non-ARC safe, no warnings, no crashes
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AdSupport/ASIdentifierManager.h>
#import <CoreLocation/CoreLocation.h>
#import <Security/Security.h>
#import <objc/runtime.h>

#pragma mark - Forward declarations

@interface UIWindow (SpoofTweak)
- (void)installFloatingButtonIfNeeded;
@end

#pragma mark - Global state (guarded by gStateLock)

static NSString *gSpoofedIP           = nil;
static NSUUID   *gSpoofedIDFA         = nil;
static double    gSpoofedLatitude     = 0.0;
static double    gSpoofedLongitude    = 0.0;
static BOOL      gLocationSpoofActive = NO;
static NSObject *gStateLock           = nil;

#pragma mark - Helpers

static NSString *generateRandomIP(void) {
    NSArray *subnets = @[@"172.56", @"172.57", @"172.59"];
    NSString *subnet = [subnets objectAtIndex:arc4random_uniform((uint32_t)[subnets count])];
    uint32_t third   = arc4random_uniform(256);
    uint32_t fourth  = arc4random_uniform(256);
    return [NSString stringWithFormat:@"%@.%u.%u", subnet, third, fourth];
}

static NSUUID *generateRandomIDFA(void) {
    return [NSUUID UUID];
}

static void generateAtlantaCoordinate(double *outLat, double *outLon) {
    double lat = 33.7480 + ((double)arc4random_uniform(4200) / 10000.0); // 33.7480 – 33.7900
    double lon = -84.3880 - ((double)arc4random_uniform(4200) / 10000.0); // -84.3880 – -84.4300
    if (outLat) *outLat = lat;
    if (outLon) *outLon = lon;
}

// Returns an autoreleased mutable copy, or nil.
static NSMutableURLRequest *injectIPIntoRequest(NSURLRequest *request) {
    if (!request) return nil;
    NSMutableURLRequest *mutableRequest = [[request mutableCopy] autorelease];
    NSString *ip = nil;
    @synchronized (gStateLock) {
        ip = [[gSpoofedIP retain] autorelease];
    }
    if (ip) {
        [mutableRequest setValue:ip forHTTPHeaderField:@"X-Forwarded-For"];
        [mutableRequest setValue:ip forHTTPHeaderField:@"X-Real-IP"];
        [mutableRequest setValue:ip forHTTPHeaderField:@"Client-IP"];
    }
    return mutableRequest;
}

#pragma mark - NSURLProtocol

@interface SpoofedIPProtocol : NSURLProtocol <NSURLSessionDelegate, NSURLSessionDataDelegate, NSURLSessionTaskDelegate>
@end

@implementation SpoofedIPProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if (!request || !request.URL) return NO;
    NSString *scheme = [request.URL.scheme lowercaseString];
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) return NO;
    if ([NSURLProtocol propertyForKey:@"SpoofedIPHandled" inRequest:request]) return NO;
    return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    NSMutableURLRequest *newRequest = [[self.request mutableCopy] autorelease];
    [NSURLProtocol setProperty:@YES forKey:@"SpoofedIPHandled" inRequest:newRequest];

    NSString *ip = nil;
    @synchronized (gStateLock) {
        ip = [[gSpoofedIP retain] autorelease];
    }
    if (ip) {
        [newRequest setValue:ip forHTTPHeaderField:@"X-Forwarded-For"];
        [newRequest setValue:ip forHTTPHeaderField:@"X-Real-IP"];
        [newRequest setValue:ip forHTTPHeaderField:@"Client-IP"];
    }

    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.protocolClasses = @[]; // prevent recursion
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config
                                                          delegate:self
                                                     delegateQueue:nil];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:newRequest];
    // Retain the session for the lifetime of the task.
    objc_setAssociatedObject(task, @selector(startLoading), session, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [task resume];
}

- (void)stopLoading { /* no-op */ }

#pragma mark NSURLSessionDelegate forwarding

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

#pragma mark - NSURLSession request hooks

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    return %orig(injectIPIntoRequest(request));
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    return %orig(injectIPIntoRequest(request), handler);
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url {
    if (!url) return %orig(url);
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    return [self dataTaskWithRequest:req];   // hits our hooked version above
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url
                        completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    if (!url) return %orig(url, handler);
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    return [self dataTaskWithRequest:req completionHandler:handler];
}

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromData:(NSData *)body {
    return %orig(injectIPIntoRequest(request), body);
}

- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)request fromFile:(NSURL *)fileURL {
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
    @synchronized (gStateLock) {
        idfa = [[gSpoofedIDFA retain] autorelease];
    }
    if (idfa) return idfa;
    return %orig;
}

- (BOOL)isAdvertisingTrackingEnabled {
    return YES;
}

%end

#pragma mark - Location spoofing

%hook CLLocationManager

- (CLLocation *)location {
    if (gLocationSpoofActive) {
        return [[[CLLocation alloc] initWithLatitude:gSpoofedLatitude
                                           longitude:gSpoofedLongitude] autorelease];
    }
    return %orig;
}

- (void)startUpdatingLocation {
    %orig;
    if (gLocationSpoofActive) {
        CLLocation *fake = [[[CLLocation alloc] initWithLatitude:gSpoofedLatitude
                                                       longitude:gSpoofedLongitude] autorelease];
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
        CLLocation *fake = [[[CLLocation alloc] initWithLatitude:gSpoofedLatitude
                                                       longitude:gSpoofedLongitude] autorelease];
        dispatch_async(dispatch_get_main_queue(), ^{
            id<CLLocationManagerDelegate> delegate = self.delegate;
            if (delegate && [delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
                [delegate locationManager:self didUpdateLocations:@[fake]];
            }
        });
    }
}

%end

%hook CLLocation

- (CLLocationCoordinate2D)coordinate {
    if (gLocationSpoofActive) {
        return CLLocationCoordinate2DMake(gSpoofedLatitude, gSpoofedLongitude);
    }
    return %orig;
}

%end

#pragma mark - Floating button

@interface SpoofFloatingButton : UIButton
+ (void)clearSafeDirectories;
+ (void)clearAppDefaults;
+ (void)clearKeychainExceptToken;
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
        UIPanGestureRecognizer *pan = [[[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                              action:@selector(onPan:)] autorelease];
        [self addGestureRecognizer:pan];
    }
    return self;
}

- (void)onPan:(UIPanGestureRecognizer *)g {
    UIView *superview = self.superview;
    if (!superview) return;
    CGPoint t = [g translationInView:superview];
    CGPoint c = self.center;
    c.x += t.x; c.y += t.y;
    CGFloat half = self.bounds.size.width / 2.0;
    c.x = MAX(half, MIN(superview.bounds.size.width  - half, c.x));
    c.y = MAX(half, MIN(superview.bounds.size.height - half, c.y));
    self.center = c;
    [g setTranslation:CGPointZero inView:superview];
}

- (void)onTap {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *newIP   = generateRandomIP();
        NSUUID   *newIDFA = generateRandomIDFA();
        double lat = 0, lon = 0;
        generateAtlantaCoordinate(&lat, &lon);

        @synchronized (gStateLock) {
            [gSpoofedIP release];
            gSpoofedIP = [newIP copy];

            [gSpoofedIDFA release];
            gSpoofedIDFA = [newIDFA retain];

            gSpoofedLatitude     = lat;
            gSpoofedLongitude    = lon;
            gLocationSpoofActive = YES;
        }

        NSLog(@"[SpoofTweak] IP=%@ IDFA=%@ Loc=(%.4f, %.4f)",
              newIP, newIDFA.UUIDString, lat, lon);

        [SpoofFloatingButton clearSafeDirectories];
        [SpoofFloatingButton clearAppDefaults];
        [SpoofFloatingButton clearKeychainExceptToken];

        dispatch_async(dispatch_get_main_queue(), ^{
            UIWindow *keyWindow = nil;
            for (UIWindow *w in [UIApplication sharedApplication].windows) {
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
            [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                     style:UIAlertActionStyleDefault
                                                   handler:nil]];

            UIViewController *presenter = rootVC;
            while (presenter.presentedViewController) presenter = presenter.presentedViewController;
            [presenter presentViewController:alert animated:YES completion:nil];
        });
    });
}

#pragma mark Cleanup routines

+ (void)clearSafeDirectories {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray *paths = [NSMutableArray array];

    NSArray *caches = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    if ([caches count] > 0) [paths addObject:[caches objectAtIndex:0]];

    NSString *tmp = NSTemporaryDirectory();
    if (tmp) [paths addObject:tmp];

    NSArray *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if ([docs count] > 0) [paths addObject:[docs objectAtIndex:0]];

    for (NSString *dir in paths) {
        NSError *listError = nil;
        NSArray *contents = [fm contentsOfDirectoryAtPath:dir error:&listError];
        if (listError) {
            NSLog(@"[SpoofTweak] list error %@: %@", dir, listError.localizedDescription);
            continue;
        }
        for (NSString *name in contents) {
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
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (!bundleID) return;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removePersistentDomainForName:bundleID];
    [defaults synchronize];
    NSLog(@"[SpoofTweak] NSUserDefaults cleared for %@", bundleID);
}

+ (void)clearKeychainExceptToken {
    // Work directly with CF types so this compiles cleanly in ARC and non-ARC.
    CFMutableDictionaryRef query = CFDictionaryCreateMutable(NULL, 0,
                                                              &kCFTypeDictionaryKeyCallBacks,
                                                              &kCFTypeDictionaryValueCallBacks);
    CFDictionarySetValue(query, kSecClass,       kSecClassGenericPassword);
    CFDictionarySetValue(query, kSecMatchLimit,  kSecMatchLimitAll);
    CFDictionarySetValue(query, kSecReturnAttributes, kCFBooleanTrue);

    CFArrayRef cfItems = NULL;
    OSStatus status = SecItemCopyMatching(query, (CFTypeRef *)&cfItems);
    CFRelease(query);

    if (status != errSecSuccess || cfItems == NULL) {
        if (status != errSecItemNotFound) {
            NSLog(@"[SpoofTweak] keychain query status=%d", (int)status);
        }
        if (cfItems) CFRelease(cfItems);
        return;
    }

    CFIndex count = CFArrayGetCount(cfItems);
    for (CFIndex i = 0; i < count; i++) {
        NSDictionary *item = (NSDictionary *)CFArrayGetValueAtIndex(cfItems, i);
        if (![item isKindOfClass:[NSDictionary class]]) continue;

        NSString *service = [item objectForKey:(__bridge id)kSecAttrService];
        NSString *account = [item objectForKey:(__bridge id)kSecAttrAccount];

        // ----- PRESERVE THIS ITEM -----
        if ([service isEqualToString:@"app.getsmscode"] &&
            [account isEqualToString:@"tokenKey"]) {
            NSLog(@"[SpoofTweak] preserved keychain item %@/%@", service, account);
            continue;
        }
        // ------------------------------

        CFMutableDictionaryRef del = CFDictionaryCreateMutable(NULL, 0,
                                                               &kCFTypeDictionaryKeyCallBacks,
                                                               &kCFTypeDictionaryValueCallBacks);
        CFDictionarySetValue(del, kSecClass, kSecClassGenericPassword);
        if (service) CFDictionarySetValue(del, kSecAttrService, (__bridge const void *)service);
        if (account) CFDictionarySetValue(del, kSecAttrAccount, (__bridge const void *)account);

        OSStatus delStatus = SecItemDelete(del);
        CFRelease(del);

        if (delStatus == errSecSuccess) {
            NSLog(@"[SpoofTweak] deleted keychain item %@/%@", service, account);
        } else if (delStatus != errSecItemNotFound) {
            NSLog(@"[SpoofTweak] delete failed (%d) for %@/%@", (int)delStatus, service, account);
        }
    }

    CFRelease(cfItems);
}

@end

#pragma mark - UIWindow hook

%hook UIWindow

- (void)installFloatingButtonIfNeeded {
    if (!self.rootViewController) return;
    if ([self viewWithTag:0xF10A7]) return;   // already installed

    CGFloat size = 58.0;
    CGFloat margin = 20.0;
    CGRect frame = CGRectMake(self.bounds.size.width - size - margin,
                              margin + 60.0,
                              size, size);

    SpoofFloatingButton *btn = [[[SpoofFloatingButton alloc] initWithFrame:frame] autorelease];
    btn.tag = 0xF10A7;
    btn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
    [self addSubview:btn];
    [self bringSubviewToFront:btn];
}

- (void)makeKeyAndVisible {
    %orig;
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self installFloatingButtonIfNeeded]; });
    } else {
        [self installFloatingButtonIfNeeded];
    }
}

%end

#pragma mark - Constructor

%ctor {
    gStateLock = [[NSObject alloc] init];
    @try {
        [NSURLProtocol registerClass:[SpoofedIPProtocol class]];
        NSLog(@"[SpoofTweak] loaded, SpoofedIPProtocol registered");
    } @catch (NSException *e) {
        NSLog(@"[SpoofTweak] register protocol failed: %@", e);
    }
}
