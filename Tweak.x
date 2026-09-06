#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <sys/stat.h>
#import <AdSupport/AdSupport.h>

// ---------------------------------------------------------------------------
// MARK: - Global Spoofing State
// ---------------------------------------------------------------------------

static NSString *g_spoofedName = nil;
static NSString *g_spoofedSystemVersion = nil;
static NSUUID *g_spoofedIDFA = nil;
static float g_spoofedBatteryLevel = 0.0;
static UIDeviceBatteryState g_spoofedBatteryState = UIDeviceBatteryStateUnknown;
static float g_spoofedBacklightLevel = 0.0;
static BOOL g_spoofedSupportsPencil = NO;
static BOOL g_spoofedIsDeveloperMode = NO;
static NSString *g_spoofedProductType = nil;
static NSString *g_spoofedUserAgent = nil;
static BOOL g_hasSpoofed = NO;

// ---------------------------------------------------------------------------
// MARK: - Helper Functions
// ---------------------------------------------------------------------------

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

static NSString *randomProductType(void) {
    NSArray *products = @[@"iPhone14,2", @"iPhone15,3", @"iPhone16,1", @"iPhone17,2"];
    return products[arc4random_uniform((uint32_t)products.count)];
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
        
        // الخروج النظيف من التطبيق بدون أي رسائل كراش
        dispatch_async(dispatch_get_main_queue(), ^{
            exit(0);
        });
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
    @try {
        g_spoofedName = randomDeviceName();
        g_spoofedSystemVersion = randomSystemVersion();
        g_spoofedIDFA = [NSUUID UUID];
        g_spoofedBatteryLevel = randomFloatBetween(0.15, 0.95);
        g_spoofedBatteryState = (arc4random_uniform(2) == 0) ? UIDeviceBatteryStateCharging : UIDeviceBatteryStateUnplugged;
        g_spoofedBacklightLevel = randomFloatBetween(0.1, 1.0);
        g_spoofedSupportsPencil = (arc4random_uniform(2) == 0);
        g_spoofedIsDeveloperMode = (arc4random_uniform(2) == 0);
        g_spoofedProductType = randomProductType();
        g_spoofedUserAgent = randomUserAgent(g_spoofedSystemVersion);
        g_hasSpoofed = YES;

        // 1. مسح الكوكيز
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        if (cookieStorage) {
            NSArray *cookies = [cookieStorage cookies];
            for (NSHTTPCookie *cookie in cookies) {
                [cookieStorage deleteCookie:cookie];
            }
        }

        // 2. مسح إعدادات NSUserDefaults
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleID) {
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleID];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }

        NSFileManager *fm = [NSFileManager defaultManager];
        
        // 3. مسح جميع الملفات والمجلدات الموجودة داخل مجلد التطبيق الرئيسي (Home Directory) بشكل عام
        NSString *homeDir = NSHomeDirectory();
        if (homeDir) {
            NSArray *contents = [fm contentsOfDirectoryAtPath:homeDir error:nil];
            for (NSString *item in contents) {
                // استثناء مجلدات النظام الأساسية التي قد تمنع تشغيل التطبيق أو الكراش فوراً إذا حُذفت بالكامل
                if ([item isEqualToString:@"Applications"] || [item isEqualToString:@"Library/Caches/Snapshots"]) {
                    continue;
                }
                NSString *fullPath = [homeDir stringByAppendingPathComponent:item];
                [fm removeItemAtPath:fullPath error:nil];
            }
        }

        // 4. تفريغ ذاكرة الكاش الخاصة بالشبكة
        NSURLCache *sharedCache = [NSURLCache sharedURLCache];
        if (sharedCache) {
            [sharedCache removeAllCachedResponses];
        }
    } @catch (NSException *exception) {
        // يتم تجاهل أي استثناء تماماً لمنع ظهور الخطأ
    }
}

@end

// ---------------------------------------------------------------------------
// MARK: - Hooking UIDevice
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
// MARK: - Hooking ASIdentifierManager (IDFA Spoofing)
// ---------------------------------------------------------------------------

%hook ASIdentifierManager

- (NSUUID *)advertisingIdentifier {
    if (g_hasSpoofed && g_spoofedIDFA) {
        return g_spoofedIDFA;
    }
    return %orig;
}

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
// MARK: - Adding the Floating Button (iPhone Only - Right Side)
// ---------------------------------------------------------------------------

static ResetFloatingButton *g_floatingButton = nil;
static BOOL g_buttonAdded = NO;

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;

    if (!g_buttonAdded && self.isKeyWindow) {
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            dispatch_async(dispatch_get_main_queue(), ^{
                CGFloat screenWidth = self.bounds.size.width;
                CGFloat buttonWidth = 50.0;
                CGFloat buttonHeight = 50.0;
                CGFloat rightX = screenWidth - buttonWidth - 20.0;
                CGFloat topY = 100.0;

                g_floatingButton = [[ResetFloatingButton alloc] initWithFrame:CGRectMake(rightX, topY, buttonWidth, buttonHeight)];
                [self addSubview:g_floatingButton];
                g_buttonAdded = YES;
            });
        }
    }
}

%end

// ---------------------------------------------------------------------------
// MARK: - Private Method Swizzling
// ---------------------------------------------------------------------------

static float (*orig_backlightLevel)(id self, SEL _cmd) = NULL;
static BOOL (*orig_supportsPencil)(id self, SEL _cmd) = NULL;
static BOOL (*orig_developerModeEnabled)(id self, SEL _cmd) = NULL;
static NSString * (*orig_productType)(id self, SEL _cmd) = NULL;

static float replaced_backlightLevel(id self, SEL _cmd) {
    if (g_hasSpoofed) return g_spoofedBacklightLevel;
    return orig_backlightLevel(self, _cmd);
}

static BOOL replaced_supportsPencil(id self, SEL _cmd) {
    if (g_hasSpoofed) return g_spoofedSupportsPencil;
    return orig_supportsPencil(self, _cmd);
}

static BOOL replaced_developerModeEnabled(id self, SEL _cmd) {
    if (g_hasSpoofed) return g_spoofedIsDeveloperMode;
    return orig_developerModeEnabled(self, _cmd);
}

static NSString * replaced_productType(id self, SEL _cmd) {
    if (g_hasSpoofed && g_spoofedProductType) return g_spoofedProductType;
    return orig_productType(self, _cmd);
}

// ---------------------------------------------------------------------------
// MARK: - Constructor
// ---------------------------------------------------------------------------

%ctor {
    if ([[UIDevice currentDevice] userInterfaceIdiom] != UIUserInterfaceIdiomPhone) {
        return;
    }

    %init;

    Class uidClass = NSClassFromString(@"UIDevice");
    if (uidClass) {
        SEL selBacklight = NSSelectorFromString(@"_backlightLevel");
        if ([uidClass instancesRespondToSelector:selBacklight]) {
            Method method = class_getInstanceMethod(uidClass, selBacklight);
            orig_backlightLevel = (float (*)(id, SEL))method_getImplementation(method);
            method_setImplementation(method, (IMP)replaced_backlightLevel);
        }

        SEL selPencil = NSSelectorFromString(@"_supportsPencil");
        if ([uidClass instancesRespondToSelector:selPencil]) {
            Method method = class_getInstanceMethod(uidClass, selPencil);
            orig_supportsPencil = (BOOL (*)(id, SEL))method_getImplementation(method);
            method_setImplementation(method, (IMP)replaced_supportsPencil);
        }

        SEL selDevMode = NSSelectorFromString(@"sf_isDeveloperModeEnabled");
        if ([uidClass instancesRespondToSelector:selDevMode]) {
            Method method = class_getInstanceMethod(uidClass, selDevMode);
            orig_developerModeEnabled = (BOOL (*)(id, SEL))method_getImplementation(method);
            method_setImplementation(method, (IMP)replaced_developerModeEnabled);
        }

        SEL selProductType = NSSelectorFromString(@"sf_productType");
        if ([uidClass instancesRespondToSelector:selProductType]) {
            Method method = class_getInstanceMethod(uidClass, selProductType);
            orig_productType = (NSString * (*)(id, SEL))method_getImplementation(method);
            method_setImplementation(method, (IMP)replaced_productType);
        }
    }
}
