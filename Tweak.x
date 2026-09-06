#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <sys/stat.h>

// ---------------------------------------------------------------------------
// MARK: - Global Spoofing State
// ---------------------------------------------------------------------------

static NSString *g_spoofedName = nil;
static NSString *g_spoofedSystemVersion = nil;
static NSUUID *g_spoofedVendorID = nil;
static float g_spoofedBatteryLevel = 0.0;
static UIDeviceBatteryState g_spoofedBatteryState = UIDeviceBatteryStateUnknown;
static float g_spoofedBacklightLevel = 0.0;
static BOOL g_spoofedSupportsPencil = NO;
static BOOL g_spoofedIsDeveloperMode = NO;
static NSString *g_spoofedProductType = nil;
static NSString *g_spoofedUserAgent = nil;  // <-- جديد
static BOOL g_hasSpoofed = NO;

// ---------------------------------------------------------------------------
// MARK: - Helper Functions
// ---------------------------------------------------------------------------

static float randomFloatBetween(float min, float max) {
    return ((float)arc4random() / UINT32_MAX) * (max - min) + min;
}

static NSString *randomDeviceName(void) {
    NSArray *names = @[@"iPhone", @"iPhone Pro", @"iPhone Max"];
    NSString *base = names[arc4random_uniform((uint32_t)names.count)];
    int model = arc4random_uniform(20) + 1;
    return [NSString stringWithFormat:@"%@ %d", base, model];
}

static NSString *randomSystemVersion(void) {
    int major = 24 + arc4random_uniform(4);          // 24 إلى 27
    int minor = arc4random_uniform(10);
    int patch = arc4random_uniform(10);
    return [NSString stringWithFormat:@"%d.%d.%d", major, minor, patch];
}

static NSString *randomProductType(void) {
    NSArray *products = @[@"iPhone14,2", @"iPhone15,3", @"iPhone16,1", @"iPhone17,2"];
    return products[arc4random_uniform((uint32_t)products.count)];
}

// توليد User-Agent عشوائي مبني على إصدار النظام المعطى
static NSString *randomUserAgent(NSString *systemVersion) {
    // استخراج الأرقام الرئيسية من systemVersion
    NSArray *components = [systemVersion componentsSeparatedByString:@"."];
    if (components.count < 2) {
        // fallback
        components = @[@"26", @"0"];
    }
    NSString *major = components[0];
    NSString *minor = components.count > 1 ? components[1] : @"0";
    
    // بناء رقم البناء (build number) بشكل عشوائي
    int buildNumber = arc4random_uniform(900) + 100; // 100-999
    NSString *build = [NSString stringWithFormat:@"%d", buildNumber];
    
    // WebKit version عشوائي
    int webKitMajor = 600 + arc4random_uniform(10);   // 600-609
    int webKitMinor = arc4random_uniform(20);          // 0-19
    int webKitPatch = arc4random_uniform(10);          // 0-9
    
    // Safari version عشوائي
    int safariMajor = 10 + arc4random_uniform(10);     // 10-19
    int safariMinor = arc4random_uniform(10);          // 0-9
    
    return [NSString stringWithFormat:
            @"Mozilla/5.0 (iPhone; CPU iPhone OS %@_%@ like Mac OS X) AppleWebKit/%d.%d.%d (KHTML, like Gecko) Version/%d.%d Mobile/15E%@ Safari/%d.%d.%d",
            major, minor, webKitMajor, webKitMinor, webKitPatch, safariMajor, safariMinor, build, webKitMajor, webKitMinor, webKitPatch];
}

// ---------------------------------------------------------------------------
// MARK: - Floating Button Implementation
// ---------------------------------------------------------------------------

@interface ResetFloatingButton : UIButton
@property (nonatomic, assign) CGPoint initialCenter;
@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;
@end

@implementation ResetFloatingButton

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithRed:0.2 green:0.6 blue:1.0 alpha:0.9];
        self.layer.cornerRadius = 25.0;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = 0.5;
        self.layer.shadowOffset = CGSizeMake(0, 2);
        self.titleLabel.font = [UIFont systemFontOfSize:24.0];
        [self setTitle:@"⟳" forState:UIControlStateNormal];
        [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self addTarget:self action:@selector(handleTap:) forControlEvents:UIControlEventTouchUpInside];

        self.panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        [self addGestureRecognizer:self.panGesture];
    }
    return self;
}

- (void)handleTap:(id)sender {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self performReset];
    });
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    UIView *superview = self.superview;
    if (!superview) return;

    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.initialCenter = self.center;
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [gesture translationInView:superview];
        self.center = CGPointMake(self.initialCenter.x + translation.x,
                                  self.initialCenter.y + translation.y);
    } else if (gesture.state == UIGestureRecognizerStateEnded ||
               gesture.state == UIGestureRecognizerStateCancelled) {
        CGRect bounds = superview.bounds;
        CGFloat margin = 10.0;
        CGFloat halfWidth = self.frame.size.width / 2.0;
        CGFloat halfHeight = self.frame.size.height / 2.0;
        CGFloat newX = MIN(MAX(self.center.x, margin + halfWidth),
                           bounds.size.width - margin - halfWidth);
        CGFloat newY = MIN(MAX(self.center.y, margin + halfHeight),
                           bounds.size.height - margin - halfHeight);
        [UIView animateWithDuration:0.2 animations:^{
            self.center = CGPointMake(newX, newY);
        }];
        self.initialCenter = self.center;
    }
}

- (void)performReset {
    // توليد قيم جديدة
    g_spoofedName = randomDeviceName();
    g_spoofedSystemVersion = randomSystemVersion();
    g_spoofedVendorID = [NSUUID UUID];
    g_spoofedBatteryLevel = randomFloatBetween(0.15, 0.95);
    g_spoofedBatteryState = (arc4random_uniform(2) == 0) ? UIDeviceBatteryStateCharging : UIDeviceBatteryStateUnplugged;
    g_spoofedBacklightLevel = randomFloatBetween(0.1, 1.0);
    g_spoofedSupportsPencil = (arc4random_uniform(2) == 0);
    g_spoofedIsDeveloperMode = (arc4random_uniform(2) == 0);
    g_spoofedProductType = randomProductType();
    
    // توليد User-Agent جديد عشوائي
    g_spoofedUserAgent = randomUserAgent(g_spoofedSystemVersion);
    
    g_hasSpoofed = YES;

    // مسح الكوكيز
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    if (cookieStorage) {
        NSArray *cookies = [cookieStorage cookies];
        for (NSHTTPCookie *cookie in cookies) {
            [cookieStorage deleteCookie:cookie];
        }
    }

    // مسح UserDefaults
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (bundleID) {
        [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleID];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    // مسح مجلد Caches
    NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    if (cachePaths.count > 0) {
        NSString *cacheDir = cachePaths[0];
        NSFileManager *fm = [NSFileManager defaultManager];
        NSArray *contents = [fm contentsOfDirectoryAtPath:cacheDir error:nil];
        for (NSString *item in contents) {
            NSString *fullPath = [cacheDir stringByAppendingPathComponent:item];
            [fm removeItemAtPath:fullPath error:nil];
        }
    }

    // obliterate background sessions
    Class nsurlSessionClass = NSClassFromString(@"NSURLSession");
    if (nsurlSessionClass && [nsurlSessionClass respondsToSelector:@selector(obliterateAllBackgroundSessionsWithCompletionHandler:)]) {
        [nsurlSessionClass performSelector:@selector(obliterateAllBackgroundSessionsWithCompletionHandler:)
                                withObject:^(void){}];
    }

    // تصفير NSURLCache
    NSURLCache *sharedCache = [NSURLCache sharedURLCache];
    if (sharedCache) {
        [sharedCache removeAllCachedResponses];
        NSURLCache *newCache = [[NSURLCache alloc] initWithMemoryCapacity:0
                                                             diskCapacity:0
                                                                 diskPath:nil];
        [NSURLCache setSharedURLCache:newCache];
    }

    NSLog(@"[FingerprintReset] تم تدوير بصمة الجهاز و User-Agent جديد.");
}

@end

// ---------------------------------------------------------------------------
// MARK: - Hooking UIDevice Getters
// ---------------------------------------------------------------------------

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
    if (g_hasSpoofed && g_spoofedVendorID) return g_spoofedVendorID;
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

// ---------------------------------------------------------------------------
// MARK: - Private UIDevice Hooks (Conditional Groups)
// ---------------------------------------------------------------------------

%group BacklightHook
%hook UIDevice
- (float)_backlightLevel { if (g_hasSpoofed) return g_spoofedBacklightLevel; return %orig; }
%end
%end

%group PencilHook
%hook UIDevice
- (BOOL)_supportsPencil { if (g_hasSpoofed) return g_spoofedSupportsPencil; return %orig; }
%end
%end

%group DeveloperModeHook
%hook UIDevice
- (BOOL)sf_isDeveloperModeEnabled { if (g_hasSpoofed) return g_spoofedIsDeveloperMode; return %orig; }
%end
%end

%group ProductTypeHook
%hook UIDevice
- (NSString *)sf_productType { if (g_hasSpoofed && g_spoofedProductType) return g_spoofedProductType; return %orig; }
%end
%end

// ---------------------------------------------------------------------------
// MARK: - Hooking NSURLSession
// ---------------------------------------------------------------------------

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    if (g_hasSpoofed && g_spoofedUserAgent) {
        [mutableRequest setValue:g_spoofedUserAgent forHTTPHeaderField:@"User-Agent"];
    }
    [mutableRequest setValue:nil forHTTPHeaderField:@"Cookie"];
    return %orig(mutableRequest);
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData * _Nullable, NSURLResponse * _Nullable, NSError * _Nullable))completionHandler {
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    if (g_hasSpoofed && g_spoofedUserAgent) {
        [mutableRequest setValue:g_spoofedUserAgent forHTTPHeaderField:@"User-Agent"];
    }
    [mutableRequest setValue:nil forHTTPHeaderField:@"Cookie"];
    return %orig(mutableRequest, completionHandler);
}

%end

// ---------------------------------------------------------------------------
// MARK: - Adding the Floating Button (iPhone Only)
// ---------------------------------------------------------------------------

static ResetFloatingButton *g_floatingButton = nil;
static BOOL g_buttonAdded = NO;

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;

    if (!g_buttonAdded && self.isKeyWindow) {
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            dispatch_async(dispatch_get_main_queue(), ^{
                g_floatingButton = [[ResetFloatingButton alloc] initWithFrame:CGRectMake(20, 100, 50, 50)];
                [self addSubview:g_floatingButton];
                g_buttonAdded = YES;
            });
        }
    }
}

%end

// ---------------------------------------------------------------------------
// MARK: - Constructor with iPhone Check
// ---------------------------------------------------------------------------

%ctor {
    if ([[UIDevice currentDevice] userInterfaceIdiom] != UIUserInterfaceIdiomPhone) {
        return;
    }

    %init;

    Class uidClass = NSClassFromString(@"UIDevice");
    if (uidClass) {
        if (class_getInstanceMethod(uidClass, NSSelectorFromString(@"_backlightLevel"))) {
            %init(BacklightHook);
        }
        if (class_getInstanceMethod(uidClass, NSSelectorFromString(@"_supportsPencil"))) {
            %init(PencilHook);
        }
        if (class_getInstanceMethod(uidClass, NSSelectorFromString(@"sf_isDeveloperModeEnabled"))) {
            %init(DeveloperModeHook);
        }
        if (class_getInstanceMethod(uidClass, NSSelectorFromString(@"sf_productType"))) {
            %init(ProductTypeHook);
        }
    }
}
