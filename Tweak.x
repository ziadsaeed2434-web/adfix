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
// MARK: - Core Reset Logic (Automatic)
// ---------------------------------------------------------------------------

static void performAutomaticSpoofing(void) {
    g_spoofedName = randomDeviceName();
    g_spoofedSystemVersion = randomSystemVersion();
    g_spoofedVendorID = [NSUUID UUID];
    g_spoofedBatteryLevel = randomFloatBetween(0.15, 0.95);
    g_spoofedBatteryState = (arc4random_uniform(2) == 0) ? UIDeviceBatteryStateCharging : UIDeviceBatteryStateUnplugged;
    g_spoofedBacklightLevel = randomFloatBetween(0.1, 1.0);
    g_spoofedSupportsPencil = (arc4random_uniform(2) == 0);
    g_spoofedIsDeveloperMode = (arc4random_uniform(2) == 0);
    g_spoofedProductType = randomProductType();
    g_spoofedUserAgent = randomUserAgent(g_spoofedSystemVersion);
    g_hasSpoofed = YES;

    // مسح الكوكيز وتنظيف البيانات بأمان لمنع أي استثناءات
    @try {
        NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        if (cookieStorage) {
            NSArray *cookies = [cookieStorage cookies];
            for (NSHTTPCookie *cookie in cookies) {
                [cookieStorage deleteCookie:cookie];
            }
        }

        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (bundleID) {
            [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:bundleID];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }

        NSURLCache *sharedCache = [NSURLCache sharedURLCache];
        if (sharedCache) {
            [sharedCache removeAllCachedResponses];
        }
    } @catch (NSException *exception) {
        NSLog(@"[FingerprintReset] Exception during cleanup: %@", exception);
    }

    NSLog(@"[FingerprintReset] تم توليد بصمة وهمية جديدة تلقائياً عند فتح التطبيق.");
}

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

    // تشغيل التوليد التلقائي للبصمة فور بدء تشغيل التطبيق
    performAutomaticSpoofing();

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
