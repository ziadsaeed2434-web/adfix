// Tweak.x
// Comprehensive iOS tweak for ad fraud prevention – corrected for Theos compilation.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <sys/sysctl.h>
#import <mach/mach.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <notify.h>

// -----------------------------------------------------------------------------
// Global static arrays (allowed at file scope)
// -----------------------------------------------------------------------------
static NSArray *deviceNames = @[@"iPhone 11", @"iPhone 12", @"iPhone 13", @"iPad Pro", @"iPad Air"];
static NSArray *models = @[@"iPhone13,2", @"iPhone14,3", @"iPad13,4"];
static NSArray *localeIdentifiers = @[@"en_US", @"en_GB", @"fr_FR", @"de_DE", @"es_ES", @"it_IT", @"ja_JP"];
static NSArray *timezoneNames = @[@"America/New_York", @"Europe/London", @"Asia/Tokyo", @"Australia/Sydney"];

// -----------------------------------------------------------------------------
// Session‑based randomization seed
// -----------------------------------------------------------------------------
static NSUInteger sessionSeed = 0;

static void generateSessionSeed(void) {
    sessionSeed = (NSUInteger)([[NSDate date] timeIntervalSince1970] * 1000) ^ getpid();
}

static NSUInteger randomInRange(NSUInteger min, NSUInteger max) {
    if (sessionSeed == 0) generateSessionSeed();
    srand((unsigned)sessionSeed + (unsigned)rand());
    return min + arc4random_uniform((uint32_t)(max - min + 1));
}

// -----------------------------------------------------------------------------
// 1. Device & Environment Spoofing
// -----------------------------------------------------------------------------
%hook UIDevice

- (NSString *)name {
    return deviceNames[randomInRange(0, deviceNames.count - 1)];
}

- (NSString *)systemVersion {
    NSUInteger major = randomInRange(14, 16);
    NSUInteger minor = randomInRange(0, 5);
    return [NSString stringWithFormat:@"%lu.%lu", (unsigned long)major, (unsigned long)minor];
}

- (NSString *)model {
    return models[randomInRange(0, models.count - 1)];
}

- (NSString *)localizedModel {
    return [self model];
}

%end

%hook NSLocale

+ (NSLocale *)currentLocale {
    NSString *identifier = localeIdentifiers[randomInRange(0, localeIdentifiers.count - 1)];
    return [[NSLocale alloc] initWithLocaleIdentifier:identifier];
}

+ (NSLocale *)systemLocale {
    return [self currentLocale];
}

%end

%hook NSTimeZone

+ (NSTimeZone *)localTimeZone {
    NSString *name = timezoneNames[randomInRange(0, timezoneNames.count - 1)];
    return [NSTimeZone timeZoneWithName:name];
}

+ (NSTimeZone *)systemTimeZone {
    return [self localTimeZone];
}

%end

// -----------------------------------------------------------------------------
// 2. Low-Level System Functions (sysctl / sysctlbyname)
// -----------------------------------------------------------------------------
static int (*orig_sysctl)(int *, u_int, void *, size_t *, void *, size_t);
static int (*orig_sysctlbyname)(const char *, void *, size_t *, void *, size_t);

static int hooked_sysctl(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int ret = orig_sysctl(name, namelen, oldp, oldlenp, newp, newlen);
    if (ret == 0 && oldp && oldlenp) {
        if (namelen >= 2 && name[0] == CTL_HW) {
            switch (name[1]) {
                case HW_NCPU:
                    if (*oldlenp == sizeof(int)) {
                        int *val = (int *)oldp;
                        *val = (int)randomInRange(2, 8);
                    }
                    break;
                case HW_MEMSIZE:
                case HW_PHYSMEM:
                    if (*oldlenp == sizeof(uint64_t)) {
                        uint64_t *val = (uint64_t *)oldp;
                        uint64_t ramGB = randomInRange(2, 8);
                        *val = ramGB * 1024ULL * 1024ULL * 1024ULL;
                    }
                    break;
                default:
                    break;
            }
        }
    }
    return ret;
}

static int hooked_sysctlbyname(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    int ret = orig_sysctlbyname(name, oldp, oldlenp, newp, newlen);
    if (ret == 0 && oldp && oldlenp) {
        if (strcmp(name, "hw.ncpu") == 0 && *oldlenp == sizeof(int)) {
            int *val = (int *)oldp;
            *val = (int)randomInRange(2, 8);
        } else if ((strcmp(name, "hw.memsize") == 0 || strcmp(name, "hw.physmem") == 0) && *oldlenp == sizeof(uint64_t)) {
            uint64_t *val = (uint64_t *)oldp;
            uint64_t ramGB = randomInRange(2, 8);
            *val = ramGB * 1024ULL * 1024ULL * 1024ULL;
        }
    }
    return ret;
}

// -----------------------------------------------------------------------------
// 3. Network Interception (NSURLSession / NSURLRequest)
// -----------------------------------------------------------------------------
static NSURL *cleanURL(NSURL *originalURL) {
    if (!originalURL) return nil;
    NSURLComponents *components = [NSURLComponents componentsWithURL:originalURL resolvingAgainstBaseURL:NO];
    if (!components) return originalURL;
    
    NSArray *trackingParams = @[@"idfa", @"udid", @"adid", @"aaid", @"openudid", @"gps_adid", @"android_id", @"gaid"];
    NSMutableArray *newQueryItems = [NSMutableArray array];
    for (NSURLQueryItem *item in components.queryItems) {
        if (![trackingParams containsObject:item.name.lowercaseString]) {
            [newQueryItems addObject:item];
        }
    }
    components.queryItems = newQueryItems;
    return components.URL;
}

%hook NSMutableURLRequest

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field caseInsensitiveCompare:@"User-Agent"] == NSOrderedSame) {
        static NSString *customUA = nil;
        if (!customUA) {
            NSArray *osVersions = @[@"15_0", @"15_1", @"15_2", @"16_0", @"16_1"];
            NSArray *uaModels = @[@"iPhone", @"iPad"];
            NSString *model = uaModels[randomInRange(0, uaModels.count-1)];
            NSString *osVer = osVersions[randomInRange(0, osVersions.count-1)];
            customUA = [NSString stringWithFormat:@"Mozilla/5.0 (%@; CPU %@ OS %@ like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1", model, model, osVer];
        }
        value = customUA;
    } else if ([field caseInsensitiveCompare:@"Accept-Language"] == NSOrderedSame) {
        static NSArray *langs = @[@"en-US,en;q=0.9", @"fr-FR,fr;q=0.9", @"de-DE,de;q=0.9", @"ja-JP,ja;q=0.9"];
        value = langs[randomInRange(0, langs.count-1)];
    }
    %orig(value, field);
}

- (void)setURL:(NSURL *)url {
    NSURL *cleaned = cleanURL(url);
    %orig(cleaned);
}

%end

%hook NSURLRequest

- (NSURL *)URL {
    NSURL *origURL = %orig;
    return cleanURL(origURL) ?: origURL;
}

%end

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    NSMutableURLRequest *newRequest = [request mutableCopy];
    [newRequest setURL:cleanURL(request.URL)];
    if (![request valueForHTTPHeaderField:@"User-Agent"]) {
        [newRequest setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1" forHTTPHeaderField:@"User-Agent"];
    }
    if (![request valueForHTTPHeaderField:@"Accept-Language"]) {
        [newRequest setValue:@"en-US,en;q=0.9" forHTTPHeaderField:@"Accept-Language"];
    }
    return %orig(newRequest, completionHandler);
}

%end

// -----------------------------------------------------------------------------
// 4. WKWebView Fingerprint Protection (JavaScript injection)
// -----------------------------------------------------------------------------
%hook WKWebView

- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    NSString *js = @"(function() {"
                   @"    const originalToDataURL = HTMLCanvasElement.prototype.toDataURL;"
                   @"    HTMLCanvasElement.prototype.toDataURL = function(type, quality) {"
                   @"        if (type === 'image/png' || !type) {"
                   @"            const context = this.getContext('2d');"
                   @"            const imageData = context.getImageData(0, 0, this.width, this.height);"
                   @"            const data = imageData.data;"
                   @"            for (let i = 0; i < data.length; i += 4) {"
                   @"                data[i] ^= Math.floor(Math.random() * 2);"
                   @"            }"
                   @"            context.putImageData(imageData, 0, 0);"
                   @"        }"
                   @"        return originalToDataURL.call(this, type, quality);"
                   @"    };"
                   @"    const getParameter = WebGLRenderingContext.prototype.getParameter;"
                   @"    WebGLRenderingContext.prototype.getParameter = function(pname) {"
                   @"        if (pname === 0x1F00) return 'WebKit';"
                   @"        if (pname === 0x1F01) return 'WebKit WebGL';"
                   @"        return getParameter.call(this, pname);"
                   @"    };"
                   @"    const originalCreateOscillator = AudioContext.prototype.createOscillator;"
                   @"    AudioContext.prototype.createOscillator = function() {"
                   @"        const oscillator = originalCreateOscillator.call(this);"
                   @"        const originalConnect = oscillator.connect;"
                   @"        oscillator.connect = function(destination) {"
                   @"            this.frequency.value += Math.random() * 0.1;"
                   @"            return originalConnect.call(this, destination);"
                   @"        };"
                   @"        return oscillator;"
                   @"    };"
                   @"})();";
    
    WKUserScript *script = [[WKUserScript alloc] initWithSource:js injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
    [configuration.userContentController addUserScript:script];
    return %orig(frame, configuration);
}

%end

// -----------------------------------------------------------------------------
// 5. Safe Temporary Cleanup (NO KEYCHAIN)
// -----------------------------------------------------------------------------
static void performCleanup(void) {
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [cookieStorage cookies]) {
        [cookieStorage deleteCookie:cookie];
    }
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *cacheDir = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    if (cacheDir) {
        for (NSString *file in [fm contentsOfDirectoryAtPath:cacheDir error:nil]) {
            [fm removeItemAtPath:[cacheDir stringByAppendingPathComponent:file] error:nil];
        }
    }
    NSString *tmpDir = NSTemporaryDirectory();
    if (tmpDir) {
        for (NSString *file in [fm contentsOfDirectoryAtPath:tmpDir error:nil]) {
            [fm removeItemAtPath:[tmpDir stringByAppendingPathComponent:file] error:nil];
        }
    }
}

// -----------------------------------------------------------------------------
// 6. Early Initialization
// -----------------------------------------------------------------------------
%ctor {
    generateSessionSeed();
    performCleanup();
    
    void *handle = dlopen("/usr/lib/libsystem_kernel.dylib", RTLD_LAZY);
    if (handle) {
        orig_sysctl = (int (*)(int *, u_int, void *, size_t *, void *, size_t))dlsym(handle, "sysctl");
        orig_sysctlbyname = (int (*)(const char *, void *, size_t *, void *, size_t))dlsym(handle, "sysctlbyname");
        if (orig_sysctl) MSHookFunction((void *)orig_sysctl, (void *)hooked_sysctl, NULL);
        if (orig_sysctlbyname) MSHookFunction((void *)orig_sysctlbyname, (void *)hooked_sysctlbyname, NULL);
    }
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
                                                      performCleanup();
                                                  }];
}
